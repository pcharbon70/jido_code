# Memory Phase 5 Artifact Claims And Procedural Memory Receipt

## Status

This receipt records the Memory Phase 5 merge candidate verified locally on
2026-08-21. MG5 remains merge-pending until the implementation pull request
passes clean-checkout CI, merges, and its full merge commit is pinned here and
in the Phase 5 plan. Phase 6 is not yet authorized.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted MG4 baseline | `48527f240c5145ebc8535d46dd8b622e4385f495` |
| Phase 4 closure record | `07676c1bac5bad737a7f055365c0d2289d4b2243` |
| Section 5.1 | `248fba7a3fc22fe2e2324186a4e45e3becdd5152` - ground claims in verified artifacts |
| Section 5.2 | `92306ff7a2cb92a27a714fc4fb6a64a6c101eb1b` - induce quarantined procedure candidates |
| Section 5.3 | `87d305e72589a17f1f276646604ad52b4508febb` - validate procedures without granting control |
| Section 5.4 | `b157d68d21bc60332ea8c17819d6ac969161416a` - retrieve current phase-aware procedures |
| Section 5.5 and receipt | This commit; exact commit is recorded by Git history |
| Merged candidate | Merge-pending; not yet accepted |

## Contract Pins

| Boundary | Candidate value |
| --- | --- |
| Artifact claim schema | `1.0.0` |
| Artifact freshness lifecycle | `1.0.0`; fresh, stale, contradicted, invalidated, superseded |
| Procedure revision schema | `1.0.0`; immutable and non-authoritative |
| Procedure lifecycle | `1.0.0`; candidate, validated, stale, invalidated, superseded |
| Induction and quarantine | `1.0.0` |
| Independent validation | `1.0.0` |
| Knowledge/policy authority boundary | `1.0.0` |
| Procedure retrieval | `1.0.0`; at most five procedures |
| Procedure-use observation | `1.0.0`; initially pending independent assessment |
| Command catalog | `2.2.0` |
| Query catalog | `2.2.0`; aggregate source digest `cd99082956ef887b026f8d752e606992a26ec384bded4d432bfc470c38a31ac1` |
| Conformance corpus | Strong/weak claims plus six execution outcomes; SHA-256 `ce5ab804b43fa0c6ee1e4a619664e6a51072dfd3948bc6d172fb69c2aaac14b7` |
| Integration fixture | Real bootstrap, enrollment, evidence, segmented execution, serialized writer, TripleStore query runner, and restart path |

## Artifact Drift Evidence

Artifact claims bind repository and exact revision, artifact, path, optional
symbol/selector, content digest, verification command and environment,
independent evidence and strength, and valid/checked times. Runtime success
alone is rejected. Evidence-writer commands persist claims in the evidence
graph. Exact comparison of source revision, artifact identity, content digest,
symbol, verification tool/environment, and evidence determines currentness.
Drift appends a stale transition while preserving the original claim and its
evidence strength. Historical risk remains queryable but stale claims are not
eligible as current evidence.

## Procedure Induction And Validation Evidence

Procedure revisions bind purpose, task and phase, triggers, exact
applicability, language/framework/version, ordered semantic steps, tools and
capabilities, expected observations, branches, stops, escalation, rollback,
exceptions, supporting/contradicting cases, delayed outcomes, and validation
time. Induction requires at least two distinct cases or explicit expert review;
case count never promotes beyond candidate. Quarantine catches instruction
injection, secrets, benchmark leakage, scope inflation, missing preconditions,
and duplicate revisions.

Independent validation requires multiple executions from actors other than the
proposer under exactly matching applicability, framework, tools, policy, and
source revisions. It records success, failure, revert, incident,
negative-transfer, and delayed-survival counts. Framework, tool, policy,
environment, or artifact drift appends stale state.

## Retrieval, Use, And Authority Evidence

Retrieval treats investigation, localization, editing, migration, testing,
verification, recovery, and incident phases separately. Selection requires a
validated lifecycle, exact repository/framework/version/tool/policy/environment
compatibility, current evidence, and chronological eligibility. Results retain
ordered steps, decision branches, stop/escalation/rollback conditions,
exceptions, evidence, failure counts, validation time, and negative transfer.

Every use is a new append-only observation in pending-independent-assessment
state. A candidate procedure cannot produce an adoptable proposition. A
validated procedure may only form a precise proposition for the existing
`AdoptKnowledge` evidence/decision boundary, and that proposition remains
non-executable. Policy requires a separate sanitized representation and an
authorized policy command; direct conversion is denied.

The fixed baseline records 50 ordinary candidate tests versus 14 history-aware
tests, correct abstention when no procedure applies, and explicit negative
transfer of `0.2` rather than hiding harm in a combined score.

## Real-Store And Recovery Evidence

The integration matrix commits and queries an artifact claim, detects exact
content drift, commits and idempotently replays a mixed-case procedure
proposal, independently validates it, retrieves it through both the product
ranker and reviewed catalog, records a use pending assessment, denies direct
policy conversion, restarts the serialized writer, and rebuilds the exact
two-transition procedure lifecycle from durable graph truth.

## Verification Record

| Command or gate | Result |
| --- | --- |
| Phase 5 focused claim, procedure, retrieval, and real-store matrix | 14 tests, 0 failures |
| Complete memory suite, including prior phases | 91 tests, 0 failures |
| `mix architecture.check` | Pass |
| `mix precommit` | 692 tests, 0 failures; pass |
| Pull request clean-checkout CI | Merge-pending |

## Known Limitations

- The conformance corpus proves deterministic boundaries, not broad production
  usefulness; delayed independent assessment must continue in production.
- Procedures are repository-scoped guidance. Cross-repository datasets remain
  blocked until MG7.
- Procedure ranking is deterministic and bounded but deliberately simple; no
  dense retrieval adapter is enabled.
- Exact content access remains governed by the separate MG6 permit and
  lifecycle boundary.

## Gate MG5

MG5 remains merge-pending. It may be accepted only after clean-checkout CI and
merge, by pinning the full merge-commit SHA here and in the Phase 5 plan. Phase
6 remains unauthorized until then.

MG5 reopens if an artifact claim can omit exact repository revision, artifact,
content digest, verification environment, evidence strength, or checked time;
if runtime success alone can create a claim; if source, symbol, tool,
environment, policy, or evidence drift leaves a claim current; if stale claims
enter current retrieval or historical evidence strength is rewritten; if one
case, frequency, or model confidence can validate a procedure; if injection,
secrets, over-generalization, missing preconditions, duplicates, or benchmark
leakage avoid quarantine; if validation is not independent and bound to exact
applicability and source revisions; if failure, revert, incident, delayed
survival, or negative transfer is hidden; if retrieval crosses phase,
repository, framework, version, tool, policy, environment, evidence, lifecycle,
or effective-time boundaries; if use self-assesses; if guidance becomes
accepted knowledge without existing evidence and decision contracts; if any
procedure becomes capability, approval, instruction, or executable policy
without a separate sanitized representation and authorized command; if replay
duplicates effects; if restart or rebuild changes durable truth; or if any
Phase 6+ memory feature becomes reachable before its owning gate. These
reopening conditions remain in force regardless of checklist state.
