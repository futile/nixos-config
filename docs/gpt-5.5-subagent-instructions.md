From https://www.reddit.com/r/codex/comments/1tztz1o/goal_ran_for_45_days/

---

Update my active global Codex instructions at `C:\cm`.

Goal: improve token-efficient model routing and subagent usage without lowering work quality.

Important:

- Active Codex home on this Windows machine is `C:\cm`.
- Update the active global instructions file in `C:\cm`, not `~\.codex`, unless diagnostics prove otherwise.
- If `C:\cm\AGENTS.override.md` exists and is non-empty, update that because it overrides `AGENTS.md`.
- Otherwise update `C:\cm\AGENTS.md`.
- Preserve all unrelated existing instructions.
- Do not duplicate headings.
- Do not turn the file into a giant policy wall.
- Apply the edits below as a targeted patch.
- After editing, report:
  1. Exact file changed.
  2. Which sections were changed.
  3. Whether any duplicate/contradictory model-routing guidance remains.
  4. Approximate file size.
  5. Whether the instructions still look concise enough to be useful.

Patch instructions:

1. In `## Working style`, replace the current subagent-related bullets:

- `Use subagents for complex architecture, debugging, refactors, and multi-file changes.`
- `Treat the main thread as the orchestrator.`
- `For complex work, use architect, code_mapper, reviewer, and implementer.`

with this:

- Treat the main thread as the orchestrator, final quality gate, and owner of architecture/security/high-risk judgment.
- Use subagents only when they create net leverage: parallel exploration, large-file scanning, tedious extraction, isolated review, bounded implementation, or context reduction.
- Do not spawn subagents for small work the main thread can finish more cheaply in one concise pass.
- For complex work, consider architect, code_mapper, reviewer, and implementer only after the net-savings gate passes. Use fewer, better agents instead of an agent swarm.
- Keep `gpt-5.5` responsible for final decisions. Use cheaper/faster models to gather evidence or perform bounded work, not to lower the quality bar.

2. Insert this new section immediately after `## Working style` and before `## Orchestration default`:

## Model routing, throughput, and usage conservation

Purpose: maximize high-quality throughput, not cheap-model usage for its own sake. Use cheaper/faster models only when they reduce main-thread burden without reducing final work quality.

### Core routing rule

Route by:

- risk
- ambiguity
- context breadth
- reversibility
- verification difficulty
- net token savings
- whether the main thread would otherwise spend tedious context scanning, formatting, or extracting

Do not route only by task length. A long mechanical task may be perfect for a cheaper model. A short architecture decision may still need `gpt-5.5`.

### Net-savings gate

Before spawning a subagent, answer:

1. What exact burden is being removed from the main thread?
2. Will the subagent output be much smaller than the raw context/work?
3. Can the result be verified quickly?
4. Is the task independent enough to delegate?
5. Is the downside of a mediocre answer low?
6. What decision remains reserved for the main thread?

Use the main thread directly when:

- the task can be finished in one concise pass
- the main thread already has the relevant context loaded
- the task touches only 1-2 files and requires little search
- the delegation prompt plus returned summary would be as large as doing the work
- the task requires judgment, architecture, security, or tradeoff reasoning
- the result cannot be cheaply verified
- a wrong answer would waste significant time or create hidden debt

Use a subagent when:

- the work is parallel, read-heavy, repetitive, or mechanical
- the subagent can compress large context into compact evidence
- the work can run independently while the main thread preserves focus
- the output has a clear format and pass/fail check
- the subagent is gathering evidence or making a bounded patch, not making final decisions
- the main thread would otherwise burn many tedious tokens scanning, extracting, formatting, or comparing

Practical rule: if the subagent does not reduce main-thread reading, reasoning, or implementation burden, do not spawn it.

### Use `gpt-5.5` for main judgment

Use `gpt-5.5` for:

- ambiguous planning
- architecture decisions
- product/UX tradeoff decisions
- multi-file implementation or refactors
- deep debugging
- security-sensitive review
- data-loss, credential, payment, deployment, or production-risk work
- final judgment before important changes
- complex reasoning across many moving parts
- computer-use workflows
- research-heavy workflows
- deciding what should be built
- reconciling conflicting evidence
- reviewing cheaper-agent findings
- anything where a wrong answer would waste significant time, corrupt the repo, or reduce project quality

`gpt-5.5` remains the adult in the room.

### Use `gpt-5.4-mini` for efficient scout/support work

Use `gpt-5.4-mini` for high-volume, low-risk, predictable support work where the task is mostly reading, summarizing, extracting, checking, formatting, or mechanical editing.

Good uses:

- scan large files and return only relevant findings
- map repo structure, entrypoints, routes, modules, and file ownership
- build inventories of files, commands, dependencies, configs, env vars, models, APIs, and MCP tools
- summarize docs, logs, reports, transcripts, handoff packets, READMEs, planning files, and issue threads
- extract TODOs, FIXME comments, unresolved decisions, stale assumptions, known bugs, repeated warnings, and contradiction points
- search source/docs for references to a feature, function, route, command, model, endpoint, schema field, env var, file path, CLI flag, or dependency
- compare files, reports, configs, plans, generated artifacts, or handoff packets and return concise diffs
- summarize test output, CI logs, stack traces, linter errors, type-check failures, and command failures into likely causes and next checks
- convert formats: JSON, YAML, CSV, Markdown tables, checklists, issue lists, manifests, ledgers, and report outlines
- draft docs, changelog entries, release notes, PR summaries, issue bodies, comments, simple guides, and verification notes
- generate boilerplate, basic tests, fixtures, mocks, schema examples, validation scripts, and simple helper scripts from a clear spec
- triage issues into categories: bug, docs, config, stale file, broken path, test gap, duplicate, missing dependency, risk, blocked, or needs-main-agent-review
- identify stale docs, duplicate files, unused scripts, old handoffs, broken references, and contradictory instructions
- produce “what changed since last handoff” summaries
- produce “what files matter for this task” maps
- create compact evidence packets for the main thread

