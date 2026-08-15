# Pi context maintenance: triggers, economics, and reminder design

Status: v1 extension implemented in `dotfiles/pi/extensions/context-pressure/`; this document retains the design evidence and tuning notes.

Last checked: 2026-08-12 against Pi 0.84.1

Tracking issues: `nixos-kmc` (original research), `nixos-ghl` (adaptive design)

## Executive summary

Pi's reversible context-prune tools are useful during long agent runs, but
"some material is safe to fold" is not enough reason to fold immediately. A
maintenance pass is worthwhile when it removes a meaningful amount of
completed material and either enough model work remains to reuse the smaller
context or context pressure and quality risk justify the churn.

The v1 implementation is a standalone Pi extension rather than a
`pi-system-reminders` reminder. It is not tiny: correct branch-local yield,
latch, and escalation persistence makes the policy and event shell roughly 800
lines before tests. If sessions do not show enough benefit to justify that
state machine, the honest simplification is to delete adaptive escalation and
keep only pressure-threshold reminders. The package is useful shared machinery
for a suite of reminders, but its fixed visible `steer` delivery with
`triggerTurn: true` makes exact streaming/finality gating mandatory and removes
useful delivery control from a precision-sensitive reminder.

Tracking the last few `context_collapse` savings is feasible and cheap because
context-prune already reports a positive net `deltaTokens`. Convert that value
to percentage points using the active context window and persist the sample in
the owning Pi session. It is an estimated fold yield, not evidence that the
session itself is degrading: small targeted folds, concise source material, or
a mostly-active context also produce small values. Escalate only when high
pressure, several low-yield attempts, and one failed broader maintenance pass
coincide. Never replace a session automatically.

Use a hybrid trigger:

- accumulate context growth since the last actual maintenance checkpoint;
- evaluate only during an ongoing tool loop, not after a final answer;
- request an assessment after about 20,000--30,000 new tokens or 8--12
  percentage points of context growth;
- lower the growth threshold at high absolute utilization;
- suppress ordinary reminders after a recent `context_collapse` until
  substantial new growth occurs;
- treat the reminder as a no-op-capable checkpoint, not a command to fold.

`context_map` and `context_collapse` can sometimes piggy-back on model calls
that an ongoing tool loop already requires. They cannot normally be issued as
one dependent tool batch: the model needs the map result and its range ids
before selecting collapse ranges. Piggy-backing is therefore opportunistic,
not guaranteed.

A warm cache makes the economics less obvious than raw token reduction
suggests. Deleting old cached context saves the cheap cache-read rate on each
future request, while changing an early prompt prefix can make a large retained
suffix expensive once again. Additional maintenance model calls and output can
dominate the local tool execution cost. For most current Codex-auth plans,
OpenAI now documents token-based credit rates for input, cached input, and
output, and explicitly does not charge for cache writes. Direct API-key billing
uses a separate rate card that does charge GPT-5.6 cache writes.

## Evidence labels

This document distinguishes four kinds of claims:

- **Documented**: stated by current Pi or OpenAI documentation or source.
- **Observed**: measured in the current Pi installation or session records.
- **Derived**: arithmetic or an implication of documented behavior.
- **Recommendation**: a design judgment that should be validated in use.

## Scope and terminology

This document concerns fdietze's reversible context-prune extension already
configured for Pi. It exposes:

- `context_map` to list live messages and folds with range ids and sizes;
- `context_collapse` to replace selected ranges with a digest or bare,
  recoverable stub;
- `context_search` and `context_peek` to inspect folded material;
- `context_expand` to restore all or part of a fold.

A **fold** or **collapse** below means that selective, reversible operation. It
is distinct from Pi's built-in `ctx.compact()`, which performs coarse, lossy
session compaction through a summarization model call.

A **user interaction** may contain several low-level Pi agent runs and many Pi
turns. A Pi **turn** is one LLM response plus its tool activity; `turn_end` can
therefore fire several times before the user receives the final answer.
`agent_end` ends one low-level run, but retry, automatic compaction, or queued
continuation can follow it. `agent_settled` is the lifecycle event indicating
that Pi has no more automatic work for the current interaction.

## Global instruction policy

The shared `AGENTS.md` now treats phase boundaries, pre-verification, and
completed batches during long work as assessment checkpoints. It explicitly
allows a no-op, requires enough meaningful completed bulk or actual pressure,
prefers piggy-backing and one batched fold over tiny folds, and protects active
instructions, evidence, decisions, and errors. That is the durable policy; the
extension should supply timing and current measurements rather than repeat it.

The user-global Pi file resolves to this repository file. Context-prune's more
specific injected guidance still applies within Pi and currently uses stronger
"collapse immediately" wording. The global policy provides the safety and
materiality interpretation; align the injected wording if it becomes locally
configurable.

