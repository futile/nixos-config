# Global Agent Guidance

## Worktrees And Build Reuse

When creating git worktrees, isolated workspaces, or subagent work areas, always check whether duplicated build outputs, caches, or dependency downloads would cause expensive cold rebuilds, repeated setup work, or wasted disk usage.

When iterating on Rust packages in `~/gits/nixpkgs` or another nixpkgs checkout, prefer `~/nixos/bin/nix-build-sccached` over plain `nix build` when the build should use the shared sccache. See `~/nixos/docs/nix-sccache.md`.

## Skill Adjustments

This section specifies overriding instructions for skills. Either for specific individual skills, for a group of skills, or for all skills.
ALWAYS respect the overriding instructions from this list over skill instructions. NEVER ignore these. It is a CRITICAL ERROR to miss any skill override from this section!
If unsure, you MUST explicitly ASK what should be done!

### Skill overrides:

#### Subagent routing

- Before spawning a subagent, apply the net-savings gate:
  - Would an available deterministic tool (`rg`, CBM, Serena, RTK, or equivalent) answer this cheaper?
  - Is the task independent enough that the subagent does not need broad main-thread context?
  - Can the prompt be smaller than the main-thread context it replaces?
  - Is the expected output compact and directly usable?
  - Can the main thread verify the result cheaply?
- Prefer subagents for bounded scouts, focused review packets, log/output triage, and narrow patch work with clear acceptance criteria.
- Prefer the main thread for architecture decisions, cross-cutting design, final synthesis, final verification, small edits where context is already loaded, and tightly coupled implementation.
- Treat names like `reviewer`, `implementer`, `code_mapper`, and `architect` as roles unless matching configured agents actually exist.
- Main thread owns decisions. Subagents may gather evidence, propose options, or produce bounded changes; they do not decide architecture or completion status.

#### Subagent model guidance

Use these routes only after the tool-first check and net-savings gate pass.

Model names age faster than these role boundaries. When the user asks for the
best/current model, model choice materially affects the result, or a newer
family is available, verify current official OpenAI model guidance and the
models callable in the active surface. Prefer verified current-surface
availability when it conflicts with public docs. Preserve an explicitly
requested model. Otherwise map newer models to the capability tiers below
instead of treating the literal versions as permanent.

For the current GPT-5.6 family:

- Prefer `gpt-5.6-luna` at `xhigh` for efficient, high-volume, low-risk
  scout/support packets and balanced bounded work where prioritization and
  judgment matter, including ordinary focused review. Use `max` for the
  hardest higher-judgment Luna packets.
- Prefer `gpt-5.6-sol` (or the `gpt-5.6` alias) for the most subtle,
  consequential, or quality-first bounded reviews and debugging packets.

Do not use `gpt-5.6-luna` below `xhigh` unless the human operator explicitly
allows a lower reasoning effort.

Use `medium` as the normal balanced reasoning baseline. Use `high` or
`xhigh` when the task has subtle interactions and the extra reasoning is
likely to produce a material quality gain. Reserve `max` for the hardest
quality-first packets; compare it with `xhigh` rather than assuming the
highest setting is automatically best. When migrating a proven route to
GPT-5.6, start at the existing effort and also consider one level lower because
the newer family may reach the same quality more efficiently.

Strongly consider the efficient scout tier (currently `gpt-5.6-luna`) where
work is high-volume, low-risk, and mostly extraction or summary:

- Large-file or repo scans that should return compact evidence.
- Docs/log/transcript/test-output triage.
- File maps, dependency/config inventories, stale-reference checks.
- Broad search summaries where exact source references are enough.
- Issue/bead/thread summarization.
- Output-compression packets that replace large raw reads.

Do not use the efficient scout tier when the main thread would need to redo the
reasoning, when findings are subtle, or when wrong prioritization would waste
significant time.

Strongly consider `gpt-5.6-luna` at `max` or the frontier tier (currently
`gpt-5.6-sol`) for higher-judgment support packets that remain bounded and
reviewable:

- Focused architecture evidence gathering without final decision authority.
- Bounded code review where subtle regressions or test gaps matter.
- Comparing competing implementation options from existing evidence.
- Debugging scouts where symptoms cross a few files/systems but final fix choice stays with the main thread.
- Synthesizing several scout/tool outputs into options, risks, and next checks.

Use the frontier tier for subtle, high-value review; use Luna at `max` when its
quality is sufficient and cost or latency matters. Do not use either as a
substitute for main-thread ownership of architecture, security, final
synthesis, or high-risk judgment.

Escalate back to the main thread or a stronger model when a cheaper subagent hits ambiguity, conflicting evidence, repeated failure, broad context needs, risky edits, or signs that the main thread would need to redo the result.

#### Subagent reuse

- Prefer fresh subagents for independent tasks, high-risk review, or role changes.
- Reuse a subagent only when it continues the same bounded role over the same scope and its existing context is still accurate.
- Before reuse, restate the current scope, decisions, changed files, expected output, and stop conditions.
- Do not reuse a subagent across unrelated beads/tasks, architecture changes, or from implementation into final review.

#### Subagent packet contract

Every subagent prompt should include:

- Role: scout, reviewer, patch worker, log triager, etc.
- Scope: files, commands, issue/bead, or subsystem boundaries.
- Goal: concrete question or deliverable.
- Constraints: allowed edits, forbidden areas, model ceiling, expected tools.
- Output: concise findings, evidence, changed files, verification run, and open questions.
- Stop condition: when to return instead of continuing.

## Tool Usage

