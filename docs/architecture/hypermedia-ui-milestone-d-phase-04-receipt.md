# HUI-D4 / HUI4 Local Delivery Receipt

Status: **merge-pending**

## Maintainer deferrals (2026-09-09)

The maintainer explicitly deferred the independent security, accessibility, and
operations-release reviews, alongside the previously deferred workstation
suspend/resume test. These reviews are not scheduled prerequisites for the
current implementation work; no reviewer approval or passing review is claimed.
The deferrals do not waive the failed production-load gate, clean-checkout CI,
or any reopening condition. HUI-D4/HUI4 remains unaccepted; deferred evidence
must be revisited before claiming full qualification.

## September 9 authorization-load diagnostics (not a runtime fix)

Merged PR #141 (`2cca4a90a8f46233a16cccacdeaf31979dc70eb3`) failed
clean-checkout CI run `34340121037`: five projection errors and four slow-owner
events during the first load round. The following instrumentation does not
change authorization, admission, query timeouts, or owner deadlines.

Fixed-cardinality authorization counters distinguish caller and store duration,
errors, and caught timeouts. Caller duration includes the QueryRunner queue;
store duration includes its StoreServer request. Neither event contains request,
principal, graph, query, or error payloads. Counts can differ when callers are
terminated before a queued operation completes; aggregate duration differences
are not exact queue-time measurements.

A disposable fixture probe under CPU affinity 0–3 measured mean fresh snapshot
times of 3,506 microseconds without contention and 67,762 microseconds with the
original two 64-MiB SHA-256 workers (20 samples each). Contended graph export
averaged 59,148 microseconds. These exploratory measurements suggest read-path
contention; they do not establish the cause of the CI failure.

The instrumented dirty-checkout production repeat on the declared i7-12700F
workstation exited zero with four schedulers and unchanged limits. Three rounds
delivered 60 patches / 988,260 HTML bytes in 113,040 ms. Projection errors,
authorization errors/timeouts, slow-owner events, pressure entries, and queued
protected bytes were zero. Four guard failures remain recorded. Peaks were
378,697,600 BEAM bytes, 594,591,744 RSS bytes, 369 processes, four streams,
query queue four, and run queue four. The counter snapshot reported 1,475 caller
authorizations / 63,303 total ms and 1,481 store authorizations / 46,408 total ms.
All three browser delivery and native rollback checks, fault recovery, scope
concealment, iterator cleanup, and restart recovery passed; graph revision was
unchanged. Asset digest:
`2cf3f825314a97ab6f2ef8850d723784d9f861036c633845ac07e78985e550f0`.
This repeat did not reproduce CI's failure and is not a repair or closure claim.
The instrumented candidate still needs clean-checkout CI and extended soak.

Focused `mix precommit` passed ten D4 architecture, stream-metric, and real graph
authority tests (seed 837098), including a suspended QueryRunner timeout that
remains fail-closed and emits only fixed stage/outcome and duration fields.
Architecture, compilation, formatting, and diff checks passed. This is not a
full regression-suite result.

## September 9 projection-deadline investigation

PR #142 CI job `102451694580` failed load round one with three projection
errors and four slow-owner events, but zero graph-grant authorization errors
or timeouts at either measured boundary. Those counters do not include the
complete identity/audit/field-shaping pipeline. Live projections explicitly
use a 1,500-ms surface deadline; ordinary pages use 5,500 ms and stream owners
have a 2,000-ms work window. No deadline was changed.

The qualification harness now logs only the already validated projection
telemetry dimensions (surface, outcome, state, cache status, duration) on
failure; it does not log request, identity, graph, result, or exception payloads.
A deliberately harsher two-CPU diagnostic run (affinity 0–1, original two
64-MiB CPU workers) reproduced failure in round one: an unavailable/invalidated
fleet projection at 3,783 ms and an unavailable/bypass projection at 1,501 ms.
The latter is consistent with the live projection deadline. This run also
recorded ten store authorization timeouts and one caller timeout, unlike CI,
so it is not an exact reproduction of CI's failure mode. Graph revision stayed
unchanged, protected queued bytes stayed zero, and slow-owner events were zero.
Browser delivery, faults, isolation, iterator cleanup, and restart recovery had
passed; final rollback was not reached. No qualification pass is claimed.

