# Memory Phase 7 Cross-Repository Dataset And Release Receipt

## Status

This receipt records the accepted Memory Phase 7 merged candidate. Pull request
#59 passed clean-checkout CI and Dialyzer, then merged on 2026-08-21 as
`fb4716137c5bf5e6b6a8468cee171e32f83b7266`. MG7 is accepted at that pinned
merged candidate and the total-agent-memory plan is closed.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted MG6 baseline | `e27fce06e593c75a532390c231cb9ce0d4ed0c65` |
| Phase 6 closure record | `e71b271` - pin and accept merged MG6 candidate |
| Section 7.1 | `0cf5aad` - authorize bounded cross-repository memory use |
| Section 7.2 | `be7d666` - build chronological governed memory datasets |
| Section 7.3 | `5474165` - govern memory dataset exports and lifecycle |
| Section 7.4 | `3df9edd` - gate memory release on governed evaluation |
| Section 7.5 and receipt | This commit; exact commit is recorded by Git history |
| Merged candidate | `fb4716137c5bf5e6b6a8468cee171e32f83b7266`; PR #59, merged 2026-08-21 |

## Contract Pins

| Boundary | Candidate value |
| --- | --- |
| Ontology and shapes | `1.2.0` / `1.2.0` |
| Memory contract | `2.1.0` |
| Graph registry | `2.4.0`; payload-free `memory_dataset` enabled |
| Data policy | `2.1.0`; personal and secret values remain non-exportable |
| Guardrails | `1.5.0` |
| Command catalog | `2.7.0`; dataset policy `2.4.0`, construction `2.5.0`, export `2.6.0`, evaluation `2.7.0` |
| Query catalog | `2.7.0`; aggregate source digest `9092fca8628e3c13188dc83a213296e39b96cf93b486f4e2f15a905edf2a3487` |
| Cross-repository authorization, policy, and audit | `1.0.0` |
| Dataset manifest, row, and builder | `1.0.0` |
| Export permit, verifier, artifact, and lifecycle | `1.0.0` |
| Training boundary | `1.0.0`; no training, checkpoint, registry, or deployment authority |
| Evaluation and release program | `1.0.0`; twelve mandatory ablations and exact metric sets |
| Real-store integration | Dataset graph revision 6 after manifest, rows, permit, export, evaluation, and invalidation commits plus writer restart |

## Authorization Isolation Evidence

Each cross-repository authorization binds one cohort, an exact sorted
repository set, actor set, purpose, allowed uses, data classes, effective
cutoff, validity interval, policy revision, decision, and per-repository
erasure generation. Its candidate-partition digest changes when any bound
dimension changes. Candidate generation opens only that exact partition;
unknown or unauthorized repositories fail before their candidates, rankings,
counts, omissions, or logs can be inspected.

Exact content, prompt-derived content, Personal data, and confidential data
must be expressly named by the authorization. Dataset construction applies a
stricter structural exclusion for secret values, Personal data,
provider-private fields, hidden reasoning, and unresolved deletion requests.
Cross-repository cases and procedures remain non-authoritative candidates;
they gain local authority only through a distinct, independent decision in the
target repository. Audit records contain authorization, repositories,
selected IRIs, bounded omission counts, status, reason, and time, never a
protected payload.

## Chronology, Split, And Lineage Evidence

`MemoryDatasetManifest` pins authorization, purpose, repositories, source
graphs and resources, cutoff, allowed classifications, extractor and query
revisions, repository-level split assignments, erasure generations, and exact
content states. Every row binds one manifest, repository, task, patch,
optional incident, classification, unchanged outcome class, split, effective
time, exact source resources, semantic and representation digests, and
erasure generation.

The builder excludes post-cutoff events, later reviews or incident findings,
future outcomes, stale erasure generations, incomplete lineage, forbidden
fields, and unresolved deletion. It deduplicates repository/task, patch,
incident, and semantic overlap before rows cross a split. Success, failure,
revert, flake, infrastructure, and ambiguous classes remain distinct; class
balance is measured without relabeling. Rebuilding reversed input produces the
same row identities.

## Export, Lifecycle, And Erasure Evidence

An export permit names the exact verified manifest, current authorization,
actor, approved sink, purpose, classifications, row and byte limits, issue
time, and expiry. The verifier rechecks chronology, repository split
isolation, deduplication, source completeness, class balance, forbidden-field
absence, permit limits, and expiry before release.

