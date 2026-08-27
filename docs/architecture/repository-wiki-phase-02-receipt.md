# Repository Wiki Phase 2 Mix And Dependency Intelligence Receipt

## Status

This merge-pending receipt records the Phase 2 implementation built from
repository main commit `1f70d3b1a73fde3a2429c7f99e09f32256a1a75d`, which
contains the accepted RW1 merged candidate at
`606f646440a5e3cc60285143395638d9e951b69a`. The implementation candidate is
not accepted until its single implementation pull request passes clean-checkout
CI, merges, and this receipt is updated in the required closure pull request
with the full merge commit and merge date.

The candidate implements bounded non-executing Mix and lock extraction, one
fixed network-denied sandbox escalation profile, exact source reconciliation,
complete represented lock closure, special-source containment, fixed Req Hex
metadata acquisition, repository-scoped positive and negative caching, safe
dependency links, deterministic dependency pages, and dependency-completeness
lint. It emits zero model calls, tokens, and model cost. Phase 3 remains
unauthorized while this receipt is merge-pending.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted RW1 prerequisite | `606f646440a5e3cc60285143395638d9e951b69a` |
| Phase 2 branch baseline | `1f70d3b1a73fde3a2429c7f99e09f32256a1a75d` |
| Section 2.1 | `5f73a995aaa1cc5b933f31d59a98f2e05f4164ad` - static Mix and lock extraction |
| Section 2.2 | `284e2a1f1e7ae165b50fc00e6a5a6b32917b2cbd` - contained observation and reconciliation |
| Section 2.3 | `efe1f27195543d7de012c3fe14be545a43849461` - complete dependency resolution and special sources |
| Section 2.4 | `86be4ec8f96568d29ff694afb675cedffc07ccad` - bounded metadata and safe links |
| Section 2.5 | `91a7087806fe8690d740fa3f41e675ef891c67fa` - deterministic pages and dependency lint |
| Section 2.6 | Merge-pending candidate commit containing this receipt |
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

## Extractor, Resolver, Metadata, Compiler, And Lint Pins

| Contract | Revision and candidate digest |
| --- | --- |
| Safe AST source | `6bf848c24f56ec8285620225d8c0566b8c5fc8b223596158ec37d03d7ddca8d1` |
| Static Mix extractor | `mix-static/1.0.0`; profile `1eae1d90b27c0f5231ab81cc8bd87bac61fdc3325300a2a1b57a36376aaa3af5`; source `5b1236abbe75378c58d72fbd62b459c3e471dec7c354fca275b40f8c054fe547` |
| Lock parser | `mix-lock/1.0.0`; profile `57d0e3c681c28771613c3b9e76181569dee72b318456128ddbc8acb97d7660b5`; source `64c9179ca3ac8119fca1ac4e57f1e3e95ade8bf5352881d2f643665740ad4835` |
| Mix sandbox | `mix-sandbox/1.0.0`; contract `c7aa1b3382b3e0a2edc3518bbe438be29bee844415184efaf420ddf5d7a2d5fd`; isolation `sha256:66ec792bf8e6190b18bacd8d155d92d42cab85da42ee2dfcf73d994d8e0c89b6`; source `0b03bc4615051b09b0c923fae10b8c55a778ae28a60d3e17dc6fe341ae341afd` |
| Mix reconciliation | `mix-reconcile/1.0.0`; profile `d18524ed53542768ffc64946ff54018310b44a3f20e15b4b0141a6bc9dfbff93`; source `83c292c9cc7eab9d5f55f5124b534cbc827d99e1d59f32662b1200b284024bd4` |
| Dependency resolver | `wiki-dependency-resolver/1.0.0`; profile `df4d981ceb0ff260cc23bdae239b6a6b11393f8bc1f4d2a24af3dfcde93e3c8f`; source `b4c45cf126df2bfcefb321489c633b3e969a7549edefff5630202c52cad789dc` |
| Special-source classifier | `wiki-dependency-sources/1.0.0`; fixture policy `1674c5951dc2c4ac535152a2707d1931cdf752302e54dc3cd516d7afe40579cb`; source `8a198ca5481064be970484e491f4944fc5bc1c7ec3a41250de48a837948b9e83` |
| Hex Req acquisition | `hex-req/1.0.0`; profile `8f88b8dd6e56889a75961b504d2926d1bc40292a8c97b3881b32e1445bf337b1`; source `5a7dafd22d874cbb78388d9f06f0091ecbcddc6896e8a2d2fe65ff3165b78027` |
| Metadata cache | `wiki-metadata-cache/1.0.0`; profile `768447f624502d624440b059c079573143c22eff604de862c829c4ba5498f2d0`; source `c1007bf2d91cb321e7e128fcad3c677208449d4091807bbd670532d20a6cf97f` |
| Dependency links | `wiki-dependency-links/1.0.0`; profile `8db6e3d64d2aced2e97316804971394c9c8c4df17147196092b5772cdf1e815e`; source `b92d289124985417ba5c3fb79c9a178cd9528ce3b2ae3608a3b2dc64d6771c54` |
| Base compiler | `wiki-deterministic-elixir/1.0.0`; digest `9bdf98cdc80899a12d5b0ffe523816ac9dc3792dd11dc0675e3f4a346a7f44cb` |
| Dependency page compiler | `wiki-dependency-pages/1.0.0`; profile `7e54e1dc074f1f66898a911b8cbefaaf41dade3563b0df6f0ba40b4effbc8cf9`; source `0e7072ea226586536852acbd71a780f195a749589d6fc458f1bab72e796c974b` |
| Dependency lint | `wiki-lint/1.0.0` plus `dependency-completeness/1.0.0`; profile `a083d973db6b77a9424159b036d919f0191a0f2eac0ff4cfeccc1ee793fe5878`; source `1a1385249908befdd70969a4549a2433fdb9c361c6c49accc3913803bee79513` |
| Phase 2 fixture | Source `243d6224e6832dbf55ee419730ee16136885550f066ca0acd9c12aa1c781a966`; catalog `a0ad94fd1bb58e812fe1efbf0948d5719a478f19f5652a5eb5c3e1a42e62c7ba`; compilation `69bce8f487e885268dd442492bec9b4f99a08113e4048a88e07b1ff7a218f4d7` |
| Phase 2 integration source | `21396089693be6e8f861e3e9d862d3525629462d9c82f2ec7762587625a5c801` |

