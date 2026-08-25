# Managed Coding Phase 6 Qualification And Rollout Receipt

## Status

This receipt records the Phase 6 implementation candidate verified locally.
MCG6 remains **merge-pending** until the implementation pull request passes
clean-checkout CI, merges, and its exact merge commit is pinned here.

The candidate supplies a signed production profile, a private reproducible
evaluation program, non-authoritative shadow qualification, a narrowly scoped
human-reviewed draft-PR pilot, independent release governance, complete
disable/incident operations, and end-to-end qualification reconciliation.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Authorized Phase 6 baseline / accepted MCG5 | `2bbc571a683c8d5298f5e81d5e8c02685f23ffdb` |
| Section 6.1 | `7e292e8646c2be0f75b8bce48812bf593265b2d7` - pinned production profile |
| Section 6.2 | `75d0ef68393f0ecf8effa60d97fb282c03d3261d` - private evaluation program |
| Section 6.3 | `c9fb4efb035b6eb2a50187769690934dc777110e` - shadow qualification |
| Section 6.4 | `a0b9e972c6fe28e6e57cda2c4057a4e65598d74e` - human-reviewed draft pilot |
| Section 6.5 | `8701ef09bff2e845375243c5edebc3c374bbb7ff` - rollout governance |
| Section 6.6 | This receipt, audit, integration matrix, and final gates; exact commit recorded by Git history |
| Merged candidate | **merge-pending** |

## Contract Pins

| Contract | Candidate SHA-256 |
| --- | --- |
| Production profile | `d2042eb2dfd52d1572cff7c7621042f37a524e113b3f266e0a2161ac8bec088d` |
| Profile change control | `a0ace1ef5f82afee693512a25cd996274fea0889ffd9bb4b1a79a9e67459f8c7` |
| Evaluation program | `69336f5c3d1dc667d4a420a59cb5e741f9046b14034ce7d335015ff8603785eb` |
| Shadow rollout | `27006c1757ce4a6b44b49837a77527f12d9a4ce639961746ec83537a69cddd46` |
| Draft-PR pilot | `52ce44b97190d66f9a546f5a00cf37636c4eb125860ced1e069edb7e339f17b7` |
| Rollout governance | `6836a13a8b791560aa1b30cd80a494b5a1baefcefcabf1f26dca72bafbe019d5` |
| Qualification audit | `951679e4bf681c2e7c10f1bf6462ee374fa87a1d8272bdb49aae4f87d0bcd68e` |
| Rollout runbook and envelope | `85cf1f3ce33963e332bd480a857d93476276181c76c3a12825b448ab46a3b04d` |
| Phase 6 integration fixture | `c1d8298d381a62bb6af75db27318cbb84b04d9046f68c04e95ff5a23c6cfce29` |

## Profile And Evaluation Evidence

- The production profile pins provider/model, prompt templates, context policy,
  tool registry, model/tool adapters, sandbox image, check registry, credential
  policy, memory mode, and verifier environment by exact revision and digest.
- Existing managed budgets impose hard or next-effect ceilings for time, turns,
  model calls, tokens, cost, tools, input/output, processes, memory, workspace,
  changed files, diff size, and clarification. The production profile adds
  exact check and retry ceilings.
- Repository/task classes, languages, dependency policy, network mode, actor
  requirements, exclusions, and unavailable capabilities are closed. Missing,
  mismatched, expired, unknown, or unapproved components reject without
  fallback. Any signed material change gets a new profile digest and makes all
  prior qualification invalid.
- The private corpus covers inspect, defect repair, focused feature, test
  repair, refactor, documentation, abstention, clarification, policy refusal,
  and unsupported tasks across sizes, languages, dependencies, ambiguity,
  malicious instructions, flaky checks, failures, cancellation, and recovery.
- Exact seeds, base revisions, clean workspaces, complete artifact capture,
  independent verification, and blinded review make assignments reproducible.
  Oracle digests and seeds do not enter prompts.
- Predeclared Wilson confidence intervals, continuous confidence/variance,
  baselines, minimum samples, regression tolerances, and blocking thresholds
  cover correctness, regressions, unsafe action, authority, unsupported claims,
  abstention, recovery, latency, resource use, tokens, and cost. Every failed
  trial requires bounded failure analysis before qualification is visible.

## Shadow And Pilot Evidence

- Shadow sampling requires exact tenant, repository, task class, profile, and
  observation window. Shadow attempts cannot push, open pull requests, change
  primary task state, influence the active implementation, or publish.
- Data classification, credentials, rate limits, isolation, retention,
  redaction, and cost accounting are pinned even for non-authoritative output.
  Human/production comparison is delayed and blinded and cannot feed the same
  attempt.
