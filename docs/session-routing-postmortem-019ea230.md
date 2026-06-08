# Session Routing Postmortem: 019ea230

Session: `019ea230-2ea3-7763-9bd2-14cdc3cecb9b`  
Artifact: `/home/felix/.codex/sessions/2026/06/07/rollout-2026-06-07T15-05-27-019ea230-2ea3-7763-9bd2-14cdc3cecb9b.jsonl`  
Repo: `/home/felix/gits/pale-darks-online`  
Scope: `pdo-m81` UnitAppearance/composite appearance work, including child beads `.1` through `.7` plus regression/cleanup beads `.8`, `.9`, `.10`.

## Summary

Main-thread ownership was appropriate for the core architectural decisions and the high-risk Bevy/ECS implementation. The best leverage opportunities were not "delegate the feature"; they were bounded scouts, bounded reviewers, and deterministic tool packets around the main implementation loop.

The strongest missed subagent leverage was review. The session repeatedly asked for adversarial review after implementation slices, and those reviews had bounded diffs, clear severity criteria, and compact expected output. A `gpt-5.4` reviewer/scout role would likely have saved main-thread context without lowering quality.

The strongest tool-only leverage was bookkeeping and repeated state inspection. The session made 971 shell calls, 130 patches, 4 compactions, and many repeated `bd`/git/status/validation operations. Some of that was necessary stateful work, but it argues for better bundled commands or purpose-built helpers before adding subagents.

Current configured-agent reality matters: there is an `architecture` agent on `gpt-5.4`, but no configured `reviewer`, `implementer`, or `code_mapper`. Superpowers role names should therefore be treated as roles, not literal agents.

## Evidence

- Session events: 6,602 JSONL records.
- User turns: 49 recorded user messages, including 43 task starts.
- Assistant messages: 620.
- Compactions: 4.
- Tool calls: 971 `exec_command`, 130 `apply_patch`, 38 Serena `find_symbol`, 9 Serena `get_symbols_overview`, 3 Serena `search_for_pattern`, 9 CBM `search_code`, 5 CBM `search_graph`, 12 CBM `get_code_snippet`, 8 `ctx_batch_execute`.
- Commits during the session included OpenSpec proposal/archive, bead hierarchy, shared model, authored content, bindings verification, editor support, simple client path coverage, composite rendering, avatar defaults, composite interaction fixes, overhead-bar scheduling fix, composite architecture cleanup, and final archive.

## Strong Leverage Points

### Bounded Review After Each Meaningful Slice

What happened:
The user repeatedly asked for slightly adversarial review after implementation slices. The main thread performed the review itself, including broad context reads, line-number gathering, and follow-up fixes.

Better route:
Use a reviewer packet after meaningful commits or before commit when the diff is bounded.

Packet:

```text
Task: Review the diff for <bead/commit range> against the OpenSpec tasks and recent user request.
Scope: git diff <base>..<head>, plus only directly referenced files.
Output: findings first, severity ordered, file references, missing tests, scope creep, and "no issue" if clean.
Stop: Do not edit files. Do not review unrelated later commits.
Main thread owns: whether to fix, final verification, commit/push.
```

Expected savings:
High. Review output should be a compact list of findings instead of the main thread rereading the implementation context.

Risk:
Low to medium. Reviewer errors are cheap if the main thread treats findings as input, not authority.

### Scout For Composite Client Architecture

What happened:
`pdo-m81.6` required conceptual work around Bevy child entities, owner relationships, custom relations, event bubbling, z-ordering, and external Bevy ECS Tiled guidance.

Better route:
Use one or two scout packets before final design, then keep the main thread responsible for the decision.

Packet:

```text
Task: Gather evidence for composite unit presentation in Bevy.
Scope: client/src/in_game, flare animation runtime, Bevy docs/DeepWiki if available, z-order URL notes.
Output: 5-10 bullets: relevant current systems, viable entity-relationship patterns, z-order constraints, event/picking implications, risks.
Stop: Do not propose a full implementation plan unless evidence directly supports it.
Main thread owns: final architecture choice.
```

Expected savings:
High. This converts broad conceptual reading into compact evidence, while preserving main-thread judgment.

Risk:
Medium. The topic is architectural; the scout must not become the decider.

### Log/Triage Scout For Runtime Regressions

What happened:
Runtime reports led to follow-up fixes: avatar parsing/visibility defaults, movement/hover/health-bar behavior, and a retained immediate UI panic with two clients.

Better route:
Use a log-triage packet for long runtime output and symptom grouping before implementation.

Packet:

```text
Task: Triage this runtime log and user symptom report.
Scope: log text, recent composite commits, directly named systems.
Output: suspected root causes, relevant file references, whether each symptom belongs in the same bead or separate regression bead, and smallest verification target.
Stop: Do not edit files.
Main thread owns: debugging plan and fixes.
```

Expected savings:
Medium to high when logs are long. The main thread still needs systematic debugging, but a scout can compress symptoms and likely files.

Risk:
Medium. Runtime diagnosis can be misleading; use scout output only as hypotheses.

### Final Diff Review For `pdo-m81.10`

What happened:
The assistant explicitly considered a reviewer subagent before committing `pdo-m81.10`, but did a local review because the available subagent path was restricted. The diff was substantial: `unit_appearance_handling`, `hover_feedback`, `overhead_health_bars`, and `target_picking`.

Better route:
Configure a general bounded reviewer agent or allow explicit reviewer role dispatch.

Packet:

```text
Task: Review this final composite architecture cleanup diff.
Scope: current staged diff plus OpenSpec tasks for pdo-m81.10.
Output: only blocking/important findings, missing tests, accidental churn, and architecture regression risk.
Stop: Do not rewrite code.
Main thread owns: fixes, final gate, commit.
```

