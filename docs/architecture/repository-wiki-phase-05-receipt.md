# Repository Wiki Phase 5 Context, Fleet, Qualification, And Release Receipt

## Status

This accepted receipt records the Phase 5 implementation built from repository
main commit `56a3687a1238629af8d8d636e1b2f68857d3dc92`, which contains the
accepted RW4 merged candidate at
`255baefc0f3c3726e639104038a714ddacb85562`. Implementation pull request #95
passed exact-head clean-checkout CI and Dialyzer and merged on 2026-08-28 as
commit `574808c1ab8f5ae002c0e7e77af95b53f611b72a`. RW5 is accepted at that exact
merged candidate.

The candidate adds advisory current-edition wiki context to parallel coding
sessions, repository and fleet usage/cost/health projections, multi-repository
backup and recovery evidence, a signed adversarial qualification corpus,
fail-closed security and quality evaluators, the self-hosted `jido_code` pilot,
and a closed deterministic V1 release catalog. Every repository remains Off by
default. Hosted model synthesis remains unavailable. The five-phase
repository-wikis plan is complete at this pinned deterministic V1 baseline.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted RW4 prerequisite | `255baefc0f3c3726e639104038a714ddacb85562` |
| Phase 5 shared-main baseline / accepted RW4 closure | `56a3687a1238629af8d8d636e1b2f68857d3dc92` |
| Section 5.1 | `66ece9a0f806f75daaa4702c659ba9b0b83376c2` - attributable bounded repository-wiki agent context |
| Section 5.2 | `1769571dcdaff6a0cf5b3fac8d14f830ea837e1d` - fleet operations, observability, backup, and cost reporting |
| Section 5.3 | `18ec29028ca43fabc02b137975a0f9bd0941a414` - signed corpus and fail-closed security/quality evidence |
| Section 5.4 | `fb684d57e286b25517739b8976f0deda14e46cd7` - self-hosted pilot and deterministic V1 release catalog |
| Section 5.5 | `a5c4802d4f7d10a216ec8962daadcfbaf7b0dbb7` - integration proof and merge-pending receipt |
| Merged candidate | `574808c1ab8f5ae002c0e7e77af95b53f611b72a` - implementation pull request #95, merged 2026-08-28 |

The shared workspace contained independent parallel-session work in a
different worktree. Phase 5 changed only its own feature branch. No other
session's branch, worktree, queue, process, or uncommitted state was used as
authority or modified by this implementation.

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

## Context, Operations, And Recovery Pins

| Contract | Revision, digest, and candidate source SHA-256 |
| --- | --- |
| Wiki context profile | `wiki-context-deterministic/1.0.0`; profile digest `c0ad5c0e9b4d6537141ff60d332b721a68b18d9e8b2d0a7bb29365add173dd1d`; source `a1c27b3fc238e8de452c6080c6feb49d0ed68c562ec760b792dd201a2dcd91a1` |
| Current-edition context source | exact actor/tenant/repository/task/session/attempt/source/edition/profile fences; source `9e6906990070bd3c413f5e3cb9d50ad7ce544136361d685f9f5b45ab8f368514` |
| Shared context assembler | direct task/source above wiki above admitted lower-confidence memory; source `c23d4c309e3bafab0f9e8ddafbe940ebcfd6dde09465735add496ed97dc28f9a` |
| Repository usage and cost projection | exact deterministic zero, reservations, pending/unknown, currency, and bounded breakdowns; source `8258d4af1809e15980582f036200eaf0b2f4cea804bcf5bc405bd19a0febee22` |
| Fleet operations | bounded repository summaries and ten closed alert types; source `979c24fc0e84c9e84331fb97bdad93f27ec03733a0e2358b2afab355ccef56b1` |
| Backup and restore | bounded multi-repository restore verification before projection rebuild and maintainer restart; source `3d31cdb73a43febc9fb865056616199631529a8fc9db9bd68862db70da74bd4e` |
| Operations telemetry | low-cardinality content-free schema; source `4127c6447236af0fdb3ededdaf902dad287bfde091e19987e1b4ad6175ef7e2f` |

