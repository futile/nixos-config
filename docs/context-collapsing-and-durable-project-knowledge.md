# Context collapsing and durable project knowledge

Status: decision record; `knowledge-distill` prototype retired

Last checked: 2026-08-11

Tracking issues: original exploration `nixos-5y4`; final documentation `nixos-92c`

## Decision

Use context collapsing and MEX as separate, complementary systems:

- Context collapsing manages the active transcript of one Pi session.
- MEX maintains curated, repository-shared project knowledge.

Do not build the proposed `knowledge-distill` system. Current MEX is probably
good enough for the demonstrated need, especially when its `AGENTS.md`, router,
and GROW workflow are followed. The remaining differences are real, but they do
not currently justify implementing and maintaining a second living-knowledge
system.

Do not make context collapse or compaction automatically update MEX. A collapse
may justify re-establishing routed context, but neither the occurrence nor the
size of a collapse reliably indicates that durable project knowledge changed.

## Original approach

The exploration began with an analogy between levels of memory:

1. live model context;
2. reversible, session-local folded context;
3. durable, repository-shared knowledge.

The first two levels fit the analogy reasonably well. The context-prune
extension moves old Pi messages between live context and recoverable folds. A
fold remains part of the session and can be searched, inspected, or expanded.

The third level proved to have different semantics. Durable project knowledge
is not merely colder transcript storage. It is a curated description of current
repository reality, shared with collaborators and reviewed like other project
artifacts. Promoting transcript material into it requires semantic judgment.

The proposed `knowledge-distill` design therefore grew into a separate system:

- a single-rooted hierarchy of Markdown knowledge nodes;
- `owned_files` patterns assigning every covered source file to its deepest
  matching knowledge node;
- overlapping, non-owning `related_files` patterns;
- VCS-independent source fingerprints as portable reconciliation receipts;
- direct-child semantic fingerprints for controlled upward invalidation;
- deterministic hierarchy, ownership, link, and freshness checks;
- explicit page-in and distillation operations;
- optional immutable session archives as evidence.

This was a coherent design, but it was never implemented. Research into current
MEX showed that much of its product-level purpose already exists in released
software.

## What current MEX provides

MEX 0.7.1 provides a repository-owned `.mex/` scaffold with:

- a compact always-loaded agent anchor;
- `ROUTER.md` for conditional knowledge navigation;
- architecture, stack, setup, decisions, and conventions documents;
- reusable patterns and runbooks;
- an explicit GROW phase for maintaining durable knowledge after work;
- structural, staleness, path, command, dependency, link, pattern, and grounding
  checks;
- an agent-driven synchronization workflow;
- an append-only event timeline;
- a local Tree-sitter and SQLite code graph for TypeScript/JavaScript, Python,
  and Rust;
- symbol-level grounding, impact analysis, and move or rename reconciliation.

This is substantially more working machinery than the proposed design had.
MEX's symbol graph and repair context are also stronger than whole-file hashes
for supported languages.

MEX does not currently have a released first-class integration for upstream Pi.
That has not prevented useful operation: Pi reads repository `AGENTS.md`, and
MEX commands remain available through the shell. An unmerged upstream PR adds
minimal Pi setup and sync launching, while a separate Oh My Pi fork provides a
larger extension that is useful prior art but is not drop-in compatible with
upstream Pi.

## Similarities

Both approaches aim to:

- keep concise agent-facing knowledge in the repository;
- route only relevant knowledge into active context;
- prevent stable decisions and patterns from being rediscovered every session;
- detect when source changes may have made knowledge stale;
- reconcile documentation explicitly rather than treating generated summaries
  as automatically authoritative;
- support policy choices ranging from advisory maintenance to stricter project
  checks.

At this level, implementing `knowledge-distill` would duplicate the central MEX
product story: a living repository wiki for coding agents with routed reads,
drift detection, and deliberate repair.

## Differences and remaining MEX gaps

The abandoned design had several stronger invariants than MEX:

| Concern | MEX 0.7.1 | Proposed design |
| --- | --- | --- |
| Source coverage | Selected claims ground to selected symbols | Root defines a complete covered source universe |
| Ownership | No formal knowledge owner for every file | Exactly one deepest owner per covered file |
| Cross-cutting relevance | Navigation edges and independent grounding | Explicit overlapping `related_files` |
| Parent freshness | Edges are checked mainly for valid targets | Child prose changes invalidate the direct parent |
| Portable receipts | Exact old source baseline is primarily local graph state | Exact fingerprints are committed and VCS-independent |
| Language coverage | Graph supports a limited language set | Whole-file hashing is language-neutral |
| Policy | Some severity and Git-history behavior is built in | Checker is explicitly policy- and VCS-neutral |
| Pi lifecycle | No fold or compaction integration | Consultation and distillation were planned explicitly |
| Session evidence | Discrete event log and optional trace pointers | Optional complete immutable transcript archives |

One important technical limitation is that MEX's exact grounded source baseline
lives in its gitignored SQLite database. Committed grounding metadata uses an
approximate fingerprint primarily to reconcile symbols that disappear or move.
On a fresh clone, an existing grounded symbol whose body changed can lack the
old exact baseline needed to report ordinary body drift. The proposed committed
exact receipts would have been stronger across clones and CI.

MEX also cannot use its code graph for Nix or Shell. Its documentation and
workflow remain usable in those repositories, but its most advanced grounding
features do not provide complete language-neutral coverage.

These are genuine limitations. They should not be minimized, but neither should
they be treated as requirements without evidence that they cause recurring
failures. A complete ownership and fingerprint system would add metadata,
reconciliation work, migration rules, and another toolchain. It still could not
prove that an agent performed a thoughtful semantic review.

## Why MEX is probably good enough

The practical requirement is useful shared project knowledge, not a perfect
formal correspondence between all source and all documentation. MEX already
provides the scaffold, routing contract, maintenance workflow, checks, and agent
behavior needed for that goal.

`~/gits/pale-darks-online` provides a useful case study. At inspection time:

- root `AGENTS.md` required agents to read `.mex/AGENTS.md` and
  `.mex/ROUTER.md`;
- the scaffold contained about 2,228 lines of substantive context and patterns;
- 46 commits had touched `.mex` since setup, including 35 commits that also
  changed non-MEX files and 11 MEX-only maintenance commits;
- recent feature work routinely updated routed context and patterns;
- durable deferred maintenance was represented in OpenSpec tasks rather than
  only in an agent session.

The inspected content was concise, useful, and appropriately delegated detailed
truth to source, OpenSpec, `docs-ai`, and live issue queries. This is good
evidence that the workflow is actively used. It is not controlled evidence that
MEX improves every agent answer, nor is there consultation telemetry proving
that agents always follow the router.

The repository was still using MEX 0.6.3 and had no 0.7 grounding metadata.
`mex check --quiet` reported 100/100 despite multiple uncommitted implementation
changes. That score therefore demonstrated structural cleanliness, not complete
semantic freshness. Upgrading and selectively grounding high-value behavioral
claims would improve coverage, but a checker result must remain supporting
evidence rather than a substitute for GROW judgment.

Given the working repository practice and the absence of a demonstrated failure
requiring stronger invariants, replacing MEX or building a parallel system
would be speculative engineering.

## Why context collapsing and MEX are complementary

The systems operate on different axes:

| Context collapsing | MEX |
| --- | --- |
| One agent session | Shared repository |
| Transcript messages and tool results | Curated current-state knowledge |
| Reversible space and attention management | Durable collaboration and maintenance |
| Preserves historical interaction | Replaces obsolete claims with current truth |
| Triggered by context pressure and completed conversational phases | Triggered by stable semantic repository changes |
| Session lifetime | Repository lifetime |

Their useful connection is page-in:

```text
MEX route and read
    -> use knowledge while working
    -> fold completed transcript material when worthwhile
    -> finish a coherent semantic unit
    -> apply GROW to the final repository diff
    -> update MEX only if stable project reality changed
```

Fold summaries may help a continuing agent resume its work, but they are not
candidate documentation by default. They can contain failed approaches,
speculation, temporary state, private material, or details that became obsolete
later in the same task.

The amount of collapsed context is an especially weak maintenance indicator. A
large build log may produce a large fold with no durable knowledge, while a
small change to one invariant may require an important MEX update without any
folding at all.

Context collapse can indicate a higher risk that an agent forgets an existing
obligation. It does not determine whether that obligation exists. A post-
compaction reminder to re-read the MEX router may aid continuity, but it should
not create, store, or discharge reconciliation work.

## Better MEX maintenance triggers

Reconciliation should follow semantic and collaboration boundaries:

1. Complete a coherent OpenSpec task, issue, feature, or change.
2. Inspect the final Git diff rather than trying to infer changes from agent
   tool calls.
3. Apply the MEX GROW questions before closing the work unit or making a pull
   request ready.
4. Update routed context or patterns in the same change when stable project
   reality changed.
5. If reconciliation must be deferred, record it immediately in the active
   OpenSpec task list or in `bd`, not in session-local state or a second queue.
6. Run MEX checks after MEX changes and treat grounding or drift findings as
   supporting signals.

Changes especially likely to require maintenance include architecture,
invariants, external behavior, persistent schemas, recurring implementation
patterns, setup or verification commands, dependencies, and troubleshooting
knowledge likely to recur.

A policy requiring every source change to touch `.mex` would be counterproductive:
it would create meaningless edits and encourage agents to satisfy the gate
without improving knowledge. The decision must remain semantic.

## Rejected integrations

Do not implement:

- automatic `.mex` writes from fold or compaction summaries;
- automatic `mex sync` or `mex log` on compaction;
- a session-local reconciliation queue as the only record of pending work;
- a maintenance score based on collapsed token volume;
- mandatory session transcript archives;
- a second full knowledge hierarchy without demonstrated MEX failures.

Session-local reminders can be conveniences, but they cannot provide durable
correctness because sessions can end, be abandoned, branch, or disappear.
Anything important enough to survive the session belongs in the repository's
existing work tracker.

## When to reconsider

Revisit a small extension or checker only after observing a repeated concrete
failure, such as:

- stable MEX knowledge routinely becoming stale despite the GROW workflow;
- new or unsupported source areas repeatedly escaping all knowledge coverage;
- cross-clone grounding limitations causing real CI or collaboration errors;
- agents repeatedly failing to re-establish routed context after compaction;
- a demonstrated need for audited transcript provenance.

Prefer the smallest addition to MEX that addresses the measured failure. The
formal ownership hierarchy, portable receipts, or parent propagation could
still be useful as independent MEX enhancements, but they are documented gaps,
not a current implementation plan.

## Related documentation

- [`pi-context-maintenance.md`](pi-context-maintenance.md) covers context-prune
  triggers, economics, and reminder design.
- [`pi-agent-setup-research.md`](pi-agent-setup-research.md) describes the Pi
  configuration and context-prune integration.

## Sources

- [MEX v0.7.1 release](https://github.com/mex-memory/mex/releases/tag/v0.7.1)
- [MEX v0.7.1 README](https://github.com/mex-memory/mex/blob/v0.7.1/README.md)
- [MEX changelog](https://github.com/mex-memory/mex/blob/v0.7.1/CHANGELOG.md)
- [MEX grounding checker](https://github.com/mex-memory/mex/blob/v0.7.1/src/drift/checkers/grounding.ts)
- [MEX grounding runtime](https://github.com/mex-memory/mex/blob/v0.7.1/src/graph/runtime.ts)
- [Pending upstream Pi support](https://github.com/mex-memory/mex/pull/89)
- [Oh My Pi MEX fork](https://github.com/thekorsen/mex/tree/main/packages/omp-mex)
