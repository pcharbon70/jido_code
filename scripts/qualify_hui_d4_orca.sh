#!/usr/bin/env bash
set -euo pipefail
evidence_dir="$(mktemp -d /tmp/hui-d4-orca.XXXXXX)"
cleanup() {
  if [[ -n "${orca_pid:-}" ]]; then kill "${orca_pid}" 2>/dev/null || true; fi
}
trap cleanup EXIT
export NO_AT_BRIDGE=0
export GTK_MODULES="gail:atk-bridge"
orca --replace --debug-file "${evidence_dir}/speech.log" >"${evidence_dir}/orca.log" 2>&1 &
orca_pid=$!
sleep 2
node test/accessibility/hypermedia_ui_phase_d4_orca.mjs >"${evidence_dir}/browser.json"
sleep 2
rg --quiet "Visual updates paused" "${evidence_dir}/speech.log"
rg --quiet "Connected" "${evidence_dir}/speech.log"
rg --quiet "Reload and check access" "${evidence_dir}/speech.log"
printf 'HUI-D4 production Orca speech/focus checks passed: %s\n' "${evidence_dir}"
