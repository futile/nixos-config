# Headroom Codex NixOS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` if this plan is resumed in a fresh session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Package Headroom declaratively for `nixos-work`, run its proxy as a user service, and route an opt-in Codex alias through that proxy without letting `headroom wrap codex` mutate repo-managed files.

**Architecture:** Headroom is installed from a pinned upstream release as `my-custom-packages.headroom`. Home Manager installs the package, starts `headroom proxy --port 8787` as a user service, and exposes `codex-headroom` as the opt-in fish alias. Codex provider and Headroom MCP settings live in the repo-owned Codex TOML so `~/.codex/config.toml` remains declarative.

**Tech Stack:** Nix flakes, custom Nix package, Home Manager, systemd user service, fish aliases, Codex `config.toml`, Headroom `headroom-ai`.

---

## Decisions

- Pin Headroom to a concrete release rather than a branch.
- Start without `--memory`, `--learn`, `--code-graph`, or Serena.
- Keep existing Nix `rtk` as the RTK source; do not let Headroom inject RTK guidance into `AGENTS.md`.
- Prefer declarative config over `headroom wrap codex` runtime edits because `~/.codex/config.toml` and `~/.codex/AGENTS.md` are Home Manager symlinks into this repository.
- Use `codex-headroom` as the opt-in command. Do not replace `codex`.

## Tasks

### Task 1: Durable Tracking

**Files:**
- Create: `docs/superpowers/plans/2026-05-27-headroom-codex-nixos.md`

- [x] **Step 1: Create this plan and progress checklist**

### Task 2: Package Headroom

**Files:**
- Create: `custom-packages/headroom.nix`
- Modify: `flake.nix`
- Modify: `modules/core.nix`

- [x] **Step 1: Inspect upstream release/build metadata**
- [x] **Step 2: Add package expression pinned to a release**
- [x] **Step 3: Expose package as `.#headroom` and `pkgs.my-custom-packages.headroom`**
- [x] **Step 4: Build package with `nix build .#headroom --no-link`**

### Task 3: Home Manager Integration

**Files:**
- Modify: `home-modules/codex-token-optimization.nix`

- [x] **Step 1: Add Headroom to `home.packages`**
- [x] **Step 2: Add `systemd.user.services.headroom` for `headroom proxy --port 8787`**
- [x] **Step 3: Keep service minimal: no memory, learn, code graph, or Serena**

### Task 4: Codex Config

**Files:**
- Modify: `dotfiles/codex/hosts/nixos-work/config.toml`

- [x] **Step 1: Add Headroom provider for Codex HTTP and WebSocket traffic**
- [x] **Step 2: Add Headroom MCP server for retrieval/stats tools**
- [x] **Step 3: Preserve existing context-mode and codebase-memory-mcp configuration**

### Task 5: Fish Alias

**Files:**
- Modify: `home-modules/fish.nix`

- [x] **Step 1: Add `codex-headroom` alias after declarative Codex config exists**
- [x] **Step 2: Keep ordinary `codex` unchanged**

### Task 6: Validation

**Commands:**
- `nix build .#headroom --no-link`
- `just format-check`
- `just check`
- `just build`

- [x] **Step 1: Run package build**
- [x] **Step 2: Run formatter check**
- [x] **Step 3: Run flake check**
- [x] **Step 4: Run host build**
- [x] **Step 5: Record any failures or follow-up work in this document**

## Progress Log

- 2026-05-27: Plan created. Upstream Headroom Codex support had already been investigated; key risk is runtime mutation of repo-managed Codex files.
- 2026-05-27: Added initial `custom-packages/headroom.nix` pinned to `v0.22.3` and exposed it through flake packages and `my-custom-packages`. The expression starts with a fake Rust vendor hash for iterative bring-up.
- 2026-05-27: First `nix build .#headroom --no-link` reached Rust vendoring and reported cargo vendor hash `sha256-WQBvil0bsS6/Z6b+uRauwOQq4VZ57VwAoghcyFdVgLE=`.
- 2026-05-27: Second build failed because upstream enables `fastembed`'s `ort-download-binaries-rustls-tls`, causing `ort-sys` to download ONNX Runtime during the sandboxed build. Patched the non-Windows feature to `ort-load-dynamic` and set `ORT_DYLIB_PATH` to Nix's `onnxruntime` library.
- 2026-05-27: Compared nixpkgs ONNX Runtime packages. `magika-cli`, `hyprwhspr-rs`, `fotema`, and `voxtype` use `ORT_STRATEGY = "system"`, `ORT_LIB_LOCATION = "${lib.getLib onnxruntime}/lib"`, and usually runtime `ORT_DYLIB_PATH`/`LD_LIBRARY_PATH` wrapping. Updated Headroom packaging to follow that pattern.
- 2026-05-27: `nice -n 19 nix build .#headroom --no-link` passed after the ONNX Runtime patch.
- 2026-05-27: Added Headroom to `home-modules/codex-token-optimization.nix`, added a minimal `headroom proxy --port 8787` user service, added declarative Codex Headroom provider/MCP config, and added opt-in fish alias `codex-headroom`.
- 2026-05-27: Validation passed: `nice -n 19 nix build .#headroom --no-link`, `nice -n 19 just format-check`, `nice -n 19 just check`, and `nice -n 19 just build`.
- 2026-05-27: Found upstream `v0.22.3` source still reports Python package version `0.9.1`; patched `pyproject.toml` during packaging so `headroom --version` reports `0.22.3`.
- 2026-05-27: Added Headroom to the repo's Rust sccache path: direct `.#headroom` builds now use the flake-level `withRustSccache` wrapper, and `nixos-work` wraps `pkgs.my-custom-packages.headroom` via `my.rustSccache.customPackageNames`.
- 2026-05-27: Verified sccache wiring: `.#headroom` evaluates with `RUSTC_WRAPPER` set to the Nix `sccache` binary and `SCCACHE_DIR=/var/cache/ccache/sccache`; `nixos-work` evaluates `my.rustSccache.customPackageNames` as `["headroom","llm-wiki"]`.
- 2026-05-27: Final validation passed after sccache wiring: `nice -n 19 nix build .#headroom --no-link --print-build-logs`, `nice -n 19 nix shell .#headroom -c headroom --version`, `nice -n 19 just format-check`, `nice -n 19 just check`, and `nice -n 19 just build`. The final host build produced `/nix/store/k3kkbby88awndakg4ncn6x8ln4434xdc-nixos-system-nixos-work-26.05.20260515.d233902`.
