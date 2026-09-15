# Pi standalone upstream migration

## Current: infinite-context v2 preparation (2026-09-15)

The configured pin is
[`639c8f5e5a77319a4423d238bf48b984424d74ac`](https://github.com/fdietze/pi-infinite-context/tree/639c8f5e5a77319a4423d238bf48b984424d74ac),
verified against Pi **0.85.1**. This preparation is **build/check only, not
activation**. The older v1 cutover record below is historical, not a procedure
for this upgrade. PRs #2/#3 were superseded by v2; none of their commits are
ported here.

V2 stores `{version:2, roots:[...]}`. `context_fold` wraps contiguous visible
roots with an explicit summary; earlier folds remain unchanged children.
`context_summary` replaces or clears one visible root fold's summary.
`context_map` lists roots or one fold's direct children with 1-based pagination;
`context_peek` reads one singular `id` with 1-based line windows.
`context_search` still takes JavaScript regex `patterns`. There is no unfold
operation, and reads never restore archived context.

The refreshed local nudge patch retains `enableNudges=false` in
`home-modules/pi.nix`. Only `context-pressure` supplies automatic reminders;
all five folding tools and **manual, threshold, and overflow native-compaction
blocking** remain enabled. Missing/invalid config defaults to upstream nudges
(enabled at 75%, then 5-point bands). Config is read at session start, or the
first turn if a headless host omits that event.

Both `context_fold` (`{ids, deltaTokens}`) and `context_summary`
(`{id, deltaTokens}`) report **after minus before** estimates: negative frees
space. The pressure extension normalizes both to its existing positive-savings
policy in live events and branch statistics. Errors count as failed attempts;
zero-yield and growth results do not satisfy productive maintenance. Cheap v1
result support remains for staged rollout; this is **not snapshot migration**.
`/context-status` reports combined maintenance attempts and estimated savings,
not net session savings including later tool output.

The installed extension path, `enableNudges=false`, and `context-pressure`
remain wired together. Actor settings stay `maxAgents=16`, `maxSpawnDepth=3`,
with the existing child-extension list unchanged. Do not duplicate these
managed extensions through `pi install`.

### Verification and later manual activation

Run `scripts/test-pi-context.sh` from this checkout for the locked upstream
suite, local nudge tests, and pressure tests/typecheck/lint. It needs Nix and
network/cache access, installs only the locked development dependencies in a
fresh scratch directory, retains artifacts, and never loads a live extension.
For Nix changes also run `nice -n 19 just format`,
`nice -n 19 just format-check`, `nice -n 19 just check`, and `just build` (the
recipe already lowers Nix priority).

When you deliberately choose to activate later on `nixos-work`:

1. Preserve a short handoff and finish/exit active Pi sessions and their child
   agents normally. Do not reload an active v1 session across this upgrade.
2. From `/home/felix/nixos`, run `nice -n 19 just switch` after reviewing the
   build. This is the activation step; none was performed during preparation.
3. Launch `pi` for a **fresh session**, without `--continue`/`--resume` or
   `/resume`. Keep historical JSONL files untouched. V1 fold snapshots and
   sessions containing native compaction are unsupported; do not run the old
   metadata migrator below, fork/clone the old session as a migration, or use
   `/compact` as a workaround.
4. In the new session, check the five-tool surface (including
   `context_summary`, no unfold), `/context-status`, and the managed
   `extensions/infinite-context.json` setting. Pi CLI is profile-owned and
   already 0.85.1; this pin update does not upgrade or restart it.

The guidance and pressure extension are repository-linked; editing their files
does not reload already-running extension instances. New sessions/processes
can see those source edits even before a system switch, which is why v1 result
support remains and the instructions defer to exposed schemas during staging.

## Historical v1 standalone cutover (not v2 instructions)

Everything below records the earlier v1 integration and its then-current
versions. In particular, the old patch commands and metadata migration are
**obsolete for v2; do not run them for this upgrade**.

Historical status: migration and coordinated cutover completed and verified on
`nixos-work`. The dedicated upstreams, migrated session metadata, foreground
session-name package, and live-linked repository changes are active. Issues
`nixos-8ss` and `nixos-eo2` are closed.

## Sources and setup at the v1 cutover

| Source                                                                                                              | Audited revision                           |
| ------------------------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| Removed `fdietze/dotfiles` input                                                                                    | `262fb764dedc2678b1522a21cbbd8818622be56c` |
| [pi-infinite-context](https://github.com/fdietze/pi-infinite-context/tree/f51891521ed9baf232133d6e507bb718e6a43023) | `f51891521ed9baf232133d6e507bb718e6a43023` |
| [pi-actor-subagents](https://github.com/fdietze/pi-actor-subagents/tree/1e8533f6ddfb83401257a31ee6356b0f48ce2167)   | `1e8533f6ddfb83401257a31ee6356b0f48ce2167` |
| [pi-session-name](https://github.com/fdietze/pi-session-name/tree/89dafe1dc48968f20d414ac0c922b3fd6cb88347)         | `89dafe1dc48968f20d414ac0c922b3fd6cb88347` |

Before this preparation, `home-modules/pi.nix` extracted `context-prune` and
`subagents` from the dotfiles input's
`modules/home-manager/profiles/ai-agents/pi-extensions/`. The prepared module
instead consumes two dedicated, pinned `flake = false` inputs, copies each
extension from its upstream `extensions/` directory, and applies one local
patch per source. The old eight actor patch applications and `context-prune`
source are no longer wired. Their patch files remain only as historical design
input; the consolidated actor patch records the new deployment.

Pi itself is profile-owned at 0.84.4. The new repositories develop against
0.84.2; inspected SDK APIs remain available in the 0.84.4 documentation, and
the migrated extensions were subsequently verified in the live 0.84.4 session.

Do not also install the same extensions through Pi's package manager.

## Nix wiring and deployed configuration

`flake.nix` and `flake.lock` replace `fdietze-dotfiles` with:

- `pi-infinite-context` at `f51891521ed9baf232133d6e507bb718e6a43023`
- `pi-actor-subagents` at `1e8533f6ddfb83401257a31ee6356b0f48ce2167`

`home-modules/pi.nix` deploys patched `infinite-context` and
`actor-subagents`, writes `extensions/infinite-context.json` with
`{"enableNudges":false}`, and writes the actor settings at
`actor-subagents/settings.json` with flat `maxAgents`, `maxSpawnDepth`, and
six-entry `childExtensions` keys. `noExtensions: true` remains in the actor
source/deployment patch rather than this settings JSON. The old
`xdg.configFile."pi/subagents/child-extensions.json"` is removed. Pi CLI
ownership remains in the profile. Foreground-only `pi-session-name` settings
were applied from `patches/pi-live-linked-migration.patch`; the Git package is
not in the child allowlist.

The input URLs include the commit revisions, so an intentional future update
starts by auditing a chosen commit and editing only that input's `rev=` in
`flake.nix`. Rebase its patch, rerun its upstream CI, then run the
corresponding lock command:

```sh
nix flake lock --update-input pi-infinite-context
nix flake lock --update-input pi-actor-subagents
```

Do not replace the revision with a branch or unreviewed HEAD. The combined lock
command is
`nix flake lock --update-input pi-infinite-context --update-input pi-actor-subagents`,
but one-at-a-time updates make review safer. Inspect `git diff -- flake.lock`:
only the deliberately changed input node and root references are expected.
Restore unrelated lock changes before proceeding.

The coordinated cutover activated this configuration and removed the obsolete
XDG child-policy path. The historical cutover procedure below must not be
rerun on this migrated host; use the repository's normal build and activation
workflow for future configuration changes.

## Infinite-context notice option

`patches/pi-infinite-context-enable-nudges.patch` is an upstream-facing patch
against the revision above: implementation, upstream README documentation,
and executable tests only. It does not include this repository's migration report.

Configure the patched extension with:

```json
{
  "enableNudges": false
}
```

File: `<Pi agent dir>/extensions/infinite-context.json`, normally
`~/.pi/agent/extensions/infinite-context.json`; Pi's agent-directory override
is respected. The default is `true`. Settings reload on `session_start`;
missing files are silent, invalid settings warn and use the default.
There is no project-local override.

This disables **only the automatic agent-facing maintenance nudges** (the
75%-and-up banded `turn_end` reminders). Tools, tool results/errors, and the
human-facing automatic-compaction warning remain active. It leaves
`context-pressure` responsible for agent reminders after migration.

To apply and test independently, run from this repository's root:

```sh
patch="$PWD/patches/pi-infinite-context-enable-nudges.patch"
workdir=$(mktemp -d)
git clone https://github.com/fdietze/pi-infinite-context "$workdir"
git -C "$workdir" checkout --detach f51891521ed9baf232133d6e507bb718e6a43023
git -C "$workdir" apply --check "$patch"
git -C "$workdir" apply "$patch"
(
  cd "$workdir"
  nice -n 19 nix develop -c npm ci
  nice -n 19 nix develop -c npm run ci
)
```

### Breaking changes and required companion adjustments

- Tools `context_collapse`/`context_expand` become
  `context_fold`/`context_unfold`.
- Persisted custom-entry type `context-prune` becomes `infinite-context`.
  **Old fold snapshots are ignored.** Original transcript data survives, but
  resumed sessions can suddenly regain a large amount of active context.
  There is no built-in legacy migration.
- `context_search` takes regex `patterns[]`, not literal substring
  `queries[]`; matching is case-insensitive ECMAScript regex per line, and
  invalid patterns fail. Literal callers must escape regex metacharacters.
- `context_peek` changes output/caps and adds a line `offset`. Fold stubs no
  longer carry inline IDs; obtain IDs from `context_map` and tool results.
- Active-context handling now uses `buildContextEntries()` after native
  compaction, adds addressable roles and reconciles spans lazily. Token
  estimates account for Pi image/bash/summary shapes. Tool results whose
  calls were folded are also removed from provider context.

Update `dotfiles/pi/extensions/context-pressure/index.ts`: persisted branch
statistics (`branchStats`), the `tool_result` listener, and reminder text.
Update `policy.ts`'s `isCollapseDetails` validator and associated tests.
The new result is `toolName === "context_fold"` with `details.action === "fold"`;
savings still use `deltaTokens`, and the context window still comes from
`ctx.getContextUsage()`, not result details. A tool-name-only rename is insufficient.
Update active guidance and relevant context-maintenance documentation too.

Do not load `context-prune` and `infinite-context` together: both install
context overlays with independent persisted state.

## Actor-subagents

### API, policy, and configuration

| Current                                       | New upstream                                               |
| --------------------------------------------- | ---------------------------------------------------------- |
| `spawn_agent`                                 | `spawn_subagent` (initial `message` now required)          |
| `list_agents`                                 | `list_subagents`                                           |
| `kill_agent`                                  | `kill_subagent` (cascades descendants)                     |
| `agent_history`                               | `subagent_history` (`limit` minimum 1)                     |
| `resume_agents`                               | `resume_subagents`                                         |
| `/agents`                                     | `/subagents`                                               |
| `/pause-agents`, `/resume-agents`, `/killall` | `/subagents-pause`, `/subagents-resume`, `/subagents-kill` |

`send_message` retains its array of recipients but now waits for a bounded
receiver reaction (up to 3 seconds, recipients in parallel), rather than
returning immediately after delivery. Spawning also waits for initial
reaction, not task completion. The acknowledgment/go-ahead handshake is
still prompt guidance, not runtime enforcement. `/feed` was removed; panel
input is now a real user turn. The panel is a focused bottom-half overlay
rather than the old fullscreen UI, with revised keybindings.

Update the tool names in `dotfiles/codex/AGENTS.md` and local patch prompts.
Preserve the independent-work wording and configured model-routing policy;
neither has been upstreamed.

Move the child-extension policy from
`~/.config/pi/subagents/child-extensions.json` to
`<Pi agent dir>/actor-subagents/settings.json`. New JSON keys are flat:
`maxAgents`, `maxSpawnDepth`, `childExtensions`. The defaults are eight live
children and depth three. Caps are read on engine creation; the child list
is read per spawn. Preserve `noExtensions: true` and the fail-closed explicit
allowlist, including **all six** entries:

- `npm:pi-mcp-adapter@2.17.0`
- `npm:@juicesharp/rpiv-web-tools@2.3.1`
- `git:github.com/DietrichGebert/ponytail`
- the new `infinite-context` extension path (replacing `context-prune`)
- the local `context-pressure` path
- the local `codex-fast` path

**The 200-turn swarm budget has been removed entirely.** Agent/depth caps
are not substitutes for a cumulative turn/cost limit. Upstream pause/resume
now concerns manual or restored-session pauses, not exhausted budgets.

### Existing patch disposition

These refer to `patches/fdietze-pi-subagents-*.patch`; old patches cannot
simply be applied to the newly modular source tree.

| Patch suffix                     | Migration treatment                                                                                                                                      |
| -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bind-errors`                    | Rebase; upstream does not supply the local error callback. `bindExtensions.onError` is supported by the development SDK.                                 |
| `independent-work`               | Rebase; upstream still has stricter message-only working instructions.                                                                                   |
| `model-routing`                  | Rebase; preserve local AGENTS.md routing rather than upstream's generic inheritance advice.                                                              |
| `remove-redundant-model-refresh` | Drop: upstream already removed that refresh.                                                                                                             |
| `engine-reset`                   | Port the intent, not old budget/frozen fields; address restored-pause state on true session replacement.                                                 |
| `activity`                       | Rebase; upstream's internal activity display does not publish our activity bridge.                                                                       |
| `fast`                           | Rebase; upstream lacks `set_fast`, the spawn flag, and our session/controller bridge. Preserve direct-owner checks and parent-desired-state inheritance. |
| `session-names`                  | Rebase; preserve both the name-lookup bridge consumed by `context-pressure` and supported SessionManager name writes.                                    |

The upstream naming code optional-calls `SessionManager.setSessionName`,
which does not exist in its 0.84.2 SDK and silently does nothing there.
`appendSessionInfo` is the supported method, also documented by Pi 0.84.4.
Keep the local restore guard so an existing user-renamed child is not overwritten.
The separate `pi-session-name` extension does not replace this bridge/fix.

Local Fast inheritance is correct for newly spawned children, including
nested children and explicit `false`. However, current restore metadata does
not persist Fast: restored children reset it to off. Preserving Fast across
restore would be a separate behavior change, not part of mechanical rebasing.

### Reliability caveats

- `nixos-v8n` remains unresolved: waiting for initial reaction does not detect
  a provider stream that subsequently stalls. There is no completion watchdog.
- `nixos-a3o` remains unresolved: late asynchronous delivery rejection still
  calls `reportError` without a delivery/turn generation guard, so it can
  overwrite newer successful progress.
- An engine-level regression was reproduced: `pauseRestored(); shutdownAll();`
  followed by a new child leaves it blocked with `agents paused`.
  `shutdownAll()` does not clear `restoredPause`. The non-reload shutdown and
  session-start hooks use the same singleton, making same-generation reuse
  relevant; no live `/new` reproduction was performed. A full engine-generation
  replacement constructs a fresh instance. Port reset intent and add a
  lifecycle regression before migration rather than assuming this is fixed.

## What pi-session-name does

It is a small extension exposing **one model-callable `setSessionName` tool**.
Prompt guidance asks the active model to name the session once its purpose
is clear and rename it when the main topic changes. It suggests a concise
2–4-word, present-tense-verb name; this is guidance, not validation.

It does not spawn a naming agent, choose a separate model, run a background
summarizer, or make network requests itself. There is ordinary tool-schema
and prompt overhead plus normal model tool-call/follow-up cost when used.
Names appear in session metadata and terminal/window UI; tool arguments and
results also enter the provider conversation. Latest name wins: it can
replace a manual name, with no protection for human overrides.

Pi already supports manual `/name`, CLI `--name`/`-n`, and renaming in the
session selector. Adopt this only if automatic, model-controlled titles are
useful. Recommendation if adopted: **foreground only**; do not add it to the
explicit child allowlist, where stable child labels are more useful.

## Decided migration behavior

- Accept upstream's removal of the cumulative 200-turn budget. Keep only the
  configured eight-live-agent and depth-three caps; do not reintroduce budget
  state or behavior.
- Migrate old fold metadata once, offline, with the tested script below. Do not
  add permanent `context-prune` compatibility to the extension.
- Adopt commit-pinned `pi-session-name` for the foreground only. Do not grant it
  to actor children. The model may replace a manual foreground title.

## Applied live-linked changes

`patches/pi-live-linked-migration.patch` records the files changed while Pi
was stopped for cutover. It changes only:

- `dotfiles/codex/AGENTS.md`
- `dotfiles/pi/extensions/context-pressure/{index.ts,index.test.ts,policy.ts,policy.test.ts}`
- `dotfiles/pi/hosts/nixos-work/settings.json`

It updates active guidance and context-pressure to `context_fold`,
`context_unfold`, regex `patterns`, and the actor-subagents names; it also adds
this foreground package without granting it to children:

```text
git:github.com/fdietze/pi-session-name@89dafe1dc48968f20d414ac0c922b3fd6cb88347
```

The patch was applied during the completed offline cutover. Do not reapply it
on this migrated checkout. Its reviewed SHA-256 is
`92b28b94b0a47d5caf764172e186c59a162a68f540e25d38bc804615fe889baa`.

## Historical v1 metadata migration (obsolete; do not run for v2)

`scripts/migrate-pi-infinite-context-sessions.py` recursively scans one or
more session roots. It defaults to read-only dry-run and reports aggregates,
not transcript content:

```sh
python3 scripts/migrate-pi-infinite-context-sessions.py "$HOME/.pi/agent/sessions"
```

For an apply, use a fresh absolute backup path outside every scan root:

```sh
backup="$HOME/pi-session-backups/infinite-context-$(date +%Y%m%d-%H%M%S)"
python3 scripts/migrate-pi-infinite-context-sessions.py \
  --apply --backup-dir "$backup" "$HOME/.pi/agent/sessions"
```

A fresh absolute path is an operational recommendation, not parser policy: the
script also accepts a relative or existing backup directory when it resolves
outside the scan roots and none of the per-file backup targets collide. Scan
roots themselves cannot be symlinks; nested symlink files and directories are
skipped. Backup path components cannot be symlinks.

The script validates every candidate before writing, rejects malformed or
duplicate-key JSON, verifies source bytes and fingerprints immediately before
each replacement, creates backups, and uses atomic replacements with rollback
on failure. It changes only exact `type: "custom"`, `customType:
"context-prune"` entries: `spans` are preserved, historical `pruned` IDs are
appended as empty-summary singleton spans, and the marker becomes
`infinite-context`. Headers, IDs, parent IDs, timestamps, order, unrelated
entries, paths, and historical text/tool names are untouched. The script does
not lock session files. Its best-effort process check is extra defense, not a
substitute for coordinated shutdown.

## Historical coordinated cutover and stage-aware recovery

> **Reference only:** this procedure records the completed cutover and its
> recovery design. Do not rerun it on the migrated host.

For the completed cutover, `/session` recorded the current session's exact
absolute JSONL path before every Pi foreground and child process was stopped.
The prepared host closure was held by the GC root
`~/.local/state/pi-migration/nixos-work-system`. The operation ran from an
ordinary Bash terminal because the fail-stop and `ERR` handling below are
Bash-specific:

```sh
cd /home/felix/nixos
session='/home/felix/.pi/agent/sessions/--home-felix-nixos--/2026-09-12T17-44-50-442Z_01a096b8-d40a-77bd-b08a-5ddc2a6c22ba.jsonl'
root="$HOME/.pi/agent/sessions"
mkdir -p "$HOME/pi-session-backups"
state=$(mktemp -d "$HOME/pi-session-backups/pi-cutover-XXXXXXXX")
backup="$state/session-backup"

# All Pi sessions/children must already be stopped.
(
  set -Eeuo pipefail
  trap 'rc=$?; printf "CUTOVER FAILED at stage %s; state: %s\n" "$(cat "$state/stage")" "$state" >&2; exit "$rc"' ERR
  printf '%s\n' preflight > "$state/stage"
  test -f "$session"
  case "$session" in "$root"/*) ;; *) exit 1 ;; esac

  new_system=$(readlink -f "$HOME/.local/state/pi-migration/nixos-work-system")
  test "$new_system" = /nix/store/gjnb42r82xjbxagmlx46m9ld4hlxz7fh-nixos-system-nixos-work-26.11.20260908.d6524aa
  test "$(nix-store --query --hash "$new_system")" = sha256:1hm8cs11pxdvxcw8ashna7axhhvv2rxblh4nxy76hm9pbyjxmp6k
  nix-store --verify-path "$new_system"
  test -x "$new_system/bin/switch-to-configuration"

  pre_system=$(readlink -f /nix/var/nix/profiles/system)
  test "$pre_system" = "$(readlink -f /run/current-system)"
  printf '%s\n' "$pre_system" > "$state/pre-system"
  printf '%s\n' "$new_system" > "$state/new-system"
  printf '%s\n' "$backup" > "$state/backup-dir"

  printf '%s  %s\n' \
    4f701df89afb8304376624f0338333c4a95962706ce7bf555d06204ec692c1be patches/pi-infinite-context-enable-nudges.patch \
    c625a3bd0a38311314772e546e24bb47e6876f8e64ed653dba0540ad0f7ff275 patches/pi-actor-subagents-local.patch \
    92b28b94b0a47d5caf764172e186c59a162a68f540e25d38bc804615fe889baa patches/pi-live-linked-migration.patch \
    | sha256sum --check
  git apply --check patches/pi-live-linked-migration.patch
  python3 scripts/migrate-pi-infinite-context-sessions.py "$root"

  printf '%s\n' live-patch-started > "$state/stage"
  git apply patches/pi-live-linked-migration.patch
  printf '%s\n' live-patch-applied > "$state/stage"
  printf '%s\n' package-install-started > "$state/stage"
  pi install git:github.com/fdietze/pi-session-name@89dafe1dc48968f20d414ac0c922b3fd6cb88347
  printf '%s\n' package-installed > "$state/stage"
  printf '%s\n' session-migration-started > "$state/stage"
  python3 scripts/migrate-pi-infinite-context-sessions.py \
    --apply --backup-dir "$backup" "$root"
  printf '%s\n' sessions-migrated > "$state/stage"

  printf '%s\n' profile-change-started > "$state/stage"
  sudo nix-env --profile /nix/var/nix/profiles/system --set "$new_system"
  printf '%s\n' profile-set > "$state/stage"
  sudo "$new_system/bin/switch-to-configuration" switch
  printf '%s\n' activated > "$state/stage"

  exec pi --session "$session"
)
```

The subshell's `set -Eeuo pipefail` stops the sequence on the first error, and
Pi was reopened only after every preceding command succeeded. `pi install` was
intentionally deferred to this offline cutover: it reconciled the audited
commit into Pi's Git package area; the settings patch already pinned the same
spec. Do not run `pi update`. Restored actor children remain paused; inspect
them if useful, but do not automatically run `/subagents-resume`.

The following recovery block was prepared for a cutover failure and is retained
only to document the stage-aware rollback design. It must not be run after the
successful migration. It acts only on stages that could have completed the
corresponding change, rather than using an unconditional generation rollback:

```sh
(
  set -Eeuo pipefail
  stage_name=$(cat "$state/stage")

  case "$stage_name" in
    profile-change-started|profile-set|activated)
      pre_system=$(cat "$state/pre-system")
      test -x "$pre_system/bin/switch-to-configuration"
      sudo nix-env --profile /nix/var/nix/profiles/system --set "$pre_system"
      sudo "$pre_system/bin/switch-to-configuration" switch
      ;;
  esac

  case "$stage_name" in
    session-migration-started|sessions-migrated|profile-change-started|profile-set|activated)
      backup=$(cat "$state/backup-dir")
      if test -d "$backup/root-0"; then
        cp -a "$backup/root-0/." "$root/"
      fi
      ;;
  esac

  case "$stage_name" in
    live-patch-started|live-patch-applied|package-install-started|package-installed|session-migration-started|sessions-migrated|profile-change-started|profile-set|activated)
      if git apply -R --check patches/pi-live-linked-migration.patch; then
        git apply -R patches/pi-live-linked-migration.patch
      elif git apply --check patches/pi-live-linked-migration.patch; then
        : # Already unapplied.
      else
        printf '%s\n' 'live patch state is ambiguous; stop for manual review' >&2
        exit 1
      fi
      ;;
  esac
)
```

The unused pinned package checkout may remain because reversing settings
prevents it from loading. If the resumed Pi session already appended new
turns, preserve a separate copy before restoring the pre-migration backup;
restoring necessarily discards those later writes.

## Verification completed

- Patched infinite-context: `nix develop -c npm run ci` passed typechecking,
  lint, and **56 tests**, including default/enabled behavior, disabled nudges,
  invalid JSON/type fallback, and settings reload.
- Patched actor-subagents: isolated `nix develop -c npm run ci` passed
  typechecking, lint, and **225 tests**. Lint retained only the three upstream
  warnings (control-character regex, redundant spread, unused import).
- Both upstream patches pass `git apply --check` against clean checkouts at the
  documented pins, applied files byte-match the tested candidates, and
  `git diff --check` passes. Reviewed SHA-256 values are
  `4f701df89afb8304376624f0338333c4a95962706ce7bf555d06204ec692c1be`
  (infinite-context) and
  `c625a3bd0a38311314772e546e24bb47e6876f8e64ed653dba0540ad0f7ff275`
  (actor-subagents).
- Before cutover, the live-linked candidate passed **36 context-pressure
  tests** and **10 codex-fast tests**. Its JSON parsed, targeted old tool-name
  searches were clean, and its durable patch applied cleanly and byte-matched
  the candidate.
- Before cutover, unmodified pi-session-name passed its isolated upstream
  typecheck, lint, test, and package dry-run at the exact pin. Its audited pin
  was then installed during cutover for foreground sessions only.
- The offline migrator passed **9 fixture tests** plus Python byte-compilation.
  Fault injection covers backup failure without source changes, a second
  replacement failing after writing with all attempted sources restored, and
  a source mutation after backup that is not overwritten while an earlier
  replacement is rolled back. Byte-exact tests cover LF, CRLF, bare CR, mixed
  endings, and no final newline. Before cutover, a provisional read-only scan
  of the active corpus found 398 files, 109871 lines, 558 matching entries, no
  historical `pruned` IDs, and 170 files that would change. The live writer
  detector refused that provisional apply as expected.
- `just format` and `just format-check` passed. During preparation, the raw
  checkout's `just check` reached the affected option but could not see the then
  untracked actor patch. A filtered staging copy that contained exactly the
  migration-owned files passed `nice -n 19 just check` and direct flake check.
- The final host closure was rebuilt from `/tmp/nixos-pi-migration-filtered`,
  constructed from Git-tracked working-tree files plus only the six task-owned
  untracked docs/patch/script/test artifacts; unrelated `notes.md` was asserted
  absent. The result is GC-rooted at
  `~/.local/state/pi-migration/nixos-work-system` and resolves to
  `/nix/store/gjnb42r82xjbxagmlx46m9ld4hlxz7fh-nixos-system-nixos-work-26.11.20260908.d6524aa`,
  with NAR hash
  `sha256:1hm8cs11pxdvxcw8ashna7axhhvv2rxblh4nxy76hm9pbyjxmp6k`.
  `nix-store --verify-path` passed. The built JSON contains
  `enableNudges: false` and the exact actor caps and six-entry child allowlist.
  Evaluation of all four out-of-store sources confirms they still point into
  `/home/felix/nixos` (AGENTS, host settings, context-pressure, and codex-fast),
  not the staging directory.

The authorized cutover completed successfully. `/run/current-system`, the
system profile, and the retained GC root all resolve to
`/nix/store/gjnb42r82xjbxagmlx46m9ld4hlxz7fh-nixos-system-nixos-work-26.11.20260908.d6524aa`.
The Home Manager service completed successfully (`active`, exited 0) with its
integrated generation, and the expected restored session is running under Pi
0.84.4. The new configuration and links match the deployed migration, and no
legacy `context-prune` markers remain.

Live smoke checks succeeded for main-session naming and context peek/fold, plus
coordinator/child spawn and messaging on the Fast-off path. These were focused
compatibility checks, not stress tests. The cutover backups, state directory,
and GC root remain retained. No Pi CLI upgrade or extension reload was needed.
No `hosts/hm-cf` changes were made.
