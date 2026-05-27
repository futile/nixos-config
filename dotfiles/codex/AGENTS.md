# Global Agent Guidance

## Worktrees And Build Reuse

Creating git worktrees, isolated workspaces, or subagent work areas: check duplicated build outputs, caches, dependency downloads. Avoid expensive cold rebuilds, repeated setup, wasted disk.

Use local skill `avoiding-duplicate-builds-in-worktrees` when available.

Rust packages in `~/gits/nixpkgs` or another nixpkgs checkout: prefer `~/nixos/bin/nix-build-sccached` over plain `nix build` when build should use shared sccache. See `~/nixos/docs/nix-sccache.md`.

After creating/changing `.codex/config.toml`, restart Codex before relying on new config. Subagents created before restart may keep stale config; never use them as proof new config active. Verify with fresh Codex session or fresh subagent created after restart.

## Skill Adjustments

This section overrides skills: individual skills, groups, or all skills.
ALWAYS respect these overrides over skill instructions. NEVER ignore. Missing any skill override is CRITICAL ERROR.
If unsure, MUST explicitly ASK what to do.

### Skill overrides:

#### the-elements-of-style:writing-clearly-and-concisely

- DO NOT silently start using this skill; it adds non-trivial token-window load.
- DO NOT auto-use for prose or human-readable text.
- ONLY use when explicitly asked, OR for LONGER, NON-TRIVIAL docs: specs, plans.
- If you want to use it, ALWAYS EXPLICITLY ASK unless already explicitly instructed.
- DO mention when it would be a good time to use it.

#### Subagent selection

- NEVER use a subagent above gpt-5.5-medium without explicit confirmation from the user!
- DO ask the user if you think an agent above gpt-5.5-medium should be used!
- DO NOT silently switch to a less-than-ideal subagent model even though a model above gpt-5.5-medium would be appropriate!
- DO use models below gpt-5.5-medium when otherwise appropriate.
- DO NOT default every model to gpt-5.5-medium instead of choosing task-appropriate model!

## Tool Usage

- Prefer `rtk <command>` for noisy shell commands when exact raw output not needed: `git status`, `git diff`, build/test/lint, package-manager commands, logs. Examples: `rtk git diff --cached`, `rtk just check`, `rtk cargo test`, `rtk journalctl --user --since "10 min ago"`.
- Use raw commands when exact byte-for-byte output matters, invoking interactive tools, or debugging RTK. Use RTK metadata commands directly: `rtk gain`, `rtk gain --history`, `rtk discover`, `rtk proxy <cmd>`.
- Prefer context-mode tools for large/queryable context: `ctx_execute` / `ctx_execute_file` for large files/logs without raw bytes, `ctx_batch_execute` for multiple noisy commands whose output should be indexed, `ctx_search` for indexed session memory. Use raw commands when exact output needed for editing/debugging.
- DeepWiki repo names may be case-sensitive. Use exact GitHub owner/repository casing from URL when lowercase/guessed name fails. Example: BitCraft public server docs indexed as `clockworklabs/BitCraftPublic`, not `clockworklabs/bitcraftpublic`.

## Coding and Implementation Guidelines

Behavioral guidelines reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

### Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State assumptions explicitly. If uncertain, ask.
- Multiple interpretations: present them. Don't pick silently.
- Simpler approach exists: say so. Push back when warranted.
- Unclear: stop. Name confusion. Ask.