## Model capability and reminder value

**Recommendation:** Sol at high or above and Luna at xhigh or above are capable
of selecting ranges, preserving active evidence, and writing useful fold
summaries. Sol should be preferred when the keep-versus-fold boundary is subtle;
Luna is adequate for bounded maintenance with explicit criteria.

The less reliable behavior is spontaneous timing. During a long investigation,
task momentum makes it easy to postpone a meta-level maintenance action. A
salient event-driven reminder should improve timing more than it improves
fold-summary quality.

Typical failure modes are:

- waiting until the phase or context window is nearly finished;
- folding too little because all prior evidence still feels potentially useful;
- folding current diagnostics or source excerpts that remain active;
- omitting a subtle constraint from a digest;
- using stale range ids after context changed;
- performing a small fold whose cache and model-call churn exceeds its benefit;
- repeating maintenance shortly before the final response.

Reversibility limits the consequence of a selection error, but it does not make
all folds timely or economical.

## Relevant Pi extension behavior

### Context usage

**Documented:** `ctx.getContextUsage()` returns:

```ts
{
  tokens: number | null;
  contextWindow: number;
  percent: number | null;
}
```

It uses the most recent valid assistant usage and estimates messages appended
after that response. It returns no usage without an active model/context window,
and `tokens` and `percent` can be `null` immediately after Pi compaction until a
fresh assistant response establishes valid usage.

The official `trigger-compact.ts` example checks threshold crossings at
`turn_end`, demonstrating the lifecycle and metric pattern.

### Reminder delivery

**Documented:** `pi.sendMessage()` can queue a custom message with
`deliverAs: "steer"` while an agent run is streaming. This is preferable to
fabricating a user message for an internal reminder.

When Pi is streaming, a `steer` message is queued for the next LLM call and
`triggerTurn` is ignored. When Pi is idle, `triggerTurn: true` starts a new turn.
A reminder should therefore be evaluated only when the runner is demonstrably
continuing through tool use: at `turn_end`, require
`event.message.stopReason === "toolUse"` and nonempty `event.toolResults`. Use
`agent_settled`, not `agent_end`, to clear transient state or defer a pending
checkpoint to the next user interaction.

This guard is necessary but insufficient. The last tool-bearing turn may still
be immediately before the final answer, so the reminder must allow the model to
decline maintenance when completion is imminent. Custom reminder messages also
remain in LLM context, so their own input and prefix effects belong in cost
measurements.

## `pi-system-reminders` assessment

**Observed from the published `pi-system-reminders` 0.1.3 tarball:** the package
is a small reminder framework that:

- discovers global and project `.pi/reminders/*.ts` files;
- supports one or more lifecycle events per reminder;
- supports async predicates and dynamic messages;
- provides evaluation-count cooldown and `once` behavior;
- allows project reminders to override global reminders by name;
- gives reminder factories access to the full `ExtensionAPI`;
- loads TypeScript through Jiti;
- adds shared reminder instructions to the system prompt.

It is useful when several reminders should share discovery and dispatch. It
does not implement the hard context-specific state machine.

The current package also has drawbacks for this use case:

- it fixes delivery to visible `steer` messages with `triggerTurn: true`; this
  queues normally while streaming but can start an unwanted turn if the
  predicate fires while Pi is idle;
- its cooldown counts predicate evaluations rather than token growth;
- reminder code must still handle compaction, model changes, recent folds,
  hysteresis, and completion gating;
- some load and predicate errors are swallowed, making diagnosis harder;
- its manually enumerated event list is not Pi's lifecycle API: version 0.1.3
  names `session_switch` and `session_fork`, while Pi 0.83 emits
  `session_before_switch` and `session_before_fork` followed by `session_start`;
  the package's `session-resumed` example is consequently inert;
- returned reminders cannot select events omitted from that list, including
  `agent_settled`, `session_shutdown`, and `session_before_compact`; a reminder
  factory could register such handlers directly on `pi`, but that bypasses the
  framework's dispatch abstraction;
- the published tests cover only basic framework behavior;
- the included context examples use simple absolute thresholds rather than a
  cache-aware policy.

**Recommendation:**

- use a standalone extension for one precision-sensitive context reminder;
- use `pi-system-reminders` if a broader reminder suite is planned and its fixed
  delivery behavior is acceptable;
- alternatively vendor or fork the small framework and add configurable
  delivery, explicit error reporting, typed events, and token-based hysteresis.

## Reminder semantics

"If nothing is safely foldable, continue" is too fold-positive because it
implies that the presence of any safe material requires a fold. Safety is only
one test. A fold should pass all three:

1. **Safety:** the material is no longer needed verbatim or as active evidence.
2. **Materiality:** enough net context can be removed to justify maintenance.
3. **Timing:** enough future model work remains to reuse the smaller context, or
   pressure and quality risk justify immediate maintenance.

