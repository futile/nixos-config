import assert from "node:assert/strict";
import { test } from "node:test";
import {
  type ContextUsage,
  beginInteraction,
  emptyPressureState,
  endInteraction,
  evaluatePressure,
  makeYieldSample,
  noteToolTurn,
  observeUsage,
  recordCollapse,
  resetPressure,
} from "./policy.ts";

const usage = (
  tokens: number,
  percent?: number,
  contextWindow = 100_000,
): ContextUsage => ({
  tokens,
  contextWindow,
  percent: percent ?? (tokens / contextWindow) * 100,
});

function ready(tokens: number, percent?: number, contextWindow = 100_000) {
  let state = emptyPressureState();
  state = observeUsage(state, usage(10_000, undefined, contextWindow));
  state = beginInteraction(state, usage(10_000, undefined, contextWindow));
  state = noteToolTurn(state);
  state = noteToolTurn(state);
  return {
    state,
    current: usage(
      tokens,
      percent ?? (tokens / contextWindow) * 100,
      contextWindow,
    ),
  };
}

test("advisory and firm use maintenance/interaction growth, while urgent is one-shot", () => {
  let first = ready(70_000, 70);
  let result = evaluatePressure(first.state, first.current);
  assert.equal(result.decision?.kind, "advisory");

  first = ready(800_000, 80, 1_000_000);
  result = evaluatePressure(first.state, first.current);
  assert.equal(result.decision?.kind, "urgent");
  result = evaluatePressure(result.state, first.current);
  assert.equal(result.decision, undefined);

  const cooled = observeUsage(result.state, usage(740_000, 74, 1_000_000));
  result = evaluatePressure(cooled, first.current);
  assert.equal(
    result.decision?.kind,
    "urgent",
    "a five-point drop re-arms before the next loop",
  );

  const firm = ready(760_000, 76, 1_000_000);
  result = evaluatePressure(firm.state, firm.current);
  assert.equal(result.decision?.kind, "firm");
  result = evaluatePressure(result.state, firm.current);
  assert.equal(
    result.decision,
    undefined,
    "a firm latch must suppress advisory repeats",
  );
});

test("critical uses reserve headroom rather than a portable percentage", () => {
  const critical = ready(76_000, 76);
  const result = evaluatePressure(critical.state, usage(76_000, 76, 100_000));
  assert.equal(result.decision?.kind, "critical");
  assert.equal(result.decision?.headroomTokens, 24_000);
});

test("still-armed higher latches suppress every lower downgrade", () => {
  const cases = [
    {
      name: "critical suppresses urgent",
      armed: 980_000,
      current: 970_000,
    },
    {
      name: "urgent suppresses firm",
      armed: 800_000,
      current: 790_000,
    },
    {
      name: "firm suppresses advisory",
      armed: 760_000,
      current: 740_000,
    },
  ];

  for (const { name, armed, current } of cases) {
    const prepared = ready(armed, undefined, 1_000_000);
    const armedResult = evaluatePressure(
      prepared.state,
      usage(armed, undefined, 1_000_000),
    );
    assert.ok(armedResult.decision, `${name} must arm its higher level`);
    const lowerResult = evaluatePressure(
      armedResult.state,
      usage(current, undefined, 1_000_000),
    );
    assert.equal(lowerResult.decision, undefined, name);
  }
});

test("each latch can legitimately retrigger after its five-point rearm", () => {
  const cases = [
    {
      name: "critical rearm permits urgent",
      armed: 980_000,
      current: 900_000,
      expected: "urgent",
    },
    {
      name: "urgent rearm permits advisory",
      armed: 800_000,
      current: 740_000,
      expected: "advisory",
    },
    {
      name: "firm rearm permits advisory",
      armed: 760_000,
      current: 700_000,
      expected: "advisory",
    },
  ] as const;

  for (const { name, armed, current, expected } of cases) {
    const prepared = ready(armed, undefined, 1_000_000);
    const armedResult = evaluatePressure(
      prepared.state,
      usage(armed, undefined, 1_000_000),
    );
    assert.ok(armedResult.decision, `${name} must arm its higher level`);
    const retriggered = evaluatePressure(
      armedResult.state,
      usage(current, undefined, 1_000_000),
    );
    assert.equal(retriggered.decision?.kind, expected, name);
  }
});

test("reset preserves samples but first interaction captures its fresh maintenance baseline", () => {
  const beforeReset = ready(70_000, 70);
  const recorded = makeYieldSample(
    { action: "collapse", ok: false, deltaTokens: 0 },
    100_000,
    1,
  );
  if (!recorded) throw new Error("expected valid sample");
  const reset = resetPressure(recordCollapse(beforeReset.state, recorded));
  const firstInteraction = beginInteraction(
    reset,
    usage(210_000, 21, 1_000_000),
  );
  assert.equal(firstInteraction.maintenance?.tokens, 210_000);
  assert.equal(firstInteraction.interaction?.tokens, 210_000);
  assert.equal(firstInteraction.yields.length, 1);

  const positive = makeYieldSample(
    { action: "collapse", ok: true, deltaTokens: 10_000 },
    100_000,
    1,
  );
  if (!positive) throw new Error("expected valid sample");
  const pending = recordCollapse(beforeReset.state, positive);
  const deferred = beginInteraction(
    endInteraction(pending),
    usage(210_000, 21, 1_000_000),
  );
  assert.equal(deferred.maintenance?.tokens, 10_000);
  assert.equal(deferred.interaction, null);
  assert.equal(deferred.pendingBaseline, true);
});

test("invalid context windows never create yield samples", () => {
  const details = { action: "collapse", ok: true, deltaTokens: 100 };
  for (const contextWindow of [0, -1, Number.NaN, Number.POSITIVE_INFINITY]) {
    assert.equal(makeYieldSample(details, contextWindow), null);
  }
});

