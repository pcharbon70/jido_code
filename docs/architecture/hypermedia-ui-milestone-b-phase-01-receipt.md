# Hypermedia UI Milestone B Phase 1 Source And Risk Receipt

## Status

Status: **merge-pending**

This receipt records the HUI-B1 implementation candidate prepared on
2026-09-03. It accepts an immutable source, license, version, protocol, BOM,
and risk baseline only. Dependency declarations, locks, application assets,
routes, runtime behavior, and product consumers are unchanged. ShadcnUI,
Dstar, and Datastar remain unavailable to product code and receive no release
credit.

HUI-B2 is not authorized from this branch or receipt. It becomes eligible only
after the implementation pull request passes clean-checkout CI, merges, and a
narrow closure pull request pins that full implementation merge SHA and date.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted HUI-A4 closure baseline | `1e4073bb6968924abb2345e49453f980ae7eee92` - PR #108 merged 2026-09-03 |
| Section 1.1 | `bf3b75fc8cb994ef6979b9f5932fc125f025701d` - ShadcnUI source, license, component, CI, accessibility, and risk record |
| Section 1.2 | `25a427144358aacafb4299df31cfd319de829f64` - Dstar/Datastar source, bundle, CSP, protocol, and risk pairing |
| Section 1.3 | `814d9bce551dbfa4caa98e46f030b0a72c2f6eaa` - candidate BOM, resolution, alternatives, cache, incident, and output ledger |
| Section 1.4 | `5afdbd460221e427c8f7091383cb813c598cf24d` - executable integrity matrix and merge-pending receipt |
| Implementation content head | `5afdbd460221e427c8f7091383cb813c598cf24d` - before this provenance-only pin |
| Merged candidate | `merge-pending` |

Merged candidate: `merge-pending`
Merge date: `merge-pending`

## Selected Immutable Inputs

| Input | Identity | License | Current disposition |
| --- | --- | --- | --- |
| ShadcnUI | `fe40eae63504adc4375aead4f0e741f158a4d86e`, archive `a71b35c1102102ee38935d80b1d21e41c68aa3966bca4fb77e8d816383831a1c`, CSS `ed0768e9582e980f3fd1b3ca0076afc573fc269514f527aef9dc942d1f8e9f41` | MIT plus retained notices | source authority accepted; adoption blocked |
| Dstar | Hex `0.2.0` checksum `4766c1f3da802aa7e842aa78cbb778c8d764599e18fc67bbe32fbe25ac2c6460`, source `4bfb9110645f3831cd350f25434493c76a42bfae` | MIT | package/protocol identity accepted; adoption blocked |
| Datastar | signed `v1.0.3` at `73ab00e7c06d8c2bad030fdddafba800fcccbde2`, bundle `5d6b7794a50a83d82da962aec5e382f5ae83ac7afbc751f903f7a9c6bd433c65` | MIT | CSP-capable asset identity accepted; adoption blocked |
| Phoenix component resolution | Phoenix `1.8.11`, Phoenix.HTML `4.3.0`, Phoenix LiveView `1.2.9`, Plug `1.20.3`, Jason `1.4.5` | MIT/Apache-2.0 as recorded in BOM | exact HUI-B2 solver candidate; not installed |

Datastar `1.0.3` replaces the nominal `1.0.0` research input because earlier
1.0 patches require `unsafe-eval`. Its opt-in mode uses response-nonce-bearing
transient scripts and the `datastar` Trusted Types policy. Enforcing CSP,
static expression, production asset, and real-browser behavior remain HUI-B2
through HUI-B4 blockers.

## License, Advisory, CI, And Accessibility Findings

The selected ShadcnUI source, compiled CSS, examples, modifications, and
redistribution have an MIT grant subject to retaining its license and
applicable third-party notices. Dstar and Datastar are MIT. Candidate Hex
transitives and npm build inputs have their exact source, checksum, license,
role, and consumer recorded in the BOM.

GitHub returned no repository security advisories for the three selected
sources at review time. Hex returned no selected release retirement; the
baseline Mix Hex audit returned no retired or advisory package; and the exact
66-component upstream ShadcnUI npm build lock returned zero audit findings.
All are dated observations that reopen on drift.

Dstar's exact commit passed its two attached Elixir/OTP jobs. Datastar's exact
release commit has no attached check runs, and ShadcnUI's exact-head workflow
failed at its Milestone E Phase 4 browser suite after earlier gates passed.
ShadcnUI is explicitly unqualified. Its remaining exact-revision CI and manual
keyboard, overlay/focus, zoom/RTL, forced-colors/reduced-motion, touch, and
screen-reader gaps block adoption or release as assigned in the risk records.

