// Regression tests for patches/pi-bash-async-jobs-signal.patch.
// Run: BASH_ASYNC_DIR=<patched package> node --experimental-transform-types --import ./register.mjs --test jobs-signal.test.mjs
import assert from "node:assert/strict";
import { join } from "node:path";
import { test } from "node:test";
import { pathToFileURL } from "node:url";

process.env.PI_BASH_ASYNC_SYNC_WINDOW_MS = "0";
const dir = process.env.BASH_ASYNC_DIR;
assert.ok(dir, "BASH_ASYNC_DIR must point at the patched bash-async package");
const mod = await import(pathToFileURL(join(dir, "index.ts")).href);

function instance(mode, m = mod) {
  const handlers = new Map();
  const tools = new Map();
  const listeners = new Map();
  const emitted = [];
  const statuses = [];
  m.default({
    on: (name, fn) => handlers.set(name, [...(handlers.get(name) ?? []), fn]),
    registerTool: (tool) => tools.set(tool.name, tool),
    sendMessage: () => {},
    events: {
      on: (channel, fn) => {
        listeners.set(channel, fn);
        return () => listeners.delete(channel);
      },
      emit: (channel, data) => {
        if (channel === m.JOBS_EVENT) emitted.push(data);
      },
    },
  });
  const ctx = {
    mode,
    hasUI: mode === "tui",
    cwd: process.cwd(),
    sessionManager: { getSessionId: () => "session-1", getSessionFile: () => undefined },
    isIdle: () => true,
    ui: { setWidget() {}, setStatus: (key, text) => statuses.push([key, text]) },
  };
  const emit = async (name, event = {}) => {
    for (const fn of handlers.get(name) ?? []) await fn(event, ctx);
  };
  const start = (command) =>
    tools.get("bash_async").execute("call", { action: "start", command, title: "t" }, undefined, undefined, ctx);
  return { emitted, statuses, listeners, emit, start };
}

const until = async (predicate, ms = 5000) => {
  for (const end = Date.now() + ms; Date.now() < end; await new Promise((r) => setTimeout(r, 50))) if (predicate()) return true;
  return false;
};

test("jobsIndicator shows the glyph alone for one job and a count for more", () => {
  assert.equal(mod.jobsIndicator(1), "⏳");
  assert.equal(mod.jobsIndicator(3), "⏳3");
});

test("job transitions are announced on the bus, answered on request, and mirrored to the TUI status", async () => {
  const pi = instance("tui");
  await pi.emit("session_start");
  await pi.start("sleep 0.3");
  await pi.start("sleep 0.3");
  assert.ok(await until(() => pi.emitted.some((u) => u.running === 2)), "two unsettled jobs announced");
  assert.deepEqual(pi.statuses.at(-1), ["bash-async", "⏳2"]);
  const update = pi.emitted.find((u) => u.running === 2);
  assert.equal(update.version, 1);
  assert.equal(update.jobs.length, 2);
  assert.equal(update.jobs[0].title, "t");

  assert.ok(await until(() => pi.emitted.at(-1)?.running === 0), "settled jobs announced as zero");
  assert.deepEqual(pi.statuses.at(-1), ["bash-async", undefined]);

  const before = pi.emitted.length;
  pi.listeners.get(mod.JOBS_REQUEST_EVENT)();
  assert.equal(pi.emitted.length, before + 1, "a request re-announces even without a change");
  await pi.emit("session_shutdown", { reason: "quit" });
  assert.equal(pi.listeners.has(mod.JOBS_REQUEST_EVENT), false, "request listener removed on shutdown");
});

test("headless sessions announce on the bus without touching the UI", async () => {
  const pi = instance("print");
  await pi.emit("session_start");
  await pi.start("sleep 0.2");
  assert.ok(await until(() => pi.emitted.some((u) => u.running === 1)));
  assert.equal(pi.statuses.length, 0);
  await pi.emit("session_shutdown", { reason: "quit" });
  assert.equal(pi.emitted.at(-1).running, 0, "killed jobs are announced as settled");
});

test("/reload: the adopting instance announces the handed-over job and sets its own status", async () => {
  // A fresh module per instance, like Pi re-evaluating extensions on /reload.
  const fresh = await import(`${pathToFileURL(join(dir, "index.ts")).href}?reload=1`);
  const old = instance("tui");
  await old.emit("session_start");
  await old.start("sleep 2");
  assert.ok(await until(() => old.emitted.some((u) => u.running === 1)));
  await old.emit("session_shutdown", { reason: "reload" });
  const oldCount = old.emitted.length;

  const next = instance("tui", fresh);
  await next.emit("session_start");
  assert.ok(await until(() => next.emitted.some((u) => u.running === 1)), "adopted job announced on the new bus");
  assert.deepEqual(next.statuses.at(-1), ["bash-async", "⏳"]);
  await next.emit("session_shutdown", { reason: "quit" });
  assert.equal(old.emitted.length, oldCount, "the retired instance stays silent");
});
