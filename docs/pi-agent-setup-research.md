# Pi agent setup research

Status: configuration implemented for `nixos-work`; fdietze subagents integration upgraded to current upstream

Last checked: 2026-08-05

Tracking issues: research `nixos-aos`; initial implementation `nixos-4kl`; upstream upgrade `nixos-mwp`

## Scope

This document records the investigation for adding a repository-managed Pi coding-agent configuration that is similar to the existing Codex setup while keeping the `pi` executable installed through `nix profile`.

The desired result is:

- one global instruction source shared by Codex and Pi;
- Serena, DeepWiki, codebase-memory graph tools, and self-hosted web search available in Pi, with context-mode researched but deferred from the initial setup;
- a maintained subagent extension;
- declarative Home Manager wiring without taking ownership of Pi's executable, credentials, sessions, or caches.

The implementation still leaves the Pi executable in `nix profile` and keeps credentials, trust decisions, sessions, and package caches runtime-owned.

## Implemented configuration

The initial setup was implemented on 2026-08-02:

- `home-modules/pi.nix` manages the shared global instructions, writable host settings and MCP links, the pinned fdietze extensions, and the SearXNG provider environment.
- `dotfiles/pi/hosts/nixos-work/settings.json` preserves the existing provider, model, reasoning, and theme while pinning `pi-mcp-adapter` `2.17.0` and `@juicesharp/rpiv-web-tools` `2.3.1`.
- `dotfiles/pi/hosts/nixos-work/mcp.json` configures lazy proxy-only DeepWiki, Serena, and codebase-memory-mcp servers. Context-mode remains excluded.
- fdietze's private repository is a non-flake input pinned to `262fb764dedc2678b1522a21cbbd8818622be56c`. It uses authenticated `git+https` rather than the anonymous `github:` archive fetcher; `flake.lock` contains no credential.
- Current upstream subagents provide the child lifecycle, effective thinking-level inheritance, and accurate pause/resume behavior that previously required broad local patches. Home Manager writes the fail-closed child-extension policy for `pi-mcp-adapter`, context-prune, and `rpiv-web-tools`; narrow local patches retain AGENTS-aware model routing, child extension error logging, and scheduler-state reset during shutdown.
- `modules/searxng-local.nix` runs SearXNG on `127.0.0.1:8888`, enables HTML and JSON search responses, and generates a persistent root-owned secret at `/var/lib/searx/searx.env` on first activation. Port `8080` was already owned by the local `process-compose` supervisor.
- the shared global `AGENTS.source.md` and generated `AGENTS.md` no longer name context-mode, so Codex and Pi can use the same file without a filtered Pi variant.

## Executive summary

The recommended shape is:

1. Add a reusable `home-modules/pi.nix` that manages Pi configuration files but does not install Pi.
2. Point both `~/.codex/AGENTS.md` and `~/.pi/agent/AGENTS.md` at the existing generated `dotfiles/codex/AGENTS.md`.
3. Continue using `~/.agents/skills` for skills shared by both harnesses.
4. Use `pi-mcp-adapter` for DeepWiki, Serena, and codebase-memory-mcp.
5. Exclude context-mode from the initial Pi package list and MCP configuration. The existing Nix-provided context-mode installation remains available to Codex; the Pi research below is retained for a possible later phase.
6. Add pinned `@juicesharp/rpiv-web-tools` with a loopback-only NixOS SearXNG service. Select SearXNG non-interactively through environment variables and expose the extension to foreground and child sessions.
7. Use fdietze's SDK-based subagents and context-prune extensions from a pinned non-flake input. Keep normal child extension discovery disabled and grant only audited headless/reentrant extensions through `~/.config/pi/subagents/child-extensions.json`.
8. Keep Pi's writable `settings.json` as an out-of-store symlink into the repository. Leave `auth.json`, `trust.json`, sessions, downloaded packages, and caches unmanaged.

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

### Harness-specific global guidance

The shared `AGENTS.md` currently contains two context-mode-specific references: the subagent net-savings gate names `ctx_execute_file` and `ctx_batch_execute`, and the tool policy prefers `ctx_*` tools for bulky/queryable data. Pi would see those instructions even though context-mode is deliberately absent.

