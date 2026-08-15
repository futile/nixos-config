import assert from "node:assert/strict";
import { test } from "node:test";
import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import contextPressure from "./index.ts";

type Handler = (event: any, ctx: ExtensionContext) => unknown;

class FakePi {
  readonly handlers = new Map<string, Handler[]>();
  readonly commands = new Map<
    string,
    { handler: (args: string, ctx: ExtensionContext) => Promise<void> }
  >();
  readonly sent: any[] = [];
  readonly entries: any[] = [];
  readonly order: string[] = [];

  on(name: string, handler: Handler): void {
    this.handlers.set(name, [...(this.handlers.get(name) ?? []), handler]);
  }

  appendEntry(customType: string, data: unknown): void {
    this.order.push("appendEntry");
    this.entries.push({ type: "custom", customType, data });
  }

  sendMessage(message: unknown, options: unknown): void {
    this.order.push("sendMessage");
    this.sent.push({ message, options });
  }

  registerCommand(
    name: string,
    command: {
      handler: (args: string, ctx: ExtensionContext) => Promise<void>;
    },
  ): void {
    this.commands.set(name, command);
  }

  async emit(name: string, event: any, ctx: ExtensionContext): Promise<void> {
    for (const handler of this.handlers.get(name) ?? [])
      await handler(event, ctx);
  }
}

function fakeContext(
  hasUI = true,
  branch: any[] = [],
  contextWindow = 100_000,
  sessionId = "test",
  sessionName?: string,
) {
  let contextUsage: any = {
    tokens: 10_000,
    contextWindow,
    percent: (10_000 / contextWindow) * 100,
  };
  const notifications: any[] = [];
  const ctx = {
    hasUI,
    mode: hasUI ? "tui" : "print",
    getContextUsage: () => contextUsage,
    sessionManager: {
      getBranch: () => branch,
      getSessionId: () => sessionId,
      getSessionName: () => sessionName,
    },
    ui: {
      notify: (message: string, level?: string) =>
        notifications.push({ message, level }),
    },
  } as unknown as ExtensionContext;
  return {
    ctx,
    notifications,
    setUsage(tokens: number, percent = (tokens / contextWindow) * 100) {
      contextUsage = { tokens, contextWindow, percent };
    },
    setRawUsage(usage: unknown) {
      contextUsage = usage;
    },
  };
}

const turn = {
  type: "turn_end",
  message: { stopReason: "toolUse" },
  toolResults: [{ toolName: "read" }],
};

test("context-status reports branch-local stats for main and live children", async () => {
  const mainBranch = [
    {
      type: "custom_message",
      customType: "context-pressure/reminder",
      details: { kind: "advisory", percent: 62 },
    },
    {
      type: "custom_message",
      customType: "context-pressure/reminder",
      details: { kind: "urgent", percent: 81 },
    },
    {
      type: "message",
      message: {
        role: "toolResult",
        toolName: "context_collapse",
        details: { action: "collapse", ok: true, deltaTokens: 12_000 },
      },
    },
    {
      type: "message",
      message: {
        role: "toolResult",
        toolName: "context_collapse",
        details: { action: "collapse", ok: false, deltaTokens: 0 },
      },
    },
  ];
  const mainPi = new FakePi();
  contextPressure(mainPi as unknown as ExtensionAPI);
  const main = fakeContext(true, mainBranch, 100_000, "main-id", "renamed");
  main.setUsage(72_000);
  await mainPi.emit(
    "session_start",
    { type: "session_start", reason: "startup" },
    main.ctx,
  );

  const childPi = new FakePi();
  contextPressure(childPi as unknown as ExtensionAPI);
  const child = fakeContext(false, [], 200_000, "child-id", "scan");
  child.setUsage(126_000);
  await childPi.emit(
    "session_start",
    { type: "session_start", reason: "startup" },
    child.ctx,
  );

  main.setUsage(60_000);
  await mainPi.commands.get("context-status")?.handler("", main.ctx);
  assert.equal(main.notifications.length, 1);
  assert.match(main.notifications[0].message, /2 live/);
  assert.match(
    main.notifications[0].message,
    /main · ctx 60% · HWM 72% · headroom 40k · reminders 2 \(A1 U1\) · last U@81% · folds 1\/2, 12k saved/,
  );
  assert.match(
    main.notifications[0].message,
    /scan · ctx 63% · HWM 63% · headroom 74k · reminders 0 · folds 0/,
  );

  await childPi.emit(
    "session_shutdown",
    { type: "session_shutdown", reason: "quit" },
    child.ctx,
  );
  await mainPi.commands.get("context-status")?.handler("", main.ctx);
  assert.match(main.notifications[1].message, /1 live/);
  assert.doesNotMatch(main.notifications[1].message, /scan/);

  await mainPi.emit(
    "session_shutdown",
    { type: "session_shutdown", reason: "quit" },
    main.ctx,
  );
});

