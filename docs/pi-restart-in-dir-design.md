# Pi restart-in-directory design

Status: agreed implementation plan; feasibility gates must pass first. This
records the Pi design including independent source review and PDO fit feedback.
Implementation belongs in this repository, not in PDO.

## Goal and scope

Move a foreground, interactive Pi conversation to another directory by gracefully
exiting Pi and starting a replacement in the same terminal. Git worktrees are an
important use case, but the target can be any existing directory.

The conversation is retained through a fork; each restart gets a new session ID.
The replacement rebuilds cwd-bound tools, instructions, project configuration,
environment, and extension services instead of mutating a running workspace.

This is independent of `pi-worktree`. It does not create/remove worktrees, change
branches, start project services, allocate ports, migrate subagents, or configure
PDO runtimes. No Pi core change is planned. An occasional unnecessary API call
while the old instance shuts down is an accepted limitation, not a guarantee that
work continues in the old instance.

## Agreed interfaces

| Interface | Name and behavior |
| --- | --- |
| Extension | `pi-restart-in-dir` |
| User command | `/restart-in-dir <directory>` |
| Model tool | `restart-in-dir`, with a required `directory` string |
| Launcher | `pi-restartable` |
| Interactive Fish command | `pi` aliases `pi-restartable` from initial deployment |
| Fish bypass | `command pi` runs the external Pi executable without the launcher |

Both command and tool use the same target validation and handoff logic. The tool
is main-agent-only, not exposed to subagents or indirect/nested tool execution.

Relative directories resolve against the current Pi session cwd, not the
launcher's original directory. Resolve the target to a canonical absolute path;
require an accessible directory, not a file. Paths are data, not shell snippets:
spaces and shell metacharacters must not change their meaning. Git membership
and a local `.envrc` are not required.

### Readiness: refuse, do not drain automatically

The command refuses while the main agent or swarm is busy. It does not wait for
work to finish, kill agents, discard queued messages, or pause active work to make
a restart possible. The user/agent finishes outstanding work and retries.

For the tool, the switching call itself is necessarily part of an active main
turn. Permit that call, but no other concurrent or pending work. The restart tool
must be the sole call in its assistant tool-call batch; reject a mixed batch
before accepting the handoff. Register it for sequential execution.

Readiness includes queued main messages and swarm messages, active provider/tool
work, compaction/retries, paused or buffered inboxes, pending spawns, reserved
names, and in-flight teardown. An idle agent record alone does not make the swarm
busy; idle subagents can be left behind under the policy below.

A small actor-subagents integration must supply an authoritative, synchronous
check-and-acquire handoff lease. Once acquired, new swarm work is refused until
shutdown or until a failed preparation releases the lease. Checking a footer,
activity boolean, roster file, or empty record map is insufficient: these omit
pending work or can report empty before cleanup finishes.

Exclude the extension from the configured child-extension allowlist, and also
check main-agent identity at execution. When the actor bridge exists but identity
or readiness cannot be established, fail closed. A standalone interactive Pi
without actor-subagents is supported with no swarm to check. An installed actor
extension without the required bridge must refuse, not assume quiescence.

The implementation must also prevent a second restart request and recheck main
queues immediately before accepting. Public idle/pending-message checks do not
cover all custom-message and deferred core queues; proving absence of pre-existing
main work is an implementation prerequisite, not supplied by the actor lease
alone. This lease does not constitute a global lock against every extension's
later nudge; see termination limitations.

## Components and ownership

### External launcher

`pi-restartable` owns the terminal-attached Pi child, its exit status, a private
handoff channel, and relaunches. It must remain alive after Pi exits. No detached
restart helper, tmux/cmux/Zellij command injection, terminal-output parsing, or
systemd service is needed.

Ordinary exits end the launcher. Only a valid, explicitly committed handoff after
a clean child exit causes a restart. The old process must be fully exited before
the new one starts; there must never be overlapping session writers.

### Pi extension

`pi-restart-in-dir` owns the command/tool, validation, readiness integration,
session checkpoint, continuation intent, and graceful shutdown request. It uses
Pi lifecycle APIs rather than `process.exit()`, shell `cd` tools, or
`process.chdir()` to simulate a live workspace change.

Both pieces are maintained and deployed together in this repository. The
launcher is not code that can exist solely inside the dying Pi process.

## Launcher contract

### Pin the real Pi once per launcher invocation

