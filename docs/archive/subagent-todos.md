# PDO session that ran into context pressure, didn't drop below 50%/60% anymore, but "N last collapses were too little"-reminder/-mechanism did not trigger

File: /home/felix/.pi/agent/sessions/--home-felix-gits-pale-darks-online--/2026-08-12T16-16-19-192Z_019ff6c2-a4f8-73ea-be05-ee1f0207c8b2.jsonl
ID: 019ff6c2-a4f8-73ea-be05-ee1f0207c8b2

-> tackled once, let's see if enough

# PDO luna max subagent that ignored A/F/U (at least) reminders (and ended up auto-compacting I think (no folds in `/context-status`))

Need to recover from PDO/Pi's session files (if still exists), I think it had `_nav` or `nav_` in its name.

-> tackled once, let's see if enough

# PDO main session that also built up context pressure over time (but maybe not as much?)

File: /home/felix/.pi/agent/sessions/--home-felix-gits-pale-darks-online--/2026-08-13T13-27-52-707Z_019ffb4e-ca82-7796-84a6-3f35b56f7fdf.jsonl
ID: 019ffb4e-ca82-7796-84a6-3f35b56f7fdf

-> I think the reminders are not strong enough language-wise to force/guide
towards "strong/aggressive" (these words work well, we don't use them yet)
context checkpointing.

-> tackled once, let's see if enough

# Subagent spurious errors notes

- nixos-a3o
- nixos-v8n

-> Both have been investigated, not suuper trivial to solve and also not urgent, so decided not to act on them for now. But the beads have lots of detail for future action.

- new one, towards the end, Pi broke during the subagent's context_collapse or something:

File: /home/felix/.pi/agent/sessions/--home-felix-gits-pale-darks-online--/2026-08-15T20-05-44-790Z_01a00707-c4d5-782b-b96f-adffd6b3d675.jsonl
ID: 01a00707-c4d5-782b-b96f-adffd6b3d675

# OpenAI Codex subscription usage visualization in statusline

Also visualize (textually/icons) the over/under of the current % compared to the time until reset.

E.g., 100% remaining usage and 7d would be about 100/7 ~= 14.3 per day as a rough "budget".
So show how much we are under (i.e., still left of daily "budget") or over (i.e., more usage than daily "budget") in the statusline as well.

Probably also "daily usage" would be nice to see, i.e., how much used since I started "today" - hard to say how exactly "today" should be determined, e.g., after midnight might still be the same "day" (for me).

-> all of this (or almost) is added now!

# Need to attack context pressure even stronger I think

E.g., if compaction doesn't compact below 50% or even 40% maybe, already require justification for not doing more.
Not 100% sure but the issue is that context% still keeps going up after multiple compactions and longer work.

File: /home/felix/.pi/agent/sessions/--home-felix-gits-pale-darks-online--/2026-08-15T20-05-44-790Z_01a00707-c4d5-782b-b96f-adffd6b3d675.jsonl
ID: 01a00707-c4d5-782b-b96f-adffd6b3d675
