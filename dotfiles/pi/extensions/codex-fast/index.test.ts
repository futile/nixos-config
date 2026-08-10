import assert from "node:assert/strict";
import { test } from "node:test";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import codexFast from "./index.ts";
import { getFastController } from "./fast-control.ts";

type Handler = (event: any, ctx: ExtensionContext) => unknown;

class FakePi {
  readonly handlers = new Map<string, Handler[]>();
  command: { handler: (args: string, ctx: ExtensionContext) => Promise<void> | void } | undefined;

  on(name: string, handler: Handler): void {
    const handlers = this.handlers.get(name) ?? [];
    handlers.push(handler);
    this.handlers.set(name, handlers);
  }

  registerCommand(name: string, command: typeof this.command): void {
    assert.equal(name, "fast");
    this.command = command;
  }

  async emit(name: string, event: any, ctx: ExtensionContext): Promise<unknown[]> {
    const results: unknown[] = [];
    for (const handler of this.handlers.get(name) ?? []) results.push(await handler(event, ctx));
    return results;
  }
}

function fakeContext(
  sessionId: string,
  model: { provider: string; id: string } | undefined = { provider: "openai-codex", id: "gpt-5.6-sol" },
  hasUI = true,
) {
  const statuses: Array<[string, string | undefined]> = [];
  const notifications: Array<[string, string | undefined]> = [];
  const ctx = {
    hasUI,
    mode: hasUI ? "tui" : "print",
    model,
    sessionManager: { getSessionId: () => sessionId },
    ui: {
      setStatus: (key: string, value: string | undefined) => statuses.push([key, value]),
      notify: (message: string, level?: string) => notifications.push([message, level]),
    },
  } as unknown as ExtensionContext;
  return { ctx, statuses, notifications };
}

function load(): FakePi {
  const pi = new FakePi();
  codexFast(pi as unknown as ExtensionAPI);
  return pi;
}

test("sessions keep independent live Fast state and rewrite their next request", async () => {
  const first = load();
  const second = load();
  const one = fakeContext("session-one");
  const two = fakeContext("session-two");
  await first.emit("session_start", { type: "session_start", reason: "startup" }, one.ctx);
  await second.emit("session_start", { type: "session_start", reason: "startup" }, two.ctx);

  assert.equal(getFastController("session-one")?.setDesired(true).effective, true);
  assert.equal(getFastController("session-two")?.getState().desired, false);

  const payload = { input: [], reasoning: { effort: "high" }, verbosity: "medium" };
  assert.deepEqual((await first.emit("before_provider_request", { type: "before_provider_request", payload }, one.ctx))[0], {
    ...payload,
    service_tier: "priority",
  });
  assert.equal((await second.emit("before_provider_request", { type: "before_provider_request", payload }, two.ctx))[0], undefined);
  assert.deepEqual(one.statuses.at(-1), ["fast", "fast"]);
  assert.deepEqual(two.statuses.at(-1), ["fast", undefined]);

  await first.emit("session_shutdown", { type: "session_shutdown", reason: "quit" }, one.ctx);
  await second.emit("session_shutdown", { type: "session_shutdown", reason: "quit" }, two.ctx);
});

test("desired state can remain on while model changes make Fast ineffective", async () => {
  const pi = load();
  const session = fakeContext("session-model");
  await pi.emit("session_start", { type: "session_start", reason: "startup" }, session.ctx);
  getFastController("session-model")?.setDesired(true);

  const unsupported = fakeContext("session-model", { provider: "anthropic", id: "claude-opus-4-6" });
  await pi.emit(
    "model_select",
    { type: "model_select", model: unsupported.ctx.model, previousModel: session.ctx.model, source: "set" },
    unsupported.ctx,
  );
  assert.deepEqual(getFastController("session-model")?.getState(), {
    desired: true,
    effective: false,
    model: { provider: "anthropic", id: "claude-opus-4-6" },
  });
  assert.deepEqual(unsupported.statuses.at(-1), ["fast", undefined]);

  const payload = { input: [] };
  assert.equal(
    (await pi.emit("before_provider_request", { type: "before_provider_request", payload }, unsupported.ctx))[0],
    undefined,
  );
  await pi.emit("session_shutdown", { type: "session_shutdown", reason: "quit" }, unsupported.ctx);
});

test("bare /fast and explicit /fast toggle invert only the current session", async () => {
  const pi = load();
  const session = fakeContext("session-toggle");
  await pi.emit("session_start", { type: "session_start", reason: "startup" }, session.ctx);

  for (const action of ["", "toggle", "", "toggle"]) {
    const before = getFastController("session-toggle")?.getState().desired;
    await pi.command?.handler(action, session.ctx);
    const after = getFastController("session-toggle")?.getState();
    assert.equal(after?.desired, !before, `${JSON.stringify(action)} should toggle desired state`);
    assert.equal(after?.effective, !before);
    assert.match(session.notifications.at(-1)?.[0] ?? "", /changes apply to the next provider request/i);
  }

  await pi.command?.handler("status", session.ctx);
  assert.equal(getFastController("session-toggle")?.getState().desired, false, "status must not toggle");
  await pi.emit("session_shutdown", { type: "session_shutdown", reason: "quit" }, session.ctx);
});