## Signed Qualification Pins

The qualification signer and verifier are injected ports. Private key
material is absent from source, graphs, reports, and diagnostics. The values
below are canonical payload digests; a release also requires valid signatures.

| Artifact | Revision or digest |
| --- | --- |
| Signed-evidence envelope | `repository-wiki-signed-evidence/1.0.0`; source `df8a98823c9485b07ad8f36b65a8473f5731226b3e96dde2949f6e7360823a8a` |
| Qualification manifest | `repository-wiki-qualification-corpus/1.0.0`; envelope digest `c9d772b01162b1214af5c70841b7f7d1b6813f1cf7e92f1c8ff0bc8e005f3ad3`; source `228345dc23c889281f218d45055887904cbeb10282ffec30a5b1b61cbfcc8d25` |
| Fixture corpus | `abfc30bd2a65c638a58dfb4b6809ff3fee9cd3f1227104d9a362480c3a1fce01` |
| Expected graph/page/usage outputs | `9720fe9a5038184be3347c25093931ac0a5bfeb17154b28ff51ef3d1313ca8a1` |
| Component profiles | `5e817d4dde29b98077b00be0f7b895c9d47adc4bb415248f038a25ef2b677572` |
| Frozen qualification clock | `b9895f7afe98aebecdcda7aba2c082f477b9bc7adfa8825885bed0fa06b504c6` |
| Evaluator contract | `db5a7f288193f86996edd2323434f2ce3aa55a167e9a60299a776a8b2311dd75` |
| Release thresholds | `e09383aa26ad3ddd2492e6e3d47ec6322a2e4f79a552796d19593bedc0f3a76e` |
| Security evaluator | `repository-wiki-security-evaluator/1.0.0`; source `3123e4889a88e10bede667617dbafa6fd0deb0f197c2aa29ce9f91457d94ce38` |
| Quality evaluator | `repository-wiki-quality-evaluator/1.0.0`; source `87ddc1a0cbc3a46f54376333c85fe39e4ccf255816bd6d94ae73a5ff8b916eb1` |

The corpus contains 15 repository, 11 guide, nine concurrency, and ten
accounting fixture manifests. Security admission covers 31 attack scenarios
and 30 non-negotiable invariants, requires zero critical/high findings, and
permits only documented bounded residual risks no higher than medium. Quality
admission requires nine completeness dimensions, two replay runs on each of
four axes, six usefulness tasks, five isolation scenarios, and nine signed
resource ceilings.

## Pilot And Release Pins

| Contract | Revision, digest, and candidate source SHA-256 |
| --- | --- |
| Self-hosted pilot | `jido-code-repository-wiki-pilot/1.0.0`; source `f15877aa6f907d70bb1fc8521ac6a8b51e8b3f929914098504ed9343810c8b01` |
| Signed merged-checkout pilot | Source `574808c1ab8f5ae002c0e7e77af95b53f611b72a`; source revision `26a26852b644ab0cdf649e64919d2fc32f14c6799dd92b13cf2e7a8fb37231eb`; report digest `15427aec26aac22c6b8ab838a01103f39f00a38474eeec39de321fa3b33d928d`; pilot digest `f68d0f4e8b8a17119da3d23ce216e67df834cc9816c987a6b4f7bab8784dcc8e`; edition root `496ac512f9ec4c00f89e16327cc48eddcc15eee43e9944de72c11795f1aa832c`; Ed25519 public key `iBswLc9fbPcu+pAbzW3FvUqxQwZjKpVtJ+l/g+/9irQ=`; signature `tceDtcwCW+LOIU1zqiNE6zrzxEGmtc5v3h8yKPMsWRxY+FqhUU1h2Rr3x/xx1IOHXJ40tXRZkNIw5HYLxmiwAw==` |
| Deterministic release catalog | `1.0.0`; catalog digest `c823ece63afd8233f83cc9ec354e81dad750b5a450c5a5c9c35c92c85e117d77`; source `d193e7f25fe9d8da13c75388d5c19fa4610b751bf5dfbc3134c59b59707c8b06` |
| Compiler | `wiki-full-edition/1.0.0`; `7e12132efbe688b7e0473ef8b6e20ebe9cfde7889d4d35749e428eb7a02a4b93` |
| Mix parser | `mix-static/1.0.0`; `1eae1d90b27c0f5231ab81cc8bd87bac61fdc3325300a2a1b57a36376aaa3af5` |
| Observation sandbox | `wiki-observation-sandbox/1.0.0`; `6660b587743ee9f1ae27ba99541ac2d952109344432d1533c90fdbc3eb16042f` |
| Metadata | `hex-metadata/1.0.0`; `0b1a9c02f8809eaedb770532905922a3f6618b3f3a7125634cf0bec03532c240` |
| Lint | `wiki-lint/1.0.0`; `a083d973db6b77a9424159b036d919f0191a0f2eac0ff4cfeccc1ee793fe5878` |
| Renderer | `wiki-renderer/1.0.0`; `c674dc9ef3fc3bed455bb3636242f508344304a92f261c90e3c86e8c5069549e` |
| Phase 5 integration matrix | source `841f1bfce69d2845e277edfabd77a1b189188a61cc425d34fd686ac974c89670` |

