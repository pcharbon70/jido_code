# Hypermedia UI Milestone B Phase 2 Component And Asset Receipt

## Status

Status: **merge-pending**

This receipt records the verified HUI-B2 implementation candidate. It remains
merge-pending until the implementation pull request passes clean-checkout CI
and merges. HUI-B3 is not authorized until a closure pull request pins that
full merge commit and date without weakening any reopening condition.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted HUI-B1 closure baseline | `da9776d49d9e2f9d487294292e7643355576902d` - closure PR #110 |
| Section 2.1 | `f6c36dd0b7937a4b2869ee278a784885f5b54a73` - exact component dependency graph |
| Section 2.2 | `245fd7d16263393b867c1c32f04365a13b74df06` - facade and theme contract |
| Section 2.3 | `e5330518b9886e401b887ab994a3dc7cc8a33add` - deterministic Datastar asset pipeline |
| Section 2.4 | `commit-pending` - integration verifier and receipt |
| Implementation PR head | `head-pending` |
| Merged candidate | `merge-pending` |

Merged candidate: `merge-pending`
Merge date: `merge-pending`

## Accepted Candidate Inputs

The candidate uses Phoenix 1.8.11, Phoenix.HTML 4.3.0, Phoenix LiveView 1.2.9,
Dstar 0.2.0, ShadcnUI at exact commit
`fe40eae63504adc4375aead4f0e741f158a4d86e`, and SaladUI 1.0.0 for existing
compatibility consumers. The stable SaladUI pin is the smallest upstream
resolution of the LiveView 1.2 tokenizer incompatibility; no fork or implicit
override is used. Phoenix.PubSub 2.2.0 and Spitfire 0.4.0 remain locked, so the
solve does not smuggle unrelated upgrades into the phase.

The npm lock is regenerated against those exact local Hex package manifests,
so `npm ci` no longer carries the stale Phoenix LiveView 1.1.33 development
graph. Node 24.3 reports engine warnings for LiveView's nested development-only
Babel 8 toolchain, while the root Vite/Tailwind production asset toolchain
installs and builds successfully.

The complete selected closure, licenses, roles, and integrity values are in
`phase_b2_resolved_sbom.json`. The release includes ShadcnUI and Dstar as
applications with no registered package processes; JidoCode starts no Dstar
StreamRegistry and adds no new LiveView route, socket, process, event, stream,
hook, or state owner.

## Facade And Theme Evidence

Only `JidoCodeWeb.Components.UI` imports ShadcnUI component modules. The facade
qualifies button, form-field input, native link, passive badge, table shell,
native disclosure, native dialog, and status primitives while preserving
`to_form/2`, `<.form>`, and the project's `<.input>`. It requires stable root
IDs, keeps closed variants, forwards reviewed global attributes to their
intended elements, escapes hostile content, and derives no authority from
component data.

The immutable ShadcnUI stylesheet input retains its HUI-B1 SHA-256. Application
tokens map its surface, color, focus, radius, and motion variables while
JidoCode retains typography and spacing. Light, dark, system, reduced-motion,
forced-color, RTL, print, zoom/reflow, and readable no-JS behavior have explicit
render or stylesheet evidence. Real supported-browser/manual assistive-
technology release qualification remains HUI-B4.

The upgraded LiveView formatter collapses the bodies of two empty decorative
spans in the existing coding-agent compatibility LiveView. That exact
markup-equivalent result is pinned by HUI-B2 and is the only authorized legacy
product-file formatter delta; it adds no route, event, stream, state, or
authority behavior.

## Asset, CSP, And Build Evidence

The locally tracked Datastar 1.0.3 bundle is exactly 33,538 bytes with SHA-256
`5d6b7794a50a83d82da962aec5e382f5ae83ac7afbc751f903f7a9c6bd433c65`.
It enters the one application JS bundle with no CDN or source map. HUI-B2 has
no production Datastar attribute and no Dstar product consumer.

Each response generates a fresh nonce shared by the enforcing CSP and the
root `data-nonce` opt-in. The policy permits self-hosted script plus the nonce,
requires the `datastar` Trusted Types policy, and has no unsafe eval, unsafe
inline, or remote script source. Static assets receive MIME, nosniff,
same-origin resource policy, ETag revalidation or versioned immutable caching,
and gzip output.

The deployment alias begins from clean generated digest state and normalizes
only non-semantic Phoenix manifest timestamps. Consecutive builds produced the
same Vite manifest, Phoenix manifest, JS/CSS, uncompressed tree, and gzip tree
digests recorded in `phase_b2_asset_pipeline.json`. The production release
assembled and `Application.ensure_all_started(:jido_code)` succeeded with its
asset manifest present.

## Verification Record

The executable HUI-B2 verifier pins dependency declarations, lock integrity,
facade ownership, theme source, exact assets, CSP directives, build policy,
consumer absence, documents, evidence, and receipt lifecycle. Negative tests
reject dependency/checksum drift, missing licenses, broad Shadcn imports,
Datastar/Dstar product consumption, asset/source-map drift, CSP weakening,
nonce faults, nondeterministic builds, and mixed closure state.

The phase candidate runs exact dependency resolution, npm installation,
warnings-as-errors compilation, the focused render/security/architecture
suite, repeated production asset deployment, production release
assembly/startup, `mix architecture.check`, and `mix precommit`. The local Hex
advisory audit passed; the npm production-only advisory endpoint timed out
after three minutes despite a successful registry ping, so its successful
clean-checkout CI run remains an explicit merge gate.
The final local `mix precommit` run completed all 1,204 tests with zero
failures.

## Exceptions And Limitations

There are no HUI-B2 exceptions. Existing LiveView, LiveVue, and SaladUI paths
remain only under their exact compatibility exceptions and HUI-H removal
ownership. HUI-B2 proves the dependency/component/asset boundary; it does not
claim the isolated enhanced consumer assigned to HUI-B3 or final browser and
accessibility release qualification assigned to HUI-B4.

## Gate HUI-B2 Reopening Conditions

HUI-B2 is merge-pending. After acceptance, the gate reopens if any selected
version, commit, checksum, license, dependency edge, lock, runtime application,
release footprint, or exception posture drifts; if a fork, floating constraint,
implicit override, or unrelated solver upgrade appears; if compilation or
release startup fails; if a new LiveView route, socket, process, event, stream,
hook, state owner, or product consumer appears; if ShadcnUI is imported outside
the facade, wrapper attrs/slots/IDs/escaping/native fallback regress, or a
component supplies authority; if theme tokens, contrast, focus, motion,
forced-color, RTL, reflow, print, or no-JS behavior regresses; if an asset is
remote, mutable, missing, mismatched, incorrectly typed, sniffable,
uncompressed, nondeterministic, or ships an unapproved source map; if CSP loses
its fresh nonce/Trusted Types behavior, gains unsafe eval/inline or a remote
source, executes Dstar Scripts, or admits an unreviewed expression; if manifest,
cache, stale-client, atomic-deployment, or rollback guarantees drift; if any
required evidence, limitation, negative case, or reopening condition is
removed; if any predecessor gate reopens; or if architecture, dependency,
license, security, focused integration, `mix precommit`, production build,
release, or clean-checkout CI fails at the exact candidate.