Recommended reminder text:

```text
<context-maintenance-reminder>
Context has grown substantially. This is an assessment checkpoint, not a
requirement to fold.

Fold now only if there is a meaningful batch of completed or superseded
material and either:

- enough substantive model/tool work remains to benefit from the smaller
  context, or
- current context pressure or quality risk makes immediate maintenance
  worthwhile.

If a final response is imminent, maintenance was performed recently, the
relevant evidence remains active, or likely savings do not justify cache and
round-trip churn, continue without folding. A no-op assessment satisfies this
reminder.
</context-maintenance-reminder>
```

## Reasonable trigger designs

The exact thresholds should be tuned from session logs. Context percentage
alone is not enough: on a 272,000-token window, a run can add tens of thousands
of tokens while the absolute percentage still looks comfortable. Growth alone
is also insufficient because pre-existing high utilization lowers the amount
of safe headroom.

### Option A: growth plus high-water mark

This is the recommended minimum viable policy.

Maintain two baselines:

- a maintenance baseline established when the extension or session starts and
  reset after positive-net maintenance, model change, or Pi compaction;
- an interaction baseline established on the first `agent_start` after the
  preceding `agent_settled`.

Do not replace the maintenance baseline at every `agent_start`: automatic retry,
auto-compaction recovery, or queued continuation can start another low-level
agent run before `agent_settled`. If usage is temporarily `null`, defer either
baseline until the first valid `turn_end`. Initialize tool-turn and reminder
latches for each interaction while preserving session-level growth and any
pending checkpoint.

At each ongoing tool-bearing `turn_end` for which
`event.message.stopReason === "toolUse"` and `event.toolResults` is nonempty:

- calculate both growth since the maintenance baseline and growth within the
  current interaction;
- require at least two or three tool-bearing turns before an ordinary reminder;
- trigger when any of these holds:
  - growth since maintenance is at least 24,000 tokens;
  - growth in the current interaction is at least 9 percentage points of the
    active context window;
  - absolute usage is at least 60% and growth since maintenance is at least 5
    percentage points;
  - absolute usage is at or above an emergency threshold such as 80%, subject
    to a one-shot latch rather than threshold crossing alone.

After sending a reminder:

- do not repeat it merely because utilization remains above the threshold;
- allow another ordinary reminder only after another 15,000--25,000 tokens of
  growth since the last reminder or positive-net collapse;
- treat a context-prune result as positive-net maintenance only when
  `details.action === "collapse"`, `details.ok === true`, and
  `details.deltaTokens > 0`, then establish the new baseline at the next valid
  context-usage reading;
- if a fold was applied with `deltaTokens <= 0`, use a short cooldown to avoid
  immediate churn but do not record an economic saving; if `ok` is false, keep
  the checkpoint pending subject to the same anti-spam cooldown;
- reset baselines on model change and Pi session compaction, and use
  `agent_settled` to clear transient tool-loop state or carry a deferred
  checkpoint into the next interaction.

The numeric values are **recommendations**, not measured optima. They make the
ordinary trigger roughly one substantial research/output batch on the current
272,000-token window while leaving semantic judgment to the model.

### Option B: piggy-back-first trigger

This policy tries to avoid adding model calls.

When a growth threshold is crossed:

1. Set a pending-maintenance flag rather than immediately forcing a response.
2. Wait for a `turn_end` with
   `event.message.stopReason === "toolUse"` and nonempty `event.toolResults`,
   which establishes that the runner must make another LLM call anyway.
3. Steer that already-required call to include `context_map` alongside any
   independent work tools.
4. Ask the model to issue `context_collapse` on the following already-required
   call only if substantive tool work will continue and the map shows
   meaningful foldable bulk.
5. If no qualifying continuation occurs before `agent_settled`, carry the
   pending checkpoint into the next interaction unless it was only a transient
   advisory. Do not treat `agent_end` as finality. An emergency threshold may
   justify maintenance without waiting for another interaction.

This reduces marginal model-call cost when the work naturally contains at
least two more tool-loop turns. It cannot guarantee zero additional calls
because the extension cannot know the future tool plan perfectly.

### Option C: two-tier advisory and emergency policy

Use two different reminders:

- **Advisory:** at about 8--10 percentage points of growth during an ongoing
  tool loop. It explicitly permits deferral and prefers piggy-backing.
- **Emergency:** at 75--80% absolute use, or closer to Pi's compaction reserve.
  It prioritizes preserving controlled reversible context even if the immediate
  monetary calculation is unfavorable.

This separates economic maintenance from window-safety maintenance. Emergency
thresholds should be chosen with Pi's compaction reserve and active model window
rather than copied as a universal percentage. Pi's documented default reserve
is 16,384 tokens; an advisory threshold should leave additional margin for
large tool results and the maintenance exchange itself.

