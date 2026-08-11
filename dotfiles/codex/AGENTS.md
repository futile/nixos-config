# Global Agent Guidance

## Worktrees And Build Reuse

Before creating git worktrees, isolated workspaces, or subagent areas, check whether duplicated outputs, caches, or downloads cause cold rebuilds, repeated setup, or disk waste.

For Rust packages in `~/gits/nixpkgs` or another nixpkgs checkout, prefer `~/nixos/bin/nix-build-sccached` over `nix build` when shared sccache should be used. See `~/nixos/docs/nix-sccache.md`.

## Skill Adjustments

Overrides below apply to specific or all skills.
ALWAYS prefer these overrides over skill instructions. Missing one is CRITICAL ERROR.
If unsure, MUST ASK.

### Skill overrides:

#### Subagent routing

- Before spawning, apply net-savings gate:
  - Can deterministic tool (`rg`, CBM, Serena, RTK, or equivalent) answer cheaper?
  - Is task independent, without broad main-thread context?
  - Can prompt be smaller than context replaced?
  - Will output be compact and directly usable?
  - Can main thread verify cheaply?
- Prefer subagents for bounded scouts, focused review packets, log/output triage, and narrow patches with clear acceptance criteria.
- Prefer main thread for architecture, cross-cutting design, final synthesis and verification, small loaded-context edits, and tightly coupled work.
- Names such as `reviewer`, `implementer`, `code_mapper`, and `architect` are roles unless configured agents exist.
- Main thread decides. Subagents gather evidence, propose options, or make bounded changes; they do not decide architecture or completion.

#### Subagent model guidance

Use routes only after tool-first and net-savings gates pass.

Model names age quickly. If user asks for best/current model, model choice matters, or newer family exists, verify official OpenAI guidance and active-surface models. Active availability beats public docs. Preserve explicit model requests. Otherwise map newer models by capability tier, not permanent literal versions.

For current GPT-5.6 family:

- Prefer `gpt-5.6-luna` at `xhigh` for efficient high-volume, low-risk scout/support packets and balanced bounded work needing prioritization and judgment, including ordinary focused review. Use `max` for hardest higher-judgment Luna packets.
- Prefer `gpt-5.6-sol` (or `gpt-5.6` alias) for subtle, consequential, quality-first bounded reviews and debugging.

Do not use `gpt-5.6-luna` below `xhigh` unless human operator explicitly permits lower effort.

Normal balanced baseline: `medium`. Use `high` or `xhigh` when subtle interactions justify cost. Reserve `max` for hardest quality-first packets; compare with `xhigh`, not automatically highest. When moving proven route to GPT-5.6, start at existing effort and consider one level lower if equally capable.

Strongly consider efficient scout tier (currently `gpt-5.6-luna`) for high-volume, low-risk extraction and summary:

- Large-file or repo scans returning compact evidence.
- Docs/log/transcript/test-output triage.
- File maps, dependency/config inventories, stale-reference checks.
- Broad search summaries needing exact source references.
- Issue/bead/thread summaries.
- Output-compression packets replacing large raw reads.

Avoid efficient tier if main thread must redo reasoning, findings are subtle, or bad prioritization wastes much time.

Strongly consider `gpt-5.6-luna` at `max` or frontier tier (currently `gpt-5.6-sol`) for bounded, reviewable higher-judgment support:

- Focused architecture evidence without decision authority.
- Bounded review for subtle regressions or test gaps.
- Existing-evidence option comparisons.
- Debugging scouts crossing few files/systems while main thread chooses fix.
- Synthesis of scout/tool outputs into options, risks, and next checks.

Use frontier tier for subtle, high-value review; use Luna at `max` when sufficient and cost or latency matters. Neither replaces main-thread ownership of architecture, security, final synthesis, or high-risk judgment.

Escalate to main thread or stronger model on ambiguity, conflicting evidence, repeated failure, broad-context needs, risky edits, or likely redo.

#### Subagent reuse

- Prefer fresh subagents for independent tasks, high-risk review, or role changes.
- Reuse only for same bounded role and scope with accurate context.
- Before reuse, restate scope, decisions, changed files, output, and stop conditions.
- Never reuse across unrelated beads/tasks, architecture changes, or implementation-to-final-review transitions.

#### Subagent packet contract

Every prompt includes:

- Role: scout, reviewer, patch worker, log triager, etc.
- Scope: files, commands, issue/bead, or subsystem boundaries.
- Goal: concrete question or deliverable.
- Constraints: allowed edits, forbidden areas, model ceiling, expected tools.
- Output: concise findings, evidence, changed files, verification, open questions.
- Stop condition: when to return.

## Tool Usage

