# Hypermedia UI Dependency And Supply-Chain Decision Ledger

- Status: HUI-B1 candidate ledger accepted; installation and release credit blocked
- Recorded: 2026-09-03
- Baseline: `1e4073bb6968924abb2345e49453f980ae7eee92`
- Owner: HUI-B supply-chain, dependency, asset, security, and release owners
- Decision ledger: [`phase_b1_supply_chain_ledger.json`](../../priv/architecture/hypermedia_ui/phase_b1_supply_chain_ledger.json)
- Candidate BOM: [`phase_b1_candidate_bom.json`](../../priv/architecture/hypermedia_ui/phase_b1_candidate_bom.json)

## Selected Candidate Graph

The only authorized HUI-B2 acquisition inputs are ShadcnUI commit
`fe40eae63504adc4375aead4f0e741f158a4d86e`, Dstar Hex `0.2.0` plus source
commit `4bfb9110645f3831cd350f25434493c76a42bfae`, and Datastar signed tag
`v1.0.3` at `73ab00e7c06d8c2bad030fdddafba800fcccbde2`. Their archive, package,
asset, license, and notice digests are pinned in the candidate BOM and the two
source records. A name, semver range, branch, or versionless document is not an
authorized substitute.

The candidate Hex closure retains Phoenix `1.8.11`, Phoenix.HTML `4.3.0`,
Plug `1.20.3`, Jason `1.4.5`, and their existing locked transitives. It changes
the direct Phoenix LiveView resolution from `1.1.33` to the ShadcnUI-tested
`1.2.9`. That is a component compatibility selection, not permission to add a
product LiveView route, process, event, stream, socket, hook, or state owner.
HUI-B2 must prove all retained compatibility consumers and the absence of new
runtime consumers before this selection may land.

No npm package is added for Datastar. The exact official bundle is vendored
and imported through the existing Vite `app.js` pipeline. ShadcnUI's upstream
CSS build lock contains 66 npm components and direct Tailwind CLI/Tailwind
`4.3.3` tools. It is provenance evidence only: JidoCode copies the exact
compiled CSS and retains its already locked Tailwind `4.3.3` build instead of
installing the upstream graph. The exact upstream npm lock returned zero
advisories at every severity on 2026-09-03. The baseline Mix lock likewise
returned no retired or security-advisory packages. These are dated snapshots,
not durable safety claims.

## Rejected Inputs And Exceptions

The historical proprietary ShadcnUI revision, mutable ShadcnUI and Dstar
branches, React shadcn/ui, Datastar `1.0.0` through `1.0.2`, CDN delivery,
versionless documentation, and a release-tree Datastar rebuild are rejected.
The earlier Datastar patches require `unsafe-eval`; the selected release tree
cannot reproduce its committed bundle because it omits package metadata and a
lock. A local patch or fork is not selected. Any byte change creates a new
candidate and repeats this phase.

There is no exception that authorizes dependency or asset adoption today. Two
temporary, blocking decisions expire on 2026-10-03: the Phoenix LiveView
component-version transition and exact-byte Datastar vendoring. Both require
HUI-B2 clean-checkout, consumer, CSP, and digest evidence. Expiry or missing
evidence fails closed; it does not convert into an exception.

## Integrity, Cache, And Publication Policy

Git inputs use exact commits, trees, archives, and licenses; signed tags are
verified where available. Hex inputs use exact tarball and registry checksums,
requirements, and retirement state. npm inputs use the recorded registry URL
and package-lock integrity. Every artifact is hashed before extraction,
compilation, or import.

An explicit online acquisition step may populate a content-addressed cache
from only the recorded HTTPS GitHub, Hex, and npm locations. The subsequent
dependency install and asset build must work with network disabled. A missing
or mismatched cache item fails; there is no latest-version, branch, alternate
registry, CDN, or online fallback. Unexpected bytes are quarantined and open a
new review rather than causing expected digests to be rewritten.

The ledger is reviewed monthly and immediately on a source release, advisory,
retirement, signature, license, dependency, CSP, or protocol event. Emergency
response stops acquisition and release credit, quarantines caches, restores
the last accepted lock/asset manifest, assesses exposure, rotates affected
credentials, revokes unsafe runtime routes, and publishes remediation
evidence.

## HUI-B2 Evidence Contract

HUI-B2 must publish exact `mix.exs`/`mix.lock` resolution, retain or justify the
npm lock, vendor the selected Datastar bytes and license, integrate the exact
ShadcnUI CSS locally, produce Vite and Phoenix production manifests, and emit
a resolved SBOM naming every runtime, compile, build, optional-platform, and
native component with source, checksum, license, advisory state, role, and
consumer. Pull-request review and the merged-candidate SHA bind that evidence;
upstream signatures supplement but never replace project review.

HUI-B1 reopens on any selected identity, digest, license, dependency,
consumer, advisory, or risk-owner drift; unrecorded or mutable acquisition;
network fallback; unexpected transitives; weakened CSP; omitted lock, asset,
SBOM, license, or production digest; or creation of a prohibited LiveView,
Dstar, remote-asset, or browser-authority consumer.
