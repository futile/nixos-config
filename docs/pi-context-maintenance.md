# Pi context maintenance: triggers, economics, and reminder design

Status: design and research; extension not yet implemented

Last checked: 2026-08-06

Tracking issue: `nixos-kmc`

## Executive summary

Pi's reversible context-prune tools are useful during long agent runs, but
"some material is safe to fold" is not enough reason to fold immediately. A
maintenance pass is worthwhile when it removes a meaningful amount of
completed material and either enough model work remains to reuse the smaller
context or context pressure and quality risk justify the churn.

The recommended first implementation is a small standalone Pi extension rather
than a `pi-system-reminders` reminder. The package is useful shared machinery
for a suite of reminders, but its fixed visible `steer` delivery with
`triggerTurn: true` makes exact streaming/finality gating mandatory and removes
useful delivery control from a precision-sensitive reminder.

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

Before this research, the shared global instructions strongly required
phase-end maintenance but only said to "check context pressure" after several
large results. An agent could therefore comply while postponing most
maintenance until the end of a long phase. They also did not distinguish
material that was safe to fold from material worth folding immediately.

The readable `AGENTS.source.md` and generated `AGENTS.md` now adopt this policy:

> - Treat phase boundaries, the point before final verification, and completed
>   batches within a long phase as context-maintenance checkpoints. Reassess
>   after several large tool results rather than waiting for phase end or
>   automatic compaction.
> - A checkpoint requires judgment, not necessarily a `context_map` call or a
>   fold. Safe-to-fold material alone is not enough reason to fold, and a no-op
>   assessment satisfies the checkpoint.
> - Fold meaningful completed or superseded bulk when enough subsequent work is
>   likely to reuse the smaller context, or when context-window or quality
>   pressure justifies immediate maintenance.
> - Prefer to piggy-back maintenance on an already-required tool loop. If a
>   final response is imminent and pressure is low, finish instead of creating
>   a maintenance-only round trip.
> - When maintenance is worthwhile, use `context_map` and batch-collapse bulky
>   completed material with resume-quality conclusions. Prefer one useful batch
>   over folding small items individually.
> - Keep governing instructions, the active request, unresolved errors, active
>   evidence, open decisions, and verbatim upcoming needs live.
> - Treat a recent successful pass as satisfying later phase-end checkpoints
>   unless substantial new foldable bulk accumulated.

The user-global Pi file resolves to the generated repository file. The adopted
policy also explicitly interprets context-prune's generic "collapse immediately
once a topic closes" wording as "assess promptly and batch-collapse when
worthwhile," not as a requirement to fold every completed item. This is the
immediate compatibility rule; if context-prune's injected guidance becomes
configurable, align that prompt directly as well.

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

## Recommended implementation sequence

1. Keep context-prune's active "collapse immediately" guidance aligned with the
   adopted safety/materiality/timing policy. The global instructions now supply
   the compatibility interpretation; update the injected prompt directly if it
   becomes configurable.
2. Implement a standalone, visible-but-non-user reminder extension with
   structured debug logging.
3. Use Option A's growth/high-water policy with the piggy-back-first behavior
   from Option B.
4. Track a session-level maintenance baseline and a per-interaction baseline,
   using `agent_start`, `agent_settled`, model selection, session compaction,
   qualifying tool-bearing turns, and positive maintenance without resetting
   cumulative growth on every low-level retry or continuation.
5. Treat a collapse as positive maintenance only when its result reports
   `action === "collapse"`, `ok === true`, and `deltaTokens > 0`; establish a
   fresh usage baseline afterward.
6. Allow another ordinary reminder only after 15,000--25,000 additional tokens;
   use a separate one-shot emergency latch for high absolute utilization.
7. Log trigger cause, reminder/map/result sizes, whether a collapse followed,
   net tokens freed, future call count, and reported input/cache/output token
   categories. Compare those categories with Codex credits or direct API costs
   according to the active provider.
8. Review several long sessions before changing thresholds or adding
   cache-aware scoring.
9. Reconsider `pi-system-reminders` only when there are enough reminder types to
   justify shared discovery and dispatch, or fork it to expose the required
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
