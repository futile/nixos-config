// Regression tests for patches/pi-bash-async-command-display.patch.
// Run: BASH_ASYNC_DIR=<patched package> node --experimental-transform-types --import ./register.mjs --test command-display.test.mjs
import assert from "node:assert/strict";
import { join } from "node:path";
import { test } from "node:test";
import { pathToFileURL } from "node:url";

process.env.PI_BASH_ASYNC_SYNC_WINDOW_MS = "0";
const dir = process.env.BASH_ASYNC_DIR;
assert.ok(dir, "BASH_ASYNC_DIR must point at the patched bash-async package");
const load = (file) => import(pathToFileURL(join(dir, file)).href);
const { defaultJobTitle, createRunningJobsWidget } = await load("running-jobs-widget.ts");
const { renderCallText } = await load("render.ts");

test("defaultJobTitle is the one-line command, clipped", () => {
  assert.equal(defaultJobTitle("cd /x &&\n  just build"), "cd /x && just build");
  const long = defaultJobTitle(`echo ${"a".repeat(100)}`);
  assert.equal(long.length, 60);
  assert.ok(long.endsWith("..."));
  assert.equal(defaultJobTitle("  "), "bash job");
});

test("start without a title uses the command as the title", async () => {
  const tools = new Map();
  const handlers = new Map();
  (await load("index.ts")).default({
    on: (name, fn) => handlers.set(name, [...(handlers.get(name) ?? []), fn]),
    registerTool: (tool) => tools.set(tool.name, tool),
    sendMessage: () => {},
    events: { on: () => () => {}, emit: () => {} },
  });
  const ctx = {
    mode: "print",
    cwd: process.cwd(),
    sessionManager: { getSessionId: () => "s", getSessionFile: () => undefined },
    isIdle: () => true,
    ui: { setWidget() {}, setStatus() {} },
  };
  const result = await tools.get("bash_async").execute("c", { action: "start", command: "cd / && true" }, undefined, undefined, ctx);
  assert.equal(result.details.title, "cd / && true");
  for (const fn of handlers.get("session_shutdown") ?? []) await fn({ reason: "quit" }, ctx);
});

test("call row shows the command, collapsed to three lines unless expanded", () => {
  const command = "a\nb\nc\nd\ne";
  assert.equal(renderCallText("start", "t", command).text, "bash_async start: t\n$ a\nb\nc\n… (2 more lines)");
  assert.equal(renderCallText("start", undefined, command, true).text, "bash_async start\n$ a\nb\nc\nd\ne");
  assert.equal(renderCallText("kill", undefined, undefined).text, "bash_async kill");
});

test("widget shows the command after an explicit title, but not a second copy of a default title", () => {
  const job = (title, command) => ({ id: "j", status: "running", title, command, queuedAt: 0, startedAt: 0 });
  const render = (j) =>
    createRunningJobsWidget({ requestRender() {} }, { fg: (_c, s) => s }, { getRunningJobs: () => [j], now: () => 5_000 })
      .render(120)[0];
  assert.equal(render(job("build", "nix build .#x")), "bash_async · build · $ nix build .#x · 5s");
  assert.equal(render(job(defaultJobTitle("nix build .#x"), "nix build .#x")), "bash_async · nix build .#x · 5s");
});
