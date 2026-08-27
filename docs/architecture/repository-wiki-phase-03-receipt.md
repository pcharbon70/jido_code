# Repository Wiki Phase 3 Guides, Product, Preview, And Activation Receipt

## Status

This merge-pending receipt records the Phase 3 implementation built from
repository main commit `7b4d0916713addcdaa6855dbcde6926802b55640`, which
contains the accepted RW2 merged candidate at
`81dd898dc92c757360c142661b30f88ce8df8c30`. The implementation candidate is
not accepted until its single implementation pull request passes clean-checkout
CI, merges, and this receipt is updated in the required closure pull request
with the full merge commit and merge date.

The candidate implements bounded guide discovery and rendering, deterministic
full editions, immutable update classification, reviewed product reads,
disposable search, authenticated repository navigation, opaque session
previews, independent review evidence, exact activation qualification,
serialized current-edition replacement, and governed retention. Deterministic
generation records zero model calls, tokens, and model cost. Phase 4 remains
unauthorized while this receipt is merge-pending.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted RW2 prerequisite | `81dd898dc92c757360c142661b30f88ce8df8c30` |
| Phase 3 branch baseline | `7b4d0916713addcdaa6855dbcde6926802b55640` |
| Section 3.1 | `813b5a99a2ccc5ea39d2e5bbc79674f16003a13a` - guide discovery and safe rendering |
| Section 3.2 | `7f0ab68e1cafb2e3bf073c91535255599b691e3e` - full deterministic editions and update classification |
| Section 3.3 | `f3da5dbea2f56f23cdc277eaa3a7d224dcbd2122` - reviewed product reads, search, navigation, and settings |
| Section 3.4 | `54c6818b256198e8da7fbf834db25abcd66664af` - preview isolation, review, qualification, activation, and retention |
| Section 3.5 | Merge-pending candidate commit containing this receipt |
| Merged candidate | Pending implementation pull request, clean-checkout CI, and merge |

## Governing Document Pins

| Contract | Candidate SHA-256 |
| --- | --- |
| ADR 0005 | `f337c4d6906f503c599bd8918d94d3356e9e5b81cc4125e93913687fb9f1a92e` |
| ADR 0006 | `c5ad6007b433214ba2a6a9119ef278f91d540d78408d070071e7591634cd28f1` |
| ADR 0007 | `c1b28b110b8e3bd586fd2365bb4d58c145c340973ea6d0f3c4739a3a5f2570e4` |
| Research deep dive | `91932a84774da9ef916c44895ee70a81cfb78b7b13dc7dd9dd5c319a43d0088f` |
| Governance baseline | `e7de65ac5eb50fd40bedb741e2919154df9997030357a4a2b3e146fc37a48475` |
| Graph and edition contract | `69d18609ae321b9583e76053110814850804df8c10ea758d60c7b4f0693c584b` |
| Compilation and update protocol | `91a455537a50fe894f8c84ccffbb8f96143b484847e4f390d2c828cfafc78f0d` |
| Enrollment, budget, and accounting | `796d9f913db481f9173aa0d5b5c7c0983a8421cfef58eb1638e01aabf29ca4fa` |
| Mix project and dependency catalog | `b309e869709e8fdc5b480002f7a8ff5ecb922eb038e4d15e979582a56281736d` |
| Maintainer runtime | `afa75952bf645ea0533df2d203aa053c24a6c0af83985587d31912a2bc348561` |
| Product and qualification | `473ec19f0670c07da516f487e0ec3270f5c413138321f8c432609382f029bcef` |

## Compiler, Query, Product, And Lifecycle Pins

