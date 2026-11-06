import { AgentSession, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { installPatch } from "./patch.ts";

let lastCtx: ExtensionContext | undefined;
let pending: string | undefined; // a failure before any session_start is shown on the next one

function warn(message: string): void {
  try {
    if (lastCtx?.hasUI) return lastCtx.ui.notify(message, "warning");
  } catch {} // stale ctx after /reload or session switch
  pending = message;
}

// Patch at load time: the prototype is shared by the main session and in-process subagents.
if (!installPatch(AgentSession.prototype, warn))
  pending =
    "cache-warming-identity: AgentSession._refreshFinalizedContext is gone; pi#10956 workaround inactive (remove it if upstream fixed the bug)";

export default function cacheWarmingIdentity(pi: ExtensionAPI): void {
  pi.on("session_start", (_event, ctx) => {
    lastCtx = ctx;
    if (pending && ctx.hasUI) {
      ctx.ui.notify(pending, "warning");
      pending = undefined;
    }
  });
}
