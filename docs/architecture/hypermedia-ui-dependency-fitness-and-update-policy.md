# Hypermedia UI Dependency Fitness And Update Policy

- Status: HUI-B4 executable policy installed
- Baseline: accepted HUI-B3 closure `e14ee7fa268eb6bd5a4d7bb7e519cce748d7b5e2`
- Owners: web, supply-chain, security, accessibility, release, and operations maintainers
- Machine record: `priv/architecture/hypermedia_ui/phase_b4_fitness_policy.json`

## Candidate Boundary

HUI-B4 qualifies only the exact HUI-B1 through HUI-B3 dependency, asset, and
consumer combination. The complete Mix and npm locks are immutable candidate
inputs. The selected HUI stack is Phoenix 1.8.11, Phoenix.HTML 4.3.0, Phoenix
LiveView 1.2.9 as component infrastructure and an existing compatibility
runtime, ShadcnUI at commit
`fe40eae63504adc4375aead4f0e741f158a4d86e`, Dstar 0.2.0, Datastar 1.0.3 at
commit `73ab00e7c06d8c2bad030fdddafba800fcccbde2`, and the locally vendored
Datastar bundle with SHA-256
`5d6b7794a50a83d82da962aec5e382f5ae83ac7afbc751f903f7a9c6bd433c65`.

The executable check verifies the predecessor manifests before accepting this
policy. It then binds their digests, both lockfiles, the selected source and
asset bytes, license set, exact consumers, and the closed set of forbidden
capabilities. A relevant drift therefore fails `mix architecture.check` and
the repository `mix precommit` gate.

## Consumer And Build Policy

ShadcnUI remains available only through `JidoCodeWeb.Components.UI` and its
single local CSS import. Dstar and Datastar remain limited to the isolated
qualification controller and fixture plus the one local application bundle.
They have no authorized product consumer. Dstar Scripts, remote/CDN assets,
source maps, inline scripts, unsafe CSP evaluation, browser-derived authority,
and new LiveView, LiveVue/Vue, or SaladUI product consumers are prohibited.

The accepted compatibility consumers are governed by the HUI-A4 exact-path
and digest exceptions and remain assigned to Milestone H. A changed or new
path is not implicitly covered. The build has no package-defined script or
network fetch: dependency acquisition is the explicit online step, followed
by `npm ci`, locked Mix resolution, and the local Vite/Phoenix asset pipeline.

## Deterministic Update Workflow

Every proposed update starts a new candidate identity. The owner must:

1. Pin the source commit, release/archive and bundle bytes, package checksums,
   dependency constraints, lockfiles, licenses, usage authority, and signer or
   publication evidence. Mutable branches, versionless URLs, CDN delivery,
   and tag labels without a locked commit are rejected.
2. Diff the complete Hex/npm/source graph, runtime applications, build steps,
   public facade, product and qualification consumers, browser assets, CSP,
   protocol behavior, and all active compatibility exceptions. Local patches,
   forks, and overrides require an explicit owner and new immutable artifact.
3. Renew advisory, license, upstream/downstream test, browser/proxy, manual
   accessibility, release-startup, stale/offline, and rollback evidence. Every
   report records tool version, environment, candidate, result, owner, and
   expiry or update trigger.
4. Replace all affected digests and negative fixtures in one reviewed update,
   run the HUI-B4 qualification task from a clean checkout, and merge only
   after CI proves both the candidate and intentional drift rejections.

No earlier evidence is silently carried forward. A changed source, version,
checksum, license, advisory, dependency edge, consumer, asset, CSP directive,
browser, protocol rule, or build step reopens HUI2 until this workflow passes.

## Reopening Conditions

The fitness gate reopens if a pinned input cannot be obtained or verified; an
unexpected dependency/application, mutable source, unreviewed fork/override,
remote asset, or build network step appears; an approved consumer widens; a
forbidden runtime or browser-authority pattern appears; a license or advisory
is unresolved; required update evidence is missing; or the executable
architecture, security, asset, browser, accessibility, release, rollback,
precommit, or clean-checkout gate fails.