At initial startup, resolve the external `pi` executable from the launcher's
`PATH`, then resolve its symlinks to its actual executable in the Nix store.
Reject a missing/unusable executable or accidental self-resolution.

Keep that exact executable path in a private launcher variable for every child
launch. `REAL_PI` in earlier discussion was a placeholder, not an existing Pi
setting or a required user-supplied environment variable.

Installing a new profile version while the launcher is running must not upgrade
a restart. Exiting the launcher and invoking `pi` again picks up the new version.
The target's environment must not substitute a different Pi executable.

Pinning a path is not a Nix GC root. If the selected executable disappears, fail
visibly with recovery instructions; do not silently switch versions. Automatic GC
root management and version-selection options are outside the initial scope.
This pins the Pi executable, not mutable user/project extensions or settings.

### Environment on every launch

Keep the launcher's inherited environment as a stable baseline. Change directory
and apply environment changes only in the child-launch context, not in the
supervisor. Preserve inherited `DIRENV_DIFF`; direnv uses it to revert an inherited
workspace environment before loading the target environment.

For every initial launch and restart:

1. Recheck whether `direnv` is available on the launcher's baseline `PATH`.
2. Enter the target directory explicitly; `direnv exec` does not itself change cwd.
3. If available, execute `direnv exec . <pinned-Pi> <arguments>`.
4. Otherwise execute `<pinned-Pi> <arguments>` directly.

Use ordinary direnv lookup/trust semantics, including ancestor `.envrc` lookup
and its configured optional dotenv support. Do not decide based only on whether
`target/.envrc` exists. With no applicable rc, direnv launches with its restored
baseline environment. Without direnv, plain execution retains the inherited
baseline; the launcher cannot recreate direnv's environment reversion itself.

If direnv is present but fails, report the failure and stop. Never fall back to
plain execution to bypass a rejected environment, and never run `direnv allow`
automatically. An unapproved rc normally reports:

```text
/path/to/.envrc is blocked. Run `direnv allow` to approve its content
```

An explicitly denied rc is skipped under normal direnv semantics. The wrapper
must not promise that all denied configurations produce an approval error.

Do not make direnv an unconditional launcher runtime dependency that inserts it
into `PATH`: its absence must remain a real, supported case.

### Arguments and operating modes

The initial child receives the user's original arguments unchanged. Restart
arguments are built deliberately: use the pinned executable and
`--fork <exact-source-session-file>`, with the target as OS cwd.

Do not reproduce Pi's CLI. Classify a bounded whitelist; unsupported options do
not prevent the initial launch, but make that invocation non-restartable. Refuse
its restart before checkpoint/shutdown and identify the unsupported option without
printing secret values. Add support only for a demonstrated caller.

| Classification | Initial supported options | Restart behavior |
| --- | --- | --- |
| Startup-only | `--session`, `--continue`, `--resume`, `--fork`, `--session-id`; positional prompts and `@file` inputs | Do not replay. Fork the currently active session, not the original selection; do not repeat prompts/attachments. |
| Startup state overrides | `--model`, `--provider`, `--thinking`, `--name` | Do not replay. Restore the current session state, verified by the feasibility gate. |
| Source-project approval | `--approve` | Do not replay or extend approval to the target. Reevaluate target trust normally. |
| Persistent launch configuration | `--offline`, `--no-approve`, `--tui-mode`, `--verbose` | Carry forward with their values/semantics unchanged. |
| Initially unsupported | Explicit resource paths/disabling flags; system-prompt overrides; tool-selection/restriction flags; `--session-dir`, `--no-session`, `--api-key`, `--models`; unknown extension flags | Refuse restart while leaving the original Pi usable. |

Parse only supported option shapes/values and Pi's `--` delimiter; anything after
the delimiter is initial prompt input, not a flag. Unsupported path-bearing
options are not canonicalized or replayed. Dropping restrictions silently is not
an alternative to refusal. Never enable native compaction as a side effect of
restarting. The pinned executable is fixed, so the whitelist can be tested against
its inspected CLI rather than trying to accommodate arbitrary future extensions.

The restart workflow is for interactive Pi. Print/RPC/help/version invocations
must not enter a restart loop, and the extension must refuse restart in modes
where the graceful interactive handoff is unsupported. Existing external-Pi RPC
scripts remain outside the Fish alias and are not converted to this workflow.

