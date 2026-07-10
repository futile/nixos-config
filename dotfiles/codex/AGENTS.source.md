# Global Agent Guidance

## Worktrees And Build Reuse

When creating git worktrees, isolated workspaces, or subagent work areas, always check whether duplicated build outputs, caches, or dependency downloads would cause expensive cold rebuilds, repeated setup work, or wasted disk usage.

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

#### Subagent routing

- Before spawning a subagent, apply the net-savings gate:
  - Would a deterministic tool (`rg`, `ctx_execute_file`, `ctx_batch_execute`, CBM, Serena, RTK) answer this cheaper?
  - Is the task independent enough that the subagent does not need broad main-thread context?
  - Can the prompt be smaller than the main-thread context it replaces?
  - Is the expected output compact and directly usable?
  - Can the main thread verify the result cheaply?
- Prefer subagents for bounded scouts, focused review packets, log/output triage, and narrow patch work with clear acceptance criteria.
- Prefer the main thread for architecture decisions, cross-cutting design, final synthesis, final verification, small edits where context is already loaded, and tightly coupled implementation.
- Treat names like `reviewer`, `implementer`, `code_mapper`, and `architect` as roles unless matching configured Codex agents actually exist.
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

- Prefer `gpt-5.6-luna` for efficient, high-volume, low-risk scout/support
  packets.
- Prefer `gpt-5.6-terra` for balanced bounded work where prioritization and
  judgment matter, including ordinary focused review.
- Prefer `gpt-5.6-sol` (or the `gpt-5.6` alias) for the most subtle,
  consequential, or quality-first bounded reviews and debugging packets.

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

Strongly consider the balanced or frontier tier (currently `gpt-5.6-terra`
or `gpt-5.6-sol`) for higher-judgment support packets that remain bounded and
reviewable:

- Focused architecture evidence gathering without final decision authority.
- Bounded code review where subtle regressions or test gaps matter.
- Comparing competing implementation options from existing evidence.
- Debugging scouts where symptoms cross a few files/systems but final fix choice stays with the main thread.
- Synthesizing several scout/tool outputs into options, risks, and next checks.

Use the frontier tier for subtle, high-value review; use the balanced tier when
its quality is sufficient and cost or latency matters. Do not use either as a
substitute for main-thread ownership of architecture, security, final
synthesis, or high-risk judgment.

Use a configured fast execution model such as `gpt-5.3-codex-spark` only when
it is available and the packet is bounded, low-risk, and cheaply verifiable:

- Small single-file or tightly scoped patches.
- Tiny UI/CSS/copy/config/test adjustments.
- Applying an established repo pattern to a clearly identified file.
- Fixing a known failing test when expected behavior is explicit.
- Mechanical edits with a cheap diff/test check.
- Quick experiments where being wrong is cheap and the result will be reviewed.

Do not use a fast execution model for broad refactors, architecture, deep
debugging, security-sensitive changes, multi-system planning, or likely hidden
debt. Its output should be the smallest correct patch, verification run,
changed files, and uncertainty.

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
- Prefer context-mode tools for large or queryable context: use `ctx_execute` / `ctx_execute_file` to process large files or logs without returning raw bytes, `ctx_batch_execute` for multiple noisy commands whose output should be indexed, and `ctx_search` to recall indexed session memory. Use raw commands when exact output is needed for editing or debugging.
- Do not use shell-call count as a proxy for token cost. `rtk` already compacts noisy output, so prioritize token-saving work around large raw `sed`/`cat`, broad `rg`, `git diff`/`git show`, large JSON/log output, validation output, and repeated source reads. Prefer context-mode or targeted tool summaries before reaching for a subagent.
- Use codebase-memory-mcp when it is configured and useful for indexed codebase exploration: architecture summaries, graph-backed code search, known symbol lookup, call/data-flow tracing, and code snippets. Useful tools include `get_architecture`, `search_code`, `search_graph`, `get_code_snippet`, `trace_path`, and `query_graph`.
- Do not treat codebase-memory-mcp as a replacement for `rg`. Use `rg` directly for exact strings, file paths, config values, docs, non-code text, or when CBM results look incomplete or noisy.
- When a change affects a known whole symbol and Serena is reliable for the language/project, consider Serena symbolic edits before manual broad file editing.
- For CBM CLI usage, discover project names with `codebase-memory-mcp cli list_projects '{}'`, query architecture with `codebase-memory-mcp cli get_architecture '{"project":"PROJECT_NAME","aspects":["all"]}'`, and index missing or stale projects with `codebase-memory-mcp cli index_repository '{"repo_path":"/absolute/path/to/repo"}'`.
- For broad CBM orientation, prefer `get_architecture` with `aspects: ["all"]`; targeted or natural-language aspect names may return only thin graph counts.
- For `get_architecture`, `aspects` is an enum list, not a free-text or semantic query field. Valid values are `all`, `languages`, `packages`, `entry_points`, `routes`, `hotspots`, `boundaries`, `layers`, `file_tree`, `structure`, and `dependencies`. Omit `aspects`, pass an empty array, or use `["all"]` for the full architecture summary. Use specific enum values such as `["structure", "dependencies", "entry_points"]` when only those sections are needed.
- For `search_code`, pass `regex: true` when using grep-style alternatives such as `foo|bar`; otherwise the pattern may be treated literally.
- Prefer `search_graph` BM25 `query` for concept discovery. Treat `semantic_query` as experimental and verify its results against `search_graph`, `search_code`, or `rg`.
- Treat `query_graph` edge queries as suspect unless verified in the current project; when call/data-flow matters, prefer `trace_path`, `search_graph`, and `get_code_snippet`, then confirm with source reads.
- Before broadly reading an external GitHub dependency's source, use DeepWiki for repository-level orientation: architecture, subsystem relationships, data/control flow, public API concepts, and likely implementation locations. Use the result to narrow subsequent source inspection.
- Treat DeepWiki as an orientation and discovery source, not as authority for the revision pinned by this repository. Verify version-sensitive behavior, exact APIs, implementation details, and claims that affect code or configuration against the pinned source; the pinned source wins on conflict.
- When using DeepWiki, repository names ARE ALWAYS case-sensitive. Use the exact GitHub owner/repository casing from the URL when available. For example, BitCraft public server docs are indexed as `clockworklabs/BitCraftPublic`, not `clockworklabs/bitcraftpublic`.

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

##### Superpowers And Subagents

Superpowers subagent skills define useful workflows, but still apply the local subagent net-savings gate before spawning agents. Use `subagent-driven-development` when there is a written plan with independent slices large enough to amortize startup cost. For smaller work, prefer main-thread implementation plus bounded scout/review packets.

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