### Option D: observed-cost trigger

A more complex extension could inspect assistant usage fields such as input,
cache read, cache write, output, and reported cost. It could avoid reminders
when cache reuse is high and little future work appears likely, or become more
aggressive after cache expiry or prefix churn.

This is not recommended for version one:

- `getContextUsage()` does not itself reveal semantic foldable bulk;
- future call count is unknown;
- Codex credits are documented, but `getContextUsage()` does not expose a plan
  balance and Pi's API-equivalent `cost` field is not itself the Codex credit
  ledger;
- legacy Enterprise plans and Fast mode use different accounting;
- provider usage fields differ;
- the model still must estimate which ranges are complete.

Log those fields first and tune the simpler hybrid policy from evidence.

## Adaptive collapse-yield tracking

### Feasibility and metric

**Observed in the configured context-prune extension:** every
`context_collapse` result currently exposes:

```ts
{
  action: "collapse";
  ok: boolean;
  msgs: number;
  deltaTokens: number;
}
```

For collapse results, `deltaTokens` is the positive net estimate of live tokens
removed after subtracting the replacement stub or summary. The extension uses
Pi-compatible `chars / 4` token estimates, not provider tokenization. A
companion extension can observe `tool_result` and calculate:

```text
saving percentage points = 100 * max(deltaTokens, 0) / contextWindow
```

This is better than subtracting two calls to `ctx.getContextUsage()`: usage
lags a just-applied fold and the next assistant/tool output would confound the
before/after difference. The percentage-point calculation still remains an
estimate, but it measures the fold itself rather than unrelated transcript
growth.

Record every collapse attempt in the recent ring, including no-op and
non-saving attempts as `0 pp`; omitting them would make the history falsely
optimistic. A useful initial ring size is three. Persist `deltaTokens`,
`contextWindow`, computed percentage points, `ok`, message count, and timestamp
in a small `pi.appendEntry()` custom entry. Storing the window at event time is
necessary because a later model switch can change it. Reconstruct only from the
active session branch so `/tree` semantics remain correct.

The tracker is naturally per agent. Pi creates a separate extension factory
instance for the foreground session and each SDK child session, and the local
subagent host binds only the extensions in its fail-closed child policy. Adding
the companion extension to that policy therefore gives each child isolated
state without agent-name routing or a global registry.

### What the samples can and cannot say

Call the samples **recent collapse yields**, not efficiency or session health.
A falling or low sequence can mean:

- little completed material remains;
- most remaining context is active evidence or governing instructions;
- the agent chose several intentionally small ranges;
- summaries are long relative to the folded material;
- earlier maintenance already succeeded.

Consequently, `last N < threshold` alone must not trigger a fresh session. Use
it only as an escalation input while pressure remains high. A reasonable v1
rule is:

1. At urgent pressure, show the last three yields without interpreting them.
2. If all three are below `3 pp`, or total less than `6 pp`, request one broader
   but still safety-preserving sweep.
3. Only if that explicitly broader pass saves less than `3 pp` and pressure
   remains urgent should the agent prepare a resume-quality handoff and advise
   replacing the session.

Collapse yield and remaining pressure are separate signals. After any
positive-net collapse, the first fresh usage reading at or above `60%` requests
one more aggressive safe collapse or a short visible retention notice naming
the indispensable working set and a concrete next checkpoint. The notice goes
to the user for a foreground agent and to `main` for a child. This path does not
reinterpret a useful 12--20 pp collapse as low-yield merely because substantial
active context remains.

An urgent or critical maintenance request remains pending across subsequent
tool turns, model selection, and session restore. `context_map`, unrelated
tools, and failed or zero-yield collapse attempts do not satisfy it. A
positive-net collapse clears the pending request. A final response or handoff
stops reminder delivery because the continuing tool loop ends; if the same
session later resumes without maintenance, the pending request remains.

"Broader" means batching more completed or superseded ranges. It never means
folding active evidence, unresolved errors, the user request, or governing
instructions merely to hit a target. Without adding another tool or protocol,
the extension cannot verify semantic breadth; it can only mark the next
collapse after that reminder as the requested pass. The final reminder must say
"reported low-yield pass," not claim that the agent actually searched every
safe range.

These numbers are deliberately coarse initial tuning values, not measured
optima. Log the actual sequences before changing them.

## Concrete version-one design

### Thresholds and reminder state

Use percentage thresholds for readability, but retain token-growth and absolute
headroom checks because the same percentage means different token counts on
128k and 272k windows.

