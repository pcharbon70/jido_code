# Harness Phase 6 Verification, Decision, And Publication Receipt

## Status

This receipt records the Harness Phase 6 candidate verified locally on
2026-08-18. Merge is pending. Phase 7 is not authorized until this
implementation pull request passes clean-checkout CI, merges, and the full
merge-commit SHA is pinned here and in the Phase 6 plan.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Phase baseline and merged HG5 closure | `768216c7e787d3fb6c451f6ad2773486bf342c4d` |
| Accepted Phase 5 candidate | `c9fc2dd625bab2385fed5fa3203c4cb6d0f38f22` |
| Section 6.1 | `ce8488d` |
| Section 6.2 | `8b5b24c` |
| Section 6.3 | `3434627` |
| Section 6.4 | `52ec8f2` |
| Section 6.5 | `3b7e5d9` |
| Section 6.6 and receipt | Merge-pending branch tip |
| Merged candidate | Pending clean-checkout CI and merge |

## Contract Revisions

| Boundary | Revision |
| --- | --- |
| Closed-run verification admission | `1.0.0` |
| Independent fresh-checkout verifier | `1.0.0` |
| `RecordVerificationEvidence` | `1.7.0` |
| Digest-bound approval gateway | `1.0.0` |
| `CreateApprovalRequest` | `1.8.0` |
| Separate publication coordinator | `1.0.0` |
| External-outcome coordinator | `1.0.0` |
| `RecordObservationBatch` | `1.1.0` |
| `DecideGoalOutcome` | `1.7.0` |

## Verification And Evidence Boundary

Verification admission requires the committed `FinalizeExecutionRun` receipt
for the exact attempt, run graph revision, terminal sequence, completeness,
and accepted reference sets. It binds source and control revisions, base and
candidate digests, artifact media types and byte counts, policy and rubric
revisions, environment, evaluator capability, lease, and fence. Incomplete
runs are unavailable or inconclusive and never yield accepting evidence.

The verifier reconstructs the base and candidate in separate disposable Git
worktrees. The integration suite applies a real binary-capable Git patch that
changes an existing file and adds both a candidate test and binary artifact.
It enforces path, protected-file, patch-size, capability, fixed check, and
flake policy; candidate-authored tests count only after failing on base and
passing on candidate alongside independent checks. Its output records command,
result, output, environment, and workspace digests and can create only the
accepted evidence command. It has neither transition nor acceptance authority.

## Approval And Publication Boundary

The approval digest covers normalized action and arguments, base and patch,
artifact set, tool/model/sandbox/policy/context versions, capability, lease and
fence, destination, egress digest and bytes, evidence, reversibility,
authenticated approver, delegated scope, actor separation, idempotency, and
expiry. Immediately before effect, the gateway rechecks every current
authorization and revision. A trusted ledger atomically records the invocation
and consumes the approval before dispatch. Replay, expiry, revocation, digest
substitution, and actor collapse fail closed.

Ambiguous delivery remains nonterminal for at most three reconciliation
observations. Redelivery is admitted only for the same invocation under a
proven idempotency contract; semantic retry changes invocation, attempt, and
approval identity. Exactly one terminal outcome may be committed.

Publication is a new task with independent eligibility, authorization, lease,
fence, attempt, and `run/{publication_attempt}` graph. The trusted provider
port performs expected-old-object compare-and-swap, requires fast-forward
movement and provider branch/ruleset protection, and claims repository-scoped
credentials only when the provider proves that scope. Its closed operation set
can open or update a bot-branch pull request. It cannot merge or update a
protected branch.

## External Outcome And Final Goal

Publication success does not satisfy a goal. The outcome coordinator first
commits an accepted provider observation linked to the publication attempt and
exact external revision, then commits independent post-change evidence against
that revision, and only then commits the accepted `FinalGoal` decision. The
decision binds actor-separated decider, evaluator, and executor identities,
the exact evidence and confirmation references, no requested effects, and one
of accept, reject, defer, waive, supersede, or request-more-evidence.

Only governed accept or waive dispositions report satisfaction. Executor
completion, publication completion, unobserved provider state, or a post-change
revision mismatch cannot bypass the decision service.

## Verification Record

| Command or gate | Result |
| --- | --- |
| `phase_h06_verification_admission_test.exs` | Pass |
| `phase_h06_fresh_checkout_test.exs` | Pass |
| `phase_h06_approval_test.exs` | Pass |
| `phase_h06_publication_test.exs` | Pass |
| `phase_h06_goal_outcome_test.exs` | Pass |
| `phase_h06_integration_test.exs` | Pass; real detached Git worktrees and binary patch |
| Complete Phase 6 focused suite | 27 tests, 0 failures |
| Phase 9 evidence and decision regressions | Pass |
| `mix compile --warnings-as-errors` | Pass |
| `mix architecture.check` | Pass |
| `mix precommit` | 532 tests, 0 failures; pass |
| Implementation pull request clean-checkout CI | Pending |

## Known Limitations

The contracts and reference adapters prove orchestration, identity, fencing,
CAS, and authority separation in-process. Production provider tokens,
branch/ruleset attestations, external observation ingestion, and independent
verification workers remain deployment integrations and must preserve these
ports. No protected-branch write or merge credential is admitted by this
phase.

## Gate HG6

HG6 remains merge-pending. It is accepted only at the merged candidate after
clean-checkout CI passes and the merge SHA and date are pinned. Phase 7 remains
unauthorized. HG6 reopens if any executor can verify itself, any approval can
be replayed, or any outcome can bypass the decision service. These reopening
conditions remain in force regardless of checklist state.
