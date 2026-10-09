# Pi restart-in-directory design

Status: implemented and verified against Pi 1.0.0 under the agreed best-effort contract. This
records the latest Pi decisions, bounded compatibility proofs, independent source
review, and PDO fit feedback. Implementation belongs in this repository, not in
PDO. No Pi core/TUI changes are planned.

## Usage and maintained checks

After applying the Home Manager configuration, interactive Fish `pi` runs
`pi-restartable`; `command pi` still bypasses it. Use
`/restart-in-dir /path/to/directory` or the main-agent `restart-in-dir` tool with
`{ "directory": "/path/to/directory" }`. The command treats its entire argument
as a directory, including spaces; it is not a shell expression. `/restart-in-dir .`
resumes the current session, while a different canonical directory forks it.

Maintained verification entrypoints:

- `python3 -m unittest discover -s tests -p 'test_pi_*.py'`: launcher and existing RPC tests.
- `scripts/test-pi-context.sh`: patched IC, context-pressure and restart-extension
  typecheck/lint/tests against the pinned Pi 1.0.0 SDK in a disposable workspace.
  Upstream's own 0.87.0 development dependency pins are not changed.
- `scripts/test-pi-restart.py --ic-source <patched-IC-root> --actor-source <patched-actor-root>`:
  isolated actual-Pi PTY tests with a fake provider, including native same-directory
  resume/paused swarm, cross-directory forks, recursive folds, historical settings,
  one-shot tool continuation (including extension reload/marker replay) and
  failed/missing guards. `--help` lists executable
  overrides. No real provider or project envrc is executed.

Build/check verification does not activate the configuration. Activation remains
an explicit operator action; do not switch the live system just to test this feature.

## Goal and scope

Move a foreground, interactive Pi conversation to another directory by gracefully
exiting Pi and starting a replacement in the same terminal. Git worktrees are an
important use case, but the target can be any existing directory.

Cross-directory restarts retain the conversation through a fork with a new
session ID. Same-directory restarts resume the exact current session file with
its existing ID. Both rebuild tools, instructions, project configuration,
environment, and extension services instead of mutating a running workspace.

This is independent of `pi-worktree`. It does not create/remove worktrees, change
branches, start project services, allocate ports, migrate subagents, or configure
PDO runtimes. An occasional unnecessary API call while the old instance shuts
down is accepted. Readiness is best-effort: hidden queued user input may be lost,
and running user Bash processes may be interrupted. These limitations are
explicitly accepted instead of adding Pi core/TUI or custom-editor integration.
Saved-history durability and restoration checks remain required.

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

### Readiness: best-effort refusal, not automatic draining

Refuse observed main/swarm activity or queued work instead of waiting for it to
finish, killing agents, or pausing active agent work to make a restart possible.
The user/agent finishes outstanding work and retries. Running user Bash processes
are not a blocker; interruption during shutdown is accepted, and side effects
already performed cannot be undone. Do not deliberately discard known completed
results or queued messages merely to pass a check.

For the tool, the switching call itself is necessarily part of an active main
turn. Permit that call, but refuse other observed concurrent or pending work. The
restart tool must be the sole call in its assistant tool-call batch; reject a
mixed batch before accepting the handoff. Register it for sequential execution.

Check public main idle/pending state and the available installed-extension
signals. Actor-owned readiness covers queued swarm messages, active work,
compaction/retries, paused or buffered inboxes, pending spawns, reserved names,
and in-flight teardown. An idle agent record alone does not make the swarm busy;
idle subagents can be left behind on cross-directory forks or restored paused
on same-directory resumes under the policy below.

A small actor-subagents integration supplies a synchronous readiness check and
handoff lease for actor-owned work. Once acquired, new swarm work is refused
until shutdown or until failed preparation releases the lease. A footer,
activity boolean, roster file, or empty record map alone is insufficient: these
omit pending work or can report empty before cleanup finishes. This is not an
authoritative lock or inventory of Pi core/TUI work.

