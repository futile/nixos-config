# Global Agent Guidance

These rules override conflicting skill guidance.

## Environment

- Before creating worktrees, avoid duplicate cold builds/downloads and preserve cache reuse.
- In `~/gits/nixpkgs`, use `~/nixos/bin/nix-build-sccached` instead of `nix build` when shared sccache applies; see `~/nixos/docs/nix-sccache.md`.

## Subagents

- Delegate only when parallelism or context isolation outweighs prompting and verification; otherwise use deterministic tools or the main thread.
- Use `gpt-5.6-luna` at `xhigh` for bounded, low-risk scanning, extraction, triage, and routine review; use `gpt-5.6-sol` for subtle, cross-cutting, consequential, or high-risk work. Preserve explicit model requests.
- Main thread owns final decisions and verification. Reuse agents only for the same role and scope.
- Prompts state goal, scope, constraints, expected evidence/output, and stop condition.

## Tools

- Prefer `rtk <command>` for noisy output; use raw commands when exact output matters. Optimize output volume, not command count.
- Use `rg` and file reads for exact text, docs, and configuration; Serena/CBM for symbolic or structural exploration; DeepWiki only for external orientation. Verify indexed or external claims against source.

## Context

- When reversible context tools are available and more work remains, batch-fold bulky completed work with a resume-quality summary. Keep instructions, the request, unresolved errors, active evidence, and soon-needed verbatim details live; skip maintenance near the final response.
