# Pi per-session Codex Fast mode and adaptable statusline

Status: implemented, deployed, and validated on `nixos-work`

Last checked: 2026-08-10

Tracking issues:

- design record: `nixos-q32` (closed)
- implementation epic: `nixos-3x6`
- fork and development shell: `nixos-3x6.1`
- fork dependency alignment: `nixos-3x6.2`
- generic status rendering: `nixos-3x6.3`
- per-session Fast and subagent controls: `nixos-3x6.4`
- repository integration and validation: `nixos-3x6.5`

## Goal

Add repository-managed Pi support for OpenAI Codex Fast mode without making it
global or persistent, and make the foreground statusline capable of displaying
that mode and future extension statuses.

The intended user experience is:

- bare `/fast` toggles the current foreground session, `/fast toggle` is the
  explicit equivalent, and `/fast on|off|status` provides direct control and
  inspection;
- every foreground or child Pi session has its own Fast setting;
- a newly spawned child inherits its owner's Fast setting unless the spawn call
  explicitly overrides it;
- an agent can change its own setting or that of a directly owned child;
- the fdietze subagent roster and `list_agents` output show when Fast is active;
- the foreground statusline shows Fast through Pi's generic extension-status
  API rather than through a Fast-specific coupling;
- no Fast setting is written to disk or restored into a later process; and
- the statusline retains the useful default presentation of
  `@shvax/pi-statusline`, especially Codex weekly usage and reset information.

This document records the decisions and source-level findings needed to avoid
repeating the package and extension research in a later AI session.

## Agreed decisions

### Codex Fast mode

Implement a small local extension rather than install one of the existing Fast
packages.

The extension will:

1. Keep desired Fast state in memory, independently for each Pi session ID.
2. Register `before_provider_request` and add the Codex priority service tier
   only when Fast is desired and the active provider/model supports it.
3. Read the current state for every provider request, rather than cache a
   process-wide value at startup. A change therefore applies to the next
   provider request, including the next request made by an already running
   child. It cannot alter an HTTP request that is already streaming.
4. Register `/fast [toggle|on|off|status]` for the foreground session. Bare
   `/fast` and explicit `/fast toggle` both invert desired state.
5. Publish its foreground indicator with `ctx.ui.setStatus(...)` so any custom
   footer can render it through `footerData.getExtensionStatuses()`.
6. Avoid all settings, state-file, environment-variable, and roster
   persistence.

Use two related state concepts:

- **desired**: the per-session toggle, inherited by a child unless explicitly
  overridden;
- **effective**: desired is on and the current model is a compatible
  `openai-codex` GPT-5.4, GPT-5.5, or GPT-5.6 model.

The `󱐋 fast` marker should represent effective state. Diagnostic output such
as `/fast status` and `list_agents` should distinguish an enabled but
unsupported state from an effective one.

### Subagent behavior

Patch the existing fdietze subagent extension rather than introduce a second
subagent manager.

- Add optional `fast?: boolean` to `spawn_agent`. Omission inherits the
  spawning session's desired state; `true` or `false` overrides it.
- Add `set_fast({ enabled, agent? })` to the per-agent custom tool set.
  Omitting `agent` changes the caller. Supplying `agent` is allowed only for a
  directly owned child (`target.spawnedBy === caller`).
- Store the live Pi session ID on the in-memory agent record or handle. Do not
  add Fast state to the persisted roster.
- Set the child's inherited or explicit state after child extensions have been
  bound but before its first prompt is submitted.
- Append `󱐋 fast` to the model cell after `<model>@<thinking-level>` when Fast
  is effective. It follows the model column's existing responsive drop
  behavior rather than appearing beside lifecycle state.
- Show agent names without a fixed cap or middle ellipsis whenever the physical
  terminal can fit the row; final terminal-safe clipping remains unavoidable
  if protected content alone exceeds terminal width.
- Include desired/effective Fast state in `list_agents` and useful spawn/tool
  results so headless owners have the same observability as the foreground
  TUI.

### Statusline

Do not write a minimal statusline from scratch at first. Create a GitHub fork
of `pi-statusline` 0.9.1, consume it as a commit-pinned Pi Git package, preserve
its default behavior, and make the smallest coherent change needed to render
generic extension statuses. Do not add the fork as a Git submodule.

Reasons:

- its symbols, Git/model/effort/context presentation, responsive layout, and
  default behavior are already desirable;