## Handoff protocol and lifecycle

Use a private per-launcher control directory, owner-only permissions, and a fresh
one-use identifier for each child launch. The launcher passes protocol metadata
to its direct child through namespaced environment variables. Clear inherited
metadata before setting it; actor children must not obtain restart authority.
The exact variable names and JSON format are implementation details, not public
user configuration.

Requests are bounded, versioned structured data containing the child identifier,
canonical target directory, exact source session-file path, and continuation
intent. Use atomic publication inside the private directory. Validate schema,
identity, path types, and ownership on receipt. Do not execute request contents,
source shell files, or rely on terminal output as the channel.

This is accidental-misuse isolation, not a security sandbox against arbitrary
same-user code that can read Pi's environment or files.

### Successful sequence

1. Validate the live launcher, supported launch arguments, target, main identity,
   source session, tool-batch isolation, and readiness; acquire the handoff lease.
   Known blockers refuse before shutdown with an explanation/manual instructions.
   Preparation errors leave Pi running and release any lease. Refuse non-persistent
   runs or a source that cannot be made durably forkable.
2. Stage the handoff intent. For a tool invocation, return a successful
   **handoff accepted** result with `terminate: true`, not **restart succeeded**.
3. Let Pi persist the tool result and reach `agent_settled` before finalizing the
   tool handoff. The command path is already idle. Do not request shutdown yet:
   an idle shutdown request can start exiting immediately and cannot be cancelled.
4. At that boundary, append a session custom entry at the final selected leaf. It
   records source and target cwd, handoff identity, invocation type, and
   continuation intent. Verify that source history and checkpoint are persisted,
   then atomically commit the request. The entry also anchors an otherwise
   in-memory `/tree` branch selection. On failure, cancel the intent, release the
   lease, report the error, and leave Pi usable.
5. Only after successful checkpoint/commit, request graceful shutdown and finish
   normal extension disposal and terminal restoration. A preparation file alone
   is not permission to restart. Shutdown-hook errors cannot cancel an exit;
   observed protocol failures after shutdown begins must invalidate the request
   and preserve recovery instructions.
6. The launcher waits for status 0 with no recorded interruption, validates and
   consumes the committed request once, revalidates the target and source, and
   launches the replacement. Use fresh child protocol metadata; stale requests
   cannot restart it again.
7. The replacement forks into the target cwd and displays/records the active
   directory and handoff outcome. If continuation is requested, start exactly one
   continuation turn after startup initialization.

Verify this ordering against the installed Pi version. A crash, signal
termination, malformed request, or failed final persistence must not turn into an
automatic restart. Pi can handle SIGTERM/SIGHUP by shutting down with status 0, so
status alone is not proof of an uninterrupted handoff. Launcher-observed
interruption cancels the handoff and reaps the child; extension-observed
SIGTERM/SIGHUP invalidates staged or committed intent, including signals delivered
directly to the child. Test both signal routes.

Normal shutdown attempts extension/resource cleanup; logged or swallowed cleanup
errors mean a clean process exit is not proof that every external resource was
successfully released.

### Tool termination is best-effort

`terminate: true` suppresses the normal tool-result follow-up when the restart
call is isolated. It does not veto later steering, follow-ups, or extension
continuations. In the inspected Pi, even abort is not a hard gate before every
possible provider/preparation path. Context-pressure can enqueue a `turn_end`
reminder after a tool result.

The accepted design uses termination plus prompt graceful shutdown, without a
Pi core terminal-handoff latch. An occasional extra API request before old-Pi
exit is acceptable. Do not advertise a zero-call guarantee. Any extra activity
must remain in the old process; the replacement cannot start until it exits, and
the final checkpoint must reflect the actual persisted branch. If these effects
prevent reliable graceful shutdown or cause unintended tool execution, revisit
the integration rather than treating correctness problems as merely API cost.

### Known inability to restart: refuse and leave Pi usable

Plain `command pi` still loads the extension. Without a valid live launcher, or
with another known blocker such as unsupported launch arguments, refuse the
operation and show the reason plus short shell-quoted manual instructions. Do
not checkpoint for an accepted handoff, shut down, or claim a restart occurred.
A stale exported variable alone must not be mistaken for a live launcher.

Prefer a ready-to-run `pi-restartable` invocation from the target directory over
a separate shutdown-and-print lifecycle. Manual instructions must distinguish the
last durably saved session state from an in-memory `/tree` selection that has not
been checkpointed; do not promise that unsaved state is retained.

