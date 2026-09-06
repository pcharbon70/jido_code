# HUI-D2 — Authorized Page/Tab Stream Coordinator Receipt

Status: **merge-pending**. Sections 2.1–2.4 admission, supervised lifecycle,
revocation and integration qualification are implemented. Clean-checkout CI,
merge and merged-candidate pinning remain required for acceptance.

## Candidate Provenance

- Authorized baseline: `852215a71fae707bd7bd89ea822e2963b695ec5b` (D1 closure PR #128).
- Accepted predecessor: `7118bf337639c5ecdd5f2567dafbc761a5e09165` (D1 CSP repair PR #129).
- Section 2.1: `16b9a187de9c74bed1209d16965bdcdf35e44423`.
- Section 2.2: `4b4b0a4d0f5a37475bca027a047085f7c975819a`.
- Section 2.3: `3be4660e030e48f30bdecc85d5e1917d7958a966`.
- Implementation PR, section 2.4 commit, merged candidate, merge date and clean-checkout jobs: pending.

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
Section 2.4 supplies the complementary real HTTP/proxy/browser qualification.

Section 2.3: all eight generation hints and lost-hint fresh checks, hard expiry,
attributable authorization audit, whole-shell terminal clearing, independent
client deadline, bounded fresh retries, stale buffered-frame rejection, cross-tab
logout, focus and native fallback have focused server/browser coverage. The
identity store now honors its existing `touch: false` contract; background checks
cannot extend idle expiry and default foreground touching remains unchanged.
The identity/reauthorization suite passes 28 tests. Initial browser qualification
passes 9 applicable checks with 21 profile skips and no failures or CSP violations.

Section 2.4 qualification: the real HTTP/production-supervision matrix passes
13 tests. With three cursor tests, four consecutive seeded runs pass all 16
checks. Named Orca connection/status/revocation/reload speech and focus passes.
The layout now emits same-origin asset paths after proxy testing exposed the
upstream-origin CSP mismatch; neither CSP nor any predecessor gate was weakened.
The cumulative browser run passes 112 checks with 148 deliberate profile skips
(260 combinations, 7.2 minutes), with no failures or retries. The final finite-read/
stream ordering guard then passes all 10 applicable Chromium stream/proxy checks
(one native-profile skip, 1.3 minutes). Strict development/production compilation
and Dialyzer pass with the existing 178 filters and no new or unused filter.
`mix precommit` passes 1,468 tests with zero failures in 663.1 seconds. No phase
acceptance is claimed before clean-checkout CI and merged-candidate pinning.
Transport cleanup and reduced-clock/limit fixtures are described explicitly
in the implementation contract; D4 global/deployment capacity is not claimed.

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
