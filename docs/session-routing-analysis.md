# Session Routing Analysis

Use this guide to mine completed agent sessions for better model routing, subagent usage, and tool discipline. The goal is not to prove that more subagents should have been used. The goal is to find repeatable points where a different routing choice would have reduced main-thread context, cost, latency, or error risk without lowering work quality.

This document is living guidance. Update it when an analysis reveals a new routing pattern, a false economy, a better packet shape, or a tool/subagent boundary that worked better than expected.

## Goals

- Identify work that should remain in the main thread because it requires synthesis, architecture, security, high-risk judgment, or already-loaded context.
- Identify work that could become compact evidence packets, bounded patch packets, or bounded review packets.
- Separate true subagent leverage from work that is better handled by `rg`, context-mode, codebase-memory, Serena, or direct shell/tool use.
- Improve future AGENTS instructions, subagent prompts, custom agent configs, and Superpowers workflow overrides.
- Preserve quality: tests, checks, final synthesis, and user-facing claims remain the main thread's responsibility unless there is a stronger explicit reason.

## Inputs

Use whatever session artifacts are available:

- session transcript or event log
- bead/task history
- command history and tool usage
- file diffs and commits
- test/build/lint output
- final handoff or summary
- AGENTS instructions and configured custom agents at the time

When exact artifacts are unavailable, record assumptions instead of inventing certainty.

## Method

Analyze routing decisions by work unit, not by total session length. A long session may contain many tiny main-thread-appropriate edits. A short session may contain one large scan that should have been delegated or compressed with tools.

For each work unit, ask:

- What outcome was needed?
- What context was loaded into the main thread?
- Was the work read-heavy, mechanical, repetitive, parallel, or independent?
- Was the work ambiguous, architectural, risky, or tightly coupled?
- Could the result have been verified cheaply?
- Would a subagent output have been much smaller than the raw context?
- Would the main thread have needed to reread or redo the result anyway?
- Would a deterministic tool have been cheaper and more reliable than a subagent?

## Steps

1. Segment the session into work units.
   Use natural boundaries such as bead, feature slice, failing test, investigation, implementation patch, review, verification, and bookkeeping.

2. Classify each work unit.
   Use categories such as discovery, planning, implementation, debugging, review, verification, documentation, and issue/git bookkeeping.

3. Identify main-thread burden.
   Look for large scans, long logs, repeated file reads, broad diffs, independent subtasks handled serially, manual summarization, stale-context carryover, and review mixed into implementation.

4. Check tool-first alternatives.
   Before recommending a subagent, ask whether `rg`, `ctx_batch_execute`, `ctx_execute_file`, codebase-memory, Serena, or direct shell use would have produced the same compact answer more deterministically. Do not assume the original session used these optimally. Include missed opportunities such as Serena symbolic edits, not just Serena reads.

   Do not treat shell-call count as a proxy for token cost. Some shell tools, especially `rtk`, already compact noisy output aggressively. Quantify returned output by command class when possible. Focus on large raw outputs: broad `sed`/`cat` reads, broad `rg`, broad `git diff`/`git show`, large JSON from issue trackers, logs, and validation output that was read directly into the main thread.

5. Apply the net-savings gate.
   A subagent candidate must have a clear burden removed from the main thread, a compact prompt, a compact expected output, cheap verification, low or bounded downside, and a decision that remains reserved for the main thread.

6. Score leverage.
   Mark each candidate as:
   - Strong leverage: should usually be delegated or tool-compressed next time.
   - Conditional leverage: useful only with clearer scope, better packet shape, or lower risk.
   - No leverage: main-thread execution was the right choice.
   - Tool-only win: no subagent needed; better tool usage would have saved context or cost.

7. Write better packets.
   For strong and conditional cases, write the packet that should have been used: task, scope, allowed files/search area, verification policy, output format, stop conditions, and what the main thread still owns.

8. Extract durable rules.
   Convert repeated findings into concise guidance for AGENTS instructions, custom agents, Superpowers overrides, or local workflow docs.

## Packet Types

Scout packet:
Use for read-heavy discovery, large-file scanning, stale-doc detection, reference extraction, or compact evidence gathering. Output should be file references, findings, risks, and next checks.

Patch packet:
Use for narrow, low-risk, verifiable edits from a clear spec. Output should be changed files, what changed, verification run, and uncertainty. Avoid broad refactors or hidden judgment.

Review packet:
Use for bounded diffs, specs, or test gaps. Output should be findings first, severity ordered, with file references. The reviewer should not rewrite code unless explicitly asked.

Tool packet:
Use when a deterministic command or MCP tool can process the raw context and return a compact result. Prefer this over subagents when reasoning is not the bottleneck.

Output-compression packet:
Use when the session returned large raw command output to the main thread. Measure output volume first, separating already-compressed tools such as `rtk` from raw commands. Prefer `ctx_batch_execute`, `ctx_execute_file`, narrower command scopes, Serena, or codebase-memory when they can return a compact derived answer without losing exactness needed for editing or review.

## Output Format

Use this structure for a session analysis:

```md
# Session Routing Postmortem: <session or work label>

## Summary
<What routing worked, what did not, and the highest-value changes for next time.>

## Strong Leverage Points
- Work unit:
- What happened:
- Better route:
- Packet:
- Expected savings:
- Verification:
- Risk:

## Conditional Leverage Points
...

## Tool-Only Wins
...

## No-Leverage Points
...

## Durable Rule Changes
...

## Follow-Up Improvements
...
```

## Improvement Loop

After each analysis, update this guide when there is a reusable lesson:

- Add packet shapes that worked.
- Add anti-patterns that looked cheap but increased total work.
- Clarify when Superpowers subagent workflows are worth their review cost.
- Note when main-thread tool use should replace a scout subagent.
- Refine output-volume heuristics; distinguish compressed command wrappers from genuinely token-heavy raw output.
- Note when a custom agent config, model route, or AGENTS instruction should change.

Prefer small edits with concrete examples over broad policy expansion. The guide should stay concise enough to use during real work.
