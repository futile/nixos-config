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
5. Install the `context-mode` Pi package for the foreground agent while retaining the Nix-provided `context-mode` executable, pinned to the same version. Give background agents context-mode through its standalone MCP server instead of loading its full Pi extension again.
6. Use fdietze's SDK-based subagents and context-prune extensions from a pinned non-flake input. Keep `noExtensions: true` for children and add only audited headless/reentrant extensions through `additionalExtensionPaths`.
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

There is a documentation/implementation discrepancy worth verifying during implementation: upstream's Pi installation section still asks for a `context-mode` entry in `~/.pi/agent/mcp.json`, but the current extension contains its own Pi-specific MCP bridge and directly registers every returned `ctx_*` tool. Do not initially add context-mode to the generic MCP adapter: loading both paths could register duplicate tools or start an unnecessary second server. Verify the package-only path with `ctx stats` and `/ctx-doctor`; add an MCP entry only if the native bridge is demonstrably insufficient.

Pinning the Pi package to the Nix package version avoids extension/server drift.

### Context pruning extension

fdietze's context-prune extension edits the actual conversation sent to the model. It stores reversible fold definitions as custom Pi session entries and applies them through Pi's `context` event. The model controls pruning explicitly through five tools:

- `context_map` shows live messages and folds in conversation order with ids and estimated token sizes;
- `context_collapse` replaces selected ranges with a caller-written digest or a bare recoverable stub;
- `context_search` searches live messages, folded messages, and fold summaries;
- `context_peek` reads folded content without restoring it to the live context;
- `context_expand` restores a whole fold or a selected sub-range.

The extension preserves tool call/result units, persists folds across session reloads and branches, and instructs the model to keep governing instructions, unresolved errors, and open loops live. It does not automatically prune at a token threshold or call a separate summarization model; the active model chooses ranges and writes any digest.

Context-mode and context-prune are complementary:

| Concern | context-mode | context-prune |
| --- | --- | --- |
| Primary intervention | Prevent bulky command, file, and web data from entering the prompt | Fold conversation content that is already in the Pi session |
| Storage | External SQLite/FTS5 content and session-event stores | Branch-aware custom Pi session entries |
| Recovery | `ctx_search` retrieves indexed external/session data | `context_search`, `context_peek`, and `context_expand` retrieve folded transcript data |
| Control | Routing hooks plus model tool choice | Explicit model-selected ranges and summaries |

Both extensions register a Pi `context` hook, but the inspected implementations compose safely in either order: context-mode appends a synthetic routing/active-memory message, while context-prune passes messages that do not match a persisted branch message id through unchanged. The main practical frictions are tool-name ambiguity, combined schema/instruction overhead, and context-mode's per-turn active-memory injection (up to roughly 500 tokens), which is ephemeral and therefore cannot be folded.

Add a short shared routing rule:

```text
Use ctx_* for external/raw data and context-mode's indexed store.
Use context_* for the current Pi conversation and its reversible folds.
Prefer ctx_* before bulky data enters the transcript; collapse completed
transcript ranges afterward.
```

Also clarify that `ctx_execute_file` analyzes large files but does not persist edits; Pi's native edit/write tools remain appropriate for changes and short exact reads. If active-memory duplication becomes measurable after adopting context-prune, a possible upstream context-mode improvement is a Pi-specific setting for its current fixed injection cap. Do not patch this pre-emptively.

## Subagent options

Pi also intentionally leaves subagents to extensions.