The graph stores only dataset identity, payload digest, schema revision,
counts, source-row lineage, authorization, sink, external-copy IRIs,
availability, and lifecycle. Exported bytes remain at the individually
approved external sink; the graph is not a second payload store. Hold
placement quarantines every copy. Hold release can restore availability.
Authorization revocation, source invalidation, or erasure requires deletion of
every copy, and deletion is not complete until separately attested. Backup
restore floors and excluded key/content identities prevent resurrection.

## Evaluation And Release Evidence

The release program requires no memory, recent history, all eligible history,
summaries, lexical, dense, graph, case, procedure, hybrid, oracle, and stale or
poisoned memory ablations. Every ablation reports exact retrieval, outcome,
cost, and harm metric sets. Missing or additional metrics fail closed.

Cross-scope leaks, secret leaks, accounting drift, missing sources, temporal
violations, permit bypasses, stale-claim acceptance, erasure failures,
future-patch leakage, and critical false acceptance are zero tolerance. A
launch product additionally requires at least 30 samples, `p <= 0.05`, a
confidence interval strictly above zero, and an accountable
`DisableMemoryProduct` path operable within five minutes. The accepted fixture
proves the executable threshold; a real launch must supply its own pinned
governed measurements through the same contract.

## Disabled Posture

`diagnostic_capture`, `project_total_history`, broad cohort access, automatic
dataset export, model training, and model deployment remain runtime-disabled.
The repository contains no fine-tuning job, checkpoint, model-registry, or
deployment command. A future training effort must pin a manifest and obtain a
separate accepted implementation plan, evidence gates, and lifecycle controls.

## Verification Record

| Command or gate | Result |
| --- | --- |
| Phase 7 policy, construction, export, evaluation, and real-store matrix | 19 tests, 0 failures |
| Complete memory suite, including Phases 1-7 | 130 tests, 0 failures |
| `mix architecture.check` | Pass |
| `mix precommit` | Pass; architecture checks and 731 tests, 0 failures |
| `mix dialyzer` | Pass; 177 existing warnings skipped, 0 unignored errors, 0 unnecessary skips |
| Pull request clean-checkout CI | Pass; PR #59 `verify` and `dialyzer` succeeded before merge |

## Known Limitations

- The included evaluation measurements are deterministic acceptance fixtures,
  not a production launch study. A launch reopens MG7 unless its own pinned
  governed sample satisfies the same statistical and zero-tolerance contract.
- Dataset payload adapters are sink-specific and remain outside the graph.
  Each production sink must enforce its permit and return quarantine/deletion
  attestations without gaining semantic authority.
- A reviewed dataset query remains inaccessible unless its current authority
  scope matches the cohort-owned dataset graph. Merely knowing the graph IRI or
  holding repository access is insufficient.
- Dense retrieval remains an evaluation ablation and adapter boundary; no
  broad dense index or external vector authority is activated by this phase.
- Physical external deletion remains incomplete until attested. An
  unavailable or unverifiable sink must remain deletion-required or
  quarantined rather than be reported erased.

## Gate MG7

MG7 is accepted at merged candidate
`fb4716137c5bf5e6b6a8468cee171e32f83b7266`, merged on 2026-08-21 after pull
request #59 passed clean-checkout CI and Dialyzer. The total-agent-memory plan
is closed at that pinned baseline.

MG7 reopens if any cohort operation lacks an explicit current repository set,
actor set, purpose, allowed use, data class, cutoff, expiry, policy revision,
decision, or erasure generation; if an unauthorized repository influences
candidates, rankings, counts, omissions, logs, or exports; if imported memory
gains local authority without independent target-repository acceptance; if an
audit record contains protected payload; if future patches, reviews,
incidents, delayed outcomes, or other post-cutoff evidence enters a row; if
related repositories, tasks, patches, incidents, or semantic duplicates cross
evaluation splits; if uncertainty is relabeled; if a secret, Personal value,
provider-private field, hidden reasoning, unresolved deletion, or disallowed
classification enters a dataset; if any row lacks exact removable source
lineage; if export occurs without a current exact-manifest permit, approved
sink, row/byte limit, class ceiling, purpose, and expiry; if the graph stores
dataset payload bytes or an external sink gains semantic authority; if hold,
revocation, source invalidation, erasure, backup, restore, quarantine, or
deletion fails to reach every derivative copy; if unverifiable deletion is
reported complete; if a mandatory ablation or metric is omitted; if any
zero-tolerance metric is non-zero; if no launch product has statistically
supported benefit; if a critical false acceptance remains; if a launched
product lacks an immediate disable path; if broad cohort access or automatic
export becomes reachable; if diagnostic or project-total capture becomes
enabled; or if any training, checkpoint, model registry, or deployment path is
created without a separate accepted plan. Every MG1-MG6 reopening condition
also remains in force regardless of checklist state.
