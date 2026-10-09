import assert from "node:assert/strict";
import { test } from "node:test";
import { chmodSync, lstatSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, realpathSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { authority, canonicalDirectory, checkpointData, commitRequest, consumeIncoming, invalidateRequest, manualInstructions, nativeExpected, readSession, savedBranch, savedSource, validateLaunch, validateRequest, verifyCheckpoint, CHECKPOINT, type Request } from "./handoff.ts";

const request = (): Request => ({ version: 1, childId: "child-1", sourceCwd: "/source", target: "/target", invocation: "tool", continue: true, source: "/source/session.jsonl", checkpointId: "entry-1", expected: { model: { provider: "fake", modelId: "a" }, thinkingLevel: "low" }, prompt: "Verify cwd before resuming" });

test("protocol rejects extra keys, malformed values, unbounded input and accidental secret-bearing options", () => {
  validateRequest(request());
  for (const invalid of [
    { ...request(), command: "exit" }, { ...request(), version: 2 }, { ...request(), target: "relative" },
    { ...request(), childId: "foo/bar" }, { ...request(), prompt: "x".repeat(16385) },
    { ...request(), expected: { model: null, thinkingLevel: "bogus" } },
    { ...request(), expected: { model: { provider: "fake", modelId: "a", apiKey: "secret" }, thinkingLevel: null } },
    { ...request(), continue: false }, { ...request(), source: "/source" },
  ]) assert.throws(() => validateRequest(invalid));
  const launch = { version: 2, childId: "child-2", launcherPid: 42, unsupported: ["--api-key"], interactive: true, incoming: request() };
  validateLaunch(launch);
  for (const invalid of [{ ...launch, secret: "no" }, { ...launch, unsupported: ["--api-key=secret"] }, { ...launch, launcherPid: 1 }, { ...launch, incoming: { ...request(), extra: true } }]) assert.throws(() => validateLaunch(invalid));
});

test("authority requires live direct parent, private canonical directory and bound child metadata", () => {
  const directory = mkdtempSync(join(tmpdir(), "pi-restart-authority-"));
  const env = { PI_RESTARTABLE_CONTROL_DIR: directory, PI_RESTARTABLE_CHILD_ID: "child", PI_RESTARTABLE_LAUNCHER_PID: String(process.ppid) };
  const file = join(directory, "launch.json");
  const launch = { version: 2, childId: "child", launcherPid: process.ppid, unsupported: [], interactive: true, incoming: null };
  try {
    writeFileSync(file, JSON.stringify(launch), { mode: 0o600 });
    assert.equal(authority(env).launch.childId, "child");
    assert.throws(() => authority({ ...env, PI_RESTARTABLE_LAUNCHER_PID: String(process.pid) }), /direct child/);
    assert.throws(() => authority({ ...env, PI_RESTARTABLE_CHILD_ID: "stale" }), /Stale/);
    assert.throws(() => authority({}), /No live/);
    chmodSync(file, 0o644); assert.throws(() => authority(env), /private/);
    chmodSync(file, 0o600); chmodSync(directory, 0o755); assert.throws(() => authority(env), /private/);
  } finally { rmSync(directory, { recursive: true, force: true }); }
});

test("canonical directories preserve metacharacters and alias equality; manual instructions shell-quote", () => {
  const root = mkdtempSync(join(tmpdir(), "pi-restart-paths-"));
  try {
    const target = join(root, "a ' ; $(touch nope)"); mkdirSync(target);
    symlinkSync(target, join(root, "alias"));
    assert.equal(canonicalDirectory("alias", root), realpathSync(target));
    assert.equal(canonicalDirectory(".", target), target);
    writeFileSync(join(root, "file"), "x");
    assert.throws(() => canonicalDirectory("file", root), /not a directory/);
    assert.throws(() => canonicalDirectory("missing", root));
    const instructions = manualInstructions(target, join(root, "s ' .jsonl"), root);
    assert.ok(instructions.includes("'\\''")); assert.ok(instructions.includes("--fork"));
    assert.match(instructions, /last saved state only.*unsaved \/tree/);
    assert.match(manualInstructions(root, "/saved.jsonl", root), /--session/);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("selected branch, not file latest or runtime state, determines native physical and virtual settings", () => {
  const a = { type: "model_change", provider: "fake", modelId: "a" };
  const low = { type: "thinking_level_change", thinkingLevel: "low" };
  const response = { type: "message", message: { role: "assistant", provider: "fake", model: "answer", api: "fake-api" } };
  const find = (_provider: string, id: string) => ({ api: id === "virtual" ? "pi-virtual" : "fake-api" });
  assert.deepEqual(nativeExpected([a, low], true, find), { model: { provider: "fake", modelId: "a" }, thinkingLevel: "low" });
  assert.deepEqual(nativeExpected([a, low, response], true, find).model, { provider: "fake", modelId: "answer" });
  const virtual = { ...a, modelId: "virtual" };
  assert.deepEqual(nativeExpected([virtual, response], true, find).model, { provider: "fake", modelId: "virtual" });
  assert.deepEqual(nativeExpected([virtual, response], true, () => undefined).model, { provider: "fake", modelId: "answer" });
  assert.deepEqual(nativeExpected([virtual, response, a], true, find).model, { provider: "fake", modelId: "a" });
  assert.deepEqual(nativeExpected([a, low], false, find), { model: null, thinkingLevel: null });
  assert.deepEqual(nativeExpected([], true, find), { model: null, thinkingLevel: null });
});

test("checkpoint anchors historical tree leaf, verifies exact saved entry and canonical header without rewriting", () => {
  const root = mkdtempSync(join(tmpdir(), "pi-restart-session-"));
  try {
    symlinkSync(root, join(root, "alias"));
    const file = join(root, "session.jsonl");
    const data = { ...checkpointData(request()), sourceCwd: root, target: root };
    const header = { type: "session", id: "session-1", cwd: join(root, "alias") };
    const a = { type: "model_change", id: "a", parentId: null, provider: "fake", modelId: "a" };
    const latest = { ...a, id: "latest", parentId: "a", modelId: "b" };
    const checkpoint = { type: "custom", id: "checkpoint", parentId: "a", customType: CHECKPOINT, data };
    const entries = [header, a, latest, checkpoint];
    const text = entries.map((entry) => JSON.stringify(entry)).join("\n") + "\n";
    writeFileSync(file, text);
    const source = savedSource(file, root, "session-1");
    assert.equal(source.sourceCwd, root); assert.equal(readFileSync(file, "utf8"), text);
    verifyCheckpoint(source.entries, "checkpoint", data);
    assert.deepEqual(savedBranch(entries, "checkpoint"), [a, checkpoint]);
    assert.throws(() => verifyCheckpoint(entries, "wrong", data));
    assert.throws(() => savedBranch(entries, "missing"));
    assert.throws(() => savedBranch([header, { ...a, parentId: "a" }], "a"), /Cyclic/);
    assert.throws(() => savedBranch([header, a, a], "a"), /duplicate/);
    assert.throws(() => savedSource(file, root, "other"));
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("committed request is atomic/private and invalidation is idempotent", () => {
  const directory = mkdtempSync(join(tmpdir(), "pi-restart-commit-"));
  try {
    commitRequest(directory, request());
    const file = join(directory, "request.json");
    assert.deepEqual(JSON.parse(readFileSync(file, "utf8")), request());
    assert.equal(lstatSync(file).mode & 0o777, 0o600);
    invalidateRequest(directory); invalidateRequest(directory);
    assert.throws(() => readFileSync(file));
  } finally { rmSync(directory, { recursive: true, force: true }); }
});

test("source ownership mismatch refuses before handoff (mocked UID, no foreign-owner file creation)", (t) => {
  const uid = process.getuid?.();
  if (uid === undefined) { t.skip("Unix UID API unavailable"); return; }
  const root = mkdtempSync(join(tmpdir(), "pi-restart-owner-"));
  const file = join(root, "session.jsonl");
  try {
    writeFileSync(file, JSON.stringify({ type: "session", id: "owned", cwd: root }) + "\n");
    assert.equal(readSession(file)[0].id, "owned");
    const changedUid = t.mock.method(process as typeof process & { getuid: () => number }, "getuid", () => uid + 1);
    try { assert.throws(() => savedSource(file, root, "owned"), /owned regular saved JSONL/); }
    finally { changedUid.mock.restore(); }
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("private atomic consumption receipts are per current and incoming child, retained across new readers", () => {
  const directory = mkdtempSync(join(tmpdir(), "pi-restart-consumed-"));
  const launch = { version: 2 as const, childId: "current-child", launcherPid: process.ppid, unsupported: [], interactive: true, incoming: request() };
  try {
    assert.equal(consumeIncoming({ directory, launch }), true);
    assert.equal(consumeIncoming({ directory, launch: JSON.parse(JSON.stringify(launch)) }), false);
    const [file] = readdirSync(directory);
    assert.match(file, /^consumed\.[a-f0-9]{64}\.json$/);
    assert.equal(lstatSync(join(directory, file)).mode & 0o777, 0o600);
    assert.equal(lstatSync(join(directory, file)).nlink, 1);
    assert.deepEqual(JSON.parse(readFileSync(join(directory, file), "utf8")), { version: 1, childId: "current-child", incomingChildId: "child-1" });
    assert.equal(consumeIncoming({ directory, launch: { ...launch, childId: "fresh-child", incoming: { ...request(), childId: "fresh-incoming" } } }), true);
    assert.equal(consumeIncoming({ directory, launch: { ...launch, incoming: { ...request(), childId: "different-incoming" } } }), true);
    assert.equal(readdirSync(directory).some((entry) => entry.endsWith(".tmp")), false);
    chmodSync(join(directory, file), 0o644);
    assert.throws(() => consumeIncoming({ directory, launch }), /private/);
  } finally { rmSync(directory, { recursive: true, force: true }); }
});

test("failed exclusive receipt publication never replaces a malformed witness or leaks temporary links", () => {
  const directory = mkdtempSync(join(tmpdir(), "pi-restart-consume-failure-"));
  const launch = { version: 2 as const, childId: "current", launcherPid: process.ppid, unsupported: [], interactive: true, incoming: request() };
  try {
    assert.equal(consumeIncoming({ directory, launch }), true);
    const [file] = readdirSync(directory);
    writeFileSync(join(directory, file), "corrupt witness\n");
    assert.throws(() => consumeIncoming({ directory, launch }));
    assert.equal(readFileSync(join(directory, file), "utf8"), "corrupt witness\n");
    assert.deepEqual(readdirSync(directory), [file]);
    assert.equal(lstatSync(join(directory, file)).nlink, 1);
  } finally { rmSync(directory, { recursive: true, force: true }); }
});
