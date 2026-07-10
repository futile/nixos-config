# Global Agent Guidance

## Worktrees And Build Reuse

When creating git worktrees, isolated workspaces, or subagent work areas, check whether duplicated build outputs, caches, or dependency downloads cause expensive cold rebuilds, repeated setup, or wasted disk.

For Rust packages in `~/gits/nixpkgs` or another nixpkgs checkout, prefer `~/nixos/bin/nix-build-sccached` over plain `nix build` when build should use shared sccache. See `~/nixos/docs/nix-sccache.md`.

After creating or changing `.codex/config.toml`, restart Codex before relying on new config. Subagents created before restart may keep stale config and must not prove new config is active. Verify with fresh Codex session or fresh subagent after restart.

## Skill Adjustments

This section overrides skills: individual skills, groups, or all skills.
ALWAYS respect these overrides over skill instructions. NEVER ignore them. Missing any skill override is CRITICAL ERROR.
If unsure, MUST explicitly ASK what to do.

### Skill overrides:

#### the-elements-of-style:writing-clearly-and-concisely

- DO NOT silently start using this skill; it adds non-trivial token-window load.
- DO NOT auto-use for prose or human-readable text.
- ONLY use when explicitly asked, or for LONGER, NON-TRIVIAL docs: specs, plans.
- If you want to use the skill, ALWAYS EXPLICITLY ASK unless already explicitly instructed.
- DO mention when it would be good time to use skill.

#### Subagent routing

- Before spawning subagent, apply net-savings gate:
  - Would deterministic tool (`rg`, `ctx_execute_file`, `ctx_batch_execute`, CBM, Serena, RTK) answer cheaper?
  - Is task independent enough that subagent needs little main-thread context?
  - Can prompt be smaller than main-thread context replaced?
  - Is expected output compact and directly usable?
  - Can main thread verify result cheaply?
- Prefer subagents for bounded scouts, focused review packets, log/output triage, narrow patch work with clear acceptance criteria.
- Prefer main thread for architecture decisions, cross-cutting design, final synthesis, final verification, small edits where context already loaded, tightly coupled implementation.
- Treat names like `reviewer`, `implementer`, `code_mapper`, and `architect` as roles unless matching configured Codex agents exist.
- Main thread owns decisions. Subagents may gather evidence, propose options, or produce bounded changes; they do not decide architecture or completion status.

#### Subagent model guidance

Use these routes only after tool-first check and net-savings gate pass.

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

- Large-file or repo scans returning compact evidence.
- Docs/log/transcript/test-output triage.
- File maps, dependency/config inventories, stale-reference checks.
- Broad search summaries where exact source refs enough.
- Issue/bead/thread summary.
- Output-compression packets replacing large raw reads.

Do not use the efficient scout tier when main thread must redo reasoning,
findings are subtle, or wrong prioritization would waste significant time.

Strongly consider the balanced or frontier tier (currently `gpt-5.6-terra`
or `gpt-5.6-sol`) for higher-judgment support packets that remain bounded and
reviewable:

- Focused architecture evidence gathering without final decision authority.
- Bounded code review where subtle regressions or test gaps matter.
- Comparing implementation options from existing evidence.
- Debugging scouts where symptoms cross few files/systems but final fix choice stays main thread.
- Synthesizing scout/tool outputs into options, risks, next checks.

Use the frontier tier for subtle, high-value review; use the balanced tier when
its quality is sufficient and cost or latency matters. Do not use either as a
substitute for main-thread ownership of architecture, security, final
synthesis, or high-risk judgment.

Use a configured fast execution model such as `gpt-5.3-codex-spark` only when
it is available and the packet is bounded, low-risk, and cheaply verifiable:

- Small single-file or tightly scoped patches.
- Tiny UI/CSS/copy/config/test adjustments.
- Applying established repo pattern to identified file.
- Fixing known failing test when expected behavior explicit.
- Mechanical edits with cheap diff/test check.
- Quick experiments where wrong is cheap and result reviewed.

Do not use a fast execution model for broad refactors, architecture, deep
debugging, security-sensitive changes, multi-system planning, or likely hidden
debt. Its output should be the smallest correct patch, verification run,
changed files, and uncertainty.

Escalate back to main thread or stronger model when cheaper subagent hits ambiguity, conflicting evidence, repeated failure, broad context needs, risky edits, or signs main thread would need redo.

#### Subagent reuse

- Prefer fresh subagents for independent tasks, high-risk review, or role changes.
- Reuse subagent only for same bounded role over same scope with accurate context.
- Before reuse, restate current scope, decisions, changed files, expected output, stop conditions.
- Do not reuse subagent across unrelated beads/tasks, architecture changes, or from implementation into final review.

#### Subagent packet contract

Every subagent prompt should include:

- Role: scout, reviewer, patch worker, log triager, etc.
- Scope: files, commands, issue/bead, or subsystem boundaries.
- Goal: concrete question or deliverable.
- Constraints: allowed edits, forbidden areas, model ceiling, expected tools.
- Output: concise findings, evidence, changed files, verification run, open questions.
- Stop condition: when to return instead of continuing.

## Tool Usage

