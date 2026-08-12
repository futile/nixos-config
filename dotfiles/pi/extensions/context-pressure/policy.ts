export const CONTEXT_RESERVE_TOKENS = 16_384;
export const CRITICAL_EXTRA_TOKENS = 8_000;
export const REARM_DROP_PERCENT = 5;
export const REARM_GROWTH_TOKENS = 20_000;
export const COLLAPSE_COOLDOWN_TOKENS = 5_000;
export const RECENT_YIELD_LIMIT = 3;

export type PressureLevel = "advisory" | "firm" | "urgent" | "critical";
export type ReminderKind = PressureLevel | "handoff";

const PRESSURE_LEVELS: PressureLevel[] = [
  "advisory",
  "firm",
  "urgent",
  "critical",
];

export interface ContextUsage {
  tokens: number | null;
  contextWindow: number;
  percent: number | null;
}

export interface UsageBaseline {
  tokens: number;
  contextWindow: number;
  percent: number;
}

export interface CollapseDetails {
  action: unknown;
  ok: unknown;
  deltaTokens: unknown;
  msgs?: unknown;
}

export interface YieldSample {
  ok: boolean;
  deltaTokens: number;
  contextWindow: number;
  percentagePoints: number;
  msgs?: number;
  timestamp: number;
  broader?: boolean;
}

export interface PressureState {
  maintenance: UsageBaseline | null;
  interaction: UsageBaseline | null;
  interactionActive: boolean;
  toolTurns: number;
  pendingBaseline: boolean;
  cooldownUntilTokens: number | null;
  latches: Partial<Record<PressureLevel, UsageBaseline>>;
  yields: YieldSample[];
  broaderPassPending: boolean;
  handoffCandidate: boolean;
  handoffSent: boolean;
}

export interface PersistentPressureState {
  version: 1;
  yields: YieldSample[];
  latches: Partial<Record<PressureLevel, UsageBaseline>>;
  broaderPassPending: boolean;
  handoffCandidate: boolean;
  handoffSent: boolean;
}

export interface PressureDecision {
  kind: ReminderKind;
  percent: number;
  headroomTokens: number;
  growthTokens: number;
  interactionGrowthPoints: number;
  yields: YieldSample[];
  broaderYield?: number;
}

export function emptyPressureState(): PressureState {
  return {
    maintenance: null,
    interaction: null,
    interactionActive: false,
    toolTurns: 0,
    pendingBaseline: false,
    cooldownUntilTokens: null,
    latches: {},
    yields: [],
    broaderPassPending: false,
    handoffCandidate: false,
    handoffSent: false,
  };
}

function finite(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value);
}

function validBaseline(value: unknown): value is UsageBaseline {
  if (value === null || typeof value !== "object") return false;
  const baseline = value as Record<string, unknown>;
  return (
    finite(baseline.tokens) &&
    finite(baseline.contextWindow) &&
    baseline.contextWindow > 0 &&
    finite(baseline.percent)
  );
}

export function isValidYieldSample(value: unknown): value is YieldSample {
  if (value === null || typeof value !== "object") return false;
  const sample = value as Record<string, unknown>;
  const validMsgs =
    sample.msgs === undefined || (finite(sample.msgs) && sample.msgs >= 0);
  const validBroader =
    sample.broader === undefined || typeof sample.broader === "boolean";
  return (
    typeof sample.ok === "boolean" &&
    finite(sample.deltaTokens) &&
    finite(sample.contextWindow) &&
    sample.contextWindow > 0 &&
    finite(sample.percentagePoints) &&
    sample.percentagePoints >= 0 &&
    finite(sample.timestamp) &&
    validMsgs &&
    validBroader
  );
}

function validLatches(
  value: unknown,
): value is Partial<Record<PressureLevel, UsageBaseline>> {
  if (value === null || typeof value !== "object" || Array.isArray(value))
    return false;
  const latches = value as Record<string, unknown>;
  if (
    Object.keys(latches).some(
      (key) => !PRESSURE_LEVELS.includes(key as PressureLevel),
    )
  )
    return false;
  return Object.values(latches).every(validBaseline);
}