test("/fast controls only its session and reports unsupported desired state", async () => {
  const pi = load();
  const session = fakeContext("session-command", { provider: "openai", id: "gpt-5.6-sol" });
  await pi.emit("session_start", { type: "session_start", reason: "startup" }, session.ctx);

  await pi.command?.handler("on", session.ctx);
  assert.equal(getFastController("session-command")?.getState().desired, true);
  assert.match(session.notifications.at(-1)?.[0] ?? "", /desired on.*effective off.*unsupported/i);

  await pi.command?.handler("status", session.ctx);
  assert.match(session.notifications.at(-1)?.[0] ?? "", /desired on.*effective off/i);
  await pi.command?.handler("off", session.ctx);
  assert.equal(getFastController("session-command")?.getState().desired, false);
  assert.equal(session.notifications.at(-1)?.[1], "info", "turning Fast off is not a warning");
  await pi.command?.handler("invalid", session.ctx);
  assert.match(session.notifications.at(-1)?.[0] ?? "", /usage: \/fast \[toggle\|on\|off\|status\]/i);

  await pi.emit("session_shutdown", { type: "session_shutdown", reason: "quit" }, session.ctx);
});

test("headless sessions never call UI and shutdown cannot unregister a replacement", async () => {
  const oldPi = load();
  const replacementPi = load();
  const old = fakeContext("session-reload", undefined, false);
  const replacement = fakeContext("session-reload", undefined, false);
  await oldPi.emit("session_start", { type: "session_start", reason: "startup" }, old.ctx);
  const oldController = getFastController("session-reload");
  await replacementPi.emit("session_start", { type: "session_start", reason: "reload" }, replacement.ctx);
  const replacementController = getFastController("session-reload");
  assert.notEqual(oldController, replacementController);

  await oldPi.emit("session_shutdown", { type: "session_shutdown", reason: "reload" }, old.ctx);
  assert.equal(getFastController("session-reload"), replacementController);
  assert.deepEqual(old.statuses, []);
  assert.deepEqual(replacement.statuses, []);

  await replacementPi.emit("session_shutdown", { type: "session_shutdown", reason: "quit" }, replacement.ctx);
  assert.equal(getFastController("session-reload"), undefined);
});

test("stale interactive shutdown cannot clear a replacement runtime's Fast status", async () => {
  const oldPi = load();
  const replacementPi = load();
  const old = fakeContext("session-ui-reload");
  const replacement = fakeContext("session-ui-reload");
  await oldPi.emit("session_start", { type: "session_start", reason: "startup" }, old.ctx);
  getFastController("session-ui-reload")?.setDesired(true);
  assert.deepEqual(old.statuses.at(-1), ["fast", "fast"]);

  await replacementPi.emit("session_start", { type: "session_start", reason: "reload" }, replacement.ctx);
  const replacementController = getFastController("session-ui-reload");
  replacementController?.setDesired(true);
  assert.deepEqual(replacement.statuses.at(-1), ["fast", "fast"]);

  const oldStatusCount = old.statuses.length;
  await oldPi.emit("session_shutdown", { type: "session_shutdown", reason: "reload" }, old.ctx);
  assert.equal(getFastController("session-ui-reload"), replacementController);
  assert.equal(old.statuses.length, oldStatusCount, "stale shutdown must not emit a status clear");
  assert.deepEqual(replacement.statuses.at(-1), ["fast", "fast"]);

  await replacementPi.emit("session_shutdown", { type: "session_shutdown", reason: "quit" }, replacement.ctx);
  assert.equal(getFastController("session-ui-reload"), undefined);
  assert.deepEqual(replacement.statuses.at(-1), ["fast", undefined]);
});

test("a fresh session with a reused id starts with Fast off", async () => {
  const first = load();
  const firstContext = fakeContext("session-fresh");
  await first.emit("session_start", { type: "session_start", reason: "startup" }, firstContext.ctx);
  getFastController("session-fresh")?.setDesired(true);
  await first.emit("session_shutdown", { type: "session_shutdown", reason: "quit" }, firstContext.ctx);

  const second = load();
  const secondContext = fakeContext("session-fresh");
  await second.emit("session_start", { type: "session_start", reason: "startup" }, secondContext.ctx);
  assert.deepEqual(getFastController("session-fresh")?.getState(), {
    desired: false,
    effective: false,
    model: { provider: "openai-codex", id: "gpt-5.6-sol" },
  });
  await second.emit("session_shutdown", { type: "session_shutdown", reason: "quit" }, secondContext.ctx);
});
