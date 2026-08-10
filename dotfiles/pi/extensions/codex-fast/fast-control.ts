export interface FastModel {
  provider: string;
  id: string;
}

export interface FastState {
  desired: boolean;
  effective: boolean;
  model?: FastModel;
}

export interface FastController {
  getState(): FastState;
  setDesired(enabled: boolean): FastState;
}

interface FastRegistryEntry {
  owner: symbol;
  controller: FastController;
}

interface FastRegistry {
  version: 1;
  controllers: Map<string, FastRegistryEntry>;
}

const FAST_REGISTRY_KEY = Symbol.for("futile.pi.codex-fast.registry.v1");

function registry(): FastRegistry {
  const globals = globalThis as Record<symbol, unknown>;
  const existing = globals[FAST_REGISTRY_KEY] as FastRegistry | undefined;
  if (existing?.version === 1 && existing.controllers instanceof Map) return existing;
  const created: FastRegistry = { version: 1, controllers: new Map() };
  globals[FAST_REGISTRY_KEY] = created;
  return created;
}

export function isFastEligibleModel(model: FastModel | undefined): boolean {
  return model?.provider === "openai-codex" && /^gpt-5\.(?:4|5|6)(?:$|[-.])/i.test(model.id);
}

export function fastState(desired: boolean, model: FastModel | undefined): FastState {
  return {
    desired,
    effective: desired && isFastEligibleModel(model),
    ...(model ? { model: { provider: model.provider, id: model.id } } : {}),
  };
}

/** Return a replacement payload only when Fast is effective and the payload is object-like. */
export function applyFastToPayload(payload: unknown, state: FastState): unknown | undefined {
  if (!state.effective || payload === null || typeof payload !== "object" || Array.isArray(payload)) return undefined;
  return { ...(payload as Record<string, unknown>), service_tier: "priority" };
}

/**
 * Register one live session controller. Cleanup is owner-guarded so a stale extension
 * runtime cannot remove the replacement controller installed during reload.
 */
export function registerFastController(sessionId: string, controller: FastController): () => void {
  const owner = Symbol(`codex-fast:${sessionId}`);
  const controllers = registry().controllers;
  controllers.set(sessionId, { owner, controller });
  return () => {
    if (controllers.get(sessionId)?.owner === owner) controllers.delete(sessionId);
  };
}

export function getFastController(sessionId: string | undefined): FastController | undefined {
  return sessionId ? registry().controllers.get(sessionId)?.controller : undefined;
}