Exclude the extension from the configured child-extension allowlist, and also
check main-agent identity at execution. When the actor bridge exists but identity
or its owned readiness cannot be established, fail closed. A standalone
interactive Pi without actor-subagents is supported with no swarm to check. An
installed actor extension without the required bridge must refuse, not assume
quiescence.

Prevent a second restart request and recheck observable main/extension work
before accepting and before final checkpoint/commit. Cooperate with installed
message senders where useful, but do not promise a fully idle check or refuse all
normal sessions because unobservable core queues cannot be proven empty.

Known accepted gaps include:

- TUI input submitted during `/tree` branch summarization can remain queued after
  cancellation or a failed queued-prompt submission, despite public idle state.
- Input accepted during prompt preflight can remain in a separate TUI buffer
  while the first turn executes the restart tool.
- Custom/deferred messages and asynchronous settled handlers are not completely
  covered by public pending-message counts; settlement has narrow idle windows.

Normal successful runs generally drain their queues; these are limitations, not
claims that every idle session has pending work. Hidden accepted input may be
lost on restart. No core/TUI queue bridge, replacement editor, or strict
zero-loss readiness proof is part of this version. Later old-process nudges are
also not globally locked out; see termination limitations.

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
`--fork <exact-source-session-file>` for a different directory or
`--session <exact-source-session-file>` when canonical target and current session
cwd are equal, with the target as OS cwd. Replacement argv
also contains the wrapper-owned namespaced handoff flag and, only for automatic
continuation, an opaque positional startup marker as specified below. These are
generated protocol arguments, not replayed user flags or prompts.

Do not reproduce Pi's CLI. Classify a bounded whitelist; unsupported options do
not prevent the initial launch, but make that invocation non-restartable. Refuse
its restart before checkpoint/shutdown and identify the unsupported option without
printing secret values. Add support only for a demonstrated caller.

| Classification | Initial supported options | Restart behavior |
| --- | --- | --- |
| Startup-only | `--session`, `--continue`, `--resume`, `--fork`, `--session-id`; positional prompts and `@file` inputs | Do not replay. Fork/resume the exact currently active session, not the original selection; do not repeat prompts/attachments. |
| Startup state overrides | `--model`, `--provider`, `--thinking`, `--name` | Do not replay. Use native fork/resume restoration of the selected conversation history; do not generate fresh live-setting overrides. |
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
intent/prompt metadata. Do not store credentials or command text to execute. Use
atomic publication inside the private directory. Validate schema,
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
7. The replacement forks into a different target cwd or resumes the same-directory
   session, using native selected-history settings. It displays/records the active
   directory and handoff outcome. The
   required handoff flag witnesses guard loading. If continuation is requested,
   process the opaque startup marker after initialization, validate restoration,
   and transform it into exactly one continuation prompt.

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

### Fork across directories; resume within the same directory

For different directories, use `--fork`, not `cd target && pi --session old-file`:
ordinary resume uses the cwd recorded in the source session and can mix old
project context with the new environment. CLI forking uses the new startup cwd
and new session identity while copying non-header entries and their IDs,
including extension custom entries.

When canonical target equals canonical current session cwd (including
`/restart-in-dir .`), use `--session <exact-current-session-file>` instead.
The old writer must still exit before the replacement opens the file. This
preserves the session ID; it is a process/environment restart, not a fork.
Canonicalize recorded cwd for comparison without rewriting the header.

Do not rewrite JSONL headers, migrate historical sessions, use native compaction,
or transfer SQLite/session sidecars by copying directory trees. The old session
remains available after a fork; a same-directory resume continues the original
session file.

### Native model/thinking/name restoration

Keep Pi's native fork/resume semantics rather than capturing and overriding the live
model/thinking settings. Do not replay the original `--model`, `--provider`,
`--thinking`, or `--name`, and do not synthesize replacement flags from current
runtime values. Ordinary latest-history forks restore the latest recorded
settings. Historical-branch forks restore that branch's recorded settings.

