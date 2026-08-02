You are reviewing downstream changes made to Felix Dietze’s Pi subagents/context extensions.
Treat the downstream patches as a tested behavioral specification, not as patches that should necessarily be applied verbatim.
Compare them with the current upstream source and redesign/refactor where appropriate.

Repository:
https://github.com/futile/nixos-config
Branch: main

The downstream configuration was built against fdietze source revision:

177de6af6a16da10670d488264dd8c27051b4ae3

Relevant git ranges:

- Full Pi research/setup history:
  27592c9^..876ab64
- More focused lifecycle and follow-up patch history:
  87c497d^..876ab64

The latter includes a few small Pi settings/statusline changes, but contains all extension patch work.

Useful commands:

     git log --reverse --oneline 27592c9^..876ab64
     git diff 87c497d^..876ab64 -- \
       home-modules/pi.nix \
       patches/fdietze-pi-subagents-child-extensions.patch \
       patches/fdietze-pi-subagents-thinking-level.patch \
       patches/fdietze-pi-subagents-pause-state.patch

## Relevant repository files

Primary research and implementation:

- docs/pi-agent-setup-research.md
- home-modules/pi.nix
- patches/fdietze-pi-subagents-child-extensions.patch
- patches/fdietze-pi-subagents-thinking-level.patch
- patches/fdietze-pi-subagents-pause-state.patch
- flake.nix
- flake.lock

The three patches apply sequentially in exactly this order:

1.  fdietze-pi-subagents-child-extensions.patch
2.  fdietze-pi-subagents-thinking-level.patch
3.  fdietze-pi-subagents-pause-state.patch

Personal setup surrounding the extension:

- dotfiles/pi/hosts/nixos-work/settings.json
- dotfiles/pi/hosts/nixos-work/mcp.json
- modules/searxng-local.nix
- dotfiles/codex/AGENTS.source.md
- dotfiles/codex/AGENTS.md
- dotfiles/kitty/kitty.conf

## Concise overview of downstream extension changes

### 1. Child extension lifecycle and settings isolation

`fdietze-pi-subagents-child-extensions.patch`:

- Supplies an explicit allowlist of extensions to SDK-created children.
- Calls `session.bindExtensions({ mode: "print" })`, because registering extension tools alone did not emit `session_start`. Without this, lifecycle-dependent extensions such as `pi-mcp-adapter` returned `MCP not initialized`.
- Replaces persistent `session.setSteeringMode("all")` with an in-memory `SettingsManager.applyOverrides(...)`, preventing children from rewriting the shared foreground `settings.json`.
- Adds ordered, idempotent child cleanup:
  abort → emit `session_shutdown` → dispose.
- Makes `kill` and `killAll` asynchronous and waits for resource cleanup.
- Separates semantic deletion from runtime shutdown:
  - Explicit kill removes roster membership.
  - Pi quit/session replacement closes child resources but preserves JSONL/roster data for restoration.
  - `/reload` preserves live child runtimes.
- Detaches lifecycle subscriptions during cleanup.
- Adds regression tests for cleanup and persistence semantics.

### 2. Thinking/reasoning-level control and visibility

`fdietze-pi-subagents-thinking-level.patch`:

- Adds optional `overrideThinkingLevel` to `spawn_agent`.
- Inherits both model and effective thinking level from the spawning agent when omitted.
- Passes the requested level to `createAgentSession`; Pi remains responsible for capability clamping.
- Records the effective clamped level in `AgentRecord`.
- Displays `model@thinking-level` in spawn results, `list_agents`, status/widget, and agent panel.
- Persists a validated optional thinking level in `roster.json`, including children that have not yet produced a JSONL thinking-level event.
- Restores the persisted level into SDK session creation.
- Updates tool wording so agents consult active AGENTS/model-routing policy rather than treating model inheritance as universally preferable.
- Bumps the global engine singleton version because the stored object shape changed.
- Adds persistence, inheritance, formatting, and validation tests.

We intentionally did not implement migration between temporary downstream singleton versions v11 and v12. A polished upstream implementation may want a real versioned reload/migration strategy.

### 3. Accurate paused/restored-swarm UX

`fdietze-pi-subagents-pause-state.patch`:

- Makes global frozen/restored state visible as `PAUSED`.
- Explains that messages are being buffered until `resume_agents`.
- Preserves route outcomes so `send_message` reports `buffered` instead of falsely reporting `sent`.
- Uses consistent `buffered (paused)` wording.
- Makes `resume_agents` report:
  - that the paused swarm was resumed,
  - that the budget was re-armed,
  - how many buffered messages were delivered,
  - how many halted agents were retriggered.
- Adds focused feed/engine/spawner tests.

## Validation performed downstream

The final sequentially patched source passed:

- 118/118 source tests
- strict sequential patch application with `--fuzz=0`
- Home Manager build and activation
- `just format-check`

Live verification included:

- Concurrent child web and MCP use.
- A real child DeepWiki MCP call, with no `MCP not initialized`.
- SearXNG search and web fetch from a child.
- Stable shared `settings.json` checksum across spawn/use/kill.
- No remaining child-owned MCP helper after kill.
- `/reload` child continuity.
- Quit/restart JSONL and roster restoration.
- Explicit Luna/xhigh spawn with effective effort shown in spawn/list/roster.
- Persistence of effort for a child with no messages yet.
- Accurate paused → buffered → resume behavior.
- Empty final roster.

The repository-wide `just check` remained blocked by an unrelated known insecure `pnpm-9.15.9` dependency in another package.

## Likely general/upstream-worthy changes

These appear broadly applicable:

1.  Explicitly binding SDK child extensions so they receive lifecycle events.
2.  Preventing child sessions from persisting runtime overrides into shared settings.
3.  Awaited and ordered child extension teardown.
4.  Separating runtime shutdown from semantic agent deletion/persistence.
5.  Optional per-child thinking-level override and parent inheritance.
6.  Displaying the effective clamped thinking level.
7.  Persisting initial model/thinking metadata even before the first child message.
8.  Making global paused state and buffered route outcomes explicit.
9.  Typed/structured resume results instead of ambiguous prose.
10. Integration tests covering child extension start, shutdown, reload, restoration, and settings isolation.

## Probably personal/setup-specific

These should not be upstreamed literally:

- The Nix patching and store-path substitution.
- The exact pinned revisions and npm package versions.
- The hardcoded child allowlist:
  - `pi-mcp-adapter`
  - `rpiv-web-tools`
  - this checkout’s `context-prune`
- SearXNG, DeepWiki, Serena, and codebase-memory choices.
- The specific Luna/xhigh versus Sol routing policy.
- The global AGENTS wording used to enforce that policy.
- The Kitty notification filter.
- The exact singleton version numbers used during downstream development.
- Any host-specific settings under `dotfiles/pi/hosts/nixos-work/`.

## More general solutions worth considering upstream

We used smaller downstream fixes because these broader solutions were excessive for one personal setup, but they may be better upstream designs:

1.  **Configurable child-extension policy**
    - Accept an audited extension list or policy callback instead of hardcoded paths.
    - Potentially distinguish child-safe extensions through metadata/capabilities.
    - Keep recursive extension discovery disabled by default.

2.  **Managed SDK child lifecycle**
    - Add a public SDK abstraction that performs bind/start/shutdown/dispose correctly.
    - Avoid requiring extensions to call `session.extensionRunner.emit(...)` directly.
    - Propagate the real shutdown reason instead of always synthesizing `quit`.

3.  **Ephemeral settings scopes**
    - Give SDK sessions a first-class in-memory settings layer.
    - Runtime changes should be non-persistent unless persistence is explicitly requested.

4.  **Typed scheduler state**
    - Model running/paused/restored/budget-exhausted states explicitly.
    - Return typed route outcomes such as delivered, buffered, busy, or unknown.
    - Let UI and tools format those states rather than inferring meaning from strings.

5.  **Versioned reload migration**
    - Replace global singleton key bumps with a migration/teardown protocol.
    - Ensure an extension upgrade cannot leave an old engine or child runtime unreachable.

6.  **Generic model-routing hook**
    - Allow a routing callback to select model and thinking level from task metadata, parent state, and policy.
    - Keep provider/model-specific guidance out of the extension itself.

7.  **Initial session metadata persistence**
    - Persist initial model and thinking level in the Pi session header or SDK session metadata immediately.
    - This would avoid duplicating initial effort metadata in the subagent roster solely for never-messaged sessions.

8.  **Optional shared MCP management**
    - If many children use MCP, consider a safe shared/poolable MCP layer rather than one helper lifecycle per child.
    - Isolation may still be preferable, so this should remain optional.

9.  **Context-prune pressure assistance**
    - Our local solution added global phase-boundary instructions because pruning is currently agent-driven.
    - Upstream could provide non-invasive pressure reminders or phase hooks without automatically folding semantically important content.

10. **Pi/terminal OSC fix**
    - Pi’s OSC 133 chat zones caused Kitty to interpret blank pseudo-commands as completed shell commands.
    - We filtered the exact blank notification in Kitty.
    - A better general fix may be in Pi’s OSC semantics or Kitty integration so chat rendering cannot trigger command-completion notifications.

## Requested outcome

Please:

1.  Compare these behaviors with current upstream HEAD.
2.  Identify which problems still exist upstream.
3.  Treat the three patches as behavior/test evidence, not mandatory implementation structure.
4.  Recommend a clean upstream PR split—likely lifecycle/settings, thinking-level support, and pause-state UX.
5.  Note any Pi SDK API improvements that would remove extension-level workarounds.
6.  Preserve or improve the regression tests.
7.  Report compatibility risks, especially around reload, restored sessions, nested children, and extension cleanup.
8.  Keep personal Nix, MCP, model-routing, Kitty, and host configuration out of upstream changes unless used only as motivating examples.