test("sends a steer only on a continuing tool loop", async () => {
  const pi = new FakePi();
  contextPressure(pi as unknown as ExtensionAPI);
  const session = fakeContext();
  await pi.emit(
    "session_start",
    { type: "session_start", reason: "startup" },
    session.ctx,
  );
  await pi.emit("agent_start", { type: "agent_start" }, session.ctx);
  session.setUsage(50_000);
  await pi.emit("turn_end", turn, session.ctx);
  session.setUsage(70_000);
  await pi.emit("turn_end", turn, session.ctx);
  assert.equal(pi.sent.length, 1);
  assert.equal(pi.sent[0].message.display, true);
  assert.equal(pi.sent[0].options.deliverAs, "steer");
  assert.equal(pi.sent[0].options.triggerTurn, undefined);

  await pi.emit("agent_settled", { type: "agent_settled" }, session.ctx);
  session.setUsage(90_000);
  await pi.emit(
    "turn_end",
    { ...turn, message: { stopReason: "stop" } },
    session.ctx,
  );
  assert.equal(pi.sent.length, 1, "final turns must not trigger maintenance");
});

test("reminder steer is queued before its durable snapshot", async () => {
  const pi = new FakePi();
  contextPressure(pi as unknown as ExtensionAPI);
  const session = fakeContext(false);
  await pi.emit(
    "session_start",
    { type: "session_start", reason: "startup" },
    session.ctx,
  );
  await pi.emit("agent_start", { type: "agent_start" }, session.ctx);
  session.setUsage(50_000);
  await pi.emit("turn_end", turn, session.ctx);
  session.setUsage(70_000);
  await pi.emit("turn_end", turn, session.ctx);
  assert.deepEqual(pi.order.slice(-2), ["sendMessage", "appendEntry"]);
});

test("critical guidance is child-safe and only foreground sessions notify", async () => {
  for (const hasUI of [true, false]) {
    const pi = new FakePi();
    contextPressure(pi as unknown as ExtensionAPI);
    const session = fakeContext(hasUI);
    await pi.emit(
      "session_start",
      { type: "session_start", reason: "startup" },
      session.ctx,
    );
    await pi.emit("agent_start", { type: "agent_start" }, session.ctx);
    session.setUsage(50_000);
    await pi.emit("turn_end", turn, session.ctx);
    session.setUsage(76_000);
    await pi.emit("turn_end", turn, session.ctx);
    assert.match(pi.sent.at(-1)?.message.content ?? "", /send_message main/);
    assert.doesNotMatch(
      pi.sent.at(-1)?.message.content ?? "",
      /recommend a fresh session/i,
    );
    assert.equal(session.notifications.length, hasUI ? 1 : 0);
  }
});

test("branch-local state snapshots restore the broader-pass handoff latch", async () => {
  const pi = new FakePi();
  contextPressure(pi as unknown as ExtensionAPI);
  const branch = [
    {
      type: "custom",
      customType: "context-pressure/state",
      data: {
        version: 1,
        yields: [
          {
            ok: true,
            deltaTokens: 1_000,
            contextWindow: 1_000_000,
            percentagePoints: 0.1,
            timestamp: 1,
            broader: true,
          },
        ],
        latches: {},
        broaderPassPending: false,
        handoffCandidate: true,
        handoffSent: false,
      },
    },
  ];
  const session = fakeContext(false, branch, 1_000_000);
  await pi.emit(
    "session_start",
    { type: "session_start", reason: "resume" },
    session.ctx,
  );
  await pi.emit("agent_start", { type: "agent_start" }, session.ctx);
  session.setUsage(800_000);
  await pi.emit("turn_end", turn, session.ctx);
  session.setUsage(810_000, 81);
  await pi.emit("turn_end", turn, session.ctx);
  assert.match(
    pi.sent[0]?.message.content ?? "",
    /reported broader pass|broader pass/i,
  );
  assert.equal(
    pi.sent.length,
    1,
    "handoff must latch critical pressure for the current crossing",
  );
});

