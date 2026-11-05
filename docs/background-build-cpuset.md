# Background Build CPU Reservation

Status: implemented in `hosts/nixos-work/default.nix` (delegation) and
`hosts/nixos-work/home.nix` (slice, `build-cpu-idle.service`); the delegation needs a
reboot. Host: nixos-work. Related:
[`nix-daemon-scheduling.md`](nix-daemon-scheduling.md) (cargo wrapper, `background-build.slice`).

## Goal

Keep one physical core free for interactive use while user builds run in
`background-build.slice` (cargo wrapper from `hosts/nixos-work/cargo-build-slice.nix`, `sccache.service`).
Lift the restriction automatically while the session is idle, e.g. overnight builds,
with noctalia's Caffeine left on. nix-daemon builds (`system.slice`) are out of scope.

## Topology

Ryzen 7 PRO 6850U: 8 cores, 2 SMT threads each, 16 logical CPUs. SMT siblings are
pairs `(0,1) (2,3) … (14,15)` (`lscpu -e`).

- `AllowedCPUs=2-15` reserves physical core 0 (both threads) and leaves builds 14 of
  16 threads (roughly 85–90 % throughput).
- `AllowedCPUs=1-15` would free only CPU 0. Its sibling CPU 1 keeps running build work,
  so interactive work on CPU 0 shares the core's execution units and L1/L2. Weaker.

amd-pstate `prefcore` ranks cores 1 and 5 (CPUs 2-3, 10-11) highest (196, core 0 is
191). Reserving one of those instead (`0-1,4-15`) is a possible later tweak.

## Mechanism: cpuset, not quota

- `AllowedCPUs=` (cpuset) is a hard placement limit. A free core is available at any
  instant, and woken interactive threads land there. Changing it at runtime migrates
  running tasks immediately, including compiler children of the long-running
  `sccache.service`.
- `CPUQuota=` (`cpu.max`) only limits CPU time per period (default 100 ms): with
  `1400%` a build may still occupy all 16 CPUs for ~87.5 ms of each period, so it does
  not guarantee a free core.
- Complements the existing `CPUWeight=30` of `background.slice`; does not replace it.

### Prerequisite: delegate `cpuset` to the user manager

Upstream `user@.service` has `Delegate=pids memory cpu`; on this host
`DelegateControllers=cpu memory pids` and `user.slice` enables only
`cpu io memory pids`. A user-unit `AllowedCPUs=` therefore has no effect today.

Add `systemd.services."user@".serviceConfig.Delegate = "cpuset";` next to the existing
`MemoryLow` in `hosts/nixos-work/default.nix`. `Delegate=` controller lists accumulate
(`config_parse_delegate` ORs the mask; only an empty value resets), so this extends the
upstream list. Check with `systemctl show user@1000.service -p DelegateControllers`.

Applies after a reboot: `user@.service` has `X-RestartIfChanged=false` and only
restarts once all sessions of the user end (two sessions, no linger).

Implications:

- cpuset becomes enabled on `user.slice` and `user-1000.slice` unconditionally
  (delegated controllers are also enabled for parent and sibling units), so session
  scopes get cpuset files too, unrestricted. Below `user@1000.service` it is enabled
  only on the path to a unit that sets `AllowedCPUs=`.
- Security: the user can only narrow CPUs inside its own subtree. The delegated
  cgroup's own interface files stay root-owned, `cpuset.cpus.partition` "is owned by the
  parent cgroup and is not delegatable", and exclusive CPUs must come from the parent's
  exclusive set (kernel `cgroup-v2.rst`).
- Overhead: small hooks on fork/attach/affinity changes; negligible at a few toggles
  per day.