Do not maintain a filtered Pi copy of the compressed file. That would create a second generated artifact, make compression updates harder to review, and weaken the decision that both harnesses share one global instruction file. Instead:

1. Keep `dotfiles/codex/AGENTS.source.md` as the readable source and `dotfiles/codex/AGENTS.md` as its compressed, harness-neutral output. Pi loads only `AGENTS.md`; `AGENTS.source.md` is not an agent instruction file at runtime.
2. Remove the explicit context-mode tool names and preference from the shared source, generalizing the net-savings rule to available deterministic tools. Regenerate the compressed file with `just compress-codex-agents`.
3. If the explicit preference still proves useful for Codex, put the short context-mode routing rule in the Codex host config's supported `developer_instructions` field. This is an additive Codex-only instruction surface and leaves the shared `AGENTS.md` unchanged for Pi.
4. Do not use `model_instructions_file` for this overlay; Codex documents it as a replacement for built-in model instructions, which is much broader than this small harness-specific rule.
5. Restart Codex after changing its config and verify with a new session or newly created subagent; existing sessions and subagents may retain the old instruction/config state.

The selected initial policy is to remove the context-mode-specific wording from the shared files. Add the Codex-only `developer_instructions` overlay only if normal MCP tool descriptions and context-mode's own guidance do not produce reliable routing in practice.

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

### Web search

Web-search options checked on 2026-08-02:

| Option | Strengths | Trade-offs |
| --- | --- | --- |
| `@juicesharp/rpiv-web-tools` `2.3.1` | Selected. Small Pi-native `web_search` and `web_fetch` surface; ten interchangeable providers; first-class SearXNG support; output truncation and spillover; SSRF protection; headless tool registration; MIT licensed | Another child extension to audit and pin; `/web-tools` is interactive; provider and fetch behavior still depend on external sites |
| Search-provider MCP through `pi-mcp-adapter` | Reuses the selected MCP layer; hosted Exa, Tavily, and Brave servers offer capable search and extraction | Adds proxy-tool indirection; hosted providers receive queries and fetched URLs; stdio servers can multiply per child |
| `pi-web-access` | Broad search/fetch/provider support plus GitHub, PDF, and video handling | Much larger dependency and state/UI surface; needs a separate same-process child audit |
| `pi-web-search` | Uses supported Gemini, OpenAI/Codex, or Anthropic model-native search without another search account | Provider/model dependent, with no portable fallback and provider-specific cost and behavior |
| `pi-web-kit` | Bounded, cache-aware search/fetch plus Context7 documentation lookup | More overlap with DeepWiki and existing code/documentation tools |
| fdietze `web-search` | Tiny, dependency-free, and likely reentrant | Fetches all pages through Jina, has a large inline output cap, lacks tests, and the inspected redirect path did not revalidate SSRF targets |
| `pi-web-research` | Keeps raw pages out of the parent context by delegating research | Requires another provider and overlaps the selected subagent system |
| `@ollama/pi-web-search` | Very small and attractive when Ollama is already part of the deployment | Adds an Ollama service dependency otherwise |

The selected initial design is:

1. Pin `npm:@juicesharp/rpiv-web-tools@2.3.1` in Pi's package list.
2. Set `WEB_SEARCH_PROVIDER=searxng` and `SEARXNG_URL=http://127.0.0.1:8888` in the Home Manager session environment. This avoids the interactive `/web-tools` setup and its mutable config file. No `SEARXNG_API_KEY` is needed for the local instance.
3. Enable NixOS `services.searx` on loopback port 8888 with `search.formats = [ "html" "json" ]`. JSON must be enabled for the extension's search API calls. Port `8080` is already used locally by `process-compose`.
4. Keep `openFirewall`, nginx/uWSGI integration, `public_instance`, the limiter, image proxying, and local Valkey disabled. They are unnecessary for a same-machine client and can be added later if the service is intentionally exposed.
5. Supply a stable random `SEARXNG_SECRET` through `services.searx.environmentFile` and reference it as `server.secret_key = "$SEARXNG_SECRET"`. This is SearXNG's internal signing/hashing secret, not a credential that Pi needs or sends to search engines.
6. Add `rpiv-web-tools` to the explicit child allowlist. Its inspected tool state is extension-instance-local and its tools do not require UI, but the exact pinned package must pass the same concurrent headless-session and shutdown tests as the other allowlisted extensions.

