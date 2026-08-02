# Pi agent setup research

Status: research complete; configuration not yet implemented

Last checked: 2026-08-02

Tracking issue: `nixos-aos`

## Scope

This document records the investigation for adding a repository-managed Pi coding-agent configuration that is similar to the existing Codex setup while keeping the `pi` executable installed through `nix profile`.

The desired result is:

- one global instruction source shared by Codex and Pi;
- Serena, DeepWiki, codebase-memory graph tools, and context-mode available in Pi;
- a maintained subagent extension;
- declarative Home Manager wiring without taking ownership of Pi's executable, credentials, sessions, or caches.

No Pi package was installed and no Pi configuration was changed during this investigation.

## Executive summary

The recommended shape is:

1. Add a reusable `home-modules/pi.nix` that manages Pi configuration files but does not install Pi.
2. Point both `~/.codex/AGENTS.md` and `~/.pi/agent/AGENTS.md` at the existing generated `dotfiles/codex/AGENTS.md`.
3. Continue using `~/.agents/skills` for skills shared by both harnesses.
4. Use `pi-mcp-adapter` for DeepWiki, Serena, and codebase-memory-mcp.
5. Install the `context-mode` Pi package as well as retaining the Nix-provided `context-mode` executable, pinned to the same version.
6. Prefer `pi-subagents` for the most complete Codex-like delegation experience, unless a deliberately smaller extension is desired.
7. Keep Pi's writable `settings.json` as an out-of-store symlink into the repository. Leave `auth.json`, `trust.json`, sessions, downloaded packages, and caches unmanaged.

Pi extensions execute with the user's full permissions. This configuration does not by itself reproduce Codex's sandbox or approval model.

## Current local state

### Pi

- Installed version: `0.83.0`.
- Installation: `nix profile`, from `github:numtide/llm-agents.nix`, store path `/nix/store/m9fdydiglkz66fgxrila6sfibm9y7jw0-pi-0.83.0`.
- `pi list` reported no installed Pi packages.
- Current global state directory: `~/.pi/agent`.
- Current `settings.json` selects `openai-codex/gpt-5.6-sol`, `high` reasoning, and the light theme.
- Existing state includes authentication, trust data, model caches, and saved sessions. Those files should remain runtime-owned.

Installing a Pi package with `pi install npm:<package>` writes Pi's package list and package cache. It does not replace the Nix-profile `pi` executable. `pi update --self` should be avoided; package-only updates are compatible with retaining the Nix installation.

### Codex

The current Home Manager module deliberately leaves the Codex executable in `nix profile` and manages only its configuration:

- `home-modules/codex.nix` links `~/.codex/AGENTS.md` to `dotfiles/codex/AGENTS.md`;
- it links `~/.codex/agents` to `dotfiles/codex/agents`;
- `hosts/nixos-work/home.nix` selects `dotfiles/codex/hosts/nixos-work/config.toml`;
- the Codex MCP configuration currently contains DeepWiki, context-mode, Serena, and codebase-memory-mcp.

Relevant current server definitions are:

- DeepWiki: `https://mcp.deepwiki.com/mcp`;
- context-mode: `context-mode`, with `CONTEXT_MODE_PLATFORM=codex`;
- Serena: `/home/felix/nixos/bin/serena-mcp-with-desktop-env start-mcp-server --project-from-cwd --context=codex`;
- codebase-memory-mcp: `codebase-memory-mcp`, with `CBM_CACHE_DIR=/home/felix/.cache/codebase-memory-mcp`.

## Instructions and shared resources

Pi and Codex use different global configuration roots:

| Resource | Codex | Pi |
| --- | --- | --- |
| Global instructions | `~/.codex/AGENTS.md` | `~/.pi/agent/AGENTS.md` |
| Project instructions | project/ancestor `AGENTS.md` | project/ancestor `AGENTS.md` |
| Shared skills | `~/.agents/skills` | `~/.agents/skills` |
| Global agent definitions | `~/.codex/agents/*.toml` | extension-specific, usually `~/.pi/agent/agents/*.md` |
| Settings | `~/.codex/config.toml` | `~/.pi/agent/settings.json` |

Pi's resource loader checks, in order, `AGENTS.md`, `AGENTS.MD`, `CLAUDE.md`, and `CLAUDE.MD` in each directory and loads only the first match. It loads the global file first, then matching files from filesystem ancestors through the current directory. Thus:

