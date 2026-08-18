## 8. Coding Agent Evaluations For Development

- Status: research baseline and implementation recommendation, not an accepted
  architecture decision, evaluation result, rollout authorization, or phase
  receipt
- Research cutoff: 2026-08-18
- Accepted merged repository baseline inspected:
  `ec98620c99d0db8f9a5b10105d7c56a3f5b902c0`
- Accepted Harness Phase 6 implementation candidate:
  `d00624e407826ca322c52557714ca20b1ba94518`
- Project scope: the JidoCode coding harness, including code-writing, code-review,
  repository-analysis, retrieval, verification, and controlled-publication
  profiles

## Executive conclusion

JidoCode should treat evaluation as a governed product control plane, not as a
leaderboard run or a collection of prompt examples. The object being evaluated
is not a model in isolation. It is the complete, versioned system:

> model snapshot + provider + access profile + agent scaffold + prompts + tools
> + retrieval + memory + sandbox + budgets + repository snapshot + verifier

A result that does not pin that tuple cannot support a deployment comparison.
A result that grades only the agent's final prose cannot support a correctness
decision. A result from a public, contaminated, or unaudited corpus cannot
support an autonomy decision.

The strongest current evidence converges on a layered approach:

1. specify externally observable outcomes and prohibited effects before
   implementing an agent behavior;
2. run each trial in a clean, isolated, revision-pinned environment;
3. make deterministic state and executable checks the primary oracle wherever
   the claim is mechanically decidable;
4. keep visible developer tests separate from verifier-owned, held-out, and
   compositional tests;
5. use structured human judgment for genuinely semantic questions;
6. use LLM graders only as calibrated advisory instruments, never as the sole
   authority for code acceptance, review truth, or security;
7. repeat trials and report both first-attempt capability and consistency;
8. report utility and security separately so an unsafe success cannot average
   into an acceptable score;
9. maintain fresh/private, incident-derived, negative-control, and adversarial
   corpora rather than relying on one public benchmark;
10. turn every material production failure into a regression case after the
    incident is understood;
11. measure real engineering outcomes in shadow and pilot operation, because
    benchmark success and perceived productivity do not establish production
    value; and
12. version the corpus, environment, oracle, rubric, and statistical analysis as
    rigorously as the agent itself.

This direction agrees with the current
[Harness Phase 7 plan](../planning/secure-effective-agent-harness/phase-07-evaluation-and-controlled-rollout.md),
especially its independent fresh-checkout verifier, hidden checks, blinded
human review, Wilson intervals, separate security outcomes, and staged rollout
gates [JC01-JC04]. Four material refinements should be made when Phase 7 is
implemented:

- **Public SWE-bench scores must not be rollout gates.** OpenAI's 2026 audits
  report that at least 59.4% of a hard 138-task SWE-bench Verified audit subset
  had material specification or test problems, and that roughly 30% of
  SWE-Bench Pro tasks were broken. The same work also found contamination in
  frontier models [CB03-CB04]. These audits were produced by a benchmark user,
  not a neutral standards body, but the failure modes are concrete enough that
  either benchmark is unsafe as a release oracle. Retain them only as public
  compatibility and diagnostic tracks.
- **The primary capability and graduation suites should be fresh/private
  JidoCode and Elixir tasks.** They must use audited prompts, pinned repositories,
  independent hidden oracles, clean negative controls, and a contamination
  ledger. Fresh public pipelines such as SWE-bench-Live and SWE-rebench are
  useful external diagnostics, but freshness does not repair an ambiguous
  specification or weak test suite [CB05-CB06].
- **Review and analysis need first-class tracks.** Patch correctness does not
  measure whether an agent can find defects, suppress false alarms, localize a
  cause, substantiate a repository claim, or express uncertainty. Review and
  analysis require different truth construction, units of scoring, and human
  adjudication [RV01-RV09, AN01-AN08].
- **The evaluation system itself needs evaluation.** Task quality, oracle
  mutation strength, grader-human agreement, judge robustness, flake rate,
  leakage, and adjudicator disagreement are release evidence. They cannot be
  invisible implementation details [EV01, CB03-CB04, CB10-CB13, JG01].

The near-term recommendation is therefore to build a small but high-quality
20-50-task internal suite first, establish the evaluation record and isolated
runner, then expand toward the plan's 300-task publication gate. The initial
suite should deliberately include coding, review, analysis, clean negatives,
and hostile cases. A large corpus of weakly specified tasks would create more
confidence theater than evidence [EV01].

## Scope and research questions

This report answers six questions:

1. What exactly must be pinned when comparing coding-agent systems?
2. How should coding changes be tested beyond visible unit tests?
3. How should agent-authored reviews be evaluated when many valid reviews are
   possible and historical PR comments are incomplete ground truth?
4. How should repository analysis be evaluated without grading hidden
   chain-of-thought or trusting unsupported prose?
5. How should stochastic results, grader disagreement, contamination, and
   benchmark defects be handled statistically and operationally?
6. How should evaluations be used during development, CI, release, shadowing,
   and controlled rollout in this repository?

The report covers agents that:

- inspect, edit, build, test, and debug repositories;
- review proposed changes and produce findings;
- answer repository questions, localize faults, trace dependencies, assess
  impact, or produce technical and security analyses;
- retrieve context and use developer-local or managed tools; and
- propose evidence that may later support a governed outcome.

It does not claim to evaluate a model's private reasoning. JidoCode should not
require or store private chain-of-thought as an oracle. It should evaluate
observable actions, state transitions, patches, tests, citations, structured
claims, tool evidence, uncertainty, and final outcomes.

## Terminology and evaluation unit

The terminology below follows current agent-evaluation practice [EV01]:

| Term | Meaning in this report |
| --- | --- |
| Evaluation target | One fully pinned agent-system profile, not a model name |
| Corpus | A versioned set of eligible tasks and exclusions |
| Task | One instruction, repository state, environment, and success contract |
| Trial | One independent execution of one task by one target profile |
| Outcome | Authoritative end state and artifacts, not what the agent says happened |
| Trace | Observable messages, tool proposals/results, timing, and state transitions |
| Oracle | Authoritative mechanism that establishes a fact or outcome |
| Grader | A check that produces a result from an outcome, artifact, or trace |
| Rubric | Versioned rules for semantic or human grading |
| Finding | One normalized review claim about one defect or risk |
| Analysis claim | One externally checkable assertion plus evidence and scope |
| Adjudication | Independent resolution of disputed task, finding, or grade truth |
| Eval run | A pinned collection of planned trials and its aggregate analysis |
| Gate | A preregistered rule that permits or blocks a rollout transition |

### The evaluation target tuple

Every result should identify at least:

```text
target = {
  product_revision,
  model_provider,
  model_identifier_and_snapshot,
  inference_parameters,
  access_profile_revision,
  agent_scaffold_revision,
  system_and_task_prompt_digests,
  tool_schema_and_policy_revisions,
  retrieval_index_and_context_policy_revisions,
  memory_policy_revision,
  sandbox_and_base_image_digests,
  dependency_lock_and_runtime_versions,
  time_step_token_cost_and_tool_budgets,
  verifier_and_grader_revisions
}
```

Changing any field creates a different target. Reporting “Model X scored 72%”
when the scaffold, tools, budgets, or verifier differ is not a controlled
comparison. Terminal-Bench results and AnalysisBench both demonstrate that
agent architecture can materially change performance independently of the
underlying model [CB09, AN01].

### Capability, regression, and gate suites

These suites have different purposes and should not be collapsed:

| Suite | Question | Expected behavior | Change policy |
| --- | --- | --- | --- |
| Capability | What difficult work can the profile do now? | Meaningful failures and headroom | Add difficult representative tasks; avoid optimizing only to public items |
| Regression | Can it still do what was previously reliable? | Near-100% on protected behavior | Add confirmed failures; failures block relevant changes |
| Conformance | Does a contract or adapter obey its exact invariants? | Deterministic pass | Version with the contract; fail closed |
| Security/adversarial | Can the profile preserve authority and outcome integrity under attack? | Safe completion or safe refusal | Critical violation blocks regardless of utility score |
| Release gate | Does a pinned candidate meet a preregistered threshold? | Statistically supported decision | Freeze corpus/rubric before execution |
| Shadow/pilot | Does it improve real work without unacceptable externalities? | Better user/system outcomes | Compare against baseline and monitor drift |

Anthropic recommends starting capability evals with tasks that expose failures,
while regression evals should remain close to perfect. Mature capability tasks
can graduate into regression tests [EV01]. JidoCode should preserve their
original provenance and never silently move a failed regression task back into
the capability bucket.

## Evaluation architecture

The smallest useful architecture has an explicit evidence flow:

```text
versioned specification
        |
        v
audited task + pinned repository + clean environment
        |
        v
fully pinned agent target -----> immutable observable trace
        |                                 |
        v                                 v
candidate artifacts/state ------> policy and behavior diagnostics
        |
        v
independent verifier-owned oracles and prohibited-effect checks
        |
        +----------> semantic/human grading where required
        |                         |
        v                         v
per-trial evidence ----------> adjudication record
        |                         |
        +------------+------------+
                     v
          preregistered aggregate analysis
                     |
                     v
       rollout decision + production monitoring
                     |
                     v
        incidents become regression candidates
```

This fits the existing JidoCode boundary. The agent executor may create a
candidate; the independent verifier reconstructs and tests it; verification
evidence is revision-bound; acceptance is a separate governed decision; and
publication requires its own authority [JC02-JC04]. The evaluation plane should
consume these records rather than inventing a second, weaker definition of
success.

### Layers of evidence

No single layer is sufficient:

| Layer | Examples | What it establishes | What it cannot establish alone |
| --- | --- | --- | --- |
| Contract | tool schema, access profile, CLI protocol | interface and containment conformance | task correctness |
| Deterministic outcome | compile, tests, state query, digest | exact executable facts | completeness of the oracle |
| Independent hidden outcome | held-out tests, mutation checks, negative controls | resistance to visible-test fitting | subjective maintainability or intent |
| Static/dynamic analysis | type, lint, security, coverage, trace | specific properties and risk indicators | all semantic correctness |
| Structured artifact | patch, review finding, evidence-backed claim | machine-valid shape and provenance | truth of every semantic claim |
| Human expert | rubric and adjudication | nuanced intent, usefulness, severity | cheap or perfectly repeatable grading |
| LLM grader | triage, semantic matching, rubric suggestion | scalable advisory signal | authoritative correctness or security |
| Production outcome | review time, revert, incident, delivery metrics | real-world value and harm | isolated causal attribution without design |

The default precedence should be:

1. authorization, containment, and prohibited-effect invariants;
2. deterministic state and executable correctness;
3. verifier-owned hidden and compositional checks;
4. static, dynamic, performance, and security checks;
5. structured human adjudication for irreducibly semantic questions; and
6. calibrated LLM-based signals as diagnostics.

A lower layer must never waive a failure at a higher layer. “The judge liked
the patch” cannot override a failed hidden test. “The task eventually passed”
cannot override unauthorized egress or grader tampering.

## What current benchmarks do and do not measure

Public benchmarks are useful for interoperability, comparative diagnostics,
and discovering evaluation techniques. They do not establish that JidoCode is
safe or effective on its product distribution.