test("a pending broader phase restores across restart and is consumed by the next collapse", async () => {
  const branch = [
    {
      type: "custom",
      customType: "context-pressure/state",
      data: {
        version: 1,
        yields: [],
        latches: {},
        broaderPassPending: true,
        handoffCandidate: false,
        handoffSent: false,
      },
    },
  ];
  const pi = new FakePi();
  contextPressure(pi as unknown as ExtensionAPI);
  const session = fakeContext(false, branch, 1_000_000);
  await pi.emit(
    "session_start",
    { type: "session_start", reason: "resume" },
    session.ctx,
  );
  const entriesAfterStart = pi.entries.length;
  await pi.emit(
    "tool_result",
    {
      type: "tool_result",
      toolName: "context_collapse",
      details: { action: "collapse", ok: false, deltaTokens: 0 },
    },
    session.ctx,
  );
  assert.equal(pi.entries.length, entriesAfterStart + 1);
  const latest = pi.entries.at(-1);
  assert.equal(latest.customType, "context-pressure/state");
  assert.equal(latest.data.yields.at(-1).broader, true);
  assert.equal(latest.data.broaderPassPending, false);
});

test("settled preserves an unacted broader phase", async () => {
  const branch = [
    {
      type: "custom",
      customType: "context-pressure/state",
      data: {
        version: 1,
        yields: [],
        latches: {},
        broaderPassPending: true,
        handoffCandidate: false,
        handoffSent: false,
      },
    },
  ];
  const pi = new FakePi();
  contextPressure(pi as unknown as ExtensionAPI);
  const session = fakeContext(false, branch, 1_000_000);
  await pi.emit(
    "session_start",
    { type: "session_start", reason: "resume" },
    session.ctx,
  );
  const entriesAfterStart = pi.entries.length;
  await pi.emit("agent_settled", { type: "agent_settled" }, session.ctx);
  assert.equal(pi.entries.length, entriesAfterStart);
});

test("restored ordinary latches stay quiet while urgent and critical remain pending", async () => {
  const cases = [
    {
      name: "advisory",
      percent: 64,
      tokens: 640_000,
      contextWindow: 1_000_000,
    },
    { name: "firm", percent: 76, tokens: 760_000, contextWindow: 1_000_000 },
    { name: "urgent", percent: 81, tokens: 810_000, contextWindow: 1_000_000 },
    {
      name: "critical",
      percent: 98,
      tokens: 980_000,
      contextWindow: 1_000_000,
    },
  ];
  for (const current of cases) {
    const source = new FakePi();
    contextPressure(source as unknown as ExtensionAPI);
    const sourceSession = fakeContext(false, [], current.contextWindow);
    await source.emit(
      "session_start",
      { type: "session_start", reason: "startup" },
      sourceSession.ctx,
    );
    await source.emit(
      "agent_start",
      { type: "agent_start" },
      sourceSession.ctx,
    );
    sourceSession.setUsage(current.tokens, current.percent);
    await source.emit("turn_end", turn, sourceSession.ctx);
    await source.emit("turn_end", turn, sourceSession.ctx);
    const repeats = current.name === "urgent" || current.name === "critical";
    assert.equal(
      source.sent.length,
      repeats ? 2 : 1,
      `${current.name} pending behavior`,
    );

    const restored = new FakePi();
    contextPressure(restored as unknown as ExtensionAPI);
    const restoredSession = fakeContext(
      false,
      source.entries,
      current.contextWindow,
    );
    restoredSession.setUsage(current.tokens, current.percent);
    await restored.emit(
      "session_start",
      { type: "session_start", reason: "resume" },
      restoredSession.ctx,
    );
    await restored.emit(
      "agent_start",
      { type: "agent_start" },
      restoredSession.ctx,
    );
    restoredSession.setUsage(current.tokens, current.percent);
    await restored.emit("turn_end", turn, restoredSession.ctx);
    await restored.emit("turn_end", turn, restoredSession.ctx);
    assert.equal(
      restored.sent.length,
      repeats ? 2 : 0,
      `${current.name} restore behavior`,
    );
  }
});

