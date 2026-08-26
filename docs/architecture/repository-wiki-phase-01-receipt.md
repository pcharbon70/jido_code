# Repository Wiki Phase 1 Deterministic Substrate Receipt

## Status

This accepted receipt records the Phase 1 implementation candidate built from
repository main commit `1347712cb5e922b4ccf22a33677e1da912999c56`, which
contains the accepted delegated-agent Phase 1 prerequisite at
`5d79d798de87a8c652ad429fd677b6e82c69e764`. The implementation passed
clean-checkout CI and merged through pull request #81 on 2026-08-26 as
`606f646440a5e3cc60285143395638d9e951b69a`; RW1 is accepted at that exact
merged candidate.

The candidate publishes an additive repository-wiki ontology, an isolated
repository-and-edition graph family, explicit default-off enrollment, reviewed
semantic interfaces, immutable segmented editions, a bounded non-executing
source inventory, seven deterministic pages, zero-token accounting, and
graph-only recovery. Hosted synthesis, external metadata, Mix evaluation,
maintainer processes, and product activation remain unavailable.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted delegated-agent Phase 1 prerequisite | `5d79d798de87a8c652ad429fd677b6e82c69e764` |
| Phase 1 branch baseline | `1347712cb5e922b4ccf22a33677e1da912999c56` |
| Section 1.1 | `f73b38e076f1b7ca0fb711ff53bd8d8bf0b3077c` - governance baseline |
| Section 1.2 | `8e4d7c207e3e794f4748ab6cec140949d93a34e3` - ontology and graph topology |
| Section 1.3 | `8414bc0c2a4e28027356784df400525296c503f4` - enrollment and semantic interfaces |
| Section 1.4 | `79317adf43dc8589135f92b4d1d19e1f3e0faea4` - deterministic inventory, editions, and recovery |
| Section 1.5 | `1078f7b84811cddc914b6a6b74799ea5fbb90d28` - integration proof and merge-pending receipt |
| Merged candidate | `606f646440a5e3cc60285143395638d9e951b69a` - pull request #81, merged 2026-08-26 |

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

## Semantic And Runtime Pins

| Contract | Candidate value or SHA-256 |
| --- | --- |
| Ontology and SHACL release | `1.5.0` |
| Ontology manifest source | `8882971b7a094ac2befd44bfd4df06f6d93410bf537485e256b9d9ad92acd3a4` |
| Repository-wiki ontology source | `42ade252f06fddf681171a94620d71b6a28b2475cd2819516b77c4d99ab4beaf` |
| SHACL source | `4742a70bbd77e9c520e3ead967a74c756ff6fa4947cd359ce7a99d9459fa928e` |
| Canonical N-Quads | `ad5f4204a9b3e4d1e7b68ec9981858c3a081ab69a969622e83c86a1a81a66098` for 2,989 quads |
| Ontology package | `1906e03618313a15b11dc9889a9ffec38e3e400339094002c441de10d5578ba1` |
| GraphRegistry | `2.5.0`; source `da331f4fe94a502e1ccecd365ded9c4c09f83259427c9ef43de302e13db24f40` |
| Semantic command protocol | `2.10.0`; registry source `abd8e86eb8e859c3944593b0efa8413c726767d00bbd84bbf085e39502b457db` |
| Reviewed query protocol | `2.10.0`; catalog digest `86af88371404872115606ce5ba5deb2003a074b07dea7f54e7176010d36b8251` |
| Wiki compiler protocol | `1.0.0`, profile `wiki-deterministic-elixir/1.0.0` |
| Compiler profile digest | `9bdf98cdc80899a12d5b0ffe523816ac9dc3792dd11dc0675e3f4a346a7f44cb` |
| Inventory source | `5d4b471224c73c46e91e072b61693ba52c1c74bfd57f1e32b9c45291860cd413` |
| Compiler source | `543f6739ffa19c2d933a7214a3abdbfa4a78cbdaae8dbb98a72684e004d9e017` |
| Segmented-edition source | `450f132cbbc3b61bd3db51d9fd98a5999ef27126a27304d7949a38c342e648d7` |
| Recovery source | `abe832f8aaa2d260ec6868678774f7b5dc86f4110b08ed621fe3c81903b48ba1` |
| Retention source | `fc9de8b86b2a5d1fab15cdaf046b0050e59f81a27b370c11fc145d500575bbec` |
| Real-store integration fixture | `e93176a121f5d7b006dc495b8862c5b8dd795106f189cffa288a3386c87157f8` |
| Parallel-safe command fixture | `46acde93420c8527eb874698368e6f52d3404bab80a5b091812cbe9b20d4c60a` |
| Migration posture | Additive release and startup compatibility; no destructive data migration is authorized or required in Phase 1 |

## Enrollment And Isolation Evidence

- An absent repository configuration resolves locally to `off`, creates no
  work, exposes no product entry, and cannot inherit another repository's
  enrollment. Only exact manual and automatic deterministic profiles exist.