## Protocol And Security Dispositions

- Product work uses explicit Phoenix controllers and application-owned
  authorization. Dstar Page, Router, Component, Dispatch, dynamic event/module
  selection, and Scripts are prohibited or deferred.
- Native Phoenix forms own the ordinary CSRF path. The default nonlocal Dstar
  CSRF signal is rejected because GET/DELETE serialize it into URLs. Enhanced
  mutations use qualified POST/PUT/PATCH header/body transport; GET has no
  effect and enhanced DELETE is avoided.
- `datastar-patch-elements` and `datastar-patch-signals`, exact modes,
  namespaces, data lines, content types, morphing, SSE IDs, retry, and error
  behavior are pinned. A versionless or semver-inferred claim fails.
- Signals are bounded untrusted presentation intent. Dstar StreamRegistry and
  Datastar retry counts provide no authority, quota, lifetime, revocation, or
  convergence guarantee.
- HUI-B2 must vendor exact Datastar bytes because the signed release tree lacks
  package metadata and a lock. There is no CDN, mutable fallback, or silent
  rebuild path.

## Verification Record

The source evidence independently materialized and hashed all three exact Git
trees, the ShadcnUI CSS/license/notices/locks, Dstar source and Hex tarball,
Datastar signed tag/source/bundle/source map/CSP implementation, candidate Hex
release metadata, and the ShadcnUI npm build graph. The executable HUI-B1
validator cross-checks all manifests and preserves the exact baseline
`mix.exs`, `mix.lock`, `package.json`, `package-lock.json`, `app.js`, and
`app.css` digests.

Negative tests reject changed commits/tags/checksums, missing license authority,
namespace drift, an advisory, false qualification of failed upstream CI,
missing artifacts, versionless protocol claims, unknown BOM edges, active
adoption exceptions, missing future evidence outputs, and any Phase 1 consumer
claim.

| Verification | Result at the Section 1.4 candidate |
| --- | --- |
| Manifest parse | 5 HUI-B1 JSON manifests parsed by `jq` |
| Focused HUI-B1 suite | 11 tests, 0 failures |
| Architecture gate | passed |
| Architecture/security regression slice | 75 tests, 0 failures |
| Repository precommit | 1,191 tests, 0 failures |
| Clean-checkout CI | merge-pending; required before implementation merge |

The immutable tracked evidence at this candidate has these SHA-256 identities:

| Artifact | SHA-256 |
| --- | --- |
| `phase_b1_shadcn_source.json` | `25a8bc96d380c216a668d009ee58df5ceee2c82eb93629dd4b0569206d1cc333` |
| `phase_b1_datastar_dstar_pairing.json` | `ad37092dfe70109aa5923ad744b67b2ccde78dca4fd4b1fa630ee50f4605298b` |
| `phase_b1_candidate_bom.json` | `dbfb08bfa5a95d41a538dadbcd8f9605918761a565e82ae075854c969a6f7f12` |
| `phase_b1_supply_chain_ledger.json` | `7e8c4286ebd125f0c1b8a8997abba699c82f0f583b5f518d0b6a7eeba9d9cfe6` |
| `phase_b1_verification_evidence.json` | `cdcea080e35d61c93533c0967fbc04bae9cd43e7207d864d2adb711b5765a513` |
| `hypermedia_ui_phase_b1.ex` | `b7641edd9ffa7a67911e1282b168296bbe3c87d7683eb1fa05890a61abec9940` |
| `hypermedia_ui_phase_b1_test.exs` | `9079ba7777d05256f8417580a606a14b69afdd288b78def0776a856ee6dd59f3` |
| unavailable-artifact fixture | `86f05b4c2b6f64fa8468135d803b179991695a54f5b0eaba02c9ac5b6b0eff06` |

## Risk Ownership And Limitations

The ShadcnUI and Dstar/Datastar records retain twelve named risks with owners,
severity, state, mitigation, expiry, and reopening conditions. Blocking work
includes the Phoenix LiveView `1.1.33` to `1.2.9` transition, exact-byte asset
integration, nonce/Trusted Types CSP, closed signals and non-URL CSRF, bounded
stream lifetime/revocation, exact browser/proxy tests, exact ShadcnUI CI, and
manual accessibility. No checklist or HUI-B1 acceptance closes those risks.