Do not use `gpt-5.4-mini` for:

- final architecture decisions
- final security judgment
- broad ambiguous refactors
- complex debugging across many interacting systems
- product strategy
- risky file operations
- anything where mediocre reasoning would reduce project quality
- anything the main thread would need to redo anyway

Output rule for `gpt-5.4-mini`: return compact evidence, not essays. Prefer findings, file references, risks, and next checks.

### Use `gpt-5.3-codex-spark` for fast bounded execution

Use `gpt-5.3-codex-spark` when available for fast, bounded, verifiable coding work. Spark can handle more than tiny UI edits, but the task must have a clear target, limited judgment, and an easy pass/fail check.

Good uses:

- tiny UI changes
- CSS/layout tweaks
- spacing, breakpoint, component-state, copy, and accessibility-label adjustments
- small single-file or tightly scoped patches
- simple route/page polish
- known failing test fixes where the expected behavior is clear
- adding or adjusting simple tests for known behavior
- implementing small helper functions from a clear spec
- updating copy, prompts, config examples, placeholder text, docs labels, or UI text
- renaming variables, labels, files, commands, or config keys when scope is bounded
- creating simple scripts, adapters, validators, parsers, or formatters from explicit input/output examples
- applying an existing repo pattern to another clearly identified file
- mechanical hygiene: remove unused imports, normalize formatting, fix obvious paths, update references, adjust simple snapshots
- bounded long single-shot tasks such as generating a table/report/manifest from known files
- fast experiments where being wrong is cheap and the result will be reviewed before merge
- implementing small patches already planned by the main thread

Do not use Spark for:

- architecture decisions
- multi-system planning
- deep debugging
- broad repo-wide refactors
- security-sensitive work
- credential, deployment, payment, billing, trading, or production-risk changes
- large context synthesis with competing tradeoffs
- final judgment before important changes
- anything requiring broad prioritization or durable planning
- anything where a wrong change could corrupt the repo, introduce hidden debt, or waste significant time

Spark output rule: make the smallest correct patch, verify it, and report exactly what changed. Do not wander into adjacent cleanup unless explicitly asked.

### Default model pattern

- Main repo brain: `gpt-5.5`
- Evidence scouts, file scanners, doc processors, log triagers, and summarizers: `gpt-5.4-mini`, only when the net-savings gate passes
- Fast bounded patches, UI polish, deterministic single-shot edits, and quick experiments: `gpt-5.3-codex-spark`, when available
- Final review before meaningful execution: `gpt-5.5`

### Quality floor

Usage conservation must not create mediocre work.

For meaningful work, done still means:

- relevant files inspected
- changes are minimal and purposeful
- tests/checks are run when available
- failures are reported honestly
- final behavior matches the request
- risks and unverified areas are stated
- important decisions are reviewed by the main thread

Escalate to `gpt-5.5` when a cheaper model hits:

- ambiguity
- conflicting evidence
- repeated failure
- unclear requirements
- broad context needs
- security risk
- high downside
- signs that the main thread would need to redo the work

### Budget/speed rules

- Prefer `gpt-5.4-mini` only when it reduces main-thread token load.
- Prefer `gpt-5.3-codex-spark` when a fast separate-lane patch or single-shot task is bounded, verifiable, and low-risk.
- Do not use cheaper models as a quality compromise.
- Do not start a subagent for work the main thread can finish more cheaply in one concise pass.
- Do not use Fast Mode when conserving usage unless speed matters more than budget.
- Always preserve verification: files changed, commands run, tests/checks performed, and anything not verified.

3. Replace the entire `## Orchestration default` section with this:

## Orchestration default

For complex requests, first decide whether subagents are actually worth it.

Use the main thread alone when the work is small, already well-scoped, context is already loaded, or delegation overhead would exceed the savings.

Use subagents when the work is meaningfully parallel, read-heavy, tedious, or safely bounded.

When subagents are warranted:

1. Use `code_mapper` or a `gpt-5.4-mini` scout for repo/file discovery and evidence gathering.
2. Use `reviewer` for risk/test review when the review can be bounded.
3. Use `architect` only for genuinely architectural uncertainty, not every normal coding task.
4. Use `implementer` only after the plan is clear; route bounded patches to Spark when available and safe.
5. Main thread synthesizes findings, makes final decisions, verifies important work, and reports uncertainty.

Do not create an agent swarm by default. Spawn fewer, sharper agents with compact output contracts.

4. Check the rest of the file for contradictions. In particular:

- Remove or replace any remaining blanket instruction that says to use subagents for all complex architecture/debugging/refactor work.
- Preserve all Windows, MCP, Composio, Mac, iPhone, and remote-control instructions unless directly contradicted by the new routing policy.