test("restored tiny positive fold retains urgent latch and restored handoff stays quiet", async () => {
  const tiny = new FakePi();
  contextPressure(tiny as unknown as ExtensionAPI);
  const tinySession = fakeContext(false, [], 1_000_000);
  await tiny.emit(
    "session_start",
    { type: "session_start", reason: "startup" },
    tinySession.ctx,
  );
  await tiny.emit("agent_start", { type: "agent_start" }, tinySession.ctx);
  tinySession.setUsage(810_000, 81);
  await tiny.emit("turn_end", turn, tinySession.ctx);
  await tiny.emit("turn_end", turn, tinySession.ctx);
  const tinySample = { action: "collapse", ok: true, deltaTokens: 10_000 };
  await tiny.emit(
    "tool_result",
    { type: "tool_result", toolName: "context_collapse", details: tinySample },
    tinySession.ctx,
  );
  const restoredTiny = new FakePi();
  contextPressure(restoredTiny as unknown as ExtensionAPI);
  const restoredTinySession = fakeContext(false, tiny.entries, 1_000_000);
  restoredTinySession.setUsage(820_000, 82);
  await restoredTiny.emit(
    "session_start",
    { type: "session_start", reason: "resume" },
    restoredTinySession.ctx,
  );
  await restoredTiny.emit(
    "agent_start",
    { type: "agent_start" },
    restoredTinySession.ctx,
  );
  restoredTinySession.setUsage(820_000, 82);
  await restoredTiny.emit("turn_end", turn, restoredTinySession.ctx);
  assert.equal(restoredTiny.sent.length, 1);
  assert.match(restoredTiny.sent[0].message.content, /retaining context because/i);

  const handoffSnapshot = {
    type: "custom",
    customType: "context-pressure/state",
    data: {
      version: 1,
      yields: [
        {
          ok: true,
          deltaTokens: 1_000,
          contextWindow: 1_000_000,
          percentagePoints: 0.1,
          timestamp: 1,
          broader: true,
        },
      ],
      latches: {
        urgent: { tokens: 810_000, contextWindow: 1_000_000, percent: 81 },
      },
      broaderPassPending: false,
      handoffCandidate: false,
      handoffSent: true,
    },
  };
  const restoredHandoff = new FakePi();
  contextPressure(restoredHandoff as unknown as ExtensionAPI);
  const handoffSession = fakeContext(false, [handoffSnapshot], 1_000_000);
  handoffSession.setUsage(820_000, 82);
  await restoredHandoff.emit(
    "session_start",
    { type: "session_start", reason: "resume" },
    handoffSession.ctx,
  );
  await restoredHandoff.emit(
    "agent_start",
    { type: "agent_start" },
    handoffSession.ctx,
  );
  handoffSession.setUsage(820_000, 82);
  await restoredHandoff.emit("turn_end", turn, handoffSession.ctx);
  assert.equal(restoredHandoff.sent.length, 0);
});

test("candidate clears below urgent and later urgent is ordinary, not handoff", async () => {
  const snapshot = {
    type: "custom",
    customType: "context-pressure/state",
    data: {
      version: 1,
      yields: [
        {
          ok: true,
          deltaTokens: 1_000,
          contextWindow: 1_000_000,
          percentagePoints: 0.1,
          timestamp: 1,
          broader: true,
        },
      ],
      latches: {},
      broaderPassPending: false,
      handoffCandidate: true,
      handoffSent: false,
    },
  };
  const pi = new FakePi();
  contextPressure(pi as unknown as ExtensionAPI);
  const session = fakeContext(false, [snapshot], 1_000_000);
  await pi.emit(
    "session_start",
    { type: "session_start", reason: "resume" },
    session.ctx,
  );
  await pi.emit("agent_start", { type: "agent_start" }, session.ctx);
  session.setUsage(790_000, 79);
  await pi.emit("turn_end", turn, session.ctx);
  session.setUsage(810_000, 81);
  await pi.emit("turn_end", turn, session.ctx);
  assert.equal(pi.sent.length, 1);
  assert.doesNotMatch(
    pi.sent[0].message.content,
    /reported broader pass|recommend a fresh session/i,
  );
});

