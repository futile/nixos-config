# Global Agent Guidance

## Worktrees And Build Reuse

When creating git worktrees, isolated workspaces, or subagent work areas, always check whether duplicated build outputs, caches, or dependency downloads would cause expensive cold rebuilds, repeated setup work, or wasted disk usage.

Use the local skill `avoiding-duplicate-builds-in-worktrees` for that check whenever it is available.

After creating or changing `.codex/config.toml`, restart Codex before relying on the new configuration. Subagents created before that restart may continue running with stale configuration and must not be used as proof that the new config is active. Verify with a fresh Codex session or a fresh subagent created after the restart.
