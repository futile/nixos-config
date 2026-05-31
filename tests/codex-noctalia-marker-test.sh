#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
notify_script="${repo_root}/bin/codex-notify-noctalia"
clear_script="${repo_root}/bin/codex-clear-noctalia-for-pane"
lua_file="${repo_root}/dotfiles/wezterm/codex-noctalia.lua"

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

grep -q 'pane_key=' "${notify_script}" ||
	fail "notify script should write namespaced pane keys, not bare pane ids"

grep -q 'window_id' "${notify_script}" ||
	fail "notify script should include the pane window id in ready marker keys"

grep -q 'pane_key=' "${clear_script}" ||
	fail "clear script should remove namespaced pane keys"

grep -q 'ready_panes' "${lua_file}" ||
	fail "WezTerm Lua should cache ready panes in memory"

grep -q 'refresh_ready_panes' "${lua_file}" ||
	fail "WezTerm Lua should refresh marker files outside format-tab-title"

format_block="$(
	awk '
		/wezterm.on\("format-tab-title"/ { in_block = 1 }
		in_block { print }
		in_block && /^\tend\)/ { exit }
	' "${lua_file}"
)"

if grep -q 'io.open' <<<"${format_block}"; then
	fail "format-tab-title must not do filesystem IO"
fi

printf 'codex-noctalia marker checks passed\n'
