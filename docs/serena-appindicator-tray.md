# Serena AppIndicator Tray Iteration

## Goal

Make Serena's `web_dashboard_interface: tray_manager` show up in the Niri/Quickshell tray by using pystray's AppIndicator backend instead of its XEmbed/Xorg backend.

## Current State

The Codex MCP wrapper now restores the generic desktop/session environment before starting Serena:

- `DISPLAY`
- `WAYLAND_DISPLAY`
- `XDG_CURRENT_DESKTOP`
- `DESKTOP_SESSION`
- `XDG_SESSION_DESKTOP`
- `XDG_SESSION_TYPE`
- `XDG_RUNTIME_DIR`
- `DBUS_SESSION_BUS_ADDRESS`

It intentionally does not export `NIRI_SOCKET`.

With those variables restored, Serena's tray-manager process starts and listens on its local management port. Without forcing a backend, pystray selects `_xorg`, which creates an XEmbed tray icon. The current Niri/Quickshell tray exposes a StatusNotifier watcher, so the XEmbed icon is not visible there.

Forcing `PYSTRAY_BACKEND=appindicator` on the current installed Serena makes the failure explicit:

```text
ImportError: this platform is not supported: No module named 'gi'
```

## Small Repro

Run against the current installed Serena:

```sh
scripts/repro-serena-appindicator-backend.sh
```

Expected current installed failure:

```text
ImportError: this platform is not supported: No module named 'gi'
```

Target success:

```text
pystray backend: pystray._appindicator
constructed: SerenaDashboardTrayManager
```

The script accepts either a Python executable or a Serena wrapper as its first argument, so it can be pointed at an upstream/local Serena build:

```sh
scripts/repro-serena-appindicator-backend.sh /path/to/serena-python
scripts/repro-serena-appindicator-backend.sh /path/to/serena-wrapper
```

Passing the wrapper is the stronger test. The bare Python executable can prove whether `import gi` exists, but GTK/AppIndicator typelibs come from the executable wrapper's `GI_TYPELIB_PATH`.

## Recommended Iteration Path

Use a local upstream Serena checkout and override this repo's flake input while testing:

```sh
git clone https://github.com/oraios/serena ~/gits/serena
nix build --override-input serena path:/home/felix/gits/serena .#serena --no-link
```

This keeps the test target close to what an upstream merge request would modify. Prefer this over switching to `custom-packages/serena-custom.nix`, because this repo currently consumes upstream Serena's own flake via `flake-inputs.serena.packages.${system}.serena`.

## Nix Fix Shape

pystray's Linux backend order is:

```python
candidates = [appindicator, gtk, xorg]
```

The AppIndicator backend imports:

```python
import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk

try:
    gi.require_version("AppIndicator3", "0.1")
    from gi.repository import AppIndicator3 as AppIndicator
except ValueError:
    gi.require_version("AyatanaAppIndicator3", "0.1")
    from gi.repository import AyatanaAppIndicator3 as AppIndicator
```

Dependencies/wrapping:

- Python: `pygobject3`
- Native/GI: `gtk3`
- AppIndicator typelib: `libayatana-appindicator` or old `libappindicator-gtk3`
- GI support/wrapping: `gobject-introspection` plus `wrapGAppsHook3` or equivalent runtime environment for `GI_TYPELIB_PATH`, `XDG_DATA_DIRS`, etc.

The `dbus-python` package is probably not the key dependency. pystray's D-Bus use is through GI/Gio under `_util/notify_dbus.py`, which requests the `DBus-1.0` typelib.

The local upstream checkout currently uses this approach:

- Add a Linux-only `pystray` override that adds `pygobject3` to `pystray.passthru.dependencies`, because `pyproject-nix`'s `mkVirtualEnv` resolves virtualenv contents through `passthru.dependencies`.
- Import `pycairo` and `pygobject3` from nixpkgs with `pyproject-nix.build.hacks.nixpkgsPrebuilt`, and give them pyproject-nix-shaped dependency metadata. This is preferable to the earlier `symlinkJoin` shim because `nixpkgsPrebuilt` is the first-party adapter for reusing packages built by nixpkgs' Python infrastructure.
- Replace the upstream `runCommand "serena"` package with a tiny `stdenv.mkDerivation`. `runCommand` did not run the normal fixup hooks, so `gappsWrapperArgs` only contained `GIO_EXTRA_MODULES`; the `stdenv.mkDerivation` version gets the full `GI_TYPELIB_PATH` including GTK and Ayatana AppIndicator.
- Keep all of this Linux-specific with `lib.optionalAttrs pkgs.stdenv.isLinux`, `lib.optionals pkgs.stdenv.isLinux`, and `lib.optionalString pkgs.stdenv.isLinux`.

