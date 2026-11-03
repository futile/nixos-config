# Nix Daemon Build Scheduling

Notes on keeping the desktop responsive while Nix builds run. Applied on nixos-work:
`nix.daemonCPUSchedPolicy = "batch"` (`hosts/nixos-work/default.nix`); `CPUWeight` is
still unset.

## Where `nice -n 19` applies

Nix uses store `auto`: the local store when `/nix/var/nix` is writable by the caller
(root), otherwise the daemon socket (`nix help-stores`).

- Root (`sudo nixos-rebuild switch`, `just switch`): the CLI builds itself, builders are
  its children and inherit `nice -n 19` (sudo keeps the nice value).
- Normal user (`nix build`, `just build`, `just hm-build`, `nix develop`, direnv): only
  evaluation runs in the niced CLI. Builds and substitutions run in `nix-daemon` at nice 0
  in `system.slice`; the daemon does not take over the client's nice value.

## Options

- `nix.daemonCPUSchedPolicy` (`other` default | `batch` | `idle`), inherited by builders:
  - `batch` (`SCHED_BATCH`): same CPU share, but builders do not preempt running tasks
    on wakeup, so interactive tasks are disturbed less. Little throughput loss.
  - `idle` (`SCHED_IDLE`): builders run on otherwise idle CPU only (weight ~0.3 % of
    nice 0). Builds, and commands waiting for them, can nearly stall while the machine is
    busy.
- `nix.daemonIOSchedClass` (`best-effort` | `idle`) and `nix.daemonIOSchedPriority`:
  ionice for builders. Only honoured by the BFQ IO scheduler; this host's NVMe uses `none`
  and ZFS issues IO from its own threads, so it has no effect here.
- `systemd.services.nix-daemon.serviceConfig.CPUWeight = 20;`: `system.slice` and
  `user.slice` both have weight 100, so under contention daemon builds can take about half
  of the CPU from the whole user session. A lower weight caps that share only under
  contention (work-conserving). Stronger than `batch`; both combine.

Suggested if daemon builds cause lag: `daemonCPUSchedPolicy = "batch"` plus `CPUWeight = 20`.

## Cargo builds on nixos-work

`hosts/nixos-work/cargo-build-slice.nix` wraps rustup's `cargo` so every cargo command runs
in the user unit `background-build.slice` (child of `background.slice`, `CPUWeight=30`);
`sccache.service` runs there too. Programs started by `cargo run` get an env runner that
moves them back to `app.slice`. Opt out with `CARGO_NO_BUILD_SLICE=1`. `app.slice`
(8G) and `session.slice` (1G) have `MemoryLow`, with 9G on the ancestors
(`user.slice`, `user-.slice`, `user@.service`), and the ZFS ARC is capped at 8 GiB
(kernel parameter, needs a reboot or a root write to `/sys/module/zfs/parameters/zfs_arc_max`).
