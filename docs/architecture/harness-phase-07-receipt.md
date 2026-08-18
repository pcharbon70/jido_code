# Harness Phase 7 Evaluation And Controlled Rollout Receipt

## Status

This receipt records the Harness Phase 7 candidate verified locally and
accepted after pull request merge on 2026-08-18. Pull request #40 passed
clean-checkout CI and merged on 2026-08-18. Phase 8 is authorized from that
exact baseline.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Phase baseline and merged HG6 closure | `ec98620c99d0db8f9a5b10105d7c56a3f5b902c0` |
| Accepted Phase 6 candidate | `d00624e407826ca322c52557714ca20b1ba94518` |
| Section 7.1 | `2b372e5994e9d7028dbb03064a4adb0cfc738474` |
| Section 7.2 | `cb4d90a726249aabce9ef5615630df5f61272d18` |
| Section 7.3 | `ad20e72370719ad436504f2c86c64a31ff89df4c` |
| Section 7.4 | `87918a59978454e44b5c7614ad3a1e02a532441b` |
| Section 7.5 and receipt | `b38dcd0e8cc53f5c811713db46be0f1f23a7ca70` |
| Merged candidate | `c8e5fc54642319149311921866104a2b642c0c2f` |

## Contract Revisions

| Boundary | Revision |
| --- | --- |
| Evaluation track catalog | `1.0.0` |
| Pinned track harness | `1.0.0` |
| Acceptance-centered metrics | `1.0.0` |
| Independent correctness adjudication | `1.0.0` |
| Adversarial scenario catalog | `1.0.0` |
| Release adversarial suite | `1.0.0` |
| Staged rollout gate | `1.0.0` |
| `RecordVerificationEvidence` | `1.7.0` |

## Evaluation Track And Corpus Boundary

The closed track catalog covers access-profile, ReqLLM, JidoHarness CLI, and
harness conformance; editing reliability and retrieval; SWE-bench Verified and
terminal interoperability; fresh/private issues; flaky tests; production
shadow; and pull-request pilot work. Public interoperability tracks are
diagnostic and have no rollout authority.

Each evaluation profile pins one track, immutable corpus revision and digest,
acceptance stage, oracle and verifier revisions, human rubric, independent
review and disagreement policy, Wilson and stratified-bootstrap methods, exact
model/access/authentication/billing/adapter/CLI/harness/tool target tuple, and
all required reporting slices. Run plans create multiple fresh independent
executions without assuming provider seed control. Trial evidence binds the
exact profile and corpus revisions, so an adjudication revision creates a new
profile and rejects prior trials until the affected corpus is rerun.

## Metrics And Adjudication Boundary

The aggregate reports Correct Accepted Yield, accepted precision, critical
false-acceptance incidence, acceptance and attempt coverage, proposal validity,
and malformed-proposal containment with exact numerators and denominators.
Binary proportions use fixed two-sided 95 percent Wilson intervals. Continuous
metrics use a deterministic 1,000-sample stratified bootstrap pinned by the
profile analysis revision. Patch approval and final-goal satisfaction remain
separate outcomes.

Pass-at-one, repeated-run consistency, separately labelled pass-at-k,
unauthorized-effect and stale-fence rejection, provenance, verifier
reproducibility, retrieval, recovery, cost, latency, review, override, and
post-publication outcomes are reported without pooling target routes.
Executable correctness requires complete reproducible fresh-checkout evidence
and verifier-owned hidden checks. Fresh/private tasks additionally require two
blinded independent reviewers and an independent resolver on disagreement.
LLM judgments are retained as advisory evidence and cannot change correctness.

## Adversarial Boundary

The versioned suite covers every planned untrusted-instruction surface; path,
process, hook, workflow, build, network, and credential attack; memory, CLI,
provider, journal, and tool-schema attack; and fence, approval, publication,
verifier, resource, sandbox, repository, and tenant attack. Each family also
has a clean control to expose over-refusal.

Every result carries independent utility and security outcomes plus explicit
authorization, credential, protected-branch, host, evidence, stale-fence, and
late-output invariants. Complete exact scenario coverage is mandatory. The
report distinguishes safe failure from violating success and rejects either a
critical security violation or a failed clean control as release evidence.

## Rollout Boundary

Stages 0 through 6 encode contract, offline, shadow, draft-PR, PR-publication,
broader-PR, and future limited-merge authority. A profile advances only one
stage per digest-bound decision backed by a committed
`RecordVerificationEvidence` receipt for the exact model-access profile,
revision, evidence, and transition. The coordinator verifies the decision
digest and enforces only its cumulative stage actions.

Every advance requires the complete adversarial suite and 100 percent
stale-fence, late-output, evidence-binding, malformed-proposal-containment, and
unapproved-fallback rejection. Automatic pull-request publication additionally
requires at least 300 fresh/private eligible tasks across 10 repositories, at
least 95 percent accepted precision with a Wilson lower bound of at least 90
percent, zero critical false acceptances, and fresh-checkout reproducibility
for every accepted patch. The task floor counts distinct tasks, not repeated
trials.

Single-operator profiles remain at shadow until the decision actor is distinct,
authenticated, and granted. Secret exposure, sandbox escape, evidence
mismatch, or protected-branch mutation produces immediate disablement with no
authorized action. Limited merge remains blocked without a separate future
decision.

## Verification Record

| Command or gate | Result |
| --- | --- |
| `phase_h07_eval_tracks_test.exs` | 5 tests, 0 failures |
| `phase_h07_metrics_test.exs` | 7 tests, 0 failures |
| `phase_h07_adversarial_test.exs` | 5 tests, 0 failures |
| `phase_h07_rollout_test.exs` | 9 tests, 0 failures |
| `phase_h07_integration_test.exs` | 4 tests, 0 failures |
| Complete Phase 7 focused suite | 30 tests, 0 failures |
| `mix compile --warnings-as-errors` | Pass |
| `mix architecture.check` | Pass |
| `mix precommit` | 562 tests, 0 failures; pass |
| Pull request #40 clean-checkout CI | Pass; merged 2026-08-18 |

## Known Limitations

This phase implements and verifies the evaluation control plane; it does not
claim that any production model-access profile has passed a rollout gate. Real
provider executions, the 300-task private release corpus, blinded human review,
and production shadow observations remain deployment evidence that must enter
through these pinned contracts. Evaluation records remain graph-owned through
the accepted semantic command boundary; deployment adapters must persist and
project the committed receipt without weakening its exact bindings.

## Gate HG7

HG7 is accepted at merged candidate
`c8e5fc54642319149311921866104a2b642c0c2f`, pinned in this receipt and the
Harness Phase 7 plan. Harness Phase 8 is authorized from that baseline. HG7
reopens if any metric can be computed outside its pinned profile or any stage
can advance without recorded evidence. These reopening conditions remain in
force regardless of checklist state.