test("failed, no-op, and saving collapse attempts populate a three-sample ring", () => {
  let state = emptyPressureState();
  const failed = makeYieldSample(
    { action: "collapse", ok: false, deltaTokens: 90_000 },
    100_000,
    1,
  );
  const noop = makeYieldSample(
    { action: "collapse", ok: true, deltaTokens: 0 },
    100_000,
    2,
  );
  const saved = makeYieldSample(
    { action: "collapse", ok: true, deltaTokens: 10_000 },
    100_000,
    3,
  );
  if (!failed || !noop || !saved) throw new Error("expected valid samples");
  state = recordCollapse(state, failed);
  state = recordCollapse(state, noop);
  state = recordCollapse(state, saved);
  assert.deepEqual(
    state.yields.map((sample) => sample.percentagePoints),
    [0, 0, 10],
  );
  assert.equal(state.pendingBaseline, true);
  assert.equal(
    makeYieldSample({ action: "expand", ok: true, deltaTokens: 1 }, 100_000),
    null,
  );
});

test("an advisory latch can escalate upward to firm without rearming", () => {
  let { state } = ready(740_000, 74, 1_000_000);
  let result = evaluatePressure(state, usage(740_000, 74, 1_000_000));
  assert.equal(result.decision?.kind, "advisory");
  state = result.state;
  result = evaluatePressure(state, usage(755_000, 75.5, 1_000_000));
  assert.equal(result.decision?.kind, "firm");
});

test("tiny positive maintenance retains urgent latch, while a five-point drop rearms it", () => {
  let { state } = ready(800_000, 80, 1_000_000);
  let result = evaluatePressure(state, usage(800_000, 80, 1_000_000));
  assert.equal(result.decision?.kind, "urgent");
  state = result.state;
  const tiny = makeYieldSample(
    { action: "collapse", ok: true, deltaTokens: 10_000 },
    1_000_000,
    1,
  );
  if (!tiny) throw new Error("expected valid sample");
  state = recordCollapse(state, tiny);
  state = observeUsage(state, usage(790_000, 79, 1_000_000));
  result = evaluatePressure(state, usage(810_000, 81, 1_000_000));
  assert.equal(result.decision, undefined);

  const larger = makeYieldSample(
    { action: "collapse", ok: true, deltaTokens: 10_000 },
    1_000_000,
    2,
  );
  if (!larger) throw new Error("expected valid sample");
  state = recordCollapse(result.state, larger);
  state = observeUsage(state, usage(750_000, 75, 1_000_000));
  result = evaluatePressure(state, usage(810_000, 81, 1_000_000));
  assert.equal(result.decision?.kind, "urgent");
});

test("a completed broader sample ages out after three newer ordinary samples", () => {
  let { state } = ready(800_000, 80, 1_000_000);
  const broad = makeYieldSample(
    { action: "collapse", ok: true, deltaTokens: 1_000 },
    1_000_000,
    1,
    true,
  );
  const ordinary = makeYieldSample(
    { action: "collapse", ok: true, deltaTokens: 0 },
    1_000_000,
    2,
  );
  if (!broad || !ordinary) throw new Error("expected valid samples");
  state = { ...state, yields: [broad, ordinary, ordinary] };
  let result = evaluatePressure(state, usage(800_000, 80, 1_000_000));
  assert.equal(result.decision?.broaderYield, undefined);
  state = {
    ...result.state,
    latches: {},
    yields: [...result.state.yields, ordinary].slice(-3),
  };
  result = evaluatePressure(state, usage(800_000, 80, 1_000_000));
  assert.equal(result.decision?.kind, "urgent");
  assert.equal(result.decision?.broaderYield, 0);
});

test("urgent low-yield escalation requests one broader pass, then handoff on its next low result", () => {
  let { state } = ready(800_000, 80, 1_000_000);
  for (let i = 0; i < 3; i++) {
    const sample = makeYieldSample(
      { action: "collapse", ok: true, deltaTokens: 0 },
      1_000_000,
      i,
    );
    if (!sample) throw new Error("expected valid sample");
    state = recordCollapse(state, sample);
  }
  let result = evaluatePressure(state, usage(800_000, 80, 1_000_000));
  assert.equal(result.decision?.kind, "urgent");
  assert.equal(result.decision?.broaderYield, 0);
  state = result.state;
  const broader = makeYieldSample(
    { action: "collapse", ok: true, deltaTokens: 1_000 },
    1_000_000,
    4,
  );
  if (!broader) throw new Error("expected valid sample");
  state = recordCollapse(state, broader);
  assert.equal(state.pendingBaseline, true);
  state = observeUsage(state, usage(800_000, 80, 1_000_000));
  result = evaluatePressure(state, usage(810_000, 81, 1_000_000));
  assert.equal(result.decision?.kind, "handoff");
  assert.match(
    "If you are a child agent, send_message main",
    /send_message main/,
  );
});

test("a positive collapse waits for a fresh reading, and reset retains yields", () => {
  const prepared = ready(70_000, 70);
  const sample = makeYieldSample(
    { action: "collapse", ok: true, deltaTokens: 10_000 },
    100_000,
    1,
  );
  if (!sample) throw new Error("expected valid sample");
  const pending = recordCollapse(prepared.state, sample);
  assert.equal(
    evaluatePressure(pending, usage(70_000, 70)).decision,
    undefined,
  );
  const fresh = observeUsage(pending, usage(60_000, 60));
  assert.equal(fresh.pendingBaseline, false);
  assert.equal(fresh.maintenance?.tokens, 60_000);
  assert.equal(resetPressure(fresh).yields.length, 1);
});