/** Fail-closed validator for the v1 branch-local snapshot. */
export function isPersistentPressureState(
  value: unknown,
): value is PersistentPressureState {
  if (value === null || typeof value !== "object") return false;
  const snapshot = value as Record<string, unknown>;
  if (
    snapshot.version !== 1 ||
    !Array.isArray(snapshot.yields) ||
    snapshot.yields.length > RECENT_YIELD_LIMIT ||
    !snapshot.yields.every(isValidYieldSample) ||
    !validLatches(snapshot.latches) ||
    typeof snapshot.broaderPassPending !== "boolean" ||
    typeof snapshot.handoffCandidate !== "boolean" ||
    typeof snapshot.handoffSent !== "boolean"
  )
    return false;
  if (snapshot.broaderPassPending && snapshot.handoffCandidate) return false;
  if (
    snapshot.handoffSent &&
    (snapshot.broaderPassPending || snapshot.handoffCandidate)
  )
    return false;
  const latestBroader = [...snapshot.yields]
    .reverse()
    .find((sample) => sample.broader);
  return (
    !snapshot.handoffCandidate ||
    (latestBroader !== undefined && latestBroader.percentagePoints < 3)
  );
}

function orderedLatches(
  latches: Partial<Record<PressureLevel, UsageBaseline>>,
): Partial<Record<PressureLevel, UsageBaseline>> {
  const result: Partial<Record<PressureLevel, UsageBaseline>> = {};
  for (const level of PRESSURE_LEVELS) {
    const baseline = latches[level];
    if (baseline) result[level] = { ...baseline };
  }
  return result;
}

/** Return only session-persistent state; usage baselines/tool-loop counters stay ephemeral. */
export function persistentPressureState(
  state: PressureState,
): PersistentPressureState {
  return {
    version: 1,
    yields: state.yields
      .slice(-RECENT_YIELD_LIMIT)
      .map((sample) => ({ ...sample })),
    latches: orderedLatches(state.latches),
    broaderPassPending: state.broaderPassPending,
    handoffCandidate: state.handoffCandidate,
    handoffSent: state.handoffSent,
  };
}

export function samePersistentPressureState(
  left: PressureState,
  right: PressureState,
): boolean {
  return (
    JSON.stringify(persistentPressureState(left)) ===
    JSON.stringify(persistentPressureState(right))
  );
}

export function restorePressureState(
  snapshot: PersistentPressureState,
): PressureState {
  return {
    ...emptyPressureState(),
    yields: snapshot.yields.map((sample) => ({ ...sample })),
    latches: orderedLatches(snapshot.latches),
    broaderPassPending: snapshot.broaderPassPending,
    handoffCandidate: snapshot.handoffCandidate,
    handoffSent: snapshot.handoffSent,
  };
}

/** Reset pressure gates while retaining session-local yields and phase state. */
export function resetPressure(state: PressureState): PressureState {
  return {
    ...emptyPressureState(),
    yields: state.yields.slice(-RECENT_YIELD_LIMIT),
    broaderPassPending: state.broaderPassPending,
    handoffCandidate: state.handoffCandidate,
    handoffSent: state.handoffSent,
  };
}

function baseline(usage: ContextUsage | undefined): UsageBaseline | null {
  if (
    !usage ||
    usage.tokens == null ||
    !finite(usage.tokens) ||
    !finite(usage.contextWindow) ||
    usage.contextWindow <= 0
  )
    return null;
  const percent = finite(usage.percent)
    ? usage.percent
    : (usage.tokens / usage.contextWindow) * 100;
  return { tokens: usage.tokens, contextWindow: usage.contextWindow, percent };
}

export function normalizeUsage(
  usage: ContextUsage | undefined,
): ContextUsage | undefined {
  const current = baseline(usage);
  return current
    ? {
        tokens: current.tokens,
        contextWindow: current.contextWindow,
        percent: current.percent,
      }
    : undefined;
}

function latestBroaderSample(state: PressureState): YieldSample | undefined {
  for (let index = state.yields.length - 1; index >= 0; index -= 1) {
    if (state.yields[index].broader) return state.yields[index];
  }
  return undefined;
}

function reconcilePhase(state: PressureState): PressureState {
  const broader = latestBroaderSample(state);
  if (state.handoffCandidate && (!broader || broader.percentagePoints >= 3)) {
    return { ...state, handoffCandidate: false };
  }
  return state;
}