Preflight does not guarantee launch success. Environment loading, target changes,
and restoration can fail after the old process exits; those remain launcher
recovery cases. Do not execute project environments twice merely to probe them.

## Session and continuation semantics

### Fork, never force a historical cwd rewrite

Use `--fork`, not `cd target && pi --session old-file`: ordinary resume uses the
cwd recorded in the source session and can mix old project context with the new
environment. CLI forking uses the new startup cwd and new session identity while
copying non-header entries and their IDs, including extension custom entries.

Do not rewrite JSONL headers, migrate historical sessions, use native compaction,
or transfer SQLite/session sidecars by copying directory trees. The old session
remains available; the fork is the active conversation in the target.

### Who gets control after restart?

| Invocation | Replacement behavior |
| --- | --- |
| User `/restart-in-dir` | Finish startup and return control to the user |
| Main-agent `restart-in-dir` tool | Supply one initial continuation prompt |

Pi supports a positional startup prompt after interactive initialization. Prefer
this over blindly sending a nudge from `session_start`, which can run before
resource discovery has completed. Scope continuation to this one consumed
handoff; ordinary resumes must not repeatedly nudge the agent.

The continuation says that the restart reached the requested directory, identifies
source/target, and asks the agent to verify current cwd/project instructions and
relevant environment/MCP routing before resuming its previous task. Old transcript
instructions and tool results remain historical evidence, not proof that the new
workspace or its services are correct.

The old tool cannot return after replacement startup: its promise belongs to the
exited process. Launch errors are reported by the wrapper to the user. Success is
reported by the new instance; no transparent pending-tool reconnection protocol
is planned. "Started in target" is not a promise that every external service or
extension initialized successfully; nonfatal startup diagnostics remain visible.

### Subagents are not transferred

A fork's new main-session ID starts with an empty swarm. Idle agents are left
behind too. Their saved transcripts/roster stay under the old session ID; no
migration or deletion is performed. Resuming the original session can restore its
saved agents paused, but transient queues/inboxes are not a durable transfer
mechanism. This is why readiness includes buffered and lifecycle work.

The continuing main agent can create new agents for the target as needed.

## Compatibility with the existing configuration

| Component | Required behavior / limit |
| --- | --- |
| Infinite-context v2 | Fork preserves entry IDs and recursive fold custom entries; target must load compatible v2. Anchor the selected leaf before exit. No v1/native-compacted migration. |
| Actor-subagents | Add authoritative readiness/lease and main-identity integration; exclude restart extension from children. New fork has no swarm. |
| pi-mcp-adapter 5 | Normal shutdown attempts owned-resource cleanup; replacement discovers target config/trust and process env. Preserve explicit configured server cwd semantics. |
| Serena / CBM | Fresh launch does not prove correct external project routing. Serena URLs/servers and CBM project IDs remain project responsibilities. |
| Context-pressure | Persisted policy state can follow forked custom entries; verify session-ID rekeying. Its nudges explain the termination limitation. |
| Session naming / footer | Preserve saved name where supported; recreate directory/Git display and timers in the replacement. |
| Codex Fast | Existing runtime flag resets on restart; do not silently assume the old setting survived. |

Target startup must not silently lose infinite-context support while claiming a
successful compatible handoff. Before automatic continuation is submitted, verify
successful v2 branch/fold restoration, not merely extension/tool registration:
IC can retain a state error while its tools remain present. Missing restart guard,
missing compatible IC, or failed restoration must withhold continuation. The
health-proof/guard mechanism remains an implementation question. Nonfatal
extension initialization/state errors are not proof of readiness; extension load
errors in the inspected CLI instead cause exit before interactive startup.
Fresh per-directory instruction discovery must coexist with retained historical
messages, not assume the fork erased old project assumptions.

## Repository / Home Manager deployment

Proposed implementation paths (not created by this specification):

- `bin/pi-restartable`: launcher source, packaged as a Home Manager executable.
- `dotfiles/pi/extensions/pi-restart-in-dir/`: local extension and focused tests.
- `home-modules/pi.nix`: package installation, extension link, and Fish alias.
- `patches/pi-actor-subagents-local.patch`: readiness/identity bridge integration
  if kept within the existing local actor-subagents patch.