## Extraction And Containment Evidence

- `SafeAst` uses the parser's static atom encoder and fixed source, AST-node,
  depth, string, and collection bounds. It does not evaluate, expand, load, or
  intern repository-selected atoms. Static extraction preserves exact literal
  dependency options and labels every dynamic expression and source location.
- The lock parser admits bounded literal Hex, git, and path forms, preserves
  future forms as unsupported evidence, and rejects term decoding, arbitrary
  code, duplicate keys, malformed integrity values, traversal, and caller-
  raised bounds.
- Sandbox escalation runs only unresolved requested facts through the existing
  harness using the controller-owned `jido-wiki-mix-introspect` executable in a
  fixed gVisor container profile. Source is read-only; scratch is disposable;
  network, dependency fetching, ambient credentials, host paths, Docker,
  devices, shells, hooks, project tools, and user configuration are denied.
- Reconciliation retains declared, locked, observed, and accepted candidates
  with exact source, parser, lock, sandbox, toolchain, and policy fences. It
  keeps disagreements explicit instead of replacing declaration truth with an
  observation.

## Closure, Source, Metadata, And Link Evidence

- Resolver identities are repository-and-edition scoped. Every lock entry is
  represented once; every admitted edge terminates in a represented node; all
  parents, roots, bounded simple root paths, canonical paths, cycles, roles,
  scopes, managers, versions, revisions, and classifications are deterministic.
- The current candidate repository observation contains 25 direct Mix
  declarations, 83 lock nodes, and 186 lock edges. Its honest catalog contains
  110 nodes and all 186 edges, including explicit unverifiable optional edge
  targets; it records 1,285 bounded paths, maximum depth 3, and 54 explicit
  gaps rather than dropping them.
- Path sources are admitted only beneath registered relative prefixes, with
  component and internal symlink denial plus bounded content manifests. Git
  sources require closed public hosts, HTTPS, no credentials, and immutable
  revisions before links are eligible. Private, credentialed, moving,
  ambiguous, outside-envelope, and unsupported locators remain unavailable or
  text-only, and raw private or credential-bearing locators are removed from
  downstream nodes.
- Req uses only `https://hex.pm` and exact package and release routes with
  fixed headers, TLS defaults, timeouts, response bounds, redirect denial, no
  automatic retries, and maximum concurrency. Package data is observational
  and cannot replace declarations or lock truth. Ordinary tests use immutable
  fixtures or `Req.Test`; they have no live-network dependency.
- Cache keys include tenant, repository, authorization class, package,
  version, and request-profile digest. Positive, negative, stale-if-error, and
  expiry behavior is disposable; no process or cache is graph authority, and
  tests prove one repository cannot reuse another repository's entry.
