// Regression tests for patches/pi-bash-async-reload.patch.
// Run: BASH_ASYNC_DIR=<patched package> node --experimental-transform-types --import ./register.mjs --test reload.test.mjs
import assert from "node:assert/strict";
import { existsSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { pathToFileURL } from "node:url";

process.env.PI_BASH_ASYNC_SYNC_WINDOW_MS = "0";
const dir = process.env.BASH_ASYNC_DIR;
assert.ok(dir, "BASH_ASYNC_DIR must point at the patched bash-async package");
let generation = 0;
// A fresh index module per instance, like Pi re-evaluating extensions on /reload.
const load = async () => (await import(`${pathToFileURL(join(dir, "index.ts")).href}?g=${++generation}`)).default;

function instance(factory) {
  const handlers = new Map();
  const tools = new Map();
  const sent = [];
  factory({
    on: (name, fn) => handlers.set(name, [...(handlers.get(name) ?? []), fn]),
    registerTool: (tool) => tools.set(tool.name, tool),
    sendMessage: (message, options) => sent.push({ message, options }),
    events: { on: () => () => {}, emit: () => {} },
  });
  const ctx = {
    mode: "print",
    hasUI: false,
    cwd: process.cwd(),
    sessionManager: { getSessionId: () => "session-1", getSessionFile: () => undefined },
    isIdle: () => true,
    ui: { setWidget() {} },
  };
  const emit = async (name, event = {}) => {
    for (const fn of handlers.get(name) ?? []) await fn(event, ctx);
  };
  const start = (command) => tools.get("bash_async").execute("call", { action: "start", command }, undefined, undefined, ctx);
  return { sent, emit, start };
}

const until = async (predicate, ms = 5000) => {
  for (const end = Date.now() + ms; Date.now() < end; await new Promise((r) => setTimeout(r, 50))) if (predicate()) return true;
  return false;
};
const completions = (sent) => sent.filter((s) => s.message.customType === "bash-async-completion");

test("/reload hands a running job to the next instance, which delivers its completion", async () => {
  const old = instance(await load());
  await old.emit("session_start");
  const started = await old.start("sleep 0.5; echo survived-reload");
  assert.equal(started.details.status, "running");
  await old.emit("session_shutdown", { reason: "reload" });

  const next = instance(await load());
  await next.emit("session_start");
  assert.ok(await until(() => completions(next.sent).length === 1), "completion delivered by the new instance");
  assert.match(completions(next.sent)[0].message.content, /survived-reload/);
  assert.equal(old.sent.length, 0, "the retired instance sends nothing");
  await next.emit("session_shutdown", { reason: "quit" });
});

test("quit still kills running jobs", async () => {
  const marker = join(mkdtempSync(join(tmpdir(), "bash-async-test-")), "marker");
  const pi = instance(await load());
  await pi.emit("session_start");
  await pi.start(`sleep 0.5; touch ${marker}`);
  await pi.emit("session_shutdown", { reason: "quit" });
  await new Promise((r) => setTimeout(r, 1000));
  assert.equal(existsSync(marker), false);
  assert.equal(completions(pi.sent).length, 0);
});
