#!/usr/bin/env bash
set -euo pipefail

target="${1:-}"
wrapper_bin="${2:-}"
python_bin=""

resolve_python_from_wrapper() {
  local wrapper="$1"
  local serena_entry

  serena_entry="$(strings "$wrapper" | rg 'serena-env/bin/serena$' | head -1 || true)"
  if [[ -n "$serena_entry" ]]; then
    head -1 "$serena_entry" | sed 's|^#!||'
    return 0
  fi

  python3 - "$wrapper" <<'PY' || true
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(errors="replace")
match = re.search(r'exec -a "\$0" "([^"]+\.serena-wrapped)"', text)
if not match:
    raise SystemExit(1)

shebang = Path(match.group(1)).read_text(errors="replace").splitlines()[0]
if not shebang.startswith("#!"):
    raise SystemExit(1)
print(shebang[2:])
PY
}

if [[ -n "$target" ]]; then
  if head -c 2 "$target" 2>/dev/null | rg -q '#!'; then
    shebang="$(head -1 "$target")"
    if [[ "$shebang" == *python* ]]; then
      python_bin="$target"
    else
      wrapper_bin="$target"
    fi
  else
    wrapper_bin="$target"
  fi
fi

if [[ -n "$wrapper_bin" && -z "$python_bin" ]]; then
  python_bin="$(resolve_python_from_wrapper "$wrapper_bin")"
fi

if [[ -z "$python_bin" ]]; then
  resolved="$(
    python3 - <<'PY'
import re
import shutil
import subprocess
from pathlib import Path

for p in Path("/proc").glob("[0-9]*/cmdline"):
    try:
        cmd = p.read_bytes().replace(b"\0", b" ").decode("utf-8", "replace")
    except Exception:
        continue
    if "serena" not in cmd or "start-mcp-server" not in cmd:
        continue
    parts = cmd.split()
    if parts:
        print(parts[0])
        print("")
        raise SystemExit(0)

serena = shutil.which("serena")
if serena:
    resolved = subprocess.check_output(["readlink", "-f", serena], text=True).strip()
    text = Path(resolved).read_text(errors="replace")
    match = re.search(r'exec -a "\$0" "([^"]+\.serena-wrapped)"', text)
    if match:
        wrapper = match.group(1)
        shebang = Path(wrapper).read_text(errors="replace").splitlines()[0]
        if shebang.startswith("#!"):
            print(shebang[2:])
            print(wrapper)
            raise SystemExit(0)

raise SystemExit("No running Serena MCP python process or installed Serena wrapper found; pass a Python executable or Serena wrapper explicitly.")
PY
  )"
  python_bin="$(sed -n '1p' <<<"$resolved")"
  wrapper_bin="$(sed -n '2p' <<<"$resolved")"
fi

export PYSTRAY_BACKEND=appindicator
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-niri}"
export DESKTOP_SESSION="${DESKTOP_SESSION:-niri}"
export XDG_SESSION_DESKTOP="${XDG_SESSION_DESKTOP:-niri}"
export XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-wayland}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" && -S "$XDG_RUNTIME_DIR/bus" ]]; then
  export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
fi

if [[ -n "$wrapper_bin" ]]; then
  gi_typelib_path="$(strings "$wrapper_bin" | rg '^/nix/store/.+lib/girepository-1.0' | head -1 || true)"
  xdg_data_dirs="$(strings "$wrapper_bin" | rg '^/nix/store/.+share/gsettings-schemas' | head -1 || true)"
  gio_extra_modules="$(strings "$wrapper_bin" | rg '^/nix/store/.+lib/gio/modules' | paste -sd: - || true)"

  if [[ -n "$gi_typelib_path" ]]; then
    export GI_TYPELIB_PATH="$gi_typelib_path"
  fi
  if [[ -n "$xdg_data_dirs" ]]; then
    export XDG_DATA_DIRS="$xdg_data_dirs"
  fi
  if [[ -n "$gio_extra_modules" ]]; then
    export GIO_EXTRA_MODULES="$gio_extra_modules"
  fi
fi

echo "python: $python_bin"
echo "wrapper: ${wrapper_bin:-<none>}"
echo "PYSTRAY_BACKEND=$PYSTRAY_BACKEND"

"$python_bin" - <<'PY'
import pystray

print(f"pystray backend: {pystray.Icon.__module__}")

from gi.repository import Gtk, AyatanaAppIndicator3

print("gtk/appindicator typelibs: ok")

from serena.dashboard import SerenaDashboardTrayManager

manager = SerenaDashboardTrayManager()
print(f"constructed: {manager.__class__.__name__}")
PY
