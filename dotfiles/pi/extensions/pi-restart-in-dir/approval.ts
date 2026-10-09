import { constants, closeSync, fstatSync, fsyncSync, linkSync, lstatSync, openSync, readFileSync, unlinkSync, writeFileSync } from "node:fs";
import { isAbsolute, join } from "node:path";
import { randomUUID } from "node:crypto";
import { setTimeout as delay } from "node:timers/promises";
import { isDeepStrictEqual } from "node:util";
import { MAX_JSON_BYTES, type Authority } from "./handoff.ts";

export type Rc = { path: string; fingerprint: string };
export type ApprovalStatus = { state: "unavailable" | "none" | "allowed" | "denied" | "blocked"; rc: Rc | null };
type Response = { version: 1; childId: string; requestId: string } & ({ ok: true; status: ApprovalStatus } | { ok: false; error: string });
function fields(value: unknown, keys: string[]): asserts value is Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value) || !isDeepStrictEqual(Object.keys(value).sort(), keys.sort())) throw new Error("Invalid direnv approval response fields");
}
export function validateResponse(value: unknown, childId: string, requestId: string): asserts value is Response {
  fields(value, value && (value as any).ok === true ? ["version", "childId", "requestId", "ok", "status"] : ["version", "childId", "requestId", "ok", "error"]);
  if (value.version !== 1 || value.childId !== childId || value.requestId !== requestId || !/^[a-f0-9]{32}$/.test(requestId)) throw new Error("Stale or invalid direnv approval response identity");
  if (value.ok === false) {
    if (typeof value.error !== "string" || !value.error.length || value.error.length > 4096 || value.error.includes("\0")) throw new Error("Invalid direnv approval error");
    return;
  }
  if (value.ok !== true) throw new Error("Invalid direnv approval response");
  fields(value.status, ["state", "rc"]);
  if (!["unavailable", "none", "allowed", "denied", "blocked"].includes(value.status.state as string)) throw new Error("Invalid direnv approval state");
  if (["unavailable", "none"].includes(value.status.state as string)) {
    if (value.status.rc !== null) throw new Error("Unexpected direnv rc");
  } else {
    fields(value.status.rc, ["path", "fingerprint"]);
    const rc = value.status.rc;
    if (typeof rc.path !== "string" || !rc.path.length || rc.path.length > 4096 || rc.path.includes("\0") || !isAbsolute(rc.path) || typeof rc.fingerprint !== "string" || !/^[a-f0-9]{64}$/.test(rc.fingerprint)) throw new Error("Invalid direnv rc identity");
  }
}
function readPrivate(file: string): { value: unknown; dev: number; ino: number } {
  const fd = openSync(file, constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
  try {
    const st = fstatSync(fd);
    if (!st.isFile() || st.uid !== process.getuid?.() || (st.mode & 0o777) !== 0o600 || st.nlink !== 1 || st.size > MAX_JSON_BYTES) throw new Error("Direnv approval file must be private, regular and bounded");
    const text = readFileSync(fd, "utf8");
    if (Buffer.byteLength(text) > MAX_JSON_BYTES) throw new Error("Direnv approval response exceeds protocol bound");
    return { value: JSON.parse(text), dev: st.dev, ino: st.ino };
  } finally { closeSync(fd); }
}
function removeOwn(file: string, identity: { dev: number; ino: number }, expected: unknown): void {
  try {
    const st = lstatSync(file);
    if (st.dev !== identity.dev || st.ino !== identity.ino) return;
    // Inodes can be reused after the server consumes a request; verify content too.
    let read: ReturnType<typeof readPrivate>;
    try { read = readPrivate(file); } catch { return; }
    if (read.dev === identity.dev && read.ino === identity.ino && isDeepStrictEqual(read.value, expected)) unlinkSync(file);
  } catch (error: any) { if (error.code !== "ENOENT") throw error; }
}
/** The launcher owns baseline direnv status/allow; this client never loads project environments. */
export async function approval(control: Authority, action: "status" | "allow", target: string, rc: Rc | null, signal: AbortSignal, revalidate: () => void, timeout = 30_000): Promise<ApprovalStatus> {
  const requestId = randomUUID().replaceAll("-", "");
  const request = { version: 1, childId: control.launch.childId, requestId, action, target, rc };
  const temporary = join(control.directory, `approval-request.${requestId}.tmp`);
  const file = join(control.directory, "approval-request.json");
  const response = join(control.directory, `approval-response.${requestId}.json`);
  let published: { dev: number; ino: number } | undefined;
  let received: { value: unknown; dev: number; ino: number } | undefined;
  let fd: number | undefined;
  try {
    signal.throwIfAborted(); revalidate();
    fd = openSync(temporary, "wx", 0o600);
    writeFileSync(fd, JSON.stringify(request) + "\n"); fsyncSync(fd);
    const st = fstatSync(fd); closeSync(fd); fd = undefined;
    // Exclusive publication must never overwrite another or stale client's request.
    linkSync(temporary, file); published = { dev: st.dev, ino: st.ino }; unlinkSync(temporary);
    const deadline = Date.now() + timeout;
    while (true) {
      signal.throwIfAborted(); revalidate();
      try {
        const read = readPrivate(response);
        validateResponse(read.value, control.launch.childId, requestId);
        received = read;
        if (!read.value.ok) throw new Error(read.value.error);
        return read.value.status;
      } catch (error: any) { if (error.code !== "ENOENT") throw error; }
      if (Date.now() >= deadline) throw new Error(`Direnv ${action} request timed out${action === "allow" ? "; approval may have been granted, but Pi has not checkpointed or restarted" : ""}`);
      await delay(Math.min(50, Math.max(1, deadline - Date.now())), undefined, { signal });
      signal.throwIfAborted(); revalidate();
    }
  } finally {
    if (fd !== undefined) closeSync(fd);
    try { unlinkSync(temporary); } catch (error: any) { if (error.code !== "ENOENT") throw error; }
    if (published) removeOwn(file, published, request);
    if (!received) {
      try {
        const read = readPrivate(response);
        validateResponse(read.value, control.launch.childId, requestId);
        received = read;
      } catch { /* Never remove a response with an unverified or stale identity. */ }
    }
    if (received) removeOwn(response, received, received.value);
  }
}
