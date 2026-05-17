# Nix sccache Notes

This repository has a local `my.rustSccache` NixOS module for opt-in Rust
compiler caching. It is useful for large local Rust packages that are built
from source and may need repeated derivation iterations.

The module is intentionally opt-in. Applying sccache broadly to all Rust
packages changes derivation identities and can lose binary cache hits from
substituters. Prefer listing only packages that are expensive and commonly
rebuilt locally.

## Current Cache Location

The local Nix build cache directory is:

```bash
/var/cache/ccache/sccache
```

This path is added to `nix.settings.extra-sandbox-paths` when
`my.rustSccache.enable = true`, so Nix sandbox builders can write sccache
entries there.

## Build nixpkgs Packages With sccache

The `my.rustSccache` module and this repo's package overlay only affect builds
where this repo's NixOS configuration or flake package wrapper is in scope. A
plain `nix build .#llm-wiki` from a separate `~/gits/nixpkgs` checkout will not
automatically use sccache, even if the sandbox can access
`/var/cache/ccache/sccache`. The derivation still needs `RUSTC_WRAPPER` and
`SCCACHE_DIR` set.

For local nixpkgs iteration builds, use the helper script:

```bash
~/nixos/bin/nix-build-sccached llm-wiki -- --no-link --print-build-logs
```

Run it from the nixpkgs checkout. It defaults to importing nixpkgs from the
current directory and wrapping the requested package attributes with a local
overlay.

Multiple attributes can be wrapped in one build:

```bash
~/nixos/bin/nix-build-sccached llm-wiki some-other-package and-another-package -- --no-link
```

To run it from another directory, pass the nixpkgs checkout explicitly:

```bash
~/nixos/bin/nix-build-sccached \
  --nixpkgs-path ~/gits/nixpkgs \
  llm-wiki \
  -- --no-link --print-build-logs
```

You can override the cache directory if needed:

```bash
~/nixos/bin/nix-build-sccached \
  --nixpkgs-path ~/gits/nixpkgs \
  --sccache-dir /var/cache/ccache/sccache \
  llm-wiki \
  -- --no-link
```

Use `--dry-run` to inspect the generated Nix expression without starting a
build:

```bash
~/nixos/bin/nix-build-sccached --nixpkgs-path ~/gits/nixpkgs llm-wiki --dry-run
```

## Check sccache Disk Usage

The most reliable way to check whether Nix builds are populating sccache is to
inspect the on-disk cache:

```bash
sudo du -sh /var/cache/ccache/sccache /var/cache/ccache 2>&1
```

To inspect the directory fanout and ownership:

```bash
sudo find /var/cache/ccache/sccache -maxdepth 2 -type d \
  -printf '%M %u %g %s %TY-%Tm-%Td %TH:%TM %p\n' | head -100
```

Entries owned by `nixbld*` users indicate that Nix sandbox builds are writing to
the cache.

## sccache Statistics Caveat

This command is still useful:

```bash
sudo env SCCACHE_DIR=/var/cache/ccache/sccache \
  /etc/profiles/per-user/felix/bin/sccache --show-stats
```

However, it may show zero compile requests even when the disk cache is being
populated. `sccache --show-stats` reports statistics from the sccache server it
can reach for the current user/session. Nix builds run under `nixbld*` sandbox
users, so a root or normal-user `sccache --show-stats` invocation can talk to a
different server context than the one used by the build.

When the stats output and disk contents disagree, trust the disk contents for
the question "is the Nix build writing cache entries?"

## ccache Statistics

The existing NixOS `programs.ccache` module provides a setgid wrapper for
checking ccache:

```bash
/run/wrappers/bin/nix-ccache --show-stats
```

This reports ccache, not sccache. For Rust packages wrapped by
`my.rustSccache`, expect the sccache directory to grow rather than the ccache
statistics.