- Cohort summaries cover failure, abstention, clarification, capacity, cost,
  latency, recovery, and security. Threshold breach, evidence gap, profile
  drift, isolation failure, unexplained cost growth, or reconstruction failure
  stops new shadow admission.
- Pilot enrollment requires exact allowlists, supported task class, profile,
  volume ceiling, business hours, on-call coverage, and documented opt-out.
  Only an accepted candidate can create an authorized draft branch and draft
  pull request with exact candidate, verification, profile, and limitation
  evidence.
- Human review, modification, approval, and merge remain under existing
  repository protections. Human changes are never attributed to the candidate.
  Cohort measures include acceptance, edit distance, review time, escaped
  regressions, reopen/revert, unsafe behavior, abstention, latency, cost, and
  operator burden. Any stop signal or threshold breach quarantines every
  pending publication.

## Operations And Release Evidence

- Owners, independent approvers, on-call responders, dashboards, alert routes,
  cadence, escalation revision, and evidence retention are explicit.
- Global, tenant, repository, provider, adapter, tool, and profile disablement
  blocks new effects while preserving recovery, cancellation, and evidence.
- The runbook covers triage, drain, credential revocation, evidence
  preservation, tenant notification, candidate quarantine, rollback, and safe
  reenable. Incident records cannot report completion without preserved
  evidence.
- Accept, extend, restrict, or reject is an independent operator decision bound
  to thresholds, unresolved findings, drills, and an evidence bundle. The
  runtime and verifier cannot make it.
- The supported envelope retains automatic approval, automatic merge, and a
  general multi-agent topology as explicitly unavailable.
- The qualification audit binds task, attempt, effect, candidate, verification,
  draft publication, human reviewer, and operator decision to one exact profile
  and requires every evaluation, shadow, pilot, stop, disable, drain, incident,
  rollback, and reenable drill.

## Verification Record

| Command or gate | Candidate result |
| --- | --- |
| Phase 6 profile, evaluation, shadow, pilot, operations, and integration suites | 21 tests, 0 failures |
| Managed-coding component, runtime, verifier, UI, and integration regressions | 127 tests, 0 failures |
| Repository-wide `mix precommit` | 867 tests, 0 failures; compile, architecture, lock, format, and test gates passed |
| Architecture checks | Passed; zero findings |
| Dialyzer | Passed; 177 existing warnings skipped by policy, zero unignored errors |
| Clean-checkout CI | Pending |

## Known Limits And Disabled Posture

- The evaluation, shadow, pilot, and operations evidence is a deterministic
  local contract fixture. Hosted-provider performance, real tenant observation
  windows, and production incident certification remain deployment evidence
  and must bind the same exact profile before broader rollout.
- The draft publisher is a port with a deterministic test adapter; production
  provider credentials and repository protections remain separately operated.
- A release decision can accept only the declared envelope. Automatic approval,
  automatic merge, and general multi-agent topology remain disabled.
- MCG6 closes only after clean-checkout CI and exact merged-candidate pinning.

## Gate MCG6

Status: **merge-pending**

MCG6 remains open until the implementation pull request passes clean-checkout
CI, merges, and the full merge-commit SHA and merge date replace the pending
provenance above. Phase 7 is not authorized from an unmerged candidate.

MCG6 reopens regardless of checklist state if any material profile component,
parameter, adapter, image, environment, policy, registry, credential mode,
memory mode, budget, check, retry, envelope, exclusion, or unavailable
capability is missing, mutable, unsigned, unapproved, expired, mismatched, or
silently falls back; a material change retains prior qualification; evaluation
answers enter prompts; corpus, seeds, base revisions, isolation, artifacts,
verification, blinding, thresholds, baselines, sample size, variance, tolerance,
confidence analysis, or failure reviews are incomplete or changed after result
viewing; a required quality, safety, authority, reliability, recovery, latency,
resource, token, or cost threshold fails; shadow output pushes, publishes,
changes task state, influences active implementation, feeds back into itself,
or omits production controls; shadow admission continues after drift, evidence,
isolation, cost, reconstruction, or threshold failure; pilot scope can bypass
allowlist, profile, volume, hours, on-call, or opt-out; a non-accepted candidate
publishes; candidate, verification, provenance, limitations, or repository
protections are incomplete; runtime or verifier can approve or merge; human
changes are attributed to the candidate; pending publication survives a stop;
disable controls fail to cover any declared scope, allow new effects, or destroy
recoverable state or evidence; incident, drain, revocation, notification,
quarantine, rollback, or reenable evidence is incomplete; a release decision is
not independent or ignores thresholds and unresolved findings; automatic
approval, automatic merge, or general multi-agent topology becomes authorized;
any MCG1-MCG5 gate reopens; or the exact architecture, Dialyzer, precommit, and
clean-checkout gates fail.
