# Global Agent Guidance

## Worktrees And Build Reuse

When creating git worktrees, isolated workspaces, or subagent work areas, check whether duplicated build outputs, caches, or dependency downloads would cause expensive cold rebuilds, repeated setup, or wasted disk.

Use local skill `avoiding-duplicate-builds-in-worktrees` when available.

For Rust packages in `~/gits/nixpkgs` or another nixpkgs checkout, prefer `~/nixos/bin/nix-build-sccached` over plain `nix build` when build should use shared sccache. See `~/nixos/docs/nix-sccache.md`.

After creating or changing `.codex/config.toml`, restart Codex before relying on new config. Subagents created before restart may keep stale config and must not prove new config is active. Verify with fresh Codex session or fresh subagent created after restart.

## Skill Adjustments

This section overrides skills: individual skills, groups, or all skills.
ALWAYS respect these overrides over skill instructions. NEVER ignore them. Missing any skill override is CRITICAL ERROR.
If unsure, MUST explicitly ASK what to do.

### Skill overrides:

#### the-elements-of-style:writing-clearly-and-concisely

- DO NOT silently start using this skill; it adds non-trivial token-window load.
- DO NOT auto-use for prose or human-readable text.
- ONLY use when explicitly asked, OR for LONGER, NON-TRIVIAL docs: specs, plans.
- If you want to use it, ALWAYS EXPLICITLY ASK unless already explicitly instructed.
- DO mention when it would be a good time to use the skill.

#### Subagent selection

- NEVER use a subagent above gpt-5.5-medium without explicit confirmation from the user!
- DO ask the user if you think an agent above gpt-5.5-medium should be used!
- DO NOT silently switch to a less-than-ideal subagent model even though a model above gpt-5.5-medium would be appropriate!
- DO use models below gpt-5.5-medium when otherwise appropriate.
- DO NOT default every model to gpt-5.5-medium instead of choosing task-appropriate model!

## Tool Usage

- Prefer `rtk <command>` for noisy shell commands when exact raw output is not needed: `git status`, `git diff`, build/test/lint, package-manager commands, logs. Examples: `rtk git diff --cached`, `rtk just check`, `rtk cargo test`, `rtk journalctl --user --since "10 min ago"`.
- Use raw commands when exact byte-for-byte output matters, invoking interactive tools, or debugging RTK. Use RTK metadata commands directly: `rtk gain`, `rtk gain --history`, `rtk discover`, `rtk proxy <cmd>`.
- Prefer context-mode tools for large or queryable context: use `ctx_execute` / `ctx_execute_file` for large files or logs without raw bytes, `ctx_batch_execute` for multiple noisy commands whose output should be indexed, and `ctx_search` for indexed session memory. Use raw commands when exact output is needed for editing or debugging.
- Use codebase-memory-mcp when it is configured and useful for indexed codebase exploration: architecture summaries, graph-backed code search, known symbol lookup, call/data-flow tracing, and code snippets. Useful tools include `get_architecture`, `search_code`, `search_graph`, `get_code_snippet`, `trace_path`, and `query_graph`.
- Do not treat codebase-memory-mcp as a replacement for `rg`. Use `rg` directly for exact strings, file paths, config values, docs, non-code text, or when CBM results look incomplete or noisy.
- For CBM CLI usage, discover project names with `codebase-memory-mcp cli list_projects '{}'`, query architecture with `codebase-memory-mcp cli get_architecture '{"project":"PROJECT_NAME","aspects":["all"]}'`, and index missing or stale projects with `codebase-memory-mcp cli index_repository '{"repo_path":"/absolute/path/to/repo"}'`.
- When using DeepWiki, repository names may be case-sensitive. Use the exact GitHub owner/repository casing from the URL when a lowercase or guessed name fails. For example, BitCraft public server docs are indexed as `clockworklabs/BitCraftPublic`, not `clockworklabs/bitcraftpublic`.

## Coding and Implementation Guidelines

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

### Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name confusion. Ask.
