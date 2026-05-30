# Memory Maintenance

## Discovery Model

- Core principle: progressive discovery through references, building a graph of memories.
- Initially, agents are provided with the list of all memories (names only).
- Agents should read `mem:core` as the top-level entry point (graph root).
  This memory should contain references to other memories covering major project domains.
  The referenced memories shall, in turn, shall contain references to even more specific memories, and so on.
  The depth of the graph shall depend on the project complexity.
- Use topics/folders to group related memories in order to make the content structure explicit.
  Folders can mirror project structure (e.g. modules like frontend/backend) or topics like debugging, architecture, etc.
- Memory references must use a mem: prefix inside backticks, e.g. `mem:frontend/core`.
  The surrounding text should clearly indicate when to read the memory/which content to expect.
  The text should provide more precise guidance than the memory name alone, 
  i.e. avoid a reference like "frontend debugging: `mem:frontend/debugging` and instead make clear which aspects of frontend debugging are covered.
- Memories themselves should not contain information about when to read them; this is the responsibility of the referring memory.

## Style

Dense agent notes, not prose docs. Prefer invariants, terse bullets. 
Avoid obvious context, rationale, and examples unless they prevent likely mistakes. 
Keep guidance durable and generalizable, not task-local.

## Add/update threshold

Add or update memories only with stable, non-obvious project conventions that avoid complex rediscovery in the future.
Do not add: quick-read facts; generic language/framework knowledge; one-off task notes; volatile line-level details; behavior likely to change soon.

## Memory Admission Test

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