| Option | Strengths | Trade-offs |
| --- | --- | --- |
| fdietze subagents at pinned revision | Preferred local reference: in-process SDK sessions; persistent child sessions and restart recovery; nested agent graph; multicast messaging; live roster/transcript TUI; steering; status and ETA reporting; model override/inheritance; halt/resume and global turn budget | Unpublished source tree rather than a package; hard-coded limits; closely coupled to Pi SDK APIs; children deliberately disable extensions; no visible repository license for redistribution |
| `pi-subagents` `0.40.0` | Feature-rich packaged choice: fresh or forked context, foreground/background execution, parallel groups, chains, live steering, resume, output truncation, artifacts, structured output, acceptance gates, worktree isolation, child-parent coordination, bundled roles/prompts, and explicit `pi-mcp-adapter` integration | Approximately 2.9 MB unpacked; large configuration and behavior surface; worktree use needs clean-tree and dependency/cache planning |
| `@mjakl/pi-subagent` `2.1.0` | Small and predictable; isolated child processes; fresh/fork context; parallel calls; named persistent sessions; depth/cycle guards; rich streaming UI | No comparable chain, worktree, acceptance, and artifact machinery |
| `@tintinweb/pi-subagents` `0.14.3` | Claude Code-like tool names and TUI; foreground/background agents; live conversation viewer; steering, resume, queuing, and optional nested agents | More UI and lifecycle machinery than the small option; upstream describes it as an early release; different conventions from Codex's current subagent API |
| Official Pi subagent example | First-party and easy to audit; isolated child processes; single, parallel, and chain modes; sample roles and workflows | An example rather than a supported package contract; vendoring transfers update and compatibility maintenance to this repository |

fdietze's implementation creates isolated background `AgentSession` objects inside the main Pi process rather than child `pi` processes. The inspected revision caps the swarm at eight background agents, spawn depth three, and 200 aggregate background turns. Children inherit global/project `AGENTS.md`, skills, the default coding tools, and the caller's model unless overridden. They persist below the main session directory and can report to or request help from `main` with `send_message`.

The current child loader uses `noExtensions: true`. This deliberately prevents recursive subagents and interactive extensions, but also removes `pi-mcp-adapter`, context-mode, Serena, DeepWiki, and codebase-memory tools from children.

#### Can `extensionsOverride` blacklist only subagents?

Pi 0.83.0 exposes `DefaultResourceLoader({ extensionsOverride })`, and an override can retain the result's `runtime` and `errors` while filtering `base.extensions` by `extension.resolvedPath`. Omitting an extension from that array prevents its collected handlers, tools, commands, flags, and shortcuts from being installed in the child `ExtensionRunner`.

It is not a safe drop-in replacement for `noExtensions: true`, for two reasons:

1. `extensionsOverride` runs after Pi imports each extension module and executes its factory. It prevents runner activation, not factory-time side effects. fdietze's subagents factory immediately initializes its process-global engine, replaces the global main-message sink with the supplied `pi` API, and begins `ModelRuntime` setup. A child load that filters the resulting extension can therefore still overwrite main-session state.
2. Other extensions are not automatically safe in several same-process SDK sessions. fdietze's interactive question extension expects UI facilities, while context-mode `1.0.169` keeps module-global database, session-id, and MCP-bridge state intended for one Pi session per process. Loading it into every background session could cross-wire state even if subagents itself were filtered.

A future refactor could make `extensionsOverride` useful by moving all subagents factory side effects behind activated lifecycle handlers (or making them lazy on first real use), then maintaining a small denylist of extensions audited as interactive-only or non-reentrant. Pi 0.83.0 applies final source metadata after the override, so the filter should use `resolvedPath`, not final `sourceInfo` fields.

#### Selected child policy: explicit allowlist and MCP-only context-mode

The selected initial design is:

1. Keep `noExtensions: true` in fdietze's child `DefaultResourceLoader`.
2. Pass an explicit, audited set of child-safe extensions through `additionalExtensionPaths`. Pi intentionally loads these explicit paths even when normal extension discovery is disabled.
3. Load the full context-mode Pi extension only in the foreground agent. It retains Pi-specific routing enforcement, tool-event capture, session restore, pre-compaction snapshots, and accurate foreground statistics.
4. Give children context-mode's `ctx_*` tools through the generic MCP adapter and standalone `context-mode` MCP server. This moves context-mode's execution and mutable tool state out of the shared Pi process while avoiding its non-reentrant Pi-extension globals.
5. Give children the other selected MCP servers through the same allowlisted adapter. Main-agent brokering through `send_message` remains a fallback when a server is unavailable or intentionally omitted.