Keep the external Pi CLI owned by `nix profile`, as the current module specifies.
Home Manager installs the separately named launcher and manages extension config.
Under `my.pi.enable`, configure:

```nix
programs.fish.shellAliases.pi = "pi-restartable";
```

Do not install another executable named `pi`, force-enable Fish, or change
macOS-only `hosts/hm-cf/`. `command pi` bypasses Fish's alias/function. External
scripts such as `bin/pi-rpc-workers` continue to resolve real Pi normally.

Use the module's existing extension-link convention and child allowlist. No
per-project wrapper settings or service manager are required. Runtime dependencies
other than optional direnv are declared in the launcher package as needed.

## Failure and recovery behavior

| Failure | Outcome |
| --- | --- |
| Missing live launcher, unsupported launch arguments, invalid target, busy state, unknown main identity, or no durable source | Refuse before shutdown; keep current Pi usable, report why, and provide applicable manual instructions. |
| Failure during checkpoint/request preparation | Cancel intent, release lease, report the error, and keep Pi running; shutdown has not been requested. |
| Observed checkpoint/protocol failure after shutdown begins | Invalidate the request; suppress restart and provide recovery instructions. |
| Ordinary exit without committed request | Exit launcher; do not restart. |
| Crash/signal/non-clean exit or invalid/stale request | Do not restart or replay; show an appropriate diagnostic. |
| Target/source disappears after acceptance | Stop with explicit recovery instructions; preserve source session. |
| direnv absent | Launch plainly from target using the pinned executable. |
| direnv present but environment load fails | Show error and manual approval/retry instructions; no bypass or automatic allow. |
| Pinned Pi disappears or replacement fails | Stop visibly; no version substitution, endless retry, or automatic rollback. |
| Target extension/MCP startup warnings | Show diagnostics; do not equate process startup with complete service readiness. |

The source transcript/checkpoint remains the recovery anchor. Show the requested
restart command and an old-session recovery command on launch failure. Once the
old instance has exited, errors cannot be returned to its original tool promise.
The launcher must forward interrupts and avoid orphaning its terminal child;
cleanup must not remove session history or project data.

## Implementation sequence and feasibility gates

Before building the full wrapper, use temporary sessions and a minimal isolated
harness to prove three compatibility gates against the installed Pi/extensions:

1. **Source readiness:** pre-existing queued work causes refusal, not loss. Prove
   coverage of custom/deferred queues as well as public pending messages; an
   accepted isolated handoff checkpoints correctly without unintended other tool
   execution. Verify mixed batches, actor lifecycle races, and lease release.
2. **Target restoration:** deliberately failed IC v2 branch/fold restoration
   prevents automatic continuation before any model request. Tool registration
   is not sufficient; verify a positive restoration-health signal.
3. **Current session state:** change model, thinking level, name, and selected
   branch after launch; fork without the old overrides and prove the latest state
   and recursive folds/IDs are restored. Explicitly capture current state only if
   restoration cannot provide it reliably and the revised contract is reviewed.

If a gate cannot be made reliable through the permitted integration, report the
blocker and revise the contract before proceeding. A check that refuses every
normal session is not a passed gate. Extra old-process API cost is accepted;
lost messages, wrong-directory writes, or broken-fold continuation are not.

After the gates pass:

1. Implement the wrapped user-command path end to end.
2. Complete the agent-callable path and one-time continuation.
3. Wire Home Manager and the Fish alias; verify external RPC remains unchanged.
4. Add further CLI compatibility only when a real caller needs it. No separate
   no-launcher shutdown lifecycle is planned.

## Verification required for implementation

Documentation review alone does not verify runtime behavior. Implementation must
cover the following with focused tests and authorized interactive smoke tests:

- Directory/path validation and quoting, including spaces/metacharacters and
  relative paths; non-Git targets and same-directory restart.
- Busy refusal for main/swarm queues, paused inboxes, spawns, teardown, and races;
  idle-agent acceptance, identity fail-closed behavior, child denial, and mixed
  tool batches. Preparation failures release the lease.
- Session-result persistence, selected-branch checkpointing, infinite-context v2
  recursive folds/IDs, source preservation, and repeated forks with new UUIDs.
- Checkpoint/commit before shutdown, including failures that keep Pi usable.
  Clean exit versus crash/signal, direct-child SIGTERM/SIGHUP that exits 0, wrapper
  interrupts, atomic commit, stale/malformed requests, duplicate consumption,
  vanished launcher, startup failure, and terminal cleanup.
