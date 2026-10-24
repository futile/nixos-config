# Pi async bash extensions: comparison notes

Goal: replace "background `&` + fixed `sleep`" / sleep-poll loops with push-based
completion, and make background jobs die with Pi.

Checked against npm sources (`npm pack`), not just READMEs:
`@ryan_nookpi/pi-extension-bash-async@0.4.1`, `@pify/shell-background@0.5.1`,
and the Pi 1.3.0 binary (`trackDetachedChildPid` / `killTrackedDetachedChildren`).

## Summary

| | bash-async (ryan_nookpi) | shell-background (pify) |
|---|---|---|
| Tool surface | new `bash_async` tool (`start/status/output/kill/list`); built-in `bash` untouched | **replaces `bash`** (+ `background: true`), adds `shell_status`, `shell_kill`, `/shell-bg` |
| Auto-backgrounding | no; only explicit `start` (waits a 10 s sync window, returns inline if done) | every `bash` call still running after 30 s moves to background (`autoBackgroundMs`) |
| Completion delivery | `sendMessage(..., {deliverAs: "steer", triggerTurn: true})`, batched 500 ms → seen after current tool batch, wakes idle agent | `deliverAs: "followUp", triggerTurn: true` → seen only after the agent run ends, wakes idle agent |
| Waiting when nothing else to do | no wait action; agent ends its turn and is woken | `shell_status {id, wait: N}` blocks up to 300 s (a real wait primitive) |
| Anti-polling | rate-limits repeated identical `status/output/list` (10 s cooldown), prompt says "don't sleep-loop", running-job reminders in context | none besides wait; docs say don't poll |
| Long-lived servers | designed for finite commands; `timeout: 0` allows it; default timeout 1800 s, max 4 concurrent | explicitly supported (`npm run dev`), max 8 alive |
| Spawning | via Pi's own `createLocalBashOperations` / `createBashToolDefinition` | own `spawn(detached)` reusing Pi's shell/env logic |
| Kill on normal quit | `session_shutdown` aborts + settles all jobs | `session_shutdown` SIGTERMs process groups (SIGKILL escalation timer is `unref`'d, so likely never fires on exit) |
| Kill on SIGTERM/SIGHUP/crash of Pi | **yes, synchronously**: Pi's local bash ops register PIDs in `trackedDetachedChildPids`, which Pi SIGKILLs (whole group) in its signal and crash handlers | only if the async `session_shutdown` gets to run; its PIDs are not in Pi's tracked set |
| Kill on SIGKILL of Pi | no (children are `setsid`-detached) | no; later sessions mark them "orphaned" and deliberately never signal them |
| `/reload` | jobs are killed (its `session_shutdown` handler ignores `event.reason`) | jobs survive and are adopted by the new instance |
| Headless `pi -p` | works only within the turn (no wait primitive) | auto-background off; `background:true` + `shell_status wait` |
| Output handling | last 200 lines / 8 KiB inline, full log in `$TMPDIR/pi-bash-async` (24 h, 1 GiB) | log-aware shrink (keeps error lines, collapses repeats, JSON test-report summary), `\r` redraw resolution |
| Non-interactive env | stdin unsupported | forces `GIT_TERMINAL_PROMPT=0`, `EDITOR=true`, pager `cat` |
| Conflicts | none with our current packages | last-write-wins on `bash` with any other `bash`-overriding extension (e.g. `@pify/pretty`) |

## Assessment

- **Lifecycle (your "die with Pi" goal):** bash-async is better. Reusing Pi's
  bash operations gets Pi's built-in signal/crash cleanup for free. Neither
  survives a `kill -9` of Pi cleanly; that would need a PR_SET_PDEATHSIG-style
  wrapper (e.g. `setpriv --pdeathsig KILL`), which neither ships.
- **Stopping sleep loops:** both push results. pify also has a blocking
  `shell_status wait`, which is the clean answer when the agent really has
  nothing else to do. bash-async gets there by rate-limiting polls plus
  "end your turn, you'll be woken" guidance. Steer delivery (bash-async) comes
  back sooner during a long agent run than followUp (pify).
- **Invasiveness:** pify changes *every* bash call (30 s auto-background,
  different output shrinking). That's convenient, but it also changes how subagents
  and existing workflows behave, and the agent may get "moved to background"
  for a test run it wanted to read synchronously. bash-async is opt-in per call.

Recommendation: try **bash-async** first (opt-in, better kill semantics,
steer delivery). Consider pify if auto-backgrounding or the blocking wait turns
out to matter more than lifecycle guarantees. Don't install both: the tools
differ, but agents would get two competing background mechanisms.

## Integration with pi-actor-subagents

Checked against `~/.pi/agent/extensions/actor-subagents` (flake input
`pi-actor-subagents`, patched in `home-modules/pi.nix`).

How children run: in-process SDK sessions (`createAgentSession`), bound with
`bindExtensions({mode: "print"})`, so `ctx.hasUI === false`. They load **only**
the extensions listed in `childExtensions` (`noExtensions: true` +
`additionalExtensionPaths`), and that list is generated in `home-modules/pi.nix`
as `~/.pi/agent/actor-subagents/settings.json`. Kill/shutdown runs
`abortBash → abort → session_shutdown{reason:"quit"} → dispose` for each child.

Common to both:

- Must be added to `childExtensions`, otherwise subagents keep plain blocking
  `bash` (and no `bash_async`).
- State is per factory instance, i.e. per session: jobs are scoped to the
  subagent that started them, and concurrency caps are per agent (bash-async
  4 × up to 16 agents = 64 jobs; pify 8 × 16 = 128).
- Killing a subagent (or quitting main) fires its `session_shutdown` "quit",
  so both extensions kill that agent's jobs. Good.
- Completion is delivered with `sendMessage(..., {triggerTurn: true})` on the
  child session, which wakes an idle child. That matches the actor model: the
  child ends its turn while the job runs and reports to its parent once woken.
  Downside: `list_subagents` shows the child as idle while its job runs, so a
  parent may think it's finished (or kill it, which kills the job).
- Pause gap: actor-subagents buffers only messages it routes itself
  (`pausedInbox`). An extension completion that arrives while a child is paused
  starts a turn that `recordTurnStart` aborts immediately. The message stays in
  the transcript (bash-async's delivery guard also re-appends it without a
  turn), but `resume` only re-triggers `pausedMidTurn` agents. So the child
  reads the result only on its next incoming message.

bash-async specifics: works unchanged in print mode (only the widget is
TUI-only). Steer delivery matches actor-subagents' own steer-based messaging.
The optional `pi.async-tasks.v1` protocol has no host here and stays inactive.

pify specifics: because children have `hasUI=false`, pify treats them as
headless `pi -p`. Auto-background is **off**, and the `bash` description
tells the model "Nothing is delivered after your turn … collect with
`shell_status {id, wait}`". That's false under actor-subagents (delivery does
wake the child), and it steers subagents into blocking waits of up to 300 s,
during which peer messages (steer) aren't seen. It also makes main and
subagents use different `bash` semantics.

