---
name: caveman-compress
description: >
  Compress natural language memory files (CLAUDE.md, AGENTS.md, todos, preferences)
  into caveman format to save input tokens. Preserves technical substance, code,
  URLs, and structure. Supports in-place mode with backup and explicit
  source-to-output mode without backup.
---

# Caveman Compress

## Purpose

Compress natural language files into caveman-speak to reduce input tokens.
Default mode overwrites original and saves `<filename>.original.md`.
Explicit output mode writes compressed content to a separate file, leaves source
unchanged, and creates no backup.

## Trigger

`/caveman-compress <filepath>`, `/caveman-compress <source> to <output>`, or
when user asks to compress a memory/instruction file.

## Process

1. Helper scripts live in `scripts/` next to this `SKILL.md`. If path is not
   immediately available, search for `scripts/__main__.py` next to this file.

2. Resolve input path to absolute path. If user provided separate output path
   (`SOURCE to OUTPUT`, `--output OUTPUT SOURCE`, or equivalent), resolve output
   path too. Confirm input is supported natural-language file and not
   `*.original.md`.

3. Choose mode:
   - In-place mode: no output path or output path same as input. Create
     `<filename>.original.md` backup before overwriting.
   - Explicit output mode: output path differs from input. Leave input
     unchanged. Do not create `<input>.original.md` or any backup unless user
     explicitly asks.

4. Do not run full `python3 -m scripts <absolute_filepath>` pipeline unless
   supported LLM CLI is available and using in-place mode. That pipeline may call
   external model CLI such as `claude` and only supports in-place backup
   semantics. If unavailable or using explicit output mode, use Current Agent
   Workflow.

## Current Agent Workflow

- Run detection on input if useful: `python3 -m scripts.detect <absolute_input>`
  or inspect `scripts/detect.py` behavior.
- Read input file.
- In-place mode only: if backup `<filename>.original.md` already exists, abort
  unless user explicitly approves overwriting/removing it. Write exact original
  bytes to backup.
- Compress input content yourself, following Compression Rules.
- Preserve all protected regions exactly.
- Write compressed content to target path: input path for in-place mode, output
  path for explicit output mode.
- Run validation: `python3 -m scripts.validate <original_reference>
  <compressed_path>`. Use backup path as `original_reference` in in-place mode;
  use input path in explicit output mode.
- If validation reports errors, fix only listed errors. Do not recompress entire
  file.
- Retry targeted fixes up to 2 times.
- If still failing after 2 retries, restore original from backup in in-place mode
  or remove failed output in explicit output mode, and report failure.

## External CLI Workflow

If supported model CLI is explicitly available and user wants automated in-place
compression, from directory containing this `SKILL.md` run:

```sh
python3 -m scripts <absolute_filepath>
```

If CLI fails because model command is missing, fall back to Current Agent
Workflow.

## Return Result

- input path
- compressed output path
- backup path, or `none` for explicit output mode
- validation result
- brief word-count or size delta when available

## Compression Rules

### Remove

- Articles: a, an, the
- Filler: just, really, basically, actually, simply, essentially, generally
- Pleasantries: "sure", "certainly", "of course", "happy to", "I'd recommend"
- Hedging: "it might be worth", "you could consider", "it would be good to"
- Redundant phrasing: "in order to" -> "to", "make sure to" -> "ensure",
  "the reason is because" -> "because"
- Connective fluff: however, furthermore, additionally, in addition

### Preserve Exactly

- Code blocks, fenced or indented
- Inline code in backticks
- URLs and markdown links
- File paths
- Commands
- Technical terms, library names, API names, protocols, algorithms
- Proper nouns
- Dates, version numbers, numeric values
- Environment variables

### Preserve Structure

- Markdown headings
- Bullet hierarchy
- Numbered lists
- Tables
- Frontmatter/YAML headers

### Compress

- Use short synonyms: "big" not "extensive", "fix" not "implement a solution
  for", "use" not "utilize"
- Fragments OK: "Run tests before commit" not "You should always run tests
  before committing"
- Drop "you should", "make sure to", "remember to"; state action directly
- Merge redundant bullets
- Keep one example when multiple examples show same pattern

## Critical Rule

Anything inside fenced code blocks must be copied exactly. Do not remove
comments, remove spacing, reorder lines, shorten commands, or simplify anything.

Inline code must be preserved exactly.

If file contains code blocks, treat code blocks as read-only regions. Only
compress text outside them. Do not merge sections around code.

## Boundaries

- Only compress natural language files: `.md`, `.txt`, `.typ`, `.typst`,
  `.tex`, or extensionless files.
- Never modify unsupported code/data files such as `.py`, `.js`, `.ts`, `.json`,
  `.yaml`, `.yml`, `.toml`, `.env`, `.lock`, `.css`, `.html`, `.xml`, `.sql`,
  `.sh`.
- If file has mixed prose and code, compress only prose.
- If unsure whether content is code or prose, leave it unchanged.
- Never compress `*.original.md`.