- Fake direnv available/missing/failing; recheck on each restart; inherited
  `DIRENV_DIFF`, ancestor/no rc, and visible unapproved-rc behavior. Do not execute
  unapproved project environments merely to satisfy a test.
- Per-launcher executable pinning despite profile/PATH changes, missing pinned
  executable, and initial/restart argument classification: startup-only values,
  current model/thinking/name restoration, prompt/attachment non-replay, target
  trust isolation, carried whitelist, and unsupported-option refusal before exit.
- User-controlled restart versus exactly-once agent continuation, no startup
  nudge race, visible cwd, proven IC branch/fold restoration before continuation,
  missing guard/IC refusal, fresh MCP discovery, and honest startup diagnostics.
- Plain-Pi refusal/manual instructions without exit, Fish `pi`/`command pi`, and
  unchanged external RPC use.
- Existing actor-subagent/extension tests plus repository checks applicable to
  future script/Nix changes. Nix changes require `just format`,
  `just format-check`, and `nice -n 19 just check`; build affected packages/host
  as required. Do not switch a live system merely for verification.

The extra old-process API-call limitation is explicit; zero calls is not an
acceptance criterion. Reliable shutdown, saved history, correct target cwd/env,
and no overlapping writers are acceptance criteria.

## Remaining implementation and PDO review questions

The architecture and policy above are agreed. These details still need review or
verification, not assumed guarantees:

1. Exact actor readiness/lease API, coverage of asynchronous lifecycle work, and
   enforcement of sole-tool-batch acceptance through the public Pi APIs. Verify
   coverage and actual consumption of main-directed custom messages/core queues;
   public pending-message and idle checks are not authoritative for them. If the
   permitted integration cannot prove absence of pre-existing pending work, fail
   closed or explicitly revise this readiness scope before implementation.
2. Verification of settled/checkpoint/commit-before-shutdown ordering and signal
   invalidation, live-launcher detection, and a target IC restoration health proof
   that can withhold the startup continuation before it acts.
3. Implement/test the bounded CLI whitelist above; unsupported resource/storage
   options refuse before shutdown rather than expanding the initial contract.
4. Behavior of retained project/system context after a cross-project fork; the
   agent must use newly discovered instructions and revalidate absolute paths.
5. PDO fit: can each target's approved environment provide its correct runtime
   routing without side effects? Are project services independently prepared, and
   do fresh instructions identify the correct Serena/CBM/runtime targets?

PDO service setup, port/database ownership, worktree creation/removal, and project
lifecycle hooks remain outside this extension. Review may reveal additional
requirements; feed them back here before changing the implementation scope.

## Evidence and references

Behavior was inspected against installed Pi 1.0.0 and direnv 2.37.1, including
matching published Pi runtime sources. The sibling Pi Git checkout was a different
version and must not be treated as the installed implementation. Static inspection
is not an end-to-end compatibility test; recheck the actual installed versions
before implementation.

- [Pi CLI: forks and startup prompts](https://cdn.jsdelivr.net/npm/@earendil-works/pi-coding-agent@1.0.0/docs/cli.md)
- [Pi extension APIs and lifecycle](https://cdn.jsdelivr.net/npm/@earendil-works/pi-coding-agent@1.0.0/docs/extensions.md)
- [Pi session format](https://cdn.jsdelivr.net/npm/@earendil-works/pi-coding-agent@1.0.0/docs/sessions.md)
- [Pi agent-loop termination/continuation source](https://cdn.jsdelivr.net/npm/@earendil-works/pi-agent-core@1.0.0/dist/agent-loop.js)
- [direnv exec environment handling](https://raw.githubusercontent.com/direnv/direnv/v2.37.1/internal/cmd/cmd_exec.go)
- [direnv rc approval behavior](https://raw.githubusercontent.com/direnv/direnv/v2.37.1/internal/cmd/rc.go)
- [Current Pi Home Manager module](../home-modules/pi.nix)
- [Current Fish module](../home-modules/fish.nix)
- [Pi context-maintenance guidance](pi-context-maintenance.md)
- [Initial investigation notes](../pi-worktree-runtime-investigation.md): background
  research, including PDO concerns and earlier alternatives; this proposal
  supersedes its unresolved Pi choices. The notes are currently untracked.