The preliminary allowlist candidates are `pi-mcp-adapter` and fdietze's context-prune extension. `pi-mcp-adapter` appears to keep its managers and server ownership per extension instance, and context-prune keeps its mutable span state inside the extension factory and reconstructs it from the owning session. Both still need a pinned-version headless concurrency test before activation. Add prompt-log, web-search, or other extensions only after the same audit.

Explicitly exclude:

- fdietze's subagents extension itself, to prevent recursive factory initialization and global engine/sink replacement;
- the interactive question extension, which assumes foreground UI;
- context-mode's full Pi extension, whose module-global database, session-id, and MCP-bridge state is not safe across same-process child sessions.

Initially, each child adapter instance may own its MCP server processes. That is simpler and better isolated, but potentially expensive for Serena, codebase-memory, and context-mode. A shared child-safe MCP connection/bridge remains a later optimization after measuring process count, memory, startup latency, and shutdown behavior.

`pi-subagents` remains the easier packaged alternative when direct `pi-mcp-adapter` integration matters more than fdietze's in-process swarm UX. Its built-in roles inherit project instructions by default, and custom agents can opt into project context, skills, and `mcp:<server>` tools.

Worktree mode is useful for parallel writers but should not be enabled as a universal default. The repository guidance requires checking build/cache reuse before creating isolated workspaces, and `pi-subagents` itself requires a clean tree for managed worktree execution.

### Integrating fdietze's source

The subagents and context-prune implementations are source directories inside fdietze's dotfiles, not published Pi packages or independent flake outputs. Concise integration choices:

| Method | Trade-off |
| --- | --- |
| Pinned non-flake input (selected) | Add `github:fdietze/dotfiles/<commit>` with `flake = false`, then link only the two extension directories. Reproducible and avoids evaluating/importing fdietze's flake dependency graph. Review source diffs before updating the lock. |
| `fetchFromGitHub` | Fixed-output source without another flake input; revision/hash updates are more manual. |
| Local fork or vendored directories | Best when implementing child-loader changes; requires upstream merge work and permission/license clarification. |
| Out-of-store links to `~/gits/fdietze-dotfiles` | Best for initial testing and `/reload` iteration; machine-specific and unreproducible. |

Example input:

```nix
inputs.fdietze-dotfiles = {
  url = "github:fdietze/dotfiles/177de6af6a16da10670d488264dd8c27051b4ae3";
  flake = false;
};
```

Home Manager can link `modules/home-manager/profiles/ai-agents/pi-extensions/{subagents,context-prune}` from that source into `~/.pi/agent/extensions/`. The inspected repository has no `LICENSE` or `COPYING` file; ask the author before publishing a modified or vendored copy.

## Findings from `fdietze-dotfiles`

The inspected setup was treated as a reference, not as the default design.

Useful patterns:

- `~/.pi/agent/settings.json` is an out-of-store symlink to a repository file because Pi rewrites settings such as `lastChangelogVersion` and changes made through `/settings`.
- Pi extensions are linked into `~/.pi/agent/extensions` from Home Manager.
- Store-mode extensions pass TypeScript type checking, linting, and unit tests before becoming Home Manager sources.
- Selected extensions can use out-of-store development links for fast `/reload` iteration.
- Pi remains independently installed; configuration and executable ownership are separate.

Patterns not recommended for the initial implementation:

- copying the bespoke extensions without a source pin, update strategy, and license clarification;
- enabling every extension inside fdietze's same-process subagents without auditing factory side effects, UI dependencies, and reentrancy;
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
| `~/.pi/agent/extensions/subagents` | Store link from a pinned fdietze source; out-of-store during deliberate extension development |
| `~/.pi/agent/extensions/context-prune` | Store link from the same pinned fdietze source; out-of-store during deliberate extension development |