The pilot compiles the actual `jido_code` checkout at a caller-pinned commit.
It verifies source and project identity, all declared dependencies against the
complete supported lock catalog, all configured guides, accepted ADR/
architecture/plan/research coverage, safe rendering and links, visible gaps,
navigation, search, and exact zero model usage. The accepted inventory ceiling
covers `lib` and normative documentation and exposes the deliberately omitted
test-tree inventory as a visible gap; the test tree remains Git-authoritative.
The signed merged-candidate replay admitted 915 inventory files, 25 declared
dependencies, all 83 supported lock entries, all 182 configured guides, and
181 accepted documents with zero model tokens and zero model cost.

The pilot then records two isolated session previews, a controlled successor
source, two reviewed source-fenced activation candidates, exactly one current
edition, and one competing result. Automatic deterministic maintenance is
exercised only after manual evidence passes. The final Off transition retains
the selected edition, accounting, and audit evidence while reporting zero new
work, running maintainers, model tokens, and model cost.

The release catalog pins ontology `1.5.0`, GraphRegistry `2.5.0`, semantic
protocol `2.10.0`, wiki protocol `1.0.0`, and the component tuple above. Only
`manual_deterministic` and `automatic_deterministic` are selectable after
explicit repository enrollment. Provider, model, price, prompt, and
production synthesis-adapter catalogs are empty.

## Documentation Pins

| Guide | Candidate SHA-256 |
| --- | --- |
| User guide | `8ad6a8ab01a9badcdf3c9194bc7cb807f37b59832e3747f7c36521f6b36f64fa` |
| Developer guide | `38bb0ac3b4cc8fafa18f6b3e816a867cfa0ea9bfb7461590e8811e493c2820d7` |
| Operator runbook | `5678374f3f463651e71db79f7ba25ce5ae006cdb139aa50c08dc6d9b0e06f836` |

The documents cover the supported repository envelope, advisory trust model,
parallel sessions, cost semantics, privacy, retention, explicit opt-out,
limitations, incident handling, backup/restore, graph repair, disabled
synthesis, qualification, rollback, and reopening conditions.

## Verification Record