| Contract | Revision, profile digest, and source SHA-256 |
| --- | --- |
| Guide discovery | `wiki-guide-discovery/1.0.0`; profile `68e055f7925c058813515c50adc84fb878b38a17e7fa713129fb0fb1c4969d37`; source `77256cd2f4fdd12c279fba7bcc7d835d9e8fea9aa4d2d96b8a1e187e75346d05` |
| Safe guide renderer | `wiki-renderer/1.0.0`; profile `c674dc9ef3fc3bed455bb3636242f508344304a92f261c90e3c86e8c5069549e`; source `a008122a31457c23576dde7a9c09bf1772748455dc7acb14521eec022e9a63df` |
| Full edition compiler | `wiki-full-edition/1.0.0`; profile `7e12132efbe688b7e0473ef8b6e20ebe9cfde7889d4d35749e428eb7a02a4b93`; source `0ccdd1a794796d64193d67925f39ab8778b1b17399fa718f08b821a77ac5b2fc` |
| Base deterministic compiler | `wiki-deterministic-elixir/1.0.0`; digest `9bdf98cdc80899a12d5b0ffe523816ac9dc3792dd11dc0675e3f4a346a7f44cb` |
| Update classifier | `wiki-update-classifier/1.0.0`; profile `dd24d95a3e2494598aae6c485292272d282a382a650ad14e84e7dfc45a79f45d`; source `d2a64d54de3c8c82cd72b4521e504eaa90b686b46112f11be86d4fb81d3ca705` |
| Dependency and edition lint | `wiki-lint/1.0.0`; profile `a083d973db6b77a9424159b036d919f0191a0f2eac0ff4cfeccc1ee793fe5878` |
| Reviewed query catalog | `2.10.0`; 17 repository-wiki definitions; aggregate source digest `526dc66bc41ec4a980a278080c5c37191c2a18295a8cf6ac37c0345a2a7e9f16`; catalog source `76aab8c6459764e35cdcd8b387ea3872e95a9e0bd51e19044c6e5d31571c042b`; query source `0023f128af7f22548c26657209ba0c3b4261285e57127e4aa8d7cd8f32a79a01` |
| Disposable search | `wiki-search-projection/1.0.0`; profile `cafe5a956a8bd096ac3015891bcced8c81791ff59ca886067f911531c6688a38`; source `f93a7585b641d61bb980713bc8f0908cb8f81df1665094b975127b1a9af67408` |
| Product projection and UI | projection source `fc23b178cac2e9c8bfb74f96a46188648ee5bb5d21aa2cc3de107a3f517a08fb`; LiveView source `ff843a54ac2b27aafbda278adc48c2521f0c56c42600ee4675b79b9d950b500a` |
| Session preview | opaque reference `rwp1`; source `69062ff6249552c47aec9d4f07eb2c7568146636a3c54c7a16316a9ede955ec2` |
| Review decision | exact immutable evidence; source `ae1118c758412c438bdea02d13d6a63a8a0917b71c48267d1ad72a4e110faeb3` |
| Qualification | closed outcomes `qualified`, `stale`, `competing`, `disabled`, `unqualified`, `duplicate`, and `unauthorized`; source `a9490998e6e447b8548bce4380fdd1e2d00de7174b1beacd6457f8748c3a3750` |
| Activation | reviewed compare-and-swap and accepted-only cache directive; source `a81d99553a1a720cf37187267eb0a459e1609400c6574002c4aeb8dae4c8513e` |
| Retention | current, superseded, preview, expired-preview, rejected, incomplete, invalid, source, render, accounting, and audit classes; source `32eee191152ad3ecaf65bd7b59add1cd00a46b71d7c87b4735395c9b40657303` |
| Phase 3 integration corpus | source `d5e59556091e47e2be5e90083f18e9a2582f4dd349075db3073843067284e2ea` |

## Guide Safety And Deterministic Edition Evidence

- Discovery is repository-rooted, rejects traversal, symlinks, devices,
  binaries, invalid encoding, oversized inputs, and caller-selected parser
  extensions, and derives renames, duplicates, title collisions, and moved
  anchors only from immutable manifests.
- Rendering admits a fixed Markdown subset, escapes raw HTML, denies scripts,
  event handlers, styles, forms, embeds, data URLs, dangerous schemes, and
  privileged application navigation, and exposes unresolved links as bounded
  text-only findings. Credential patterns block activation and retain only
  redacted fingerprints and diagnostics.
- Full editions contain stable overview, guide, architecture, project,
  dependency, source, operations, provenance, freshness, and gap collections.
  Identical admitted inputs reproduce the same page, graph, navigation,
  coverage, render, usage, and compilation digests byte-for-byte.
- Update classification is derived from immutable before/after manifests and
  exact enrollment, source, compiler, and policy fences. Drift makes the prior
  edition visibly stale; retained readability remains an independent policy.

## Product, Search, And Authorization Evidence

- Every product read uses a closed catalog query and exact graph-family,
  repository, actor, tenant, edition, visibility, and dataset-revision checks.
  Raw SPARQL, arbitrary predicates, browser-supplied graph identity,
  cross-edition joins outside the comparison query, and unbounded search are
  rejected.
- Search tokenization, fields, ranking, snippets, and result limits are fixed.
  Candidate pages are authorized before index construction, and search and
  navigation values are disposable projections rebuilt from accepted graph
  state after restart.
- The authenticated repository workbench exposes Wiki only under retained-read
  authority. Stable DOM IDs cover disabled, empty, stale, incomplete,
  unavailable, current, and settings states; reviewed views cover guides,
  architecture, project, dependencies, source, search, history, and gaps.
- Off, Manual, and Automatic deterministic settings retain an explicit
  zero-model-token posture. Runtime regeneration remains unavailable until the
  Phase 4 maintainer is installed.

## Parallel Preview, Review, Activation, And Retention Evidence

