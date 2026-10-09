import { accessSync, constants, closeSync, fsyncSync, linkSync, lstatSync, openSync, readFileSync, realpathSync, renameSync, unlinkSync, writeFileSync } from "node:fs";
import { isAbsolute, join, resolve } from "node:path";
import { createHash, randomUUID } from "node:crypto";
import { isDeepStrictEqual } from "node:util";

export const CHECKPOINT = "pi-restart-in-dir/checkpoint";
export const FLAG = "pi-restart-in-dir-handoff";
export const MARKER = "pi-restart-in-dir:";
export const MAX_JSON_BYTES = 65536;
export type Expected = { model: { provider: string; modelId: string } | null; thinkingLevel: string | null };
export type Checkpoint = { version: 1; childId: string; sourceCwd: string; target: string; invocation: "command" | "tool"; continue: boolean };
export type Request = Checkpoint & { source: string; checkpointId: string; expected: Expected; prompt: string | null };
export type Launch = { version: 2; childId: string; launcherPid: number; unsupported: string[]; interactive: boolean; incoming: Request | null };
export type Authority = { directory: string; launch: Launch };

function object(value: unknown, keys: string[]): asserts value is Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value) || !isDeepStrictEqual(Object.keys(value).sort(), keys.sort())) throw new Error("Invalid handoff object fields");
}
function string(value: unknown, max = 4096): asserts value is string {
  if (typeof value !== "string" || !value.length || value.length > max || value.includes("\0")) throw new Error("Invalid handoff string");
}
function path(value: unknown): asserts value is string {
  string(value);
  if (!isAbsolute(value)) throw new Error("Handoff paths must be absolute");
}
function identifier(value: unknown): asserts value is string {
  string(value, 128);
  if (!/^[a-zA-Z0-9_-]+$/.test(value)) throw new Error("Invalid handoff identifier");
}
export function validateCheckpoint(value: unknown): asserts value is Checkpoint {
  object(value, ["version", "childId", "sourceCwd", "target", "invocation", "continue"]);
  if (value.version !== 1 || !["command", "tool"].includes(value.invocation as string) || typeof value.continue !== "boolean" || value.continue !== (value.invocation === "tool")) throw new Error("Invalid handoff checkpoint");
  identifier(value.childId); path(value.sourceCwd); path(value.target);
}
export function validateRequest(value: unknown): asserts value is Request {
  object(value, ["version", "childId", "sourceCwd", "target", "invocation", "continue", "source", "checkpointId", "expected", "prompt"]);
  validateCheckpoint(checkpointData(value as unknown as Request));
  path(value.source); identifier(value.checkpointId);
  if (!(value.source as string).endsWith(".jsonl")) throw new Error("Source must be an exact session JSONL file");
  object(value.expected, ["model", "thinkingLevel"]);
  if (value.expected.model !== null) {
    object(value.expected.model, ["provider", "modelId"]);
    string(value.expected.model.provider, 256); string(value.expected.model.modelId, 1024);
  }
  if (value.expected.thinkingLevel !== null && !["off", "minimal", "low", "medium", "high", "xhigh", "max"].includes(value.expected.thinkingLevel as string)) throw new Error("Invalid native thinking level");
  if (value.continue) string(value.prompt, 16384);
  else if (value.prompt !== null) throw new Error("Command handoff must not contain a prompt");
}
export function validateLaunch(value: unknown): asserts value is Launch {
  object(value, ["version", "childId", "launcherPid", "unsupported", "interactive", "incoming"]);
  if (value.version === 1) throw new Error("This pi-restartable launcher predates direnv approval support; exit and relaunch with the updated pi-restartable");
  if (value.version !== 2 || !Number.isSafeInteger(value.launcherPid) || (value.launcherPid as number) <= 1 || typeof value.interactive !== "boolean") throw new Error("Invalid launcher metadata");
  identifier(value.childId);
  if (!Array.isArray(value.unsupported) || value.unsupported.length > 128) throw new Error("Invalid unsupported options");
  for (const option of value.unsupported) {
    string(option, 128);
    if (!/^--?[a-zA-Z0-9][a-zA-Z0-9-]*$/.test(option)) throw new Error("Invalid unsupported option name");
  }
  if (value.incoming !== null) validateRequest(value.incoming);
}
export function checkpointData(request: Checkpoint): Checkpoint {
  return { version: request.version, childId: request.childId, sourceCwd: request.sourceCwd, target: request.target, invocation: request.invocation, continue: request.continue };
}
function privateFile(file: string): void {
  const st = lstatSync(file);
  if (!st.isFile() || st.uid !== process.getuid?.() || (st.mode & 0o777) !== 0o600 || st.nlink !== 1 || st.size > MAX_JSON_BYTES) throw new Error("Handoff file must be private, regular and bounded");
}
export function authority(env = process.env): Authority {
  const directory = env.PI_RESTARTABLE_CONTROL_DIR;
  const childId = env.PI_RESTARTABLE_CHILD_ID;
  const pid = env.PI_RESTARTABLE_LAUNCHER_PID;
  if (!directory || !childId || !pid) throw new Error("No live pi-restartable launcher; use pi-restartable rather than command pi");
  identifier(childId); path(directory);
  if (!/^[1-9][0-9]*$/.test(pid)) throw new Error("Invalid launcher process identity");
  const launcherPid = Number(pid);
  if (!Number.isSafeInteger(launcherPid) || launcherPid !== process.ppid || launcherPid <= 1) throw new Error("Restart authority is only valid in the launcher's direct child");
  process.kill(launcherPid, 0);
  const st = lstatSync(directory);
  if (!st.isDirectory() || st.uid !== process.getuid?.() || (st.mode & 0o777) !== 0o700 || realpathSync(directory) !== directory) throw new Error("Launcher control directory must be canonical and private");
  const file = join(directory, "launch.json");
  privateFile(file);
  const launch: unknown = JSON.parse(readFileSync(file, "utf8"));
  validateLaunch(launch);
  if (launch.childId !== childId || launch.launcherPid !== launcherPid) throw new Error("Stale launcher identity");
  return { directory, launch };
}
export function canonicalDirectory(directory: string, cwd: string): string {
  string(directory);
  const target = realpathSync(resolve(cwd, directory));
  if (!lstatSync(target).isDirectory()) throw new Error("Restart target is not a directory");
  // R_OK and X_OK are needed by a fresh process, not just the current directory handle.
  accessSync(target, constants.R_OK | constants.X_OK);
  const fd = openSync(target, constants.O_RDONLY | constants.O_DIRECTORY);
  closeSync(fd);
  return target;
}
export function readSession(file: string): any[] {
  const st = lstatSync(file);
  if (!st.isFile() || st.uid !== process.getuid?.()) throw new Error("Session must be an owned regular saved JSONL file");
  const text = readFileSync(file, "utf8");
  if (!text.endsWith("\n")) throw new Error("Session has an incomplete last line");
  const entries = text.trimEnd().split("\n").map((line) => JSON.parse(line));
  if (entries[0]?.type !== "session") throw new Error("Session header missing");
  return entries;
}
export function savedSource(file: string | undefined, cwd: string, sessionId: string): { source: string; sourceCwd: string; entries: any[] } {
  if (!file) throw new Error("No persistent session file is available");
  const source = realpathSync(file);
  if (!source.endsWith(".jsonl")) throw new Error("Session source must be an exact JSONL file");
  const sourceCwd = realpathSync(cwd);
  const entries = readSession(source);
  if (typeof entries[0].cwd !== "string" || realpathSync(entries[0].cwd) !== sourceCwd || entries[0].id !== sessionId) throw new Error("Saved session header does not match the current canonical cwd/session");
  return { source, sourceCwd, entries };
}
export function savedBranch(entries: any[], leafId: string): any[] {
  const byId = new Map<string, any>();
  for (const entry of entries.slice(1)) {
    if (typeof entry.id !== "string" || byId.has(entry.id)) throw new Error("Invalid/duplicate session entry identity");
    byId.set(entry.id, entry);
  }
  const branch: any[] = [];
  const seen = new Set<string>();
  let id: string | null = leafId;
  while (id !== null) {
    if (seen.has(id)) throw new Error("Cyclic saved branch");
    seen.add(id);
    const entry = byId.get(id);
    if (!entry) throw new Error("Selected branch is not durably saved");
    branch.push(entry);
    if (entry.parentId !== null && typeof entry.parentId !== "string") throw new Error("Invalid selected branch parent");
    id = entry.parentId;
  }
  return branch.reverse();
}
/** Mirrors Pi 1.0.0 sdk.js + virtual-models.js, not the live runtime selection. */
export function nativeExpected(branch: any[], hasMessages: boolean, getModel: (provider: string, id: string) => { api?: string } | undefined): Expected {
  if (!hasMessages) return { model: null, thinkingLevel: null };
  let model: Expected["model"] = null;
  for (let i = branch.length - 1; i >= 0; i--) {
    const entry = branch[i];
    if (entry.type === "model_change") {
      model = { provider: entry.provider, modelId: entry.modelId };
      break;
    }
    if (entry.type === "message" && entry.message.role === "assistant" && entry.message.api !== "pi-virtual") {
      model = { provider: entry.message.provider, modelId: entry.message.model };
      for (let j = i - 1; j >= 0; j--) {
        const change = branch[j];
        if (change.type !== "model_change") continue;
        if (getModel(change.provider, change.modelId)?.api === "pi-virtual") model = { provider: change.provider, modelId: change.modelId };
        break;
      }
      break;
    }
  }
  const thinking = [...branch].reverse().find((entry) => entry.type === "thinking_level_change");
  return { model, thinkingLevel: thinking?.thinkingLevel ?? null };
}
export function verifyCheckpoint(entries: any[], id: string, data: Checkpoint): void {
  const last = entries.at(-1);
  if (last?.type !== "custom" || last.id !== id || last.customType !== CHECKPOINT || !isDeepStrictEqual(last.data, data)) throw new Error("Restart checkpoint was not saved as the final session entry");
  if (typeof entries[0]?.cwd !== "string" || realpathSync(entries[0].cwd) !== data.sourceCwd) throw new Error("Saved source cwd changed");
}
export function commitRequest(directory: string, request: Request): void {
  validateRequest(request);
  const text = JSON.stringify(request) + "\n";
  if (Buffer.byteLength(text) > MAX_JSON_BYTES) throw new Error("Restart request exceeds protocol bound");
  const temporary = join(directory, `request.${randomUUID()}.tmp`);
  let fd: number | undefined;
  try {
    fd = openSync(temporary, "wx", 0o600);
    writeFileSync(fd, text); fsyncSync(fd); closeSync(fd); fd = undefined;
    renameSync(temporary, join(directory, "request.json"));
    const dirFd = openSync(directory, constants.O_RDONLY | constants.O_DIRECTORY);
    try { fsyncSync(dirFd); } finally { closeSync(dirFd); }
  } finally {
    if (fd !== undefined) closeSync(fd);
    try { unlinkSync(temporary); } catch (error: any) { if (error.code !== "ENOENT") throw error; }
  }
}
/** One-use receipt survives session switches and extension reloads in this launcher child. */
export function consumeIncoming(control: Authority): boolean {
  const incoming = control.launch.incoming;
  if (!incoming) throw new Error("No incoming handoff to consume");
  const receipt = { version: 1, childId: control.launch.childId, incomingChildId: incoming.childId };
  const key = createHash("sha256").update(`${receipt.childId}:${receipt.incomingChildId}`).digest("hex");
  const file = join(control.directory, `consumed.${key}.json`);
  const temporary = join(control.directory, `consumed.${randomUUID()}.tmp`);
  let fd: number | undefined;
  let consumed = false;
  try {
    fd = openSync(temporary, "wx", 0o600);
    writeFileSync(fd, JSON.stringify(receipt) + "\n"); fsyncSync(fd); closeSync(fd); fd = undefined;
    try {
      // link is atomic and exclusive, unlike rename which could replace an earlier receipt.
      linkSync(temporary, file);
    } catch (error: any) {
      if (error.code !== "EEXIST") throw error;
      consumed = true;
    }
    unlinkSync(temporary);
    if (consumed) {
      privateFile(file);
      if (!isDeepStrictEqual(JSON.parse(readFileSync(file, "utf8")), receipt)) throw new Error("Invalid incoming handoff consumption receipt");
    }
    const directoryFd = openSync(control.directory, constants.O_RDONLY | constants.O_DIRECTORY);
    try { fsyncSync(directoryFd); } finally { closeSync(directoryFd); }
    return !consumed;
  } finally {
    if (fd !== undefined) closeSync(fd);
    try { unlinkSync(temporary); } catch (error: any) { if (error.code !== "ENOENT") throw error; }
  }
}
export function invalidateRequest(directory: string): void {
  try { unlinkSync(join(directory, "request.json")); } catch (error: any) { if (error.code !== "ENOENT") throw error; }
}
export function syncSession(source: string): void {
  const fd = openSync(source, "r");
  try { fsyncSync(fd); } finally { closeSync(fd); }
}
export function shellQuote(text: string): string { return `'${text.replaceAll("'", "'\\''")}'`; }
export function manualInstructions(target: string | undefined, source: string | undefined, cwd: string): string {
  const destination = target ?? cwd;
  const mode = target && target !== cwd ? "--fork" : "--session";
  const invocation = `cd -- ${shellQuote(destination)} && pi-restartable${source ? ` ${mode} ${shellQuote(source)}` : ""}`;
  return `Manual recovery (last saved state only): ${invocation}. An unsaved /tree selection or queued input is not preserved.`;
}