- Codex quota display is not trivial UI glue: it includes authenticated usage
  retrieval, window parsing, shared caching, bars, percentages, and live reset
  countdowns;
- replacing all of that immediately would create more code and regression risk
  than a local fork;
- a local fork still makes future adaptation and selective simplification easy.

The fork provides a normal, generic extension-status segment based on
`footerData.getExtensionStatuses()`. It preserves each map key so selected
statuses can be placed without coupling the renderer to their publishers. The
configurable `layout.rightAlignedExtensionStatuses` list defaults to only
`mcp`; those values use spare right-edge space and drop before any left-side
content. Other statuses, including future Fast state, remain inline. The
statusline must not import or query the Fast controller directly. Preserve
status ordering, ANSI-aware width calculation, and graceful narrow-terminal
behavior.

Retain the one-second refresh needed for live quota-reset countdowns. Active
turn/session timers and other nonessential features may be removed later, but
only after the fork reproduces the currently useful behavior and has tests.
Keep the upstream MIT license and attribution.

## Current repository state

As of the date above:

- Pi is 0.84.1 and the selected model is
  `openai-codex/gpt-5.6-sol` at `high` thinking level.
- `dotfiles/pi/hosts/nixos-work/settings.json` contains the commit-pinned
  `futile/pi-statusline` Git package at
  `90bc5a39bf1ea4597126a3d0eb3d478510f4b0bf`. This revision includes generic
  keyed extension statuses, MCP-only right alignment with a compact `🔌 MCP N/N`
  presentation under the default emoji icon style, aggregate agent activity/progress,
  the project-local working-tree override described below, inline warning-colored
  `󱐋 fast`, and one-space context rendering (`🪟 60.2%/272K`).
- `home-modules/pi.nix` copies fdietze's subagent source from the pinned
  `fdietze-dotfiles` flake input and applies five repository patches:
  - `patches/fdietze-pi-subagents-bind-errors.patch`
  - `patches/fdietze-pi-subagents-model-routing.patch`
  - `patches/fdietze-pi-subagents-engine-reset.patch`
  - `patches/fdietze-pi-subagents-activity.patch`
  - `patches/fdietze-pi-subagents-fast.patch`
- The Fast extension is implemented in `dotfiles/pi/extensions/codex-fast/`.
  Home Manager links it to `~/.pi/agent/extensions/codex-fast` for the
  foreground and explicitly grants that same path to child sessions.
- The fdietze source is pinned at
  `262fb764dedc2678b1522a21cbbd8818622be56c`.
- Home Manager links the patched extension to
  `~/.pi/agent/extensions/subagents`.
- Child extension discovery is fail-closed. The generated
  `~/.config/pi/subagents/child-extensions.json` allowlists only:
  - `pi-mcp-adapter@2.17.0`
  - `@juicesharp/rpiv-web-tools@2.3.1`
  - the repository-managed context-prune extension
  - the repository-managed Codex Fast extension
- `~/.pi/agent/settings.json` is an out-of-store symlink to the host settings
  file in this repository. Do not use `pi install` as the final configuration
  mechanism; edit the declarative settings source instead.

The Fast extension is installed for the foreground and added explicitly to the
child allowlist. The statusline remains foreground-only and is not present in
that allowlist.

## Verified source findings

### Pi and Fast requests

Pi 0.84.1 has no built-in `/fast`. A public `before_provider_request` hook can
modify each outgoing request, and its handler receives an extension context
with the active model and `SessionManager`. `SessionManager.getSessionId()`
provides the session UUID required for independent state.

For supported Codex requests, Fast is selected through the priority service
tier. The older wire spelling `service_tier: "priority"` is equivalent to the
newer Fast terminology. The hook must leave all unsupported providers and
models unchanged.

OpenAI documents Fast as the same model and intelligence with faster serving,
not a different reasoning model. At the time of research it supports GPT-5.4,
GPT-5.5, and GPT-5.6. Credit cost is higher than standard serving.

### Existing Fast packages considered

Existing packages were useful references but do not meet the complete design:

- `pi-codex-fast-mode@0.2.0` is narrow, dependency-free, compatible with Pi
  0.84.1, and has good tests. Its state is global/persistent and cached per
  extension instance, so it does not provide live, independently controllable
  children.
- `pi-openai-fast@1.0.1` uses a process environment variable that newly spawned
  in-process children could inherit, but it does not distinguish child state,
  lacks GPT-5.6 in its default model list, and competes for footer ownership.
