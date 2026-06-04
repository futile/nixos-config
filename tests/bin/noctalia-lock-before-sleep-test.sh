#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$repo_root/bin/noctalia-lock-before-sleep"

run_case() {
  local name="$1"
  local signal_fixture="$2"
  local expected_status="$3"
  local tmp
  tmp="$(mktemp -d)"

  cat >"$tmp/busctl" <<EOF
#!/usr/bin/env bash
cat "$signal_fixture"
EOF
  chmod +x "$tmp/busctl"

  cat >"$tmp/noctalia-shell" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$LOCK_LOG"
EOF
  chmod +x "$tmp/noctalia-shell"

  set +e
  BUSCTL_BIN="$tmp/busctl" \
    NOCTALIA_SHELL_BIN="$tmp/noctalia-shell" \
    LOCK_LOG="$tmp/lock.log" \
    "$script" --wait-once >/tmp/noctalia-lock-before-sleep-test.out 2>&1
  status=$?
  set -e

  if [[ "$status" -ne "$expected_status" ]]; then
    printf 'case %s: expected exit %s, got %s\n' "$name" "$expected_status" "$status" >&2
    cat /tmp/noctalia-lock-before-sleep-test.out >&2
    return 1
  fi

  if [[ "$expected_status" -eq 0 ]]; then
    if [[ "$(<"$tmp/lock.log")" != "ipc call lockScreen lock" ]]; then
      printf 'case %s: lock command was not called correctly\n' "$name" >&2
      [[ -f "$tmp/lock.log" ]] && cat "$tmp/lock.log" >&2
      return 1
    fi
  else
    if [[ -e "$tmp/lock.log" ]]; then
      printf 'case %s: lock command should not have been called\n' "$name" >&2
      cat "$tmp/lock.log" >&2
      return 1
    fi
  fi
}

true_fixture="$(mktemp)"
cat >"$true_fixture" <<'EOF'
Monitoring bus message stream.
Type=signal  Endian=l  Flags=1  Version=1 Cookie=1
  Sender=:1.1  Path=/org/freedesktop/login1  Interface=org.freedesktop.login1.Manager  Member=PrepareForSleep
  MESSAGE "b" {
          BOOLEAN false;
  };
Type=signal  Endian=l  Flags=1  Version=1 Cookie=2
  Sender=:1.1  Path=/org/freedesktop/login1  Interface=org.freedesktop.login1.Manager  Member=PrepareForSleep
  MESSAGE "b" {
          BOOLEAN true;
  };
EOF

false_fixture="$(mktemp)"
cat >"$false_fixture" <<'EOF'
Monitoring bus message stream.
Type=signal  Endian=l  Flags=1  Version=1 Cookie=1
  Sender=:1.1  Path=/org/freedesktop/login1  Interface=org.freedesktop.login1.Manager  Member=PrepareForSleep
  MESSAGE "b" {
          BOOLEAN false;
  };
EOF

run_case "locks on prepare-for-sleep true" "$true_fixture" 0
run_case "ignores prepare-for-sleep false" "$false_fixture" 1