- Affinity: cpuset overrides and restricts per-task affinity. Since `da019032819a1`
  ("sched: Enforce user requested affinity", ~v6.2) explicitly set affinities are kept
  and intersected, and tasks widen again when the cpuset grows
  ([systemd#23748](https://github.com/systemd/systemd/issues/23748)). Host runs 7.x.

## Idle detection: dedicated swayidle instance

systemd cannot detect Wayland idleness by itself: logind `IdleHint` only changes when a
session client sets it (currently `IdleHint=no`). The source of truth is niri's
`ext-idle-notify-v1`, consumed by swayidle.

### Why not the existing swayidle (Caffeine)

noctalia 5.3 implements Caffeine as a logind `idle` block inhibitor
(`systemd-inhibit --list`: `noctalia … idle Caffeine block`; log:
`idle inhibitor enabled via logind`). niri ignores logind inhibitors, but swayidle
1.9 does not: with logind support it checks `BlockInhibited` before enabling timeouts
and disables them when an `idle` inhibitor appears. The existing service
(`home-modules/niri.nix`) uses `before-sleep`, so it has a logind connection and logs
`Not enabling timeouts: idle inhibitor found` while Caffeine is on.

An ad-hoc `swayidle timeout 3 … resume …` did fire with Caffeine on, but only because
without logind events swayidle has no bus connection; the inhibitor check then fails
(`Failed to parse get BlockInhibited property: Invalid argument`) and is skipped.
Relying on that error path is fragile.

### Plan

A separate user service in `hosts/nixos-work/home.nix` (the Home Manager swayidle module
supports one instance), e.g. `build-cpu-idle.service`:

- Binary: `pkgs.swayidle.override { systemdSupport = false; }` (`-Dlogind=disabled`),
  so logind inhibitors (Caffeine) are ignored by design. Wayland
  `zwp_idle_inhibitor_v1` is still honoured (timeouts use `get_idle_notification`), so
  video playback keeps the session "not idle", which is desired.
- `swayidle -w timeout 300 <lift> resume <restrict>`; `-w` serialises the commands, so
  a lift and a restore cannot race.
  - lift: `systemctl --user set-property --runtime background-build.slice AllowedCPUs=0-15`
  - restrict: same with `AllowedCPUs=2-15`
- Use absolute `systemctl` paths, as `niri.nix` does (nixpkgs patches swayidle to run
  commands with an absolute bash, so no `PATH` is needed).
- Lift with `0-15`, not an empty value: an empty `AllowedCPUs=` overrides correctly but
  makes systemd drop the cpuset controller for the slice, so `EffectiveCPUs` reads empty
  and the controller toggles on every switch.
- Define the restricted value once in Nix and use it for the slice's persistent
  `AllowedCPUs=` and the restore commands; otherwise the runtime drop-in shadows later
  Nix changes until `user@1000` restarts.
- Safe default: the persistent slice value is restricted, and the service runs the
  restore as `ExecStartPre=-…` and `ExecStopPost=-…`. swayidle runs its resume command on
  SIGTERM, but `ExecStopPost` also covers SIGKILL and crashes, so it is the restore
  that matters.
- Runtime drop-ins live under `$XDG_RUNTIME_DIR/systemd/user.control` until
  `user@1000` stops.
- Do not toggle with `systemctl --user revert`: it triggers a daemon-reload per toggle
  and would also remove any Home Manager `background-build.slice.d/` drop-ins.

Other notes:

- Caffeine still suppresses noctalia's own idle behaviours (all disabled here) and
  logind `IdleAction` (`ignore`). Do not implement the toggle as a noctalia
  `action = "command"` idle behaviour: Caffeine would suppress it too.
- Caffeine does not block lid handling: `HandleLidSwitch=suspend` (docked: `ignore`).
  With the lid closed and undocked, the machine suspends regardless.

## Caveats

- Parallelism is fixed at start: cargo/rustc size jobs from `sched_getaffinity`. A build
  started while restricted runs `-j14` and does not grow when the limit lifts; one
  started while idle oversubscribes 14 CPUs after resume (harmless).

## Verification (after implementing and rebooting)

- `systemctl show user@1000.service -p DelegateControllers` includes `cpuset`.
- `systemctl --user show background-build.slice -p AllowedCPUs -p EffectiveCPUs`
  shows `2-15`, and `cpuset.cpus.effective` exists in the slice's cgroup directory.
- With Caffeine on: `journalctl --user -u build-cpu-idle` shows no
  `Not enabling timeouts`; after the timeout `EffectiveCPUs` is `0-15`, and the first
  input restores `2-15`.
- While a cargo build runs restricted, `ps -o psr` / `top` (last-CPU field) never shows
  CPUs 0-1 for build processes.
- `systemctl --user stop build-cpu-idle` while idle restores `2-15`.
