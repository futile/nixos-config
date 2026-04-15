---
name: avoiding-duplicate-builds-in-worktrees
description: Use when creating git worktrees, isolated workspaces, or subagent work areas where duplicated build outputs, caches, or dependency downloads could cause expensive cold rebuilds, repeated setup work, or wasted disk usage.
---

# Avoiding Duplicate Builds In Worktrees

## Overview

When an isolated workspace is about to be created, check whether the project's build artifacts or dependency caches should be shared instead of duplicated.

Core principle: ask before isolation becomes expensive.

## Required Behavior

Before creating a git worktree or other isolated workspace:

1. Identify the build system or package manager in use.
2. Check whether separate checkouts normally create separate build outputs or dependency state.
3. If duplicate state is likely to be expensive, ask the user whether they want sharing configured.
4. Apply ecosystem-specific setup only after the user agrees.
5. Verify the setup from inside the isolated workspace.

Do not assume the user wants hermetic isolation if faster iteration is the more likely goal. Ask.

## When Sharing Is Usually Worth Checking

Strongly consider asking when you see any of these:

- `Cargo.toml`
- `package.json`
- `pnpm-lock.yaml`
- `poetry.lock`
- `pyproject.toml`
- `go.mod`
- `CMakeLists.txt`
- `WORKSPACE`, `MODULE.bazel`, or `BUILD.bazel`
- large monorepos
- expensive code generation
- repeated dependency downloads
- prior evidence of slow cold builds

## Question To Ask

Use a direct question like:

`This worktree will likely create separate build outputs and may trigger expensive cold builds. Do you want me to configure shared build/cache paths before I create it?`

If helpful, mention the concrete artifact path you expect to duplicate.

## Rust / Cargo

If the project uses Cargo and the user wants shared build artifacts across worktrees:

1. Determine the main checkout root.
2. Use the main checkout's `target/` directory as the shared target dir.
3. Configure this in the main checkout's project-local `.codex/config.toml`.
4. Restart Codex before relying on the change.
5. Verify from inside a fresh worktree using a fresh subagent or fresh Codex session.

### Project-local Config

If `.codex/config.toml` does not exist, create it with:

```toml
[shell_environment_policy.set]
CARGO_TARGET_DIR = "/ABSOLUTE/PATH/TO/MAIN-CHECKOUT/target"
```

If `.codex/config.toml` already exists and already contains `[shell_environment_policy.set]`, add only this line inside that section:

```toml
CARGO_TARGET_DIR = "/ABSOLUTE/PATH/TO/MAIN-CHECKOUT/target"
```

If `.codex/config.toml` already exists but does not contain `[shell_environment_policy.set]`, append:

```toml
[shell_environment_policy.set]
CARGO_TARGET_DIR = "/ABSOLUTE/PATH/TO/MAIN-CHECKOUT/target"
```

Never add a duplicate `[shell_environment_policy.set]` section to the same TOML file.

### Restart Rule

After creating or changing `.codex/config.toml`, restart Codex before treating the configuration as active.

Important: subagents created before that restart may keep stale configuration. Do not use an old subagent as verification. Use a fresh worker or a fresh Codex process after restart.

### Verification

From inside the worktree, verify:

```bash
pwd
printf '%s\n' "${CARGO_TARGET_DIR-}"
test -w "$CARGO_TARGET_DIR" && echo writable || echo not-writable
```

If the target dir is intended to be writable, also verify an actual write probe, for example:

```bash
touch "$CARGO_TARGET_DIR/worktree-probe.foo"
```

Remove the probe file afterward if appropriate.

## Sandbox Check

If the shared build/cache path is inside the writable workspace already, extra sandbox configuration may not be needed.

If the shared path is outside the active workspace, check whether the sandbox needs an additional writable root. Ask the user before changing sandbox config.

## Worktree Interaction

If another worktree skill is in use, perform this build/cache decision before or during worktree setup, not afterward.

For project-local worktrees such as `.worktrees/...`, verification must happen from inside the worktree, not only from the main checkout.

## Common Mistakes

- Creating the worktree first and only later noticing cold rebuilds
- Assuming separate worktrees must use separate build outputs
- Forgetting to restart Codex after editing `.codex/config.toml`
- Trusting a subagent that was spawned before the restart
- Verifying only environment variables without verifying actual writability
- Adding a duplicate TOML section instead of extending the existing one

## Minimum Acceptable Verification

For any shared-build setup, report:

- the workspace path being used
- the shared artifact/cache path
- whether the environment variable is set in the isolated workspace
- whether a write probe succeeded