This removes a search SaaS intermediary, but SearXNG remains a metasearch proxy: its configured upstream engines receive the query from this machine's public IP and may rate-limit, block, or challenge it. The extension's `web_fetch` guard still rejects arbitrary loopback/private targets; its dedicated SearXNG provider is the intended path to the configured local search endpoint.

### Context-mode

The repository currently packages context-mode `1.0.169`, which matched the current npm package at investigation time.

Context-mode is explicitly deferred from the initial Pi setup. Do not add either its Pi package or a context-mode server entry to Pi's generic MCP configuration. The existing Nix-provided executable remains in place for Codex.

If context-mode is reconsidered later, the researched package form was:

```json
{
  "packages": ["npm:context-mode@1.0.169"]
}
```

The Pi package would provide more lifecycle integration than MCP-only use. Its extension registers `tool_call`, `tool_result`, `session_start`, `session_before_compact`, shutdown, routing, and continuity behavior. Inspection of the packaged `1.0.169` implementation also showed that it starts its bundled MCP server lazily and registers the returned `ctx_*` tools directly with Pi.

There is a documentation/implementation discrepancy to revisit only if this later phase is activated: upstream's Pi installation section still asks for a `context-mode` entry in `~/.pi/agent/mcp.json`, but the current extension contains its own Pi-specific MCP bridge and directly registers every returned `ctx_*` tool. Loading both paths could register duplicate tools or start an unnecessary second server.

If later enabled, pinning the Pi package to the Nix package version would avoid extension/server drift.

### Context pruning extension

fdietze's context-prune extension edits the actual conversation sent to the model. It stores reversible fold definitions as custom Pi session entries and applies them through Pi's `context` event. The model controls pruning explicitly through five tools:

- `context_map` shows live messages and folds in conversation order with ids and estimated token sizes;
- `context_collapse` replaces selected ranges with a caller-written digest or a bare recoverable stub;
- `context_search` searches live messages, folded messages, and fold summaries;
- `context_peek` reads folded content without restoring it to the live context;
- `context_expand` restores a whole fold or a selected sub-range.

The extension preserves tool call/result units, persists folds across session reloads and branches, and instructs the model to keep governing instructions, unresolved errors, and open loops live. It does not automatically prune at a token threshold or call a separate summarization model; the active model chooses ranges and writes any digest.

Context-mode and context-prune would be complementary if context-mode is added in a later phase:

| Concern | context-mode | context-prune |
| --- | --- | --- |
| Primary intervention | Prevent bulky command, file, and web data from entering the prompt | Fold conversation content that is already in the Pi session |
| Storage | External SQLite/FTS5 content and session-event stores | Branch-aware custom Pi session entries |
| Recovery | `ctx_search` retrieves indexed external/session data | `context_search`, `context_peek`, and `context_expand` retrieve folded transcript data |
| Control | Routing hooks plus model tool choice | Explicit model-selected ranges and summaries |

Both extensions register a Pi `context` hook, but the inspected implementations compose safely in either order: context-mode appends a synthetic routing/active-memory message, while context-prune passes messages that do not match a persisted branch message id through unchanged. The main practical frictions are tool-name ambiguity, combined schema/instruction overhead, and context-mode's per-turn active-memory injection (up to roughly 500 tokens), which is ephemeral and therefore cannot be folded.

