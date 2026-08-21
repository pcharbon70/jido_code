# Memory Phase 4 Experience Cases And Failure Memory Receipt

## Status

This receipt records the Memory Phase 4 candidate accepted on 2026-08-21 after
the implementation and CI-remediation pull requests merged. Pull request #56
passed clean-checkout verification and Dialyzer before merging as
`48527f240c5145ebc8535d46dd8b622e4385f495`. MG4 is accepted, and Phase 5 is
authorized only from that exact merged baseline.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted MG3 baseline | `c1185415439bf32d7387e5fe9e94c57bc7a2d42e` |
| Phase 3 closure record | `25ba9d746afea595725fbfd244764acbc51c01d2` |
| Section 4.1 | `b59005072f880ae54db1402f7c60535fd51a1d98` - define governed experience cases |
| Section 4.2 | `51699fabd4de5030ed5ebba4a0d2fe10d1ea488d` - construct and quarantine experience cases |
| Section 4.3 | `ffa742de5772fc50d064a1ba330f4e007cea9563` - retrieve applicable experience cases |
| Section 4.4 | `9a7c0357e5f88372105f761598a8b48091c699ac` - assess experience case utility |
| Section 4.5 and receipt | This commit; exact commit is recorded by Git history |
| Implementation merge | `5d0fa8bfda7524795ef77de499bc28d8941dc89a` - pull request #55 |
| CI remediation | `11d60dcef388a24e972e8f6346f840fa058b086a` - patched Bandit and Dialyzer gates |
| Accepted merged candidate | `48527f240c5145ebc8535d46dd8b622e4385f495` - pull request #56 |

## Contract Pins

| Boundary | Candidate value |
| --- | --- |
| Experience-case schema | `1.0.0`; seven closed classes; every case is non-authoritative |
| Experience lifecycle | `1.0.0`; candidate, validated, stale, invalidated, and superseded append-only transitions |
| Construction and validation | `1.0.0`; closed-run extraction and independent exact-manifest validation |
| Command catalog | `2.1.0`; proposal, validation, quarantine, lifecycle, and assessment commands |
| Query catalog | `2.1.0`; aggregate source digest `78ef4ccd06848e92c5e535124bfdad94bb11af6a8098720a68f09ea12be781f8` |
| Deterministic case ranker | `1.0.0`; lexical, graph, failure-signature, and optional dense scores remain separate |
| Quarantine evaluator | `1.0.0` |
| Memory-use evaluator | `1.0.0`; useful, neutral, misleading, stale, unauthorized, and causally-indeterminate outcomes |
| Negative-transfer evaluator | `1.0.0` |
| Memory guardrails | `1.2.0`; `experience_writer` enabled and bootstrap-authorized |
| Graph registry | `2.2.0`; append/supersede experience family |
| Benchmark corpus | Seven case classes; SHA-256 `962189094dc5299e03a1cc2173ed83ebc71f5678cb8d98bf9c9505b68b465ec2` |
| Integration fixture | Real bootstrap, enrollment, evidence, segmented run, serialized writer, TripleStore query runner, export, and restart path |

## Case, Quarantine, And Leakage Evidence

The matrix constructs success, failure, revert, flake, infrastructure,
abandoned, and ambiguous cases from a closed attempt plus evidence available at
the exact effective-time cutoff. Every candidate retains its source events,
artifacts, evidence, graph-revision references, verification, delayed outcome,
exceptions, and limitations. Candidate status grants no work, evidence,
knowledge, policy, or instruction authority.

The quarantine suite rejects embedded instructions, secret-shaped values,
personal data, foreign-scope references, unsupported claims, future summaries,
suspicious trigger concentration, and missing evidence. Independent validation
requires a different actor, the exact manifest digest, and the exact source
graph revisions. Future outcomes and missing event lineage fail construction;
forged validation fails closed.

## Retrieval And Negative-Transfer Evidence

Retrieval filters repository, framework/version, runtime environment,
dependency, task class, plan phase, effective time, and current applicability
before deterministic ranking. It returns at most seven cases, diversifies
success, harmful, and ambiguous trajectories, and abstains when none apply.
The fixed-budget comparison records zero no-memory cases, seven ordinary
lexical candidates, and seven governed candidates; only the governed path
applies chronology, lifecycle, scope, applicability, diversity, and explicit
negative-transfer penalties.

Independent assessments bind the exact retrieval packet, attempt outcome,
evaluator, policy, source revisions, and withheld-memory control. Two harmful
assessments produce a stale transition. Unauthorized use, poisoning success,
or suspicious trigger concentration produces immediate invalidation. The
original case statements remain unchanged, and harmful feedback changes only
ranking inputs or append-only lifecycle history.

## Replay, Concurrency, Restart, And Rebuild Evidence

The real-store matrix commits a proposal, returns `already_committed` for its
exact replay, independently validates it, and reads its candidate-to-validated
lifecycle through the reviewed query catalog. Two transitions racing from the
same predecessor produce exactly one commit and one refreshable conflict.
Dataset export proves every original case statement remains visible after the
winning transition. After writer restart, a fresh graph query rebuilds the
same ordered lifecycle prefix and includes the committed terminal transition.

## Verification Record

| Command or gate | Result |
| --- | --- |
| Phase 4 focused construction, quarantine, retrieval, assessment, and real-store integration matrix | 14 tests, 0 failures |
| Complete memory suite, including prior phases | 77 tests, 0 failures |
| `mix architecture.check` | Pass |
| Isolated release-contract and command-pipeline regression rerun | 4 tests, 0 failures |
| `mix precommit` | 678 tests, 0 failures; pass |
| Pull request #56 clean-checkout CI and Dialyzer | Pass; merged 2026-08-21 |

## Known Limitations

- Dense retrieval remains a disabled optional score; this phase authorizes no
  embedding model or vector store.
- The benchmark is a deterministic conformance corpus, not evidence of broad
  production utility. Production usefulness requires continued independent,
  delayed assessment.
- Experience memory remains repository-scoped and non-authoritative. Cross-
  repository learning belongs to a later gate.
- Exact retained content remains behind its separate permit and lifecycle;
  experience summaries do not bypass content policy.

## Gate MG4

MG4 is accepted at merged candidate
`48527f240c5145ebc8535d46dd8b622e4385f495`, pinned in this receipt and the
Phase 4 plan. Phase 5 is authorized only from that exact baseline.

MG4 reopens if any case can omit exact attempt, event, artifact, evidence,
verification, delayed-outcome, effective-time, repository, environment,
dependency, or graph-revision lineage; if candidate summaries, repeated use,
frequency, model self-report, or case status can grant truth, policy,
instruction, tool, work, evidence, or knowledge authority; if injected
instructions, secrets, personal data, cross-scope references, unsupported
claims, future evidence, suspicious triggers, missing evidence, or forged
validation can avoid quarantine; if validation is not independent and bound to
the exact source manifest; if retrieval can cross repository, framework,
version, environment, dependency, task, phase, effective-time, lifecycle, or
applicability boundaries; if scores are hidden or nondeterministic; if harmful
or poisoning outcomes cannot demote or disable a case without rewriting its
history; if replay duplicates effects; if competing transitions both commit;
if restart or index rebuild changes durable case truth; or if any Phase 5+
memory feature becomes reachable before its owning gate. These reopening
conditions remain in force regardless of checklist state.