function rearm(state: PressureState, current: UsageBaseline): PressureState {
  const latches = { ...state.latches };
  for (const level of PRESSURE_LEVELS) {
    const latch = latches[level];
    if (
      latch &&
      (current.percent <= latch.percent - REARM_DROP_PERCENT ||
        (current.contextWindow === latch.contextWindow &&
          current.tokens - latch.tokens >= REARM_GROWTH_TOKENS))
    )
      delete latches[level];
  }
  return reconcilePhase({ ...state, latches });
}

/** Establish a deferred post-collapse baseline, then apply ordinary hysteresis. */
export function observeUsage(
  state: PressureState,
  usage: ContextUsage | undefined,
): PressureState {
  const current = baseline(usage);
  if (!current) return state;
  if (state.pendingBaseline) {
    return rearm(
      {
        ...state,
        maintenance: current,
        interaction: state.interactionActive ? current : null,
        pendingBaseline: false,
        cooldownUntilTokens: null,
      },
      current,
    );
  }
  return rearm(
    {
      ...state,
      maintenance: state.maintenance ?? current,
      interaction: state.interactionActive
        ? (state.interaction ?? current)
        : state.interaction,
    },
    current,
  );
}

export function beginInteraction(
  state: PressureState,
  usage?: ContextUsage,
): PressureState {
  if (state.interactionActive) return state;
  const current = state.pendingBaseline ? null : baseline(usage);
  return {
    ...state,
    interactionActive: true,
    maintenance: state.maintenance ?? current,
    interaction: current,
    toolTurns: 0,
  };
}

export function endInteraction(state: PressureState): PressureState {
  return {
    ...state,
    interactionActive: false,
    interaction: null,
    toolTurns: 0,
  };
}

export function noteToolTurn(state: PressureState): PressureState {
  return { ...state, toolTurns: state.toolTurns + 1 };
}

export function isCollapseDetails(value: unknown): value is CollapseDetails {
  if (value === null || typeof value !== "object") return false;
  const details = value as Record<string, unknown>;
  return (
    details.action === "collapse" &&
    typeof details.ok === "boolean" &&
    finite(details.deltaTokens)
  );
}

export function makeYieldSample(
  details: CollapseDetails,
  contextWindow: number,
  timestamp = Date.now(),
  broader = false,
): YieldSample | null {
  if (
    !isCollapseDetails(details) ||
    !finite(contextWindow) ||
    contextWindow <= 0
  )
    return null;
  const deltaTokens = details.deltaTokens as number;
  const ok = details.ok as boolean;
  const percentagePoints = ok
    ? (100 * Math.max(deltaTokens, 0)) / contextWindow
    : 0;
  const msgs = finite(details.msgs) ? details.msgs : undefined;
  return {
    ok,
    deltaTokens,
    contextWindow,
    percentagePoints,
    timestamp,
    ...(msgs === undefined ? {} : { msgs }),
    ...(broader ? { broader: true } : {}),
  };
}

/** Record each valid collapse; a pending broader phase is consumed atomically with its sample. */
export function recordCollapse(
  state: PressureState,
  sample: YieldSample,
  currentTokens: number | null = null,
): PressureState {
  const broader = state.broaderPassPending;
  const recorded = broader ? { ...sample, broader: true } : sample;
  const yields = [...state.yields, recorded].slice(-RECENT_YIELD_LIMIT);
  const next: PressureState = {
    ...state,
    yields,
    broaderPassPending: broader ? false : state.broaderPassPending,
    handoffCandidate: broader
      ? sample.percentagePoints < 3
      : state.handoffCandidate,
    handoffSent: broader ? false : state.handoffSent,
    cooldownUntilTokens:
      sample.ok && sample.deltaTokens > 0
        ? state.cooldownUntilTokens
        : currentTokens == null
          ? state.cooldownUntilTokens
          : currentTokens + COLLAPSE_COOLDOWN_TOKENS,
  };
  return sample.ok && sample.deltaTokens > 0
    ? { ...next, pendingBaseline: true, cooldownUntilTokens: null }
    : reconcilePhase(next);
}

function lowYieldEscalation(state: PressureState): boolean {
  if (state.broaderPassPending || state.yields.some((sample) => sample.broader))
    return false;
  if (state.yields.length < RECENT_YIELD_LIMIT) return false;
  const recent = state.yields.slice(-RECENT_YIELD_LIMIT);
  return (
    recent.every((sample) => sample.percentagePoints < 3) ||
    recent.reduce((sum, sample) => sum + sample.percentagePoints, 0) < 6
  );
}