test("malformed newest snapshot falls back to the latest valid one", async () => {
  const valid = {
    type: "custom",
    customType: "context-pressure/state",
    data: {
      version: 1,
      yields: [],
      latches: {
        urgent: { tokens: 810_000, contextWindow: 1_000_000, percent: 81 },
      },
      broaderPassPending: false,
      handoffCandidate: false,
      handoffSent: false,
    },
  };
  const malformed = {
    type: "custom",
    customType: "context-pressure/state",
    data: {
      version: 1,
      yields: [],
      latches: { bogus: {} },
      broaderPassPending: false,
      handoffCandidate: false,
      handoffSent: false,
    },
  };
  const pi = new FakePi();
  contextPressure(pi as unknown as ExtensionAPI);
  const session = fakeContext(false, [valid, malformed], 1_000_000);
  session.setUsage(810_000, 81);
  await pi.emit(
    "session_start",
    { type: "session_start", reason: "resume" },
    session.ctx,
  );
  await pi.emit("agent_start", { type: "agent_start" }, session.ctx);
  session.setUsage(810_000, 81);
  await pi.emit("turn_end", turn, session.ctx);
  assert.equal(pi.sent.length, 0);
});

test("model, compaction, and tree resets anchor the next interaction baseline", async () => {
  for (const eventName of ["model_select", "session_compact", "session_tree"]) {
    const pi = new FakePi();
    contextPressure(pi as unknown as ExtensionAPI);
    const session = fakeContext(false, [], 1_000_000);
    await pi.emit(
      "session_start",
      { type: "session_start", reason: "startup" },
      session.ctx,
    );
    await pi.emit("agent_start", { type: "agent_start" }, session.ctx);
    await pi.emit("agent_settled", { type: "agent_settled" }, session.ctx);

    await pi.emit(eventName, { type: eventName }, session.ctx);
    session.setUsage(210_000);
    await pi.emit("agent_start", { type: "agent_start" }, session.ctx);
    session.setUsage(700_000);
    await pi.emit("turn_end", turn, session.ctx);
    await pi.emit("turn_end", turn, session.ctx);

    assert.equal(
      pi.sent.length,
      1,
      `${eventName} must not lose the fresh baseline`,
    );
    assert.equal(pi.sent[0].options.triggerTurn, undefined);
  }
});

test("model selection preserves urgent pending while compaction clears it", async () => {
  for (const [eventName, expected] of [
    ["model_select", 2],
    ["session_compact", 1],
  ] as const) {
    const pi = new FakePi();
    contextPressure(pi as unknown as ExtensionAPI);
    const session = fakeContext(false, [], 1_000_000);
    await pi.emit(
      "session_start",
      { type: "session_start", reason: "startup" },
      session.ctx,
    );
    await pi.emit("agent_start", { type: "agent_start" }, session.ctx);
    session.setUsage(810_000, 81);
    await pi.emit("turn_end", turn, session.ctx);
    await pi.emit(eventName, { type: eventName }, session.ctx);
    session.setUsage(700_000, 70);
    await pi.emit("turn_end", turn, session.ctx);
    assert.equal(pi.sent.length, expected, eventName);
  }
});

test("urgent repeats through unrelated work and clears after productive maintenance", async () => {
  const pi = new FakePi();
  contextPressure(pi as unknown as ExtensionAPI);
  const session = fakeContext(false, [], 1_000_000);
  await pi.emit(
    "session_start",
    { type: "session_start", reason: "startup" },
    session.ctx,
  );
  await pi.emit("agent_start", { type: "agent_start" }, session.ctx);
  session.setUsage(810_000, 81);
  await pi.emit("turn_end", turn, session.ctx);
  await pi.emit("turn_end", turn, session.ctx);
  assert.equal(pi.sent.length, 2);
  assert.match(pi.sent[0].message.content, /STOP other work now/);
  assert.match(pi.sent[1].message.content, /remains pending/);

  await pi.commands.get("context-status")?.handler("", session.ctx);
  assert.match(session.notifications[0].message, /urgent pending/);

  await pi.emit(
    "tool_result",
    {
      type: "tool_result",
      toolName: "context_collapse",
      details: { action: "collapse", ok: true, deltaTokens: 260_000 },
    },
    session.ctx,
  );
  await pi.emit("turn_end", turn, session.ctx);
  session.setUsage(550_000, 55);
  await pi.emit("turn_end", turn, session.ctx);
  assert.equal(pi.sent.length, 2);
});