An experiment exporting only policy content for grant snapshots, while reading
target ownership metadata separately, did not demonstrate improvement: the
20-sample contended fixture probe averaged 130,085 microseconds versus 114,097
for the existing full snapshot. The experimental runtime and test edits were
removed. Only harness diagnostics remain; the next clean CI run must identify
its failing projection state and duration before a runtime fix is claimed.

## Strict timing follow-up (qualification pending)

The earlier green CI load still recorded two slow owners and six guard failures;
it is not evidence of clean timing. A stricter local three-round run completed
60 patches with zero query errors/slow owners but failed on four guard failures.
A second traced run failed with two slow owners and six guard failures; all
seven watchdog deadline observations printed before its final snapshot were
explicit terminal-cleanup deadlines, not active-work deadlines. These failed
runs remain evidence, not acceptance.

The watchdog now distinguishes an already-dead owner from an unexpected guard
exit. Deliberate coordinator-ordered force-stop after terminal grace is counted
as `forced_terminal_cleanup`, not guard failure. Active deadlines still count
as failure, with the event emitted before killing the owner to preserve it
regardless of monitor ordering. Regressions force reversed monitor ordering,
guard crash, active deadline, and stalled terminal cleanup. No deadline changes.

One duplicate authorization immediately before local frame-budget reservation
is removed. StreamUpdate still authorizes its rendered frame; write_update
still reconstructs current authorization after reservation and before any
protected bytes are sent. No query/render/delivery occurs between reservation
and that check. Query, field, route and protected-write authorization remain.

The production gate now rejects new query errors, slow owners and genuine guard
failures and waits up to 15 seconds for owner teardown before sampling. Forced
terminal cleanup is retained explicitly, not claimed as an active timing failure
or hidden. Ten-round soak and clean-checkout CI on this candidate are pending;
no timing-resolution or milestone-closure claim is made yet.

## Candidate Provenance

CI follow-up: production delivery now runs independently of the application
and browser/proxy regression job. The original required `verify` check is an
always-running aggregate requiring both jobs to succeed (including rejecting
skipped/cancelled jobs). No coverage is removed. Production uses a distinct
cache write key and can restore the existing compatible dependency cache;
it cleans application artifacts and builds production assets before qualification.
The speedup is not yet measured on CI; cold native compilation remains possible.

Projection stage telemetry records only fixed stage/phase and duration fields.
The qualification reports load-interval starts, completions and aggregate
microseconds for full authorization, cohort queries, detail queries, resource
lookup and fleet-row construction. Nested durations overlap; starts without
completions may indicate killed or still-active work. No authority, query,
identity, resource, result or error payload is emitted. All runtime deadlines
and fail-closed behavior remain unchanged. Historical candidate receipts are
preserved through exact successor source digests.

Local validation includes parsed YAML checks for independent job scheduling,
retained regression/audit/browser/qualification steps, and the required aggregate
check. Focused precommit covers projection/cache behavior, closed stage timing
dimensions, killed-task unfinished spans, and C4/D4 source provenance. Hosted
job timings and load qualification remain pending; no latency improvement or
production-load repair is claimed from this scheduling/measurement change.

Baseline: `8cac85172eeda04a41ee68f4b3a6dbba935ca8eb`.
Accepted D3 implementation: `a25d1ba65138935bbd065e09518bcdc7c7945301`.
Implementation is in progress; no merged D4 candidate exists.
Source and preserved predecessor digests are recorded in
`priv/architecture/hypermedia_ui/phase_d4_implementation_evidence.json`.

## Qualification

Candidate topology: direct IPv4 loopback HTTP/1.1, single local writable-store
owner; no proxy, cluster, LAN/public exposure or TLS/HTTP2 support is claimed.
Section 4.1 implements the loopback production profile, non-forwarded origin
guard, local HTTP cookie policy, bounded Bandit transport, drain/readiness,
named-human graph-grant composition and pristine local bootstrap ceremony.
Seven focused checks pass, including a real store grant and outage case.
The production-build Chromium 151.0.7922.34 runner passes direct delivery,
periodic refresh, offline clearing/recovery and paused cross-tab revocation.
Request-parameter logging is disabled in production without detaching the
Phoenix telemetry logger. Production restart preserves the graph revision and
the persisted named-human login; the same browser checks pass after restart.
These checks do not substitute for load/fault, complete browser/AT or
independent-review evidence. No section is accepted yet.