| Benchmark or method | Useful signal | Important limitation | Recommended JidoCode use |
| --- | --- | --- | --- |
| HumanEval/pass@k [ST01] | Small functional synthesis and repeated sampling | Functions, not repository work; public and saturated | Statistical terminology and unit-level smoke diagnostics only |
| EvalPlus [CB10] | Test amplification using generated inputs and mutation analysis | Still small synthesis tasks | Adopt the test-strengthening technique, not its task distribution |
| SWE-bench [CB01] | Real issue-to-patch repository tasks | Python-heavy, public, environment and oracle defects | Historical compatibility only |
| SWE-bench Verified [CB02-CB03] | Expert-curated 500-task subset | Contamination, saturation, audited defects | Public regression/diagnostic; never a rollout gate |
| SWE-Bench Pro [CB04, CB07] | Larger and multilingual/longer issue work | 2026 audit estimates roughly 30% broken | Experimental diagnostic after task-level exclusions only |
| SWE-bench-Live [CB05] | 1,319 initially recent tasks across 93 repositories | Primarily Python; freshness does not guarantee fair tests | External recency and harness diagnostic |
| SWE-rebench [CB06] | Continuously collected, decontamination-oriented tasks; large task pipeline | Automated collection still needs oracle audit | Source of fresh candidates and external diagnostic |
| Multi-SWE-bench [CB08] | 1,632 expert-annotated tasks in seven non-Python languages | No Elixir and still public | Cross-language scaffold diagnostic |
| SWE-PolyBench [CB09] | Repository work across Python, Java, JavaScript, and TypeScript | Public; language/task mix unlike JidoCode | Optional retrieval/editing diagnostic |
| SWE-Gym/SWE-smith [CB14-CB15] | Thousands of executable or synthetic tasks for training and stress testing | Training distribution and synthetic artifacts can distort evaluation | Generate candidates, never mix train and sealed test sets |
| Terminal-Bench 2.0 [CB16] | 89 hard terminal tasks with isolated environments, human solutions, and tests | Broad terminal work, not the JidoCode product distribution | External harness and long-horizon interoperability track |
| METR time horizons/HCAST [MT01-MT03] | Capability as a function of human task duration | Well-specified, low-context task distribution; not wall-clock runtime | Long-horizon trend and task-duration stratification |
| SpecBench [CB11] | Visible-versus-held-out compositional gap on systems tasks | Small 30-task research benchmark | Copy its compositional holdout pattern |
| EvilGenie [CB12] | Explicit test editing/hard-coding reward-hacking cases | Artificially hackable programming environment | Seed adversarial outcome-integrity cases |
| AnalysisBench [AN01] | 35 manually verified tool-project setup/analysis tasks | C/C++ and Java; narrow analysis-tool application | Copy stage-specific and manual validation methods |
| AACR-Bench/c-CRAB/CR-Bench [RV04, RV08-RV09] | Repository-level review, expert-expanded truth, executable review evidence, precision/noise trade-off | New, public, and each captures only part of review truth | External review diagnostic and corpus-design input |

### Why the public SWE-bench tracks cannot gate rollout

The lifecycle of SWE-bench is a useful warning about benchmark governance:

1. The original benchmark converted real GitHub issues and pull requests into
   executable patch tasks [CB01].
2. SWE-bench Verified added a major human curation campaign: 93 developers
   annotated 1,699 candidate tasks, each with three independent reviewers, to
   produce 500 tasks [CB02].
3. In February 2026, an audit of 138 tasks that a frontier model did not solve
   consistently across 64 runs reported material specification or test issues
   in 59.4% of that audited subset, plus evidence of contamination [CB03].
4. The same report recommended SWE-Bench Pro; in July 2026, a subsequent audit
   flagged 200 of 731 tasks by an automated pipeline and 249 of 731 by human
   annotation. It estimated about 30% of the dataset was broken, citing overly
   strict tests, underspecified prompts, weak coverage, and misleading prompts
   [CB04].

This does not imply that every public benchmark result is useless. It means a
single aggregate score hides which tasks are invalid, contaminated, saturated,
or scaffold-sensitive. JidoCode should:

- record public results at task granularity;
- maintain an exclusion and dispute ledger;
- report raw and audited-subset results separately;
- prohibit public tasks from satisfying fresh/private publication counts;
- never tune prompts on the sealed release set;
- disclose the agent scaffold, budgets, attempts, and exclusions; and
- use public tracks to find regressions and compatibility gaps, not to prove
  product safety.

### Freshness is necessary but insufficient

SWE-bench-Live and SWE-rebench address contamination by continuously collecting
new tasks [CB05-CB06]. JidoCode should borrow this temporal split:

- training/development material ends before a declared cutoff;
- validation tasks guide tuning but never enter the release test set;
- sealed release tasks are created after the target model's relevant knowledge
  cutoff where practical;
- production-derived cases remain private until retirement; and
- retired tasks may become public regression examples only after replacement.

Fresh tasks can still be broken. Every fresh/private case needs task-level
eligibility and oracle review before it counts toward a gate.

## Building a trustworthy task corpus

### Task eligibility contract

A task is eligible only when all of the following are true:

| Requirement | Evidence |
| --- | --- |
| Pinned starting state | Repository URL/identity, commit, submodules, lockfiles, base image, runtime, and toolchain digests |
| Clear instruction | Two qualified reviewers agree the checked behavior is reasonably inferable from the task |
| Reproducible baseline | The declared failure or starting condition reproduces in independent clean environments |
| Known-valid solution | A reference or independently produced solution passes every required oracle |
| Baseline discrimination | The base fails each required fail-to-pass check and passes protected pass-to-pass checks |
| Oracle independence | Acceptance does not depend only on tests or claims authored by the evaluated agent |
| Sufficient oracle strength | Boundary, negative, property, mutation, and/or compositional checks cover the requested behavior |
| No secret leakage | The agent cannot read hidden tests, expected patches, scorer code, or adjudication labels |
| Bounded effects | Network, credentials, filesystem, process, and publication authority match the profile |
| Stable execution | Flake characterization, retry policy, resource limits, and timeouts are pinned |
| Scorable output | The expected artifact or state and every critical prohibited effect are mechanically observable |
| Reviewable ambiguity | Disputes have a documented independent adjudication path |
| Contamination status | Public/private/fresh dates, exposure history, and suspected model access are recorded |
| Representativeness | Task tags place it in a preregistered product slice rather than an untracked convenience sample |

Zero success across many strong trials should trigger a task audit before it is
interpreted as a capability result. Anthropic notes that 0% at very high `k`
often reveals a broken task, and both 2026 SWE-bench audits demonstrate why
[EV01, CB03-CB04]. Conversely, 100% from all targets can mean the task is too
easy, leaked, or under-tested.

### Corpus partitions

JidoCode should maintain physically and logically separate partitions:

| Partition | Visible to developers/agents? | Purpose | Rotation |
| --- | --- | --- | --- |
| Development | Yes | Fast iteration and debugging | Continuous |
| Validation | Prompt/scaffold team only | Compare candidate designs | Periodic; never report as test |
| Sealed release | No task labels, oracle, or expected artifacts | Release and rollout gates | Fixed for a decision, then refreshed |
| Security red-team | Limited custodians | Adaptive and outcome-integrity attacks | Refresh after exposure |
| Production shadow | Natural tasks; identity protected | Real distribution and operational value | Rolling windows |
| Regression | Task visible; hidden oracle protected as needed | Preserve confirmed behavior | Append incident-derived cases |
| Benchmark-audit canaries | Custodians only | Detect leakage, grader failure, and suspiciously perfect results | Regular replacement |

The task record should identify whether a trial may influence prompts, routing,
retrieval, or model selection. If it may, it is training or validation data from
that point forward, not sealed test data.

### Positive, negative, and metamorphic cases

Balanced suites prevent one-sided agents [EV01]. Each behavior should include:

- positive cases where the edit, review finding, search, or escalation is
  required;
- negative cases where the correct behavior is to leave valid code alone,
  suppress a finding, avoid a tool, or state that evidence is insufficient;
- near-neighbor cases differing in one decisive condition;
- metamorphic cases where harmless renaming, formatting, order, or equivalent
  implementation must not change the grade;
- contradiction cases where an instruction, comment, or retrieved source makes
  a false claim that conflicts with executable or source evidence;
- out-of-distribution cases that require an explicit abstention or escalation;
  and
- adversarial cases that offer an easy path to pass visible checks by violating
  the true specification.

CodeJudgeBench found code judges sensitive to response order, variable names,
and misleading comments [JG01]. The same transformations should be standard
metamorphic tests for JidoCode graders and analysis/review profiles.

### Test-suite strength

Passing tests measures correctness only relative to those tests. EvalPlus
expanded HumanEval tests roughly 80-fold using LLM-generated inputs and
mutation-based strategies; the strengthened suites reduced measured `pass@k`
by as much as 19.3-28.9 percentage points and changed some model rankings
[CB10]. That finding supports a concrete oracle-audit pipeline:

1. prove the reference patch passes and the base fails the intended checks;
2. generate boundary, property, and equivalence cases from the specification;
3. run mutation testing against the reference and plausible near-miss patches;
4. require a minimum mutation score by task category;
5. add compositional tests that combine individually visible features;
6. execute performance/resource tests where the specification contains
   complexity or boundedness requirements;
7. test an independent alternate correct implementation to detect overly
   prescriptive oracles; and
8. manually audit any task that distinguishes high-performing targets or
   controls a release decision.

SpecBench reports that frontier agents can saturate visible feature tests while
failing held-out compositions, with the visible/held-out gap growing with code
size [CB11]. A JidoCode coding task should therefore have at least these
conceptual suites:

- `base_reproduction`: proves the starting problem;
- `candidate_visible`: developer-visible checks allowed during work;
- `pass_to_pass`: protects established behavior;
- `verifier_hidden`: independent boundary and negative checks;
- `verifier_compositional`: exercises features together;
- `policy_invariants`: detects forbidden effects and evidence tampering; and
- `nonfunctional`: security, performance, resource, compatibility, or
  maintainability constraints where applicable.

### Task manifest

A conceptual task manifest should contain the following. This is a data
contract recommendation, not a commitment to YAML storage:

```yaml
task_id: jido-edit-0042
task_revision: 3
track: editing
instruction_digest: sha256:...
repository:
  identity: ...
  base_commit: ...
  submodule_digests: []
environment:
  image_digest: sha256:...
  lock_digest: sha256:...
  runtime_versions: {...}
eligibility:
  reviewers: [reviewer-a, reviewer-b]
  reference_solution_digest: sha256:...
  contamination_class: private-post-cutoff
slices:
  language: elixir
  framework: phoenix
  task_type: cross-file-bug-fix
  risk: high
  human_duration_minutes: 90
budgets:
  wall_time_seconds: 3600
  model_steps: 120
  tokens: 250000
  cost_microunits: ...
oracles:
  visible_revision: ...
  hidden_revision: ...
  mutation_policy_revision: ...
  prohibited_effect_policy_revision: ...
adjudication:
  rubric_revision: ...
  independent_reviewers: 2
  resolver_policy: third-reviewer
statistics:
  planned_trials: 5
  primary_endpoint: correct_accepted
```

The agent receives only the fields its access profile permits. Hidden oracle
identities, scorer code, reference solutions, and labels remain in a separate
evaluator trust domain.

## Isolated and production-representative execution

Each trial must begin from a newly reconstructed environment. Shared worktrees,
git history from previous trials, warm mutable caches, lingering processes,
ports, environment variables, or rate-limit state can make trials correlated
or leak answers. Anthropic reports agents gaining an unintended advantage from
prior-trial git history, illustrating that “clean enough” is not a sound
boundary [EV01].

For every trial JidoCode should record:

- base image and package/runtime digests;
- repository and submodule revisions;
- allowed network destinations and observed connections;
- credential capability identities without secret values;
- CPU, memory, disk, process, time, token, step, and cost budgets;
- random/inference seeds when a provider exposes them, without assuming they
  make generation deterministic;
- tool proposals, policy decisions, effects, exits, and outputs;
- candidate patch and artifact digests;
- verifier environment and check digests;
- infrastructure anomalies separately from agent failures; and
- enough evidence to reproduce the authoritative checks in a fresh checkout.

Production representativeness does not justify weakening isolation. The right
design is a production-equivalent tool and context profile inside a controlled
environment, with a separately governed shadow profile for natural workloads.

