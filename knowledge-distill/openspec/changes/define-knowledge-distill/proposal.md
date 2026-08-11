## Why

AI agents repeatedly rediscover project structure, decisions, and debugging knowledge because active context is temporary while repository documentation lacks a systematic write-back mechanism. The project needs shared, hierarchical agent-facing knowledge that can be paged into context, reconciled against source changes, and checked deterministically without imposing a particular collaboration workflow.

## What Changes

- Add a repository-owned hierarchy of concise knowledge nodes for AI agents.
- Associate source files with their deepest owning knowledge node through `owned_files`, with non-owning cross-cutting dependencies through `related_files`.
- Detect stale knowledge using VCS-independent source and child-content fingerprints.
- Reconcile current source state with leaf knowledge nodes and propagate substantive documentation changes toward the root.
- Integrate knowledge reads with context collapsing without treating durable knowledge as merely colder conversation history.
- Permit explicit, optional archival of complete agent sessions as searchable evidence linked from knowledge nodes.

## Capabilities

### New Capabilities

- `project-knowledge`: Hierarchical knowledge nodes, source ownership, fingerprints, reconciliation, context paging, and deterministic validation.
- `session-archive`: Explicit archival and retrieval of complete agent sessions as optional provenance.

### Modified Capabilities

None.

## Impact

- Adds a new repository-local knowledge format and validation/reconciliation tooling.
- Adds agent tools or extension hooks for reading, tracking, distilling, and reconciling knowledge.
- Adds a policy-neutral CLI check suitable for manual use, advisory warnings, or optional strict PR/CI enforcement.
- Adds optional storage and search conventions for archived sessions; normal knowledge operation does not depend on archives.