Section 4.2 adds fixed-cardinality in-memory counters, a four-stream local
factory/tenant envelope, and pressure admission with three-high/ten-low sample
hysteresis. Seven pressure/coordinator tests pass, including rejection without
allocation and refusal to retain arbitrary telemetry keys or payloads.

On Linux Mint 22.1, OTP 28 / Elixir 1.19.5, 20 online schedulers, production
Chromium 151.0.7922.34 sustained four live tabs in two sessions with two SHA-256
workers each retaining 64 MiB. The empty-factory workload delivered eight
patches (36,144 HTML bytes) in 7,499 ms and rejected a fifth stream. Peaks were
369,885,136 BEAM bytes, 564,482,048 process RSS bytes, 1,124 BEAM processes,
nine process sockets, run queue two, query queue zero, four streams and zero
queued protected payload bytes. The measured interval used 21,364 CPU-runtime
ms across schedulers. There were no query errors or slow-owner warnings.
These are small-corpus smoke measurements, not a large-corpus soak, minimum
hardware promise, percentile SLO, or cross-OS performance acceptance.

Section 4.3 adds the trusted disable-delivery switch and closes both new
enhanced admission and protected-delivery races while preserving native routes.
Its real HTTP rollback test passes. The production runner passes Chromium
151.0.7922.34, Firefox 153.0 and WebKit 26.5 for signed-in real graph reads,
direct SSE, periodic refresh, reduced-motion configuration, offline clearing,
and cross-tab revocation while paused. All three engines pass JavaScript-off
native sign-in, navigation/reload and sign-out after rollback. A pre-existing
session remains valid and the graph revision is unchanged by rollback.

The named production Orca/Xvfb run passes announced connected/paused/reload
states, keyboard activation, focus preservation and terminal revocation focus
(`/tmp/hui-d4-orca.I91ccX`, ephemeral speech artifacts). Desktop portal/FUSE
warnings occurred outside the application; they did not replace or satisfy
the speech/focus assertions. No independent reviewer approval is claimed.

## Section 4.4 Integration Record (in progress)

The real LocalGraph authority adapter now has a non-empty HTTP integration:
two repositories are enrolled through semantic commands, the authorized
repository converges into the stream, and the other repository stays absent
and returns 404 on direct navigation. Reading does not change graph revision.
There is no fixture principal substitution in this test.

The full precommit run passed 1,507 tests (seed 597252, 775.4 seconds).
The pre-upgrade browser matrix passed 123 tests with 162 declared applicability
skips in 13 minutes. Normal-environment Dialyzer passed with its existing
178 filters and no new unfiltered warning. These runs do not by themselves
qualify the subsequent browser-toolchain upgrade.

Production fault probes stop the real query runner and identity store, and
kill the coordinator. Protected content was cleared in approximately 2.3
seconds for service outages and 7–8 milliseconds for coordinator failure;
fresh navigation recovered and graph revision stayed unchanged. One probe
also encountered a failed reconnect after query recovery: the unavailable
query runner correctly triggers pressure degradation. The harness now waits
for the existing ten-low-sample recovery window before fresh admission.
Repeated production probes pass without weakening that guard. The latest
query/identity/coordinator cleanup measurements were 2,317/2,308/2 ms.

