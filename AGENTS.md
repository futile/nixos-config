# Repository Guidelines

## Project Structure & Module Organization
`flake.nix` is the entrypoint for all systems and exposes the shared formatter. Put machine-specific configuration in `hosts/` (`nixos-home/`, `nixos-work/`, `hm-cf/`). Keep reusable NixOS modules in `modules/` and reusable Home Manager modules in `home-modules/`. Store application config under `dotfiles/`, helper executables in `bin/`, non-PATH automation in `scripts/`, and ad hoc project dev flakes in `project-flakes/`. Use `docs/` for contributor-facing reference material such as [`docs/macos-permissions.md`](docs/macos-permissions.md).

Treat `hosts/hm-cf/` as macOS-only. Do not change `hm-cf` files unless the task is explicitly for a macOS device or macOS-specific behavior.

## Build, Test, and Development Commands
Prefer `just` recipes over ad hoc commands:

- `just check`: run `nix flake check` for repository-level evaluation.
- `just build`: build the current host system to `./result` without switching.
- `just switch`: apply the current NixOS configuration on Linux.
- `just hm-build` / `just hm-switch`: build or switch the standalone Home Manager config.
- `just format`: run `nix fmt` and format the `justfile`.
- `just format-check`: fail if formatting is not clean.

Use `just --list --unsorted` to discover less common workflows such as `dry-activate` or macOS permission setup.

When running Nix evaluation or build commands directly, lower their CPU scheduling priority with `nice -n 19`, for example `nice -n 19 nix build .#headroom --no-link`. Prefer the same treatment for noisy `just` recipes that mostly wrap Nix builds or checks.

## Codebase Memory
This repo may be indexed by codebase-memory-mcp as `home-felix-nixos`.

Useful commands:

```sh
codebase-memory-mcp cli list_projects '{}'
codebase-memory-mcp cli index_status '{"project":"home-felix-nixos"}'
codebase-memory-mcp cli get_architecture '{"project":"home-felix-nixos","aspects":["all"]}'
codebase-memory-mcp cli search_code '{"project":"home-felix-nixos","pattern":"codex-token-optimization","mode":"compact","limit":10}'
```

Use CBM as an auxiliary index here, not as the main source of truth for Nix semantics. It helps with repo inventory, docs/config search, and TOML/Lua/Bash structure, but does not deeply model Nix module dependencies or option evaluation.

For Nix files, exact options, module wiring, paths, and config values, prefer `rg`, `nix eval`, and normal file reads. If CBM output conflicts with source files or Nix evaluation, source/eval wins.

## Coding Style & Naming Conventions
Nix code is formatted with the flake formatter (`nixfmt-tree`); run `just format` before submitting changes. Follow existing naming patterns: host directories use machine names, reusable modules use descriptive kebab-case filenames such as `desktop-common.nix`, and keep related logic grouped by domain instead of by tool. Match the surrounding file’s indentation and comment style. Prefer small, composable modules over host-local duplication.

## Testing Guidelines
There is no standalone unit test suite here; validation is configuration-focused. At minimum, run `just format-check` and `just check`. For host-specific changes, also run the relevant build path: `just build` for the current Linux host or `just hm-build` for `hosts/hm-cf`. When a change affects activation behavior, include the exact command you used to verify it.

## Commit & Pull Request Guidelines
Recent commits follow a scoped style such as `hm-cf: Add touch-id support for sudo` or `docs: Move current AGENTS.md...`. Use `scope: imperative summary`, with multiple scopes when needed (`hm-cf,docs:`). Keep commits narrowly focused. Pull requests should state which host or module is affected, list validation commands run, and include screenshots only for UI-facing dotfile changes (Waybar, Neovim, WezTerm, etc.). Link any relevant issue or setup note when the change depends on manual steps.


<!-- BEGIN BEADS INTEGRATION v:1 profile:full hash:f65d5d33 -->
## Issue Tracking with bd (beads)

**IMPORTANT**: This project uses **bd (beads)** for ALL issue tracking. Do NOT use markdown TODOs, task lists, or other tracking methods.

### Why bd?

- Dependency-aware: Track blockers and relationships between issues
- Git-friendly: Dolt-powered version control with native sync
- Agent-optimized: JSON output, ready work detection, discovered-from links
- Prevents duplicate tracking systems and confusion

### Quick Start

**Check for ready work:**

```bash
bd ready --json
```

**Create new issues:**

```bash
bd create "Issue title" --description="Detailed context" -t bug|feature|task -p 0-4 --json
bd create "Issue title" --description="What this issue is about" -p 1 --deps discovered-from:bd-123 --json
```

**Claim and update:**

```bash
bd update <id> --claim --json
bd update bd-42 --priority 1 --json
```

**Complete work:**

```bash
bd close bd-42 --reason "Completed" --json
```

### Issue Types

- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature with subtasks
- `chore` - Maintenance (dependencies, tooling)

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

### Workflow for AI Agents

1. **Check ready work**: `bd ready` shows unblocked issues
2. **Claim your task atomically**: `bd update <id> --claim`
3. **Work on it**: Implement, test, document
4. **Discover new work?** Create linked issue:
   - `bd create "Found bug" --description="Details about what was found" -p 1 --deps discovered-from:<parent-id>`
5. **Complete**: `bd close <id> --reason "Done"`

### Quality
- Use `--acceptance` and `--design` fields when creating issues
- Use `--validate` to check description completeness

### Lifecycle
- `bd defer <id>` / `bd supersede <id>` for issue management
- `bd stale` / `bd orphans` / `bd lint` for hygiene
- `bd human <id>` to flag for human decisions
- `bd formula list` / `bd mol pour <name>` for structured workflows

### Auto-Sync

bd automatically syncs via Dolt:

- Each write auto-commits to Dolt history
- Use `bd dolt push`/`bd dolt pull` for remote sync
- No manual export/import needed!

### Important Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic use
- ✅ Link discovered work with `discovered-from` dependencies
- ✅ Check `bd ready` before asking "what should I work on?"
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT use external issue trackers
- ❌ Do NOT duplicate tracking systems

For more details, see README.md and docs/QUICKSTART.md.

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds

<!-- END BEADS INTEGRATION -->
