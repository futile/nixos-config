#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

export KITTY_LISTEN_ON="unix:/tmp/test-kitty.sock"
export PYTHONPATH="${repo_root}/dotfiles/kitty${PYTHONPATH:+:${PYTHONPATH}}"

python3 <<'PY'
import hashlib
import runpy
module = runpy.run_path("dotfiles/kitty/notifications.py")
watcher = runpy.run_path("dotfiles/kitty/codex-noctalia-watcher.py")


class Command:
    channel_id = 42
    body = "Command finished"


cmd = Command()
filtered = module["main"](cmd)
instance = hashlib.sha256(b"unix:/tmp/test-kitty.sock").hexdigest()[:12]
footer = f"Kitty-Source: kitty:{instance}:42"

assert filtered is False
assert cmd.body == "Command finished\n\n" + footer

module["main"](cmd)
assert cmd.body.count(footer) == 1


class Notification:
    def __init__(self, channel_id):
        self.channel_id = channel_id


class NotificationManager:
    def __init__(self):
        self.in_progress_notification_commands = {
            10: Notification(42),
            11: Notification(7),
        }
        self.closed = []

    def close_notification(self, notification_id):
        self.closed.append(notification_id)


class Boss:
    def __init__(self):
        self.notification_manager = NotificationManager()


class Window:
    id = 42


calls = []
watcher["subprocess"].Popen = lambda argv: calls.append(argv)
watcher["_last_clear_by_source"].clear()
watcher["_last_active_by_os_window"].clear()
watcher["time"].monotonic = lambda: 10.0

boss = Boss()
watcher["on_focus_change"](boss, Window(), {"focused": True})

assert boss.notification_manager.closed == [10]
assert calls == [["/home/felix/nixos/bin/kitty-clear-noctalia-for-source", f"kitty:{instance}:42"]]
PY

fake_noctalia="${tmp_dir}/noctalia-shell"
log_file="${tmp_dir}/calls.log"
source_key="$(python3 - <<'PY'
import hashlib
print("kitty:" + hashlib.sha256(b"unix:/tmp/test-kitty.sock").hexdigest()[:12] + ":42")
PY
)"

cat >"${fake_noctalia}" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"${NOCTALIA_TEST_LOG}"

if [[ "$*" == "ipc call notifications getHistory" ]]; then
	cat <<JSON
[
  {
    "id": "match",
    "body": "Command finished\\n\\nKitty-Source: ${KITTY_NOCTALIA_TEST_SOURCE}"
  },
  {
    "id": "other",
    "body": "Command finished\\n\\nKitty-Source: kitty:other:42"
  },
  {
    "id": "plain",
    "body": "Command finished"
  }
]
JSON
	exit 0
fi

if [[ "$*" == "ipc call notifications removeFromHistory match" ]]; then
	printf 'true\n'
	exit 0
fi

printf 'unexpected call: %s\n' "$*" >&2
exit 1
SH
chmod +x "${fake_noctalia}"

NOCTALIA_SHELL="${fake_noctalia}" \
	NOCTALIA_TEST_LOG="${log_file}" \
	KITTY_NOCTALIA_TEST_SOURCE="${source_key}" \
	bash "${repo_root}/bin/kitty-clear-noctalia-for-source" "${source_key}"

expected="${tmp_dir}/expected.log"
cat >"${expected}" <<'EOF'
ipc call notifications getHistory
ipc call notifications removeFromHistory match
EOF

diff -u "${expected}" "${log_file}" || fail "cleanup should remove only matching source footer"

printf 'kitty noctalia footer checks passed\n'