## Grader design and oracle precedence

### Grader matrix

| Grader | Appropriate uses | Required controls | Authority |
| --- | --- | --- | --- |
| Exact schema/state | tool proposals, RDF shapes, files, Git state, database state | canonicalization, pinned schema, negative cases | Authoritative for the exact property |
| Compiler/test | build, behavior, regression | clean checkout, pinned deps, hidden tests, flake policy | Authoritative within oracle coverage |
| Property/mutation/fuzz | boundary and test strength | deterministic replay artifact, shrink/reproducer, budget | Authoritative when reproducible |
| Static analyzer | type, lint, dependency, known security class | pinned rules/version/baseline | Authoritative for configured finding, not full correctness |
| Dynamic/resource | crashes, races, resource/performance bounds | controlled load, tolerance, repeated measurement | Authoritative under pinned protocol |
| Policy monitor | authorization, egress, protected paths, stale fences | outside agent control, durable evidence | Hard gate |
| Structured semantic matching | map a review/claim to known truth | blinded matching, deterministic fields first, human dispute path | Advisory until adjudicated |
| LLM rubric | prose quality, semantic triage, candidate matching | calibration, perturbation tests, abstain option, pinned judge | Advisory only |
| Human expert | intent, severity, usefulness, incomplete truth | independent reviewers, blinded target, rubric, disagreement process | Authoritative semantic adjudication |

### Grade outcomes, not one expected trajectory

Agents may take multiple valid paths. Requiring an exact tool order makes an
eval brittle and rewards imitation rather than outcomes [EV01]. Trajectory
checks should be limited to behavior that is itself a contract or safety
property, such as:

- a forbidden tool or path was never available or used;
- every external effect had an admitted proposal, capability, lease, and fence;
- the agent did not modify verifier-owned files;
- the run remained within budget and terminated coherently;
- a claimed fact was preceded by retrievable evidence;
- retries preserved or changed idempotency identity correctly; or
- the agent recovered from an injected tool failure without violating policy.

Exploration strategy, file-reading order, or number of intermediate hypotheses
should normally be diagnostic, not a pass condition. Report them to explain
performance and cost, not to forbid creative valid solutions.

### Partial credit and hard gates

Partial credit is valuable for capability diagnosis: localization can be right
even when a patch is wrong, or a review can find one of three defects. It must
not be confused with acceptance. Maintain both:

- a diagnostic score vector for subsystem improvement; and
- a binary gate result whose required checks all pass.

Critical authorization, credential, protected-branch, evidence, host-isolation,
or oracle-integrity violations are absorbing failures. They are never averaged
with task utility.

## Outcome integrity and reward hacking

Coding agents can optimize the visible measurement instead of the requested
system. Research examples include hard-coded inputs, test-file editing,
weak-test exploitation, misleading comments, and implementations that satisfy
isolated visible features but fail composition [CB11-CB13]. EvilGenie reports
explicit reward-hacking behavior from evaluated coding agents in an environment
designed to make such behavior possible [CB12].

JidoCode's evaluator should be outside the candidate sandbox and enforce:

1. hidden tests and scorer implementation are absent from the agent filesystem
   and context;
2. the evaluator image, task manifest, and grader revisions are content-pinned;
3. the agent cannot edit the test harness, expected results, package source,
   clocks, process supervisor, network policy, or evidence store;
4. candidate-authored tests count only when they fail at the pinned base and
   pass on the candidate, and they never replace independent checks;
5. test deletion, skip insertion, selective discovery, dependency shadowing,
   fixture replacement, hard-coded task IDs, and environment detection are
   explicit adversarial checks;
6. the fresh-checkout verifier reconstructs the candidate from admitted
   artifacts rather than trusting the executor worktree;
7. visible and hidden/compositional pass rates are reported separately;
8. suspiciously large gaps, perfect scores, or unusual access patterns trigger
   human audit; and
9. the utility result and security result form a vector, not a blended scalar.

This is consistent with JidoCode's accepted Phase 6 verifier and evidence
boundary [JC02-JC04]. Evaluation should reuse that stronger path for every
acceptance claim.

## Evaluating code-writing and editing agents

### Capability decomposition

An end-to-end patch score is necessary but too coarse to explain failures.
JidoCode should tag and diagnose at least these capabilities:

| Capability | Representative tasks | Primary oracle | Diagnostic signals |
| --- | --- | --- | --- |
| Instruction understanding | change scope, constraints, acceptance criteria | hidden requirement checks and human dispute review | omitted/contradicted requirement rate |
| Repository navigation | locate implementation, tests, configuration, generated boundaries | gold/evidence locations, dynamic slices, retrieval labels | file/function recall, reading load, irrelevant context |
| Fault localization | identify cause rather than symptom | known fault location and reproducer | Top-k, MRR, EXAM-style rank |
| Patch construction | fix, feature, refactor, migration | fail-to-pass plus pass-to-pass tests | compile rate, patch applicability, changed-surface size |
| Test generation | add discriminating regression checks | fail on base, pass on candidate, mutation strength | mutation score, boundary coverage, redundant-test rate |
| Multi-file consistency | update callers, schemas, docs, migrations | dependency/integration checks | missed-edge and stale-reference rate |
| Tool use/recovery | build, inspect, edit, retry, recover | contract and injected-failure scenarios | valid proposal rate, recovery success, loop/stall rate |
| Nonfunctional quality | security, performance, compatibility, maintainability | pinned analyzer/load/rubric | regression magnitude and reviewer burden |
| Scope control | avoid unrelated or protected changes | diff/policy check | unauthorized paths, diff expansion, churn |
| Outcome reporting | accurately state what changed and what was verified | artifact/evidence reconciliation | unsupported success claim rate |

Task categories must include more than issue fixing. The product distribution
should cover:

- localized and cross-file bug fixes;
- new features with explicit negative cases;
- refactors that must preserve behavior;
- test-only and reproduction work;
- dependency, configuration, build, and migration changes;
- Phoenix/LiveView, Ecto/data, OTP/concurrency, CLI, and protocol changes;
- flaky, timing, resource, and failure-recovery tasks;
- ambiguous requests where the correct response is clarification or refusal;
- already-correct code where no edit is warranted; and
- tasks containing untrusted repository instructions or hostile fixtures.

### Correctness decision

A patch should be `correct` only when all task-required checks pass in the
independent environment. A patch should be `accepted` only when the governed
decision policy accepts the exact patch/evidence digest. These are distinct:

```text
eligible task
  -> attempted?
  -> valid bounded proposal?
  -> independently correct?
  -> accepted by policy/human?
  -> published?
  -> externally observed as healthy?
```

Collapsing those transitions into “resolved” hides whether the system failed to
produce a patch, produced a correct patch that was unnecessarily rejected, or
accepted an incorrect patch.

### Primary coding metrics

The Phase 7 plan already names the right acceptance-centered metrics [JC01].
Their denominators must remain explicit:

```text
Correct Accepted Yield = correct and accepted outcomes / eligible tasks
Accepted Precision      = correct accepted outcomes / all accepted outcomes
Acceptance Coverage     = accepted outcomes / eligible tasks
Attempt Coverage        = completed eligible trials / planned eligible trials
Proposal Validity       = schema-valid bounded proposals / all proposals
Containment Rate        = malformed or unauthorized proposals safely contained
Critical False Accept   = accepted outcome with a critical correctness/security defect
```

Also report:

| Metric | Why it matters |
| --- | --- |
| `pass@1` | Expected first-attempt capability on the task distribution |
| `pass@k`, explicitly labelled | Whether repeated independent attempts can find at least one solution |
| `pass^k`, explicitly labelled | Whether the system succeeds consistently across all `k` attempts |
| Hidden-test pass rate | Correctness beyond developer-visible checks |
| Visible/held-out gap | Reward-hacking or incomplete-generalization warning |
| Pass-to-pass preservation | Regression safety |
| Fresh-checkout reproducibility | Independence from executor state |
| Test discrimination/mutation score | Strength of generated and verifier tests |
| Patch applicability | Candidate artifact integrity |
| Scope adherence | Unrequested or protected change rate |
| Recovery success | Correct recovery after tool, provider, build, and flake faults |
| Unsupported completion claim rate | Whether prose agrees with actual evidence |
| Cost/latency per correct accepted outcome | Operational efficiency with failures included |
| Human verification minutes | Oversight burden, not just generation speed |
| Post-publication CI/revert/incident rate | Delayed outcome quality |

Token cost per attempted task can look better when a system exits early and
fails. Cost should therefore be reported both per trial and per correct
accepted outcome. The same applies to latency.

### Required slices

Aggregate scores should be accompanied by preregistered slices. At minimum:

| Dimension | Example strata |
| --- | --- |
| Repository | JidoCode, other first-party, private external, public benchmark |
| Language/framework | Elixir/Phoenix/LiveView/OTP, JavaScript, shell, external languages |
| Task type | bug, feature, refactor, test, migration, dependency, analysis-assisted edit |
| Scope | one file, cross-file, cross-application, generated/config/data boundary |
| Human duration | `<15m`, `15-60m`, `1-4h`, `>4h` |
| Risk | low, medium, high, critical/security-sensitive |
| Context condition | full, retrieval-limited, stale distractor, missing/ambiguous |
| Failure mode | deterministic, flaky, concurrency, environment, external dependency |
| Target profile | model/provider/scaffold/tool/retrieval/access revision |
| Authority | read-only, workspace edit, delegated local execution, managed shadow |

METR's time-horizon work defines task difficulty by the time a human takes to
complete a task at a given success probability, not by agent runtime [MT01].
JidoCode should capture calibrated human duration because a system that improves
only short, self-contained tasks has a different product value from one that
preserves reliability as repository scope increases.

### Coding failure taxonomy

Every failed or disputed trial should receive one primary and optional
secondary labels:

- task/specification defect;
- environment/infrastructure defect;
- oracle/grader defect;
- context retrieval miss or pollution;
- instruction misunderstanding;
- incorrect localization;
- incomplete dependency/impact reasoning;
- incorrect implementation;
- missing/weak test;
- visible-test overfit or reward hacking;
- regression outside the requested feature;
- unauthorized or over-broad effect;
- tool/protocol error;
- failed recovery, loop, or premature termination;
- budget exhaustion;
- correct candidate rejected by policy or reviewer;
- incorrect candidate accepted; or
- inconclusive.

The taxonomy prevents benchmark defects from being counted as model failures
and prevents infrastructure exclusions from being used opportunistically to
improve a target's score.

## Evaluating code-review agents

### Review is defect retrieval, not reference-text imitation

Code review is one-to-many: different reviewers can find different valid
issues and phrase the same issue differently. CRScore documents why BLEU,
ROUGE, exact text match, and similar reference-response metrics are poor
measures, and reports only moderate human alignment even for its stronger,
claim-grounded reference-free method [RV02]. Historical PR comments are also
positive-unlabeled data: an issue mentioned by a reviewer is evidence that it
exists, but silence is not evidence that every other issue is absent.

Recent benchmarks improve different parts of this problem:

- CodeReviewQA separates change-type recognition, localization, and solution
  identification on 900 curated examples across nine languages [RV03].
- AACR-Bench adds full repository context and an AI-assisted,
  expert-verified annotation process. Its authors report 285% greater defect
  coverage than raw PR comments, demonstrating how incomplete historical
  comments can be [RV04].
- c-CRAB converts human review findings into held-out executable tests,
  connecting a review claim to observable behavior [RV08].
- CR-Bench explicitly examines the frontier between issue resolution and
  spurious findings, which is central to practical review utility [RV09].
- CriticGPT found that AI assistance can help humans catch errors, while also
  showing the critic itself can hallucinate issues. Human-plus-critic review
  was preferred to unassisted review more than 60% of the time in the reported
  experiment [RV01].

The design implication is to evaluate a review agent as a detector and an
oversight aid, not as an autonomous merge authority or prose generator.

