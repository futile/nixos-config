import type {
  ExtensionAPI,
  ExtensionContext,
} from "@earendil-works/pi-coding-agent";
import {
  type ContextUsage,
  type PersistentPressureState,
  type PressureDecision,
  type PressureState,
  type YieldSample,
  beginInteraction,
  emptyPressureState,
  endInteraction,
  evaluatePressure,
  isCollapseDetails,
  isPersistentPressureState,
  makeYieldSample,
  normalizeUsage,
  noteToolTurn,
  observeUsage,
  persistentPressureState,
  recordCollapse,
  resetPressure,
  restorePressureState,
  samePersistentPressureState,
} from "./policy.ts";

const STATE_ENTRY = "context-pressure/state";
const REMINDER_TYPE = "context-pressure/reminder";

function branchSnapshot(
  ctx: ExtensionContext,
  warnInvalid: () => void,
): PersistentPressureState | undefined {
  const entries = ctx.sessionManager.getBranch();
  let snapshot: PersistentPressureState | undefined;
  for (const entry of entries) {
    if (entry.type !== "custom" || entry.customType !== STATE_ENTRY) continue;
    if (isPersistentPressureState(entry.data)) snapshot = entry.data;
    else warnInvalid();
  }
  return snapshot;
}

function percent(value: number): string {
  return `${Math.round(value)}%`;
}

function points(value: number): string {
  return `${value.toFixed(1)} pp`;
}

function yieldList(decision: PressureDecision): string {
  if (!decision.yields.length) return "none";
  return decision.yields
    .map((sample) => points(sample.percentagePoints))
    .join(", ");
}

function reminderText(decision: PressureDecision): string {
  const context = `Context ${percent(decision.percent)}`;
  switch (decision.kind) {
    case "advisory":
      return `<context-maintenance>\n${context} (+${Math.round(decision.growthTokens).toLocaleString()} tokens since maintenance; +${points(decision.interactionGrowthPoints)} interaction). If a meaningful completed/superseded batch and more work remain, piggy-back context_map + batched context_collapse; otherwise continue (no-op valid).\n</context-maintenance>`;
    case "firm":
      return `<context-maintenance firm>\n${context}. Use context_map before broadening; collapse only safe completed/superseded material. Preserve active evidence and open loops.\n</context-maintenance>`;
    case "urgent":
      if (decision.broaderYield !== undefined) {
        return `<context-maintenance urgent>\n${context}; recent yields: ${yieldList(decision)}. Do one broader safe sweep of completed/superseded material. Breadth is unverified; report what you checked. Preserve request, instructions, open loops, errors, and active evidence.\n</context-maintenance>`;
      }
      return `<context-maintenance urgent>\n${context}. Do one meaningful batched safe sweep if work continues; preserve active evidence, instructions, open loops, and unresolved errors.\n</context-maintenance>`;
    case "handoff":
      return `<context-maintenance critical>\n${context} remains urgent; the reported broader pass saved ${points(decision.broaderYield ?? 0)}. Stop tiny folds; preserve a resume-quality handoff and recommend a fresh session. Do not discard active evidence. If you are a child agent, send_message main with this recommendation.\n</context-maintenance>`;
    case "critical":
      return `<context-maintenance critical>\n${context}; about ${Math.round(decision.headroomTokens).toLocaleString()} tokens remain near Pi's reserve. Stop token-chasing; finish or preserve a handoff at a safe stopping point. Do not discard active evidence. If you are a child agent, send_message main with this critical warning.\n</context-maintenance>`;
  }
}

function sendReminder(pi: ExtensionAPI, decision: PressureDecision): void {
  // Pi 0.84.1 queues this steer synchronously while streaming. Persisting the
  // resulting phase immediately afterwards avoids a durable checkpoint without
  // its queued reminder; custom-entry persistence is not transactional.
  pi.sendMessage(
    {
      customType: REMINDER_TYPE,
      content: reminderText(decision),
      display: true,
      details: { kind: decision.kind, percent: decision.percent },
    },
    { deliverAs: "steer" },
  );
}