| Level | Initial trigger | Behavior |
| --- | --- | --- |
| Advisory | at least `60%` and either `24k` growth since positive maintenance or `8 pp` interaction growth | no-op-capable assessment; prefer piggy-backing |
| Firm | at least `75%` and `5 pp` growth since positive maintenance | ask for `context_map` before broadening exploration |
| Urgent | at least `80%` | stop other work and request one aggressive batched sweep; repeat while tool work continues until productive maintenance or handoff |
| Post-collapse residual | first fresh reading at least `60%` after a positive collapse | request one more aggressive safe collapse or a specific retention notice with a concrete checkpoint |
| Critical | remaining window at most configured reserve plus about `8k` tokens | stop token-chasing; finish or hand off immediately |

The critical trigger should use Pi's effective compaction reserve when that
becomes directly available. For v1, expose a local constant defaulting to Pi's
documented `16,384` tokens rather than pretending that `90%` is portable. Keep
the constants in code; a user-facing configuration format is unnecessary until
real sessions show they need tuning.

Evaluate ordinary reminders only on a continuing tool-bearing `turn_end`:
`stopReason === "toolUse"` with nonempty tool results. Deliver with a custom
`pi.sendMessage(..., { deliverAs: "steer" })` and do not set
`triggerTurn: true`. This lets the next already-required model call receive the
reminder without waking an idle agent solely for maintenance.

Use one latch per level. Re-arm a level only after usage falls at least `5 pp`
below it, or after another `15k`--`25k` tokens of growth following its reminder.
Urgent and critical additionally carry a persistent pending-maintenance flag so
the ordinary one-shot latch cannot silence an ignored request. A positive-net
collapse clears that flag and establishes a pending baseline; take the fresh
baseline from the next valid usage reading because the immediate reading still
lags the fold. Reset pressure baselines on model change and Pi compaction, but
retain the historical yield samples with their original windows. Model changes
preserve an unresolved urgent request and remeasure an unresolved post-collapse
reading in the new window; Pi compaction clears both because it is maintenance.

`/context-status` exposes `urgent pending`, the latest `post-fold N%` reading
(with `high` at or above 60%), and retention reminder counts. Its reminder-level
header expands each count prefix compactly as
`(A)dvisory/(F)irm/(U)rgent/(R)etention/(H)andoff/(C)ritical`. Named subagents
use their roster name even when an older child session lacks Pi display-name
metadata. `ctx unavailable` means Pi has no current usage sample, commonly just
after compaction and before the next assistant turn; the HWM remains historical.

### Reminder text

Keep injected messages much shorter than the standing global/tool guidance.
They should report state and point at that guidance, not paste it again.

Advisory:

```text
<context-maintenance>
Context 64% (+9 pp this interaction). Assessment checkpoint: if a meaningful
completed/superseded batch exists and more work remains, piggy-back one
context_map and batched context_collapse. Otherwise continue; no-op is valid.
</context-maintenance>
```

Urgent with yield history:

```text
<context-maintenance urgent>
Context 82%. Recent collapse yields: 5.8, 1.7, 0.6 pp. STOP other work now and
do one aggressive, broader safe sweep of completed phases, superseded
reads/logs, and dead ends. Preserve the request, instructions, open loops,
unresolved errors, and active evidence.
</context-maintenance>
```

High residual after productive maintenance:

```text
<context-maintenance urgent>
Context 64% after productive maintenance is still high. STOP and either do one
more aggressive safe collapse now, or send one short visible notice:
"Retaining context because: [specific indispensable working set]. Next
checkpoint: [concrete phase/event]." Main agents tell the user; child agents
send_message main.
</context-maintenance>
```

Critical after a low-yield broader pass:

```text
<context-maintenance critical>
Context headroom is near Pi compaction reserve; the broader pass saved 1.4 pp.
STOP now. Preserve a resume-quality handoff and recommend a fresh session. Do
not run more diagnostics or discard active evidence to force a lower percentage.
</context-maintenance>
```

For the foreground TUI, also issue one short `ctx.ui.notify(..., "warning")` at
critical level so the human sees the recommendation. Child sessions run in
`print` mode and have no UI. Their reminder can instruct the child to send its
handoff/replacement recommendation to `main`, but that is agent-mediated rather
than guaranteed. A guaranteed central per-child alert would require a small
subagent-host API or shared event bridge and is not justified in v1; the current
subagent panel already exposes each child's token/window usage.

### Minimal repository structure

```text
dotfiles/pi/extensions/context-pressure/
  index.ts          # Pi events, delivery, snapshot persistence, prune adapter
  policy.ts         # pure threshold/latch/yield decision function
  index.test.ts     # shell/lifecycle/persistence integration tests
  policy.test.ts    # node:test tables for hysteresis and escalation
```

No package, timer, background process, model call, dependency, custom tool, or
standing system-prompt text is needed. The extension should stay silent below a
trigger and rely on the existing global/context-prune guidance.
`home-modules/pi.nix` links the directory into the foreground extension set
and adds the same path to `child-extensions.json`. The nontrivial state
machine belongs in a pure function; the extension shell should remain small.