"Selected history" means the ancestry of the selected Pi conversation leaf,
not a Git/worktree branch. For example, after A/low history, switching to B/high,
and navigating back, the existing process still runs B/high. A restart checkpoint
appended on the earlier history forks that history and restores A/low. This is
intentional native behavior, not a restoration failure. The latest saved session
name is file-global and survives independently of the selected branch.

Before automatic continuation, check target model availability/authentication
and expected native thinking compatibility. Distinguish intentional historical
restoration from an unavailable-model fallback or unexpected clamp; report such
problems and withhold automatic continuation rather than silently working with
an unintended fallback. Empty/no-message histories follow native defaults and
need explicit test coverage, not a live-settings-preservation promise.

### Who gets control after restart?

| Invocation | Replacement behavior |
| --- | --- |
| User `/restart-in-dir` | Finish startup and return control to the user; no positional startup marker |
| Main-agent `restart-in-dir` tool | Supply one opaque startup marker, transformed into one validated continuation prompt |

Scope continuation to this one consumed handoff; ordinary resumes must not
repeatedly nudge the agent. A private durable consumption receipt binds the
current launcher child and incoming handoff, surviving session-start events and
extension reloads; a fresh replacement child has independent authority. Claim
it synchronously after main identity/launcher validation, before awaited
restoration/authentication work. Failed validation also consumes the intent.
The real prompt is derived from private handoff
metadata, not copied from the original CLI prompt or attachments. It says that
the restart reached the requested directory, identifies source/target, and asks
the agent to verify cwd/project instructions and relevant environment/MCP routing
before resuming its task. Old transcript instructions and tool results remain
historical evidence, not proof that the new workspace or its services are correct.

### Required handoff flag plus opaque positional marker

Every replacement launch supplies the extension-registered string flag
`--pi-restart-in-dir-handoff <one-use-id>`. The flag identifies the consumed
handoff and witnesses guard loading under the requirement that this namespace
is registered only by the trusted `pi-restart-in-dir` extension. In inspected Pi,
an unknown extension flag fails startup before interactive initialization or a
model request. Pi checks globally registered names, not authenticated owner
identity; another extension registering the same name would defeat this absence
check and is outside the supported contract. Merely exporting an environment
variable or checking registered tools cannot provide the missing-extension check.

For agent-requested continuation, also supply an opaque positional marker tied
to the handoff. It contains no task instructions and is never intended for the
model. Pi processes positional startup input after awaited startup hooks,
resource application, and interactive initialization. The extension's `input`
handler validates the flag, one-use identity, main context, handoff data, target,
IC health, and native settings before returning a transformed real prompt.
Invalid/missing health handles the marker without starting a turn, reports why,
and leaves control with the user. Consume continuation intent once; ordinary
later input must not retrigger it.

Both mechanisms are needed:

- The flag provides fail-closed guard loading and selects metadata-owned content.
  A marker alone could become a normal prompt if the extension were missing.
- The marker provides safe post-initialization scheduling. A flag alone does not
  schedule a turn, and Pi has no public startup-ready event in this version.

Do not send the continuation from `session_start`, `resources_discover`, or an
assumed timer/microtask delay. Those can run before later startup hooks or
resource application complete. No Pi core startup-ready event is added.
Initialization also does not prove arbitrary fire-and-forget external services
are ready; service readiness remains a separate responsibility.

### IC health guard and startup-turn assumption

Add a small synchronous request/reply bridge through public `pi.events` in
infinite-context v2. At marker processing time, require a positive compatible
reply keyed to the current session ID and selected leaf, based on current
branch/fold/projection validation. Missing, stale, incompatible, or failed health
must withhold continuation. Tools can remain registered after IC stores a
restoration error, so registration or a cached "loaded" boolean is not proof.

