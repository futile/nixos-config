# Codex Token Optimization Stack on NixOS

This document summarizes Abid Abdul Gafoor's Medium article,
`How I Cut Claude Code Token Usage by 90_+ With 5 Tools, Custom Hooks, and Enforcement`,
and the companion repository at
<https://github.com/sgaabdu4/claude-code-tips>. It then translates the setup to
this NixOS + Codex CLI machine.

The original setup is Claude Code-first. Do not run its installer directly for
Codex. It writes `~/.claude` settings, installs Claude plugins, adds shell
wrappers, installs some tools outside Nix, and enables Headroom by default.

## Article Overview

The article's core idea is that context savings compound when each layer catches
a different source of waste:

| Layer | Tool | Original purpose | Codex transfer |
|---|---|---|---|
| 1 | Codebase Memory MCP | Avoid file reads for code exploration by querying a local graph. | Useful. Configure as a Codex MCP server. |
| 2 | context-mode | Keep large command/file/web output in a local searchable store and return summaries. | Implemented for `nixos-work` as a Bun-backed Nix package, Codex MCP server, and hook provider. |
| 3 | RTK | Compress shell output before it enters context. | Implemented for `nixos-work` through `pkgs.rtk` and `AGENTS.md` guidance. |
| 4 | Headroom | Anthropic API proxy that compresses request payloads. | Defer. It adds an API service/proxy and is not the first thing to adopt. |
| 5 | Caveman | Make agent replies shorter and compress memory files. | Partly implemented: only the `caveman-compress` skill is installed, for explicit file compression. Global Caveman speech style is not enabled. |

The companion repo contains:

- `install.sh`: an opinionated Claude Code installer.
- `settings/settings.json`: Claude Code settings with hooks for context-mode,
  RTK, CBM, Caveman, status line, and model/env defaults.
- `hooks/`: Bash hooks such as `bash-ban-raw-tools`,
  `cbm-code-discovery-gate`, and `cbm-mcp-marker`.
- `CLAUDE.md.example`: behavior rules telling Claude to prefer CBM and
  context-mode.
- `commands/`, `rules/`, `bin/`, and `statusline/`: Claude slash commands,
  per-stack rule templates, sync scripts, and a status line.

The useful lesson is not "copy the Claude config". It is "make the efficient
path the default, and use hooks or instructions to block expensive habits."

## Current Setup Summary

Current `nixos-work` setup:

- RTK is installed from nixpkgs and preferred for noisy shell commands when
  exact raw output is not needed.
- context-mode is packaged locally with Bun, installed through Home Manager,
  registered as a Codex MCP server, and wired through reviewed Codex hooks.
- `~/.agents/skills` is managed skill-by-skill in `home-modules/agents.nix`.
  Local skills stay live-editable; upstream skills can be pinned and patched
  through flake inputs.
- Caveman is pinned as a non-flake input, but only
  `skills/caveman-compress` is exposed. A local patch changes that skill to
  let the running agent compress files when the upstream `claude` CLI path is
  unavailable.
- Global Caveman speech style is not enabled. Use Caveman only when explicitly
  compressing selected memory/instruction files.
- Codebase Memory MCP and Headroom are not installed yet. CBM is the next
  local-only candidate; Headroom remains deferred because it changes the API
  request path.

## Current Codex Baseline

This machine already has a Home Manager module for Codex at
`home-modules/codex.nix`. It symlinks:

- `~/.codex/AGENTS.md` from `dotfiles/codex/AGENTS.md`
- `~/.codex/agents` from `dotfiles/codex/agents`

It intentionally does not symlink `~/.codex/config.toml`, because Codex writes
machine-specific trusted project paths into that file.

Current local Codex config already has:

```toml
model = "gpt-5.5"
model_reasoning_effort = "medium"
model_verbosity = "medium"
personality = "pragmatic"

[features]
multi_agent = true
```

The official Codex config schema currently includes lifecycle hooks under
`hooks`, plus hook feature flags under `[features]`, including `hooks`,
`plugin_hooks`, and the legacy-ish `codex_hooks` flag. The local `codex --help`
also exposes `codex plugin` and `codex mcp`, so the Codex side can consume some
of these tools directly.

After changing `~/.codex/config.toml`, restart Codex before relying on the new
configuration. Existing sessions and subagents may keep stale config.

