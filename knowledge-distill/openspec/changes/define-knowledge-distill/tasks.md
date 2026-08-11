## 1. Knowledge Format

- [ ] 1.1 Define the root, directory-index, and leaf-node layout with machine-readable metadata validation.
- [ ] 1.2 Specify glob syntax and exclusion rules for `owned_files` and `related_files`.
- [ ] 1.3 Resolve symlink, file-mode, and binary-content behavior before fixing the canonical fingerprint format.
- [ ] 1.4 Implement versioned semantic, owned-file, related-file, and direct-child SHA-256 fingerprints.

## 2. Ownership and Validation

- [ ] 2.1 Implement deepest-owner resolution with root fallback and equal-depth ambiguity errors.
- [ ] 2.2 Implement overlapping non-owning `related_files` matching.
- [ ] 2.3 Report root-owned unclassified additions as possible new knowledge areas.
- [ ] 2.4 Add an explain command showing why each file owns, relates to, or invalidates a node.
- [ ] 2.5 Add deterministic tests for additions, removals, renames, mapping changes, ambiguity, and child propagation.

## 3. Reconciliation Workflow

- [ ] 3.1 Implement status output that distinguishes structural errors, source mismatches, child mismatches, and soft consulted nodes.
- [ ] 3.2 Implement reconciliation that patches node prose or records a reviewed-no-change fingerprint receipt.
- [ ] 3.3 Ensure later source changes invalidate earlier receipts and metadata-only child changes do not propagate upward.
- [ ] 3.4 Add a merge-gate command that succeeds only when every node and hierarchy invariant is reconciled.

## 4. Agent Context Integration

- [ ] 4.1 Implement knowledge map, search, and read tools with concise progressive-disclosure output.
- [ ] 4.2 Persist consulted-node identities and hashes across folds, compaction, session resume, and tree navigation.
- [ ] 4.3 Present consulted nodes as soft reconciliation prompts without making searches or reads hard merge obligations.
- [ ] 4.4 Implement explicit distillation from selected live or folded context into one or more knowledge nodes.
- [ ] 4.5 Verify source validation still catches impacted nodes when agents bypass all knowledge tools.

## 5. Optional Session Archives

- [ ] 5.1 Define an immutable transcript and summary format with many-to-many knowledge links and exact-range references.
- [ ] 5.2 Implement explicit archive preparation with secret detection, size review, and visible redaction markers.
- [ ] 5.3 Implement text search across archive summaries and raw transcripts without requiring a committed derived index.
- [ ] 5.4 Verify the complete knowledge workflow with zero archives and with sparse archives.

## 6. Adoption

- [ ] 6.1 Create and reconcile an initial root knowledge node over a narrow source scope.
- [ ] 6.2 Document node authoring, reconciliation, no-change acknowledgement, and hierarchy-refinement workflows.
- [ ] 6.3 Add CI validation only after the initial hierarchy reports zero pending reconciliation.
