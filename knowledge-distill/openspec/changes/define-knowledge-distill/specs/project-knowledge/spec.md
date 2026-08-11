## ADDED Requirements

### Requirement: Hierarchical knowledge nodes
The system SHALL maintain repository-shared agent knowledge as a single-rooted hierarchy of Markdown nodes whose filesystem positions determine their parent-child relationships.

#### Scenario: Agent navigates from root to detail
- **WHEN** an agent requests the knowledge map
- **THEN** the system presents the root and its descendants in hierarchy order with stable node identifiers

#### Scenario: Hierarchy is malformed
- **WHEN** a node has no resolvable parent or the hierarchy contains conflicting node identities
- **THEN** validation fails with the affected paths and required correction

### Requirement: Root-defined source coverage
The root node's `owned_files` patterns SHALL define the source-file universe covered by the knowledge hierarchy.

#### Scenario: Changed file is outside root coverage
- **WHEN** a changed file matches none of the root node's `owned_files` patterns
- **THEN** the knowledge check creates no source-triggered reconciliation candidate for that file

#### Scenario: New file has no descendant owner
- **WHEN** a new file matches the root node but no descendant node's `owned_files`
- **THEN** the root becomes pending and the system identifies the file as root-owned and unclassified

### Requirement: Deepest file ownership
For every covered file, the system SHALL assign ownership to the deepest matching node according to `owned_files` and SHALL reject ambiguous equal-depth ownership.

#### Scenario: Child and root both match
- **WHEN** a source file matches both the root and a descendant node
- **THEN** only the deepest matching descendant owns that file

#### Scenario: Sibling ownership conflicts
- **WHEN** two nodes at the same hierarchy depth both claim a file through `owned_files`
- **THEN** validation fails and reports both nodes and the conflicting file

### Requirement: Non-owning file relationships
The system SHALL allow `related_files` patterns to trigger reconciliation without changing deepest-owner assignment, and SHALL allow a file to relate to multiple nodes.

#### Scenario: Owned file also affects cross-cutting knowledge
- **WHEN** a changed file is owned by one node and matches `related_files` on two other nodes
- **THEN** the owner and both related nodes become reconciliation candidates

### Requirement: VCS-independent source reconciliation
Each node SHALL store versioned, VCS-independent fingerprints of its directly owned files and related files, and validation SHALL mark the node pending when a stored fingerprint differs from the current filesystem projection.

#### Scenario: Owned source changes after reconciliation
- **WHEN** the content, path, addition, or removal of a directly owned file changes
- **THEN** the owner's computed fingerprint differs and the node becomes pending

#### Scenario: Reconciliation finds documentation unchanged
- **WHEN** an agent reviews a pending node and determines its knowledge remains accurate
- **THEN** the system can update only the stored fingerprint as a `reviewed-no-change` receipt

#### Scenario: Source changes again
- **WHEN** relevant source changes after a receipt was recorded
- **THEN** the fingerprint mismatch automatically reopens reconciliation

### Requirement: Controlled parent reconciliation
Each parent SHALL track the identity, hierarchy position, and semantic content of its direct children while excluding machine-managed reconciliation metadata from semantic hashing.

#### Scenario: Child receipt changes without prose changes
- **WHEN** only a child's machine-managed fingerprint fields change
- **THEN** the parent remains reconciled

#### Scenario: Child knowledge changes substantively
- **WHEN** a child's semantic content changes or a child is added, removed, moved, or renamed
- **THEN** the direct parent's child fingerprint differs and the parent becomes pending

#### Scenario: Parent summary remains accurate
- **WHEN** the parent is reconciled after a child change and its prose needs no change
- **THEN** only the parent's child fingerprint is updated and no further ancestor becomes pending

#### Scenario: Parent summary changes
- **WHEN** parent prose is updated during reconciliation
- **THEN** its semantic hash changes and its direct parent becomes pending

### Requirement: Deterministic knowledge check
The system SHALL provide a policy-neutral, VCS-independent check that reports fingerprint mismatches, malformed hierarchy, ambiguous ownership, and invalid links in human-readable and machine-readable forms.

#### Scenario: Current tree contains pending knowledge
- **WHEN** the check runs with unreconciled source or child changes
- **THEN** it lists every pending node with its triggering files or children

#### Scenario: Knowledge or file link is invalid
- **WHEN** a knowledge node links to a missing knowledge node or repository file
- **THEN** the check reports the source node and invalid target

#### Scenario: Repository chooses strict automation
- **WHEN** the check is invoked in strict mode and finds any validation issue
- **THEN** it returns a failing status suitable for optional CI or pull-request enforcement

#### Scenario: Repository chooses advisory operation
- **WHEN** the check is invoked in advisory mode and finds stale knowledge
- **THEN** it reports warnings without itself preventing commits, pushes, or integration

#### Scenario: Current tree is fully reconciled
- **WHEN** every stored fingerprint matches and all structural and link invariants are valid
- **THEN** the check reports zero pending reconciliation entries

### Requirement: Context-compatible knowledge reads
The system SHALL page knowledge nodes into active agent context while recording consulted node identity and content hash in state that survives folding, compaction, and session resume.

#### Scenario: Read result is folded
- **WHEN** an agent reads a node and later collapses the corresponding messages
- **THEN** the consulted-node record remains available for later reconciliation

#### Scenario: Search returns incidental matches
- **WHEN** an agent searches knowledge without opening a result
- **THEN** the returned nodes do not become hard reconciliation obligations

#### Scenario: Knowledge tooling is bypassed
- **WHEN** source changes are made without any knowledge read
- **THEN** source fingerprint validation still detects affected nodes

### Requirement: Explicit knowledge distillation
The system SHALL allow an agent to explicitly distill durable claims from one or more live or folded context ranges into selected knowledge nodes.

#### Scenario: Fold contains reusable project knowledge
- **WHEN** an agent identifies durable findings in a fold and selects target knowledge nodes
- **THEN** the system supports updating those nodes while retaining the fold or source session only as optional provenance

#### Scenario: Fold is merely old context
- **WHEN** content is collapsed without an explicit distillation action
- **THEN** the system does not copy the fold summary into shared project knowledge
