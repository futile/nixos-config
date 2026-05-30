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
  Local skills stay live-editable; upstream helper assets can be pinned through
  flake inputs.
- Caveman is pinned as a non-flake input, but only
  `skills/caveman-compress` is exposed. Its `SKILL.md` is repo-owned, while the
  derivation reuses upstream helper scripts for detection and validation.
- Global Caveman speech style is not enabled. Use Caveman only when explicitly
  compressing selected memory/instruction files.
- Codebase Memory MCP is installed from its upstream flake and registered as a
  Codex MCP server on `nixos-work`. Headroom remains deferred because it changes
  the API request path.
- Serena is packaged locally as `my-custom-packages.serena` and installed in
  the Codex token optimization profile. Its CLI is wrapped with the shared
  editor/LSP tool bundle so the LSP backend can see the same tools used by
  editors.

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
   compression. Done via a pinned non-flake input, upstream helper scripts, and
   a repo-owned `SKILL.md`.
4. Add Codebase Memory MCP via its upstream flake and Codex MCP config.
5. Add Serena as an optional semantic code MCP/server layer, using the existing
   editor tool bundle for language-server availability. Done for `nixos-work`.
6. Revisit Headroom later, only after the local-only layers are working.

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
  my-custom-packages.serena
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

## Serena

Serena is packaged locally as `custom-packages/serena.nix` rather than installed
with upstream's `uv tool install` path. The package tracks `serena-agent` 1.5.3
from the upstream GitHub release and is exposed as both `.#serena` and
`pkgs.my-custom-packages.serena`.

The package keeps `__structuredAttrs = true` and uses separate wrapper argv
entries for `makeWrapperArgs`. It removes the deprecated `dotenv` stub
dependency and relaxes upstream's exact Python dependency pins to the nixpkgs
versions.

Serena's LSP backend needs language-server tools at runtime. Instead of giving
Serena a separate list, the package accepts `editorTools` and the Home Manager
overlay passes `final.lib.my.editorTools`. That keeps Serena aligned with the
same LSP/formatter bundle used by Helix, Neovim, Zed, Doom Emacs, and VS Code.
The `.#serena` flake package imports the same list from `modules/editor-tools.nix`.

Basic checks:

```sh
nix build .#serena --no-link
serena --version
serena start-mcp-server --help
```

The current integration only installs Serena. It does not yet add a Codex MCP
server entry, because Serena can be used either as a per-client setup command or
as an explicitly configured MCP server depending on the desired transport and
project-selection behavior.

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
live-editable through `mkOutOfStoreSymlink`, while `caveman-compress` is a small
derivation that copies upstream helper scripts and replaces `SKILL.md` with the
repo-owned version:

```nix
cavemanCompressSkill = pkgs.runCommand "caveman-compress-skill" { } ''
  cp -R ${flake-inputs.caveman}/skills/caveman-compress "$out"
  chmod -R u+w "$out"
  cp ${../dotfiles/agents/skills/caveman-compress/SKILL.md} "$out/SKILL.md"
'';

home.file.".agents/skills/caveman-compress".source = cavemanCompressSkill;
```

The repo-owned skill makes "running agent does the compression" the preferred
workflow. Upstream's helper scripts are still available for detection and
validation, but the full CLI pipeline is no longer the default because it shells
out to `claude` when no Anthropic API client is configured.

When using `$caveman:caveman-compress <file>` in-place:

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

When using explicit output mode:

```text
$caveman-compress dotfiles/codex/AGENTS.source.md to dotfiles/codex/AGENTS.md
```

The source stays unchanged, no `.original.md` backup is created, and validation
uses the source file as the original reference.

If updating Caveman, run:

```sh
nix flake update caveman
nix build --no-link '.#nixosConfigurations.nixos-work.config.home-manager.users.felix.home.file.".agents/skills/caveman-compress".source'
```

Then review whether upstream `skills/caveman-compress/scripts/` changed in a way
that requires updating `dotfiles/agents/skills/caveman-compress/SKILL.md`, then
rerun `just format-check` and `just check`.

The first migration away from `~/.agents` as a whole-directory symlink required a
one-time switch to make `~/.agents` a real directory. The final module no longer
contains that migration shim.

## Headroom

Headroom is deliberately not part of the active Codex setup.

Reasons:

- It is an API-layer proxy/service.
- The article uses it to wrap Claude Code and the Anthropic API.
- It changes the request path for every model call, which is a larger trust and
  debugging surface than local CLI/MCP tools.
- RTK is already available independently in nixpkgs.

The package expression remains in `custom-packages/headroom.nix` and the
service definition remains gated in `home-modules/codex-token-optimization.nix`
for future manual experiments. The package is not installed through Home
Manager, the service is not started, and `nixos-work` does not include Headroom
in the host `my.rustSccache.customPackageNames` list. This keeps the package
definition around without making normal `just switch` builds pay for it.

### Headroom Evaluation

Headroom was tested as a Codex OpenAI proxy with `headroom-ai` 0.22.3, first in
`--mode cache` and then in `--mode token`. The proxy needed local guardrails to
avoid pathological Codex websocket frames consuming all CPU:

- `HEADROOM_COMPRESSION_MAX_WORKERS=1`
- `HEADROOM_COMPRESS_WORKERS=1`
- `HEADROOM_KOMPRESS_MAX_CONCURRENT=1`
- `HEADROOM_WS_COMPRESSION_FAIL_THRESHOLD_BYTES=1048576`
- `HEADROOM_WS_FAIL_OPEN_ON_COMPRESSION_FAILURE=1`
- native-thread caps for `OMP_NUM_THREADS`, `ORT_NUM_THREADS`, and
  `RAYON_NUM_THREADS`

Those guardrails kept the machine usable, but the measured value for Codex was
not compelling. In the observed workload, the huge token numbers reported by
`headroom perf` were cumulative across many requests, not single prompts larger
than Codex's context window. A typical long Codex session repeatedly sent a
large stable prefix and a small changing suffix; provider prompt caching handled
most of the useful savings.

Cache-mode `/stats` snapshot:

| Metric | Value |
|---|---:|
| Requests | 127 |
| Average compression | 1.0% |
| Best compression | 10.4% |
| Tokens removed | 49,148 |
| Total input tokens | 7,180,085 |
| Attempted compression tokens | 435,784 |
| Active compression ratio | ~11.3% |
| Cache read tokens | 6,695,296 |
| Cache write tokens | 435,641 |
| Request cache hit rate | 98.4% |
| Total saved | $0.25 |
| Cache savings reported separately | $16.74 |

Token-mode `/stats` snapshot after about 30 minutes of normal Codex work:

| Metric | Value |
|---|---:|
| Requests | 133 |
| Average compression | 0.4% |
| Best compression | 6.9% |
| Tokens removed | 82,557 |
| Total input tokens | 22,416,780 |
| Attempted compression tokens | 508,100 |
| Active compression ratio | ~16.2% |
| Cache read tokens | 22,144,000 |
| Cache write tokens | 190,223 |
| Request cache hit rate | 99.2% |
| Total saved | $0.41 |
| Cache savings reported separately | $55.36 |

Token mode compressed the subset Headroom touched more aggressively, but that
subset was small relative to the repeated cached prefix. Overall token reduction
was not better, total savings percentage stayed around 3.1%, and optimization
overhead increased slightly. The live health endpoint also showed one queued
compression timeout and one leaked compression thread during token-mode
observation, so the CPU-risk path was still present even though the service
stayed alive.

The resulting decision is:

- Keep `custom-packages/headroom.nix` and
  `custom-packages/patches/headroom-codex-ws-oversize-preflight.patch` for
  future manual experiments.
- Do not install Headroom in the normal Codex Home Manager profile.
- Do not start `headroom.service` by default.
- Do not keep active Codex `model_providers.headroom`,
  `mcp_servers.headroom`, or `codex-headroom` aliases while the service is
  disabled.
- Prefer context-mode, RTK, and Codebase Memory MCP for the active Codex token
  optimization stack.

Revisit Headroom only for workloads with large fresh tool outputs where
compression can act on logs, JSON, search results, stack traces, or generated
files before they enter the model context. For normal Codex sessions on this
machine, provider prompt caching appears to carry nearly all of the useful
economics, and that provider caching remains available without the Headroom
proxy.

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
  Codebase Memory MCP, Serena, and links the context-mode hook config.
- `home-modules/agents.nix`: exposes repo-managed skills and upstream-backed
  helper assets under `~/.agents/skills`.

`codex-token-optimization.nix` is explicit, Codex-scoped, and broad enough for
RTK, context-mode, Codebase Memory MCP, hooks, and future Headroom experiments.
Skill files that are not Codex-specific belong in `agents.nix`.

For the first pass, keep packages in that module and avoid direct mutation of
managed dotfiles:

```nix
home.packages = with pkgs; [
  rtk
  my-custom-packages.context-mode
  my-custom-packages.serena
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
  `skills/caveman-compress` is exposed; upstream scripts are reused with a
  repo-owned `SKILL.md`.
- `codebase-memory-mcp` is consumed from its upstream flake.
- `serena` is implemented as a repo-local custom package, exposed through the
  flake and `pkgs.my-custom-packages`, and installed through
  `codex-token-optimization.nix`.

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
6. Added Caveman as a non-flake flake input and exposed only the
   `caveman-compress` skill through `home-modules/agents.nix`.
7. Switched `~/.agents` management from one whole-directory symlink to
   individual skill links:
   - local `avoiding-duplicate-builds-in-worktrees`
   - local `find-skills`
   - repo-owned `caveman-compress` instructions with upstream helper scripts
9. Added Serena as a local custom package, exposed it through the flake and
   `pkgs.my-custom-packages`, and installed it through
   `home-modules/codex-token-optimization.nix`.
10. Keep readable global Codex instructions in
    `dotfiles/codex/AGENTS.source.md` and regenerate compressed
    `dotfiles/codex/AGENTS.md` with:

```sh
just compress-codex-agents
```

Next patch set:

1. Restart Codex after switching, so the CBM MCP server and updated
   `caveman-compress` skill are loaded by a fresh session.
2. Verify `just compress-codex-agents` in a controlled run and inspect the
   resulting `dotfiles/codex/AGENTS.md` diff before relying on it unattended.
3. Keep observing RTK/context-mode/CBM/Caveman-compress gains before considering
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
