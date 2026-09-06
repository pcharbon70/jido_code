# HUI-D2 — Authorized Page/Tab Stream Coordinator Receipt

Status: **merge-pending**. Sections 2.1–2.2 admission and supervised lifecycle are
implemented. Live revocation, browser delivery and integration acceptance remain pending.

## Candidate Provenance

- Authorized baseline: `852215a71fae707bd7bd89ea822e2963b695ec5b` (D1 closure PR #128).
- Accepted predecessor: `7118bf337639c5ecdd5f2567dafbc761a5e09165` (D1 CSP repair PR #129).
- Implementation PR, section commits, merged candidate, merge date and clean-checkout jobs: pending.

## Gate HUI-D2

**merge-pending**. No subsequent phase is authorized by this receipt.

## Evidence

Section 2.1: closed intent/cursor, coordinator admission, ten controller routes,
page-versus-stream grants, pre-header failures and D1 regression tests pass.
The initial missing HEEx format selection was corrected. Successor evidence
retains D1's original source digests; its negative drift tests remain binding.

Section 2.2: coordinator/watchdog supervision, hard count/rate/byte/event/credit
limits, independent session/connection/idle deadlines, blocked-owner termination,
drain, crash/restart cleanup and private telemetry have focused executable tests.
This is not yet the real HTTP/proxy/browser integration acceptance of section 2.4.

The executable source inventory and section evidence are in
`priv/architecture/hypermedia_ui/phase_d2_implementation_evidence.json`.
The runtime design and fixed limits are recorded in
[the coordinator implementation contract](./hypermedia-ui-stream-coordinator-implementation.md).

## Reopening Conditions

The gate reopens, regardless of checkbox state, on any of the following:

- Authentication, CSRF, Origin, Fetch Metadata, negotiation, exact route/resource authorization or initial query/field authorization occurs after response start.
- Tab, cursor, Last-Event-ID, browser state, cached fragment, socket or retry timer becomes authority or permits protected replay.
- Duplicate/takeover races permit the replaced owner to retain a current lease or restore earlier scope.
- Principal/session/tenant/factory count, admission/event rate, queue depth/bytes, encoded patch/event size, retry/backoff, heartbeat, idle or lifetime is unbounded or bypassed.
- Slow reader, exception, disconnect, process/node failure, supervisor restart, timeout or deploy drain leaves a zombie owner or leaks capacity.
- Account/session/role/delegation/project/tenant/graph/incident generation changes, hard expiry, periodic checks or pre-patch checks fail to stop unauthorized delivery.
- Revocation retains protected queued work or connected DOM where safe replacement is possible, lacks attributable audit, or permits automatic reconnect.
- Native fallback, focus, accessibility, nonce CSP, local bundle confinement, private responses or any predecessor reopening invariant regresses.
- Real HTTP, browser, proxy, security, resource or telemetry evidence is absent, unreproducible or fails; clean-checkout CI fails; candidate provenance is not pinned after merge.

Offline delivered DOM cannot be remotely erased. Production graph authority is
still unconfigured and fails closed. D3 graph-change subscriptions and D4
multi-node/deployment capacity acceptance remain separate gates.
