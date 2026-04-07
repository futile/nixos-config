#!/usr/bin/env bash
# Opens System Settings privacy panes for apps whose binaries have changed since
# the last run. TCC permissions are reset by macOS when a Nix update replaces the
# binary, so this script detects which apps changed and only prompts for those.
#
# Permissions managed:
#   • Developer Tools  →  WezTerm, Neovide  (XProtect bypass for cargo build/test)
#   • Screen Recording →  Brave Browser
#   • App Management   →  WezTerm
#
# Safe to run repeatedly. Pass --force to open all panes regardless of changes.
#
# Note: macOS Sequoia does not allow TCC permissions to be granted programmatically
# without MDM (PrivacyPreferencesPolicyControl is blocked with "must originate from
# a user approved MDM server"). The System Settings GUI is the only viable path.

set -euo pipefail

FORCE=0
CHECK_ONLY=0
for arg in "${@}"; do
  case "$arg" in
    --force)      FORCE=1 ;;
    --check-only) CHECK_ONLY=1 ;;  # exit 1 if any binary changed, 0 if all unchanged
  esac
done

APPS_BASE="$HOME/Applications/Home Manager Apps"
HASH_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hm-tcc-hashes"
mkdir -p "$HASH_DIR"

WEZTERM_BIN="$APPS_BASE/WezTerm.app/wezterm-gui"
NEOVIDE_BIN="$APPS_BASE/Neovide.app/Contents/MacOS/.neovide-wrapped"
BRAVE_BIN="$APPS_BASE/Brave Browser.app/Contents/MacOS/Brave Browser"

# Returns 1 if the binary changed (or has never been seen), 0 if unchanged.
binary_changed() {
  local name="$1"
  local bin="$2"
  local hash_file="$HASH_DIR/$name"

  if [[ ! -f "$bin" ]]; then
    echo "Warning: binary not found: $bin" >&2
    return 0  # treat as unchanged to avoid spurious prompts
  fi

  local current
  current=$(md5 -q "$bin")

  if [[ ! -f "$hash_file" ]] || [[ "$(cat "$hash_file")" != "$current" ]]; then
    return 1  # changed
  fi
  return 0  # unchanged
}

# Records the current hash after the user has granted permissions.
record_hash() {
  local name="$1"
  local bin="$2"
  if [[ -f "$bin" ]]; then
    md5 -q "$bin" > "$HASH_DIR/$name"
  fi
}

open_pane() {
  local label="$1"
  local url="$2"
  local apps="$3"

  echo ""
  echo "── $label ──"
  echo "   Add: $apps"
  echo "   Opening System Settings..."
  /usr/bin/open "$url"
  echo "   Press Enter when done (or Ctrl-C to stop here)."
  read -r
}

WEZTERM_CHANGED=0; NEOVIDE_CHANGED=0; BRAVE_CHANGED=0
if [[ $FORCE -eq 1 ]] || ! binary_changed wezterm "$WEZTERM_BIN"; then WEZTERM_CHANGED=1; fi
if [[ $FORCE -eq 1 ]] || ! binary_changed neovide "$NEOVIDE_BIN"; then NEOVIDE_CHANGED=1; fi
if [[ $FORCE -eq 1 ]] || ! binary_changed brave   "$BRAVE_BIN";    then BRAVE_CHANGED=1; fi

if [[ $WEZTERM_CHANGED -eq 0 && $NEOVIDE_CHANGED -eq 0 && $BRAVE_CHANGED -eq 0 ]]; then
  echo "No app binaries have changed — permissions should still be valid."
  echo "Run with --force to open all panes anyway."
  exit 0
fi

# In check-only mode, just signal that changes were detected and exit.
if [[ $CHECK_ONLY -eq 1 ]]; then
  exit 1
fi

echo "┌──────────────────────────────────────────────────────────────────┐"
echo "│  macOS privacy permissions setup for local development tools.    │"
echo "│                                                                  │"
echo "│  The following apps have been updated and need re-granting:      │"
[[ $WEZTERM_CHANGED -eq 1 ]] && \
echo "│    • WezTerm  (Developer Tools, App Management)                  │"
[[ $NEOVIDE_CHANGED -eq 1 ]] && \
echo "│    • Neovide  (Developer Tools)                                  │"
[[ $BRAVE_CHANGED   -eq 1 ]] && \
echo "│    • Brave    (Screen Recording)                                 │"
echo "│                                                                  │"
echo "│  Each step opens a System Settings pane. Click '+', select the  │"
echo "│  app, and press Enter to continue to the next pane.             │"
echo "└──────────────────────────────────────────────────────────────────┘"

# Developer Tools: open once for both WezTerm and Neovide if either changed
if [[ $WEZTERM_CHANGED -eq 1 || $NEOVIDE_CHANGED -eq 1 ]]; then
  DEVTOOLS_APPS=""
  [[ $WEZTERM_CHANGED -eq 1 ]] && DEVTOOLS_APPS="WezTerm"
  [[ $NEOVIDE_CHANGED -eq 1 ]] && DEVTOOLS_APPS="${DEVTOOLS_APPS:+$DEVTOOLS_APPS, }Neovide"
  open_pane \
    "Developer Tools (XProtect bypass for cargo build/test)" \
    "x-apple.systempreferences:com.apple.preference.security?Privacy_DevTools" \
    "$DEVTOOLS_APPS"
fi

if [[ $BRAVE_CHANGED -eq 1 ]]; then
  open_pane \
    "Screen Recording" \
    "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture" \
    "Brave Browser"
fi

if [[ $WEZTERM_CHANGED -eq 1 ]]; then
  open_pane \
    "App Management" \
    "x-apple.systempreferences:com.apple.preference.security?Privacy_AppBundles" \
    "WezTerm"
fi

# Record hashes now that permissions have been granted
[[ $WEZTERM_CHANGED -eq 1 ]] && record_hash wezterm "$WEZTERM_BIN"
[[ $NEOVIDE_CHANGED -eq 1 ]] && record_hash neovide "$NEOVIDE_BIN"
[[ $BRAVE_CHANGED   -eq 1 ]] && record_hash brave   "$BRAVE_BIN"

echo ""
echo "Done. Hashes recorded — this script will only prompt again after the next update."
