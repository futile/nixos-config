import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { realpathSync } from "node:fs";
import { randomUUID } from "node:crypto";
import { isDeepStrictEqual } from "node:util";
import {
  authority, canonicalDirectory, CHECKPOINT, checkpointData, commitRequest, consumeIncoming, FLAG, invalidateRequest,
  manualInstructions, MARKER, nativeExpected, readSession, savedBranch, savedSource, syncSession, verifyCheckpoint,
  type Authority, type Checkpoint, type Request,
} from "./handoff.ts";

import { approval } from "./approval.ts";

const ACTOR = Symbol.for("futile.pi.subagents.restart-in-dir.v1");
const NAME_LOOKUP = Symbol.for("futile.pi.subagents.agent-name-lookup.v1");
const HEALTH_REQUEST = "pi-restart-in-dir:ic-health-request";
const HEALTH_RESPONSE = "pi-restart-in-dir:ic-health-response";
type ActorBridge = {
  inspect(sessionId: string): { main: boolean; ready: boolean; reason?: string };
  acquire(sessionId: string, token: string): { ok: boolean; reason?: string };
  release(sessionId: string, token: string): void;
};
type Intent = {
  authority: Authority; data: Checkpoint; source: string; sessionId: string; token: string;
  actor?: ActorBridge; toolCallId?: string; resultObserved: boolean; committed: boolean;
  controller: AbortController; signal: AbortSignal;
};
function bridge(): ActorBridge | undefined {
  const globals = globalThis as Record<symbol, unknown>;
  const value = globals[ACTOR] as ActorBridge | undefined;
  if (!value && globals[NAME_LOOKUP] !== undefined) throw new Error("Actor-subagents is loaded without its restart readiness bridge");
  if (value && (!["inspect", "acquire", "release"].every((key) => typeof (value as any)[key] === "function"))) throw new Error("Invalid actor restart readiness bridge");
  return value;
}
function mainIdentity(ctx: ExtensionContext): ActorBridge | undefined {
  if (ctx.mode !== "tui" || !ctx.hasUI) throw new Error("Restart is only supported in foreground interactive Pi");
  const actor = bridge();
  const globals = globalThis as Record<symbol, unknown>;
  const lookup = globals[NAME_LOOKUP];
  if (lookup !== undefined && (typeof lookup !== "function" || lookup(ctx.sessionManager.getSessionId()) !== "main")) throw new Error("Only the main agent may restart Pi");
  if (actor && actor.inspect(ctx.sessionManager.getSessionId()).main !== true) throw new Error("Cannot establish main-agent identity");
  return actor;
}
function checkReady(ctx: ExtensionContext, actor: ActorBridge | undefined, ownTool: boolean, activeTools: Set<string>, toolCallId?: string): void {
  if (!ownTool && !ctx.isIdle()) throw new Error("Main agent is busy; finish its work and retry");
  if (ctx.hasPendingMessages()) throw new Error("Main agent has pending messages; finish them and retry");
  if ([...activeTools].some((id) => id !== toolCallId)) throw new Error("Another tool is still executing");
  if (actor) {
    const status = actor.inspect(ctx.sessionManager.getSessionId());
    if (status.main !== true || status.ready !== true) throw new Error(status.reason ?? "Actor-owned work is not ready for restart");
  }
}
function assistantCalls(ctx: ExtensionContext): Array<{ type: string; id: string; name: string }> {
  const assistant = ctx.sessionManager.getBranch().reverse().find((entry: any) => entry.type === "message" && entry.message.role === "assistant") as any;
  return Array.isArray(assistant?.message.content) ? assistant.message.content.filter((part: any) => part.type === "toolCall") : [];
}
function soleTool(ctx: ExtensionContext, id: string): void {
  const calls = assistantCalls(ctx);
  if (id.includes("/") || calls.length !== 1 || calls[0].id !== id || calls[0].name !== "restart-in-dir") throw new Error("restart-in-dir must be the sole, direct call in its assistant tool batch");
}
function expected(ctx: ExtensionContext, branch: any[]) {
  return nativeExpected(branch, ctx.sessionManager.buildSessionProjection().messages.length > 0, (provider, id) => ctx.modelRegistry.find(provider, id));
}
function errorText(error: unknown): string { return error instanceof Error ? error.message : String(error); }
class RestartCancelled extends Error {}

