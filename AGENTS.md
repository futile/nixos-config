# Agent Notes

This file documents non-obvious decisions and context that are useful for AI agents
(or future-me) working on this repository.

## macOS Privacy Permissions (`hosts/hm-cf/`)

### Problem

macOS Sequoia locks TCC (Transparency, Consent & Control) permissions behind SIP.
After every Nix package update, apps like WezTerm and Brave lose certain permissions
because the app bundle is replaced at a new Nix store path.

Permissions needed:

| App | Permission | Reason |
|---|---|---|
| WezTerm | Developer Tools | XProtect bypass for child processes (`cargo build`/`test`) |
| WezTerm | App Management | Required for home-manager shell integration |
| WezTerm | Accessibility | General accessibility access |
| Neovide | Developer Tools | XProtect bypass for child processes (`cargo build`/`test`) |
| Brave Browser | Screen Recording | Lost after each Nix update otherwise |

### Solution

`hosts/hm-cf/setup-macos-permissions.sh` tracks MD5 hashes of the relevant app
binaries in `~/.local/state/hm-tcc-hashes/`. On each run it compares current hashes
against stored ones and only acts on apps whose binary changed. For each affected app
it:

1. Runs `tccutil reset <service> <bundle-id>` to remove the stale TCC entry (no sudo
   required — this is what previously required manual deletion in System Settings).
2. Opens the correct System Settings privacy pane.
3. Waits for you to click `+`, select the app, and press Enter.

Run it with:
```sh
just setup-macos-permissions          # only prompts for changed apps
just setup-macos-permissions --force  # opens all panes regardless
```

`home-manager switch` runs the script in `--check-only` mode (non-interactive): if any
binary has changed it prints a reminder to run `just setup-macos-permissions`, otherwise
it is silent. `tccutil reset` is intentionally not called in `--check-only` mode —
resetting without immediately re-granting would leave the app with no permission.

### Why not a .mobileconfig profile?

This was attempted. The `PrivacyPreferencesPolicyControl` payload
(`com.apple.TCC.configuration-profile-policy`) looks like the right tool — it can
grant TCC permissions declaratively — but it is blocked on Sequoia with:

> "The profile must originate from a user approved MDM server."

Manual installation (double-clicking a `.mobileconfig`) is rejected for this specific
payload type regardless of `PayloadScope = System`. It requires being pushed by an
enrolled MDM server.

### Why not a self-hosted MDM (MicroMDM/NanoMDM)?

A Mac can only be enrolled in **one MDM server at a time**. This machine is already
DEP-enrolled with Cloudflare's Jamf (`askit.jamfcloud.com`). Enrolling in a second
MDM would require unenrolling from Jamf first, which is not appropriate on a work
machine.

### Why not ask Cloudflare IT to push the profile via Jamf?

Theoretically the cleanest path — Jamf could push a `PrivacyPreferencesPolicyControl`
profile silently with no user interaction required. Not pursued as it is unlikely to
be approved for personal development tool permissions.

### Why not Apple Configurator 2?

Apple Configurator 2 manages *other* Apple devices connected via USB (iPhones, iPads,
Apple TVs). It has no mechanism to push profiles to the Mac it is running on.

### Why not disable SIP?

Not appropriate on a company-managed machine.

### Do permissions need to be re-granted after Nix updates?

Yes, when the binary changes. TCC permissions are stored against the app's binary
identity. When home-manager updates an app (`copyApps` replaces the bundle), macOS
resets the permissions for that app.

The script detects this automatically by storing MD5 hashes of the relevant binaries
in `~/.local/state/hm-tcc-hashes/`. After `home-manager switch`, if a hash changed
you will see a reminder in the activation output. Run `just setup-macos-permissions`
to re-grant only the affected permissions.

### XProtect and Rust build performance

The Developer Tools permission is particularly impactful for `cargo test`, which
spawns large numbers of short-lived test binaries. XProtect scans each one at launch
time. With the permission granted, processes spawned by WezTerm/Neovide skip the
scan entirely, dramatically reducing test run times.

Reference: https://nnethercote.github.io/2025/09/04/faster-rust-builds-on-mac.html
