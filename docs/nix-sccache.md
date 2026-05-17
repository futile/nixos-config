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

## Check sccache Disk Usage

The most reliable way to check whether Nix builds are populating sccache is to
inspect the on-disk cache:

```bash
sudo du -sh /var/cache/ccache /var/cache/ccache/sccache 2>&1
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
