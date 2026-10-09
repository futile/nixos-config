import assert from "node:assert/strict";
import { test } from "node:test";
import { appendFileSync, existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, renameSync, rmSync, symlinkSync, unlinkSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import restartInDir from "./index.ts";
import { CHECKPOINT, FLAG, MARKER, readSession, savedBranch, type Request } from "./handoff.ts";

const ACTOR = Symbol.for("futile.pi.subagents.restart-in-dir.v1");
const LOOKUP = Symbol.for("futile.pi.subagents.agent-name-lookup.v1");
const globals = globalThis as Record<symbol, unknown>;
type Handler = (event: any, ctx: ExtensionContext) => unknown;
class FakePi {
  handlers = new Map<string, Handler[]>();
  channels = new Map<string, Array<(event: any) => void>>();
  command: any;
  tool: any;
  flag: unknown;
  thinking = "low";
  current: any;
  persistCheckpoint = true;
  ledger: string[] = [];
  on(name: string, handler: Handler) { this.handlers.set(name, [...this.handlers.get(name) ?? [], handler]); }
  registerFlag(name: string, options: any) { assert.equal(name, FLAG); assert.equal(options.type, "string"); }
  registerCommand(name: string, command: any) { assert.equal(name, "restart-in-dir"); this.command = command; }
  registerTool(tool: any) { this.tool = tool; }
  getFlag() { return this.flag; }
  getThinkingLevel() { return this.thinking; }
  appendEntry(customType: string, data: any) {
    this.ledger.push("checkpoint");
    this.current.append({ type: "custom", customType, data }, this.persistCheckpoint);
  }
  events = {
    on: (name: string, handler: (event: any) => void) => {
      this.channels.set(name, [...this.channels.get(name) ?? [], handler]);
      return () => this.channels.set(name, this.channels.get(name)!.filter((item) => item !== handler));
    },
    emit: (name: string, event: any) => { for (const handler of this.channels.get(name) ?? []) handler(event); },
  };
  async emit(name: string, event: any, ctx: ExtensionContext) {
    const values: unknown[] = [];
    for (const handler of this.handlers.get(name) ?? []) values.push(await handler(event, ctx));
    return values;
  }
}
function fixture() {
  const root = mkdtempSync(join(tmpdir(), "pi-restart-extension-"));
  const cwd = join(root, "source"); const target = join(root, "target ; ' $(echo x)"); const control = join(root, "control");
  for (const path of [cwd, target, control]) mkdirSync(path, { mode: 0o700 });
  const source = join(root, "source.jsonl");
  const entries: any[] = [
    { type: "session", version: 3, id: "source-session", cwd },
    { type: "model_change", id: "model-a", parentId: null, provider: "fake", modelId: "a" },
    { type: "thinking_level_change", id: "low", parentId: "model-a", thinkingLevel: "low" },
    { type: "message", id: "user", parentId: "low", message: { role: "user", content: "task" } },
    { type: "message", id: "answer", parentId: "user", message: { role: "assistant", provider: "fake", model: "a", api: "fake-api", content: [{ type: "text", text: "answer" }] } },
  ];
  const persist = () => writeFileSync(source, entries.map((entry) => JSON.stringify(entry)).join("\n") + "\n");
  persist();
  const launch: any = { version: 2, childId: "old-child", launcherPid: process.ppid, unsupported: [], interactive: true, incoming: null };
  const saveLaunch = () => writeFileSync(join(control, "launch.json"), JSON.stringify(launch), { mode: 0o600 });
  saveLaunch();
  const oldEnv = { ...process.env };
  process.env.PI_RESTARTABLE_CONTROL_DIR = control;
  process.env.PI_RESTARTABLE_CHILD_ID = launch.childId;
  process.env.PI_RESTARTABLE_LAUNCHER_PID = String(process.ppid);
  const oldActor = globals[ACTOR]; const oldLookup = globals[LOOKUP];
  delete globals[ACTOR]; delete globals[LOOKUP];
  const oldTerm = process.listeners("SIGTERM"); const oldHup = process.listeners("SIGHUP");
  const notices: string[] = [];
  const noticeLevels: string[] = [];
  const dialogs: Array<{ title: string; options: string[]; opts: any }> = [];
  const approvalRequests: any[] = [];
  let status: any = { state: "none", rc: null };
  let approvalHandler: (request: any) => any = (request) => {
    if (request.action === "allow") status = { ...status, state: "allowed" };
    return { ok: true, status };
  };
  const server = setInterval(() => {
    const file = join(control, "approval-request.json");
    if (!existsSync(file)) return;
    const request = JSON.parse(readFileSync(file, "utf8")); unlinkSync(file);
    approvalRequests.push(request);
    const reply = approvalHandler(request);
    if (reply === undefined) return;
    const response = join(control, `approval-response.${request.requestId}.json`);
    writeFileSync(response + ".tmp", JSON.stringify({ version: 1, childId: request.childId, requestId: request.requestId, ...reply }), { mode: 0o600 });
    renameSync(response + ".tmp", response);
  }, 5);
  let select: (dialog: { title: string; options: string[]; opts: any }) => Promise<string | undefined> = async () => "Cancel";
  const pi = new FakePi();
  let leaf = entries.at(-1).id;
  let entryCount = 0;
  let idle = true; let pending = false; let shutdown = false;
  let currentFile = source;
  let currentHeader = entries[0];
  let currentBranch = () => savedBranch(entries, leaf);
  const ctx: any = {
    mode: "tui", hasUI: true, cwd,
    model: { provider: "fake", id: "a", api: "fake-api" },
    modelRegistry: {
      find: (provider: string, id: string) => provider === "fake" ? { provider, id, api: "fake-api" } : undefined,
      hasConfiguredAuth: () => true,
      getApiKeyAndHeaders: async () => ({ ok: true }),
    },
    isIdle: () => idle, hasPendingMessages: () => pending,
    ui: { notify: (text: string, level: string) => { notices.push(text); noticeLevels.push(level); }, select: (title: string, options: string[], opts: any) => { const dialog = { title, options, opts }; dialogs.push(dialog); return select(dialog); } },
    shutdown: () => { assert.ok(existsSync(join(control, "request.json")), "commit must precede shutdown"); pi.ledger.push("shutdown"); shutdown = true; },
    sessionManager: {
      getSessionId: () => currentHeader.id, getSessionFile: () => currentFile, getHeader: () => currentHeader,
      getBranch: () => currentBranch(), getLeafId: () => leaf,
      buildSessionProjection: () => ({ messages: currentBranch().filter((entry) => entry.type === "message").map((entry) => entry.message) }),
    },
  };
  const append = (entry: any, saved = true) => {
    const complete = { id: `entry-${++entryCount}`, parentId: leaf, ...entry };
    entries.push(complete); leaf = complete.id;
    if (saved) appendFileSync(currentFile, JSON.stringify(complete) + "\n");
    return complete;
  };
  pi.current = { append }; restartInDir(pi as unknown as ExtensionAPI);
  const cleanup = () => {
    clearInterval(server);
    for (const [name, before] of [["SIGTERM", oldTerm], ["SIGHUP", oldHup]] as const) for (const handler of process.listeners(name)) if (!before.includes(handler)) process.off(name, handler);
    for (const name of ["PI_RESTARTABLE_CONTROL_DIR", "PI_RESTARTABLE_CHILD_ID", "PI_RESTARTABLE_LAUNCHER_PID"]) {
      if (oldEnv[name] === undefined) delete process.env[name]; else process.env[name] = oldEnv[name];
    }
    if (oldActor === undefined) delete globals[ACTOR]; else globals[ACTOR] = oldActor;
    if (oldLookup === undefined) delete globals[LOOKUP]; else globals[LOOKUP] = oldLookup;
    rmSync(root, { recursive: true, force: true });
  };
  const toolBatch = (calls: Array<{ type: string; id: string; name: string; arguments: Record<string, unknown> }> = [{ type: "toolCall", id: "switch", name: "restart-in-dir", arguments: { directory: target } }]) => append({ type: "message", message: { role: "assistant", provider: "fake", model: "a", api: "fake-api", content: calls } });
  const acceptedTool = async (directory = target) => {
    toolBatch([{ type: "toolCall", id: "switch", name: "restart-in-dir", arguments: { directory } }]); idle = false;
    await pi.emit("tool_execution_start", { toolCallId: "switch", toolName: "restart-in-dir" }, ctx);
    assert.equal((await pi.emit("tool_call", { toolCallId: "switch", toolName: "restart-in-dir", input: { directory: target } }, ctx))[0], undefined);
    const result = await pi.tool.execute("switch", { directory }, undefined, undefined, ctx);
    await pi.emit("tool_result", { toolCallId: "switch", toolName: "restart-in-dir", isError: false }, ctx);
    await pi.emit("tool_execution_end", { toolCallId: "switch", toolName: "restart-in-dir" }, ctx);
    return result;
  };
  const saveResult = () => {
    pi.ledger.push("result_saved");
    append({ type: "message", message: { role: "toolResult", toolCallId: "switch", toolName: "restart-in-dir", content: [{ type: "text", text: "accepted" }], isError: false } });
  };
  const request = () => JSON.parse(readFileSync(join(control, "request.json"), "utf8")) as Request;
  const restore = (incoming: Request, sameDirectory = false) => {
    launch.childId = "new-child"; launch.incoming = incoming; saveLaunch(); process.env.PI_RESTARTABLE_CHILD_ID = launch.childId;
    pi.flag = incoming.childId;
    ctx.cwd = incoming.target;
    if (!sameDirectory) {
      currentHeader = { type: "session", id: "target-session", cwd: incoming.target, parentSession: incoming.source };
      currentFile = join(root, "fork.jsonl");
      writeFileSync(currentFile, [currentHeader, ...entries.slice(1)].map((entry) => JSON.stringify(entry)).join("\n") + "\n");
    }
  };
  const health = (modify: (value: any) => any = (value) => value) => pi.events.on("pi-restart-in-dir:ic-health-request", (event) => pi.events.emit("pi-restart-in-dir:ic-health-response", modify({ ...event, version: 2, ok: true })));
  return { noticeLevels, dialogs, approvalRequests, status: (value: any) => { status = value; }, approvalHandler: (value: typeof approvalHandler) => { approvalHandler = value; }, selectDialog: (value: typeof select) => { select = value; }, root, cwd, target, control, source, entries, launch, saveLaunch, ctx, pi, notices, cleanup, toolBatch, acceptedTool, saveResult, request, append, restore, health,
    reload: () => { pi.handlers.clear(); restartInDir(pi as unknown as ExtensionAPI); },
    idle: (value: boolean) => { idle = value; }, pending: (value: boolean) => { pending = value; }, didShutdown: () => shutdown,
    select: (id: string) => { leaf = id; }, sourceFile: (file: string) => { currentFile = file; },
  };
}
async function started(f: ReturnType<typeof fixture>) { await f.pi.emit("session_start", { type: "session_start", reason: "startup" }, f.ctx); }

// Fixtures deliberately exercise public ExtensionContext only, not private core queues.
test("registers mandatory flag, required directory model-only/sequential tool", () => {
  const f = fixture(); try {
    assert.equal(f.pi.tool.name, "restart-in-dir"); assert.equal(f.pi.tool.exposure, "model-only"); assert.equal(f.pi.tool.executionMode, "sequential");
    assert.deepEqual(f.pi.tool.parameters.required, ["directory"]); assert.equal(f.pi.tool.parameters.additionalProperties, false);
  } finally { f.cleanup(); }
});

test("idle command checkpoints historical selected native state, atomically commits before shutdown", async () => {
  const f = fixture(); try {
    await started(f);
    f.append({ type: "model_change", provider: "fake", modelId: "b" }); f.append({ type: "thinking_level_change", thinkingLevel: "high" });
    f.ctx.model.id = "b"; f.pi.thinking = "high"; f.select("answer");
    await f.pi.command.handler(f.target, f.ctx);
    assert.equal(f.didShutdown(), true);
    assert.deepEqual(f.pi.ledger, ["checkpoint", "shutdown"]);
    assert.deepEqual(f.request().expected, { model: { provider: "fake", modelId: "a" }, thinkingLevel: "low" });
    assert.equal(f.request().prompt, null); assert.equal(f.request().continue, false);
    const last = readSession(f.source).at(-1);
    assert.equal(last.parentId, "answer"); assert.equal(last.id, f.request().checkpointId); assert.equal(last.customType, CHECKPOINT);
  } finally { f.cleanup(); }
});

test("tool stages terminate result, blocks later old tools and only finalizes once result is saved at settled", async () => {
  const f = fixture(); try {
    await started(f);
    const result = await f.acceptedTool();
    assert.equal(result.terminate, true); assert.equal(result.details.accepted, true);
    assert.equal(f.didShutdown(), false); assert.equal(existsSync(join(f.control, "request.json")), false);
    assert.deepEqual((await f.pi.emit("tool_call", { toolCallId: "later", toolName: "write", input: {} }, f.ctx))[0], { block: true, reason: "Restart handoff accepted; no more old-process tools may execute" });
    await assert.rejects(f.pi.tool.execute("again", { directory: f.target }, undefined, undefined, f.ctx), /already accepted/);
    f.saveResult(); f.idle(true);
    await f.pi.emit("agent_settled", {}, f.ctx);
    assert.equal(f.didShutdown(), true); assert.deepEqual(f.pi.ledger, ["result_saved", "checkpoint", "shutdown"]);
    assert.equal(f.request().continue, true); assert.match(f.request().prompt!, /Verify the current cwd/);
  } finally { f.cleanup(); }
});

test("mixed batches are wholly blocked, including siblings before and after restart; nested calls denied", async () => {
  const f = fixture(); try {
    f.toolBatch([{ type: "toolCall", id: "write", name: "write", arguments: {} }, { type: "toolCall", id: "switch", name: "restart-in-dir", arguments: { directory: f.target } }]);
    for (const [toolName, toolCallId] of [["write", "write"], ["restart-in-dir", "switch"]]) assert.equal(((await f.pi.emit("tool_call", { toolName, toolCallId, input: {} }, f.ctx))[0] as any).block, true);
    f.toolBatch();
    assert.equal(((await f.pi.emit("tool_call", { toolName: "restart-in-dir", toolCallId: "parent/1", parentToolCallId: "parent", input: {} }, f.ctx))[0] as any).block, true);
    assert.equal(f.didShutdown(), false); assert.equal(f.pi.ledger.length, 0);
  } finally { f.cleanup(); }
});

test("plain Pi, unsupported options, wrong parent/mode/identity and pending work refuse without checkpoint or exit", async () => {
  for (const mutate of [
    (f: any) => { delete process.env.PI_RESTARTABLE_CONTROL_DIR; },
    (f: any) => { f.launch.unsupported = ["--api-key"]; f.saveLaunch(); },
    (f: any) => { process.env.PI_RESTARTABLE_LAUNCHER_PID = String(process.pid); },
    (f: any) => { f.ctx.mode = "rpc"; },
    (f: any) => { globals[LOOKUP] = () => "child"; },
    (f: any) => { globals[ACTOR] = { inspect: () => ({ main: false, ready: true }), acquire: () => ({ ok: true }), release: () => {} }; },
    (f: any) => { f.pending(true); }, (f: any) => { f.idle(false); },
    (f: any) => { f.sourceFile(join(f.root, "unsaved.jsonl")); },
  ]) {
    const f = fixture(); try {
      await started(f); mutate(f); await f.pi.command.handler(f.target, f.ctx);
      assert.equal(f.didShutdown(), false); assert.equal(f.pi.ledger.length, 0); assert.equal(existsSync(join(f.control, "request.json")), false);
      assert.match(f.notices.at(-1)!, /Restart refused.*Manual recovery/);
      assert.match(f.notices.at(-1)!, /unsaved \/tree/);
    } finally { f.cleanup(); }
  }
});

test("command directory required and files/missing directories refused without changing source", async () => {
  const f = fixture(); try {
    for (const arg of ["", f.source, join(f.root, "missing")]) await f.pi.command.handler(arg, f.ctx);
    assert.equal(f.didShutdown(), false); assert.equal(f.pi.ledger.length, 0);
  } finally { f.cleanup(); }
});

test("actor missing readiness bridge fails closed; busy bridge blocks and failed preparation releases acquired lease", async () => {
  const f = fixture(); try {
    globals[LOOKUP] = () => "main";
    await f.pi.command.handler(f.target, f.ctx); assert.match(f.notices.at(-1)!, /without its restart readiness bridge/);
    let ready = false; let acquired = 0; let released = 0;
    globals[ACTOR] = { inspect: () => ({ main: true, ready, reason: "buffered actor work" }), acquire: () => { acquired++; return { ok: true }; }, release: () => { released++; } };
    await f.pi.command.handler(f.target, f.ctx); assert.equal(acquired, 0); assert.match(f.notices.at(-1)!, /buffered actor work/);
    ready = true; f.pi.persistCheckpoint = false;
    await f.pi.command.handler(f.target, f.ctx);
    assert.equal(acquired, 1); assert.equal(released, 1); assert.equal(f.didShutdown(), false); assert.equal(existsSync(join(f.control, "request.json")), false);
    assert.match(f.notices.at(-1)!, /checkpoint was not saved/);
  } finally { f.cleanup(); }
});

test("in-flight actor refusal explains subagent work and safe retry in tool errors and command notifications", async () => {
  for (const refusal of ["inspect", "acquire"] as const) {
    const f = fixture(); try {
      globals[ACTOR] = {
        inspect: () => ({ main: true, ready: refusal !== "inspect", reason: "actor operation is in flight" }),
        acquire: () => ({ ok: false, reason: "actor operation is in flight" }),
        release: () => { assert.fail("no lease was acquired"); },
      };
      const guidance = /actor operation is in flight: subagent work or a control operation.*still running or finishing.*settle before retrying restart-in-dir.*end your turn instead of polling/;
      f.toolBatch();
      await assert.rejects(f.pi.tool.execute("switch", { directory: f.target }, undefined, undefined, f.ctx), guidance);
      assert.match(f.notices.at(-1)!, guidance);
      await f.pi.command.handler(f.target, f.ctx);
      assert.match(f.notices.at(-1)!, guidance);
      assert.equal(f.didShutdown(), false); assert.equal(f.pi.ledger.length, 0);
      assert.equal(existsSync(join(f.control, "request.json")), false);
    } finally { f.cleanup(); }
  }
});

test("final readiness changes, missing durable tool result, and persistence failures cancel handoff without shutdown", async () => {
  for (const mutate of [
    (f: any) => { f.pending(true); },
    (f: any) => { /* deliberately do not save tool result */ },
    (f: any) => { f.saveResult(); f.pi.persistCheckpoint = false; },
  ]) {
    const f = fixture(); try {
      await started(f); await f.acceptedTool(); f.idle(true); mutate(f);
      await f.pi.emit("agent_settled", {}, f.ctx);
      assert.equal(f.didShutdown(), false); assert.equal(existsSync(join(f.control, "request.json")), false);
      assert.match(f.notices.at(-1)!, /Restart refused/);
      assert.equal((await f.pi.emit("tool_call", { toolName: "write", toolCallId: "new", input: {} }, f.ctx))[0], undefined);
    } finally { f.cleanup(); }
  }
});

test("direct SIGTERM/SIGHUP invalidate even committed request; ordinary shutdown does not", async () => {
  for (const signal of ["SIGTERM", "SIGHUP"] as const) {
    const f = fixture(); try {
      await started(f); await f.pi.command.handler(f.target, f.ctx);
      await f.pi.emit("session_shutdown", {}, f.ctx);
      assert.equal(existsSync(join(f.control, "request.json")), true);
      // Invoke only newly installed listeners; never send signals to the test process.
      const listener = process.listeners(signal).at(-1)!;
      listener(signal);
      assert.equal(existsSync(join(f.control, "request.json")), false);
    } finally { f.cleanup(); }
  }
});

test("same-directory canonical alias handoff retains source/session identity and no prompt on command", async () => {
  const f = fixture(); try {
    symlinkSync(f.cwd, join(f.root, "alias"));
    await started(f); await f.pi.command.handler(join(f.root, "alias"), f.ctx);
    const request = f.request(); assert.equal(request.target, f.cwd);
    f.restore(request, true); await started(f);
    assert.match(f.notices.at(-1)!, /Session ID retained/);
    assert.equal(f.ctx.sessionManager.getSessionId(), "source-session");
    assert.equal(request.prompt, null);
  } finally { f.cleanup(); }
});

async function continuationFixture() {
  const f = fixture(); await started(f); await f.acceptedTool(); f.saveResult(); f.idle(true);
  await f.pi.emit("agent_settled", {}, f.ctx); const request = f.request(); f.restore(request); await started(f);
  return { f, request };
}
test("valid opaque marker transforms private metadata exactly once after synchronous keyed IC health", async () => {
  const { f, request } = await continuationFixture(); try {
    f.health();
    const [result] = await f.pi.emit("input", { text: MARKER + request.childId, source: "interactive" }, f.ctx);
    assert.deepEqual(result, { action: "transform", text: request.prompt, images: undefined });
    assert.deepEqual((await f.pi.emit("input", { text: MARKER + request.childId, source: "interactive" }, f.ctx))[0], { action: "handled" });
    assert.equal((await f.pi.emit("input", { text: "ordinary input", source: "interactive" }, f.ctx))[0], undefined);
  } finally { f.cleanup(); }
});

test("marker guard withholds missing/stale/failed health, flags, target/model/auth/thinking fallback", async () => {
  for (const mutate of [
    (f: any) => {},
    (f: any) => { f.health((value: any) => ({ ...value, leafId: "stale" })); },
    (f: any) => { f.health((value: any) => ({ ...value, sessionId: "other" })); },
    (f: any) => { f.health((value: any) => ({ ...value, version: 1 })); },
    (f: any) => { f.health((value: any) => ({ ...value, ok: false })); },
    (f: any) => { f.health(); f.health(); },
    (f: any) => { f.health(); f.pi.flag = undefined; },
    (f: any) => { f.health(); f.ctx.cwd = f.cwd; },
    (f: any) => { f.health(); f.ctx.model.id = "b"; },
    (f: any) => { f.health(); f.pi.thinking = "off"; },
    (f: any) => { f.health(); f.ctx.modelRegistry.find = () => undefined; },
    (f: any) => { f.health(); f.ctx.modelRegistry.hasConfiguredAuth = () => false; },
    (f: any) => { f.health(); f.ctx.modelRegistry.getApiKeyAndHeaders = async () => ({ ok: false }); },
    (f: any) => { f.health(); f.pending(true); },
  ]) {
    const { f, request } = await continuationFixture(); try {
      mutate(f);
      assert.deepEqual((await f.pi.emit("input", { text: MARKER + request.childId, source: "interactive" }, f.ctx))[0], { action: "handled" });
      assert.match(f.notices.at(-1)!, /continuation withheld/);
    } finally { f.cleanup(); }
  }
});

test("spoofed markers and nested execution never start a turn or publish handoff", async () => {
  const f = fixture(); try {
    await started(f);
    assert.deepEqual((await f.pi.emit("input", { text: MARKER + "spoof", source: "interactive" }, f.ctx))[0], { action: "handled" });
    f.toolBatch();
    await assert.rejects(f.pi.tool.execute("parent/1", { directory: f.target }, undefined, undefined, f.ctx), /sole, direct/);
    assert.equal(f.didShutdown(), false);
  } finally { f.cleanup(); }
});

test("same-directory tool continuation tolerates legitimate startup metadata after checkpoint", async () => {
  const f = fixture(); try {
    await started(f); await f.acceptedTool(f.cwd); f.saveResult(); f.idle(true);
    await f.pi.emit("agent_settled", {}, f.ctx);
    const request = f.request(); f.restore(request, true);
    f.append({ type: "custom", customType: "startup-metadata", data: { loaded: true } });
    await started(f); f.health();
    assert.match(f.notices.at(-1)!, /Session ID retained/);
    assert.deepEqual((await f.pi.emit("input", { text: MARKER + request.childId, source: "interactive" }, f.ctx))[0], { action: "transform", text: request.prompt, images: undefined });
    assert.equal(f.ctx.sessionManager.getSessionFile(), f.source);
  } finally { f.cleanup(); }
});

test("a no-message selected leaf in saved file uses native target defaults, not live source settings", async () => {
  const f = fixture(); try {
    f.ctx.model.id = "live-source"; f.pi.thinking = "max";
    f.select("low"); await started(f); await f.pi.command.handler(f.target, f.ctx);
    assert.equal(f.didShutdown(), true);
    assert.deepEqual(f.request().expected, { model: null, thinkingLevel: null });
  } finally { f.cleanup(); }
});

test("virtual selected model holds over physical response, but missing target virtual registry suppresses continuation", async () => {
  const f = fixture(); try {
    f.append({ type: "model_change", provider: "fake", modelId: "virtual" });
    f.ctx.modelRegistry.find = (provider: string, id: string) => ({ provider, id, api: id === "virtual" ? "pi-virtual" : "fake-api" });
    f.ctx.model.id = "virtual"; f.ctx.model.api = "pi-virtual";
    await started(f); await f.acceptedTool(); f.saveResult(); f.idle(true);
    await f.pi.emit("agent_settled", {}, f.ctx); const request = f.request();
    assert.deepEqual(request.expected.model, { provider: "fake", modelId: "virtual" });
    f.restore(request); await started(f); f.health();
    f.ctx.modelRegistry.find = (provider: string, id: string) => id === "virtual" ? undefined : ({ provider, id, api: "fake-api" });
    assert.deepEqual((await f.pi.emit("input", { text: MARKER + request.childId, source: "interactive" }, f.ctx))[0], { action: "handled" });
    assert.match(f.notices.at(-1)!, /missing virtual selection/);
  } finally { f.cleanup(); }
});

test("authentication awaits cannot authorize a changed native model or selected thinking branch", async () => {
  for (const change of [
    (f: any) => { f.ctx.model.id = "new-model"; },
    (f: any) => { f.append({ type: "thinking_level_change", thinkingLevel: "high" }); },
    (f: any) => { f.pending(true); },
  ]) {
    const { f, request } = await continuationFixture(); try {
      f.health(); f.ctx.modelRegistry.getApiKeyAndHeaders = async () => { change(f); return { ok: true }; };
      assert.deepEqual((await f.pi.emit("input", { text: MARKER + request.childId, source: "interactive" }, f.ctx))[0], { action: "handled" });
      assert.match(f.notices.at(-1)!, /withheld/);
    } finally { f.cleanup(); }
  }
});

test("IC reply must be synchronous and exactly keyed; invalid marker never reaches model text", async () => {
  const { f, request } = await continuationFixture(); try {
    f.pi.events.on("pi-restart-in-dir:ic-health-request", (event) => queueMicrotask(() => f.pi.events.emit("pi-restart-in-dir:ic-health-response", { ...event, version: 2, ok: true })));
    assert.deepEqual((await f.pi.emit("input", { text: MARKER + request.childId, source: "interactive" }, f.ctx))[0], { action: "handled" });
    assert.match(f.notices.at(-1)!, /infinite-context v2 health/);
  } finally { f.cleanup(); }
});

test("actor lease races fail closed and release without checkpointing; staged signals cannot commit", async () => {
  const f = fixture(); try {
    let ready = true; let released = 0;
    globals[ACTOR] = { inspect: () => ({ main: true, ready }), acquire: () => { ready = false; return { ok: true }; }, release: () => { released++; ready = true; } };
    await started(f); await f.pi.command.handler(f.target, f.ctx);
    assert.equal(released, 1); assert.equal(f.pi.ledger.length, 0); assert.equal(f.didShutdown(), false);
    delete globals[ACTOR]; await f.acceptedTool(); f.saveResult(); f.idle(true);
    process.listeners("SIGTERM").at(-1)!("SIGTERM");
    await f.pi.emit("agent_settled", {}, f.ctx);
    assert.equal(f.didShutdown(), false); assert.equal(existsSync(join(f.control, "request.json")), false);
  } finally { f.cleanup(); }
});

test("durability comparison uses native JSONL representation, omitting legitimate undefined result fields", async () => {
  const f = fixture(); try {
    await started(f); await f.acceptedTool();
    f.append({ type: "message", message: { role: "toolResult", toolCallId: "switch", toolName: "restart-in-dir", content: [{ type: "text", text: "accepted" }], details: { accepted: true }, usage: undefined, structuredContent: undefined, isError: false } });
    f.idle(true); await f.pi.emit("agent_settled", {}, f.ctx);
    assert.equal(f.didShutdown(), true); assert.equal(f.request().continue, true);
  } finally { f.cleanup(); }
});

test("consumed continuation cannot be replayed after session_start or fresh extension factory reload", async () => {
  const { f, request } = await continuationFixture(); try {
    f.health(); const event = { text: MARKER + request.childId, source: "interactive" };
    assert.equal(((await f.pi.emit("input", event, f.ctx))[0] as any).action, "transform");
    await started(f);
    assert.deepEqual((await f.pi.emit("input", event, f.ctx))[0], { action: "handled" });
    f.reload(); await started(f);
    assert.deepEqual((await f.pi.emit("input", event, f.ctx))[0], { action: "handled" });
    assert.match(f.notices.at(-1)!, /already consumed in this launcher child/);
  } finally { f.cleanup(); }
});

test("failed restoration consumes handoff across reload, while genuinely fresh child can consume its own handoff", async () => {
  const { f, request } = await continuationFixture(); try {
    const event = { text: MARKER + request.childId, source: "interactive" };
    // Missing health refuses before transform but still creates the durable consumption receipt.
    assert.deepEqual((await f.pi.emit("input", event, f.ctx))[0], { action: "handled" });
    f.health(); f.reload(); await started(f);
    assert.deepEqual((await f.pi.emit("input", event, f.ctx))[0], { action: "handled" });
    assert.match(f.notices.at(-1)!, /already consumed in this launcher child/);
    f.launch.childId = "fresh-replacement"; f.saveLaunch();
    process.env.PI_RESTARTABLE_CHILD_ID = f.launch.childId;
    f.reload(); await started(f);
    assert.deepEqual((await f.pi.emit("input", event, f.ctx))[0], { action: "transform", text: request.prompt, images: undefined });
  } finally { f.cleanup(); }
});

test("fresh recursive native handoff in same control directory uses a new child/incoming receipt", async () => {
  const { f, request: first } = await continuationFixture(); try {
    f.health();
    assert.equal(((await f.pi.emit("input", { text: MARKER + first.childId, source: "interactive" }, f.ctx))[0] as any).action, "transform");
    // A replacement process now creates a second, same-directory handoff from its native fork file.
    f.reload(); await started(f); await f.acceptedTool(f.target); f.saveResult(); f.idle(true);
    await f.pi.emit("agent_settled", {}, f.ctx);
    const second = f.request(); assert.equal(second.childId, "new-child");
    assert.notEqual(second.source, first.source); assert.equal(second.target, second.sourceCwd);
    f.restore(second, true);
    f.launch.childId = "third-child"; f.saveLaunch(); process.env.PI_RESTARTABLE_CHILD_ID = f.launch.childId;
    f.reload(); await started(f);
    assert.deepEqual((await f.pi.emit("input", { text: MARKER + second.childId, source: "interactive" }, f.ctx))[0], { action: "transform", text: second.prompt, images: undefined });
    f.reload(); await started(f);
    assert.deepEqual((await f.pi.emit("input", { text: MARKER + second.childId, source: "interactive" }, f.ctx))[0], { action: "handled" });
  } finally { f.cleanup(); }
});

test("shared-process actor child cannot consume main's handoff; main can then consume once", async () => {
  const { f, request } = await continuationFixture(); try {
    f.health();
    globals[LOOKUP] = (id: string) => id === "actor-child" ? "worker" : "main";
    globals[ACTOR] = { inspect: (id: string) => ({ main: id !== "actor-child", ready: true }), acquire: () => ({ ok: true }), release: () => {} };
    const child = { ...f.ctx, sessionManager: { ...f.ctx.sessionManager, getSessionId: () => "actor-child" } };
    const event = { text: MARKER + request.childId, source: "interactive" };
    assert.deepEqual((await f.pi.emit("input", event, child))[0], { action: "handled" });
    assert.match(f.notices.at(-1)!, /Only the main agent/);
    assert.equal(readdirSync(f.control).some((entry) => entry.startsWith("consumed.")), false);
    assert.deepEqual((await f.pi.emit("input", event, f.ctx))[0], { action: "transform", text: request.prompt, images: undefined });
    assert.equal(readdirSync(f.control).filter((entry) => entry.startsWith("consumed.")).length, 1);
  } finally { f.cleanup(); }
});

const blockedRc = (f: ReturnType<typeof fixture>) => ({ path: join(f.root, ".envrc"), fingerprint: "a".repeat(64) });
const deferred = <T,>() => { let resolve!: (value: T) => void; const promise = new Promise<T>((done) => { resolve = done; }); return { promise, resolve }; };

test("only blocked direnv prompts; none, unavailable, allowed and explicitly denied retain normal launch behavior", async () => {
  for (const state of ["none", "unavailable", "allowed", "denied"]) {
    const f = fixture(); try {
      f.status({ state, rc: ["none", "unavailable"].includes(state) ? null : blockedRc(f) });
      await f.pi.command.handler(f.target, f.ctx);
      assert.equal(f.didShutdown(), true); assert.equal(f.dialogs.length, 0);
      assert.deepEqual(f.approvalRequests.map((request) => request.action), ["status"]);
      assert.equal(f.approvalRequests[0].rc, null);
    } finally { f.cleanup(); }
  }
});

test("blocked direnv uses safe first Cancel option and exact ancestor rc; cancel/dismiss/boolean never authorize", async () => {
  for (const choice of ["Cancel", undefined, true]) {
    const f = fixture(); try {
      let released = 0;
      globals[ACTOR] = { inspect: () => ({ main: true, ready: true }), acquire: () => ({ ok: true }), release: () => { released++; } };
      const rc = blockedRc(f); f.status({ state: "blocked", rc });
      f.selectDialog(async () => choice as any);
      await f.pi.command.handler(f.target, f.ctx);
      assert.equal(released, 1); assert.equal(f.didShutdown(), false); assert.deepEqual(f.pi.ledger, []);
      assert.equal(f.approvalRequests.length, 1);
      assert.equal(f.notices.at(-1), "Restart cancelled; Pi remains here."); assert.equal(f.noticeLevels.at(-1), "info");
      assert.doesNotMatch(f.notices.at(-1)!, /Restart refused|Manual recovery/);
      assert.deepEqual(f.dialogs[0].options, ["Cancel", "Allow and restart"]);
      assert.ok(f.dialogs[0].title.includes(rc.path)); assert.ok(f.dialogs[0].title.includes(f.target));
      assert.match(f.dialogs[0].title, /next restart executes project code/);
      assert.equal(f.dialogs[0].opts.timeout, undefined); assert.ok(f.dialogs[0].opts.signal instanceof AbortSignal);
      assert.equal(existsSync(join(f.control, "request.json")), false);
      assert.equal((await f.pi.emit("tool_call", { toolName: "write", toolCallId: "usable", input: {} }, f.ctx))[0], undefined);
    } finally { f.cleanup(); }
  }
});

test("explicit user Allow and restart sends exact rc witness before checkpoint; tool remains staged until durable result", async () => {
  const f = fixture(); try {
    const rc = blockedRc(f); f.status({ state: "blocked", rc }); f.selectDialog(async () => "Allow and restart");
    const result = await f.acceptedTool(); assert.equal(result.terminate, true);
    assert.deepEqual(f.pi.ledger, []); assert.equal(f.didShutdown(), false);
    assert.deepEqual(f.approvalRequests.map((request) => request.action), ["status", "allow"]);
    assert.deepEqual(f.approvalRequests[1].rc, rc);
    assert.equal(f.approvalRequests[1].target, f.target); assert.equal(f.approvalRequests[1].childId, f.launch.childId);
    assert.match(f.approvalRequests[1].requestId, /^[a-f0-9]{32}$/);
    f.saveResult(); f.idle(true); await f.pi.emit("agent_settled", {}, f.ctx);
    assert.equal(f.didShutdown(), true);
  } finally { f.cleanup(); }
});

test("pending approval serializes preparations and ignores premature settled events without releasing its lease", async () => {
  const f = fixture(); try {
    let released = 0;
    globals[ACTOR] = { inspect: () => ({ main: true, ready: true }), acquire: () => ({ ok: true }), release: () => { released++; } };
    f.status({ state: "blocked", rc: blockedRc(f) });
    const shown = deferred<void>(); const choice = deferred<string | undefined>();
    f.selectDialog(async () => { shown.resolve(); return choice.promise; });
    const pending = f.pi.command.handler(f.target, f.ctx); await shown.promise;
    await f.pi.emit("agent_settled", {}, f.ctx);
    await f.pi.command.handler(f.cwd, f.ctx);
    await assert.rejects(f.pi.tool.execute("other", { directory: f.cwd }, undefined, undefined, f.ctx), /awaiting approval/);
    assert.equal(released, 0); assert.deepEqual(f.pi.ledger, []); assert.equal(f.didShutdown(), false);
    assert.equal(f.approvalRequests.length, 1);
    choice.resolve("Cancel"); await pending;
    assert.equal(released, 1); assert.deepEqual(f.pi.ledger, []);
  } finally { f.cleanup(); }
});

test("every UI await revalidates readiness, branch, source, actor and launcher before publishing allow", async () => {
  for (const change of [
    (f: ReturnType<typeof fixture>) => f.pending(true),
    (f: ReturnType<typeof fixture>) => f.append({ type: "custom", customType: "branch-change", data: {} }),
    (f: ReturnType<typeof fixture>) => f.sourceFile(join(f.root, "missing.jsonl")),
    (f: ReturnType<typeof fixture>) => { f.launch.childId = "changed-child"; f.saveLaunch(); },
    (f: ReturnType<typeof fixture>) => { globals[LOOKUP] = () => "worker"; },
    (f: ReturnType<typeof fixture>) => { globals[ACTOR] = { inspect: () => ({ main: true, ready: false }), acquire: () => ({ ok: true }), release: () => {} }; },
  ]) {
    const f = fixture(); try {
      f.status({ state: "blocked", rc: blockedRc(f) });
      f.selectDialog(async () => { change(f); return "Allow and restart"; });
      await f.pi.command.handler(f.target, f.ctx);
      assert.equal(f.approvalRequests.length, 1); assert.deepEqual(f.pi.ledger, []); assert.equal(f.didShutdown(), false);
      assert.match(f.notices.at(-1)!, /Restart refused/);
    } finally { f.cleanup(); }
  }
});

test("tool abort and shutdown signal dismiss approval without allow, checkpoint or restart", async () => {
  for (const useSignal of [false, true]) {
    const f = fixture(); try {
      await started(f); f.status({ state: "blocked", rc: blockedRc(f) }); f.toolBatch(); f.idle(false);
      const shown = deferred<void>(); const controller = new AbortController();
      f.selectDialog(({ opts }) => new Promise((resolve) => { shown.resolve(); opts.signal.addEventListener("abort", () => resolve(undefined), { once: true }); }));
      const result = f.pi.tool.execute("switch", { directory: f.target }, controller.signal, undefined, f.ctx);
      const rejected = assert.rejects(result, /Restart refused/); await shown.promise;
      if (useSignal) process.listeners("SIGTERM").at(-1)!("SIGTERM"); else controller.abort();
      await rejected;
      assert.equal(f.approvalRequests.length, 1); assert.deepEqual(f.pi.ledger, []); assert.equal(f.didShutdown(), false);
      assert.equal((await f.pi.emit("tool_call", { toolName: "write", toolCallId: "usable", input: {} }, f.ctx))[0], undefined);
    } finally { f.cleanup(); }
  }
});

test("status await readiness races never show approval; allow refusal or changed witness never checkpoints", async () => {
  for (const kind of ["status-race", "allow-error", "allow-denied", "allow-changed", "allow-race"]) {
    const f = fixture(); try {
      const rc = blockedRc(f); f.selectDialog(async () => "Allow and restart");
      f.approvalHandler((request) => {
        if (request.action === "status") {
          if (kind === "status-race") f.pending(true);
          return { ok: true, status: { state: "blocked", rc } };
        }
        if (kind === "allow-error") return { ok: false, error: "direnv rc changed; fresh approval required" };
        if (kind === "allow-race") f.pending(true);
        return { ok: true, status: { state: kind === "allow-denied" ? "denied" : "allowed", rc: kind === "allow-changed" ? { ...rc, fingerprint: "b".repeat(64) } : rc } };
      });
      await f.pi.command.handler(f.target, f.ctx);
      assert.deepEqual(f.pi.ledger, []); assert.equal(f.didShutdown(), false);
      assert.equal(f.dialogs.length, kind === "status-race" ? 0 : 1);
      assert.match(f.notices.at(-1)!, /Restart refused/);
    } finally { f.cleanup(); }
  }
});

test("old launcher v1 fails helpfully before IPC or checkpoint", async () => {
  const f = fixture(); try {
    f.launch.version = 1; f.saveLaunch(); await f.pi.command.handler(f.target, f.ctx);
    assert.equal(f.approvalRequests.length, 0); assert.deepEqual(f.pi.ledger, []);
    assert.match(f.notices.at(-1)!, /predates direnv approval support.*relaunch/);
  } finally { f.cleanup(); }
});

test("tool abort after accepted result but before settled cancels without checkpointing or shutdown", async () => {
  const f = fixture(); try {
    let released = 0;
    globals[ACTOR] = { inspect: () => ({ main: true, ready: true }), acquire: () => ({ ok: true }), release: () => { released++; } };
    const rc = blockedRc(f); f.status({ state: "blocked", rc }); f.selectDialog(async () => "Allow and restart");
    f.toolBatch(); f.idle(false); const controller = new AbortController();
    const result = await f.pi.tool.execute("switch", { directory: f.target }, controller.signal, undefined, f.ctx);
    assert.equal(result.terminate, true); assert.equal(f.approvalRequests[1].action, "allow");
    controller.abort();
    await f.pi.emit("tool_result", { toolCallId: "switch", isError: false }, f.ctx);
    f.saveResult(); f.idle(true); await f.pi.emit("agent_settled", {}, f.ctx);
    assert.equal(f.didShutdown(), false); assert.deepEqual(f.pi.ledger, ["result_saved"]); assert.equal(released, 1);
    assert.equal(existsSync(join(f.control, "request.json")), false);
    assert.equal((await f.pi.emit("tool_call", { toolName: "write", toolCallId: "usable", input: {} }, f.ctx))[0], undefined);
  } finally { f.cleanup(); }
});

test("consent escapes path terminal controls rather than rendering spoofed path text", async () => {
  const f = fixture(); try {
    const rc = { path: join(f.root, "ancestor\n\x1b[31m.envrc"), fingerprint: "a".repeat(64) };
    f.status({ state: "blocked", rc }); await f.pi.command.handler(f.target, f.ctx);
    assert.ok(f.dialogs[0].title.includes(JSON.stringify(rc.path)));
    assert.equal(f.dialogs[0].title.includes("\x1b"), false);
    assert.equal(f.approvalRequests.length, 1); assert.deepEqual(f.pi.ledger, []);
  } finally { f.cleanup(); }
});

test("deliberate tool approval cancellation is informational UI and a cancelled tool error", async () => {
  const f = fixture(); try {
    f.status({ state: "blocked", rc: blockedRc(f) }); f.toolBatch(); f.idle(false);
    await assert.rejects(f.pi.tool.execute("switch", { directory: f.target }, undefined, undefined, f.ctx), /^Error: Restart cancelled:.*cancelled by user/);
    assert.equal(f.notices.at(-1), "Restart cancelled; Pi remains here."); assert.equal(f.noticeLevels.at(-1), "info");
    assert.equal(f.approvalRequests.length, 1); assert.deepEqual(f.pi.ledger, []); assert.equal(f.didShutdown(), false);
  } finally { f.cleanup(); }
});