## Recommended Adoption Order

1. Add RTK through Nix. Done for `nixos-work`.
2. Add context-mode as a Nix package and Codex MCP server/hook provider. Done
   for `nixos-work`.
3. Add Caveman's `caveman-compress` skill declaratively for explicit memory-file
   compression. Done via a pinned non-flake input and local patch.
4. Add Codebase Memory MCP via its upstream flake and Codex MCP config.
5. Revisit Headroom later, only after the local-only layers are working.

This order avoids API proxy complexity and starts with tools that are either
already in nixpkgs or have explicit Codex support.

## RTK

RTK was the easiest first step. In this flake's nixpkgs, `pkgs.rtk` exists and
reports:

```text
CLI proxy that reduces LLM token consumption by 60-90% on common dev commands
```

The currently evaluated nixpkgs package version is `0.38.0`. It is installed
through `home-modules/codex-token-optimization.nix` for `nixos-work`. Upstream
`rtk-ai/rtk` has newer tags, so keep using the packaged version and only add a
custom package if a newer RTK feature matters.

Current module shape:

```nix
home.packages = with pkgs; [
  my-custom-packages.context-mode
  rtk
];
```

Basic checks:

```sh
rtk --version
rtk gain
rtk discover
```

Usage pattern:

```sh
rtk git status
rtk cargo test
rtk nix flake check
```

`dotfiles/codex/AGENTS.md` now tells agents to prefer `rtk <command>` for noisy
shell commands when exact raw output is not needed. Do not add an RTK command
rewriting hook yet. A hook that rewrites shell commands is less mature in Codex
than it is in Claude Code; context-mode's own README notes that Codex
`PreToolUse` currently supports blocking/deny behavior, not input rewrites.

## context-mode

context-mode is highly relevant because it now has explicit Codex support. Its
repo says the Codex plugin path provides MCP via `.codex-plugin/mcp.json`,
skills via `skills/`, and bundled hooks via `.codex-plugin/hooks.json`.

It needs a modern JavaScript runtime, but this machine should not add Node
user-wide or system-wide just to run context-mode. The implemented package wraps
context-mode with `pkgs.bun`, not `nodejs_22`. That gives Codex a
`context-mode` executable without exposing Node as a general user package, and
`context-mode doctor` reports `Performance: FAST` with JavaScript and
TypeScript handled by Bun.

Upstream does not currently ship a `flake.nix`, so this is a repo-local package
candidate. It is packaged under `custom-packages/context-mode.nix` by fetching
the npm tarball, copying it to `$out/lib/context-mode`, and wrapping
`cli.bundle.mjs` with Bun. The wrapper also prefixes Bun onto `PATH`, because
context-mode's runtime discovery checks child process availability too.

The package is exposed through this flake and installed only through
`home-modules/codex-token-optimization.nix`:

```nix
home.packages = with pkgs; [
  my-custom-packages.context-mode
];
```

The local machine config uses the manual Codex MCP/hook path:

```toml
[features]
hooks = true

[mcp_servers.context-mode]
command = "context-mode"
env = { CONTEXT_MODE_PLATFORM = "codex" }
```

The Codex sandbox also needs write access to context-mode storage:

```toml
[sandbox_workspace_write]
writable_roots = [
  "/home/felix/.cache/sccache",
  "/home/felix/.codex/context-mode",
]
```

For manual hooks, `dotfiles/codex/hooks.json` is linked to
`~/.codex/hooks.json` and contains the documented
`PreToolUse`, `PostToolUse`, `SessionStart`, `PreCompact`,
`UserPromptSubmit`, and `Stop` commands. Each command forces Codex detection:

```sh
env CONTEXT_MODE_PLATFORM=codex context-mode hook codex <event>
```

After changing `.codex/config.toml`, restart Codex. On first use, Codex asks for
trust approval for the six hook commands; review and trust those commands if
they still match `dotfiles/codex/hooks.json`.

The Codex plugin path is still useful as a reference and may become preferable
once plugin packaging can use a Nix-provided runtime cleanly:

```sh
codex plugin marketplace add mksglu/context-mode
codex plugin add context-mode@context-mode
```

If testing that plugin path later, enable plugin hooks in
`~/.codex/config.toml`:

```toml
[features]
hooks = true
plugin_hooks = true
```

