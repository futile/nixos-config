#!/usr/bin/env bash
# Enables Touch ID for sudo by writing /etc/pam.d/sudo_local.
#
# /etc/pam.d/sudo_local is Apple's designated override file — it is included by
# /etc/pam.d/sudo and is NOT reset by macOS updates (unlike sudo itself).
# This means this script only needs to be run once per machine.
#
# Requires sudo to write to /etc/pam.d/sudo_local.

set -euo pipefail

PAM_FILE="/etc/pam.d/sudo_local"
PAM_LINE="auth       sufficient     pam_tid.so"

if [[ -f "$PAM_FILE" ]] && grep -qF "pam_tid.so" "$PAM_FILE"; then
  echo "Touch ID for sudo is already enabled ($PAM_FILE contains pam_tid.so)."
  exit 0
fi

echo "Enabling Touch ID for sudo (requires sudo to write to $PAM_FILE)..."
echo "# sudo_local: local config file which survives system update and is included for sudo" \
  | sudo tee "$PAM_FILE" > /dev/null
echo "$PAM_LINE" | sudo tee -a "$PAM_FILE" > /dev/null
echo "Done. Touch ID for sudo is now enabled."