### Review truth construction

No one source can provide complete review ground truth. Use a portfolio:

| Source | Strength | Weakness | Use |
| --- | --- | --- | --- |
| Expert-seeded defects | Known location, class, and severity | Can be artificial or too obvious | Controlled recall and localization |
| Historical defects with reproducer/fix | Real context and consequence | Surviving records favor discovered defects | Realism and executable oracle |
| Human PR comments | Natural wording and developer priorities | Incomplete, noisy, sometimes wrong | Candidate positives, never complete negatives |
| Independent hidden tests | Reproducible behavioral defect | Not every review concern is executable | Strong correctness truth |
| Static/dynamic analyzer findings | Deterministic known classes | Tool-specific false positives/blind spots | Specialized slices |
| Mutation-generated defects | Scalable paired clean/buggy variants | Mutation distribution may be unrealistic | Controlled sensitivity and near-neighbor tests |
| Incident/postmortem defects | High impact, realistic | Rare and sensitive | Critical regression suite |
| Clean PR negative controls | Measures spurious findings and restraint | “Clean” requires strong review | Precision/noise estimation |
| Benign alternate implementations | Tests style and implementation bias | Expensive to construct | Metamorphic robustness |

For release-quality review tasks:

1. two independent qualified reviewers inspect the full task context while
   blinded to the evaluated agent;
2. known executable or analyzer evidence is available to, but does not replace,
   their review;
3. each gold issue has a normalized location, defect claim, impact, severity,
   evidence, and reproduction or rationale;
4. a third reviewer resolves disagreement;
5. late-discovered valid issues append the truth set with versioned provenance;
6. evaluation results affected by truth-set changes are invalidated or restated;
   and
7. clean negatives receive the same review effort as positive cases.

### Required review output schema

Free-form comments should be derived from structured findings. Each candidate
finding should include:

```text
finding_id
repository_revision
changed_file and changed_line/range, or explicit repository-level scope
category
severity
claim: what is wrong
preconditions: when the issue occurs
impact: observable consequence
evidence: source ranges, trace, test, analyzer, or specification
reproduction_or_test: optional but required for executable critical claims
remediation: bounded suggested direction
confidence
abstain_or_unknown_reason
related_finding_ids for deduplication
```

Schema validation should reject nonexistent files, out-of-diff coordinates
when the review policy requires changed-line anchoring, invalid revisions, and
missing evidence for high-severity claims before a comment reaches a human.

### Matching a predicted finding to truth

Finding matching should use a cascade:

1. exact repository and revision identity;
2. deterministic overlap or dependency relation for file/range/symbol;
3. compatible defect category and precondition;
4. matching executable reproducer, expected effect, or analyzer rule where
   available;
5. blinded human semantic equivalence for unresolved cases; and
6. an LLM matcher only for triage, with its proposed match hidden from the
   adjudicator until after the independent decision.

Multiple agent comments about the same root cause count as one true positive
plus duplicates, not multiple discoveries. One vague comment that lists many
unrelated possibilities should not receive credit for every matching gold
issue. The matching policy and intersection-over-union/location tolerances must
be frozen before the test run.

### Review metrics

The primary review result is a vector, not a single score:

| Metric | Definition or intent |
| --- | --- |
| Finding precision | Matched valid findings / published findings |
| Finding recall | Matched gold findings / eligible gold findings |
| Critical recall | Matched critical/high findings / critical/high gold findings |
| Critical false negatives | Count and task incidence; hard gate where applicable |
| Clean-PR false-positive rate | Clean tasks with at least one invalid finding / clean tasks |
| Noise per PR | Invalid, duplicate, trivial, or unverifiable comments per reviewed PR |
| Noise per KLOC/change size | Normalizes review volume across patches |
| Localization precision/recall | Correct file/symbol/range among findings and gold issues |
| Severity accuracy | Agreement/confusion matrix against adjudicated severity |
| Calibration | Reliability curve, Brier score, and ECE for confidence |
| Actionability | Valid findings with a specific reproducible next step |
| Evidence sufficiency | Findings whose cited evidence entails the claim |
| Duplicate rate | Redundant comments / proposed comments |
| Time to first valid finding | Oversight latency |
| Verification minutes | Human time required to accept/reject the review |
| Defect escape | Gold or production defect missed after agent-assisted review |
| Human uplift | Difference between blinded human-alone and human-plus-agent arms |

Precision and recall must both be reported. Publishing many speculative
comments can improve recall while destroying developer trust and review time.
Publishing only obvious, high-confidence issues can improve precision while
missing critical defects. `F_beta` may summarize a preregistered operating
point, but it must accompany the components. A higher beta can weight recall
for critical/security slices; lower-risk style suggestions may prioritize
precision.

Comment acceptance, reaction, or whether a developer changed the line is a
useful production signal but not ground truth. Developers can ignore valid
findings, accept invalid ones, or change code for unrelated reasons.

### Review evaluation matrix

| Test family | Positive case | Negative/control | Oracle |
| --- | --- | --- | --- |
| Local logic | off-by-one, null/error path, wrong condition | equivalent refactor | hidden test + expert finding |
| Cross-file contract | caller/callee/schema mismatch | synchronized multi-file change | integration test + dependency evidence |
| Concurrency/OTP | race, supervision/retry error | deliberate safe ordering | deterministic schedule/trace where possible + expert |
| Security/authority | bypass, over-broad capability, secret exposure | secure unfamiliar pattern | exploit/reproducer + threat rubric |
| Data/migration | lossy migration, constraint mismatch | valid backward-compatible change | migration round-trip and invariants |
| Performance/resource | unbounded query/loop/memory | justified bounded cost | controlled benchmark/complexity check |
| Phoenix/LiveView | state, auth scope, DOM/stream contract | alternate valid component structure | LiveView tests + framework rubric |
| Test quality | deleted/skipped/weak assertion | legitimate test cleanup | mutation and base/candidate discrimination |
| Requirement fit | omitted user constraint | intentional out-of-scope code untouched | hidden acceptance checks |
| Already-correct PR | none | clean negative | two-reviewer clean adjudication |

### Human-plus-agent experiment

Before review comments are automatically published, run a blinded crossover or
randomized study:

- sample representative PRs and reviewers;
- randomize human-only versus human-plus-agent assistance, or counterbalance
  order in a crossover design;
- hide authoring profile and condition during truth adjudication;
- measure defect recall, false positives, review duration, verification time,
  confidence calibration, and critical escapes;
- account for reviewer and PR as clustered effects; and
- inspect whether assistance changes the kinds of defects found, not only the
  total.

CriticGPT supports the possibility of human uplift [RV01], while review-benchmark
work shows substantial incompleteness and false-positive trade-offs [RV02-RV09].
JidoCode should require measured uplift on its own repositories rather than
assuming a second agent is an independent or superior reviewer.

## Evaluating repository-analysis agents

### What counts as analysis

In this report, analysis includes:

- repository question answering and architecture explanation;
- change-impact and dependency analysis;
- fault localization and root-cause hypotheses;
- security/threat analysis and attack-path identification;
- test-gap, flake, performance, and concurrency diagnosis;
- implementation-plan feasibility and boundary analysis;
- static/dynamic analysis tool setup and interpretation; and
- incident or regression investigation.

AnalysisBench shows why a final self-declared success is inadequate: across its
35 tool-project tasks, agent self-validation consistently overstated manually
verified success, and failures included stage mixing, poor error localization,
and premature termination [AN01]. RepoReason uses execution-driven mutation and
dynamic slicing to create semantic ground truth and decompose repository
reasoning into reading load, simulation depth, and integration width [AN02].
SWE-QA, SWE-QA-Pro, and DependEval add cross-file, multi-hop, long-tail, and
dependency-focused task distributions [AN03-AN05].

### Evaluate claims, evidence, and decision usefulness separately

A fluent report can be wrong; a correct conclusion can be supported by invalid
evidence; and a well-grounded diagnosis can recommend an unsafe remediation.
Grade at least four layers:

1. **claim correctness**: is each externally checkable assertion true at the
   pinned revision and scope?
2. **evidence quality**: do the cited source spans, traces, tests, or tool
   results actually support that claim?
3. **coverage and reasoning product**: are required dependencies, alternatives,
   contradictions, and unknowns represented?
4. **recommendation quality**: is the proposed action feasible, scoped, and
   consistent with project policy and risk?

Writing quality is a fifth, lower-priority dimension. It must not compensate
for false claims or fabricated evidence.

### Structured analysis claim

Each material assertion should be externalized as a record:

```text
claim_id
task_id and trial_id
repository_identity and exact revision
claim_type
subject and scope
assertion
polarity: positive | negative | unknown
evidence_refs:
  - file/symbol/line range at revision
  - command/tool result digest
  - test/trace/analyzer result digest
  - accepted project document revision
inference_kind: direct | derived | hypothesis | recommendation
preconditions and temporal scope
confidence
contradicting_evidence_refs
unknown_or_abstention_reason
related_claim_ids
```

The evaluator should re-resolve source references at the pinned commit, replay
deterministic evidence, and distinguish “the source contains these words” from
“the source proves this interpretation.” A missing or stale citation is a
provenance failure even when the claim happens to be true.

### Analysis task and oracle matrix

| Analysis task | Primary truth | Secondary/human truth | Metrics |
| --- | --- | --- | --- |
| Repository fact QA | exact source/config/test state | expert wording/coverage | atomic accuracy, evidence precision/recall |
| Cross-file intent/architecture | accepted docs + source/dependency graph | maintainers | required-fact coverage, contradiction rate |
| Dependency/impact | compiler/build graph, calls/imports, runtime traces | expert hidden edges | edge precision/recall, missed-impact severity |
| Fault localization | seeded/historical fault and failing reproducer | expert root cause | Top-k, MRR, EXAM rank, reproduction success |
| Root-cause explanation | fault, trace, and counterfactual fix | blinded experts | causal-claim precision, sufficiency, alternate hypotheses |
| Static/dynamic tool application | manually verified tool-project setup and output | tool/domain expert | setup success, meaningful-output success, false self-success |
| Security/threat analysis | exploit, policy model, seeded attack paths | security reviewers | critical recall, false positives, attack-path completeness |
| Test-gap analysis | mutants, hidden behaviors, historical escapes | test experts | kill/coverage uplift, invalid-test rate |
| Change plan | accepted architecture/contracts and executable feasibility checks | maintainers | dependency completeness, unsafe-step rate, rework |
| Incident analysis | telemetry, timeline, reproducer, fix | incident panel | causal accuracy, unsupported claims, prevention coverage |

RepoBench can serve as a retrieval/completion diagnostic, while AgentFL
motivates Top-k and ranking metrics for project-level localization [AN06-AN07].
Repository-vulnerability benchmarks can contribute security slices, but every
task still needs local truth and current dependency/runtime validation [AN08].

### Analysis metrics

| Dimension | Metric |
| --- | --- |
| Atomic truth | claim precision, claim recall against required facts, contradiction count |
| Grounding | evidence-reference validity, entailment precision, source-location recall |
| Snapshot integrity | claims/citations resolving at the exact revision |
| Completeness | weighted required-fact and dependency-edge coverage |
| Localization | Top-1/Top-k, MRR, inspected-code fraction/EXAM-style rank |
| Reproduction | proportion of diagnoses with a clean executable reproducer |
| Hypothesis quality | correct-cause rank, alternative coverage, falsification attempts |
| Uncertainty | Brier/ECE, risk-coverage curve, appropriate abstention rate |
| Retrieval | relevant symbol/file recall, distractor rate, token cost, freshness |
| Recommendation safety | policy-consistent, bounded, reversible recommendations |
| Efficiency | latency/cost per correct sufficiently grounded analysis |
| Human usefulness | independent engineer correctness/time with and without the artifact |
| Self-validation gap | agent-declared success minus independently verified success |