The implemented manual path has been verified with:

```text
context-mode doctor
```

The post-switch doctor check passed storage access, all six hooks, MCP
registration, server initialization, and FTS5/SQLite.

Nix caveat: the plugin path downloads plugin content into Codex's plugin cache
and may still assume a runtime visible to the Codex process. That conflicts with
the "no user-wide Node" preference unless the plugin can be pointed at a
Nix-wrapped runtime. Prefer the packaged manual MCP/hook path.

## Codebase Memory MCP

Codebase Memory MCP is a local static binary that builds a SQLite-backed
knowledge graph. Upstream says it supports Codex CLI directly; for Codex it
writes `.codex/config.toml` and `.codex/AGENTS.md`, but no hooks.

Do not run the upstream installer as the first choice. It is convenient, but it
mutates agent config directly. Prefer one of these Nix options:

1. Use the upstream flake as a package input.
2. Add a repo-local `custom-packages/codebase-memory-mcp.nix`.
3. If you only want to evaluate it once, use `nix shell` against the upstream
   flake without making permanent config changes.

The upstream flake builds a `codebase-memory-mcp` binary from source. Its
`flake.nix` currently sets version `0.6.0`. Because it has a flake, prefer using
that before writing a custom package. Before adding it, check whether upstream
publishes a binary cache:

```sh
git clone --depth 1 https://github.com/DeusData/codebase-memory-mcp /tmp/codebase-memory-mcp
rg -n "cachix|nixConfig|substituters|trusted-public-keys" /tmp/codebase-memory-mcp
```

In the checkout inspected for this document, no Cachix or `nixConfig`
substituter hints were present. If a cache is later documented, add its
`nix.settings.substituters` and `nix.settings.trusted-public-keys` first, run
`just switch`, then build. A newly added cache is not used by builds that run
before activation.

Codex MCP config shape:

```toml
[mcp_servers.codebase-memory-mcp]
command = "codebase-memory-mcp"
args = []
```

Useful one-time config:

```sh
codebase-memory-mcp config set auto_index true
codebase-memory-mcp config set auto_index_limit 50000
```

Basic CLI fallback examples:

```sh
codebase-memory-mcp cli list_projects
codebase-memory-mcp cli index_repository '{"repo_path": "/home/felix/nixos"}'
codebase-memory-mcp cli search_graph '{"name_pattern": ".*Handler.*", "label": "Function"}'
```

Codex instruction transfer belongs in `dotfiles/codex/AGENTS.md`, not in a
Claude `CLAUDE.md`. Suggested rule:

```md
For code discovery, prefer codebase-memory-mcp before broad file reads:
`get_architecture`, `search_graph`, `search_code`, `trace_call_path`, and
`get_code_snippet`. Fall back to `rg`/file reads for literals, docs, configs,
or when the graph is missing/stale.
```

Do not ban `rg` outright in this repo. The repository guidance explicitly says
to prefer `rg` for text/file search. A better rule is "CBM for structural code
questions; `rg` for text and repository navigation."

## Caveman

Caveman is no longer only a Claude plugin. Its repo says Codex CLI support is:

```sh
npx skills add JuliusBrussee/caveman -a codex
```

That is not a Nix-native install. Do not use it as persistent setup on this
machine.

Current setup installs only Caveman's `caveman-compress` skill. It does not
enable Caveman's global speech-style hook. This matches the intended scope:
compress selected memory/instruction files when explicitly asked, while keeping
normal Codex replies under the existing `personality = "pragmatic"` and
`model_verbosity = "medium"` config.

The flake has a pinned non-flake input:

```nix
caveman = {
  url = "github:JuliusBrussee/caveman";
  flake = false;
};
```

`home-modules/agents.nix` exposes agent skills individually under
`~/.agents/skills` rather than symlinking all of `~/.agents`. Local skills stay
live-editable through `mkOutOfStoreSymlink`, while `caveman-compress` comes from
a patched derivation:

```nix
cavemanCompressSkill = pkgs.applyPatches {
  name = "caveman-compress-skill";
  src = "${flake-inputs.caveman}/skills/caveman-compress";
  patches = [ ../dotfiles/agents/patches/caveman-compress-current-agent.patch ];
};

home.file.".agents/skills/caveman-compress".source = cavemanCompressSkill;
```