Only in that later phase, add a short shared routing rule:

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
| fdietze subagents at pinned revision | Preferred local reference: in-process SDK sessions; persistent child sessions and restart recovery; nested agent graph; multicast messaging; live roster/transcript TUI; steering; status and ETA reporting; model/thinking-level override and inheritance; pause/resume and global turn budget | Unpublished source tree rather than a package; hard-coded limits; closely coupled to Pi SDK APIs; child extensions require an explicit capability policy; no visible repository license for redistribution |
| `pi-subagents` `0.40.0` | Feature-rich packaged choice: fresh or forked context, foreground/background execution, parallel groups, chains, live steering, resume, output truncation, artifacts, structured output, acceptance gates, worktree isolation, child-parent coordination, bundled roles/prompts, and explicit `pi-mcp-adapter` integration | Approximately 2.9 MB unpacked; large configuration and behavior surface; worktree use needs clean-tree and dependency/cache planning |
| `@mjakl/pi-subagent` `2.1.0` | Small and predictable; isolated child processes; fresh/fork context; parallel calls; named persistent sessions; depth/cycle guards; rich streaming UI | No comparable chain, worktree, acceptance, and artifact machinery |
| `@tintinweb/pi-subagents` `0.14.3` | Claude Code-like tool names and TUI; foreground/background agents; live conversation viewer; steering, resume, queuing, and optional nested agents | More UI and lifecycle machinery than the small option; upstream describes it as an early release; different conventions from Codex's current subagent API |
| Official Pi subagent example | First-party and easy to audit; isolated child processes; single, parallel, and chain modes; sample roles and workflows | An example rather than a supported package contract; vendoring transfers update and compatibility maintenance to this repository |

fdietze's implementation creates isolated background `AgentSession` objects inside the main Pi process rather than child `pi` processes. The inspected revision caps the swarm at eight background agents, spawn depth three, and 200 aggregate background turns. Children inherit global/project `AGENTS.md`, skills, the default coding tools, and the caller's effective model and thinking level unless overridden. They persist below the main session directory and can report to or request help from `main` with `send_message`.

The current child loader uses `noExtensions: true` to prevent normal extension discovery, including recursive subagents and interactive extensions. It then loads only the entries in the fail-closed child-extension policy. The Home Manager policy restores `pi-mcp-adapter`, context-prune, and `rpiv-web-tools`; MCP-backed Serena, DeepWiki, and codebase-memory tools are therefore available through the adapter, while context-mode remains excluded.

#### Can `extensionsOverride` blacklist only subagents?

Pi 0.83.0 exposes `DefaultResourceLoader({ extensionsOverride })`, and an override can retain the result's `runtime` and `errors` while filtering `base.extensions` by `extension.resolvedPath`. Omitting an extension from that array prevents its collected handlers, tools, commands, flags, and shortcuts from being installed in the child `ExtensionRunner`.

It is not a safe drop-in replacement for `noExtensions: true`, for two reasons:

1. `extensionsOverride` runs after Pi imports each extension module and executes its factory. It prevents runner activation, not factory-time side effects. fdietze's subagents factory immediately initializes its process-global engine, replaces the global main-message sink with the supplied `pi` API, and begins `ModelRuntime` setup. A child load that filters the resulting extension can therefore still overwrite main-session state.
2. Other extensions are not automatically safe in several same-process SDK sessions. fdietze's interactive question extension expects UI facilities, while context-mode `1.0.169` keeps module-global database, session-id, and MCP-bridge state intended for one Pi session per process. Loading it into every background session could cross-wire state even if subagents itself were filtered.

A future refactor could make `extensionsOverride` useful by moving all subagents factory side effects behind activated lifecycle handlers (or making them lazy on first real use), then maintaining a small denylist of extensions audited as interactive-only or non-reentrant. Pi 0.83.0 applies final source metadata after the override, so the filter should use `resolvedPath`, not final `sourceInfo` fields.

#### Selected child policy: explicit allowlist

The selected initial design is:

1. Keep `noExtensions: true` in fdietze's child `DefaultResourceLoader`.
2. Pass an explicit, audited set of child-safe extensions through `additionalExtensionPaths`. Pi intentionally loads these explicit paths even when normal extension discovery is disabled.
3. Give children the selected MCP servers through the same allowlisted adapter. Main-agent brokering through `send_message` remains a fallback when a server is unavailable or intentionally omitted.
4. Do not give either foreground or child Pi sessions context-mode tools in the initial setup.