The subagents extension needs a small local integration layer or patch that supplies the audited child extension paths through `additionalExtensionPaths`. Those paths should come from the same pinned package/source definitions used by Home Manager rather than from mutable package-cache locations.

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
  "npm:context-mode@1.0.169"
]
```

The fdietze extensions are local Home Manager resources rather than entries in Pi's package list. If `pi-subagents` is chosen instead, add its pinned npm package and omit the fdietze subagents link.

## Recorded decisions

1. Keep the Pi executable installed through `nix profile`; the Home Manager module manages configuration and pinned extensions, not Pi itself.
2. Share the generated global `AGENTS.md` and shared skills between Codex and Pi.
3. Use fdietze's subagents and context-prune implementations from a pinned non-flake input.
4. Use the full context-mode Pi extension in the foreground and standalone context-mode MCP access in children.
5. Keep normal child extension discovery disabled and supply an explicit `additionalExtensionPaths` allowlist of extensions audited as headless and reentrant.

## Open and missing questions

1. **Exact initial allowlist:** confirm `pi-mcp-adapter` and context-prune against the pinned revisions with concurrent SDK child sessions. Decide whether prompt-log or web-search is useful and safe enough to add; keep question, subagents, and the full context-mode extension excluded.
2. **MCP process topology:** start with independent adapter/server ownership per child or build a shared MCP connection immediately? Independent ownership is simpler, but several simultaneous Serena, codebase-memory, and context-mode processes may be too expensive.
3. **Context-mode configuration scope:** arrange for children to see the context-mode MCP server without encouraging the foreground generic MCP proxy to start a redundant second context-mode server beside the native Pi extension bridge.
4. **Context-mode attribution:** decide whether child indexing and savings statistics may be unattributed/shared with the foreground session, or whether the child bridge should pass explicit project and child-session identifiers. The content store itself is intentionally project-shared.
5. **MCP tool exposure:** decide which Serena and codebase-memory tools deserve direct registration and which should remain behind `pi-mcp-adapter`'s token-efficient proxy. DeepWiki and rarely used tools are strong proxy candidates.
6. **Lifecycle verification:** confirm that killing, restoring, reloading, and shutting down several children closes every adapter-owned MCP process and does not race on shared metadata or SQLite caches.
7. **Context-prune defaults:** decide whether children receive the same pruning instructions and thresholds as the foreground agent or a simpler child-specific policy.
8. **Source licensing:** ask fdietze for an explicit license before publishing a fork, vendored copy, or modified redistribution. A private flake input reference still avoids claiming a redistribution right but does not resolve the ambiguity.
9. **Permissions:** decide whether Pi should later gain an explicit permission/sandbox extension. This is separate from MCP and subagent configuration.
10. **Shared configuration generation:** decide whether global MCP server data should eventually be generated once for Pi JSON and Codex TOML. Avoid making that larger Codex refactor a prerequisite for the initial Pi setup.
11. **Update compatibility:** define the tested Pi, `pi-mcp-adapter`, context-mode, and fdietze revisions as one compatibility set, plus the checks required before advancing any pin.

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
- Pi `DefaultResourceLoader` at `v0.83.0`: <https://github.com/earendil-works/pi/blob/v0.83.0/packages/coding-agent/src/core/resource-loader.ts>
- `pi-mcp-adapter`: <https://github.com/nicobailon/pi-mcp-adapter>
- `pi-mcp-extension`: <https://github.com/irahardianto/pi-mcp-extension>
- `@spences10/pi-mcp`: <https://github.com/spences10/my-pi>
- context-mode: <https://github.com/mksglu/context-mode>
- context-mode Pi adapter at `v1.0.169`: <https://github.com/mksglu/context-mode/blob/v1.0.169/src/adapters/pi/extension.ts>
- fdietze subagents at the inspected revision: <https://github.com/fdietze/dotfiles/tree/177de6af6a16da10670d488264dd8c27051b4ae3/modules/home-manager/profiles/ai-agents/pi-extensions/subagents>
- fdietze context-prune design: <https://github.com/fdietze/dotfiles/blob/177de6af6a16da10670d488264dd8c27051b4ae3/modules/home-manager/profiles/ai-agents/pi-extensions/context-prune/DESIGN.md>
- `pi-subagents`: <https://github.com/nicobailon/pi-subagents>
- `@mjakl/pi-subagent`: <https://github.com/mjakl/pi-subagent>
- `@tintinweb/pi-subagents`: <https://github.com/tintinweb/pi-subagents>
- `@bacnh85/pi-serena`: <https://pi.dev/packages/%40bacnh85/pi-serena>