The relevant nixpkgs precedent is:

- `pkgs/development/python-modules/pystray/default.nix`: `pygobject3`, `gtk3`, and `libayatana-appindicator` are propagated on Linux.
- `pkgs/applications/video/plex-mpv-shim/default.nix` and `pkgs/applications/video/jellyfin-mpv-shim/default.nix`: use `wrapGAppsHook3`, `gobject-introspection`, `dontWrapGApps = true`, and feed `gappsWrapperArgs` into the final Python application wrapper for pystray/AppIndicator.
- `pkgs/development/python-modules/pygobject/3.nix`: `pygobject3` propagates `pycairo`, so the pyproject-nix bridge should preserve that Python dependency edge.

The relevant pyproject-nix references are:

- <https://pyproject-nix.github.io/pyproject.nix/builders/overriding.html>: runtime dependencies for lock-file packages are represented with `passthru.dependencies`.
- <https://pyproject-nix.github.io/pyproject.nix/build/packages.html>: `mkVirtualEnv` consumes a dependency spec such as `{ foo = [ "extra" ]; }`.
- <https://pyproject-nix.github.io/uv2nix/usage/getting-started.html>: uv2nix composes a Python package set from pyproject-nix builders plus overlays, then builds a virtualenv with `mkVirtualEnv`.
- `pyproject-nix.build.hacks.nixpkgsPrebuilt`: adapts a package output built by nixpkgs' Python infrastructure for use in a pyproject-nix package set.

## SymlinkJoin Review

The first working patch used:

```nix
pygobject3 = pkgs.symlinkJoin {
  name = "${python.pkgs.pygobject3.name}-pyproject";
  paths = [ python.pkgs.pygobject3 ];
  passthru = {
    dependencies = { };
    optional-dependencies = { };
    dependency-groups = { };
  };
};
```

That is defensible as a local bridge because it provides both a store path and the pyproject-nix-shaped `passthru.dependencies` attrset that `mkVirtualEnv` expects. However, it is not the best upstream version:

- It is ad hoc rather than using pyproject-nix's explicit nixpkgs adapter.
- It drops the `pygobject3 -> pycairo` Python dependency edge.
- It is less self-explanatory to maintainers reviewing a pyproject-nix flake.

The preferred upstream shape is:

```nix
pyprojectHacks = pkgs.callPackage pyproject-nix.build.hacks { };

pycairo = pyprojectHacks.nixpkgsPrebuilt {
  from = python.pkgs.pycairo;
  prev = {
    passthru = {
      dependencies = { };
      optional-dependencies = { };
      dependency-groups = { };
    };
  };
};

pygobject3 = pyprojectHacks.nixpkgsPrebuilt {
  from = python.pkgs.pygobject3;
  prev = {
    passthru = {
      dependencies = {
        pycairo = [ ];
      };
      optional-dependencies = { };
      dependency-groups = { };
    };
  };
};
```

This version has been built and passed the same AppIndicator repro as the `symlinkJoin` version.

## Validation

First validate the bare current failure:

```sh
scripts/repro-serena-appindicator-backend.sh /path/to/python
```

Then validate the local upstream build through the Serena wrapper:

```sh
nix build --override-input serena path:/home/felix/gits/serena .#serena --no-link --print-out-paths
scripts/repro-serena-appindicator-backend.sh /nix/store/...-serena-with-editor-tools/bin/.serena-wrapped
```

Validated local target output:

```text
pystray backend: pystray._appindicator
gtk/appindicator typelibs: ok
constructed: SerenaDashboardTrayManager
```