- Profile registration, enrollment, admission, edition persistence, lint,
  closure, activation, and disable run through the real serialized writer with
  graph authorization, exact dataset and graph revisions, provenance,
  idempotency, and stable conflict outcomes.
- The real-store matrix rejects an unauthorized profile, an unknown profile,
  stale source activation, a late result after opt-out, and repository identity
  paired with another repository's graph. The matrix exposed and closed missing
  `wiki_writer` authorization, graph placement, close-removal, and exact graph
  derivation paths before this receipt was written.
- Parallel successor commands from two sessions produce exactly one committed
  endpoint and one revision conflict. Exact repository-derived graph IRIs and
  reviewed queries preserve repository, tenant, edition, and read-scope
  isolation.
- Opt-out advances the cancellation generation, rejects new or late work,
  removes product availability, and preserves the closed edition, accounting,
  audit, and separately selected retained-read policy.

## Deterministic Edition And Recovery Evidence

- The source adapter inventories registered root files, documentation, source,
  tests, guides, and accepted graph references under fixed path, file, count,
  and byte bounds. Unicode is normalized; traversal and caller-selected roots
  fail closed; symlinked, binary, unsupported, oversized, missing, unreadable,
  ignored, and changed-during-read inputs are explicit gaps.
- Inventory never evaluates `mix.exs`, repository modules, scripts, hooks,
  build tools, network clients, providers, or models. The compiler emits seven
  stable attributed pages and one explicit successful usage record with zero
  model calls, input tokens, output tokens, and cost.
- Edition statements are partitioned into content-addressed predecessor-linked
  segments bounded to 800 statements and 192 KiB. Duplicate, malformed,
  oversized, discontinuous, incomplete, stale-fence, and post-closure writes
  fail closed or remain non-visible history.
- Real backup and restore preserve the application dataset. Open exact-fence
  editions are resumable, mismatched open editions are abandoned and hidden,
  closed editions are reconstructed from RDF alone, and navigation/search
  indexes are disposable graph-derived projections.
- Retention covers current, superseded, preview, incomplete, invalid, source
  snapshot, render artifact, accounting, and audit classes. Restore validation
  rejects multiple current editions, current pointers under `off`, cross-scope
  editions, missing audit evidence, and unknown graph lifecycles.

## Verification Record

| Command or gate | Candidate result |
| --- | --- |
| Repository-wiki contract, inventory, edition, recovery, and real-store integration suites | 26 tests, 0 failures |
| Architecture checks | Passed; zero findings |
| Ontology verification | Passed for release `1.5.0` and its pinned canonical/package digests |
| Compile with warnings as errors | Passed |
| Repository-wide isolated `mix precommit` | Passed; 950 tests, 0 failures; compile, architecture, lock, format, and test gates passed |
| Dialyzer | Passed; 178 existing warnings skipped by policy, zero unignored errors |
| Clean-checkout CI | Passed at pull request #81 head `1078f7b84811cddc914b6a6b74799ea5fbb90d28`: CI run `32989427186` and Dialyzer run `32989427148` |

## Known Limits And Disabled Posture

- Phase 1 statically reads `mix.exs` and `mix.lock` only as bounded source
  inventory entries. It does not interpret the Mix project, resolve a complete
  dependency closure, or fetch Hex, source, advisory, license, or link metadata;
  those remain Phase 2 work.
- Authored user and developer guide rendering, navigation/search product
  surfaces, previews, review UI, rollback, and production current-edition reads
  remain Phase 3 work.
- No maintainer process is started. Scheduling, leases, reservations, provider
  pricing, token budgets, synthesis usage, and automated reconciliation remain
  Phase 4 work. All repositories remain off by default and deterministic-only
  when explicitly enrolled.
- Phase 1 proves semantic activation mechanics but does not enable a production
  wiki route or a model-backed generation profile.

## Gate RW1

Status: **accepted at merged candidate**

RW1 is accepted at merge commit
`606f646440a5e3cc60285143395638d9e951b69a`, merged on 2026-08-26 after
clean-checkout CI passed. Phase 2 is authorized only from this exact pinned
baseline.

RW1 reopens regardless of checklist state if absent enrollment creates work or
visibility; repository, tenant, session, preview, edition, source, retention,
or usage data crosses scope; more than one current edition can exist; a stale
writer can append, finalize, lint, invalidate, or activate; a finalized edition
can mutate; a caller or repository value can select a graph, module, command,
path, endpoint, prompt, credential, price, or executable behavior; repository
code executes outside a later accepted fixed sandbox profile; deterministic
generation produces nonzero model tokens; a model/provider path becomes
reachable in V1; disposable process, queue, cursor, cache, preview, or artifact
state competes with graph authority; disabling enrollment accepts new or late
work; recovery cannot reconstruct from graph state and accepted artifacts; any
governing ADR or specification digest changes without reevaluation; the
delegated-agent Phase 1 prerequisite reopens; or ontology verification,
architecture checks, Dialyzer, precommit, or clean-checkout CI fails at the
exact merged Phase 1 candidate.