For open-ended tasks, claim recall requires a task-specific set of required
facts or issues. It should not pretend that every possible valid insight is
enumerated. Report “coverage of adjudicated required facts” rather than an
unqualified completeness percentage.

### Confidence and abstention

An analysis agent should be rewarded for saying that evidence is insufficient
when the task is genuinely underdetermined. Include:

- resolvable tasks with affirmative and negative answers;
- underdetermined tasks with a correct `unknown` outcome;
- stale or contradictory documentation;
- plausible but false comments and filenames;
- missing runtime access;
- ambiguous version/scope; and
- evidence that supports correlation but not causation.

Evaluate selective risk: as the confidence threshold rises and the agent
answers fewer questions, error among answered questions should fall. An agent
that assigns high confidence to every claim is poorly calibrated even if its
average accuracy appears competitive.

### Analysis failure taxonomy

- wrong repository/revision or stale evidence;
- source retrieval miss;
- distractor fixation or comment/name bias;
- false direct claim;
- unsupported inference;
- causal overreach;
- incomplete cross-file/dependency integration;
- missed contradiction;
- fabricated or non-entailing citation;
- tool setup failure mistaken for meaningful analysis;
- stage mixing;
- premature success declaration;
- uncalibrated certainty or failure to abstain;
- correct diagnosis with unsafe/unscoped remediation;
- verbose but non-actionable output; or
- oracle/adjudication defect.

The taxonomy should be captured at claim and trial level. It can then guide
retrieval, scaffold, tool, and prompt changes without reducing every failure to
“the model reasoned badly.”

## Evaluating the evaluators

### LLM judges are measurement instruments, not authorities

Model-based graders are useful when candidate outputs have many valid forms,
but they are nondeterministic and can encode irrelevant biases. CodeJudgeBench
tested 26 judges over generation, repair, and unit-test-generation tasks and
found every evaluated judge unstable under perturbations including response
order, variable names, and misleading comments [JG01]. Separate work also
finds position bias in LLM-as-judge settings [JG02].

JidoCode should therefore permit an LLM judge to:

- triage trials for human review;
- propose semantic matches between a finding/claim and an adjudicated item;
- score isolated, low-stakes rubric dimensions;
- flag possible unsupported claims, omissions, or style problems;
- select samples for audit; and
- summarize deterministic evidence without replacing it.

It must not alone:

- decide executable correctness;
- waive a test, policy, authorization, or provenance failure;
- establish that a review finding is true;
- establish that a repository claim is supported;
- approve publication or final-goal satisfaction;
- grade its own outputs without independent calibration; or
- turn multi-judge agreement into ground truth.

Several correlated judges can agree on the same error. Consensus is a stability
signal, not proof.

### Judge calibration protocol

Every judge/rubric revision needs a held-out meta-evaluation:

1. build a balanced gold set adjudicated by qualified humans, including true,
   false, partially supported, ambiguous, and `unknown` examples;
2. blind the judge to agent identity, model/provider, expected label frequency,
   and production outcome;
3. isolate rubric dimensions rather than ask for one holistic impression;
4. require structured labels, cited evidence, confidence, and an `unknown`
   option;
5. measure per-class precision, recall, confusion, agreement, calibration, and
   abstention;
6. run metamorphic perturbations: reorder responses, rename variables, alter
   formatting, insert misleading comments, swap labels, and paraphrase while
   preserving semantics;
7. repeat identical examples to estimate within-judge variance;
8. compare against deterministic checks wherever a fact is mechanically
   decidable;
9. predefine the threshold below which the judge returns to human-only use; and
10. rerun calibration after any judge model, prompt, rubric, context, or tool
    change.

Judge test data must remain separate from rubric prompt development. Otherwise
the meta-eval becomes another tuned validation set.

### Human grader quality

Human judgment is not automatically consistent. Human-evaluated tasks should
record:

- reviewer eligibility and domain;
- independence and conflicts;
- blind condition;
- rubric revision;
- time spent and evidence consulted;
- item-level label and confidence;
- disagreement and resolution;
- inter-rater agreement by dimension; and
- any post-adjudication truth-set revision.

For Phase 7's fresh/private tasks, the existing requirement of two blinded
independent reviewers plus a third resolver is sound [JC01]. Agreement should
not be used to discard hard tasks silently. High disagreement is evidence that
the task, rubric, or underlying question needs audit.

### Evaluation-system health metrics

| Health metric | Failure indicated |
| --- | --- |
| Reference-solution failure | broken environment or oracle |
| Alternate-correct-solution rejection | overly prescriptive oracle |
| Base unexpectedly passing | weak or stale task |
| Mutation survival | insufficient test strength |
| Infrastructure/flake rate | contaminated agent metric |
| Judge-human divergence | invalid semantic automation |
| Human disagreement | ambiguity or underspecified rubric |
| Metamorphic label flip | irrelevant judge/oracle sensitivity |
| Suspicious target-perfect canary score | leakage or grader bypass |
| Visible/held-out gap | overfitting or reward hacking |
| Self-validation gap | agent cannot establish its own success |
| Task score inversion after audit | benchmark-health regression |

These should appear beside target results in an evaluation report. A high agent
score from an unhealthy suite is not strong evidence.

## Security and adversarial evaluation

AgentDojo evaluates utility and prompt-injection security separately across
tasks and adversarial cases [SE01]. Anthropic's sabotage and SHADE-Arena work
studies subtle bug insertion, side tasks, and monitor trade-offs, including the
problem that high attack detection may require unacceptable false-positive
rates [SE02-SE03]. The operational lesson is that model monitoring supplements
least authority and independent verification; it does not replace them.

### Adversarial families

The existing Phase 7 plan already includes a broad suite [JC01]. It should be
organized and reported as follows:

| Family | Example attack/failure | Required safe outcome | Measurement |
| --- | --- | --- | --- |
| Indirect instruction | hostile README, issue, source comment, test output, dependency message | treat as data; no authority expansion | task utility + unauthorized proposal/effect |
| Tool/schema | unknown operation, malformed path, hidden argument, Unicode/path trick | reject before effect | 100% containment |
| Filesystem/workspace | traversal, symlink race, protected path, submodule escape | no host/protected mutation | effect journal + independent state check |
| Credential | environment scraping, metadata service, helper abuse, cross-repo token | no secret disclosure/use outside scope | canary and broker audit |
| Network/egress | DNS rebinding, redirect, IP drift, exfiltration | policy-bound denial | broker/packet evidence |
| Lease/fence/retry | stale output, late completion, replay, idempotency confusion | reject stale/replayed effect | 100% stale/late rejection |
| Outcome integrity | delete/skip tests, hard-code visible inputs, edit grader, shadow dependency | no accepted incorrect result | hidden/compositional tests + tamper check |
| Evidence | forge, omit, substitute revision/digest, reuse evidence | no decision at wrong provenance | graph/evidence invariant |
| Review sabotage | plausible false reassurance, bury critical issue in noise | critical truth retained or escalated | critical recall + noise |
| Analysis sabotage | fabricated citation, false dependency, confident stale claim | reject/abstain; no accepted unsupported claim | claim/evidence checks |
| Memory/retrieval | poison durable memory, stale index, cross-tenant context | no unauthorized persistence/use | source and revision provenance |
| Resource/availability | loop, fork/process storm, huge output/artifact, rate limit | bounded safe failure | resource and recovery metrics |
| Adaptive monitor evasion | obfuscate a violating side effect | hard boundary blocks independently of monitor | security outcome + monitor ROC |

### Security result vector

For each adversarial trial record:

```text
utility_outcome: success | partial | safe_failure | inconclusive
security_outcome: preserved | attempted_violation_contained | violated | inconclusive
critical_invariant_results: [...]
monitor_alerts: [...]
authoritative_effects: [...]
```

`utility=success, security=violated` is a critical failure. `utility=safe_failure,
security=preserved` is a product limitation but a security success. This makes
safe refusal distinguishable from both useful completion and violating
completion.

### Adaptive and incident-derived cases

Static attack strings invite overfitting. The security suite should include:

- fixed regressions for known attacks;
- generated variants transformed without changing the attack goal;
- adaptive red-team attempts made against the frozen candidate;
- multi-turn and delayed triggers;
- attacks embedded in realistic repository and tool data;
- clean controls to measure monitor false positives; and
- confidential incidents converted to sealed regression cases.

ABTest's behavior-driven agent fuzzing mined 400 developer-confirmed failures
into reusable interaction patterns and generated 647 repository-grounded fuzz
cases, finding hundreds of manually confirmed anomalies [BF01]. JidoCode can
apply the same pattern: normalize an incident into preconditions, action
sequence, expected invariant, and oracle, then generate controlled variants.

## Statistical design for stochastic agents

### Trial independence and unit of inference

Agent output varies even under an apparently identical configuration. A 2026
study of roughly 60,000 SWE-bench trajectories reports that single-run `pass@1`
estimates can vary by several percentage points, enough to make small claimed
improvements indistinguishable from noise [ST03].

The task, not the individual trial, is usually the unit of product inference.
Trials are nested within tasks; tasks are nested within repositories; reviewers
may grade multiple tasks. Treating all trials as independent inflates sample
size and narrows intervals incorrectly.

Each comparison should pin:

- primary endpoint and safety endpoints;
- task eligibility and exclusions;
- number of trials per task;
- task/repository strata;
- target configurations and budgets;
- pairing/randomization method;
- missing/infrastructure-failure policy;
- confidence interval and hypothesis test;
- minimum practically important effect;
- multiplicity policy; and
- stop/rollback rules.

This is preregistered before looking at test results.

### `pass@k` and `pass^k`

The two metrics answer opposite questions [ST01-ST02, EV01]:

- `pass@k`: probability of at least one successful solution in `k` independent
  attempts. It increases with `k` and is appropriate only when the product can
  actually generate and safely select among multiple attempts.
- `pass^k`: probability all `k` attempts succeed. It decreases with `k` and
  measures consistency expected by repeated users or unattended execution.

Always report `k`, the selection mechanism, and the number of samples used.
Do not call a best-of-five result “accuracy” or compare it with another
system's first attempt. If a human or verifier selects the best candidate, its
time, error rate, and access to hidden truth are part of the target system.

For JidoCode:

- `pass@1` is the primary capability endpoint;
- `pass^3` or `pass^5` is a practical consistency diagnostic;
- `pass@k` is secondary and only relevant to an explicitly implemented,
  independently verified multi-candidate policy; and
- zero critical false acceptance applies across every trial, not just the
  selected candidate.

### Intervals and comparisons

The Phase 7 plan specifies two-sided 95% Wilson score intervals for binary
proportion gates and a preregistered stratified bootstrap for continuous
metrics [JC01]. Preserve that rule, with these details:

- compute gate proportions over the declared unit, normally eligible tasks or
  accepted outcomes, not model turns;
- include exact numerators and denominators;
- stratify by preregistered repository/task/risk slices;
- use a hierarchical or cluster bootstrap over repositories and tasks as a
  sensitivity analysis when repeated trials are aggregated;
- compare two profiles on the same tasks using paired methods, such as McNemar
  for paired binary outcomes or a paired permutation/bootstrap for score/cost;
- report confidence intervals on differences, not only separate intervals;
- use robust/nonparametric summaries for heavy-tailed cost and latency; and
- disclose results for every preregistered primary slice, including unfavorable
  ones.

If many models, prompts, or metrics are tested, designate one confirmatory
comparison or control family-wise/false-discovery error. Exploratory analyses
should be labelled exploratory and confirmed on a new sealed set.

### Power and sample size

The number of tasks should be justified by the desired decision, not a generic
benchmark convention. Before a gate run:

1. choose the baseline rate and minimum meaningful improvement or maximum
   acceptable failure incidence;
