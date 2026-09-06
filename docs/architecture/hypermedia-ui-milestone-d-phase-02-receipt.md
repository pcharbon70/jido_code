# HUI-D2 — Authorized Page/Tab Stream Coordinator Receipt

Status: **accepted-at-merged-candidate**. Sections 2.1–2.4 admission, supervised
lifecycle, revocation and integration qualification passed clean-checkout CI and
merged in implementation PR #130. The pinned candidate below is the only D2
baseline; every predecessor and D2 reopening condition remains binding.

## Candidate Provenance

- Authorized baseline: `852215a71fae707bd7bd89ea822e2963b695ec5b` (D1 closure PR #128).
- Accepted predecessor: `7118bf337639c5ecdd5f2567dafbc761a5e09165` (D1 CSP repair PR #129).
- Section 2.1: `16b9a187de9c74bed1209d16965bdcdf35e44423`.
- Section 2.2: `4b4b0a4d0f5a37475bca027a047085f7c975819a`.
- Section 2.3: `3be4660e030e48f30bdecc85d5e1917d7958a966`.
- Section 2.4: `33aa29220f1de3d9abf319d5c15e64e03bb1e71a`.
- Implementation PR: [#130](https://github.com/pcharbon70/jido_code/pull/130).

Merged candidate: `1d55390108763052998cc6f6e6dfc4ce319998c0`
Merge date: `2026-09-06`

Clean-checkout jobs on the exact implementation head: [verify 101528874736](https://github.com/pcharbon70/jido_code/actions/runs/34048916379/job/101528874736)
(27m9s) and [Dialyzer 101528874615](https://github.com/pcharbon70/jido_code/actions/runs/34048916353/job/101528874615)
(1m33s). Both completed successfully before the implementation merge. Completed
logs confirm all test totals below and no browser retries or flaky passes.

## Gate HUI-D2

**accepted-at-merged-candidate**. D3 is authorized only from the pinned candidate
after this closure is published on main. Gate reopening is independent of every
checkbox, and no scope, limit or predecessor invariant is weakened.

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
The final cumulative browser matrix passes 113 checks with 152 deliberate profile
skips (265 combinations): 7.3 minutes locally and 8.1 minutes in clean-checkout CI,
with no failures, retries or flaky passes. It includes the final finite-read/stream
ordering guard. Named Orca 46.1 with Chrome 140.0.7339.80 passes again on the final
committed assets; speech traces remain ephemeral. Strict development/production
compilation and Dialyzer pass with the existing 178 filters and no new or unused
filter. `mix precommit` passes 1,468 tests with zero failures in both local runs
(663.1 and 667.1 seconds) and clean-checkout CI (953.9 seconds).
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
