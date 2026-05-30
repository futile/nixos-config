# Memory Admission Test

Before writing or updating a memory, classify the candidate note.

Keep if it is:
- Durable: likely true for months, not tied to a just-completed edit.
- Non-obvious: future agents would otherwise need real investigation to rediscover it.
- Reusable: applies across multiple likely tasks, not just one file/line/change.
- Operational: changes how agents should search, edit, validate, or avoid mistakes.
- Project-specific: more specific than generic language/tool knowledge.

Drop or keep only in the final response if it is:
- A line number, current file state, or just-observed diff.
- A one-off task outcome.
- A temporary workaround or stale-risk observation.
- An example that can be replaced by a more general rule.
- Generic tool behavior that is not specific to this repo.

When in doubt:
- Generalize examples into a rule.
- Store the rule, not the example.
- Prefer durable guidance like "Serena Nix references may be incomplete; use pattern search for option usage" over a one-off failing option path.

## Update Workflow

When proposing a memory update:
1. State the candidate memory text.
2. State why it passes the admission test.
3. State what was intentionally excluded as too specific.
4. Ask before writing unless the user explicitly requested memory mutation.

## Maintenance Actions

- Renaming memories: References are updated automatically if handled via Serena's memory rename tool.
- Checking for stale memories (e.g. after deletion): Call `serena memories check` for a report.