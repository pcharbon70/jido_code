#!/usr/bin/env bash
set -euo pipefail

report_path="${1:-/tmp/hui-c5-orca-debug.log}"
server_log="/tmp/hui-c5-orca-server.log"
browser_report="/tmp/hui-c5-orca-browser.json"

cleanup() {
  if [[ -n "${orca_pid:-}" ]]; then kill "${orca_pid}" 2>/dev/null || true; fi
  if [[ -n "${server_pid:-}" ]]; then kill "${server_pid}" 2>/dev/null || true; fi
}
trap cleanup EXIT

MIX_ENV=test PHX_SERVER=true PORT=4413 PHX_HOST=127.0.0.1 \
  JIDO_CODE_HUI_QUALIFICATION_ENABLED=true \
  JIDO_CODE_HUI_QUALIFICATION_HOSTS=127.0.0.1 \
  JIDO_CODE_HUI_BROWSER_ASSETS=production \
  mix phx.server >"${server_log}" 2>&1 &
server_pid=$!

for _attempt in $(seq 1 120); do
  if curl --fail --silent http://127.0.0.1:4413/sign-in >/dev/null; then break; fi
  sleep 0.25
done
curl --fail --silent http://127.0.0.1:4413/sign-in >/dev/null

export NO_AT_BRIDGE=0
export GTK_MODULES="gail:atk-bridge"
orca --replace --debug-file "${report_path}" &
orca_pid=$!
sleep 2

node test/accessibility/hypermedia_ui_phase_c5_orca.mjs >"${browser_report}"
sleep 2

grep -F "Needs attention" "${report_path}" >/dev/null
grep -F "Projects" "${report_path}" >/dev/null
grep -F "Project overview" "${report_path}" >/dev/null
grep -F "Attempt workspace" "${report_path}" >/dev/null

printf 'Orca speech-output qualification passed.\n'
printf 'Browser assertions: %s\n' "${browser_report}"
printf 'Ephemeral Orca debug log: %s\n' "${report_path}"