- `@diegopetrucci/pi-openai-fast@0.1.15` is narrow and OAuth-aware, but its
  session-local state does not supply parent-to-child control.
- `pi-better-openai` is much broader than required and is unsuitable for the
  child allowlist.
- Other candidates were rejected for footer replacement, shared
  `settings.json` writes, forced verbosity changes, or invasive provider
  wrapping.

The local implementation should borrow narrow validation and request-hook test
patterns where useful, not their persistence or footer behavior.

### fdietze subagent architecture

The inspected source at the repository's pinned revision already has the
necessary control points:

- a process-global `Engine` owns `AgentRecord` entries with model, effective
  thinking level, owner (`spawnedBy`), depth, lifecycle state, and status;
- `makeAgentTools(selfName)` creates custom tools for both the main session and
  every child, so ownership checks can be made centrally;
- each child gets a unique `SessionManager`;
- child creation constructs a fail-closed `DefaultResourceLoader`, creates the
  session, and awaits `session.bindExtensions({ mode: "print" })` before the
  first message;
- extension hooks in each session receive that session's manager;
- children can spawn children, and the engine records the direct owner;
- `formatRoster` and `list_agents` already centralize the two required summary
  representations.

Consequently, inherited/explicit Fast can be set after `bindExtensions`
without racing the first provider request. Direct-owner control is also
possible without adding a new persistence layer.

### `pi-statusline` 0.9.1

The package is published as `@shvax/pi-statusline`, while its repository is
`martin-tahli/pi-statusline`. The npm 0.9.1 metadata identifies source commit:

```text
17813cafc9ed447f3e1ef0d07a0b245e55681548
```

The published package is MIT licensed. The Git tree at that exact commit has a
Pi package manifest, a single extension entry point, source modules, and a
substantial test suite. It declares Pi core peer dependencies and the runtime
dependency `proper-lockfile`. The commit subject mentions release `v0.8.1`, but
`package.json` at the commit reports `0.9.1`; use the exact npm `gitHead` above
rather than inferring the baseline from that subject or an unverified tag.

The inspected 0.9.1 source:

- installs a custom footer;
- receives `footerData` but only calls `getGitBranch()`;
- never calls `footerData.getExtensionStatuses()`;
- has a closed configurable segment set consisting of project, model, effort,
  context, session, throughput, and time;
- therefore cannot show extension statuses through existing configuration.

Its Codex adapter requests authenticated usage data from the
`/backend-api/wham/usage` endpoint at the active model base URL's origin. It
parses primary and secondary windows, labels durations, renders usage bars and
percentages, and updates reset countdowns. Provider data is refreshed on a
roughly ten-second cadence, shared across processes through a lock-protected
cache, and allowed a bounded stale-cache fallback. A one-second UI timer drives
countdowns and timing displays.

DeepWiki did not index `martin-tahli/pi-statusline` when checked. For future
source work, inspect the pinned Git commit or npm tarball directly rather than
retrying broad repository research first.

A reproducible npm-source inspection command is:

```bash
tmp=$(mktemp -d)
npm pack @shvax/pi-statusline@0.9.1 --pack-destination "$tmp"
tar -xzf "$tmp"/shvax-pi-statusline-0.9.1.tgz -C "$tmp"
```

## Target Fast architecture

### In-memory control plane

Each loaded Fast extension instance should own its local desired boolean. A
small process-global registry, keyed by session UUID, should expose controllers
to the patched subagent extension:

```ts
interface FastController {
  getState(): { desired: boolean; effective: boolean; model?: { provider: string; id: string } };
  setDesired(enabled: boolean): FastState;
}

type FastRegistry = Map<string, { owner: symbol; controller: FastController }>;
```

Use a versioned `Symbol.for(...)` key or equivalent stable process-global key.
The registry is a control plane, not one global Fast value. Register during
`session_start`, remove the entry during `session_shutdown`, and guard cleanup
so an old instance cannot remove a newer controller for the same session.

The `before_provider_request` closure should read its own controller on every
request. The fdietze patch should use the registry only to initialize or change
a particular live session.

### Spawn sequence

The intended child sequence is:

1. Resolve `desiredFast = spec.fast ?? ownerDesiredFast`.
2. Create the child `SessionManager` and agent session.
3. Bind the allowlisted child extensions in print/headless mode.
4. Obtain the child's registered Fast controller by session UUID.
5. Apply `desiredFast`.
6. Attach the live session and UUID to the engine record.
7. Submit the first prompt.

