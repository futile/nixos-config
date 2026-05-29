# Global Agent Guidance

## Worktrees And Build Reuse

When creating git worktrees, isolated workspaces, or subagent work areas, always check whether duplicated build outputs, caches, or dependency downloads would cause expensive cold rebuilds, repeated setup work, or wasted disk usage.

Use the local skill `avoiding-duplicate-builds-in-worktrees` for that check whenever it is available.

When iterating on Rust packages in `~/gits/nixpkgs` or another nixpkgs checkout, prefer `~/nixos/bin/nix-build-sccached` over plain `nix build` when the build should use the shared sccache. See `~/nixos/docs/nix-sccache.md`.

After creating or changing `.codex/config.toml`, restart Codex before relying on the new configuration. Subagents created before that restart may continue running with stale configuration and must not be used as proof that the new config is active. Verify with a fresh Codex session or a fresh subagent created after the restart.

## Skill Adjustments

This section specifies overriding instructions for skills. Either for specific individual skills, for a group of skills, or for all skills.
ALWAYS respect the overriding instructions from this list over skill instructions. NEVER ignore these. It is a CRITICAL ERROR to miss any skill override from this section!
If unsure, you MUST explicitly ASK what should be done!

### Skill overrides:

#### the-elements-of-style:writing-clearly-and-concisely

- DO NOT silently start using this skill, since it adds a non-trivial load on the token window.
- DO NOT automatically use this skill whenever writing prose or writing text for human consumption.
- Instead, ONLY use this skill when explicitly asked to, OR only when writing LONGER, NON-TRIVIAL documents, such as specs and plans.
- However, if you want to use the skill, you must ALWAYS EXPLICITLY ASK unless you have explicit clear instructions to use it already.
- DO let the user know when it would be a good time to use the skill.

#### Subagent selection

- NEVER use a subagent above gpt-5.5-medium without explicit confirmation from the user!
- DO ask the user if you think an agent above gpt-5.5-medium should be used!
- DO NOT silently switch to a less-than-ideal subagent model even though a model above gpt-5.5-medium would be appropriate!
- DO use models below gpt-5.5-medium if you wanted to do so anyway.
- DO NOT use gpt-5.5-medium for every model instead of choosing the appropriate model for each task!

## Tool Usage

- Prefer `rtk <command>` for shell commands that may produce noisy output when exact raw output is not required, especially `git status`, `git diff`, build/test/lint commands, package-manager commands, and logs. Examples: `rtk git diff --cached`, `rtk just check`, `rtk cargo test`, `rtk journalctl --user --since "10 min ago"`.
- Use raw commands when exact byte-for-byte output matters, when invoking interactive tools, or when debugging RTK itself. Use RTK metadata commands directly: `rtk gain`, `rtk gain --history`, `rtk discover`, and `rtk proxy <cmd>`.
- Prefer context-mode tools for large or queryable context: use `ctx_execute` / `ctx_execute_file` to process large files or logs without returning raw bytes, `ctx_batch_execute` for multiple noisy commands whose output should be indexed, and `ctx_search` to recall indexed session memory. Use raw commands when exact output is needed for editing or debugging.
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

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, skip the rest of this file.
</SUBAGENT-STOP>

## Inlined Superpowers Startup Skill

This section inlines the full body of the `superpowers:using-superpowers` skill, DO NOT separately load the `superpowers:using-superpowers` skill only to read this same policy to satisfy `superpowers:using-superpowers` startup policy.

Other applicable skills MUST still be loaded before use.

<EXTREMELY-IMPORTANT>
If you think there is even a 1% chance a skill might apply to what you are doing, you ABSOLUTELY MUST invoke the skill.

IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

This is not negotiable. This is not optional. You cannot rationalize your way out of this.
</EXTREMELY-IMPORTANT>

### Instruction Priority

Superpowers skills override default system prompt behavior, but **user instructions always take precedence**:

1. **User's explicit instructions** (CLAUDE.md, GEMINI.md, AGENTS.md, direct requests) - highest priority
2. **Superpowers skills** - override default system behavior where they conflict
3. **Default system prompt** - lowest priority

If CLAUDE.md, GEMINI.md, or AGENTS.md says "don't use TDD" and a skill says "always use TDD," follow the user's instructions. The user is in control.

### Claude -> Codex Adaptation

Skills sometimes use Claude Code tool names, resolve them using the following mapping.

#### Codex Tool Mapping

When you encounter these in a skill, use your platform equivalent:

| Skill references                 | Codex equivalent                                    |
| -------------------------------- | --------------------------------------------------- |
| `Task` tool (dispatch subagent)  | `spawn_agent`                                       |
| Multiple `Task` calls (parallel) | Multiple `spawn_agent` calls                        |
| Task returns result              | `wait_agent`                                        |
| Task completes automatically     | `close_agent` to free slot                          |
| `TodoWrite` (task tracking)      | `update_plan`                                       |
| `Skill` tool (invoke a skill)    | Skills load natively — just follow the instructions |
| `Read`, `Write`, `Edit` (files)  | Use your native file tools                          |
| `Bash` (run commands)            | Use your native shell tools                         |

##### Environment Detection

Skills that create worktrees or finish branches should detect their
environment with read-only git commands before proceeding:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
```

- `GIT_DIR != GIT_COMMON` → already in a linked worktree (skip creation)
- `BRANCH` empty → detached HEAD (cannot branch/push/PR from sandbox)

See `using-git-worktrees` Step 0 and `finishing-a-development-branch`
Step 1 for how each skill uses these signals.

##### Codex App Finishing

When the sandbox blocks branch/push operations (detached HEAD in an
externally managed worktree), the agent commits all work and informs
the user to use the App's native controls:

- **"Create branch"** — names the branch, then commit/push/PR via App UI
- **"Hand off to local"** — transfers work to the user's local checkout

The agent can still run tests, stage files, and output suggested branch
names, commit messages, and PR descriptions for the user to copy.

## Using Skills

### The Rule

**Invoke relevant or requested skills BEFORE any response or action.** Even a 1% chance a skill might apply means that you should invoke the skill to check. If an invoked skill turns out to be wrong for the situation, you don't need to use it.

```dot
digraph skill_flow {
    "User message received" [shape=doublecircle];
    "About to EnterPlanMode?" [shape=doublecircle];
    "Already brainstormed?" [shape=diamond];
    "Invoke brainstorming skill" [shape=box];
    "Might any skill apply?" [shape=diamond];
    "Invoke Skill tool" [shape=box];
    "Announce: 'Using [skill] to [purpose]'" [shape=box];
    "Has checklist?" [shape=diamond];
    "Create TodoWrite todo per item" [shape=box];
    "Follow skill exactly" [shape=box];
    "Respond (including clarifications)" [shape=doublecircle];

    "About to EnterPlanMode?" -> "Already brainstormed?";
    "Already brainstormed?" -> "Invoke brainstorming skill" [label="no"];
    "Already brainstormed?" -> "Might any skill apply?" [label="yes"];
    "Invoke brainstorming skill" -> "Might any skill apply?";

    "User message received" -> "Might any skill apply?";
    "Might any skill apply?" -> "Invoke Skill tool" [label="yes, even 1%"];
    "Might any skill apply?" -> "Respond (including clarifications)" [label="definitely not"];
    "Invoke Skill tool" -> "Announce: 'Using [skill] to [purpose]'";
    "Announce: 'Using [skill] to [purpose]'" -> "Has checklist?";
    "Has checklist?" -> "Create TodoWrite todo per item" [label="yes"];
    "Has checklist?" -> "Follow skill exactly" [label="no"];
    "Create TodoWrite todo per item" -> "Follow skill exactly";
}
```

### Red Flags

These thoughts mean STOP-you're rationalizing:

| Thought                             | Reality                                                            |
| ----------------------------------- | ------------------------------------------------------------------ |
| "This is just a simple question"    | Questions are tasks. Check for skills.                             |
| "I need more context first"         | Skill check comes BEFORE clarifying questions.                     |
| "Let me explore the codebase first" | Skills tell you HOW to explore. Check first.                       |
| "I can check git/files quickly"     | Files lack conversation context. Check for skills.                 |
| "Let me gather information first"   | Skills tell you HOW to gather information.                         |
| "This doesn't need a formal skill"  | If a skill exists, use it.                                         |
| "I remember this skill"             | Skills evolve. Read current version.                               |
| "This doesn't count as a task"      | Action = task. Check for skills.                                   |
| "The skill is overkill"             | Simple things become complex. Use it.                              |
| "I'll just do this one thing first" | Check BEFORE doing anything.                                       |
| "This feels productive"             | Undisciplined action wastes time. Skills prevent this.             |
| "I know what that means"            | Knowing the concept is not the same as using the skill. Invoke it. |

### Skill Priority

When multiple skills could apply, use this order:

1. **Process skills first** (brainstorming, debugging) - these determine HOW to approach the task
2. **Implementation skills second** (frontend-design, mcp-builder) - these guide execution

"Let's build X" -> brainstorming first, then implementation skills.
"Fix this bug" -> debugging first, then domain-specific skills.

### Skill Types

**Rigid** (TDD, debugging): Follow exactly. Don't adapt away discipline.

**Flexible** (patterns): Adapt principles to context.

The skill itself tells you which.

### User Instructions

Instructions say WHAT, not HOW. "Add X" or "Fix Y" doesn't mean skip workflows.
