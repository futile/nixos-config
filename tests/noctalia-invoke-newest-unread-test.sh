#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

log_file="${tmp_dir}/calls.log"
fake_noctalia="${tmp_dir}/noctalia-shell"
history_file="${tmp_dir}/notifications.json"

cat >"${fake_noctalia}" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"${NOCTALIA_TEST_LOG}"

if [[ "$*" == "ipc call state all" ]]; then
	cat <<'JSON'
{
  "state": {
    "notificationsState": {
      "lastSeenTs": 1000
    }
  }
}
JSON
	exit 0
fi

if [[ "$*" == "ipc call notifications getHistory" ]]; then
	cat <<'JSON'
[
  { "id": "old", "summary": "old", "timestamp": 900 },
  { "id": "success", "summary": "second newest", "timestamp": 1800 },
  { "id": "missing-default", "summary": "newest", "timestamp": 2000 }
]
JSON
	exit 0
fi

if [[ "$*" == "ipc call notifications invokeAction missing-default default" ]]; then
	printf 'false\n'
	exit 0
fi

if [[ "$*" == "ipc call notifications invokeAction success default" ]]; then
	printf 'true\n'
	exit 0
fi

if [[ "$*" == "ipc call notifications removeFromHistory success" ]]; then
	printf 'true\n'
	exit 0
fi

printf 'unexpected call: %s\n' "$*" >&2
exit 1
SH
chmod +x "${fake_noctalia}"

cat >"${history_file}" <<'JSON'
{
  "notifications": [
    {
      "id": "missing-default",
      "actionsJson": "[{\"identifier\":\"reply\",\"text\":\"Reply\"}]"
    },
    {
      "id": "success",
      "actionsJson": "[{\"identifier\":\"default\",\"text\":\"Open\"}]"
    }
  ]
}
JSON

NOCTALIA_SHELL="${fake_noctalia}" \
	NOCTALIA_TEST_LOG="${log_file}" \
	NOCTALIA_HISTORY_FILE="${history_file}" \
	bash "${repo_root}/bin/noctalia-invoke-newest-unread"

expected="${tmp_dir}/expected.log"
cat >"${expected}" <<'EOF'
ipc call state all
ipc call notifications getHistory
ipc call notifications invokeAction success default
ipc call notifications removeFromHistory success
EOF

diff -u "${expected}" "${log_file}"

: >"${log_file}"
NOCTALIA_SHELL="${fake_noctalia}" \
	NOCTALIA_TEST_LOG="${log_file}" \
	NOCTALIA_HISTORY_FILE="${tmp_dir}/missing-notifications.json" \
	bash "${repo_root}/bin/noctalia-invoke-newest-unread"

cat >"${expected}" <<'EOF'
ipc call state all
ipc call notifications getHistory
EOF

diff -u "${expected}" "${log_file}"