**Requirement: no other extension starts a model turn during restart startup.**
This includes approved target-project extensions and custom
`pi.sendMessage(..., { triggerTurn: true })` nudges. Such custom-message triggers
can bypass the `input` guard. The guard protects the planned marker-derived
continuation under this assumption; it is not a global provider-request latch or
sandbox against arbitrary extension code. Do not promise protection if another
startup source violates this requirement. The inspected configured extensions
do not auto-start model turns during startup.

The old tool cannot return after replacement startup: its promise belongs to the
exited process. Launch errors are reported by the wrapper to the user. Success is
reported by the new instance; no transparent pending-tool reconnection protocol
is planned. "Started in target" is not a promise that every external service or
extension initialized successfully; nonfatal startup diagnostics remain visible.

### Cross-directory forks do not transfer subagents

A cross-directory fork's new main-session ID starts with an empty swarm. Idle
agents are left behind too. Their saved transcripts/roster stay under the old
session ID; no migration or deletion is performed. The continuing main agent can
create new agents for the target as needed.

Same-directory restart retains the main-session ID and lets actor-subagents
restore its saved swarm as paused. Transient queues/inboxes are not a durable
transfer mechanism in either case. This is why readiness includes buffered and
lifecycle work.

## Compatibility with the existing configuration

| Component | Required behavior / limit |
| --- | --- |
| Infinite-context v2 | Fork preserves entry IDs and recursive fold custom entries; target must load compatible v2. Anchor the selected leaf before exit. No v1/native-compacted migration. |
| Actor-subagents | Add actor-owned readiness/lease and main-identity integration, not a core/TUI readiness guarantee; exclude restart extension from children. Cross-directory fork has no swarm; same-directory resume restores the saved swarm paused. |
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
agreed guard uses the required handoff flag, post-init marker/input handling,
and a synchronous validated IC health reply under the no-other-startup-turn
assumption. Nonfatal extension initialization/state errors are not proof of
readiness; extension load errors in the inspected CLI instead cause exit before
interactive startup.
Fresh per-directory instruction discovery must coexist with retained historical
messages, not assume the fork erased old project assumptions.

## Repository / Home Manager deployment

Implementation paths:

- `bin/pi-restartable`: launcher source, packaged as a Home Manager executable.
- `dotfiles/pi/extensions/pi-restart-in-dir/`: local extension and focused tests.
- `home-modules/pi.nix`: package installation, extension link, and Fish alias.
- `patches/pi-actor-subagents-restart.patch`: actor-owned readiness/identity bridge,
  applied after the existing actor local patch.
- `patches/pi-infinite-context-restart.patch`: validated health bridge, applied
  after the existing `pi-infinite-context-enable-nudges.patch`.

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
| Missing live launcher, unsupported launch arguments, invalid target, observed busy state, unknown main identity, or no durable source | Refuse before shutdown; keep current Pi usable, report why, and provide applicable manual instructions. |
| Failure during checkpoint/request preparation | Cancel intent, release lease, report the error, and keep Pi running; shutdown has not been requested. |
| Observed checkpoint/protocol failure after shutdown begins | Invalidate the request; suppress restart and provide recovery instructions. |
| Ordinary exit without committed request | Exit launcher; do not restart. |
| Crash/signal/non-clean exit or invalid/stale request | Do not restart or replay; show an appropriate diagnostic. |
| Target/source disappears after acceptance | Stop with explicit recovery instructions; preserve source session. |
| direnv absent | Launch plainly from target using the pinned executable. |
| direnv present but environment load fails | Show error and manual approval/retry instructions; no bypass or automatic allow. |
| Pinned Pi disappears or replacement fails | Stop visibly; no version substitution, endless retry, or automatic rollback. |
| Missing required handoff-flag owner, with no conflicting registration | Pi rejects the unknown extension flag before startup; wrapper reports recovery instructions. |
| Missing/invalid IC health, handoff marker, or unexpected target model/thinking fallback | Withhold automatic continuation, show the error, and leave user control where startup succeeded. |
| Target extension/MCP startup warnings | Show diagnostics; do not equate process startup with complete service readiness. |
| Hidden queued input or running user Bash missed by best-effort checks | Restart may lose unpersisted queued input or interrupt Bash; accepted limitation, not a fully idle guarantee. |