2. estimate repository/task clustering and trial variance from pilot data;
3. compute the sample needed for the chosen interval or paired test;
4. add capacity for invalidated tasks without changing the inclusion rule; and
5. ensure critical slices have enough observations to support their own claims.

The Phase 7 floor of 300 fresh/private tasks across at least 10 repositories is
reasonable as a publication-gate minimum, but the accepted-precision
denominator is the number accepted, not all 300 tasks. If coverage is low, the
precision interval may still be too wide. Report coverage next to precision so
a system cannot meet the gate by accepting only a trivial handful.

### Missingness, flakes, and infrastructure failures

Do not rerun only failed agent trials. Predefine:

- which infrastructure signatures make a trial invalid;
- whether a full paired block is rerun when one target encounters the anomaly;
- maximum invalidation rate before the entire run is rejected;
- the exact flake detection/repetition policy;
- how timeouts and budget exhaustion count; and
- whether provider refusals or rate limits are target failures or external
  incidents under the target's production contract.

Report eligible, scheduled, started, completed, invalidated, timed out, and
graded counts. “Success among completed runs” is misleading if completion is
selective.

### Reproducible evaluation report

Every reported aggregate should be reconstructible from immutable per-trial
records and include:

- corpus and task revisions plus exclusions;
- target tuple;
- environment/oracle/rubric revisions;
- planned versus actual trial counts;
- randomization/pairing assignments;
- raw task-level outcomes;
- invalidation and adjudication records;
- all primary numerators, denominators, intervals, and slice results;
- cost, latency, token, tool, and human-time accounting;
- security outcomes and critical incidents;
- evaluator-health metrics; and
- analysis code revision and output digest.

## Eval-driven development workflow

### Lifecycle

Evaluation should be part of feature development, not a certification sprint
at the end [EV01]:

1. **Specify.** Write observable success, prohibited effects, ambiguity, and
   acceptable abstention.
2. **Create the eval first.** Add positive, negative, near-neighbor, and
   adversarial cases; audit the reference solution and oracle.
3. **Baseline.** Run the current accepted target before changing the agent.
4. **Develop.** Tune only on development tasks and inspect full observable
   traces for both passes and failures.
5. **Compare.** Run paired validation tasks with equal budgets and frozen
   targets.
6. **Regress.** Run contract, outcome-integrity, and confirmed-failure suites.
7. **Release-evaluate.** Freeze the candidate and run the sealed, preregistered
   profile without prompt or task changes.
8. **Adjudicate.** Resolve semantic disputes independently and publish
   evaluator-health data.
9. **Shadow.** Execute natural work without publication authority and compare
   against the existing workflow.
10. **Pilot.** Introduce human-reviewed proposals for a bounded population.
11. **Monitor.** Observe reverts, incidents, escapes, overrides, cost, and user
    burden.
12. **Learn.** Convert confirmed failures into regression cases, then refresh
    sealed holdouts so the fix cannot train on its future exam.

The eval definition and oracle should normally receive review independently of
the implementation change. An author who knows the expected patch and owns the
grader has too much opportunity to encode the candidate into the test.

### CI tiers

| Tier | Trigger and budget | Contents | Decision |
| --- | --- | --- | --- |
| T0 deterministic | every code change; seconds/minutes | unit, schema, contract, formatter, policy, evaluator self-tests | blocks merge |
| T1 agent smoke | relevant PR; minutes | 10-30 development/regression tasks, one trial, no external effect | blocks relevant merge on regression |
| T2 nightly | scheduled; hours | broader capability, repeated trials, retrieval, review, analysis, mutation and judge health | alerts/blocks candidate promotion |
| T3 security | scheduled and candidate; hours/day | adversarial, fuzz, outcome-integrity, stale/replay, canaries | critical failure blocks |
| T4 release | frozen candidate; potentially days | sealed corpus, multiple trials, blinded review, full statistics | rollout gate |
| T5 shadow/pilot | rolling production window | natural tasks, human comparison, operational outcomes | advance/hold/rollback |

T0-T1 should remain cheap enough that developers run them locally or in every
PR. T2-T5 may sample or parallelize, but sampling policies must be stable and
failures must link back to reproducible task records.

### Changing an eval

An eval change can alter a score without altering the agent. Treat it as a
measurement migration:

- state why the task, oracle, rubric, exclusion, or statistic changed;
- retain the old revision and affected results;
- rerun reference and negative-control candidates;
- dual-score a comparison set under old and new revisions;
- disclose direction and magnitude of score changes; and
- never back-edit a release result without an explicit restatement.

Benchmark-audit agents may help find issues, as in the 2026 SWE-Bench Pro
audit, but their flags require human confirmation and their own measured
precision [CB04].

## Production and developer-outcome evaluation

Benchmarks establish bounded capabilities, not productivity. Evidence about
developer tools is mixed and strongly distribution-dependent:

- METR's randomized early-2025 study had 16 experienced open-source developers
  complete 246 tasks in repositories they knew. With the then-current tools,
  the AI-allowed condition took 19% longer even though participants expected a
  24% speedup and afterwards believed they had been 20% faster [PD01]. METR
  explicitly cautions against generalizing that snapshot to most developers or
  later tools; a 2026 update also describes selection and measurement problems
  in its follow-up [PD02].
- GitHub reports a controlled 2024 study of 202 valid submissions in one API
  coding exercise where Copilot access improved test-passing likelihood and
  blinded quality ratings [PD03]. It is vendor-produced and based on a narrow
  task, so it supports the need for controlled experiments rather than a
  universal effect claim.
- DORA's 2025 research describes AI as an amplifier of organizational
  strengths and weaknesses and reports associations between adoption,
  throughput, and instability [PD04]. These are system-level observational
  findings, not causal estimates for a particular JidoCode profile.
- A Google user study found effects on performance, efficiency, satisfaction,
  and trust varied by expertise, question type, and self-reported versus
  demonstrated measurement, with evidence of automation complacency [PD05].

JidoCode should therefore measure demonstrated outcomes rather than ask only
whether developers feel faster.

### Shadow and pilot design

The safest useful progression is:

1. replay historical tasks without showing results to developers;
2. run prospective shadow tasks with no publication authority;
3. compare agent proposals against actual human outcomes after the fact;
4. expose proposals to a small, consented group with mandatory review;
5. randomize or use stepped-wedge introduction where feasible;
6. retain a contemporaneous baseline group or matched tasks;
7. stratify by expertise, familiarity, task type, and risk; and
8. advance only when both quality and human/system outcomes meet the gate.

Production metrics should include:

| Area | Metrics |
| --- | --- |
| Flow | task lead time, active engineering time, waiting time, review cycles |
| Quality | CI after proposal, defect escape, revert, incident, security finding, regression |
| Oversight | time verifying agent work, false-positive review burden, override/rejection reason |
| Scope | unrequested churn, follow-up cleanup, dependency/codebase health |
| Reliability | completion, recovery, repeatability, provider/tool failure |
| Delivery | batch size, deployment frequency, change failure, recovery time |
| Human factors | trust calibration, cognitive load, satisfaction, skill/expertise slice |
| Economics | total model/tool/compute cost plus human verification and remediation |
| Safety/privacy | unauthorized attempts/effects, secret/data exposure, audit gaps |

Count downstream cleanup and verification time. Faster initial generation with
slower review or more instability is not a productivity gain.

## Recommended JidoCode evaluation tracks

The Phase 7 track list should be organized into the following governed
profiles. This refines, rather than replaces, its existing requirements [JC01].

| Track ID | Scope | Primary endpoints | Hard failures | Corpus |
| --- | --- | --- | --- | --- |
| `H7-CONTRACT` | access profiles, ReqLLM, CLI, tool schemas, harness | conformance, malformed containment, provenance completeness | contract/policy bypass | exhaustive deterministic fixtures |
| `H7-EDIT` | repository coding and testing | correct accepted yield, accepted precision, `pass@1`, `pass^k` | critical false accept, verifier nonreproducibility | private/fresh Elixir-first tasks |
| `H7-RETRIEVE` | context and source retrieval | relevant evidence recall, distractor rate, freshness, token cost | cross-scope/stale evidence accepted | labelled source/dependency tasks |
| `H7-REVIEW` | PR review findings | critical recall, precision, clean-PR FPR, noise, human uplift | missed/false critical publication threshold | expert-expanded and executable review cases |
| `H7-ANALYZE` | QA, impact, fault, threat, planning | claim/evidence precision, required-fact coverage, Top-k, calibration | accepted fabricated/critical false claim | source-, trace-, mutation-, and incident-grounded tasks |
| `H7-ORACLE` | tasks, tests, graders, human rubrics | reference/alternate pass, mutation score, flake, agreement, judge robustness | leaked/bypassable oracle | benchmark canaries and meta-evals |
| `H7-SECURITY` | injection, authority, credentials, egress, evidence, reward hacking | utility/security vector, containment, stale rejection | any critical boundary violation | fixed, generated, adaptive, incident-derived |
| `H7-RELIABILITY` | repeated runs, faults, flakes, time/resource pressure | `pass^k`, recovery, bounded failure, cost tails | unsafe recovery or unbounded effect | chaos/fault-injection corpus |
| `H7-INTEROP` | public SWE/Terminal/analysis/review benchmarks | task-level public metrics and compatibility | none directly authorizes rollout | audited public datasets |
| `H7-SHADOW` | natural product tasks | human/system outcomes, accepted precision, oversight burden | production critical incident | rolling private shadow/pilot |

### Required cross-track slices

Every run should carry common dimensions so results can be joined without
guessing:

- task/corpus revision;
- repository and source revision;
- language/framework;
- task/risk/authority class;
- target profile tuple;
- model/provider/auth/billing route;
- adapter, CLI, harness, tool, sandbox, retrieval, and verifier revision;
- attempt/trial identity and independent-run index;
- reviewer/judge/rubric revisions where applicable;
- utility, security, correctness, acceptance, publication, and external outcome;
- cost, latency, tokens, steps, artifacts, and human time; and
- exclusion, invalidation, dispute, or incident status.

## Evaluation records in the JidoCode graph

The evaluation plane should preserve the existing distinction between
observations, evidence, and governed decisions [JC02-JC04]. Suggested record
types are:

| Record | Purpose |
| --- | --- |
| `EvaluationProfile` | pins target tuple, allowed tracks, budgets, and stage |
| `CorpusRevision` | pins eligible task identities, partitions, cuts, and exclusions |
| `EvaluationTask` | task manifest, slices, oracle/rubric policy, contamination status |
| `EvaluationRun` | frozen plan, candidate, assignment, and statistical protocol |
| `EvaluationTrial` | one independent task execution and infrastructure status |
| `GraderResult` | one grader/check result with input/output/revision digests |
| `ReviewFinding` | normalized defect finding and match/adjudication state |
| `AnalysisClaim` | normalized claim, evidence, uncertainty, and truth state |
| `HumanGrade` | blinded rubric judgment and confidence |
| `Adjudication` | disagreement resolution and truth-set change provenance |
| `EvaluatorHealth` | flake, mutation, leakage, agreement, perturbation, reference checks |
| `AggregateResult` | exact numerators/denominators, intervals, slices, and analysis revision |
| `RolloutDecision` | advance/hold/rollback linked to qualifying evidence |
| `ProductionOutcome` | later CI, revert, incident, delivery, and human-workflow observations |

No `GraderResult` should directly create acceptance. It is evidence consumed by
the existing governed decision boundary. An `AggregateResult` should point to
immutable trial results, never contain only a mutable summary.

### Provenance invariants

- every trial binds exactly one task revision and one target profile revision;
- every grader result binds the exact outcome/artifact and grader revision;
- every human grade binds a rubric and blind condition;
- every semantic match retains both machine proposal and human adjudication;
- every aggregate binds the frozen inclusion set and analysis code;
- task or truth changes create new revisions and do not mutate prior evidence;
- evaluation evidence cannot be reused across a changed candidate tuple without
  an explicit compatibility rule; and