export default function restartInDir(pi: ExtensionAPI): void {
  let intent: Intent | undefined;
  let preparing = false;
  let interrupted = false;
  let incomingConsumed = false;
  let signalHandlersInstalled = false;
  let refusalTarget: string | undefined;
  const activeTools = new Set<string>();

  const notify = (ctx: ExtensionContext, text: string, level: "info" | "warning" | "error" = "error") => ctx.ui.notify(text, level);
  const release = (value: Intent) => value.actor?.release(value.sessionId, value.token);
  const cancel = (ctx: ExtensionContext, error: unknown) => {
    const previous = intent;
    intent = undefined;
    if (previous) {
      previous.controller.abort();
      try { invalidateRequest(previous.authority.directory); } catch (failure) { notify(ctx, `Could not invalidate restart request: ${errorText(failure)}`); }
      try { release(previous); } catch (failure) { notify(ctx, `Could not release restart lease: ${errorText(failure)}`); }
    }
    if (error instanceof RestartCancelled) { notify(ctx, "Restart cancelled; Pi remains here.", "info"); return; }
    notify(ctx, `Restart refused: ${errorText(error)}. ${manualInstructions(previous?.data.target ?? refusalTarget, previous?.source ?? ctx.sessionManager.getSessionFile(), ctx.cwd)}`);
  };
  const invalidateOnSignal = () => {
    interrupted = true;
    if (intent) {
      intent.controller.abort();
      // Do not cancel Pi's signal handler or force an exit. A clean signal exit must not restart.
      try { invalidateRequest(intent.authority.directory); } catch (error) { console.error(`pi-restart-in-dir: cannot invalidate signalled handoff: ${errorText(error)}`); }
    }
  };
  const removeSignalHandlers = () => {
    process.off("SIGTERM", invalidateOnSignal); process.off("SIGHUP", invalidateOnSignal);
    signalHandlersInstalled = false;
  };
  const validateAuthority = (ctx: ExtensionContext): Authority => {
    mainIdentity(ctx);
    const control = authority();
    if (!control.launch.interactive) throw new Error("Launcher invocation is not interactive");
    if (control.launch.unsupported.length) throw new Error(`Unsupported launcher options: ${control.launch.unsupported.join(", ")}`);
    if (interrupted) throw new Error("This process has received a shutdown signal");
    return control;
  };
  const prepare = async (directory: string, invocation: "command" | "tool", ctx: ExtensionContext, toolCallId?: string, toolSignal?: AbortSignal) => {
    if (intent || preparing) throw new Error("A restart handoff is already accepted or awaiting approval");
    preparing = true;
    try {
      if (typeof directory !== "string" || !directory.trim()) throw new Error("A directory argument is required");
      refusalTarget = undefined;
      const target = canonicalDirectory(directory, ctx.cwd);
      refusalTarget = target;
      const control = validateAuthority(ctx);
      const actor = mainIdentity(ctx);
      if (invocation === "tool") soleTool(ctx, toolCallId!);
      checkReady(ctx, actor, invocation === "tool", activeTools, toolCallId);
      const source = savedSource(ctx.sessionManager.getSessionFile(), ctx.cwd, ctx.sessionManager.getSessionId());
      const token = randomUUID();
      if (actor) {
        const lease = actor.acquire(ctx.sessionManager.getSessionId(), token);
        if (lease.ok !== true) throw new Error(lease.reason ?? "Could not acquire actor restart lease");
      }
      const controller = new AbortController();
      const signal = toolSignal ? AbortSignal.any([toolSignal, controller.signal]) : controller.signal;
      intent = {
        authority: control, source: source.source, sessionId: ctx.sessionManager.getSessionId(), token, actor, toolCallId,
        data: { version: 1, childId: control.launch.childId, sourceCwd: source.sourceCwd, target, invocation, continue: invocation === "tool" },
        resultObserved: false, committed: false, controller, signal,
      };
      // No await between lease acquisition and publication of the local pending intent.
      const value = intent;
      const leafId = ctx.sessionManager.getLeafId();
      const revalidate = () => {
        signal.throwIfAborted();
        if (intent !== value || ctx.sessionManager.getSessionId() !== value.sessionId) throw new Error("Active session changed during restart preparation");
        const fresh = validateAuthority(ctx);
        if (fresh.directory !== control.directory || fresh.launch.childId !== control.launch.childId) throw new Error("Launcher changed during restart preparation");
        if (mainIdentity(ctx) !== actor) throw new Error("Actor restart bridge changed");
        if (canonicalDirectory(target, ctx.cwd) !== target) throw new Error("Restart target changed");
        if (invocation === "tool") soleTool(ctx, toolCallId!);
        checkReady(ctx, actor, invocation === "tool", activeTools, toolCallId);
        const saved = savedSource(ctx.sessionManager.getSessionFile(), ctx.cwd, value.sessionId);
        if (saved.source !== value.source || saved.sourceCwd !== value.data.sourceCwd || ctx.sessionManager.getLeafId() !== leafId) throw new Error("Session source or selected branch changed during restart preparation");
      };
      revalidate();
      const status = await approval(control, "status", target, null, signal, revalidate);
      revalidate();
      if (status.state === "blocked") {
        const choice = await ctx.ui.select(`Allow direnv for this restart?\n\nTarget: ${JSON.stringify(target)}\nConfiguration: ${JSON.stringify(status.rc!.path)}\n\nAllowing trusts this file persistently. The next restart executes project code through direnv.`, ["Cancel", "Allow and restart"], { signal });
        revalidate();
        if (choice !== "Allow and restart") throw new RestartCancelled("Direnv approval cancelled by user; Pi remains here without a checkpoint");
        try {
          const allowed = await approval(control, "allow", target, status.rc, signal, revalidate);
          revalidate();
          if (allowed.state !== "allowed" || !isDeepStrictEqual(allowed.rc, status.rc)) throw new Error("Direnv approval changed or was not granted; retry for a fresh explicit choice");
        } catch (error) {
          throw new Error(`${errorText(error)}. Direnv permission may have changed; Pi has not checkpointed or restarted. No automatic retry or revoke.`);
        }
      }
      // Explicitly denied files retain direnv's normal skip behavior; never offer to override deny.
    } finally { preparing = false; }
  };
  const finalize = (ctx: ExtensionContext) => {
    const value = intent;
    if (!value || value.committed || preparing) return;
    try {
      value.signal.throwIfAborted();
      if (ctx.sessionManager.getSessionId() !== value.sessionId) throw new Error("Active session changed during handoff");
      const control = validateAuthority(ctx);
      if (control.directory !== value.authority.directory || control.launch.childId !== value.data.childId) throw new Error("Launcher changed during handoff");
      if (canonicalDirectory(value.data.target, ctx.cwd) !== value.data.target) throw new Error("Restart target changed");
      checkReady(ctx, value.actor, false, activeTools);
      const source = savedSource(ctx.sessionManager.getSessionFile(), ctx.cwd, value.sessionId);
      if (source.source !== value.source || source.sourceCwd !== value.data.sourceCwd) throw new Error("Session source changed");
      if (value.toolCallId) {
        if (!value.resultObserved) throw new Error("Accepted tool result was not observed");
        const result = ctx.sessionManager.getBranch().reverse().find((entry: any) => entry.type === "message" && entry.message.role === "toolResult" && entry.message.toolCallId === value.toolCallId) as any;
        if (!result || result.message.isError) throw new Error("Accepted tool result is not saved successfully");
        const saved = source.entries.find((entry) => entry.id === result.id);
        if (!isDeepStrictEqual(saved, JSON.parse(JSON.stringify(result)))) throw new Error("Accepted tool result is not durably saved");
      }
      pi.appendEntry(CHECKPOINT, value.data);
      const checkpointId = ctx.sessionManager.getLeafId();
      if (!checkpointId) throw new Error("Checkpoint did not select a session leaf");
      const entries = readSession(value.source);
      verifyCheckpoint(entries, checkpointId, value.data);
      const branch = savedBranch(entries, checkpointId);
      // Pi's JSONL writer omits undefined fields (e.g. toolResult.usage); compare its representation.
      if (!isDeepStrictEqual(branch, JSON.parse(JSON.stringify(ctx.sessionManager.getBranch())))) throw new Error("Selected source branch differs from saved checkpoint history");
      const request: Request = {
        ...value.data, source: value.source, checkpointId, expected: expected(ctx, branch),
        prompt: value.data.continue ? `Pi restarted in the requested directory ${value.data.target} (from ${value.data.sourceCwd}). Verify the current cwd, newly loaded project instructions, relevant environment and MCP routing before resuming your task. Historical transcript/tool results are not proof of the new workspace's state.` : null,
      };
      syncSession(value.source);
      if (interrupted) throw new Error("Shutdown signal invalidated the handoff");
      commitRequest(value.authority.directory, request);
      value.committed = true;
      // shutdown() may start exit immediately. All verification and atomic publication precede it.
      ctx.shutdown();
    } catch (error) { cancel(ctx, error); }
  };
  const validateIncoming = (ctx: ExtensionContext): Request => {
    const control = validateAuthority(ctx);
    const incoming = control.launch.incoming;
    if (!incoming || pi.getFlag(FLAG) !== incoming.childId) throw new Error("Missing or invalid required handoff flag");
    if (realpathSync(ctx.cwd) !== incoming.target || canonicalDirectory(incoming.target, ctx.cwd) !== incoming.target) throw new Error("Replacement cwd does not match the requested target");
    const header = ctx.sessionManager.getHeader();
    if (!header || realpathSync(header.cwd) !== incoming.target) throw new Error("Replacement session header cwd does not match target");
    const original = readSession(incoming.source);
    const sameDirectory = incoming.target === incoming.sourceCwd;
    if (sameDirectory) {
      const anchored = original.find((entry) => entry.id === incoming.checkpointId);
      if (anchored?.type !== "custom" || anchored.customType !== CHECKPOINT || !isDeepStrictEqual(anchored.data, checkpointData(incoming)) || realpathSync(original[0].cwd) !== incoming.sourceCwd) throw new Error("Saved restart checkpoint is missing or changed");
    } else verifyCheckpoint(original, incoming.checkpointId, checkpointData(incoming));
    if (sameDirectory ? header.id !== original[0].id : header.id === original[0].id) throw new Error("Replacement session identity does not match native resume/fork policy");
    const sessionFile = ctx.sessionManager.getSessionFile();
    if (!sessionFile || (sameDirectory ? realpathSync(sessionFile) !== incoming.source : realpathSync(sessionFile) === incoming.source || header.parentSession !== incoming.source)) throw new Error("Replacement did not use the exact native resume/fork source");
    const checkpoint = ctx.sessionManager.getBranch().find((entry) => entry.id === incoming.checkpointId) as any;
    if (checkpoint?.type !== "custom" || checkpoint.customType !== CHECKPOINT || !isDeepStrictEqual(checkpoint.data, checkpointData(incoming))) throw new Error("Replacement selected branch lost the restart checkpoint");
    return incoming;
  };

  pi.registerFlag(FLAG, { type: "string", description: "Private pi-restartable one-use handoff witness" });
  pi.registerCommand("restart-in-dir", {
    description: "Restart foreground Pi in an existing directory: /restart-in-dir <directory>",
    handler: async (args, ctx) => {
      if (intent || preparing) { notify(ctx, "A restart handoff is already accepted or awaiting approval"); return; }
      try { await prepare(args.trim(), "command", ctx); finalize(ctx); }
      catch (error) { cancel(ctx, error); }
    },
  });
  pi.registerTool({
    name: "restart-in-dir", label: "Restart in directory",
    description: "Request a graceful Pi restart in an existing directory. Main agent only; must be the sole direct tool call in a batch. Unapproved direnv requires explicit user UI consent; cancellation refuses without checkpointing. Return means handoff accepted, not restart succeeded. Same cwd resumes the saved session/swarm paused; different cwd forks with a new session ID and empty swarm. Queued hidden input may be lost and running user Bash interrupted.",
    exposure: "model-only", executionMode: "sequential",
    parameters: { type: "object", properties: { directory: { type: "string", minLength: 1, maxLength: 4096, description: "Existing directory, relative to current Pi cwd or absolute" } }, required: ["directory"], additionalProperties: false } as any,
    execute: async (id, params: { directory: string }, signal, _onUpdate, ctx) => {
      if (intent || preparing) throw new Error("A restart handoff is already accepted or awaiting approval");
      try {
        await prepare(params.directory, "tool", ctx, id, signal);
        return { content: [{ type: "text", text: "Restart handoff accepted. Pi will checkpoint the saved result and gracefully shut down; replacement startup may still fail." }], details: { accepted: true }, terminate: true };
      } catch (error) {
        cancel(ctx, error);
        throw new Error(`${error instanceof RestartCancelled ? "Restart cancelled" : "Restart refused"}: ${errorText(error)}`);
      }
    },
  });
  pi.on("tool_call", (event, ctx) => {
    if (intent) return { block: true, reason: "Restart handoff accepted; no more old-process tools may execute" };
    const calls = assistantCalls(ctx);
    if (calls.some((call) => call.name === "restart-in-dir") && calls.length !== 1) return { block: true, reason: "Mixed restart-in-dir batch refused, including sibling calls" };
    if (event.toolName === "restart-in-dir") {
      try {
        if (event.parentToolCallId) throw new Error("Nested restart calls are not allowed");
        mainIdentity(ctx); soleTool(ctx, event.toolCallId);
      } catch (error) { return { block: true, reason: errorText(error) }; }
    }
  });
  pi.on("tool_execution_start", (event) => { activeTools.add(event.toolCallId); });
  pi.on("tool_execution_end", (event) => { activeTools.delete(event.toolCallId); });
  pi.on("tool_result", (event, ctx) => {
    if (intent?.toolCallId === event.toolCallId) {
      if (event.isError) cancel(ctx, new Error("Accepted restart tool result failed"));
      else intent.resultObserved = true;
    }
  });
  pi.on("agent_settled", (_event, ctx) => { finalize(ctx); });
  pi.on("session_start", (_event, ctx) => {
    activeTools.clear();
    if (!signalHandlersInstalled) {
      process.on("SIGTERM", invalidateOnSignal); process.on("SIGHUP", invalidateOnSignal);
      signalHandlersInstalled = true;
    }
    if (pi.getFlag(FLAG) !== undefined) {
      try {
        const incoming = validateIncoming(ctx);
        notify(ctx, `Pi restarted in ${incoming.target}. ${incoming.target === incoming.sourceCwd ? "Session ID retained; saved swarm restored paused." : "New session ID; no subagents migrated."}`, "info");
      } catch (error) { notify(ctx, `Restart restoration guard: ${errorText(error)}. Automatic continuation will be withheld.`); }
    }
  });
  pi.on("input", async (event, ctx) => {
    if (!event.text.startsWith(MARKER)) return;
    if (incomingConsumed) { notify(ctx, "Restart continuation marker already consumed"); return { action: "handled" }; }
    try {
      // Actor SDK sessions can share this process/control directory. Never let a child consume main's intent.
      mainIdentity(ctx);
      const control = validateAuthority(ctx);
      incomingConsumed = true;
      // Claim before restoration/marker/flag/auth/IC checks: refused main input still consumes this intent.
      if (!consumeIncoming(control)) throw new Error("Restart continuation marker already consumed in this launcher child");
      const incoming = validateIncoming(ctx);
      if (!incoming.continue || event.text !== MARKER + incoming.childId || event.source !== "interactive" || event.images?.length) throw new Error("Invalid restart continuation marker");
      if (!ctx.isIdle() || ctx.hasPendingMessages()) throw new Error("Replacement has other observed work pending");
      const wanted = incoming.expected;
      const native = expected(ctx, ctx.sessionManager.getBranch());
      // null fields deliberately allow native target defaults when history had no saved selection.
      if (wanted.model && !isDeepStrictEqual(native.model, wanted.model)) throw new Error("Selected branch model restoration changed (including a missing virtual selection)");
      if (wanted.model && (!ctx.model || ctx.model.provider !== wanted.model.provider || ctx.model.id !== wanted.model.modelId)) throw new Error("Target model restoration fell back to another model");
      if (wanted.thinkingLevel !== null && (native.thinkingLevel !== wanted.thinkingLevel || pi.getThinkingLevel() !== wanted.thinkingLevel)) throw new Error("Target thinking level was changed or clamped");
      if (!ctx.model || !ctx.modelRegistry.find(ctx.model.provider, ctx.model.id)) throw new Error("Target model is unavailable");
      if (!ctx.modelRegistry.hasConfiguredAuth(ctx.model)) throw new Error("Target model authentication is not configured");
      const authenticatedModel = { provider: ctx.model.provider, id: ctx.model.id };
      const auth = await ctx.modelRegistry.getApiKeyAndHeaders(ctx.model);
      if (!auth.ok) throw new Error("Target model authentication is unavailable");
      // Authentication can await; recheck the selected branch and public/actor readiness afterward.
      validateIncoming(ctx);
      checkReady(ctx, mainIdentity(ctx), false, activeTools);
      const afterAuth = expected(ctx, ctx.sessionManager.getBranch());
      if (wanted.model && (!isDeepStrictEqual(afterAuth.model, wanted.model) || ctx.model?.provider !== wanted.model.provider || ctx.model?.id !== wanted.model.modelId)) throw new Error("Selected model changed during authentication");
      if (ctx.model?.provider !== authenticatedModel.provider || ctx.model?.id !== authenticatedModel.id) throw new Error("Target model changed during authentication");
      if (wanted.thinkingLevel !== null && (afterAuth.thinkingLevel !== wanted.thinkingLevel || pi.getThinkingLevel() !== wanted.thinkingLevel)) throw new Error("Thinking level changed during authentication");
      const requestId = randomUUID();
      const sessionId = ctx.sessionManager.getSessionId();
      const leafId = ctx.sessionManager.getLeafId();
      let response: any;
      let responses = 0;
      const off = pi.events.on(HEALTH_RESPONSE, (data: any) => {
        if (data?.requestId === requestId) { response = data; responses++; }
      });
      try { pi.events.emit(HEALTH_REQUEST, { requestId, sessionId, leafId }); } finally { off(); }
      if (responses !== 1 || response?.version !== 2 || response.ok !== true || response.sessionId !== sessionId || response.leafId !== leafId) throw new Error("Compatible validated infinite-context v2 health was not established");
      return { action: "transform", text: incoming.prompt!, images: undefined };
    } catch (error) {
      notify(ctx, `Restart continuation withheld: ${errorText(error)}. Verify restoration before continuing manually.`);
      return { action: "handled" };
    }
  });
  pi.on("session_shutdown", () => {
    if (intent) {
      intent.controller.abort();
      try { release(intent); } catch (error) { console.error(`pi-restart-in-dir: lease release failed: ${errorText(error)}`); }
    }
    // A committed dying process still needs direct-child signal invalidation during cleanup.
    if (!intent?.committed) removeSignalHandlers();
  });
}
