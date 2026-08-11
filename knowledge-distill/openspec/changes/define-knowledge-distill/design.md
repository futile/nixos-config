## Context

The context-collapse extension already provides reversible, session-local movement between live messages and folded summaries. Durable project knowledge has different semantics: it is shared, curated, current-state documentation rather than colder transcript storage. The two systems should compose through page-in, collapse, and explicit write-back rather than pretending that a fold can be losslessly moved into documentation.

The repository is the collaboration boundary. Its knowledge state must be deterministically inspectable, but maintainers decide whether stale knowledge is blocked in pull requests, reported as warnings, checked manually, or temporarily accepted on the default branch. Full session archives are useful evidence but must remain optional.

## Goals / Non-Goals

**Goals:**

- Maintain a single-rooted hierarchy of concise, agent-facing project knowledge.
- Detect source changes that may invalidate existing knowledge, including new files in previously unclassified areas.
- Provide a policy-neutral check for stale fingerprints, malformed hierarchy, ambiguous ownership, and invalid links.
- Store lightweight reconciliation receipts in knowledge nodes using VCS-independent fingerprints.
- Propagate substantive child documentation changes upward without invalidating every ancestor for metadata-only changes.
- Track consulted knowledge across context folding and compaction, while keeping reads cheap and non-punitive.
- Allow agents to distill durable knowledge explicitly from live or folded context.
- Preserve selected complete sessions as optional, searchable provenance.

**Non-Goals:**

- Proving that a human or agent performed a thoughtful semantic review.
- Treating documentation as a lossless third context-storage tier.
- Requiring every search result or consulted node to be edited.
- Requiring session archival for normal knowledge creation or reconciliation.
- Providing live cross-clone locking or presence through Git.
- Requiring pull requests, blocking merges, or requiring the default branch to remain fully reconciled.

## Decisions

### Represent knowledge as a path hierarchy

A root Markdown node anchors the hierarchy. Directory index nodes parent nested index and leaf nodes, allowing paths to provide the primary hierarchy while Markdown links express cross-cutting relationships. Each node carries machine-readable metadata and human-readable knowledge.

The root node's `owned_files` patterns define the source universe covered by the knowledge system. This avoids a separate `knowledge_roots` concept and makes unmatched areas fall back naturally to the root.

### Separate ownership from relevance

Nodes declare two lists of file patterns:

- `owned_files`: participates in deepest-owner resolution. Each covered file has one deepest owner; equal-depth sibling matches are invalid.
- `related_files`: creates a non-owning dependency. Every matching node is affected, and overlap is allowed.

A changed file matched only by the root is reported as root-owned and unclassified, prompting reconciliation to create a child, assign it to an existing child, or affirm that root-level knowledge is sufficient.

### Persist source-state receipts as fingerprints

Each node stores VCS-independent fingerprints for:

- Files it directly owns after deepest-owner resolution.
- Files matching its `related_files` patterns.
- Its direct child knowledge nodes.

Source fingerprints use a versioned canonical SHA-256 projection of normalized patterns and sorted relative path/content entries. Knowledge files and machine-managed metadata are excluded from source projections, avoiding circular hashes.

A node is pending reconciliation whenever a stored fingerprint differs from its computed value. Reconciliation updates the prose when needed and then records the current fingerprints. Updating a fingerprint without changing prose is the lightweight `reviewed-no-change` receipt.

This model cannot prove semantic review, but it deterministically detects later source changes and remains valid across Git rebases, Jujutsu rewrites, or use without a VCS.

### Propagate substantive knowledge changes one level at a time

A node's child fingerprint includes the identity, hierarchy position, and semantic content hash of each direct child. Semantic hashing excludes machine-managed reconciliation fields.

Consequences:

- Updating only a child's source fingerprint does not invalidate its parent.
- Changing child prose or adding, removing, moving, or renaming a child invalidates the direct parent.
- A parent that remains accurate updates only its child fingerprint, stopping propagation.
- If parent prose changes, its semantic hash changes and reconciliation continues to the next ancestor.

This controlled bubbling prevents every source change from automatically reaching the root.

### Provide deterministic, policy-neutral checking

The checker recomputes fingerprints from the checked-out tree and validates hierarchy structure, ownership, and links to knowledge or repository files. It reports every mismatch in human-readable and machine-readable forms without assuming Git, branches, pull requests, or a special default branch.

Repositories may use the same result as a strict CI/PR gate, an advisory warning, a manual maintenance command, or information they intentionally ignore. Adding or modifying source after reconciliation still changes the computed fingerprint and reopens the node automatically; whether that state blocks collaboration is repository policy.

### Treat knowledge reads as page-ins, not hard invalidations

`knowledge_read` records the node and its content hash in extension/session state. This consulted set survives context collapse, compaction, and session resume. Folded content remains recoverable using the existing context tools.

Consultation is a soft reconciliation prompt, not by itself a deterministic check failure. `knowledge_search` does not mark returned nodes. Hard reconciliation candidates come from fingerprint mismatches or an explicit affected-node signal. This avoids incentivizing agents to bypass the knowledge tools.

`knowledge_distill` is an explicit semantic promotion from one or more live/folded ranges into selected knowledge nodes. It is not an automatic archive operation.

### Keep session archives as a separate evidence corpus

An explicit archive operation writes an immutable raw transcript plus a concise searchable summary and links to relevant knowledge nodes, source files, commits when available, and outcomes. Knowledge nodes may link back to exact session ranges.

The curated hierarchy remains authoritative. Session archives are sparse evidence records and form a linked corpus rather than being forced into the knowledge tree. Search begins with repository text search; derived indexes remain disposable.

## Risks / Trade-offs

- **Fingerprint updates become rubber stamps** → Keep reconciliation agent-visible, require explicit dispositions, and rely on review for semantic quality.
- **Broad ownership creates metadata churn** → Use deepest direct ownership and refine large root-owned areas into children as value emerges.
- **Parent reconciliation becomes noisy for trivial prose edits** → Start with deterministic semantic content hashes; consider a designated exported-summary section only if measured churn warrants it.
- **Overlapping patterns create surprising ownership** → Reject equal-depth ownership ambiguity and provide an explain command showing why a node owns or relates to a file.
- **Pattern or hashing changes invalidate many nodes** → Version the fingerprint algorithm and provide an explicit migration command.
- **Complete sessions leak secrets or bloat Git** → Keep archival explicit and add a review/redaction and size gate before committing archives.
- **Sparse archives weaken provenance** → Treat source references, tests, and Git history as sufficient; archives are optional enrichment.

## Migration Plan

1. Define and validate the node metadata and hierarchy format.
2. Create the root knowledge node with a deliberately narrow initial `owned_files` scope.
3. Compute initial fingerprints and reconcile the first hierarchy manually.
4. Add local status and reconciliation commands.
5. Document optional manual, advisory, and strict CI/PR uses of the checker.
6. Add context-tool integration and optional session archival independently.

Rollback consists of disabling any repository-specific automation while retaining the checker and ordinary Markdown documentation; no source code depends on enforcement policy.

## Open Questions

- Whether and how ownership, relevance, and fingerprints should treat symlinks.
- The exact canonical fingerprint encoding and treatment of file modes and binary content.
- Whether parent propagation should eventually hash a designated summary section rather than all semantic prose.
- How explicit conceptual obligations without file dependencies should be persisted across collaborators.
- The archive format, redaction policy, and size threshold for complete sessions.