The candidate BOM is the sole version-selection input for HUI-B2. HUI-B2 must
publish the resolved runtime/compile/build/optional-platform SBOM, exact locks,
local assets, production manifests, licenses, consumer inventory, and rollback
evidence. A different resolution returns to HUI-B1 unless explicitly reviewed
as an equivalent candidate with all source and risk evidence.

## Evidence Owners And Reviewers

| Evidence | Primary owner | Independent reviewer | Current limitation |
| --- | --- | --- | --- |
| ShadcnUI source/license/namespace/CSS | HUI-B component owner | license and accessibility owner | exact CI and manual accessibility remain open |
| Dstar Hex/source/API/protocol | HUI-B dependency owner | request and stream security owner | consumer and operational behavior unproved |
| Datastar tag/bundle/CSP/protocol | HUI-B asset owner | CSP and browser owner | no release-commit checks or JidoCode browser proof |
| Candidate BOM and acquisition policy | HUI-B supply-chain owner | security and release owner | candidate graph not installed; resolved SBOM deferred |
| Mutation and boundary verification | HUI-B architecture owner | clean-checkout CI | implementation candidate is not merged |

## Gate HUI-B1

Status: **merge-pending**

HUI-B1 remains merge-pending until the implementation PR passes all required
checks and merges, then a closure PR records the exact merge SHA/date, changes
this status to accepted-at-merged-candidate, completes the Phase 1 plan and
checkboxes 1, 1.4, 1.4.2, and 1.4.2.3, and passes clean-checkout CI. Only that
pinned baseline authorizes HUI-B2.

HUI-B1 reopens regardless of checklist state if any selected repository,
owner, package, version, commit, tag, tree, archive, Hex or npm checksum,
bundle, source map, CSS, license, notice, namespace, dependency, build input,
consumer, CSP behavior, protocol behavior, CI result, accessibility evidence,
retirement, advisory, signature, maintenance state, risk owner, mitigation,
expiry, replacement trigger, or update cadence changes; if a mutable branch,
version label, latest selection, versionless document, CDN, remote runtime,
alternate registry, online fallback, unverified cache, silent rebuild, or
unexpected transitive replaces a recorded input; if unexpected bytes cause an
expected digest to be rewritten rather than review to reopen; if source,
compiled assets, copied code, modifications, examples, icons, notices, or
redistribution lose usage authority; if proprietary or ambiguous terms return;
if the failed ShadcnUI run, missing Datastar checks, historical browser tests,
or automated evidence is represented as exact green CI, manual accessibility,
supported-browser, or release acceptance; if Phoenix LiveView resolution or
any other solver decision changes, uses an implicit override, breaks a current
consumer, or creates a new LiveView route/process/event/stream/socket/hook/
state owner; if product code broadly imports ShadcnUI, bypasses the JidoCode UI
facade, or claims missing application composites; if Datastar uses a pre-1.0.3
unsafe-eval client, weakens CSP with unsafe-eval/unsafe-inline/remote sources,
omits the response nonce or Trusted Types review, executes text/javascript,
ships a source map without approval, or uses non-static or untrusted
expressions; if Dstar Page/Router/Component/Dispatch/dynamic module selection/
Scripts becomes product authority, authorization starts after a protected
response, or StreamRegistry is treated as quota, lifetime, revocation,
authority, or convergence; if a nonlocal CSRF credential reaches a signal,
GET/DELETE URL, log, referrer, cache, or telemetry; if GET gains an effect,
DELETE enhancement bypasses the recorded decision, a request/signal schema is
open or unbounded, or browser data supplies identity, authority, action,
resource, graph, policy, or authoritative revision; if an SSE response,
fragment, signal, selector, mode, namespace, event, retry, error, morph,
heartbeat, queue, patch, connection, lifetime, reauthorization, revocation,
reconnect, cleanup, proxy, focus, overlay, native fallback, or safe outcome
departs from the exact matrix; if any required manifest, BOM edge, alternative,
constraint, exception/control, cache/channel policy, incident response,
lockfile, asset manifest, SBOM, integrity record, license output, production
digest, reviewer, negative fixture, source verification, limitation, or
reopening condition disappears or becomes inconsistent; if HUI-B1 changes a
dependency declaration, lock, application asset, route, runtime, or product
consumer; if the receipt accepts an unmerged/different candidate, omits the
full SHA/date, enters mixed closure state, or authorizes HUI-B2 early; if any
HUI-A1 through HUI-A4 reopening condition triggers; or if architecture,
dependency, license, security, documentation, focused integration,
`mix precommit`, or clean-checkout CI fails at the exact candidate.
