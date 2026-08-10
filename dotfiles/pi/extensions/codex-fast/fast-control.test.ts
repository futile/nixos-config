import assert from "node:assert/strict";
import { test } from "node:test";
import {
  applyFastToPayload,
  fastState,
  getFastController,
  isFastEligibleModel,
  registerFastController,
  type FastController,
} from "./fast-control.ts";

test("Fast eligibility is limited to openai-codex GPT-5.4 through GPT-5.6 families", () => {
  for (const id of ["gpt-5.4", "gpt-5.4-codex", "gpt-5.5", "gpt-5.6-sol", "gpt-5.6-luna"]) {
    assert.equal(isFastEligibleModel({ provider: "openai-codex", id }), true, id);
  }
  for (const model of [
    { provider: "openai", id: "gpt-5.6-sol" },
    { provider: "openai-codex", id: "gpt-5.3-codex" },
    { provider: "openai-codex", id: "gpt-5.7" },
    { provider: "anthropic", id: "claude-opus-4-6" },
    undefined,
  ]) {
    assert.equal(isFastEligibleModel(model), false, JSON.stringify(model));
  }
});

test("request rewriting adds only the priority service tier when Fast is effective", () => {
  const eligible = fastState(true, { provider: "openai-codex", id: "gpt-5.6-sol" });
  const original = { model: "gpt-5.6-sol", input: [], reasoning: { effort: "high" }, verbosity: "medium" };
  assert.deepEqual(applyFastToPayload(original, eligible), { ...original, service_tier: "priority" });
  assert.deepEqual(original, { model: "gpt-5.6-sol", input: [], reasoning: { effort: "high" }, verbosity: "medium" });

  assert.equal(applyFastToPayload(original, fastState(false, eligible.model)), undefined);
  assert.equal(
    applyFastToPayload(original, fastState(true, { provider: "openai", id: "gpt-5.6-sol" })),
    undefined,
  );
  assert.equal(applyFastToPayload(null, eligible), undefined);
  assert.equal(applyFastToPayload(["not", "an", "object"], eligible), undefined);
});

test("registry cleanup cannot remove a replacement controller for the same session", () => {
  const state = fastState(false, { provider: "openai-codex", id: "gpt-5.6-sol" });
  const first: FastController = { getState: () => state, setDesired: () => state };
  const second: FastController = { getState: () => state, setDesired: () => state };
  const cleanupFirst = registerFastController("session-replaced", first);
  assert.equal(getFastController("session-replaced"), first);

  const cleanupSecond = registerFastController("session-replaced", second);
  assert.equal(getFastController("session-replaced"), second);
  cleanupFirst();
  assert.equal(getFastController("session-replaced"), second);
  cleanupSecond();
  assert.equal(getFastController("session-replaced"), undefined);
});