The selected allowlist is `pi-mcp-adapter`, fdietze's context-prune extension, and `@juicesharp/rpiv-web-tools`. The adapter appears to keep its managers and server ownership per extension instance, context-prune keeps its mutable span state inside the extension factory and reconstructs it from the owning session, and web-tools keeps tool/provider state local while using a shared external SearXNG service. All three still need a pinned-version headless concurrency test before activation. Add prompt-log or other extensions only after the same audit.

Explicitly exclude:

- fdietze's subagents extension itself, to prevent recursive factory initialization and global engine/sink replacement;
- the interactive question extension, which assumes foreground UI;
- context-mode's full Pi extension, whose module-global database, session-id, and MCP-bridge state is not safe across same-process child sessions.

Initially, each child adapter instance may own its MCP server processes. That is simpler and better isolated, but potentially expensive for Serena and codebase-memory. A shared child-safe MCP connection/bridge remains a later optimization after measuring process count, memory, startup latency, and shutdown behavior.

`pi-subagents` remains the easier packaged alternative when direct `pi-mcp-adapter` integration matters more than fdietze's in-process swarm UX. Its built-in roles inherit project instructions by default, and custom agents can opt into project context, skills, and `mcp:<server>` tools.

Worktree mode is useful for parallel writers but should not be enabled as a universal default. The repository guidance requires checking build/cache reuse before creating isolated workspaces, and `pi-subagents` itself requires a clean tree for managed worktree execution.

### Integrating fdietze's source

The subagents and context-prune implementations are source directories inside fdietze's dotfiles, not published Pi packages or independent flake outputs. Concise integration choices:

| Method | Trade-off |
| --- | --- |
| Pinned non-flake input (selected) | Add authenticated `git+https://github.com/fdietze/dotfiles?rev=<commit>` with `flake = false`, then link only the two extension directories. Reproducible and avoids evaluating/importing fdietze's flake dependency graph; fresh machines need repository access. Review source diffs before updating the lock. |
| `fetchFromGitHub` | Fixed-output source without another flake input; revision/hash updates are more manual. |
| Local fork or vendored directories | Best when implementing child-loader changes; requires upstream merge work and permission/license clarification. |
| Out-of-store links to `~/gits/fdietze-dotfiles` | Best for initial testing and `/reload` iteration; machine-specific and unreproducible. |

Example input:

```nix
inputs.fdietze-dotfiles = {
  url = "git+https://github.com/fdietze/dotfiles?rev=262fb764dedc2678b1522a21cbbd8818622be56c";
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

The Home Manager configuration should also set `WEB_SEARCH_PROVIDER=searxng` and `SEARXNG_URL=http://127.0.0.1:8888`. The NixOS host configuration should enable the loopback-only SearXNG service separately; Home Manager should not try to own the system service.

The subagents extension reads an explicit fail-closed capability policy from `~/.config/pi/subagents/child-extensions.json`; Home Manager generates the audited extension list. The extension paths and package specifications should remain pinned and reviewable rather than being discovered implicitly.

Do not manage:

- `auth.json`;
- `trust.json`;
- model caches and backups;
- sessions and subagent artifacts;
- npm/git package caches;
- adapter metadata and OAuth caches;
- context-mode's runtime database, which remains owned by the existing Codex setup and is not used by the initial Pi configuration.

The initial `settings.json` should preserve the current provider, model, reasoning, and theme while adding pinned packages. A likely package list is:

```json
[
  "npm:pi-mcp-adapter@2.17.0",
  "npm:@juicesharp/rpiv-web-tools@2.3.1"
]
```

The fdietze extensions are local Home Manager resources rather than entries in Pi's package list. If `pi-subagents` is chosen instead, add its pinned npm package and omit the fdietze subagents link.

## Recorded decisions