The source transcript/checkpoint remains the recovery anchor. Show the requested
restart command and an old-session recovery command on launch failure. Once the
old instance has exited, errors cannot be returned to its original tool promise.
The launcher must forward interrupts and avoid orphaning its terminal child;
cleanup must not remove session history or project data.

## Implementation sequence and bounded compatibility checks

The earlier strict readiness/live-settings gates were investigated and the
contract deliberately narrowed. Full core/TUI readiness could not be proved
through the selected public APIs; best-effort checking is now accepted instead.
Native historical-branch settings restoration is intentional, not a failed
requirement. These findings no longer require a Pi core change or block the
architecture.

Before building the full wrapper, validate the scoped integration against the
installed Pi/extensions with temporary sessions and an isolated harness:

1. **Best-effort source readiness:** refuse observable pending/busy work; test
   normal quiescent acceptance, main identity, sole-tool batches, actor-owned
   lifecycle checks/lease release, and checkpointing. Record hidden-queue limits
   rather than claiming complete coverage or refusing every normal session.
2. **Target restoration:** under the no-other-startup-turn requirement, failed IC
   v2 validation prevents the marker-derived continuation before its model
   request. Test positive health and missing guard/IC, not tool registration.
3. **Native session state:** fork latest and historical selected histories without
   old overrides; verify their respective recorded model/thinking, global latest
   name, recursive folds/IDs, and new cwd/UUID. Test target availability/fallback
   checks without synthesizing live-setting overrides.

Bounded proofs using the actual installed binary and an in-process fake provider
already demonstrated ordinary and historical native fork behavior, positive and
failed IC guarding, missing-flag-owner startup refusal, and early flag-only nudge
races. Source inspection and an exact-method projection demonstrated hidden TUI
queue gaps. These temporary proofs are not production code or complete runtime
verification. Replace/extend them with maintained integration tests.

If scoped checks reveal a new incompatibility, report and revise the integration
instead of silently weakening durability, target cwd isolation, or fold health.
Accepted limits are extra old-process API cost, missed hidden queues, Bash
interruption, and the explicit startup-turn assumption. Saved history,
no overlapping writers, and a guarded continuation remain required.

After the scoped checks:

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
- Best-effort refusal for observable main/swarm work and actor-owned queues,
  paused inboxes, spawns, teardown, and races; normal idle-agent acceptance,
  identity fail-closed behavior, child denial, and mixed tool batches. Preparation
  failures release the lease. Cover/document hidden-input gaps and permitted user
  Bash interruption without asserting a complete core/TUI readiness proof.
- Session-result persistence, selected-branch checkpointing, infinite-context v2
  recursive folds/IDs, source preservation, repeated cross-directory forks with
  new UUIDs, and same-directory resumes with the existing UUID/paused swarm.
- Checkpoint/commit before shutdown, including failures that keep Pi usable.
  Clean exit versus crash/signal, direct-child SIGTERM/SIGHUP that exits 0, wrapper
  interrupts, atomic commit, stale/malformed requests, duplicate consumption,
  vanished launcher, startup failure, and terminal cleanup.
- Fake direnv available/missing/failing; recheck on each restart; inherited
  `DIRENV_DIFF`, ancestor/no rc, and visible unapproved-rc behavior. Do not execute
  unapproved project environments merely to satisfy a test.
- Per-launcher executable pinning despite profile/PATH changes, missing pinned
  executable, and initial/restart argument classification: startup-only values,
  native latest/historical model/thinking and global-name restoration,
  prompt/attachment non-replay, target trust isolation, carried whitelist, and
  unsupported-option refusal before exit. Test target fallback/clamping and
  empty-history behavior; do not require exit-time live settings to survive `/tree`.