- the global Pi file should be a second symlink to the existing generated Codex instruction file;
- no duplicate `CLAUDE.md` is needed;
- repository-local `AGENTS.md` already works unchanged in both harnesses;
- the existing Home Manager-managed `~/.agents/skills` is already the correct cross-harness skill location.

Codex agent TOML and Pi subagent Markdown should not be linked together automatically. Their schemas and runtime semantics differ even when role prose can be shared manually.

## MCP support

Pi intentionally has no built-in MCP client. Its core documentation recommends an extension for MCP rather than adding MCP to the harness itself.

### General MCP extension options

Versions and activity below were checked on 2026-08-02.

| Option | Strengths | Trade-offs |
| --- | --- | --- |
| `pi-mcp-adapter` `2.17.0` | Recommended. Actively maintained; standard shared configuration; explicit Codex import; stdio, Streamable HTTP, and SSE; lazy processes; one token-efficient proxy tool; optional selective direct tools; metadata cache; output guarding; OAuth; integration with `pi-subagents` | Approximately 2.2 MB unpacked with several dependencies; proxy use adds discovery calls; direct tools cost prompt tokens; each Pi session normally owns its server processes |
| `pi-mcp-extension` `1.5.0` | Small and straightforward; registers MCP tools directly; multi-transport; cancellation, reconnection, health checks, and tool-list refresh | Much smaller adoption and maintenance history; direct registration can make the prompt large; fewer shared-config/import conveniences; lazy servers require explicit startup in its documented workflow |
| `@spences10/pi-mcp` `0.0.58` | Small, active, project-aware, and security-conscious | Developed inside the broader `my-pi` distribution; less established as an independent default; brings a different configuration ecosystem |
| Per-service native extensions | Can provide the best Pi-specific lifecycle and UI integration | Fragmented configuration; behavior and tool sets differ from the MCP servers used by Codex; no native alternative was found for every requested server |

`pi-mcp-adapter` reads these sources, with later/project-specific sources overriding earlier/global sources:

1. `~/.config/mcp/mcp.json` and tool-agnostic `~/.agents/mcp*.json`;
2. `~/.pi/agent/mcp.json`;
3. project `.mcp.json`;
4. project `.pi/mcp.json`.

It can explicitly import host-specific configuration, including Codex, but host configs are not executed automatically. For this repository, an explicit Pi MCP file is preferable to wholesale import of the Codex TOML because the Codex file also contains unrelated model, plugin, hook, approval, and trust settings.

By default the adapter exposes one `mcp` proxy tool and starts servers lazily. `directTools` can register all or selected server tools as normal Pi tools. Upstream estimates roughly 150–300 prompt tokens per direct tool, so direct registration should be selective for Serena and codebase-memory.

### DeepWiki

DeepWiki is a remote Streamable HTTP server:

```json
{
  "url": "https://mcp.deepwiki.com/mcp",
  "lifecycle": "lazy",
  "directTools": true
}
```

It exposes only a few commonly used tools, so registering them directly is reasonable.

### Serena

The closest match to Codex is the existing local MCP wrapper:

```json
{
  "command": "/home/felix/nixos/bin/serena-mcp-with-desktop-env",
  "args": ["start-mcp-server", "--project-from-cwd", "--context=codex"],
  "lifecycle": "lazy"
}
```

Serena currently has built-in contexts including `agent`, `codex`, `ide`, and several client-specific contexts, but no Pi context. Reusing `codex` is appropriate because both harnesses already provide file, edit, and shell tools; this context removes six redundant Serena tools.

The adapter can expose a selected Serena tool set directly and leave less common tools behind the proxy. Important direct candidates include initialization/project activation, symbol overview/search/reference tools, diagnostics, safe symbolic edits, and bulk replacement.

An alternative is `@bacnh85/pi-serena`, used by the inspected `fdietze-dotfiles`. It provides Pi-native `serena_*` tools through a persistent TypeScript worker and embedded Python bridge. Advantages include Pi-specific timeouts, output caps, worker recovery, and argument repair. Disadvantages are that it does not exercise the same MCP server path as Codex, exposes a different tool surface, and deliberately removes Serena memory tools. It is attractive as a later optimization but is not the best initial parity choice.

### Codebase memory and graph tools

Use the existing command and cache:

```json
{
  "command": "codebase-memory-mcp",
  "env": {
    "CBM_CACHE_DIR": "/home/felix/.cache/codebase-memory-mcp"
  },
  "lifecycle": "lazy"
}
```

Direct-tool candidates are `list_projects`, `index_status`, `get_architecture`, `search_code`, `search_graph`, `trace_path`, `get_code_snippet`, and possibly `index_repository`. Less common graph administration tools can remain proxy-only.

### Context-mode

The repository currently packages context-mode `1.0.169`, which matched the current npm package at investigation time.

Context-mode should be installed as a Pi package as well as remaining available as a Nix-provided executable:

```json
{
  "packages": ["npm:context-mode@1.0.169"]
}
```

The Pi package is materially better than MCP-only use. Its extension registers `tool_call`, `tool_result`, `session_start`, `session_before_compact`, shutdown, routing, and continuity behavior. Inspection of the packaged `1.0.169` implementation also showed that it starts its bundled MCP server lazily and registers the returned `ctx_*` tools directly with Pi.

There is a documentation/implementation discrepancy worth verifying during implementation: upstream's Pi installation section still asks for a `context-mode` entry in `~/.pi/agent/mcp.json`, but the current extension contains its own Pi-specific MCP bridge. With `pi-mcp-adapter`, a conservative initial setup can keep a lazy, proxy-only context-mode server entry while relying on the native context-mode extension for the direct tools and hooks. If this results in duplicate diagnostics or unnecessary processes, remove the generic adapter entry after verifying `ctx_*` tools and `ctx doctor` still pass.

Pinning the Pi package to the Nix package version avoids extension/server drift.

## Subagent options

Pi also intentionally leaves subagents to extensions.

| Option | Strengths | Trade-offs |
| --- | --- | --- |
| `pi-subagents` `0.40.0` | Recommended feature-rich choice: fresh or forked context, foreground/background execution, parallel groups, chains, live steering, resume, output truncation, artifacts, structured output, acceptance gates, worktree isolation, child-parent coordination, bundled roles/prompts, and explicit `pi-mcp-adapter` integration | Approximately 2.9 MB unpacked; large configuration and behavior surface; worktree use needs clean-tree and dependency/cache planning |
| `@mjakl/pi-subagent` `2.1.0` | Small and predictable; isolated child processes; fresh/fork context; parallel calls; named persistent sessions; depth/cycle guards; rich streaming UI | No comparable chain, worktree, acceptance, and artifact machinery |
| `@tintinweb/pi-subagents` `0.14.3` | Claude Code-like tool names and TUI; foreground/background agents; live conversation viewer; steering, resume, queuing, and optional nested agents | More UI and lifecycle machinery than the small option; upstream describes it as an early release; different conventions from Codex's current subagent API |
| Official Pi subagent example | First-party and easy to audit; isolated child processes; single, parallel, and chain modes; sample roles and workflows | An example rather than a supported package contract; vendoring transfers update and compatibility maintenance to this repository |

`pi-subagents` is the closest match to the desired Codex-like setup. Its built-in roles inherit project instructions by default. Custom agents can opt into `inheritProjectContext` and `inheritSkills`; they can select direct MCP tools with `mcp:<server>` frontmatter when `pi-mcp-adapter` is installed. Explicit tool lists are strict allowlists, so extension tools must be deliberately included or ambient extension loading retained.

Worktree mode is useful for parallel writers but should not be enabled as a universal default. The repository guidance requires checking build/cache reuse before creating isolated workspaces, and `pi-subagents` itself requires a clean tree for managed worktree execution.

## Findings from `fdietze-dotfiles`

The inspected setup was treated as a reference, not as the default design.

Useful patterns:

- `~/.pi/agent/settings.json` is an out-of-store symlink to a repository file because Pi rewrites settings such as `lastChangelogVersion` and changes made through `/settings`.
- Pi extensions are linked into `~/.pi/agent/extensions` from Home Manager.
- Store-mode extensions pass TypeScript type checking, linting, and unit tests before becoming Home Manager sources.
- Selected extensions can use out-of-store development links for fast `/reload` iteration.
- Pi remains independently installed; configuration and executable ownership are separate.

Patterns not recommended for the initial implementation:

- copying the bespoke subagent extension, which currently spans 17 source/test files plus multiple local specifications for persistence, turn budgets, ETA calculation, roster UI, messaging, resume, deadlock handling, and graph tracking;
- copying the full sandbox/wrapper architecture without separately deciding that Pi should be wrapped;
- adopting `@bacnh85/pi-serena` solely because the reference setup uses it;
- disabling compaction or trusting every project without an explicit local decision.