function decision(
  kind: ReminderKind,
  current: UsageBaseline,
  maintenance: UsageBaseline,
  interaction: UsageBaseline | null,
  yields: YieldSample[],
): PressureDecision {
  return {
    kind,
    percent: current.percent,
    headroomTokens: Math.max(0, current.contextWindow - current.tokens),
    growthTokens: Math.max(0, current.tokens - maintenance.tokens),
    interactionGrowthPoints: interaction
      ? Math.max(
          0,
          (100 * (current.tokens - interaction.tokens)) / current.contextWindow,
        )
      : 0,
    yields,
  };
}

/** Decide at a turn; persistent transitions are committed by the extension shell. */
export function evaluatePressure(
  state: PressureState,
  usage: ContextUsage | undefined,
): { state: PressureState; decision?: PressureDecision } {
  const current = baseline(usage);
  if (!current || state.pendingBaseline || !state.maintenance) return { state };

  let next = rearm(state, current);
  const maintenance = next.maintenance ?? current;
  const interaction = next.interaction;
  const growthTokens = current.tokens - maintenance.tokens;
  const growthPoints = (100 * growthTokens) / current.contextWindow;
  const interactionGrowthPoints = interaction
    ? (100 * (current.tokens - interaction.tokens)) / current.contextWindow
    : 0;
  const urgent = current.percent >= 80;
  const critical =
    current.contextWindow - current.tokens <=
    CONTEXT_RESERVE_TOKENS + CRITICAL_EXTRA_TOKENS;

  if (next.handoffCandidate) {
    if (!urgent) {
      next = { ...next, handoffCandidate: false, handoffSent: false };
    } else if (!next.handoffSent) {
      const broader = latestBroaderSample(next);
      if (broader) {
        next = {
          ...next,
          handoffSent: true,
          handoffCandidate: false,
          latches: {
            ...next.latches,
            urgent: current,
            ...(critical ? { critical: current } : {}),
          },
        };
        return {
          state: next,
          decision: {
            ...decision(
              "handoff",
              current,
              maintenance,
              interaction,
              next.yields,
            ),
            broaderYield: broader.percentagePoints,
          },
        };
      }
      next = { ...next, handoffCandidate: false };
    }
  }

  if (critical && !next.latches.critical) {
    next = { ...next, latches: { ...next.latches, critical: current } };
    return {
      state: next,
      decision: decision(
        "critical",
        current,
        maintenance,
        interaction,
        next.yields,
      ),
    };
  }
  if (next.latches.critical) return { state: next };

  if (urgent && !next.latches.urgent) {
    const broader = lowYieldEscalation(next);
    next = {
      ...next,
      latches: { ...next.latches, urgent: current },
      broaderPassPending: next.broaderPassPending || broader,
      handoffSent: broader ? false : next.handoffSent,
    };
    return {
      state: next,
      decision: {
        ...decision("urgent", current, maintenance, interaction, next.yields),
        ...(broader
          ? {
              broaderYield: next.yields.reduce(
                (sum, sample) => sum + sample.percentagePoints,
                0,
              ),
            }
          : {}),
      },
    };
  }

  if (next.latches.urgent || next.toolTurns < 2) return { state: next };
  const cooldown = next.cooldownUntilTokens;
  if (cooldown != null && current.tokens < cooldown) return { state: next };

  const firm = current.percent >= 75 && growthPoints >= 5;
  if (firm) {
    if (next.latches.firm) return { state: next };
    next = { ...next, latches: { ...next.latches, firm: current } };
    return {
      state: next,
      decision: decision(
        "firm",
        current,
        maintenance,
        interaction,
        next.yields,
      ),
    };
  }
  if (next.latches.firm) return { state: next };

  const advisory =
    current.percent >= 60 &&
    (growthTokens >= 24_000 || interactionGrowthPoints >= 8);
  if (advisory) {
    if (next.latches.advisory) return { state: next };
    next = { ...next, latches: { ...next.latches, advisory: current } };
    return {
      state: next,
      decision: decision(
        "advisory",
        current,
        maintenance,
        interaction,
        next.yields,
      ),
    };
  }
  if (next.latches.advisory) return { state: next };
  return { state: next };
}