1. Keep the Pi executable installed through `nix profile`; the Home Manager module manages configuration and pinned extensions, not Pi itself.
2. Share the generated global `AGENTS.md` and shared skills between Codex and Pi.
3. Use fdietze's subagents and context-prune implementations from a pinned non-flake input.
4. Exclude context-mode from the initial Pi package list, MCP configuration, foreground session, and children. Retain its research as a deferred option.
5. Keep normal child extension discovery disabled and generate the explicit child capability policy with only extensions audited as headless and reentrant.
6. Use pinned `@juicesharp/rpiv-web-tools` with a loopback-only NixOS SearXNG instance, selected through `WEB_SEARCH_PROVIDER` and `SEARXNG_URL`.
7. Allowlist `pi-mcp-adapter`, context-prune, and `rpiv-web-tools` for child sessions; exclude subagents itself, interactive question/prompt extensions, prompt-log, and context-mode.
8. Let each child adapter own independent lazy MCP server processes initially; consider a shared bridge only after measurements justify it.
9. Begin with the adapter's proxy-only MCP exposure. Promote a small frequently used Serena or codebase-memory subset only after observing call frequency and prompt cost; keep DeepWiki proxy-only initially.
10. Treat clean child MCP shutdown and absence of orphan processes or cache races as activation requirements.
11. Use the same context-prune implementation and policy in foreground and children until usage shows a need to diverge.
12. Use fdietze's pinned source privately without vendoring or publishing modifications until its licensing is clarified.
13. Keep Pi permission/sandbox work as a separate later phase and state that the initial Pi setup runs extensions and MCP servers with the user's permissions.
14. Duplicate the small initial Pi MCP JSON rather than refactoring the working Codex TOML; revisit shared generation only if real drift appears.
15. Treat Pi, `pi-mcp-adapter`, `rpiv-web-tools`, and the fdietze revision as one tested compatibility set and update pins in deliberate, validated batches.
16. Keep the shared global `AGENTS.md` harness-neutral by removing its explicit context-mode references. Use Codex `developer_instructions` later only if Codex still needs an explicit context-mode preference; do not generate a filtered Pi copy.

## Selected policies and remaining verification

The initial answers below are decisions. The last column records validation gates or evidence that would justify revisiting them, not unresolved design choices.

| Area | Selected initial policy | Verification or reevaluation trigger |
| --- | --- | --- |
| Exact child allowlist | Use `pi-mcp-adapter`, context-prune, and `rpiv-web-tools`. Keep question, subagents itself, prompt-log, and context-mode excluded. | Run all three concurrently in several SDK child sessions against the exact pins; add another extension only after a separate headless/reentrancy audit. |
| MCP process topology | Let each child adapter own independent lazy server processes initially. This is the simplest isolation model. | Measure process count, memory, startup latency, and cleanup with several simultaneous Serena/codebase-memory users; build a shared bridge only if those measurements justify it. |
| MCP tool exposure | Begin proxy-only. Promote a small, frequently used Serena or codebase-memory subset to direct tools after observing real usage. Keep DeepWiki proxy-only initially. | Decide the direct subset using prompt-token cost and call-frequency evidence rather than enabling each server wholesale. |
| Child MCP lifecycle | Treat clean shutdown as an acceptance requirement, not an optional enhancement. | Test spawn, concurrent calls, kill, restore, same-version Pi `/reload`, and session shutdown; use a full Pi restart when an upgrade changes the engine key. Check for orphan server processes and shared metadata-cache races. |
| Context-prune policy | Use the same extension and instructions in foreground and children initially; avoid a second policy before there is usage evidence. | Observe whether short-lived children spend enough context to benefit, and introduce child-specific guidance only if they prune too eagerly or never prune when needed. |
| fdietze source licensing | Use the pinned non-flake source privately, without vendoring or publishing modifications. | Ask fdietze for an explicit license before distributing a fork, vendored source, or modified copy. |
| Pi permissions/sandboxing | Keep it outside the first configuration increment, but state clearly that Pi extensions and MCP servers run with the user's permissions. | Choose and test a permission/sandbox extension before treating Pi as equivalent to Codex's approval and sandbox model. |
| Shared Codex/Pi MCP generation | Duplicate the small initial Pi JSON configuration instead of refactoring the working Codex TOML. | Revisit a shared generated source only after the Pi setup stabilizes and configuration drift becomes a demonstrated problem. |
| Pin compatibility and updates | Treat Pi, `pi-mcp-adapter`, `rpiv-web-tools`, and the fdietze revision as one tested compatibility set; update one deliberate batch at a time. | Record the first passing versions and require loader, subagent, MCP, web-search, reload, and Home Manager checks before advancing any pin. |
| Deferred context-mode | Leave it entirely out of Pi for now. The Nix-provided Codex integration is unaffected. | No initial blocker. Revisit only if Pi usage demonstrates a context-ingestion or continuity problem that context-prune and MCP output guarding do not solve. |
| Harness-specific instructions | Keep the shared generated `AGENTS.md` free of context-mode-specific tool names. Do not create a filtered Pi variant. | Add a Codex-only `developer_instructions` rule only if MCP/tool-provided guidance proves insufficient; restart Codex and test in a fresh session. |

