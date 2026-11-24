---
name: design-mockup
description: Build a throwaway interactive HTML mockup so the user can compare and pick visual or interaction variants before anything is specified or implemented. Use when a decision is about look, layout, motion, wording-in-context or interaction flow and several plausible options exist (palettes, fonts, tooltip layouts, HUD placement, animation, multi-step UI flows), or when the user says "mockup", "show me options", "let me compare".
---

# Design Mockup

A mockup turns a visual decision into a pick. It is cheaper than a spec round and far cheaper than reimplementing UI. It is throwaway: never production code, never committed unless the user asks.

## When

- Offer one before writing a spec when the user must judge something by eye or by feel and there are 2+ real options.
- Skip it for decisions with one obvious answer, pure backend behaviour, or wording that can be judged as plain text.
- Text questions still settle rules (when, who, limits); the mockup settles how it looks and moves.

## Build

- One static `index.html` (inline CSS/JS) plus `img/` and `fonts/` next to it. No build step, no network, no framework. Opens via `file://`.
- Put it in the project's ignored scratch area (ask or follow project guidance); copy assets in, do not hotlink.
- Use the product's real tokens: colours, fonts, sizes, spacing, sample content and a real screenshot as backdrop when one exists. Mockups in generic styling mislead.
- Show every variant with the same real content, side by side or switchable. Add controls for each open dimension (variant, size, motion, colour-vision, background) rather than one page per idea.
- Encode the full state in the URL hash (`#v=b&size=1.2&motion=toss`) and show the current hash on the page, so the user can paste back an exact pick.
- Interaction flows: simulate the other parties (server latency, second client) with simple state machines and include named scenarios, including the bad paths (race, cancel, full, error).
- Add `#test` running a small assert-based self-check of the mockup's own logic when it has logic (flows, formatting rules), and print PASS/FAIL on the page.
- Add `#snap` (and named variants like `#snap-grid`) that freezes animations at a representative frame for screenshots.

## Verify yourself

- Screenshot headless and look at the images before handing over:
  `firefox --headless --no-remote --profile "$(mktemp -d)" --window-size=1500,1000 --screenshot /abs/out.png "file:///abs/index.html#snap&v=b"`
  (absolute paths; Chromium `--headless --screenshot` works too).
- Check text fits, nothing overlaps, contrast holds, every control changes something.

## Hand over

- Give the `file://` link, a 3-6 line guide to the controls, your recommendation and why, and the screenshot paths.
- Ask the user to reply with the hash of their pick plus notes. Iterate on the same page.
- Record the chosen hash and decisions where the project tracks decisions (issue, design note, spec), with what the mockup cannot show (engine limits, performance, accessibility gaps).
- The mockup is not a spec: implementation follows the project's normal spec/review flow.