| Command or gate | Candidate result |
| --- | --- |
| RW5 context, operations, corpus, evaluator, pilot, and release suites | Passed locally before final candidate commit |
| RW1-RW4 repository-wiki regression suite | Passed locally before final candidate commit |
| Parallel-session and cross-repository matrix | Passed; exact context/session pins, preview exclusion, source/activation races, fleet scope validation, multi-repository recovery, signed concurrency fixtures, and pilot one-current evidence |
| Cost, opt-out, and synthesis posture | Passed; exact deterministic zero, pending/unknown/multicurrency views, retained accounting, Off-by-default, empty provider/model/price/adapter catalogs, and disable zero-work evidence |
| Security and quality qualification | Passed; signed complete evidence admits, while tampering, missing invariants, critical/high findings, replay drift, source mixing, and ceiling excess fail closed |
| Architecture checks | Passed; zero findings |
| Compile with warnings as errors | Passed |
| Dialyzer | Passed; 178 existing warnings skipped by policy, zero unignored findings, and zero unused filters |
| Repository-wide `mix precommit` | Passed; 1,152 tests, 0 failures in 579.4 seconds; compile, architecture, lock, format, and test gates passed |
| Clean-checkout CI | Passed at exact implementation head `a5c4802d4f7d10a216ec8962daadcfbaf7b0dbb7`; CI run `33182221473` completed in 16m56s and Dialyzer run `33182221719` completed in 1m42s before merge |
| Signed merged-checkout pilot | Passed and admitted at exact merge commit `574808c1ab8f5ae002c0e7e77af95b53f611b72a`; report and Ed25519 verification evidence are pinned above |

Exact-head clean-checkout CI and Dialyzer passed before merge. The signed pilot
was rebuilt from the clean merged checkout; future failures still reopen RW5.

## Known Limits And Disabled Posture

- Hosted synthesis remains structurally unavailable. Qualification and pilot
  evidence authorize no provider, model, price, prompt, credential, endpoint,
  tokenizer, production adapter, or fallback.
- The signed corpus consists of immutable manifests and deterministic oracles;
  externally retained fixture bodies and execution observations must match
  their digests and signatures. A signature does not make a failed invariant
  pass.
- V1 supports bounded Elixir single-application and umbrella repositories.
  Dynamic Mix facts, unsupported content, missing/private metadata, oversized
  trees, and external outages remain visible gaps or failures.
- The accepted pilot output is pinned to exact merged implementation commit
  `574808c1ab8f5ae002c0e7e77af95b53f611b72a`; a report from a dirty, different,
  or moving source is not acceptance evidence.
- Any later implementation, governing-contract, compiler, qualification,
  release, source, or pilot digest change requires reevaluation under the gate
  conditions below.

## Gate RW5

Status: **accepted-at-merged-candidate**

RW5 is accepted at merged candidate
`574808c1ab8f5ae002c0e7e77af95b53f611b72a` after exact-head clean-checkout CI,
Dialyzer, merge, and signed merged-checkout pilot replay on 2026-08-28. The
five-phase repository-wikis plan is complete at this exact pinned baseline.

All reopening conditions in accepted RW1, RW2, RW3, and RW4 receipts remain
normative, cumulative, and incorporated here without deletion, replacement,
or weakening. RW5 also reopens regardless of checklist state if wiki context
creates graph facts or gains policy, command, tool, credential, runtime,
verification, publication, approval, or merge authority; context, pages,
search, previews, caches, logs, telemetry, usage, or operations evidence leaks
across actor, tenant, repository, task, session, attempt, source, edition, or
visibility scope; a running context changes without explicit successor
compilation; current reads or context mix source revisions, editions, or
previews; deterministic replay differs across required runs or environments;
dependency, project, guide, source, provenance, link, navigation, gap, lint, or
render coverage is missing or falsely complete; a critical/high security
finding, unbounded residual risk, unsigned invariant, failed usefulness task,
or exceeded resource ceiling is admitted; an unconfigured or Off repository
creates compilation, maintainer, reservation, network, model, token, or cost
effects; disabling a repository admits new/late work or loses current-edition,
retained-read, usage, accounting, or audit integrity; more than one current
edition succeeds; a stale source, enrollment, cancellation, profile, lease,
review, or activation fence succeeds; any hosted synthesis provider, model,
price, prompt, credential, endpoint, adapter, or fallback is selectable;
deterministic work reports nonzero or unknown model usage/cost; backup,
restore, rebuild, restart, or rollback trusts disposable state or crosses
scope; a signed corpus, oracle, component, clock, threshold, report, pilot, or
release digest changes without requalification; any governing ADR or
specification changes without reevaluation; any earlier RW gate reopens; or
ontology verification, architecture checks, Dialyzer, precommit, or
clean-checkout CI fails at the exact merged Phase 5 candidate.