- Every preview identity binds actor, tenant, repository, session, attempt,
  candidate, source snapshot/fence, compiler profile, fencing token,
  enrollment revision, reviewers, and expiry. Its presentation reference and
  cache namespace reveal none of those raw bindings.
- Participant and reviewer authorization is exact and precedes preview graph
  resolution. Sibling session references, counts, slugs, cache namespaces, and
  lifecycle transitions remain independent; preview editions cannot enter
  current navigation, agent context, or activation qualification.
- Review evidence binds the exact edition root, lint and render profiles and
  outcomes, coverage, blocking warnings, policy, reviewer class and authority,
  decision, reason, and time. Approval is consistent only with passing
  blocking lint/render checks, complete coverage, and no blocking warning.
- Qualification is recalculated immediately before command construction. Any
  enrollment, current pointer, source, graph revision, profile, compiler,
  policy, reviewer authority, lint, render, or evidence drift returns a closed
  non-authorizing outcome and retains attributable candidate history.
- Activation appends one repository-control enrollment transition and records
  activation/supersession lineage under the exact expected graph revisions.
  Writer serialization admits one competing successor. Only a newly committed
  receipt invalidates disposable navigation and search; replay and failure do
  not.
- Retention can delete expired preview/render caches and compact rejected,
  invalid, or incomplete diagnostics only when not selected, cited,
  release-required, or immutable evidence. Retained history has no direct
  authority to restore itself as current.

## Verification Record

| Command or gate | Candidate result |
| --- | --- |
| RW3 guide, compiler, classifier, query, search, product, preview, qualification, activation, retention, ontology, and integration suites | Passed locally; 146 tests, 0 failures before final precommit |
| RW1-RW2 regression coverage | Passed through the repository-wiki suite, including real writer lifecycle, graph-only recovery, one-successor races, sandbox/dependency fixtures, zero-token accounting, and restore contracts |
| Architecture checks | Passed; zero findings |
| Compile with warnings as errors | Passed |
| Dialyzer | Passed; 178 existing warnings skipped by policy, zero unignored errors |
| Repository-wide `mix precommit` | Passed on Section 3.5 code candidate `cfd3630`; 1,052 tests, 0 failures in 587.8 seconds |
| Clean-checkout CI | Pending implementation pull request |

## Known Limits And Disabled Posture

- Phase 3 installs semantic preview, review, qualification, and activation
  contracts but no always-running maintainer, graph work scheduler, lease,
  reservation, model invocation, or automatic regeneration runtime. Those are
  Phase 4 work.
- Deterministic-only generation is the sole enabled compiler posture and emits
  zero model calls, input, output, cached, and reasoning tokens and zero model
  cost. Synthesis commands remain reserved-disabled.
- Preview actor/session/candidate bindings are held behind the reviewed opaque
  resolver and are deliberately absent from ordinary graph/product results.
  Preview graphs have bounded non-backup retention.
- This receipt remains merge-pending until exact-head clean-checkout CI, merge,
  full merge SHA, merge date, and closure checklist state are pinned.

## Gate RW3

Status: **merge-pending**

RW3 remains open. Phase 4 is unauthorized until the implementation candidate
passes clean-checkout CI, merges, and this receipt is accepted at the exact
merged candidate in the required closure pull request.

RW3 reopens regardless of checklist state if authored guide markup executes or
renders unsafe HTML, script, event, style, form, embed, data, credential, or
privileged navigation content; guide identity, audience, rename, anchor, page,
graph, navigation, coverage, render, update classification, or deterministic
replay becomes unbounded, unattributed, or nondeterministic; any deterministic
path records nonzero model calls, tokens, or model cost; a product caller can
submit query text, graph identity, predicate, source path, actor, policy, or
command authority; repository, tenant, edition, visibility, preview, session,
attempt, candidate, source, compiler, policy, reviewer, enrollment, graph
revision, or cache scope crosses its boundary; a hidden or expired preview is
disclosed through reads, search, navigation, counts, logs, cache keys, hints,
notifications, or direct references; a preview enters agent context, ordinary
current reads, or activation; activation succeeds with incomplete content,
blocking lint/render findings, missing or stale review, a stale source or
profile, a changed current pointer, opt-out, cancellation, late writer, or any
other drifted fence; more than one competing successor becomes current;
failed, duplicate, stale, or unauthorized activation invalidates accepted
product caches; retention deletes selected, cited, release-required,
accounting, audit, activation, review, usage, or immutable lineage evidence;
retained history can restore itself without a new qualified activation; any
RW1 or RW2 invariant reopens; any governing ADR or specification digest changes
without reevaluation; or ontology verification, accessibility/security suites,
architecture checks, Dialyzer, precommit, or clean-checkout CI fails at the
exact merged Phase 3 candidate.
