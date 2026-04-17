# Global Agent Guidance

## Worktrees And Build Reuse

When creating git worktrees, isolated workspaces, or subagent work areas, always check whether duplicated build outputs, caches, or dependency downloads would cause expensive cold rebuilds, repeated setup work, or wasted disk usage.

Use the local skill `avoiding-duplicate-builds-in-worktrees` for that check whenever it is available.

After creating or changing `.codex/config.toml`, restart Codex before relying on the new configuration. Subagents created before that restart may continue running with stale configuration and must not be used as proof that the new config is active. Verify with a fresh Codex session or a fresh subagent created after the restart.

## Skill Adjustments

This section specifies overriding instructions for skills. Either for specific individual skills, for a group of skills, or for all skills.
ALWAYS respect the overriding instructions from this list over skill instructions. NEVER ignore these. It is a CRITICAL ERROR to miss any skill override from this section!
If unsure, you MUST explicitly ASK what should be done!

### Skill overrides:

- the-elements-of-style:writing-clearly-and-concisely - DO NOT silently start using this skill, since it adds a non-trivial load on the token window. DO NOT automatically use this skill whenever writing prose or writing text for human consumption. Instead, ONLY use this skill when explicitly asked to, OR only when writing LONGER, NON-TRIVIAL documents, such as specs and plans. However, if you want to use the skill, you must ALWAYS EXPLICITLY ASK unless you have explicit clear instructions to use it already.
