import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import {
  applyFastToPayload,
  fastState,
  getFastController,
  registerFastController,
  type FastController,
  type FastModel,
  type FastState,
} from "./fast-control.ts";

const STATUS_KEY = "fast";

function modelFromContext(ctx: ExtensionContext): FastModel | undefined {
  return ctx.model ? { provider: ctx.model.provider, id: ctx.model.id } : undefined;
}

function describeState(state: FastState): string {
  const desired = state.desired ? "on" : "off";
  const effective = state.effective ? "on" : "off";
  const model = state.model ? `${state.model.provider}/${state.model.id}` : "no active model";
  const reason = state.desired && !state.effective ? `; unsupported model: ${model}` : `; model: ${model}`;
  return `Fast desired ${desired}; effective ${effective}${reason}`;
}

export default function codexFast(pi: ExtensionAPI): void {
  let active = false;
  let desired = false;
  let model: FastModel | undefined;
  let latestContext: ExtensionContext | undefined;
  let sessionId: string | undefined;
  let unregister: (() => void) | undefined;
  let published: string | undefined;

  const state = (): FastState => fastState(desired, model);

  const publish = (ctx: ExtensionContext | undefined = latestContext, force = false): void => {
    if (!ctx?.hasUI) return;
    const value = state().effective ? "fast" : undefined;
    if (!force && value === published) return;
    ctx.ui.setStatus(STATUS_KEY, value);
    published = value;
  };

  const controller: FastController = {
    getState: state,
    setDesired: (enabled) => {
      if (!active) throw new Error("Fast controller is no longer active");
      desired = enabled;
      publish();
      return state();
    },
  };

  pi.on("session_start", (_event, ctx) => {
    unregister?.();
    active = true;
    desired = false;
    model = modelFromContext(ctx);
    latestContext = ctx;
    published = undefined;
    sessionId = ctx.sessionManager.getSessionId();
    unregister = registerFastController(sessionId, controller);
    publish(ctx, true);
  });

  pi.on("model_select", (event, ctx) => {
    model = { provider: event.model.provider, id: event.model.id };
    latestContext = ctx;
    publish(ctx);
  });

  pi.on("before_provider_request", (event, ctx) => {
    model = modelFromContext(ctx);
    latestContext = ctx;
    publish(ctx);
    return applyFastToPayload(event.payload, state());
  });

  pi.on("session_shutdown", (_event, ctx) => {
    const ownsCurrentRegistration = getFastController(sessionId) === controller;
    active = false;
    unregister?.();
    unregister = undefined;
    if (ownsCurrentRegistration && ctx.hasUI && published !== undefined) ctx.ui.setStatus(STATUS_KEY, undefined);
    published = undefined;
    latestContext = undefined;
    sessionId = undefined;
    model = undefined;
    desired = false;
  });

  pi.registerCommand("fast", {
    description: "Toggle or control Codex Fast mode for this session: /fast [toggle|on|off|status]",
    handler: async (args, ctx) => {
      const action = args.trim().toLowerCase();
      let enabled: boolean | undefined;
      if (action === "" || action === "toggle") enabled = !state().desired;
      else if (action === "on" || action === "off") enabled = action === "on";

      if (enabled !== undefined) {
        const result = controller.setDesired(enabled);
        const level = result.desired && !result.effective ? "warning" : "info";
        ctx.ui.notify(`${describeState(result)}. Changes apply to the next provider request.`, level);
        return;
      }
      if (action === "status") {
        ctx.ui.notify(describeState(state()), "info");
        return;
      }
      ctx.ui.notify("Usage: /fast [toggle|on|off|status]", "error");
    },
  });
}