If the Fast controller is missing, fail visibly rather than silently claiming
that Fast was enabled. Child extension load/bind failures already have explicit
logging and should remain diagnosable.

### UI and output

- Foreground status: publish plain `fast` through
  `ctx.ui.setStatus("fast", "fast")`; clear it when ineffective. Styling belongs
  to the statusline, not the publisher.
- Child roster: append `󱐋 fast` after `<model>@<thinking-level>` only when
  effective; leave lifecycle state independent.
- Agent names have no fixed shortening cap or middle ellipsis.
- `list_agents`: show the marker after the model when effective and always
  report desired/effective state when a live controller is available,
  especially when desired is on but the model is unsupported.
- Spawn and setter tools: return the resulting state and any incompatibility
  explanation.
- Headless children must never call interactive UI methods.

## Target statusline architecture

The fork should continue to own the one foreground footer. Its first functional
change should:

1. Read `footerData.getExtensionStatuses()` on every render.
2. Preserve generic keyed statuses in a stable segment. Keep their publisher
   styling by default; the approved keyed `fast` presentation is the narrow UI
   exception and adds `󱐋` plus the theme warning color at render time.
3. Keep Fast inline after effort, keep only configured keys such as `mcp`
   right-aligned, and allow normal responsive dropping when space is genuinely
   unavailable.
4. Preserve ANSI styling and use terminal display width rather than JavaScript
   string length.
5. Ensure `setStatus` changes trigger the expected re-render.
6. Add tests for no statuses, one status, several statuses, styled values, and
   narrow widths.

Start from behavior parity with upstream 0.9.1. Defer code deletion until the
quota display, Git/model/context fields, streaming behavior, and reset
countdown have been manually compared with the currently installed package.

## Repository and fork strategy

### Decision: fork plus pinned Pi Git package

Pi supports Git packages, installs their npm dependencies, and pins tags or
commits. The selected long-term arrangement is:

1. Fork `martin-tahli/pi-statusline` on GitHub.
2. Develop it in a separate clone such as `~/gits/pi-statusline`.
3. Push reviewed fork commits.
4. Replace the unpinned npm setting with a commit-pinned source such as:

   ```json
   "git:github.com/futile/pi-statusline@<full-commit-sha>"
   ```

5. Let Pi clone the package under its package directory and run `npm install`,
   which supplies `proper-lockfile`.

This matches Pi's package model, keeps the full fork out of this repository,
avoids nested Git state, and leaves this repository with only a reviewable
commit pin. Do not edit Pi's managed package checkout: reconciliation resets
and cleans Git package clones.

For normal local iteration, install dependencies and launch Pi from the fork:

```bash
cd ~/gits/pi-statusline
npm ci
pi
```

The fork's committed `.pi/settings.json` uses Pi's project-package delta
semantics to disable the globally installed `futile/pi-statusline` extension
and load `..` from the working tree. The project must be trusted. Pi launched
outside this checkout continues to use the declarative commit pin, and other
global extensions remain available.

For a statusline-only smoke test, disable normal extension discovery explicitly:

```bash
pi --no-extensions -e ~/gits/pi-statusline
```

Loading the local package with `-e` while normal discovery remains enabled is
not an override: it would load both copies and make two extensions compete for
footer ownership.

### Fork development environment

Commit a small Nix development environment at the root of the fork rather than
use the repository's `parasite-nix` template unchanged. That template is a
useful structural starting point, but its nested, git-ignored flake is intended
for adding private Nix tooling to a repository that should not own it. This
fork should make its development toolchain visible and reproducible for future
human and AI sessions.

Commit these files in the fork:

```text
flake.nix
flake.lock
.envrc
```

Add `.direnv/` and `result` to the fork's `.gitignore`. Use `nodejs_24` to match
the Node 24 runtime of the installed Pi and retain the high-priority
`bashInteractive` workaround from the template. Deliberately do **not** add
`pkgs.git`: development assumes Git is installed on the host. Do not install a
global TypeScript through Nix; `npm ci` must supply the versions pinned by the
fork's `package-lock.json`.

The initial flake shape is:

```nix
{
  description = "Development environment for pi-statusline";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = [
            pkgs.nodejs_24
            (pkgs.lib.hiPrio pkgs.bashInteractive)
          ];
        };
      }
    );
}
```

Use a committed `.envrc` containing `use flake`. Commit `flake.lock` so both
nixpkgs and the resulting Node/npm toolchain are pinned. This pins development
tools, not the npm dependency graph; `package-lock.json` remains the source of
truth for JavaScript and TypeScript dependencies.

