import assert from "node:assert/strict";
import { test } from "node:test";
import { chmodSync, existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, renameSync, rmSync, symlinkSync, unlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { approval, validateResponse } from "./approval.ts";
import { type Authority } from "./handoff.ts";

const requestId = "a".repeat(32);
const rc = { path: "/ancestor/.envrc", fingerprint: "a".repeat(64) };
const success = () => ({ version: 1, childId: "child", requestId, ok: true, status: { state: "blocked", rc } });
test("approval envelopes enforce exact IDs, fields, states, bounds and rc witness", () => {
  validateResponse(success(), "child", requestId);
  for (const state of ["none", "unavailable"]) validateResponse({ ...success(), status: { state, rc: null } }, "child", requestId);
  validateResponse({ version: 1, childId: "child", requestId, ok: false, error: "refused" }, "child", requestId);
  for (const invalid of [
    { ...success(), version: 2 }, { ...success(), extra: true }, { ...success(), childId: "stale" }, { ...success(), requestId: "b".repeat(32) },
    { ...success(), ok: 1 }, { ...success(), status: { state: "unknown", rc } }, { ...success(), status: { state: "allowed", rc: null } },
    { ...success(), status: { state: "none", rc } }, { ...success(), status: { state: "blocked", rc: { ...rc, extra: true } } },
    { ...success(), status: { state: "blocked", rc: { ...rc, fingerprint: "A".repeat(64) } } },
    { ...success(), status: { state: "blocked", rc: { ...rc, path: "relative" } } },
    { version: 1, childId: "child", requestId, ok: false, error: "x".repeat(4097) },
  ]) assert.throws(() => validateResponse(invalid, "child", requestId));
});
function fixture() {
  const directory = mkdtempSync(join(tmpdir(), "pi-direnv-client-"));
  const target = join(directory, "target"); mkdirSync(target);
  const control: Authority = { directory, launch: { version: 2, childId: "child", launcherPid: process.ppid, interactive: true, unsupported: [], incoming: null } };
  const file = join(directory, "approval-request.json");
  const controller = new AbortController();
  const respond = (request: any, value: any) => {
    const response = join(directory, `approval-response.${request.requestId}.json`);
    writeFileSync(response + ".tmp", JSON.stringify(value), { mode: 0o600 }); renameSync(response + ".tmp", response);
    return response;
  };
  const startServer = (serve: (request: any) => void) => {
    const timer = setInterval(() => {
      if (!existsSync(file)) return;
      const request = JSON.parse(readFileSync(file, "utf8")); unlinkSync(file); serve(request);
    }, 2);
    return () => clearInterval(timer);
  };
  return { directory, target, control, file, controller, respond, startServer, cleanup: () => rmSync(directory, { recursive: true, force: true }) };
}
test("client atomically publishes private bounded current-child request and cleans its own files", async () => {
  const f = fixture(); let stop = () => {}; try {
    let checks = 0; let request: any;
    stop = f.startServer((value) => { request = value; f.respond(value, { version: 1, childId: value.childId, requestId: value.requestId, ok: true, status: { state: "allowed", rc } }); });
    const pending = approval(f.control, "allow", f.target, rc, f.controller.signal, () => { checks++; });
    assert.equal(lstatSync(f.file).mode & 0o777, 0o600); assert.equal(lstatSync(f.file).nlink, 1);
    assert.deepEqual(await pending, { state: "allowed", rc });
    assert.ok(checks >= 3); assert.match(request.requestId, /^[a-f0-9]{32}$/);
    assert.deepEqual(Object.keys(request).sort(), ["version", "childId", "requestId", "action", "target", "rc"].sort());
    assert.equal(request.childId, "child"); assert.equal(request.action, "allow"); assert.deepEqual(request.rc, rc);
    assert.deepEqual(readdirSync(f.directory), ["target"]);
  } finally { stop(); f.cleanup(); }
});
test("existing or stale request is never overwritten or removed", async () => {
  const f = fixture(); try {
    writeFileSync(f.file, "stale request", { mode: 0o600 });
    await assert.rejects(approval(f.control, "status", f.target, null, f.controller.signal, () => {}), /EEXIST/);
    assert.equal(readFileSync(f.file, "utf8"), "stale request");
    assert.equal(readdirSync(f.directory).some((name) => name.endsWith(".tmp")), false);
  } finally { f.cleanup(); }
});
test("concurrent private IPC publication fails exclusively and does not cancel the first request", async () => {
  const f = fixture(); try {
    const first = approval(f.control, "status", f.target, null, f.controller.signal, () => {});
    const firstRejected = assert.rejects(first, /abort/i);
    const original = readFileSync(f.file, "utf8");
    await assert.rejects(approval(f.control, "status", f.target, null, new AbortController().signal, () => {}), /EEXIST/);
    assert.equal(readFileSync(f.file, "utf8"), original);
    f.controller.abort(); await firstRejected;
    assert.equal(existsSync(f.file), false);
  } finally { f.cleanup(); }
});
test("abort and timeout release pending request; allow timeout warns persistent grant may already have happened", async () => {
  for (const action of ["status", "allow"] as const) {
    const f = fixture(); try {
      await assert.rejects(approval(f.control, action, f.target, action === "allow" ? rc : null, f.controller.signal, () => {}, 5), action === "allow" ? /approval may have been granted.*not checkpointed/ : /timed out/);
      assert.deepEqual(readdirSync(f.directory), ["target"]);
    } finally { f.cleanup(); }
  }
});
test("cleanup cannot unlink a new request replacing the consumed inode", async () => {
  const f = fixture(); try {
    const pending = approval(f.control, "status", f.target, null, f.controller.signal, () => {});
    const rejected = assert.rejects(pending, /abort/i);
    unlinkSync(f.file); writeFileSync(f.file, "other request", { mode: 0o600 }); f.controller.abort();
    await rejected;
    assert.equal(readFileSync(f.file, "utf8"), "other request");
  } finally { f.cleanup(); }
});
test("stale response identity is rejected and never removed by current client's cleanup", async () => {
  const f = fixture(); let stop = () => {}; try {
    let response = "";
    stop = f.startServer((request) => { response = f.respond(request, { version: 1, childId: "stale", requestId: request.requestId, ok: true, status: { state: "none", rc: null } }); });
    await assert.rejects(approval(f.control, "status", f.target, null, f.controller.signal, () => {}), /Stale/);
    assert.equal(existsSync(response), true);
  } finally { stop(); f.cleanup(); }
});
test("response symlinks, nonprivate files and oversized envelopes fail closed", async () => {
  for (const kind of ["symlink", "mode", "oversize"]) {
    const f = fixture(); let stop = () => {}; try {
      stop = f.startServer((request) => {
        const response = join(f.directory, `approval-response.${request.requestId}.json`);
        if (kind === "symlink") { const foreign = join(f.directory, "foreign.json"); writeFileSync(foreign, "{}", { mode: 0o600 }); symlinkSync(foreign, response); }
        else { f.respond(request, { version: 1, childId: "child", requestId: request.requestId, ok: true, status: { state: "none", rc: null } }); if (kind === "mode") chmodSync(response, 0o644); else writeFileSync(response, "x".repeat(65537)); }
      });
      await assert.rejects(approval(f.control, "status", f.target, null, f.controller.signal, () => {}));
      assert.equal(existsSync(f.file), false);
    } finally { stop(); f.cleanup(); }
  }
});
test("readiness is revalidated after poll awaits before any response is accepted", async () => {
  const f = fixture(); let stop = () => {}; try {
    let ready = true;
    stop = f.startServer((request) => { ready = false; f.respond(request, { version: 1, childId: "child", requestId: request.requestId, ok: true, status: { state: "none", rc: null } }); });
    await assert.rejects(approval(f.control, "status", f.target, null, f.controller.signal, () => { if (!ready) throw new Error("readiness changed"); }), /readiness changed/);
    assert.deepEqual(readdirSync(f.directory), ["target"]);
  } finally { stop(); f.cleanup(); }
});
