#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

export QUIET_COMPUTE_SYSFS="${tmp_dir}/sys"
export QUIET_COMPUTE_STATE_DIR="${tmp_dir}/state"
export TUNED_TEST_PROFILE="${tmp_dir}/profile"
echo throughput-performance >"${TUNED_TEST_PROFILE}"

for cpu in 0 1; do
	d="${QUIET_COMPUTE_SYSFS}/devices/system/cpu/cpu${cpu}/cpufreq"
	mkdir -p "${d}"
	echo 400000 >"${d}/cpuinfo_min_freq"
	echo 4700000 >"${d}/cpuinfo_max_freq"
	echo 4700000 >"${d}/scaling_max_freq"
done

mkdir -p "${tmp_dir}/bin"
cat >"${tmp_dir}/bin/tuned-adm" <<'SH'
#!/usr/bin/env bash
case "$1" in
active) echo "Current active profile: $(cat "${TUNED_TEST_PROFILE}")" ;;
profile)
	echo "$2" >"${TUNED_TEST_PROFILE}"
	# Like amd-pstate: with boost off (powersave), cpuinfo_max_freq drops to nominal.
	max=4700000
	[[ "$2" == powersave ]] && max=2700000
	for f in "${QUIET_COMPUTE_SYSFS}"/devices/system/cpu/cpu*/cpufreq/cpuinfo_max_freq; do echo "${max}" >"${f}"; done
	;;
esac
SH
chmod +x "${tmp_dir}/bin/tuned-adm"
export PATH="${tmp_dir}/bin:${PATH}"

qc="${repo_root}/bin/quiet-compute"
max1="${QUIET_COMPUTE_SYSFS}/devices/system/cpu/cpu1/cpufreq/scaling_max_freq"

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

"${qc}" on 1200 >/dev/null
[[ "$(cat "${max1}")" == 1200000 ]] || fail "cap not applied to all CPUs"
[[ "$(cat "${TUNED_TEST_PROFILE}")" == powersave ]] || fail "powersave not selected"

# A second "on" must not overwrite the saved original profile.
"${qc}" on >/dev/null
[[ "$(cat "${max1}")" == 1400000 ]] || fail "default cap not 1400 MHz"

for bad in abc 100 9000 0 0800; do
	if "${qc}" on "${bad}" 2>/dev/null; then fail "accepted invalid MHz '${bad}'"; fi
done
[[ "$(cat "${max1}")" == 1400000 ]] || fail "invalid MHz changed the cap"

# No hwmon in the fake sysfs: status must degrade, not fail.
status="$("${qc}" status)" || fail "status failed"
[[ "${status}" == *"max freq:  1400 MHz"* && "${status}" == *"Tctl:      n/a"* ]] || fail "status output: ${status}"
[[ "${status}" == *"quiet mode: on (off restores 'throughput-performance')"* ]] || fail "status state: ${status}"

"${qc}" off >/dev/null
[[ "$(cat "${max1}")" == 4700000 ]] || fail "cap not removed"
[[ "$(cat "${TUNED_TEST_PROFILE}")" == throughput-performance ]] || fail "previous profile not restored"

# No active profile before "on": a later "on" must not record powersave as the original.
: >"${TUNED_TEST_PROFILE}"
"${qc}" on >/dev/null
"${qc}" on >/dev/null
"${qc}" off >/dev/null
[[ "$(cat "${TUNED_TEST_PROFILE}")" == powersave ]] || fail "empty saved profile mishandled"
[[ ! -e "${QUIET_COMPUTE_STATE_DIR}/previous-profile" ]] || fail "state not cleared by off"

echo "quiet-compute tests passed"