The patch changes upstream `SKILL.md` so the preferred workflow is "running
agent does the compression". Upstream's helper scripts are still available for
detection and validation, but the full CLI pipeline is no longer the default
because it shells out to `claude` when no Anthropic API client is configured.

When using `$caveman:caveman-compress <file>`:

1. Resolve the file and confirm it is natural-language input, not
   `*.original.md`.
2. Create `<filename>.original.md` before overwriting.
3. Compress only prose, preserving headings, code blocks, inline code, URLs,
   paths, commands, proper nouns, dates, versions, and environment variables.
4. Run the upstream validator:

```sh
python3 -m scripts.validate <backup_path> <compressed_path>
```

5. Fix only listed validation errors; do not recompress the whole file.

If updating Caveman, run:

```sh
nix flake update caveman
nix build --no-link '.#nixosConfigurations.nixos-work.config.home-manager.users.felix.home.file.".agents/skills/caveman-compress".source'
```

If the patch no longer applies, refresh
`dotfiles/agents/patches/caveman-compress-current-agent.patch` against
`${flake-inputs.caveman}/skills/caveman-compress/SKILL.md`, then rerun
`just format-check` and `just check`.

The first migration away from `~/.agents` as a whole-directory symlink required a
one-time switch to make `~/.agents` a real directory. The final module no longer
contains that migration shim.

## Headroom

Headroom is deliberately not part of the initial setup.

Reasons:

- It is an API-layer proxy/service.
- The article uses it to wrap Claude Code and the Anthropic API.
- It changes the request path for every model call, which is a larger trust and
  debugging surface than local CLI/MCP tools.
- RTK is already available independently in nixpkgs.

Revisit Headroom only after RTK, context-mode, CBM, and any Caveman-style
brevity rules have measurable value.

## Hook Transfer Notes

Claude Code and Codex both have lifecycle hooks, but the exact tool names and
capabilities differ. The original Claude hooks should be ported carefully, not
copied blindly.

Codex hook events in the current official schema include:

- `PreToolUse`
- `PostToolUse`
- `PreCompact`
- `PostCompact`
- `SessionStart`
- `Stop`
- `SubagentStart`
- `SubagentStop`
- `UserPromptSubmit`
- `PermissionRequest`

Hook entries have this shape:

```toml
[[hooks.SessionStart]]
matcher = "startup|resume"

[[hooks.SessionStart.hooks]]
type = "command"
command = "echo 'short instruction'"
timeout = 5
statusMessage = "Loading rule"
```

For context-mode, prefer the packaged manual Codex hooks for this machine. The
upstream Codex plugin hooks are still useful reference material, but the plugin
path currently conflicts with the "no user-wide Node" preference unless it can
run through a Nix-wrapped runtime. The active setup uses `~/.codex/hooks.json`
linked from `dotfiles/codex/hooks.json`; test changes in a fresh Codex session.

Potential ports:

| Claude hook | Codex status |
|---|---|
| `bash-ban-raw-tools` | Possible as a blocking `PreToolUse` hook, but it conflicts with this repo's normal `rg`-first search habit if copied exactly. |
| `cbm-code-discovery-gate` | Possible, but should be softer for Codex: remind once, do not block docs/config/literal searches. |
| `cbm-mcp-marker` | Needs Codex MCP tool name confirmation before porting. |
| `cbm-session-reminder` | Better as `AGENTS.md` guidance or a `SessionStart` hook. |
| `context-mode hook claude-code ...` | Do not use. Use `context-mode hook codex ...` or plugin hooks. |
| `rtk hook claude` | Do not use unless RTK documents a Codex hook mode. Use explicit `rtk <cmd>` first. |

## NixOS Implementation Sketch

There are two relevant Home Manager modules:

- `home-modules/codex-token-optimization.nix`: installs RTK and context-mode,
  and links the context-mode hook config.
- `home-modules/agents.nix`: exposes repo-managed and patched upstream skills
  under `~/.agents/skills`.

`codex-token-optimization.nix` is explicit, Codex-scoped, and broad enough for
RTK, context-mode, Codebase Memory MCP, hooks, and future Headroom experiments.
Skill files that are not Codex-specific belong in `agents.nix`.

For the first pass, keep packages in that module and avoid direct mutation of
managed dotfiles:

```nix
home.packages = with pkgs; [
  rtk
  my-custom-packages.context-mode
];
```

For Codex-managed config:

- Keep `~/.codex/config.toml` machine-local for trusted project paths.
- Add only hand-reviewed snippets to it.
- Keep shared instructions in `dotfiles/codex/AGENTS.md`.
- General agent skills live under `~/.agents/skills`, managed by
  `home-modules/agents.nix`.
- Codex-specific agents still live under `~/.codex/agents`, managed by
  `home-modules/codex.nix`.

For packages not in nixpkgs:

- If upstream has a `flake.nix`, prefer consuming that flake before writing a
  local package expression.
- Before adding a flake input, check upstream docs and repo files for Cachix or
  other substituter settings (`nixConfig`, `substituters`,
  `trusted-public-keys`). If adding a cache, apply it with `just switch` before
  expecting builds to use it.
- Prefer `custom-packages/<name>.nix`.
- Expose via `flake.nix` and `modules/core.nix`.
- Build package-only first.
- Add to Home Manager only after the package builds.

Custom package status:

- `context-mode` is implemented as a repo-local custom package backed by Bun.
- `caveman` is a pinned non-flake input, not a package. Only
  `skills/caveman-compress` is exposed, through `pkgs.applyPatches`.
- `codebase-memory-mcp` only if consuming the upstream flake is not workable.

## Suggested First Patch Set

Completed:

1. Added `home-modules/codex-token-optimization.nix` and imported it for
   `nixos-work` only.
2. Added `rtk` to that module. `nodejs_22` is not installed user-wide or
   system-wide.
3. Packaged context-mode under `custom-packages/` with a Nix-wrapped Bun
   runtime, exposed it through this flake, and added only the resulting package
   to Home Manager through `codex-token-optimization.nix`.
4. Configured Codex for packaged context-mode:
   - enabled `[features].hooks = true`
   - added `[mcp_servers.context-mode] command = "context-mode"`
   - added `env = { CONTEXT_MODE_PLATFORM = "codex" }`
   - added `/home/felix/.codex/context-mode` to sandbox writable roots
   - linked `dotfiles/codex/hooks.json` to `~/.codex/hooks.json`
   - trusted the six hook commands after restarting Codex
5. Verified `context-mode doctor` after `just switch`; it reports Bun-backed
   JavaScript and TypeScript, `Performance: FAST`, hook registration, MCP
   registration, storage access, server initialization, and FTS5/SQLite.
6. Added Caveman as a non-flake flake input and exposed only the patched
   `caveman-compress` skill through `home-modules/agents.nix`.
7. Switched `~/.agents` management from one whole-directory symlink to
   individual skill links:
   - local `avoiding-duplicate-builds-in-worktrees`
   - local `find-skills`
   - patched upstream `caveman-compress`
8. Compressed `dotfiles/codex/AGENTS.md` with `caveman-compress`; the readable
   backup is `dotfiles/codex/AGENTS.original.md`.

Next patch set:

1. Check Codebase Memory MCP's upstream flake and cache story:
   - prefer its upstream `flake.nix`
   - search for Cachix/substituter hints before adding the input
   - if a cache is added, run `just switch` before building CBM
2. Add Codebase Memory MCP via the upstream flake or a fallback custom package,
   then configure the Codex MCP server.
3. Add CBM guidance to `dotfiles/codex/AGENTS.md` for structural code
   exploration once installed.
4. Restart Codex and verify the CBM MCP server in a fresh session.
5. Keep observing RTK/context-mode/Caveman-compress gains before considering
   Headroom or any global Caveman style hook.

## Sources Checked

- Article markdown in the repository root:
  `How I Cut Claude Code Token Usage by 90_+ With 5 Tools, Custom Hooks, and Enforcement  by Abid Abdul Gafoor  Apr, 2026  Medium.md`
- Companion repo: <https://github.com/sgaabdu4/claude-code-tips>
- RTK repo: <https://github.com/rtk-ai/rtk>
- context-mode repo: <https://github.com/mksglu/context-mode>
- Codebase Memory MCP repo: <https://github.com/DeusData/codebase-memory-mcp>
- Caveman repo: <https://github.com/JuliusBrussee/caveman>
- Official Codex config schema:
  <https://developers.openai.com/codex/config-schema.json>