### Integration options and trade-offs

| Option | Accuracy | Coupling and cost | Verdict |
| --- | --- | --- | --- |
| Standalone companion observes `context_collapse` `tool_result.details` | Best available fold-local estimate | Small runtime/schema coupling to context-prune; no upstream fork | **Recommended v1**; validate details and fail visibly if they change |
| Context-prune emits a typed `pi.events` yield event; companion consumes it | Same accuracy with explicit contract | Requires an upstream change or local patch to the pinned external source | Best long-term contract if upstream accepts it |
| Put reminder policy inside context-prune | Exact access, simplest state transfer | Mixes mechanism with personal policy and makes the external source a maintained fork | Sensible only if the feature is upstream-configurable |
| Track before/after `getContextUsage()` generically | Works with any pruning tool | Lagged and contaminated by new assistant/tool content; model switches complicate it | Too misleading for savings history |
| Track all children centrally in the subagent extension | Guaranteed parent UI and roster integration | Does not cover standalone Pi, couples maintenance to orchestration, broadens the local patch stack | Defer unless missing child alerts are a real problem |
| Use `pi-system-reminders` | Shared reminder discovery | Still needs this state machine and gives less delivery control | Not worthwhile for one reminder |

The standalone option should treat the details shape as a capability check: if
`action`, `ok`, or numeric `deltaTokens` is absent, skip the sample and log one
warning rather than guessing. A one-line upstream event would be cleaner, but
forking the whole context-prune implementation only for that contract is not.

## Can maintenance piggy-back on existing LLM calls?

### What can be shared

Suppose a long run already follows this sequence:

```text
LLM call A -> work tool results -> LLM call B -> more work tools -> LLM call C
```

The model can add `context_map` to the independent work tools selected by call
A or B. The next LLM call was already required to process the work results, so
reading the map does not necessarily introduce another model invocation.

After seeing the map, the model can add `context_collapse` to the next batch of
independent work tools. If another LLM call was already required after that
batch, the smaller context begins paying off without a maintenance-only call.

The local tool execution itself has no separate model-token fee. Its arguments
and result add prompt tokens, however, and a large session can produce a large
`context_map` result. Whether that cost is smaller than a dedicated round-trip
has not been measured; log map-result size and subsequent input categories.

### The dependency that prevents full fusion

`context_collapse` needs valid ids and a summary chosen from `context_map`.
Because an LLM cannot consume a tool result until its next invocation, it cannot
normally discover ids and issue a dependent collapse in the same tool batch.
Calling both concurrently would either use stale ids or guess.

The normal minimum dependency chain is therefore:

```text
LLM call -> context_map -> LLM call -> context_collapse -> next LLM call
```

The first two LLM calls can coincide with calls required by substantive work.
The final call can also be required naturally after other tools. A collapse is
applied by context-prune's `context` hook before the following LLM call, so it
cannot reduce the prompt of the call that selected the collapse. If the model
would otherwise have answered finally after seeing the map, choosing collapse
instead creates an additional turn before the final answer.

### Conditions for effective piggy-backing

Piggy-backing is most credible when:

- the agent is in a multi-step tool loop with at least two likely tool batches
  remaining;
- `context_map` can run independently beside current work tools;
- collapse selection does not depend on unresolved results from those tools;
- `context_collapse` can accompany another independent tool call;
- another response is needed after the collapse anyway.

It is weak when:

- verification just finished and the next response is likely final;
- the current diagnostics determine whether earlier evidence remains active;
- only one tool result remains to be summarized;
- the model has to interrupt work solely to orient and fold.

### Possible future optimization

A purpose-built integration could reduce the dependency chain by exposing a
precomputed map in the reminder or a compound checkpoint API. This would
require cooperation with context-prune's internal branch ids and fold state;
Pi's normal reminder API does not automatically execute another extension's
tool with standard transcript accounting.

A fully automatic compound fold would still need semantic range selection and
digest writing. Moving that judgment into another summarization call merely
moves, rather than removes, the model cost. The piggy-back-first policy is the
simpler initial experiment.

## Cache-aware economics

### Provider qualification

**Observed:** the current Pi runtime uses
`openai-codex/gpt-5.6-sol`. Pi documents `openai-codex` as ChatGPT
subscription authentication.

**Documented:** since April 2026, most Plus, Pro, Business, Enterprise, Edu,
Health, Gov, and ChatGPT for Teachers plans use Codex's token-based credit rate
card. A small subset of Enterprise customers remains on the legacy rate card.
Fast mode also consumes credits at a higher rate. The plan's Codex Usage panel
is authoritative for available and consumed credits.