Proposed fix for the pause gap (in pi-actor-subagents, not in the bash
extension). In `Engine.recordTurnStart` (`engine.ts`), mark the refused turn
as interrupted:

```ts
if (rec && this.isStopped(rec)) { rec.pausedMidTurn = true; return { abort: true, reason: "agents paused" }; }
```

Resume then lists the agent in `interrupted`, and index.ts routes
`RESUME_NUDGE` to it. The triggering message is already persisted: Pi's
`runAgentLoop` emits `message_start/end` for the prompt after `turn_start`,
even when the turn is aborted. Only turns not started by the engine reach this
path (routed messages go to `pausedInbox`), so it's generic: it covers any
extension's `sendMessage(..., {triggerTurn: true})`, not just bash jobs.
Regression test next to `"recordTurnStart aborts while paused"` in
`engine.test.ts`: pause "a", call `recordTurnStart("a")`, resume, and expect
`interrupted` to contain "a".

Verdict: bash-async integrates cleanly. pify works, but in subagents it
behaves like headless mode and its prompt describes delivery wrongly.

## Upstream status (checked against earendil-works/pi issues)

No issue specifically covers "children survive `kill -9` of Pi". DeepWiki
also confirms Pi has no `PR_SET_PDEATHSIG` or parent-death watchdog. Related:

- #8225 *Detached bash descendants survive Pi shutdown*: closed as not planned.
  The maintainer says Pi only cleans up bash trees that are still running, and
  that real containment (Job Objects etc.) would be a separate feature that
  changes what intentionally backgrounded commands mean. It also notes that
  `/quit` does not use the global tracked-PID cleanup.
- #10905 *Escape leaves task launched background processes running on Linux*:
  closed (dup of #8225). `start_new_session` escapes the group kill.
- #10797 *macOS: bash timeout leaves Playwright Chrome running in a detached
  process group*: open.
- #9129 *On Windows, bash timeout kill leaves pipeline processes orphaned*: open.
- #10029 *Print mode: let background task completion wake follow-up turns*:
  closed (auto-closed).

A SIGKILL-safe fix on Linux would be an OS-level feature (`PR_SET_PDEATHSIG`
per child, or a cgroup/systemd scope per Pi). A new issue should frame it
that way, since #8225 shows upstream reluctance.

## Adopted setup (nixos-01q)

- The extension comes from our fork https://github.com/futile/pi-bash-async (flake input
  `pi-bash-async`; `main` = bash-async package only, `upstream` = full Jonghakseo/pi-extension monorepo
  plus our commits, maintained with `scripts/sync-upstream` / `scripts/update-main` on `upstream`).
  `home-modules/pi.nix` installs it to `~/.pi/agent/extensions/bash-async`, also listed in actor-subagents `childExtensions`.
  Update with `nix flake update pi-bash-async`.
- Reload change: on `session_shutdown{reason:"reload"}` the running
  `JobManager`/batcher/provider bundle goes into a `globalThis` map keyed by
  session id instead of being aborted. The next instance adopts it in
  `session_start`, rebinds delivery and the widget, and replays completions that
  arrived during the gap. If nobody adopts it within 30 s, the jobs are killed.
  Other shutdown reasons still kill jobs.
- The pause fix above is upstream (https://github.com/fdietze/pi-actor-subagents/pull/6).
- Jobs signal: on every job
  transition bash-async emits `pi.bash-async.v1:jobs` `{version: 1, running, jobs: [{id, title}]}`
  (queued + running jobs) on `pi.events`, re-emits on `pi.bash-async.v1:request`, and in every host
  (whatever `ctx.hasUI` says) sets the `bash-async` footer status to `⏳N` (N running jobs). pi-statusline shows main's;
  actor-subagents (since ea929fd) shows each child's in its roster/`list_subagents` extensions column.
  `patches/pi-actor-subagents-extension-status-keys.patch` adds the `childExtensionStatusKeys` setting
  (allowlist of child status keys); we set it to `["bash-async"]`.
  `patches/pi-actor-subagents-background-jobs.patch` listens on main's and every child's bus (a child
  extension factory, keyed by session id) and adds what the per-agent status can't: the total in the
  swarm state line and the jobs stopped with an agent in kill results.
  Running jobs in any agent (main included) also set `terminalProgress` (not `active`) in its
  `pi.agent-activity.v1` update, so kitty's tab progress bar/title indicator stays on while jobs run,
  gated by Pi's `showTerminalProgress` setting; job time doesn't count as active agent time.
- Command display: the call row shows `$ <command>`
  (3 lines collapsed, all when expanded); a missing `title` defaults to the one-line command clipped to 60
  chars instead of its first word; the widget below the editor adds `$ <command…>` after an explicit title.
- Tests for the fork's changes: `packages/bash-async/fork-changes.test.ts` on the fork's `upstream` branch
  (`nix shell nixpkgs#pnpm_10 nixpkgs#nodejs -c pnpm exec vitest run packages/bash-async` after `pnpm install`).
- Optional env: `PI_BASH_ASYNC_SYNC_WINDOW_MS`, `PI_BASH_ASYNC_MAX_CONCURRENCY`.
- Nothing stops the agent from still running `cmd &` in plain `bash`.
  Only guidance prevents it (or a `tool_call` hook that rejects trailing `&`).