- Link policy independently validates generated and remote URLs. Only bounded
  ASCII HTTPS destinations without credentials, unsafe ports, IP literals,
  private/internal hosts, encoded controls, ambiguous paths, or application-
  internal navigation become clickable. Every other value is retained as
  non-clickable text with a reason.

## Deterministic Pages, Lint, And Parallel-Session Evidence

- The compiler adds Project, Runtime Requirements, Dependency Overview,
  Direct Dependencies, Transitive Dependencies, Dependency Gaps, and Metadata
  Freshness pages plus one stable detail page per catalog node. Detail pages
  include general information, declared/locked/observed facts, incoming and
  outgoing edges, bounded root paths, scopes, source state, provenance,
  observational metadata, and safe links.
- Page identity, order, anchors, slugs, facts, source citations, and statements
  are deterministic. The edition extension pins parser, lock, sandbox,
  resolver, source, metadata fixture, cache, link, compiler, lint, source fence,
  toolchain, and policy evidence with zero model calls, input tokens, output
  tokens, and cost.
- Dependency lint independently checks declaration and lock representation,
  exact supported edges, stable identities, unique pages, bounded paths,
  explicit classifications, source labels, visible conflicts, metadata
  authority, safe-link semantics, exact counts, digests, and zero-token
  accounting. Its profile digest is persisted on the edition lint report.
- All test workspaces use unique directories, cache instances are caller-owned
  and unnamed, source and edition identities include repository scope, and no
  module uses a global mutable wiki catalog. These properties permit parallel
  coding sessions and projects without shared fixture, cache, or edition state.

## Verification Record

| Command or gate | Candidate result |
| --- | --- |
| Repository-wiki extraction, containment, resolution, metadata, page, lint, protocol, and integration suites | Passed; 64 tests, 0 failures |
| RW2 end-to-end integration | Passed; exact closure, safe links, source fencing, segmentation, lint-profile persistence, and cross-repository denial |
| Architecture checks | Passed; zero findings |
| Ontology verification | Passed for release `1.5.0`; canonical `ad5f4204a9b3e4d1e7b68ec9981858c3a081ab69a969622e83c86a1a81a66098`; package `1906e036183a15b11dc9889a9ffec38e3e400339094002c441de10d5578ba1` |
| Compile with warnings as errors | Passed |
| Repository-wide isolated `mix precommit` | Passed; 1,005 tests, 0 failures in 605.4 seconds |
| Dialyzer | Passed; 178 existing warnings skipped by policy, zero unignored errors |
| Clean-checkout CI | Pending implementation pull request |

## Known Limits And Disabled Posture

- Remote Hex metadata is observational and can be stale or unavailable. Phase
  2 does not claim registry metadata is project truth and does not fetch source,
  license, changelog, or advisory bodies.
- Authored user and developer guide compilation, product routes, navigation,
  search, previews, review, and activation remain Phase 3 work.
- No wiki maintainer process, scheduler, lease, reservation, model invocation,
  token-priced synthesis, or automated source mutation is enabled. Those remain
  Phase 4 or later work, and repository enrollment remains default-off under
  the accepted RW1 contract.
- Clean-checkout CI, implementation merge provenance, the full Section 2.6
  commit, merge date, and closure checklist pins remain intentionally open.

## Gate RW2

Status: **merge-pending**

RW2 remains open until the implementation pull request passes clean-checkout
CI and merges, after which the closure pull request must record the full merge
commit and merge date and tick only the closure-authorized plan boxes. Phase 3
is not authorized from this merge-pending receipt.

RW2 reopens regardless of checklist state if repository code executes on the
host or escapes the exact fixed sandbox; a repository can select an executable,
argument, environment, endpoint, redirect, network policy, credential, cache
scope, parser extension, graph, or compiler behavior; any supported lock node
or edge is omitted, duplicated, or points outside represented closure; source,
toolchain, parser, sandbox, policy, repository, tenant, authorization, or
edition fences drift; private, credentialed, moving, ambiguous, Unicode-
lookalike, encoded-control, unsafe, or unverified destinations become
clickable; remote metadata overrides declared, locked, accepted, or observed
source labels; a path source escapes its registered envelope or traverses a
symlink; positive, negative, or stale cache state crosses repository, tenant,
or authorization scope; deterministic generation records nonzero model calls,
tokens, or cost; page, source, graph, lint, fixture, profile, or protocol output
is nondeterministic or unpinned; an unresolved or conflicting fact is hidden;
parallel sessions share mutable wiki authority; any governing ADR or
specification digest changes without reevaluation; RW1 reopens; or ontology
verification, architecture checks, Dialyzer, precommit, or clean-checkout CI
fails at the exact merged Phase 2 candidate.