- User-controlled restart versus exactly-once agent continuation, required
  namespaced flag loading, opaque marker transformation/non-delivery to the model,
  visible cwd, validated IC branch/fold health before continuation, missing/stale
  guard/IC refusal, fresh MCP discovery, and honest startup diagnostics. Show that
  a custom startup nudge bypasses input so the no-other-startup-turn assumption
  stays explicit; do not claim a global provider gate.
- Plain-Pi refusal/manual instructions without exit, Fish `pi`/`command pi`, and
  unchanged external RPC use.
- Existing actor-subagent/extension tests plus repository checks applicable to
  script/Nix changes. Nix changes require `just format`,
  `just format-check`, and `nice -n 19 just check`; build affected packages/host
  as required. Do not switch a live system merely for verification.

Zero old-process API calls and complete hidden-queue preservation are not
acceptance criteria. Reliable shutdown, saved history, correct target cwd/env,
native selected-history restoration, no overlapping writers, and validated
automatic continuation under the startup-turn assumption are acceptance criteria.
Documentation-only edits need diff/link checks, not Nix evaluation or builds.

## Operational requirements and remaining limits

The launcher, extension, actor-owned readiness/lease, IC health bridge and bounded
CLI whitelist are implemented. Automated tests cover the scoped lifecycle and
restoration contract; they do not prove every live project/service configuration.

1. Readiness remains best-effort: hidden queued input can be lost and running user
   Bash interrupted. There is no Pi core/TUI queue bridge or global provider latch.
2. Target extensions must not start a model turn during restart startup. The
   required handoff flag namespace must have only the trusted extension owner.
3. Retained historical context does not establish target correctness. Revalidate
   newly discovered instructions, absolute paths, environment and MCP routing.
4. Project services, port/database ownership, worktree creation/removal and PDO
   lifecycle hooks remain external responsibilities. An approved environment must
   provide the intended routing without requiring this extension to start services.
5. Unsupported CLI resource/storage/policy options intentionally refuse restart.
   The pinned executable is not a GC root, and extensions/settings remain mutable.

Real project envrc/MCP/provider smoke tests and live Home Manager activation were
not performed. The maintained PTY tests use isolated sessions and a fake provider.

## Evidence and references

Behavior was inspected against installed Pi 1.0.0 and direnv 2.37.1, including
matching published Pi runtime sources. Isolated actual-binary RPC/interactive
proofs used temporary sessions and an in-process fake provider, without external
provider calls, live-session mutation, or envrc execution. They covered native
fork/restoration and guarded startup behavior; hidden-queue evidence also used
static inspection/exact-method projections, not a full TUI race reproduction.
The sibling Pi Git checkout was a different version and must not be treated as
the installed implementation. Bounded proofs are not end-to-end production
verification; recheck actual installed versions during implementation.

- [Pi CLI: forks and startup prompts](https://cdn.jsdelivr.net/npm/@earendil-works/pi-coding-agent@1.0.0/docs/cli.md)
- [Pi extension APIs and lifecycle](https://cdn.jsdelivr.net/npm/@earendil-works/pi-coding-agent@1.0.0/docs/extensions.md)
- [Pi session format](https://cdn.jsdelivr.net/npm/@earendil-works/pi-coding-agent@1.0.0/docs/sessions.md)
- [Pi agent-loop termination/continuation source](https://cdn.jsdelivr.net/npm/@earendil-works/pi-agent-core@1.0.0/dist/agent-loop.js)
- [direnv exec environment handling](https://raw.githubusercontent.com/direnv/direnv/v2.37.1/internal/cmd/cmd_exec.go)
- [direnv rc approval behavior](https://raw.githubusercontent.com/direnv/direnv/v2.37.1/internal/cmd/rc.go)
- [Current Pi Home Manager module](../home-modules/pi.nix)
- [Current Fish module](../home-modules/fish.nix)
- [Pi context-maintenance guidance](pi-context-maintenance.md)