Expected savings:
High. This is exactly the shape of work where independent review can add value and reduce main-thread rereading.

Risk:
Low. The diff was already staged and the full gate had passed.

## Conditional Leverage Points

### Shared Model Implementation (`pdo-m81.1`)

What happened:
This crossed shared synced types, SpacetimeDB bindings, generated content, client consumers, and editor fallout. The main thread used TDD and fixed downstream compile failures.

Better route:
Use a scout to find affected consumers and generation commands, but keep implementation in the main thread.

Expected savings:
Medium. A scout could have returned "files and commands that will break" before the red/green loop. Full implementation delegation would be risky because this was cross-boundary model work.

### Authored Content And Editor Slices (`pdo-m81.2`, `.3`, `.4`)

What happened:
These were narrower than `.1` and `.6`, but still involved CUE schema, cooking, editor projection, source editing, and task updates.

Better route:
After the shared model landed, use separate scouts or patch packets only if each bead has a clear file boundary and verification command.

Expected savings:
Medium. Some tasks may have been parallelizable after `.1`, but dependencies and generated artifacts make blind parallelism risky.

### Bounded Patch Work In Client Tests

What happened:
Several cycles involved fixing imports, Bevy query syntax, fixture setup, and red tests that failed for test-scoping reasons before reaching behavior.

Better route:
Use a patch worker only when the target failure and allowed files are explicit.

Expected savings:
Medium. This is suitable for a Spark-style bounded worker if one exists. Without such a configured worker, main-thread edits are acceptable.

## Tool-Only Wins

### Bookkeeping Bundles

The session repeatedly hit `bd` auto-stage/export churn, then ran `git status`, `git add .beads/issues.jsonl`, validation, commit, post-commit status, and push sequences. This is stateful work, so a subagent is not the right default. A deterministic helper or shell recipe would likely save more than a subagent.

Suggested packet/helper:

```text
Verify bead export state, restage .beads/issues.jsonl if needed, show exact staged set, and stop before commit unless explicitly allowed.
```

### Context-Mode For Command Output Compression

The raw shell-call count overstated the opportunity. `rtk` was already doing useful output compression: 91 `rtk` shell calls returned only about 33 KB total, averaging about 366 bytes each, with no outputs over 5 KB.

The heavier output came from non-`rtk` shell calls. Across 971 shell calls, recorded shell output was about 2.6 MB. Of that, non-`rtk` calls accounted for about 2.57 MB, including 152 outputs over 5 KB and 19 over 20 KB. The largest sources were raw file reads, broad `rg`, and raw `git diff`/`git show`:

- file reads: 283 calls, about 1.15 MB, 86 outputs over 5 KB
- `rg`: 75 calls, about 578 KB, 28 outputs over 5 KB
- `git`: 172 calls, about 500 KB, 28 outputs over 5 KB
- `bd`: 88 calls, about 141 KB, 8 outputs over 5 KB
- `rtk`: 91 calls, about 33 KB, 0 outputs over 5 KB

Rough savings estimate: if the 151 large non-`rtk` outputs that were not simple state mutations had been routed through `ctx_batch_execute`, `ctx_execute_file`, narrower `rg`, Serena/CBM, or scout packets, the theoretical compressible pool was about 1.7 MB of returned text. At a rough 4 bytes/token estimate, that is about 425k tokens of raw output exposure. Realistic savings would be lower because some raw diffs and file reads were needed for exact editing/review, but even a 30-50% reduction of that pool would be material.

The durable rule is: do not count `rtk` calls as automatically token-heavy. Look for large raw `sed`/`cat`, broad `rg`, and broad `git diff`/`git show` outputs first.

### Serena Edits

Serena was used mostly for reads: `find_symbol`, overviews, and pattern search. There were 130 patches. Some symbol-sized changes in Rust modules may have been candidates for Serena symbolic edits, especially where a whole function or test body was being replaced. This is a tool discipline improvement, not a subagent need.

## No-Leverage Points

- Final architecture/security/high-risk decisions: main thread should keep these.
- Core Bevy/ECS implementation in `pdo-m81.6` and `pdo-m81.10`: too interconnected for a cheap implementer to own without likely rework.
- Final verification, OpenSpec sync/archive, closing beads, and pushing: deterministic, stateful, and user-facing; main thread should own it.
- Small single-file mechanical fixes already in active context: delegation overhead would exceed savings.

## Durable Rule Changes

- Add a routing rule: after every meaningful implementation slice, consider a bounded review packet before doing local review in the main thread.
- Add a routing rule: for broad conceptual research, use scouts to gather evidence, not to decide architecture.
- Add a routing rule: if a Superpowers workflow asks for `reviewer`, `implementer`, or `code_mapper`, map that to a role and verify a matching configured agent exists before assuming delegation is possible.
- Add a tool rule: prefer deterministic bookkeeping helpers for repeated `bd`/git/export/validation state work before considering subagents.
- Add a tool rule: evaluate Serena symbolic edits when a whole known Rust symbol is being replaced; do not limit Serena to reads by habit.

## Follow-Up Improvements

- Configure a bounded `reviewer` agent on a cheaper model such as `gpt-5.4` if available. This would have been useful multiple times in this session.
- Consider a read-only `scout`/`code_mapper` agent for large evidence gathering, also on `gpt-5.4` or a cheaper suitable model.
- Do not add a generic `implementer` until there is a clear packet standard and model policy; implementation delegation was less obviously beneficial than review/scout delegation here.
- Add or improve a Beads/OpenSpec commit helper to collapse repeated export/status/stage/validate steps.
- Update AGENTS/Superpowers overrides so subagent workflows require packet scope, output format, verification policy, and stop conditions before dispatch.