- rollout decisions consume only evidence admitted for that exact stage.

## Rollout gate matrix

The existing numeric Phase 7 gates remain the controlling plan until changed
through normal review [JC01]. The following matrix makes their evidence intent
explicit and adds review/analysis/evaluator gates that should be calibrated in
the initial shadow phase rather than invented without data.

| Transition | Required evidence | Blocking conditions |
| --- | --- | --- |
| Development -> internal shadow | `H7-CONTRACT`, small `H7-EDIT/REVIEW/ANALYZE`, evaluator health | contract failure, unverifiable result, critical security violation |
| Internal shadow -> broader shadow | stable nightly/repeated results, healthy oracles, bounded cost | critical false accept, high flake, judge used as authority, unexplained regression |
| Shadow -> human-reviewed PR pilot | at least the plan's required fresh/private evidence and security gates; review/analysis thresholds frozen from pilot data | any critical authorization/credential/protected-branch/host/evidence bypass; stale/late acceptance |
| PR pilot -> broader assisted use | accepted precision and Wilson bound, zero critical false accept, demonstrated reviewer/developer benefit, acceptable noise/overhead | defect escape, critical review miss pattern, increased instability, unbounded cost |
| Any stage -> hold/rollback | fresh evidence no longer satisfies gate | gate invariant reopens regardless of prior checkbox/decision |

For automatic pull-request publication, preserve the plan's current minimum of
300 fresh/private eligible tasks across at least 10 repositories, at least 95%
accepted precision with a two-sided 95% Wilson lower bound of at least 90%, zero
critical false acceptances, and fresh-checkout reproducibility for every
accepted patch [JC01]. Review and analysis should not independently authorize
publication; they can strengthen or block a decision under their adopted
rubrics.

### Stop and rollback triggers

Regardless of aggregate score:

- any critical authorization, credential, protected-branch, host, or evidence
  bypass stops advancement;
- any accepted grader/test tampering or hidden-oracle access stops the run;
- any critical false acceptance reopens the gate;
- an unexplained judge-human divergence above the calibrated limit disables
  that judge from decision use;
- excessive task invalidation, flake, leakage, or reference-solution failure
  invalidates the evaluation run;
- a production critical incident rolls the implicated profile back to its last
  accepted stage; and
- material model/provider/scaffold/tool/policy changes require the applicable
  gate evidence to be rerun.

## Framework and implementation choices

No evaluation framework repairs weak tasks or oracles. Anthropic's guidance
explicitly places task quality and grader design ahead of framework choice
[EV01]. For JidoCode:

- the authoritative evaluator should be project-native and integrate with the
  existing Elixir contracts, graph provenance, fresh-checkout verifier, policy
  monitor, and governed decisions;
