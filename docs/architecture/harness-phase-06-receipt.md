# Harness Phase 6 Verification, Decision, And Publication Receipt

## Status

This receipt records the Harness Phase 6 candidate verified locally and
accepted after pull request merge on 2026-08-18. Pull request #38 passed
clean-checkout CI and merged on 2026-08-18. Phase 7 is authorized from that
exact baseline.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Phase baseline and merged HG5 closure | `768216c7e787d3fb6c451f6ad2773486bf342c4d` |
| Accepted Phase 5 candidate | `c9fc2dd625bab2385fed5fa3203c4cb6d0f38f22` |
| Section 6.1 | `ce8488d09716f0ed4edd0d9ffa5e7e1ca197286a` |
| Section 6.2 | `8b5b24c4aad593ec5401af16f85f3f7eaf524d54` |
| Section 6.3 | `34346276b31a1f2a958682884741f83fe848794c` |
| Section 6.4 | `52ec8f292826cb214ab50131d7de40de56d16a47` |
| Section 6.5 | `3b7e5d91eeebcd2bdb2e335dd3a89c34eed4566a` |
| Section 6.6 and receipt | `065d279b5a51d1b711815551bd2d108b32216682` |
| Merged candidate | `d00624e407826ca322c52557714ca20b1ba94518` |

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
| Pull request #38 clean-checkout CI | Pass; merged 2026-08-18 |

## Known Limitations

The contracts and reference adapters prove orchestration, identity, fencing,
CAS, and authority separation in-process. Production provider tokens,
branch/ruleset attestations, external observation ingestion, and independent
verification workers remain deployment integrations and must preserve these
ports. No protected-branch write or merge credential is admitted by this
phase.

## Gate HG6

HG6 is accepted at merged candidate
`d00624e407826ca322c52557714ca20b1ba94518`, pinned in this receipt and the
Harness Phase 6 plan. Harness Phase 7 is authorized from that baseline. HG6
reopens if any executor can verify itself, any approval can be replayed, or any
outcome can bypass the decision service. These reopening conditions remain in
force regardless of checklist state.