Pi's assistant usage records still expose useful input, cache-read, cache-write,
and output categories. Pi's dollar-denominated `cost` field is an
API-equivalent estimate, not the Codex credit balance, but the documented token
categories now allow direct credit estimates for migrated standard-speed plans.

### Codex-auth credit rates

At the rates checked on 2026-08-06:

| Model | Input / 1M | Cached input / 1M | Output / 1M |
| --- | ---: | ---: | ---: |
| GPT-5.6 Sol | 125 credits | 12.5 credits | 750 credits |
| GPT-5.6 Luna | 5 credits | 0.5 credits | 30 credits |

For both models:

- uncached input costs 10 times cached input;
- output costs 60 times cached input;
- Codex does not charge for cache writes.

After an exact-prefix change, model the invalidated suffix as uncached input for
Codex credit accounting. Its one-time premium over a cache read is therefore 9
cached-token equivalents, not 11.5.

### Direct API-key prices

The separate short-context OpenAI API rate card is:

| Model | Uncached input / 1M | Cache read / 1M | Cache write / 1M | Output / 1M |
| --- | ---: | ---: | ---: | ---: |
| GPT-5.6 Sol | $5.00 | $0.50 | $6.25 | $30.00 |
| GPT-5.6 Luna | $0.20 | $0.02 | $0.25 | $1.20 |

For direct API billing, cache writes cost 12.5 times cache reads and their
one-time premium over an otherwise cached token is 11.5 times. Uncached input
and output retain the same 10x and 60x ratios as Codex credits.

Above 272,000 input tokens, the direct API long-context tier raises prices for
the entire request. Pi currently caps direct and Codex-auth GPT-5.6 Sol at
272,000 tokens despite the model's larger supported window, avoiding that tier
unless model configuration is overridden. Near a window or pricing boundary,
controlled folding has value beyond the ordinary warm-cache calculation.

### Break-even model

Exact-prefix caching means that changing an earlier message can invalidate the
retained suffix after it. A more complete directional model defines:

- `H`: old hidden tokens replaced by the fold;
- `S`: new summary or stub tokens inserted in their place;
- `G = H - S`: net tokens removed;
- `R`: retained tokens following the earliest changed position;
- `N`: future model calls using the new folded prefix, including the first;
- `Cr`: cache-read rate in dollars or credits;
- `Cnew`: first-call rate for the changed summary plus invalidated suffix;
- `Cm`: marginal cost of maintenance-only model calls and their output.

Under the simplifying assumption that `H + R` would otherwise remain cached,
the first post-fold request changes cost by approximately:

```text
(S + R) * Cnew - (H + R) * Cr + Cm
```

After the new prefix becomes warm, each additional request saves approximately:

```text
G * Cr
```

Across `N` future calls, folding pays when:

```text
N > ((S + R) * (Cnew - Cr) + Cm) / (G * Cr)
```

For standard Codex-auth credits, `(Cnew - Cr) / Cr` is 9. For direct API
cache-write billing it is 11.5. Ignoring maintenance overhead and using a
1,000-token replacement summary:

- Removing 100,000 net tokens with a 10,000-token retained suffix gives a
  threshold of about 0.99 future calls for Codex and 1.27 for direct API. One
  Codex call can pay; direct API normally needs two.
- Removing 30,000 net tokens with a 120,000-token retained suffix gives a
  threshold of about 36.3 calls for Codex and 46.4 for direct API. It is
  unattractive despite being semantically safe.

This is still an estimate. Cache block boundaries, expiry, provider behavior,
newly appended tokens, and imperfect cache hits can change the result. Measure
actual token categories rather than treating these thresholds as guarantees.

### Why maintenance tool use may not be small

The local tool call is cheap, but a maintenance-only model turn must:

- reread the full current prompt, even if mostly at the cached rate;
- consume the map and collapse tool arguments/results;
- produce reasoning and tool-call output;
- invoke the model again after the tool result.

One output token currently costs the same as 60 cached-input tokens for both Sol
and Luna under both standard Codex credits and direct API pricing. A 1,000-token
maintenance response therefore costs as much as rereading 60,000 cached tokens,
before counting its input.

Maintenance is cheaper when its tools piggy-back on already-required calls. It
is expensive when `context_map` creates a dedicated full-context round-trip
immediately before the final answer.

### Session observation

**Observed:** one large maintenance pass in the research session reduced the
next request input from roughly 171,000 tokens to roughly 23,000 and retained
about 16,900 cached-prefix tokens. The intermediate Sol maintenance request
used approximately 4,157 uncached-input, 166,400 cached-input, and 860 output
tokens.

**Derived from the standard Codex rate card:** that maintenance request was
about 3.24 credits. The next request's input was about 0.97 credits, versus a
minimum of about 2.14 credits for an entirely cached, unfolded 171,000-token
request. The fold therefore saved at least about 1.17 credits on that next
input but did not repay the maintenance request before the one final response.
Continued user turns can amortize it. This directly supports suppressing normal
maintenance when completion is imminent.

