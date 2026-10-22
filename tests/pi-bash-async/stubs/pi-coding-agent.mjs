// Minimal stand-in for Pi's local bash: detached process group, killed as a group on abort.
import { spawn } from "node:child_process";

export function createLocalBashOperations() {
  return {
    exec: (command, cwd, { onData, signal, env } = {}) =>
      new Promise((resolve, reject) => {
        const child = spawn("/bin/sh", ["-c", command], { cwd, env, detached: true, stdio: ["ignore", "pipe", "pipe"] });
        const kill = () => {
          try {
            process.kill(-child.pid, "SIGKILL");
          } catch {}
        };
        signal?.addEventListener("abort", kill, { once: true });
        child.stdout.on("data", (d) => onData?.(d));
        child.stderr.on("data", (d) => onData?.(d));
        child.on("error", reject);
        child.on("close", (code) => {
          signal?.removeEventListener("abort", kill);
          if (signal?.aborted) reject(new Error("aborted"));
          else resolve({ exitCode: code });
        });
      }),
  };
}

export function createBashToolDefinition(cwd, { operations, spawnHook }) {
  return {
    async execute(_id, { command }, signal) {
      const req = spawnHook ? spawnHook({ command, cwd, env: { ...process.env } }) : { command, cwd, env: process.env };
      const result = await operations.exec(req.command, req.cwd, { signal, env: req.env });
      if (result.exitCode !== 0) throw new Error(`Command exited with code ${result.exitCode}`);
      return { content: [] };
    },
  };
}