- Prefer `rtk <command>` for shell commands that may produce noisy output when exact raw output is not required, especially `git status`, `git diff`, build/test/lint commands, package-manager commands, and logs. Examples: `rtk git diff --cached`, `rtk just check`, `rtk cargo test`, `rtk journalctl --user --since "10 min ago"`.
- Use raw commands when exact byte-for-byte output matters, when invoking interactive tools, or when debugging RTK itself. Use RTK metadata commands directly: `rtk gain`, `rtk gain --history`, `rtk discover`, and `rtk proxy <cmd>`.
- Do not use shell-call count as a proxy for token cost. `rtk` already compacts noisy output, so prioritize token-saving work around large raw `sed`/`cat`, broad `rg`, `git diff`/`git show`, large JSON/log output, validation output, and repeated source reads. Prefer available targeted summaries or indexes before reaching for a subagent.
- Use codebase-memory-mcp when it is configured and useful for indexed codebase exploration: architecture summaries, graph-backed code search, known symbol lookup, call/data-flow tracing, and code snippets. Useful tools include `get_architecture`, `search_code`, `search_graph`, `get_code_snippet`, `trace_path`, and `query_graph`.
- Do not treat codebase-memory-mcp as a replacement for `rg`. Use `rg` directly for exact strings, file paths, config values, docs, non-code text, or when CBM results look incomplete or noisy.
- For CBM CLI usage, discover project names with `codebase-memory-mcp cli list_projects '{}'`, query architecture with `codebase-memory-mcp cli get_architecture '{"project":"PROJECT_NAME","aspects":["all"]}'`, and index missing or stale projects with `codebase-memory-mcp cli index_repository '{"repo_path":"/absolute/path/to/repo"}'`.
- For broad CBM orientation, prefer `get_architecture` with `aspects: ["all"]`; targeted or natural-language aspect names may return only thin graph counts.
- For `get_architecture`, `aspects` is an enum list, not a free-text or semantic query field. Valid values are `all`, `languages`, `packages`, `entry_points`, `routes`, `hotspots`, `boundaries`, `layers`, `file_tree`, `structure`, and `dependencies`. Omit `aspects`, pass an empty array, or use `["all"]` for the full architecture summary. Use specific enum values such as `["structure", "dependencies", "entry_points"]` when only those sections are needed.
- For `search_code`, pass `regex: true` when using grep-style alternatives such as `foo|bar`; otherwise the pattern may be treated literally.
- Prefer `search_graph` BM25 `query` for concept discovery. Treat `semantic_query` as experimental and verify its results against `search_graph`, `search_code`, or `rg`.
- Treat `query_graph` edge queries as suspect unless verified in the current project; when call/data-flow matters, prefer `trace_path`, `search_graph`, and `get_code_snippet`, then confirm with source reads.
- Before exploring or modifying source code in a coding project, check whether a Serena integration is available. Do not assume the MCP server is named exactly `serena`; it may be named `serena_stream` or another alias. Identify Serena by its server instructions or characteristic tools such as `activate_project`, `get_current_config`, `get_symbols_overview`, and `find_symbol`.
- If Serena is available and its Instructions Manual has not yet been read in the current session, read it before code exploration. Use the MCP client's server-instructions mechanism or Serena's `initial_instructions` tool, whichever the integration exposes.
- Ensure the current repository is the active Serena project. Check Serena's current configuration when uncertain, and call `activate_project` only when the correct project is not already active. Servers started with `--project-from-cwd` may already have activated it.
- After activation, prefer Serena's symbolic tools for code structure, symbol lookup, references, and whole-symbol edits. Continue using ordinary search and file tools for exact text, documentation, configuration, non-code files, and narrow source ranges.
- Before broadly reading an external GitHub dependency's source, use DeepWiki for repository-level orientation: architecture, subsystem relationships, data/control flow, public API concepts, and likely implementation locations. Use the result to narrow subsequent source inspection.
- Treat DeepWiki as an orientation and discovery source, not as authority for the revision pinned by this repository. Verify version-sensitive behavior, exact APIs, implementation details, and claims that affect code or configuration against the pinned source; the pinned source wins on conflict.
- When using DeepWiki, repository names ARE ALWAYS case-sensitive. Use the exact GitHub owner/repository casing from the URL when available. For example, BitCraft public server docs are indexed as `clockworklabs/BitCraftPublic`, not `clockworklabs/bitcraftpublic`.

## Context Hygiene

When reversible context-editing tools are available:

- Treat phase boundaries, the point before final verification, and completed batches within a long exploration, debugging, implementation, or verification phase as context-maintenance checkpoints. During a long phase, reassess after several large tool results; do not wait for phase end or automatic compaction.
- A checkpoint requires judgment, not necessarily a `context_map` call or a fold. Material being safe to fold is not by itself enough reason to fold it, and a no-op assessment satisfies the checkpoint.
- Fold when there is meaningful completed or superseded bulk and either enough subsequent model/tool work is likely to reuse the smaller context, or context-window or quality pressure justifies immediate maintenance.
- Prefer to piggy-back maintenance on an already-required tool loop. If a final response is imminent and pressure is low, finish instead of creating a maintenance-only round trip.
- When maintenance is worthwhile, orient with `context_map` and batch-collapse bulky reads, logs, compiler or test output, rejected approaches, and completed details after capturing their conclusions in a resume-quality summary. Prefer one useful batch over folding small items individually.
- Keep governing instructions, the active user request, unresolved errors, active evidence, open decisions, and information needed verbatim for upcoming work live.
- A recent successful maintenance pass satisfies later phase-end checkpoints unless substantial new foldable bulk has accumulated. Interpret “collapse immediately once a topic closes” as “assess promptly and batch-collapse when worthwhile,” not as a requirement to fold every completed item.

## Coding and Implementation Guidelines

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

### Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.