Repeated WebKit 26.5 production runs failed the unchanged 10-second refresh
assertion. Diagnostic runs at 20 seconds observed delivery around 11 seconds;
those diagnostic passes are **not** acceptance. TCP nodelay and padding
experiments did not fix the issue and were removed. The behavior matches
[WebKit bug 322545](https://bugs.webkit.org/show_bug.cgi?id=322545), whose
[upstream fix](https://github.com/WebKit/WebKit/pull/72494) landed August 27.
The candidate pins Playwright 1.63.0: Chromium 153.0.8010.12, Firefox 155.0
and WebKit 26.6. All three pass production qualification with the original
10-second assertion, including restart, offline clearing, paused revocation
and native-only rollback. The new regression matrix passed 105 tests outside
WebKit; its 42 WebKit launch failures were missing host libraries, not failed
product assertions. After isolated Ubuntu library installation in the temporary
browser cache, the complete WebKit project passed 21 tests with 36 applicability
skips. Clean-checkout CI must still repeat the complete matrix together.
The earlier WebKit smoke result above is historical only.

The latest production load run completed three rounds in 85,383 ms: four tabs,
two sessions, one named human and an empty factory, under two bounded SHA-256
workers. It delivered 60 patches / 271,080 HTML bytes and rejected the fifth
stream. Peaks: 404,137,912 BEAM bytes, 658,223,104 RSS bytes, 5,218 BEAM processes,
11 process sockets, run queue three, query queue one, four streams and zero
queued protected payload bytes. Query errors and pressure entries were zero.
Reload rounds allow the existing disconnect-cleanup window before reconnecting;
immediate replacement admission can correctly encounter the four-lease ceiling.
This bounded empty-corpus run is not the full production corpus or soak gate.

A subsequent full precommit run had two failures in 1,507 tests: a historical
package-lock assertion and a test command timestamp truncated before its newly
created grant. Both were corrected and their focused reruns passed. Historical
asset evidence remains unchanged; the current browser pin uses bounded successor
provenance. The grant test now keeps full timestamp precision.
Final `mix precommit --failed` passed architecture, formatting and compilation
checks and both previously failed tests (seed 330435, 10.1 seconds).

Declared local hardware: Intel Core i7-12700F, 20 online logical CPUs,
65,619,420 KiB physical RAM, Linux Mint 22.1 x86_64. The production runner emits
the exact candidate/dirty-state, normalized asset-manifest digest, transport
digest (including its ephemeral port), fixed limits, runtime versions, bounded
resource peaks and privacy-safe counters. Disposable data is never a release
artifact. CI repeats production qualification after building digested assets.

### September 8 automated acceptance expansion

The full `mix precommit` regression run passed 1,507 tests with zero failures
in 825.4 seconds. Subsequent evidence/source inventory edits still require the
final architecture check and clean-checkout CI on the published candidate.

The production harness now creates a three-repository corpus through real
semantic commands and registers explicit project memberships through the trusted
identity administration boundary. Chromium verifies two accessible projects,
one concealed project (absent links and direct 404), and the current evaluated
dataset revision. No fixture authority adapter or substituted principal is used.

The new non-reading HTTP client passed: its owner retired in 29,795–29,798 ms
with zero queued protected bytes. This proves bounded owner cleanup, not OS TCP
buffer saturation. Invalid relative-store configuration remained unready;
restoring the original configuration preserved graph revision and an existing
session. This is deployment-configuration failure recovery, not a destructive
schema-migration rollback claim.

A three-round scoped run without injected CPU workers passed in 94,545 ms,
delivering 61 patches / 1,004,731 HTML bytes. All twelve simultaneous reconnect
attempts against the occupied four-stream ceiling returned 429. The load harness
now supports 3–20 rounds, checks scope concealment after periodic refresh, and
replays bounded duplicate/out-of-order notifications from actual committed
commands without changing graph truth. New browser failure logs retain fixed
failure classes rather than DOM attributes or signed correlation cursors.

A ten-round contention run and the complete three-browser harness's load stage
hit slow-owner guards while other qualification/regression workloads ran on the
same host. Protected content was cleared, and no query errors or queued protected
payload were recorded. These are failed capacity runs, not acceptance evidence;
the isolated repeat completed all ten load rounds, then failed the original
burst assertion requiring twelve 429 responses. Owners can retire while burst
requests authorize, so newly free slots can legitimately be reused. The burst
assertion now permits reviewed 200/409/429/503 outcomes, requires scoped content
for successful newcomers, and verifies native recovery; the server sampler
continues to assert at most four streams and zero queued protected payload.
The corrected isolated repeat subsequently entered memory-pressure degradation
near round ten: peak BEAM memory 545,173,328 bytes, RSS 1,014,501,376 bytes and
19,643 processes. Four streams and zero queued protected bytes remained bounded;
query errors were zero and native rollback passed in all three browsers. This
is a failed sustained-capacity result, not acceptance.

A focused real-read probe identified retained RocksDB iterator processes:
372 before reads, 844 after 100 authorization checks and 924 after 20 additional
projection reads. `scripts/qualify_hui_d4_resources.exs` now makes completed-read
iterator cleanup a hard production qualification assertion. It intentionally
fails on the current dependency, rather than accepting a short smoke run that
stays below the degradation threshold. The pinned `pcharbon70/triple_store`
commit `6dc1b6d985f4805f9856858e0c0047b9f2d5ad7f` was also upstream HEAD when
checked. No dependency source, guard deadline or admission limit was changed.
An upstream cleanup fix and dependency update require separately scoped work.
The final focused regression reproduced exactly 200 additional retained
iterators after 50 completed authorization reads (444 → 644), with graph
revision unchanged, and exited nonzero as required.

Earlier clean-checkout CI passed PR #135's original candidate; it
does not qualify these subsequent edits.

### TripleStore resource repair candidate (2026-09-08)

The separately authorized upstream repair is
[TripleStore PR #30](https://github.com/pcharbon70/triple_store/pull/30), pinned
here at `c243be84decaeaa744d509fbfa8e07c10e2a0988`. It adds stream finalization,
closes direct-scan iterators, and closes exhausted multi-iterator strategies
before the existing single-iterator fallback. A separate test-only CI repair
corrects stale helper contracts and adds ExUnit to Dialyzer's analysis data;
no warnings are suppressed. Upstream dependency constraints, lock and license
are unchanged; the Mix project change affects analysis configuration only.
JidoCode's lock changes only the TripleStore Git pin. Historical accepted
dependency receipts remain records of their original candidates, not evidence
for this update; the current D4 source inventory binds both changed Mix inputs.

Upstream isolated validation (Elixir 1.19.5 / OTP 28.3.1): 360 query/executor/
cleanup tests passed, then 112 helper/cleanup tests passed; strict compilation,
code-doc validation and Dialyzer passed (zero errors or skips). All five new
resource tests fail on the original dependency and pass on the repair. The
existing QuadLeapfrog suite has 22 failures on the original and patched modules;
this is not a claim of full upstream suite acceptance.

A diagnostic production rehearsal loaded the two repaired runtime modules into
the existing dependency VM (not yet a clean-checkout locked-candidate run):
50 authorization reads retained zero iterators; all ten sustained-load rounds
passed with 200 patches, four maximum streams, zero queued protected payload,
zero query errors and zero memory-pressure entries. Peak BEAM processes were
404, BEAM memory 386,797,872 bytes and RSS 697,319,424 bytes under the original
limits and two 64 MiB contention workers. Native rollback passed Chromium,
Firefox and WebKit. The run exited zero. No guard, deadline or admission limit
was relaxed.

All 24 upstream candidate checks passed. PR #30 merged on 2026-09-08 as
`4e55b4872041831c8d63739202c7369f200fefa0`; the pinned tested commit is its
ancestor. Upstream local main was synced before its feature branch was deleted.

The actual locked-dependency production run (no runtime overrides) at JidoCode
`5211f25bb59017aa6f5ac0db39e363225a0c274e` also exited zero on 2026-09-08.
Its checkout was dirty only for an unrelated architecture-document edit, so
clean-checkout CI remains independently required. It passed all three browser
engines, exact scope/concealment, fault recovery, invalid-config restart/session
preservation, non-reading client retirement, and zero retained iterators after
50 authorization reads. Ten load rounds produced 201 patches in 354,672 ms;
peak processes 406, BEAM memory 389,115,424 bytes, RSS 737,804,288 bytes,
connections four and queued protected bytes zero. Query errors and pressure
entries were zero. One guard failure was recorded with bounded recovery;
the reconnect burst returned ten 429 and two scoped 200 outcomes, and native
recovery and all three browser rollback checks passed. The original resource
limits, graph revision invariants and contention profile remained intact.

The downstream repair and clean-checkout results are tracked in
[JidoCode PR #137](https://github.com/pcharbon70/jido_code/pull/137).
Neither these automated results nor the upstream merge close HUI2 or HUI4;
the remaining release-review and merged-candidate requirements still apply.

Outstanding acceptance evidence includes completion of dependency release review,
any remaining
release-review fault scenarios, actual workstation suspend/resume evidence,
independent security/accessibility/operations-release review, clean-checkout
CI, and merged-candidate closure. No exception or waiver is inferred.

### Dependency audit follow-up

PR #137 merged as `05f6dcdab0f4a4a7f0494d246908ccbaaa637212`, but its
dependency-audit failure prevents acceptance. The subsequent
[audit remediation record](hypermedia-ui-d4-dependency-audit-remediation.md)
pins Igniter 0.8.4 and preserves the Decimal 3.1.1 advisory discrepancy as an
explicit blocker. The exact successor lock is tracked in the current D4
inventory; earlier lock assertions above describe their historical candidates.
No audit suppression or D4 closure is inferred from the Igniter repair.

## Gate HUI-D4 / HUI4

### TripleStore query type-contract repair

The maintainer authorized fixing and merging the owned TripleStore repository.
[TripleStore PR #31](https://github.com/pcharbon70/triple_store/pull/31) corrects
query/property-path context handle types and adds a compiled-typespec regression.
Its candidate is `660ee1bf3a53e08f8ea3b3f39f1d688f03be5aab`; local validation
passed 177 query/property-path/context tests, code-doc governance, and Dialyzer
with zero errors or skips. All 24 hosted checks passed, and PR #31 merged on
2026-09-09 as `3b86494a3db2a8639f6145c4367011035b264934`. Upstream local main
was synced before deleting the local and remote feature branches. The pinned
tested candidate is an ancestor of that merge. No upstream runtime behavior or
dependency constraints changed.

JidoCode's successor lock changes only the TripleStore pin and has SHA-256
`040a115655f0d086c6ce9754c7987d3d93a5e94dc48d730aec7a76bde68cc462`.
The corrected contract removes 105 obsolete downstream warning filters (13
identified before the dependency repair, then 92 afterward). No new suppression
is added. Restore validation now rejects missing metadata before the validation
chain; the redundant raw-error branch is removed because those operations
return the structured knowledge error contract. These changes do not waive
the remaining soak finding or any HUI4 gate.

Downstream Dialyzer passed with 62 existing filtered findings, zero unfiltered
findings, and zero unused filters. The seven backup/restore tests passed,
including a new checksummed candidate with missing metadata that is rejected
while the previous dataset remains ready and active. Complete clean-checkout
downstream CI is still independently required.

Broader downstream `mix precommit` validation passed 613 tests with zero
failures in 624.9 seconds (seed 967748): the full knowledge test directory,
local graph authority, and D4/C1/C5 architecture regressions. Architecture,
formatting and compilation checks passed, as did unmodified `mix hex.audit`.
This is not a full application/browser run. The previous merged candidate's
main CI run `34332633033` subsequently failed production qualification; the
type-only dependency repair does not claim to resolve that runtime finding.

### Merged PR #140 extended qualification (September 9)

The ten-round, four-CPU production run on merged candidate
`3842f0944b717aebc223b9e7520a8e81fda79d4f` completed the browser load journey
with 200 patches / 3,294,200 HTML bytes in 382,641 ms, but failed the unchanged
zero-query-error assertion with one recorded error. Ten guard-failure events
were recorded; slow-owner events and pressure entries were zero. Graph revision
was unchanged, streams peaked at four, queued protected bytes stayed zero, and
peak BEAM/RSS memory was 385,878,696 / 624,201,728 bytes with 370 processes.
The burst returned ten 429 and two scoped 200 responses. The final rollback
stage was not reached after the failed assertion. This is failed soak evidence,
not a passing extension of the earlier three-round run.

The run used unchanged tracked sources, CPU affinity 0–3, the original two
64-MiB SHA-256 workers, and restored complete production assets with manifest
digest `2cf3f825314a97ab6f2ef8850d723784d9f861036c633845ac07e78985e550f0`.
An earlier attempt was deliberately interrupted after detecting missing generated
assets and is excluded from acceptance. Main Dialyzer run `34332632692` also
failed, reporting 13 obsolete filters and four unfiltered findings. No gate
closure follows from the PR merge.

Local analysis reproduced 166 warnings, with 164 filtered and two remaining
findings: a no-return callback in derived metadata reference reads and an
apparently unreachable absent-revision branch. The pinned TripleStore query
context declares `db: reference()` while its RocksDB adapter declares
`db_ref: pid()`. This inconsistent contract makes real query paths appear
unreachable in analysis. Thirteen CI-confirmed obsolete filters were removed;
no new suppression, dynamic-call workaround, or upstream change is introduced.
The type-contract correction and the remaining soak error are still open.

### September 9 snapshot read optimization (qualification in progress)

PR #139 diagnostics exposed five additional query errors and four guard failures
in the first CI load round, while iterator cleanup, graph revision invariance,
four-stream bounds and zero queued protected bytes held. This remains failed
capacity evidence.

The follow-up removes one redundant system-graph revision query per populated
graph in each semantic snapshot. `GraphMetadata.read` has already read that
authoritative revision during the same serialized store operation. Reusing it
does not cache authority across requests or use the graph-local RDF revision
statement as the authority. Empty graphs retain the independent system-graph
revision lookup. No admission limit, query timeout or owner deadline changes.
The real-store regression verifies that a subsequent committed change advances
both snapshot and metadata revisions, while an absent graph remains revision
zero. Thirteen focused snapshot, authority, projection and derived-graph tests
passed; this is not complete clean-checkout acceptance.

The revision-only optimization still failed the three-round qualification
under CPU affinity 0–3 on the declared i7 workstation: round two, two query
errors, three guard failures, four maximum streams, zero queued protected bytes,
and unchanged graph revision. Peak BEAM memory was 368,885,904 bytes with 368
processes. This is a failed diagnostic run, not proof of improvement over CI's
different hardware.

The next candidate also decodes graph metadata from the dataset already freshly
exported during that same serialized snapshot. It retains exact graph/subject
selection, the 50-statement cutoff, existing field/family validation, and a fresh
authoritative system-graph revision read. Derived revision-reference validation
still runs through the original store query path. Tests compare the new path
with direct metadata reads and reject duplicate ownership and oversized metadata;
metadata from a different graph is ignored. No cross-request cache is added.

The combined candidate's local production harness exited zero on September 9
with CPU affinity 0–3 (four schedulers), the original two 64-MiB SHA-256 workers,
and unchanged limits. Three load rounds delivered 60 patches / 988,260 HTML
bytes in 115,226 ms. Query errors, slow-owner events, pressure entries and queued
protected bytes were zero; six guard-failure events remain recorded rather than
suppressed. Peaks were 376,344,128 BEAM bytes, 590,856,192 RSS bytes, 370 processes,
four streams, eleven sockets, query queue four and run queue four. The reconnect
burst returned ten 429 and two scoped 200 responses; native recovery and all
three browser rollback checks passed. The earlier browser, fault, scope,
iterator and restart checks also passed. This dirty-checkout local run does not
substitute for clean-checkout CI, independent review, or extended soak acceptance.
Its asset manifest digest was
`2cf3f825314a97ab6f2ef8850d723784d9f861036c633845ac07e78985e550f0`.
Actual workstation suspend/resume is deferred at the maintainer's request, not
claimed as passed. HUI4 remains open.

### Merged PR #138 clean-checkout follow-up

CI run `34231321393` at `528c2ee69bfc95321704b53abd8ff74ce0315360`
passed application verification, the browser/proxy matrix, dependency audits,
and production asset build. Production qualification passed three-browser
delivery, query/identity/coordinator fault recovery, three-scope concealment,
zero retained iterators after 50 reads, invalid-configuration restart recovery,
and non-reading client cleanup. Load then failed the zero-query-error assertion:
the counter increased by four. This is failed acceptance, not an audit blocker.
The diagnostic follow-up preserves all assertions and prints bounded counters
and browser outcome before those assertions can terminate the runner.

On 2026-09-08 the maintainer accepted Decimal 3.1.1 for now. A fresh unmodified
`mix hex.audit` subsequently passed with no retired or advisory packages, so
no audit suppression was retained. The linked remediation record documents
the recheck and re-review conditions. This does not accept D4 or replace clean
CI and independent review.

**merge-pending**. Milestone E is not authorized.

## Reopening Conditions

The gate remains open or reopens, regardless of checkboxes, if:

- Identity, scope, policy, grant, revision, CSRF, Origin or CSP checks weaken, or protected data leaks.
- A browser/event/cached fragment supplies authority or replaces a fresh authorized graph query.
- A claimed transport/runtime/browser profile lacks matching real production evidence, or non-loopback exposure becomes possible.
- Streams, sockets, processes, queues, payloads, queries, retries or cleanup breach their declared bounds.
- Loss, reordering, outage, restart, sleep/wake or overload prevents bounded recovery and graph convergence.
- Revocation, pause, focus, overlays, assistive behavior, native fallback or safe stale-state replacement regresses.
- Disable-delivery rollback changes authoritative data, identity, sessions, routes or bookmarks, or fails its rehearsal.
- Source/config/assets/limits/candidate provenance is incomplete, clean-checkout CI fails, or required independent review is missing.
- Any predecessor gate reopens or single-writer/store integrity is violated.
