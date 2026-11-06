// Workaround for https://github.com/earendil-works/pi/issues/10956: idle cache warming compares
// context messages by object identity (sdk.js cacheContextIsCurrent), but every context refresh
// re-projects custom, branch-summary and compaction entries into new objects. Keeping the previous
// object wherever the refreshed one sends the same payload lets the warmer see an unchanged prefix.
// shortcut: relies on AgentSession privates of pi 1.5.0; delete once upstream compares entry ids.

type Message = { role?: string; content?: unknown; summary?: unknown };

const MARK = Symbol.for("pi-10956-cache-warming-identity");

/** Same role and same payload reference: re-projections reuse their entry's content/summary value. */
export function isSameProviderMessage(a: Message, b: Message): boolean {
  if (a === b) return true;
  if (a.role !== b.role) return false;
  if (a.role === "branchSummary" || a.role === "compactionSummary") return a.summary === b.summary;
  // bashExecution has no content; identity (above) covers it.
  return a.content !== undefined && a.content === b.content;
}

type PatchState = { failed: boolean; report?: (message: string) => void };

/**
 * Wraps `_refreshFinalizedContext` on an AgentSession prototype. Returns false if the private API is gone.
 * If the session's private shape changed, the wrapper disables itself, reports once, and leaves stock
 * behavior intact: the original refresh result is never altered by a failure here.
 */
export function installPatch(proto: any, report?: (message: string) => void): boolean {
  const existing: PatchState | undefined = proto[MARK];
  if (existing) {
    existing.report = report; // /reload re-runs the extension; route reports to the new instance
    return true;
  }
  const original = proto._refreshFinalizedContext;
  if (typeof original !== "function") return false;
  const state: PatchState = { failed: false, report };
  const fail = (reason: unknown) => {
    state.failed = true;
    state.report?.(`cache-warming-identity disabled (pi#10956 workaround): ${reason instanceof Error ? reason.message : String(reason)}`);
  };
  proto._refreshFinalizedContext = function (this: any, ...args: unknown[]) {
    let previous: unknown;
    if (!state.failed) {
      try {
        previous = this.agent.state.messages;
      } catch (error) {
        fail(error);
      }
    }
    const result = original.apply(this, args);
    if (state.failed) return result;
    try {
      const current: unknown = this.agent.state.messages;
      if (!Array.isArray(previous) || !Array.isArray(current))
        throw new Error("agent.state.messages is not an array");
      let reused = false;
      const next = current.map((message: Message, index: number) => {
        const old: Message | undefined = previous[index];
        if (!old || old === message || !isSameProviderMessage(old, message)) return message;
        const entryId = this._entryIdsByMessage?.get(message);
        if (entryId !== undefined) this._entryIdsByMessage.set(old, entryId);
        reused = true;
        return old;
      });
      if (reused) this.agent.state.messages = next;
    } catch (error) {
      fail(error);
    }
    return result;
  };
  proto[MARK] = state;
  return true;
}
