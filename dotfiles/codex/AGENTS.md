# Global Agent Guidance

These rules override conflicting skill guidance.

## Environment

- Before creating worktrees, avoid duplicate cold builds/downloads and preserve cache reuse.
- In `~/gits/nixpkgs`, use `~/nixos/bin/nix-build-sccached` instead of `nix build` when shared sccache applies; see `~/nixos/docs/nix-sccache.md`.

## Subagents

- Delegate only when parallelism or context isolation outweighs prompting and verification; otherwise use deterministic tools or the main thread.
- In Pi, pass provider-qualified subagent model IDs: use `openai-codex/gpt-5.6-luna` at `xhigh` for bounded, low-risk scanning, extraction, triage, and routine review; use `openai-codex/gpt-5.6-sol` for subtle, cross-cutting, consequential, or high-risk work. The provider is `openai-codex`, not `openai`. Preserve explicit model requests.
- Always include the initial task in `spawn_agent.message`. A system prompt alone only defines the role; without a first message the agent starts idle and does no work. After the agent acknowledges the task and asks clarifying questions, send an explicit go-ahead with answers or reasonable defaults.
- Main thread owns final decisions and verification. Reuse agents only for the same role and scope.
- Prompts state goal, scope, constraints, expected evidence/output, and stop condition.

## Tools

- Prefer `rtk <command>` for noisy output; use raw commands when exact output matters. Optimize output volume, not command count.
- Use `rg` and file reads for exact text, docs, and configuration; use Serena/CBM for symbolic or structural exploration.
- Use DeepWiki early when investigating an unfamiliar GitHub-hosted dependency or relevant upstream/reference project. “Unfamiliar” means the relevant execution path, subsystem boundaries, or responsible source symbols have not already been established in the current session.
- DeepWiki is especially useful for architecture, subsystem relationships, implementation concepts, locating likely source files/symbols, and finding upstream patterns, examples, and tests that may inform a project-specific implementation.
- Treat DeepWiki output as orientation and candidate design input, not final evidence or a locally approved design. Verify consequential behavior against the pinned dependency version, upstream source, or official documentation, and check proposed patterns against the local codebase, requirements, and conventions before adopting them.
- Prefer exact source lookup when the relevant symbol/path is already known. Prefer official docs or web search for supported public APIs, compatibility guarantees, current releases, and other version-sensitive claims.

## Context

When reversible context-editing tools are available:

- Treat phase boundaries, the point before final verification, and completed batches within a long exploration, debugging, implementation, or verification phase as context-maintenance checkpoints. During a long phase, reassess after several large tool results; do not wait for phase end or automatic compaction.
- A checkpoint requires judgment, not necessarily a `context_map` call or a fold. Material being safe to fold is not by itself enough reason to fold it, and a no-op assessment satisfies the checkpoint _if_ there is not enough worth folding.
- Fold when there is meaningful completed or superseded bulk and either enough subsequent model/tool work is likely to reuse the smaller context, or context-window or quality pressure justifies immediate maintenance.
- Prefer to piggy-back maintenance on an already-required tool loop.
- When maintenance is worthwhile, orient with `context_map` and batch-collapse bulky reads, logs, compiler or test output, rejected approaches, and completed details after capturing their conclusions in a resume-quality summary. Prefer one useful batch over folding small items individually.
- Keep governing instructions, the active user request, unresolved errors, active evidence, open decisions, and information needed verbatim for upcoming work live.
- A recent successful maintenance pass satisfies later phase-end checkpoints unless substantial new foldable bulk has accumulated. Interpret “collapse immediately once a topic closes” as “assess promptly and batch-collapse when worthwhile,” not as a requirement to fold every completed item.