## Proposed Home Manager design

Add `home-modules/pi.nix` with host-selectable source paths, similar to `home-modules/codex.nix`. The module should explicitly document that the Pi executable remains in `nix profile`.

Suggested managed files:

| Destination | Source/behavior |
| --- | --- |
| `~/.pi/agent/AGENTS.md` | Out-of-store symlink to `dotfiles/codex/AGENTS.md` |
| `~/.pi/agent/settings.json` | Writable out-of-store symlink to `dotfiles/pi/hosts/nixos-work/settings.json` |
| `~/.pi/agent/mcp.json` | Out-of-store symlink to `dotfiles/pi/hosts/nixos-work/mcp.json`, unless generated from Nix data |
| `~/.pi/agent/agents` | Optional, only after choosing the subagent extension and custom roles |

Do not manage:

- `auth.json`;
- `trust.json`;
- model caches and backups;
- sessions and subagent artifacts;
- npm/git package caches;
- adapter metadata and OAuth caches;
- context-mode's runtime database.

The initial `settings.json` should preserve the current provider, model, reasoning, and theme while adding pinned packages. A likely package list is:

```json
[
  "npm:pi-mcp-adapter@2.17.0",
  "npm:context-mode@1.0.169",
  "npm:pi-subagents@0.40.0"
]
```

If another subagent extension is chosen, replace only the third entry.

## Decisions still required

1. Which subagent extension to install. The default recommendation is `pi-subagents`.
2. Which Serena and codebase-memory tools should be direct rather than proxy-only.
3. Whether to retain the generic lazy context-mode MCP entry in addition to context-mode's native Pi bridge after verification.
4. Whether custom Pi agent definitions are needed initially or the selected extension's bundled agents are sufficient.
5. Whether Pi should later gain an explicit permission/sandbox extension. This is separate from MCP and subagent configuration.
6. Whether global MCP server data should eventually be factored into a shared generated source for both Pi JSON and Codex TOML. The initial implementation should avoid a larger Codex configuration refactor.

## Suggested verification

After implementation and Home Manager activation:

1. Confirm `pi --version` still resolves to the Nix-profile package.
2. Run `pi list` and confirm the pinned packages.
3. Start Pi in this repository and inspect the startup resource list.
4. Confirm the global and repository `AGENTS.md` files are loaded once each.
5. Use `/mcp` to check DeepWiki, Serena, and codebase-memory configuration.
6. Call one representative tool from each server.
7. Run `ctx stats` and `/ctx-doctor`; verify context-mode hooks and direct `ctx_*` tools.
8. Run the selected subagent extension's doctor/status command and one read-only scout.
9. Verify that a subagent follows project `AGENTS.md` and can access only its intended MCP/extension tools.
10. Run `just format-check` and `just check`; run the appropriate Home Manager build or dry activation before switching.

## Sources

Local sources:

- `home-modules/codex.nix`
- `home-modules/agents.nix`
- `home-modules/serena.nix`
- `hosts/nixos-work/home.nix`
- `dotfiles/codex/hosts/nixos-work/config.toml`
- `custom-packages/context-mode.nix`
- `bin/serena-mcp-with-desktop-env`
- `/home/felix/gits/fdietze-dotfiles/modules/home-manager/profiles/ai-agents/`

Upstream sources:

- Pi: <https://github.com/earendil-works/pi>
- Pi package and resource documentation: <https://pi.dev/docs/latest>
- Pi package catalog: <https://pi.dev/packages>
- `pi-mcp-adapter`: <https://github.com/nicobailon/pi-mcp-adapter>
- `pi-mcp-extension`: <https://github.com/irahardianto/pi-mcp-extension>
- `@spences10/pi-mcp`: <https://github.com/spences10/my-pi>
- context-mode: <https://github.com/mksglu/context-mode>
- `pi-subagents`: <https://github.com/nicobailon/pi-subagents>
- `@mjakl/pi-subagent`: <https://github.com/mjakl/pi-subagent>
- `@tintinweb/pi-subagents`: <https://github.com/tintinweb/pi-subagents>
- `@bacnh85/pi-serena`: <https://pi.dev/packages/%40bacnh85/pi-serena>