- Prefer `rtk <command>` for noisy shell commands when exact raw output not required: `git status`, `git diff`, build/test/lint, package-manager commands, logs. Examples: `rtk git diff --cached`, `rtk just check`, `rtk cargo test`, `rtk journalctl --user --since "10 min ago"`.
- Use raw commands when exact byte-for-byte output matters, invoking interactive tools, or debugging RTK. Use RTK metadata commands directly: `rtk gain`, `rtk gain --history`, `rtk discover`, `rtk proxy <cmd>`.
- Prefer context-mode tools for large or queryable context: use `ctx_execute` / `ctx_execute_file` for large files/logs without raw bytes, `ctx_batch_execute` for multiple noisy commands whose output should be indexed, and `ctx_search` for indexed session memory. Use raw commands when exact output needed for editing or debugging.
- Do not use shell-call count as token-cost proxy. `rtk` compacts noisy output, so prioritize token-saving around large raw `sed`/`cat`, broad `rg`, `git diff`/`git show`, large JSON/log output, validation output, and repeated source reads. Prefer context-mode or targeted summaries before subagent.
- Use codebase-memory-mcp when configured and useful for indexed codebase exploration: architecture summaries, graph-backed code search, known symbol lookup, call/data-flow tracing, code snippets. Useful tools: `get_architecture`, `search_code`, `search_graph`, `get_code_snippet`, `trace_path`, `query_graph`.
- Do not treat codebase-memory-mcp as `rg` replacement. Use `rg` for exact strings, file paths, config values, docs, non-code text, or when CBM results incomplete/noisy.
- When change affects known whole symbol and Serena reliable for language/project, consider Serena symbolic edits before manual broad file edit.
- For CBM CLI, discover project names with `codebase-memory-mcp cli list_projects '{}'`, query architecture with `codebase-memory-mcp cli get_architecture '{"project":"PROJECT_NAME","aspects":["all"]}'`, index stale/missing projects with `codebase-memory-mcp cli index_repository '{"repo_path":"/absolute/path/to/repo"}'`.
- For broad CBM orientation, prefer `get_architecture` with `aspects: ["all"]`; targeted/natural-language aspect names may return thin graph counts.
- For `get_architecture`, `aspects` is enum list, not free-text/semantic query. Valid values: `all`, `languages`, `packages`, `entry_points`, `routes`, `hotspots`, `boundaries`, `layers`, `file_tree`, `structure`, `dependencies`. Omit `aspects`, pass empty array, or use `["all"]` for full architecture summary. Use specific enum values like `["structure", "dependencies", "entry_points"]` when only those sections needed.
- For `search_code`, pass `regex: true` when using grep-style alternatives like `foo|bar`; otherwise pattern may be literal.
- Prefer `search_graph` BM25 `query` for concept discovery. Treat `semantic_query` experimental; verify against `search_graph`, `search_code`, or `rg`.
- Treat `query_graph` edge queries as suspect unless verified in current project; when call/data-flow matters, prefer `trace_path`, `search_graph`, `get_code_snippet`, then source reads.
- When using DeepWiki, repository names ARE ALWAYS case-sensitive. Use exact GitHub owner/repository casing from URL when available. Example: BitCraft public server docs indexed as `clockworklabs/BitCraftPublic`, not `clockworklabs/bitcraftpublic`.

## Coding and Implementation Guidelines

Behavioral guidelines reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

### Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them; don't pick silently.
- If simpler approach exists, say so. Push back when warranted.
- If unclear, stop. Name confusion. Ask.

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, skip the rest of this file.
</SUBAGENT-STOP>

## Inlined Superpowers Startup Skill

This section inlines full body of `superpowers:using-superpowers` skill. DO NOT separately load `superpowers:using-superpowers` skill just to read same `superpowers:using-superpowers` startup policy.

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

Skills sometimes use Claude Code tool names, resolve them using following mapping.

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

Superpowers subagent skills define useful workflows, but still apply local subagent net-savings gate before spawning agents. Use `subagent-driven-development` when written plan has independent slices large enough to amortize startup cost. For smaller work, prefer main-thread implementation plus bounded scout/review packets.

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

When sandbox blocks branch/push operations (detached HEAD in externally managed worktree), agent commits all work and tells user to use App native controls:

- **"Create branch"** — names branch, then commit/push/PR via App UI
- **"Hand off to local"** — transfers work to user's local checkout

Agent can still run tests, stage files, and output suggested branch names, commit messages, and PR descriptions for user to copy.

## Using Skills

### The Rule

**Invoke relevant or requested skills BEFORE any response or action.** Even 1% chance skill might apply means invoke skill to check. If invoked skill wrong for situation, no need to use it.

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

| Thought                             | Reality                                                |
| ----------------------------------- | ------------------------------------------------------ |
| "This is just a simple question"    | Questions are tasks. Check for skills.                 |
| "I need more context first"         | Skill check comes BEFORE clarifying questions.         |
| "Let me explore the codebase first" | Skills tell you HOW to explore. Check first.           |
| "I can check git/files quickly"     | Files lack conversation context. Check for skills.     |
| "Let me gather information first"   | Skills tell you HOW to gather information.             |
| "This doesn't need a formal skill"  | If a skill exists, use it.                             |
| "I remember this skill"             | Skills evolve. Read current version.                   |
| "This doesn't count as a task"      | Action = task. Check for skills.                       |
| "The skill is overkill"             | Simple things become complex. Use it.                  |
| "I'll just do this one thing first" | Check BEFORE doing anything.                           |
| "This feels productive"             | Undisciplined action wastes time. Skills prevent this. |
| "I know what that means"            | Knowing concept is not same as using skill. Invoke it. |

### Skill Priority

When multiple skills could apply, use this order:

1. **Process skills first** (brainstorming, debugging) - these determine HOW to approach task
2. **Implementation skills second** (frontend-design, mcp-builder) - these guide execution

"Let's build X" -> brainstorming first, then implementation skills.
"Fix this bug" -> debugging first, then domain-specific skills.

### Skill Types

**Rigid** (TDD, debugging): Follow exactly. Don't adapt away discipline.

**Flexible** (patterns): Adapt principles to context.

Skill itself tells you which.

### User Instructions

Instructions say WHAT, not HOW. "Add X" or "Fix Y" doesn't mean skip workflows.