## Suggested verification

After implementation and Home Manager activation:

1. Confirm `pi --version` still resolves to the Nix-profile package.
2. Run `pi list` and confirm the pinned packages.
3. Start Pi in this repository and inspect the startup resource list.
4. Confirm the global and repository `AGENTS.md` files are loaded once each, and Pi receives no unavailable `ctx_*` instructions.
5. Use `/mcp` to check DeepWiki, Serena, and codebase-memory configuration.
6. Call one representative tool from each server.
7. Confirm that neither the foreground nor a child Pi session exposes context-mode tools or starts a context-mode MCP process.
8. Confirm SearXNG listens only on `127.0.0.1:8888`, its JSON API returns results, and no firewall port, reverse proxy, Valkey, or limiter was enabled.
9. Call foreground `web_search` and `web_fetch`, then repeat `web_search` from simultaneous child sessions and confirm they use SearXNG without an API key.
10. Run the selected subagent extension's doctor/status command and one read-only scout.
11. Verify that a subagent follows project `AGENTS.md` and can access only `pi-mcp-adapter`, context-prune, and `rpiv-web-tools` in addition to its normal tools.
12. Exercise child spawn, concurrent MCP/search calls, kill, restore, same-version Pi `/reload`, and shutdown; confirm no orphan MCP processes or cross-session extension state. For an engine-key upgrade, gracefully quit all Pi processes and start fresh instead of using `/reload`.
13. Run `just format-check` and `just check`; run the appropriate Home Manager build or dry activation before switching.

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
- fdietze subagents at the inspected revision: <https://github.com/fdietze/dotfiles/tree/262fb764dedc2678b1522a21cbbd8818622be56c/modules/home-manager/profiles/ai-agents/pi-extensions/subagents>
- fdietze context-prune design: <https://github.com/fdietze/dotfiles/blob/262fb764dedc2678b1522a21cbbd8818622be56c/modules/home-manager/profiles/ai-agents/pi-extensions/context-prune/DESIGN.md>
- `pi-subagents`: <https://github.com/nicobailon/pi-subagents>
- `@mjakl/pi-subagent`: <https://github.com/mjakl/pi-subagent>
- `@tintinweb/pi-subagents`: <https://github.com/tintinweb/pi-subagents>
- `@bacnh85/pi-serena`: <https://pi.dev/packages/%40bacnh85/pi-serena>
- `@juicesharp/rpiv-web-tools` `2.3.1`: <https://pi.dev/packages/%40juicesharp/rpiv-web-tools>
- `rpiv-web-tools` provider resolution: <https://github.com/juicesharp/rpiv-mono/blob/main/packages/rpiv-web-tools/docs/providers.md>
- SearXNG NixOS module: <https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/networking/searx.nix>
- SearXNG Search API: <https://docs.searxng.org/dev/search_api.html>
- SearXNG server settings: <https://docs.searxng.org/admin/settings/settings_server.html>
- Codex configuration reference (`developer_instructions` and `model_instructions_file`): <https://developers.openai.com/codex/config-reference/#configtoml>