After recording the unchanged upstream baseline, update the fork's three
`@earendil-works` Pi development dependencies to 0.84.1 in a separate commit.
Align `@types/node` with Node 24 or explicitly document why its existing version
is retained. Keep environment, dependency-alignment, and functional rendering
changes in separate commits so failures remain attributable.

### Rejected: Git submodule

A submodule under a path such as `vendor/pi-statusline` would give one visible
working tree and record an exact fork commit as a gitlink, but it was rejected
for this integration.

Its costs would include:

- every checkout and CI/deployment environment must initialize the submodule;
- contributors must push the fork commit before pushing the superproject
  gitlink update;
- submodule checkouts commonly start detached, which is easy to mishandle;
- local package dependencies still need installation or Nix packaging;
- if Nix reads submodule files as part of the flake source,
  `inputs.self.submodules = true` is required (Nix defaults it to false);
- a missing or stale submodule creates failures outside the ordinary
  `flake.lock` update workflow.

A non-flake flake input is another possible pin and matches the existing
fdietze source integration, but Pi's direct Git-package support is preferable
here because it also performs the package's npm dependency installation. The
commit-pinned Pi Git package is the single source of truth.

## Proposed repository layout

The exact implementation may adjust names, but the expected main-repository
changes are:

```text
dotfiles/pi/extensions/codex-fast/
  index.ts
  fast-control.ts           # pure registry/model helpers used by tests
  *.test.ts
patches/
  fdietze-pi-subagents-fast.patch
home-modules/pi.nix         # foreground link and child allowlist
dotfiles/pi/hosts/nixos-work/settings.json
                           # replace statusline package source/pin
```

The fork remains in its own repository. No fork source directory or submodule
belongs in this repository. The fork itself additionally contains:

```text
flake.nix                    # Node 24 development shell; no Git package
flake.lock                   # committed development-tool pin
.envrc                       # use flake
```

## Implementation order

1. Fork and baseline `pi-statusline` at npm 0.9.1's Git commit. Run its existing
   tests and typecheck unchanged.
2. Add and commit the root Nix/direnv development environment, then reproduce
   the baseline through `nix develop`.
3. In a separate compatibility commit, align the fork's Pi development
   dependencies with Pi 0.84.1 and intentionally resolve the Node type version.
4. Add generic extension-status rendering and focused tests in the fork.
5. Test the fork locally with the project override and with an isolated dummy
   status publisher.
6. Push the fork commit, replace the npm package entry with its full Git commit
   pin, and reconcile Pi packages.
7. Implement the local Fast extension with pure compatibility/state/request
   tests.
8. Add the Fast extension to foreground Home Manager wiring and the fail-closed
   child extension policy.
9. Patch fdietze subagents for session IDs, spawn inheritance/override,
   owner-controlled changes, and roster/list output.
10. Run integration tests with main, child, and nested-child sessions.
11. Only after parity is confirmed, consider trimming unwanted statusline
    features in separate commits.

## Validation checklist

### Fast extension

- bare `/fast` and explicit `/fast toggle` invert desired state, while
  `/fast on`, `off`, and `status` retain direct control and inspection;
- Unsupported providers/models receive no service-tier mutation.
- Enabled state follows compatible model changes correctly.
- A child inherits both on and off states when `fast` is omitted.
- Explicit `fast: true` and `fast: false` override inheritance.
- A child can inherit from another child.
- `set_fast` changes self and a directly owned child.
- `set_fast` rejects control of a sibling or unrelated agent.
- A live child's next provider request observes a changed setting.
- A currently streaming request is not incorrectly claimed to have changed.
- Child headless mode performs no UI calls.
- shutdown unregisters controllers without deleting a replacement controller.
- a new/restored process starts with Fast off.

### Subagent presentation

- roster lines show `<model>@<thinking-level> 󱐋 fast` for effective sessions;
- long agent names have no fixed ellipsis cap, and narrow layouts remain
  terminal-safe through whole-column dropping plus final clipping;
- production roster layout injects Pi TUI's exact `visibleWidth` and
  `sliceByColumn`, including exact-boundary Nerd glyph and non-Latin alignment
  regressions;
- `list_agents` distinguishes desired and effective state;
- spawn/set results report the resolved state;
- existing model/thinking inheritance, pause/resume, and shutdown tests still
  pass.

### Statusline fork

