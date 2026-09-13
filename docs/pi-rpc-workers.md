# Managed Pi RPC workers

`bin/pi-rpc-workers` supervises independent, persistent Pi RPC processes. Each
worker starts in its own Git worktree and uses its own session directory and
TMPDIR. Python's standard library provides the controller and private Unix
socket. This is **not a sandbox or a shell-command filter**.

## Current upstream-context run

Run directory: `~/.local/state/pi-workers/20260913-context`

- `workers.json`: exact worktrees, branches, models, policy and task-brief paths.
- `safety.txt`: mandatory policy supplied as actual system-prompt text.
- `map-brief.txt`, `summary-brief.txt`: read-only handshake and task scopes.
- `runtime/<worker>/output.log`: live assistant text and tool-call status.
- `runtime/<worker>/events.jsonl`: raw RPC events, including detailed results.
- `runtime/<worker>/sessions/`: persistent Pi sessions and actor bookkeeping.
- `runtime/<worker>/stderr.log`: startup/extension diagnostics.
- `runtime/controller.log`: controller diagnostics.

These files are private local coordination artifacts, not upstream commit
content. The worktrees are under `~/gits/pi-infinite-context-worktrees/`.

## Viewing and messaging

Open a viewer in any terminal; Ctrl-C exits the viewer, not the worker:

```sh
~/nixos/bin/pi-rpc-workers watch ~/.local/state/pi-workers/20260913-context map
~/nixos/bin/pi-rpc-workers watch ~/.local/state/pi-workers/20260913-context summary
```

Inspect state or send a message:

```sh
~/nixos/bin/pi-rpc-workers status ~/.local/state/pi-workers/20260913-context
~/nixos/bin/pi-rpc-workers send ~/.local/state/pi-workers/20260913-context map --text 'Report any blockers, then wait.'
```

Default delivery starts an idle worker or queues a follow-up behind active work.
Use `--mode steer` for a mid-task correction, or `--file /absolute/message.txt`
for a longer message. Request acknowledgment is not task completion. Messages
are never automatically retried after timeout: inspect state/events first.

A successful send returns `settled_before`. `wait RUN WORKER --after NUMBER`
waits on an event-driven condition, not a polling loop. It returns when a later
run is settled, or the worker disconnects/fails. Settlement is not proof of
success: inspect `stop_reason`, `error`, `ui_cancelled`, and `last_text`.
The counter is **not a prompt ID**. Serialize control messages per worker;
helper wake-ups and subsequent work can start another run after a snapshot.
Main must retrieve reports explicitly; this controller does not inject worker
messages automatically into an unrelated foreground Pi session.

## Interrupting and stopping

```sh
~/nixos/bin/pi-rpc-workers abort ~/.local/state/pi-workers/20260913-context map
~/nixos/bin/pi-rpc-workers stop ~/.local/state/pi-workers/20260913-context
```

`abort` clears queued messages, pauses the worker's actor swarm (only when the
extension was verified), aborts direct RPC bash and the main agent turn, and
keeps the process/session. Helpers remain paused until explicitly resumed.
Compaction has no public RPC abort command; an abort request is not a guarantee
of complete quiescence. Check state and use explicit stop if necessary.

`stop` acknowledges shutdown initiation, closes worker stdin for Pi's normal
session/actor cleanup, and escalates after bounded waits to TERM/KILL only for
the controller-owned worker processes. It preserves all logs and sessions.
The controller log/socket may remain as historical artifacts; it never
recursively removes a run. Normal abort/EOF/SIGTERM let Pi clean up tracked
shell children; forced termination cannot guarantee cleanup of every detached
external process. Do not terminate workers during important writes unless
interruption is necessary.

Do not start another Pi writer on a live worker's session file. Do not modify
installed extensions or global settings to experiment with a worktree version.

## Starting another approved run

Requires Pi 0.84.4-compatible RPC, the configured actor-subagents extension,
Python 3, authenticated requested models, clean Git worktrees, and prepared
pinned dependencies. The manifest must name canonical absolute worktrees,
expected branches, exact provider/model/thinking, and readable policy/brief
files. Review the policy and dependency setup before launch. Normal shared
Pi resources load offline; project-local resources still follow Pi's existing
trust configuration. No sandbox, tool denylist or command guard is added.

```sh
~/nixos/bin/pi-rpc-workers start /absolute/private-run/workers.json
```

Start refuses an existing `runtime/` directory, verifies correlated RPC
readiness, the exact model/effort and the actor command, and sends **no task
prompts**. Inspect startup stderr. Send each task brief, review its read-only
acknowledgment, and only then send an explicit implementation go-ahead.
Never treat startup acceptance, `agent_end`, or a successful prompt response as
proof that the requested task completed.

The current policy allows focused local commits but forbids publishing,
destructive cleanup and outside-worktree changes. Every helper must receive
the full policy explicitly. Astra use is forbidden unless the human explicitly
approves it and Main relays that specific authorization; global model-routing
defaults do not override this restriction.

## Verification

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tests/test_pi_rpc_workers.py -v
```

Tests use fake RPC processes, not providers. They exercise readiness, framing,
settlement, failed/missing capabilities, startup dialogs, blocked pipes,
malformed output, non-retried failures, abort/cleanup and worktree checks.
