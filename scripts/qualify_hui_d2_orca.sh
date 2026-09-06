#!/usr/bin/env bash
set -euo pipefail

evidence_dir="$(mktemp -d /tmp/hui-d2-orca.XXXXXX)"
cleanup() {
  if [[ -n "${orca_pid:-}" ]]; then kill "${orca_pid}" 2>/dev/null || true; fi
  if [[ -n "${server_pid:-}" ]]; then kill "${server_pid}" 2>/dev/null || true; fi
}
trap cleanup EXIT

MIX_ENV=test PHX_SERVER=true PORT=4423 PHX_HOST=127.0.0.1 \
  JIDO_CODE_HUI_QUALIFICATION_ENABLED=true JIDO_CODE_HUI_QUALIFICATION_HOSTS=127.0.0.1 \
  JIDO_CODE_HUI_BROWSER_ASSETS=production mix phx.server >"${evidence_dir}/server.log" 2>&1 &
server_pid=$!
for _attempt in $(seq 1 120); do
  if curl --fail --silent http://127.0.0.1:4423/sign-in >/dev/null; then break; fi
  sleep 0.25
done
curl --fail --silent http://127.0.0.1:4423/sign-in >/dev/null

export NO_AT_BRIDGE=0
export GTK_MODULES="gail:atk-bridge"
orca --replace --debug-file "${evidence_dir}/speech.log" >"${evidence_dir}/orca.log" 2>&1 &
orca_pid=$!
sleep 2
node test/accessibility/hypermedia_ui_phase_d2_orca.mjs >"${evidence_dir}/browser.json"
sleep 2
rg --quiet "Connected" "${evidence_dir}/speech.log"
rg --quiet "Reload and check access" "${evidence_dir}/speech.log"
printf 'HUI-D2 named Orca speech and focus checks passed. Ephemeral evidence: %s\n' "${evidence_dir}"