- the unchanged 0.9.1 baseline tests and typecheck pass before modification;
- `nix develop` supplies Node 24 and the interactive shell, but intentionally
  relies on host Git;
- `flake.lock` and `package-lock.json` separately pin development tools and npm
  dependencies;
- the Pi development dependencies match 0.84.1 before functional changes;
- no, one, and several extension statuses render correctly;
- ANSI-colored statuses do not break width calculations;
- narrow-width degradation remains readable;
- Codex primary/secondary quota bars and reset countdown match the current
  statusline;
- Git, model, effort, context, throughput, and other retained defaults do not
  regress;
- only one extension owns the footer during integration testing.

### Repository

Run the focused extension/fork tests first, then repository validation:

```bash
just format
just format-check
nice -n 19 just check
```

For Home Manager wiring changes, also run the relevant `just hm-build` or host
build path before switching.

### Completed deployment validation

Validation on `nixos-work` completed on 2026-08-10:

- `just format-check`, `nice -n 19 just check`, and the full
  `nice -n 19 just build` passed. The built and activated system was
  `/nix/store/zc1041jjr9n9vcwh535k885fkdmmz7sa-nixos-system-nixos-work-26.11.20260807.f13ff45`.
- The built subagent extension passed all 142 tests. The local Fast extension
  passed all 9 tests; the pinned statusline had previously passed all 256 tests,
  typecheck, and its flake check.
- The activated foreground Fast link resolves to the repository working tree,
  and the generated child policy contains exactly the pinned MCP adapter, web
  tools, context-prune, and Fast extension. It does not contain the statusline.
- The managed statusline checkout resolves to exact commit
  `90bc5a39bf1ea4597126a3d0eb3d478510f4b0bf` and has no npm audit findings.
- Fresh managed Pi processes verified bare `/fast`, explicit `/fast toggle`,
  and `/fast on|off|status`. With Fast on, the
  warning-colored inline status rendered as
  `🧠 high > 󱐋 fast > 🪟 0.0%/272K`, with one space after the context icon,
  while `🔌 MCP 0/3` remained at the right edge.
- A fresh Pi RPC process exercised the deployed extensions with an eligible
  Codex model. Main self-control was effective; an omitted child override
  inherited on; explicit `fast: false` stayed off; a nested grandchild inherited
  its direct owner's on state; the direct owner changed the grandchild off;
  main changed its direct child off; and both child-to-main and main-to-grandchild
  non-owner controls were rejected. Roster and `list_agents` output tracked the
  effective marker transitions, and all fixture agents were terminated.

## Known boundaries and deferred choices

- Fast changes take effect on the next request, not an active stream.
- Fast is intentionally not persisted to disk. Whether a particular extension
  reload preserves an otherwise live controller is an implementation detail;
  process restart/session restoration must not restore it.
- The first statusline fork should preserve upstream features. Exact later
  removals are intentionally deferred.
- The keyed Fast presentation is fixed inline after effort as warning-colored
  `󱐋 fast`; MCP remains the independently configured right-aligned status.
- Publishing a forked npm package is unnecessary unless Git-package loading
  becomes inconvenient.
- The fork is consumed as a pinned Pi Git package, not a submodule or flake
  input.
- The fork's Nix development shell assumes Git is available on the host.
- Per-agent control beyond the direct owner is not part of the agreed design.

## Sources

- OpenAI Codex Fast mode: <https://developers.openai.com/codex/speed>
- OpenAI API Fast mode: <https://developers.openai.com/api/docs/guides/fast-mode>
- Pi package documentation (matching installed Pi 0.84.1):
  `/nix/store/17ylsaaiywkyh4qfzicrwwyarjrc73z1-pi-0.84.1/libexec/pi/docs/packages.md`
- Pi extension documentation (matching installed Pi 0.84.1):
  `/nix/store/17ylsaaiywkyh4qfzicrwwyarjrc73z1-pi-0.84.1/libexec/pi/docs/extensions.md`
- `pi-statusline`: <https://github.com/martin-tahli/pi-statusline>
- `@shvax/pi-statusline@0.9.1` tarball:
  <https://registry.npmjs.org/@shvax/pi-statusline/-/pi-statusline-0.9.1.tgz>
- fdietze subagents at the repository's pinned revision:
  <https://github.com/fdietze/dotfiles/tree/262fb764dedc2678b1522a21cbbd8818622be56c/modules/home-manager/profiles/ai-agents/pi-extensions/subagents>
