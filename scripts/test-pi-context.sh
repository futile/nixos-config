#!/usr/bin/env bash
# Verify locked upstream/local code against Pi 1.0.0 without loading live extensions.
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
patch -d "$work/upstream" --batch --fuzz=0 -p1 \
  < "$repo/patches/pi-infinite-context-restart.patch"
cp -R "$repo/dotfiles/pi/extensions/context-pressure" "$work/upstream/extensions/context-pressure"
cp -R "$repo/dotfiles/pi/extensions/pi-restart-in-dir" "$work/upstream/extensions/pi-restart-in-dir"
cd "$work/upstream"
nice -n 19 nix develop --no-write-lock-file -c bash -euo pipefail -c '
  npm ci --ignore-scripts --no-audit --no-fund
  # Upstream devDependencies are 0.87.0; only this disposable workspace targets our CLI SDK.
  node --input-type=module -e '\''
    import { readFileSync, writeFileSync } from "node:fs";
    const pkg = JSON.parse(readFileSync("package.json", "utf8"));
    for (const name of ["pi-ai", "pi-agent-core", "pi-coding-agent", "pi-tui"])
      pkg.devDependencies[`@earendil-works/${name}`] = "1.0.0";
    writeFileSync("package.json", JSON.stringify(pkg, null, 2));
  '\''
  npm install --ignore-scripts --no-audit --no-fund --package-lock=false
  npm ls @earendil-works/pi-coding-agent @earendil-works/pi-ai @earendil-works/pi-agent-core @earendil-works/pi-tui --depth=0
  npm run ci
' 2>&1 | tee "$work/ci.log"