- Prefer `rtk <command>` for potentially noisy shell output when exact raw output is unnecessary, especially `git status`, `git diff`, build/test/lint, package-manager commands, and logs. Examples: `rtk git diff --cached`, `rtk just check`, `rtk cargo test`, `rtk journalctl --user --since "10 min ago"`.
- Use raw commands for byte-exact output, interactive tools, or RTK debugging. Run metadata directly: `rtk gain`, `rtk gain --history`, `rtk discover`, and `rtk proxy <cmd>`.
- Shell-call count is not token cost. Because `rtk` compacts noisy output, focus savings on large raw `sed`/`cat`, broad `rg`, `git diff`/`git show`, large JSON/log output, validation output, and repeated reads. Prefer targeted summaries or indexes before subagents.
- Use codebase-memory-mcp when configured and useful for indexed exploration: architecture, graph search, known symbols, call/data-flow, snippets. Tools: `get_architecture`, `search_code`, `search_graph`, `get_code_snippet`, `trace_path`, `query_graph`.
- CBM does not replace `rg`. Use `rg` for exact strings, paths, config, docs, non-code text, or incomplete or noisy CBM results.
- For CBM CLI, discover projects with `codebase-memory-mcp cli list_projects '{}'`, query architecture with `codebase-memory-mcp cli get_architecture '{"project":"PROJECT_NAME","aspects":["all"]}'`, and index stale or missing projects with `codebase-memory-mcp cli index_repository '{"repo_path":"/absolute/path/to/repo"}'`.
- For broad orientation, prefer `get_architecture` with `aspects: ["all"]`; targeted or natural-language aspect names can return thin counts.
- For `get_architecture`, `aspects` is enum list, not semantic query. Values: `all`, `languages`, `packages`, `entry_points`, `routes`, `hotspots`, `boundaries`, `layers`, `file_tree`, `structure`, `dependencies`. Omit `aspects`, use empty array, or `["all"]` for full summary. Use `["structure", "dependencies", "entry_points"]` for selected sections.
- For `search_code`, pass `regex: true` for grep alternatives such as `foo|bar`; otherwise pattern may be literal.
- Prefer `search_graph` BM25 `query` for discovery. `semantic_query` is experimental; verify via `search_graph`, `search_code`, or `rg`.
- Distrust `query_graph` edge queries unless project-verified. For call/data-flow, prefer `trace_path`, `search_graph`, `get_code_snippet`, then source confirmation.
- Before source exploration or modification, check for Serena integration. Server may be `serena`, `serena_stream`, or another alias. Identify via instructions or tools: `activate_project`, `get_current_config`, `get_symbols_overview`, `find_symbol`.
- If available and unread this session, read Serena Instructions Manual before exploration via server instructions or `initial_instructions`.
- Ensure current repository is active Serena project. Check config if unsure; call `activate_project` only if wrong. Servers using `--project-from-cwd` may already activate it.
- After activation, prefer Serena symbolic tools for structure, symbol lookup and references, and whole-symbol edits. Use ordinary tools for exact text, docs, config, non-code, and narrow ranges.
- Before broad external GitHub dependency inspection, use DeepWiki for architecture, relationships, data/control flow, public API concepts, and likely locations; then narrow source reads.
- DeepWiki orients, but pinned revision is authority. Verify version-sensitive behavior, exact APIs, implementation, and consequential claims against pinned source.
- DeepWiki repository names ARE ALWAYS case-sensitive. Use exact GitHub owner/repository casing; e.g. `clockworklabs/BitCraftPublic`, not `clockworklabs/bitcraftpublic`.

## Context Hygiene

When reversible context-editing tools exist:

- Treat phase boundaries, pre-final verification, and completed batches in long work as maintenance checkpoints. Reassess after several large results; do not await phase end or auto-compaction.
- Checkpoint means judgment, not mandatory `context_map` or fold. Safe-to-fold alone is insufficient; no-op is valid.
- Fold meaningful completed or superseded bulk when enough later model/tool work benefits or context or quality pressure warrants it.
- Piggy-back maintenance on required tool loops. If final response is near and pressure low, finish.
- When useful, orient with `context_map`, then batch-collapse bulky reads, logs, compiler or test output, rejected paths, and completed details with resume-quality summary. Prefer one batch over tiny folds.
- Keep governing instructions, request, unresolved errors, active evidence and decisions, and soon-needed verbatim data live.
- Recent successful maintenance satisfies phase-end checks until substantial new bulk. “Collapse immediately once topic closes” means assess promptly and batch when worthwhile, not fold everything.

## Coding and Implementation Guidelines

Guidelines reduce common LLM coding mistakes. Merge with project rules.

**Tradeoff:** Caution over speed; use judgment for trivial tasks.

### Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State assumptions. Ask if uncertain.
- Present multiple interpretations; do not silently choose.
- Name simpler options and push back when warranted.
- If unclear, stop, explain confusion, ask.