test("high residual pressure emits a retention choice and appears in context-status", async () => {
  const pi = new FakePi();
  contextPressure(pi as unknown as ExtensionAPI);
  const session = fakeContext(false, [], 1_000_000);
  await pi.emit(
    "session_start",
    { type: "session_start", reason: "startup" },
    session.ctx,
  );
  await pi.emit("agent_start", { type: "agent_start" }, session.ctx);
  session.setUsage(810_000, 81);
  await pi.emit("turn_end", turn, session.ctx);
  await pi.emit(
    "tool_result",
    {
      type: "tool_result",
      toolName: "context_collapse",
      details: { action: "collapse", ok: true, deltaTokens: 200_000 },
    },
    session.ctx,
  );
  await pi.emit("turn_end", turn, session.ctx);
  session.setUsage(650_000, 65);
  await pi.emit("turn_end", turn, session.ctx);
  assert.equal(pi.sent.at(-1)?.message.details.kind, "retention");
  assert.match(pi.sent.at(-1)?.message.content ?? "", /specific indispensable working set/);
  assert.match(pi.sent.at(-1)?.message.content ?? "", /child agents send_message main/);

  await pi.commands.get("context-status")?.handler("", session.ctx);
  assert.match(session.notifications[0].message, /post-fold 65% high/);
  assert.doesNotMatch(session.notifications[0].message, /urgent pending/);
});

test("invalid context windows skip persistence and warn only once", async () => {
  const pi = new FakePi();
  contextPressure(pi as unknown as ExtensionAPI);
  const session = fakeContext(false);
  await pi.emit(
    "session_start",
    { type: "session_start", reason: "startup" },
    session.ctx,
  );
  const entriesAfterStart = pi.entries.length;
  const originalWarn = console.warn;
  const warnings: unknown[][] = [];
  console.warn = (...args: unknown[]) => warnings.push(args);
  try {
    for (const contextWindow of [
      undefined,
      0,
      -1,
      Number.NaN,
      Number.POSITIVE_INFINITY,
    ]) {
      session.setRawUsage({ tokens: 20_000, contextWindow, percent: null });
      await pi.emit(
        "tool_result",
        {
          type: "tool_result",
          toolName: "context_collapse",
          details: { action: "collapse", ok: true, deltaTokens: 10 },
        },
        session.ctx,
      );
    }
  } finally {
    console.warn = originalWarn;
  }
  assert.equal(pi.entries.length, entriesAfterStart);
  assert.equal(warnings.length, 1);
  assert.match(String(warnings[0][0]), /valid context window/i);
});

test("valid collapse results persist a zero-yield attempt and malformed details are ignored", async () => {
  const pi = new FakePi();
  contextPressure(pi as unknown as ExtensionAPI);
  const session = fakeContext(false);
  await pi.emit(
    "session_start",
    { type: "session_start", reason: "startup" },
    session.ctx,
  );
  const entriesAfterStart = pi.entries.length;
  await pi.emit(
    "tool_result",
    {
      type: "tool_result",
      toolName: "context_collapse",
      details: { action: "collapse", ok: false, deltaTokens: 10 },
    },
    session.ctx,
  );
  assert.equal(pi.entries.length, entriesAfterStart + 1);
  const latest = pi.entries.at(-1);
  assert.equal(latest.customType, "context-pressure/state");
  assert.equal(latest.data.yields.at(-1).percentagePoints, 0);
  await pi.emit(
    "tool_result",
    {
      type: "tool_result",
      toolName: "context_collapse",
      details: { action: "collapse" },
    },
    session.ctx,
  );
  assert.equal(pi.entries.length, entriesAfterStart + 1);
});