function notifyReminder(
  ctx: ExtensionContext,
  decision: PressureDecision,
): void {
  if (
    !ctx.hasUI ||
    (decision.kind !== "critical" && decision.kind !== "handoff")
  )
    return;
  const message =
    decision.kind === "handoff"
      ? "A broader pass was low-yield; preserve a handoff and recommend a fresh session."
      : "Context headroom is near Pi's compaction reserve; stop token-chasing and preserve a handoff.";
  ctx.ui.notify(message, "warning");
}

export default function contextPressure(pi: ExtensionAPI): void {
  let state = emptyPressureState();
  let collapseInCurrentTurn = false;
  let warnedMalformed = false;
  let warnedInvalidWindow = false;
  let warnedInvalidSnapshot = false;

  const warnInvalidSnapshot = (): void => {
    if (warnedInvalidSnapshot) return;
    console.warn(
      "[context-pressure] ignored malformed context-pressure/state snapshot",
    );
    warnedInvalidSnapshot = true;
  };

  const commit = (next: PressureState): void => {
    if (samePersistentPressureState(state, next)) {
      state = next;
      return;
    }
    state = next;
    pi.appendEntry(STATE_ENTRY, persistentPressureState(next));
  };

  const restore = (ctx: ExtensionContext): void => {
    const snapshot = branchSnapshot(ctx, warnInvalidSnapshot);
    const restored = snapshot
      ? restorePressureState(snapshot)
      : emptyPressureState();
    const observed = observeUsage(
      restored,
      ctx.getContextUsage() as ContextUsage | undefined,
    );
    state = restored;
    commit(observed);
    collapseInCurrentTurn = false;
  };

  pi.on("session_start", (_event, ctx) => {
    warnedInvalidSnapshot = false;
    restore(ctx);
    warnedMalformed = false;
    warnedInvalidWindow = false;
  });

  pi.on("session_tree", (_event, ctx) => restore(ctx));

  pi.on("model_select", (_event, _ctx) => {
    commit(resetPressure(state));
    collapseInCurrentTurn = false;
  });

  pi.on("session_compact", (_event, _ctx) => {
    commit(resetPressure(state));
    collapseInCurrentTurn = false;
  });

  pi.on("agent_start", (_event, ctx) => {
    state = beginInteraction(
      state,
      ctx.getContextUsage() as ContextUsage | undefined,
    );
  });

  pi.on("agent_settled", () => {
    commit(endInteraction(state));
    collapseInCurrentTurn = false;
  });

  pi.on("tool_result", (event, ctx) => {
    if (event.toolName !== "context_collapse") return;
    const details = event.details;
    if (!isCollapseDetails(details)) {
      if (!warnedMalformed) {
        console.warn(
          "[context-pressure] ignored malformed context_collapse details",
        );
        warnedMalformed = true;
      }
      return;
    }
    const usage = ctx.getContextUsage();
    const contextWindow = usage?.contextWindow;
    if (
      typeof contextWindow !== "number" ||
      !Number.isFinite(contextWindow) ||
      contextWindow <= 0
    ) {
      if (!warnedInvalidWindow) {
        console.warn(
          "[context-pressure] ignored context_collapse result without a valid context window",
        );
        warnedInvalidWindow = true;
      }
      return;
    }
    const sample = makeYieldSample(details, contextWindow);
    if (!sample) return;
    const next = recordCollapse(state, sample, usage?.tokens ?? null);
    commit(next);
    if (sample.ok && sample.deltaTokens > 0) collapseInCurrentTurn = true;
  });

  pi.on("turn_end", (event, ctx) => {
    const usage = normalizeUsage(
      ctx.getContextUsage() as ContextUsage | undefined,
    );
    let next = collapseInCurrentTurn ? state : observeUsage(state, usage);
    collapseInCurrentTurn = false;

    const message = event.message as { stopReason?: string };
    const continuing =
      message.stopReason === "toolUse" && event.toolResults.length > 0;
    let decision: PressureDecision | undefined;
    if (continuing) {
      next = noteToolTurn(next);
      const result = evaluatePressure(next, usage);
      next = result.state;
      decision = result.decision;
    }

    // Queue the steer before durable snapshot persistence, per Pi 0.84.1's
    // synchronous streaming path. UI notification follows the commit.
    if (decision) sendReminder(pi, decision);
    commit(next);
    if (decision) notifyReminder(ctx, decision);
  });

  pi.on("session_shutdown", () => {
    state = emptyPressureState();
    collapseInCurrentTurn = false;
  });
}