The repro currently emits dconf warnings from this sandbox because `/run/user/1000/dconf/user` is read-only here. Those warnings did not prevent pystray from selecting the AppIndicator backend or importing GTK/Ayatana typelibs.

Then restart Codex and check Serena's process logs. The old failure should be gone:

```text
Dashboard tray manager did not start within the expected time
Failed to register with tray manager
```

Finally, check whether a Serena item appears in the StatusNotifier watcher:

```sh
env XDG_RUNTIME_DIR=/run/user/1000 \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
  busctl --user get-property \
    org.kde.StatusNotifierWatcher \
    /StatusNotifierWatcher \
    org.kde.StatusNotifierWatcher \
    RegisteredStatusNotifierItems
```

If pystray reports `_appindicator` but no tray item appears, inspect the tray-manager child process and Serena dashboard logs before changing dependencies again.

## Upstream MR Plan

Serena's `CONTRIBUTING.md` allows small bug fixes to be submitted directly as pull requests. This is a single Nix packaging bug fix, so an issue-first discussion should not be necessary unless maintainers push back on scope.

1. Prepare the branch:

   ```sh
   cd /home/felix/gits/serena
   git status --short
   git switch -c fix-nix-appindicator-tray
   ```

2. Keep the upstream diff focused to `flake.nix`:

   - Use `pyproject-nix.build.hacks.nixpkgsPrebuilt` for `pycairo` and `pygobject3`.
   - Add `pygobject3` to Linux `pystray.passthru.dependencies`.
   - Keep `gtk3`, `libayatana-appindicator`, `gobject-introspection`, and `wrapGAppsHook3` Linux-only.
   - Use `stdenv.mkDerivation` for `packages.serena` so `preFixup` can apply `gappsWrapperArgs`.
   - Do not include this repo's repro script or Niri/Codex-specific wrapper in the upstream MR.

3. Format and validate:

   ```sh
   nix fmt flake.nix
   env XDG_CACHE_HOME=/tmp/nix-cache nice -n 19 nix flake check /home/felix/gits/serena
   nice -n 19 nix build .#serena --no-link --print-out-paths
   /home/felix/nixos/scripts/repro-serena-appindicator-backend.sh /nix/store/...-serena/bin/serena
   ```

   Expected repro tail:

   ```text
   pystray backend: pystray._appindicator
   gtk/appindicator typelibs: ok
   constructed: SerenaDashboardTrayManager
   ```

4. Commit with the required assisted-by footer:

   ```sh
   git add flake.nix
   git commit -m "flake: support pystray AppIndicator backend on Linux" -m "Assisted-by: gpt-5.5"
   ```

5. Push and open the MR/PR:

   ```sh
   git push -u origin fix-nix-appindicator-tray
   ```

   Suggested title:

   ```text
   flake: support pystray AppIndicator backend on Linux
   ```

   Suggested body:

   ```markdown
   ## Summary

   - add Linux-only GI/AppIndicator runtime support for pystray in the Nix flake
   - adapt nixpkgs `pycairo`/`pygobject3` into the pyproject-nix package set with `nixpkgsPrebuilt`
   - wrap the `serena` executable with `wrapGAppsHook3` args so `GI_TYPELIB_PATH` includes GTK and Ayatana AppIndicator typelibs

   ## Motivation

   When `web_dashboard_interface: tray_manager` is used on a StatusNotifier/AppIndicator-based desktop, pystray needs its AppIndicator backend. In the current Nix package, forcing `PYSTRAY_BACKEND=appindicator` fails because `gi`/GTK/AppIndicator runtime support is not available in the virtualenv/wrapper.

   ## Validation

   - `nix fmt flake.nix`
   - `env XDG_CACHE_HOME=/tmp/nix-cache nice -n 19 nix flake check /home/felix/gits/serena`
   - `nice -n 19 nix build .#serena --no-link --print-out-paths`
   - external repro confirmed:
     - `pystray backend: pystray._appindicator`
     - `gtk/appindicator typelibs: ok`
     - `constructed: SerenaDashboardTrayManager`
   ```

   Mention that the change is limited to Nix packaging and Linux-only paths. Non-Nix uv installs still need distro-level GTK/AppIndicator packages.