### Non-monetary reasons to fold

Even when immediate token charges do not break even, folding can be justified
to:

- avoid uncontrolled automatic compaction;
- preserve exact active evidence and deliberate summaries;
- reduce distraction from obsolete failures and rejected paths;
- stay within the active context window;
- reduce latency;
- keep a long-lived session usable for likely follow-up work.

The window and exact-prefix caching behavior are documented. The magnitude of
quality improvement from removing irrelevant material is task-dependent and
has not been measured for this setup.

## Implemented v1 and follow-up sequence

The standalone v1 companion is now wired for foreground and child sessions,
with policy and shell/lifecycle tests and no bespoke repository test architecture.
It keeps a versioned, branch-local session snapshot containing recent yields,
armed pressure latches, and phase flags. Items 1--8
below describe the implemented shape; items 9--11 remain follow-up measurement
and tuning work.

1. Retain context-prune's active guidance and the global safety/materiality/
   timing interpretation; no fork or prompt bridge is required for v1.
2. The standalone companion is loaded in both the foreground and fail-closed
   child policy.
3. Use Option A's growth/high-water policy with piggy-back delivery and the
   advisory/firm/urgent/critical levels above.
4. Track session-level maintenance and per-interaction baselines through
   `agent_start`, `agent_settled`, model selection, session compaction,
   qualifying tool-bearing turns, and positive maintenance without resetting
   cumulative growth on retries or continuations.
5. Observe context-prune's collapse result, persist the last three yield samples
   with their original windows, and warn visibly rather than estimate if its
   details contract or context window is invalid.
6. Treat a collapse as positive maintenance only when its result reports
   `action === "collapse"`, `ok === true`, and `deltaTokens > 0`; establish a
   fresh usage baseline on the next valid reading and independently flag a
   post-collapse reading that remains at or above 60%.
7. Keep urgent maintenance pending until a positive collapse. Stop delivering
   while the agent is final or handed off, but retain the pending state if the
   same session resumes without maintenance. If positive maintenance leaves
   high residual pressure, require another aggressive safe pass or a specific,
   visible retention notice with a concrete next checkpoint.
8. Escalate low yields only under high pressure, require one explicitly broader
   pass before recommending a new session, and never replace automatically.
   Ordinary pressure latches retain hysteresis and a short post-attempt cooldown;
   critical headroom still uses Pi's reserve plus 8,000 tokens.
9. Log trigger cause, reminder/map/result sizes, yield samples, whether a
   collapse followed, future call count, and reported input/cache/output token
   categories. Compare those categories with Codex credits or direct API costs
   according to the active provider.
10. Review several long foreground and child sessions before changing
    thresholds, adding central child alerts, or adding cache-aware scoring.
11. Reconsider `pi-system-reminders` only when there are enough reminder types
    to justify shared discovery and dispatch, or fork it to expose the required
    delivery and lifecycle controls.

## Sources

- [Pi extensions and `ctx.getContextUsage()`](https://pi.dev/docs/latest/extensions#ctx-getcontextusage)
- [Pi compaction](https://pi.dev/docs/latest/compaction)
- [Pi 0.83.0 extension lifecycle documentation](https://github.com/earendil-works/pi/blob/v0.83.0/packages/coding-agent/docs/extensions.md)
- [Pi 0.83.0 `trigger-compact.ts` example](https://github.com/earendil-works/pi/blob/v0.83.0/packages/coding-agent/examples/extensions/trigger-compact.ts)
- [Latest-upstream Pi extension API types](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/src/core/extensions/types.ts)
- [`pi-system-reminders` package page](https://pi.dev/packages/pi-system-reminders)
- [`pi-system-reminders` 0.1.3 published tarball](https://registry.npmjs.org/pi-system-reminders/-/pi-system-reminders-0.1.3.tgz)
- [Pi provider documentation](https://pi.dev/docs/latest/providers)
- [Pi `openai-codex/gpt-5.6-sol` model details](https://pi.dev/models/openai-codex/gpt-5-6-sol)
- [Codex token-based credit rate card](https://help.openai.com/en/articles/20001106-codex-rate-card#codex-rate-card-token-based-pricing)
- [OpenAI API pricing](https://developers.openai.com/api/docs/pricing)
- [OpenAI prompt caching](https://platform.openai.com/docs/guides/prompt-caching)
- [GPT-5.6 model documentation](https://platform.openai.com/docs/models/gpt-5.6)
- [DeepWiki predecessor-repository feasibility query](https://deepwiki.com/search/assess-the-feasibility-of-a-pi_100c079a-5ce0-4bf4-b6ed-c889d70f3867)
