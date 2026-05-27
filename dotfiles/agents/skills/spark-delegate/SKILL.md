---
name: spark-delegate
description: Use only when the user explicitly prefixes a prompt with `s:` or `spark:` or asks to delegate a tiny bounded edit to the Spark worker.
---

# Spark Delegate

Use this skill for explicit low-latency delegation to the `spark_worker` custom agent.

## Trigger

Use only when the user clearly opts in:

- Prompt starts with `s:`
- Prompt starts with `spark:`
- User explicitly asks to use the Spark worker for a tiny bounded edit

Do not use for broad refactors, architectural decisions, ambiguous behavior changes, security-sensitive work, or tasks that need careful multi-file reasoning.

## Workflow

1. Strip the `s:` or `spark:` prefix.
2. Decide whether the task is small and bounded enough for `spark_worker`.
   - If not, handle it in the main session and briefly say why.
3. Decide the verification policy before delegation.
   - Explicitly decide whether the worker is allowed to run tests, linting, formatting checks, builds, or other verification.
   - Include specific commands or test scope when obvious.
   - If the worker should decide, say that explicitly and constrain it to the smallest useful check.
   - If no verification should run, say that explicitly and why.
4. Spawn or reuse `spark_worker`.
   - Prefer reusing an existing `spark_worker` thread when it is relevant and not stale.
   - Spawn a fresh `spark_worker` with current context when the task depends on the current conversation or the existing worker is stale.
5. Send a compact worker prompt with:
   - task
   - write scope or target files/symbols if known
   - verification policy
   - instruction to stop after the bounded edit
6. Wait for tiny edits unless the user asks for async work.
7. Review the worker result at a high level before reporting.

## Worker Prompt Shape

Keep worker prompts compact:

```text
Task: <stripped user request>
Scope: <known files/symbols, or "infer the narrowest safe scope">
Verification: <allowed commands, worker-decides-smallest-useful-check, or no verification>
Constraints: tiny bounded edit only; no unrelated refactors; stop and ask if ambiguous.
```

## Parent Response

Keep the main response terse. Report:

- whether Spark was used
- changed files
- verification run or intentionally skipped
- any uncertainty or follow-up needed