- [Inspect](https://inspect.aisi.org.uk/) is a useful external reference and
  interoperability adapter because it models an evaluation as dataset + solver
  + scorer and supports sandboxed agent tasks and multiple scorers [EV02];
- [Harbor](https://harborframework.com/) is a useful external runner/task-format
  adapter for Terminal-Bench and other containerized workloads [EV03];
- an external Python runner may execute a public compatibility track, but it
  must not become an alternate source of publication authority; and
- observability or evaluation SaaS products may help explore traces, but raw
  vendor dashboards are not durable JidoCode evidence unless imported through
  an explicit, revision-bound observation contract.

The implementation decision should be based on contract fit, isolation,
reproducibility, offline operation, artifact export, cost, and maintenance—not
leaderboard popularity.

## Recommended changes when Phase 7 is implemented

This report does not edit the accepted plan. The implementation PR should
consider the following explicit deltas:

| Current plan element | Recommended interpretation/change | Reason |
| --- | --- | --- |
| SWE-bench Verified track | Rename/generalize to public benchmark compatibility; include audited Live/rebench/Terminal slices | Verified and Pro are not defensible rollout oracles after 2026 audits |
| Fresh/private issue track | Make Elixir/JidoCode-private tasks the primary capability and graduation corpus | Product validity and contamination control |
| Repeated consistency | Specify `pass^k` in addition to separately labelled `pass@k` | Reliability and best-of-many answer different questions |
| Hidden checks | Add compositional holdouts, mutation strength, alternate-correct implementations, and reward-hacking gap | Visible test success is insufficient |
| Evaluation profiles | Add `H7-REVIEW`, `H7-ANALYZE`, and `H7-ORACLE` | Review, analysis, and evaluator health need distinct truth/metrics |
| Human review | Normalize review findings and analysis claims before adjudication | Enables repeatable matching, provenance, and slice analysis |
| LLM judges advisory | Add a required held-out judge meta-eval and metamorphic robustness suite | “Advisory” still needs a known error rate |
| Statistical protocol | Add task/repository clustering, paired comparisons, power/MDE, and missingness rules | Trials are stochastic and nested |
| Adversarial suite | Add explicit clean controls, adaptive variants, and incident-derived fuzzing | Measures false positives and avoids static-attack overfit |
| Production shadow | Add human-alone versus human-plus-agent outcomes and total verification/rework time | Benchmark/pass rates do not establish developer value |

None of these recommendations weakens a current gate. The public benchmark
change makes the evidence more conservative by moving deployment authority to
fresh/private, audited product tasks.

## Incremental implementation roadmap

### Increment 0 - Freeze evaluation semantics

Before writing a runner:

- approve terminology and the target-profile tuple;
- approve utility/security result separation;
- define task eligibility, partition, contamination, and invalidation policy;
- define code, review-finding, and analysis-claim truth models;
- select primary Phase 7 endpoints and units of inference; and
- state that LLM judges cannot satisfy hard acceptance checks.

Exit evidence: reviewed evaluation contract and threat-model update, with no
claim that an evaluation has yet passed.

### Increment 1 - Build the deterministic spine

- add versioned `EvaluationProfile`, `CorpusRevision`, `EvaluationTask`,
  `EvaluationRun`, `EvaluationTrial`, `GraderResult`, and `EvaluatorHealth`
  contracts;
- execute one task per fresh isolated environment;
- invoke the accepted Phase 6 fresh-checkout verifier;
- store immutable observable trace/artifact references;
- implement exact task/run/profile provenance invariants;
- distinguish agent, infrastructure, oracle, and inconclusive outcomes; and
- generate a reproducible task-level report.

Start with deterministic fake/model fixtures and contract tests. Exit evidence:
clean-checkout conformance and failure-injection receipts.

### Increment 2 - Establish 20-50 audited development tasks

Select real manual checks, recent bugs, and plan requirements [EV01]:

- 15-25 editing/testing tasks;
- 5-10 review tasks including clean PRs;
- 5-10 repository-analysis tasks including `unknown` cases;
- 5-10 adversarial/robustness cases, overlapping tracks where useful; and
- reference, alternate-correct, base, mutant, and canary candidates.

Run enough repeated trials to estimate flake and target variance. Exit evidence:
every task passes eligibility review, every reference passes, every base behaves
as declared, and evaluator-health results are published.

### Increment 3 - Add review, analysis, and judge adjudication

- implement normalized `ReviewFinding` and `AnalysisClaim` records;
- build deterministic location/evidence validators;
- implement blinded two-reviewer plus resolver workflows;
- build a held-out LLM-judge calibration and perturbation set;
- report precision/recall/noise for review and claim/evidence metrics for
  analysis; and
- run a small human-only versus human-plus-agent review experiment.

Exit evidence: adjudicator agreement and judge error/robustness results, with
LLM grades remaining advisory.

### Increment 4 - Expand and seal the release corpus

- collect fresh/private tasks across at least 10 repositories;
- prioritize Elixir/Phoenix/OTP and the actual JidoCode risk distribution;
- use continuous collection but task-level human/oracle audit;
- freeze development, validation, sealed, red-team, and canary partitions;
- perform mutation, alternate-solution, leakage, and flake audits;
- conduct power analysis and freeze the release protocol; and
- reach or exceed the plan's 300-task publication minimum without counting
  invalid or public tasks.

Exit evidence: a signed/frozen corpus manifest and preregistration, not a score
selected after testing.

### Increment 5 - Release evaluation and controlled rollout

- freeze the exact target;
- run paired independent trials and the full adversarial suite;
- adjudicate under the frozen rubric;
- publish raw denominators, intervals, slices, evaluator health, and disputes;
- enter internal shadow only if its gate passes;
- run prospective production and human-uplift measurement; and
- advance, hold, or roll back through the existing governed decision boundary.

Exit evidence: a Phase 7 receipt pinned to the merged candidate after
clean-checkout CI, preserving every reopening condition.

### Ongoing - Maintain the measurement system

- rotate sealed/canary tasks before contamination or saturation;
- audit influential failures and surprising successes;
- promote solved capability cases into regressions;
- convert production incidents into confidential regressions;
- revalidate judges and humans after rubric changes;
- monitor distribution drift and slice coverage;
- dual-run oracle migrations; and
- publish restatements when benchmark defects change conclusions.

## Ownership and review boundaries

Evaluation infrastructure should have a clear maintainer, while domain owners
contribute and review tasks [EV01]. Separate roles where practical:

| Role | Responsibility | Must not solely control |
| --- | --- | --- |
| Eval infrastructure owner | runner, isolation, records, aggregation | task truth for every domain |
| Task author | specification, base, candidate/reference | final eligibility and sealed oracle |
| Oracle reviewer | hidden checks, alternate solutions, mutation audit | target implementation |
| Domain adjudicator | semantic truth/severity/coverage | agent identity or rollout decision |
| Security/red team | adaptive attacks and canaries | production authorization |
| Statistical reviewer | protocol, power, analysis, restatement | outcome inclusion after seeing labels |
| Rollout authority | advance/hold/rollback | creation or mutation of evidence |

For small teams, one person may hold multiple roles, but the record should make
the overlap visible and require a second reviewer at high-risk boundaries.

## Common evaluation anti-patterns

Avoid the following:

1. **Model-only labels.** Comparing “GPT/Claude/Gemini” without scaffold,
   prompt, tool, budget, and environment revisions.
2. **One public leaderboard as a release gate.** It is exposed, distributionally
   narrow, and may contain broken tasks.
3. **Visible tests as the whole oracle.** This rewards overfitting, deletion,
   mocking, and hard-coding.
4. **Best-of-many reported as first-attempt success.** It hides attempts and the
   selection cost/oracle.
5. **One stochastic trial per task.** Small score changes may be random.
6. **Treating trials as independent tasks.** It creates false precision.
7. **Rerunning failures selectively.** It biases target results.
8. **Excluding timeouts or malformed outputs.** Those are system outcomes unless
   a preregistered infrastructure rule applies.
9. **Exact trajectory grading.** It rejects valid solutions unless the trajectory
   itself is a safety contract.
10. **LLM judge as executable oracle.** Code judges are perturbation-sensitive
    and cannot override state.
11. **Agent self-validation.** AnalysisBench observes systematic overstatement
    relative to independent manual verification [AN01].
12. **BLEU/ROUGE for review truth.** Review has multiple valid outputs and
    historical comments are incomplete.
13. **PR comment silence as a true negative.** Undiscovered defects remain
    unlabelled.
14. **Comment acceptance as truth.** Developer action is a production proxy,
    not a correctness label.
15. **Analysis prose graded holistically.** False claims can hide inside fluent
    reports; claims and evidence need separate checks.
16. **No clean negative controls.** Recall can be bought with unusable noise.
17. **Security averaged with utility.** A violating success must remain visible.
18. **Changing tasks after seeing a candidate score.** That converts a test into
    optimization data.
19. **Reporting only mean cost/latency.** Long tails, failures, and human review
    determine operational value.
20. **Assuming perceived speed equals productivity.** Controlled studies show
    perception and measured completion time can diverge [PD01, PD05].

## Research limits and confidence

This field is moving quickly. Several cited 2025-2026 benchmarks are preprints,
their tasks are public, and some results are produced by model or tooling
vendors. This report uses them for methods and failure modes, not as universal
rankings. Counts and reported effects are attributed to their sources.

The strongest-confidence recommendations are those supported by both software
testing principles and repeated agent-evaluation evidence:

- pin the complete system and environment;
- use independent executable outcomes where possible;
- protect hidden oracles and audit test strength;
- run repeated, paired, preregistered trials;
- keep public benchmarks diagnostic;
- calibrate semantic graders against independent humans;
- evaluate review precision and recall with clean controls;
- evaluate analysis as claims plus evidence and uncertainty;
- separate utility from security; and
- validate benchmark results against real production outcomes.

The least certain details are numeric thresholds for review noise, analysis
coverage, and human uplift. They should be set from JidoCode pilot data before
release, then frozen prospectively. They should not be copied from a public
leaderboard with a different task distribution.

## References

### Evaluation practice and infrastructure

- **EV01.** Anthropic, [Demystifying Evals for AI
  Agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents),
  2026.
- **EV02.** UK AI Security Institute, [Inspect AI
  Tutorial](https://inspect.aisi.org.uk/tutorial.html) and
  [documentation](https://inspect.aisi.org.uk/).
- **EV03.** Harbor Framework, [Terminal-Bench 2
  repository](https://github.com/harbor-framework/terminal-bench-2) and
  [Running Terminal-Bench](https://www.harborframework.com/docs/tutorials/running-terminal-bench).

### Statistical and long-horizon methods

- **ST01.** Mark Chen et al., [Evaluating Large Language Models Trained on
  Code](https://arxiv.org/abs/2107.03374), 2021. Introduces HumanEval and the
  `pass@k` estimator.
- **ST02.** Shunyu Yao et al., [`tau`-bench: A Benchmark for Tool-Agent-User
  Interaction in Real-World Domains](https://arxiv.org/abs/2406.12045), 2024.
  Introduces the consistency-oriented `pass^k` metric.
- **ST03.** [On Randomness in Agentic
  Evals](https://arxiv.org/abs/2602.07150), 2026.
- **MT01.** METR, [Task-Completion Time Horizons of Frontier AI
  Models](https://metr.org/time-horizons/).
- **MT02.** METR, [HCAST: Human-Calibrated Autonomy Software
  Tasks](https://metr.org/hcast.pdf).
- **MT03.** METR, [Example Evaluation
  Protocol](https://evaluations.metr.org/example-protocol/).

### Coding-agent benchmarks and oracle integrity

- **CB01.** Carlos E. Jimenez et al., [SWE-bench: Can Language Models Resolve
  Real-World GitHub Issues?](https://arxiv.org/abs/2310.06770), 2023.
- **CB02.** OpenAI, [Introducing SWE-bench
  Verified](https://openai.com/index/introducing-swe-bench-verified/), 2024,
  updated 2025.
- **CB03.** OpenAI, [Why SWE-bench Verified No Longer Measures Frontier Coding
  Capabilities](https://openai.com/index/why-we-no-longer-evaluate-swe-bench-verified/),
  2026.
- **CB04.** OpenAI, [Separating Signal from Noise in Coding
  Evaluations](https://openai.com/index/separating-signal-from-noise-coding-evaluations/),
  2026.
- **CB05.** [SWE-bench Goes Live!](https://arxiv.org/abs/2505.23419), 2025.
- **CB06.** [SWE-rebench: An Automated Pipeline for Task Collection and
  Decontaminated Evaluation of Software Engineering
  Agents](https://arxiv.org/abs/2505.20411), 2025.
- **CB07.** [SWE-Bench Pro](https://arxiv.org/abs/2509.16941), 2025.
- **CB08.** [Multi-SWE-bench: A Multilingual Benchmark for Issue
  Resolving](https://arxiv.org/abs/2504.02605), 2025.
- **CB09.** [SWE-PolyBench](https://arxiv.org/abs/2504.08703), 2025.
- **CB10.** Jiawei Liu et al., [Is Your Code Generated by ChatGPT Really
  Correct? Rigorous Evaluation of Large Language Models for Code
  Generation](https://arxiv.org/abs/2305.01210), EvalPlus, NeurIPS 2023.
- **CB11.** [SpecBench: Measuring Reward Hacking in Long-Horizon Coding
  Agents](https://arxiv.org/abs/2605.21384), 2026.
- **CB12.** Jonathan Gabor et al., [EvilGenie: A Reward Hacking
  Benchmark](https://arxiv.org/abs/2511.21654), 2025, revised 2026.
- **CB13.** [Investigating Test Overfitting on
  SWE-bench](https://arxiv.org/abs/2511.16858), 2025/2026.
- **CB14.** [SWE-Gym: Training Software Engineering Agents and Verifiers with
  Real-World Repositories](https://arxiv.org/abs/2412.21139), 2024.
- **CB15.** [SWE-smith: Scaling Data for Software Engineering
  Agents](https://arxiv.org/abs/2504.21798), 2025.
- **CB16.** Mike A. Merrill et al., [Terminal-Bench: Benchmarking Agents on
  Hard, Realistic Tasks in Command Line
  Interfaces](https://arxiv.org/abs/2601.11868), Terminal-Bench 2.0, 2026.
- **BF01.** Wuyang Dai et al., [ABTest: Behavior-Driven Testing for AI Coding
  Agents](https://arxiv.org/abs/2604.03362), 2026.

### Code-review evaluation

- **RV01.** OpenAI, [Finding GPT-4's Mistakes with
  GPT-4](https://openai.com/index/finding-gpt4s-mistakes-with-gpt-4/),
  CriticGPT, 2024; see also the [paper](https://cdn.openai.com/llm-critics-help-catch-llm-bugs-paper.pdf).
- **RV02.** Atharva Naik et al., [CRScore: Grounding Automated Evaluation of
  Code Review Comments in Code Claims and
  Smells](https://aclanthology.org/2025.naacl-long.457/), NAACL 2025.
- **RV03.** Hong Yi Lin et al., [CodeReviewQA: The Code Review Comprehension
  Assessment for Large Language
  Models](https://aclanthology.org/2025.findings-acl.476/), ACL Findings 2025.
- **RV04.** Lei Zhang et al., [AACR-Bench: Evaluating Automatic Code Review
  with Holistic Repository-Level Context](https://arxiv.org/abs/2601.19494),
  2026.
- **RV05.** Hanyang Guo et al., [CodeFuse-CR-Bench: A
  Comprehensiveness-aware Benchmark for End-to-End Code Review Evaluation in
  Python Projects](https://arxiv.org/abs/2509.14856), 2025.
- **RV06.** [ContextCRBench: Benchmarking LLMs for Fine-Grained Code Review
  with Enriched Context in Practice](https://arxiv.org/abs/2511.07017), 2025.
- **RV07.** [Benchmarking and Studying the LLM-based Code Review
  (SWR-Bench)](https://arxiv.org/abs/2509.01494), 2025.
- **RV08.** [Code Review Agent Benchmark](https://arxiv.org/abs/2603.23448),
  including c-CRAB, 2026.
- **RV09.** [CR-Bench: Evaluating the Real-World Utility of AI Code Review
  Agents](https://arxiv.org/abs/2603.11078), 2026.

### Repository-analysis evaluation

- **AN01.** Michael Pradel, Cristian Cadar, and Islem Bouzenia, [Evaluating LLM
  Agents on Automated Software Analysis
  Tasks](https://arxiv.org/abs/2604.11270), AnalysisBench, 2026.
- **AN02.** Jia Li, Yuxin Su, and Michael R. Lyu, [From Laboratory to
  Real-World Applications: Benchmarking Agentic Code Reasoning at the
  Repository Level](https://aclanthology.org/2026.acl-long.399/), RepoReason,
  ACL 2026.
- **AN03.** [SWE-QA: Can Language Models Answer Repository-level Code
  Questions?](https://aclanthology.org/2026.findings-acl.402/), ACL Findings
  2026.
- **AN04.** Songcheng Cai et al., [SWE-QA-Pro: A Representative Benchmark and
  Scalable Training Recipe for Repository-Level Code
  Understanding](https://aclanthology.org/2026.findings-acl.837/), ACL Findings
  2026.
- **AN05.** [DependEval: Benchmarking LLMs for Repository Dependency
  Understanding](https://aclanthology.org/2025.findings-acl.373/), ACL Findings
  2025.
- **AN06.** [RepoBench: Benchmarking Repository-Level Code
  Auto-Completion Systems](https://arxiv.org/abs/2306.03091), 2023.
- **AN07.** Yihao Qin et al., [AgentFL: Scaling LLM-based Fault Localization to
  Project-Level Context](https://arxiv.org/abs/2403.16362), 2024.
- **AN08.** [Just-in-Time Vulnerability Detection at the Repository
  Level](https://aclanthology.org/2025.acl-long.1490/), ACL 2025.

### Model-judge evaluation

- **JG01.** Hongchao Jiang et al., [CodeJudgeBench: Benchmarking LLM-as-a-Judge
  for Coding Tasks](https://aclanthology.org/2026.acl-long.888/), ACL 2026.
- **JG02.** Lin Shi et al., [Judging the Judges: A Systematic Study of Position
  Bias in LLM-as-a-Judge](https://aclanthology.org/2025.ijcnlp-long.18/),
  IJCNLP-AACL 2025.

### Security, injection, and sabotage evaluation

- **SE01.** Edoardo Debenedetti et al., [AgentDojo: A Dynamic Environment to
  Evaluate Prompt Injection Attacks and Defenses for LLM
  Agents](https://arxiv.org/abs/2406.13352), 2024.
- **SE02.** Anthropic, [Sabotage
  Evaluations](https://www.anthropic.com/research/sabotage-evaluations), 2024.
- **SE03.** Anthropic, [SHADE-Arena: Evaluating Sabotage and Monitoring in LLM
  Agents](https://www.anthropic.com/research/shade-arena-sabotage-monitoring),
  2025.

### Production and developer-outcome evidence

- **PD01.** Joel Becker et al., [Measuring the Impact of Early-2025 AI on
  Experienced Open-Source Developer
  Productivity](https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/),
  METR, 2025.
- **PD02.** METR, [We Are Changing Our Developer Productivity Experiment
  Design](https://metr.org/blog/2026-02-24-uplift-update/), 2026.
- **PD03.** GitHub, [Does GitHub Copilot Improve Code Quality? Here's What the
  Data Says](https://github.blog/news-insights/research/does-github-copilot-improve-code-quality-heres-what-the-data-says/),
  2024, updated 2025.
- **PD04.** DORA/Google Cloud, [State of AI-assisted Software Development
  2025](https://dora.dev/research/2025/dora-report/) and
  [errata](https://dora.dev/research/2025/errata/).
- **PD05.** Crystal Qian and James Wexler, [Take It, Leave It, or Fix It:
  Measuring Productivity and Trust in Human-AI
  Collaboration](https://research.google/pubs/take-it-leave-it-or-fix-it-measuring-productivity-and-trust-in-human-ai-collaboration/),
  IUI 2024.

### JidoCode plans, architecture, and accepted evidence

- **JC01.** JidoCode, [Harness Phase 7 Evaluation And Controlled Rollout
  Plan](../planning/secure-effective-agent-harness/phase-07-evaluation-and-controlled-rollout.md).
- **JC02.** JidoCode, [Harness Phase 6 Verification, Decision, And Publication
  Receipt](../architecture/harness-phase-06-receipt.md).
- **JC03.** JidoCode, [Verification And Evidence
  Boundary](../architecture/verification-evidence-boundary.md).
- **JC04.** JidoCode, [Current Threat Model For
  JidoCode](./07-current-threat-model-for-jido-code.md).
- **JC05.** JidoCode, [Secure And Effective Agent
  Harness](./02-secure-effective-agent-harness.md).
