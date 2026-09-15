#!/usr/bin/env bash
# Verify the locked upstream plus local compatibility without loading live extensions.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/nixos-pi-context-test.XXXXXX")
printf 'Verification artifacts (retained): %s\n' "$work"
source=$(nice -n 19 nix eval --impure --raw --expr \
  "(builtins.getFlake \"$repo\").inputs.pi-infinite-context.outPath")
cp -R "$source" "$work/upstream"
chmod -R u+w "$work/upstream"
patch -d "$work/upstream" --batch --fuzz=0 -p1 \
  < "$repo/patches/pi-infinite-context-enable-nudges.patch"
cp -R "$repo/dotfiles/pi/extensions/context-pressure" "$work/upstream/extensions/context-pressure"
cd "$work/upstream"
nice -n 19 nix develop --no-write-lock-file -c bash -euo pipefail -c '
  npm ci --ignore-scripts --no-audit --no-fund
  npm ls @earendil-works/pi-coding-agent @earendil-works/pi-ai @earendil-works/pi-agent-core @earendil-works/pi-tui --depth=0
  npm run ci
' 2>&1 | tee "$work/ci.log"
