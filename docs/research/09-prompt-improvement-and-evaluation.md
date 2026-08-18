## 9. Prompt Improvement And Evaluation

- Status: research baseline and implementation recommendation, not an accepted
  architecture decision, prompt release, evaluation result, rollout
  authorization, or phase receipt
- Research cutoff: 2026-08-18
- Accepted merged repository baseline inspected:
  `b2a64789ee2ccca4daf4b763aa984ed5528adaf4`
- Project scope: JidoCode prompt and context bundles used for code writing,
  code review, repository analysis, retrieval, verification, and controlled
  publication

## Executive conclusion

JidoCode should practice **evaluation-driven prompt development**, but it
should not treat a prompt as a magic string or optimize one headline score.
The operational object is a versioned prompt bundle:

> instruction hierarchy + task template + examples + rendering logic +
> context-selection policy + tool descriptions and schemas + output contract

That bundle only has meaning inside the complete evaluation target already
defined by the coding-agent evaluation research:

> model snapshot + inference parameters + harness + prompt bundle + tools +
> retrieval + memory + sandbox + budgets + repository snapshot + verifier

Changing any of those fields creates a different target. A claimed prompt
improvement is therefore a controlled comparison in which the prompt bundle is
the declared treatment and the other relevant fields are held fixed. If the
model, tools, context policy, and prompt all change, the result applies to a new
agent profile; it does not establish that the wording caused the improvement.

The evidence supports eight conclusions:

1. **Define success before editing prompts.** Turn expected behavior into
   executable checks, structured rubrics, negative cases, and safety
   invariants. Establish a baseline before optimization [PR01-PR04].
2. **Evaluate prompt distributions, not one lucky wording.** Semantically
   equivalent formats, paraphrases, demonstration orders, and minor user-input
   perturbations can materially alter both absolute scores and model rankings
   [PS01-PS08].
3. **Use the strongest available oracle.** End-state tests and deterministic
   checks outrank reference-string metrics; calibrated humans handle genuinely
   semantic judgments; model judges remain advisory and continuously
   meta-evaluated [EV01-EV10].
4. **Separate development, validation, and sealed test data.** Prompt authors
   and optimizers may learn from development failures. Candidate selection uses
   validation. Only a frozen candidate reaches the sealed release set.
5. **Treat automatic optimization as candidate generation.** APE, ProTeGi,
   OPRO, PromptBreeder, DSPy/MIPRO, GEPA, TextGrad, Bayesian selection, and
   newer multi-judge methods can search much larger spaces than manual editing,
   but they optimize the supplied data and grader—not the true product
   objective [AO01-AO11].
6. **Keep safety and authority as hard constraints.** Prompt injection,
   extraction, data disclosure, unauthorized tool effects, and evaluator
   tampering cannot be averaged away by higher task success [SE01-SE05].
7. **Measure production value through controlled rollout.** Offline success
   cannot establish causal effects on review burden, defect escape, developer
   time, or user outcomes. Shadow evaluation and randomized or otherwise
   defensible online comparisons close that gap [ON01-ON05].
8. **Learn continuously without contaminating the test.** Triage production
   failures, adjudicate their cause, add them to a development or confidential
   regression corpus, and periodically create a new sealed test revision.

For JidoCode, the immediate goal is not an autonomous prompt-rewriting service.
It is a reproducible prompt experiment lane inside the existing evaluation
catalog/run/evidence topology. Prompt optimizers may propose immutable
candidates. They may not read sealed truth, mutate production prompts, weaken
security controls, grade themselves authoritatively, or advance a rollout gate.

## Scope and research questions

This report answers seven questions:

1. What is a prompt when instructions are assembled dynamically around tools,
   retrieved context, repository policy, and conversation state?
2. Which prompt-improvement techniques have credible empirical support, and
   when do they fail to transfer?
3. What does “prompt success rate” mean for coding, review, and analysis
   agents?
4. How should prompt candidates be compared statistically under stochastic
   generation and prompt sensitivity?
5. How can automatic prompt optimizers be used without overfitting, leakage,
   reward hacking, or unsafe self-modification?
6. How should prompt changes move through local development, CI, sealed
   evaluation, shadow operation, and controlled rollout?
7. How should prompt revisions and their evidence fit JidoCode's existing
   evaluation graph and security boundaries?

The report covers discrete natural-language prompts and compound agent prompt
programs. It does not cover continuous/soft prompt tuning in model weights
except where the distinction matters. Fine-tuning, preference optimization,
and model training are adjacent techniques, not prompt revisions, and require
their own training-data and model-provenance controls.

The report does not recommend collecting private chain-of-thought. Research on
chain-of-thought, self-consistency, and reflection demonstrates useful
elicitation patterns on particular models and tasks [PI01-PI07]. JidoCode
should evaluate observable plans, tool calls, patches, tests, evidence,
structured claims, uncertainty, and end states. It should not make disclosure
or persistence of hidden reasoning a success criterion.

## Evidence standards and limits

The source set prioritizes peer-reviewed papers, official research pages, and
official platform documentation. Preprints are explicitly identified in the
references. Vendor engineering posts are valuable operational evidence but are
not independent validation of vendor product claims.

Reported percentage gains are study-specific. They depend on the model
generation, task distribution, prompt baseline, inference budget, and grader.
They establish that a method can work under studied conditions; they do not
establish a universal improvement for current JidoCode profiles.

The research area changes quickly. In particular:

- model families respond differently to the same instructions;
- hosted model aliases and default parameters may change;
- a technique that helped older completion models may be neutral or harmful on
  newer reasoning models;
- public benchmark and prompt exposure can contaminate later comparisons; and
- platform tooling can be deprecated independently of the underlying method.

OpenAI's current documentation, for example, recommends building evals before
iterating prompts and manually reviewing optimized prompts, but its
dataset-backed Evals platform and prompt optimizer are scheduled to become
read-only on 2026-10-31 and shut down on 2026-11-30 [PR01-PR03]. JidoCode
should adopt the method, not depend on that legacy platform.

## Terminology

| Term | Meaning in this report |
| --- | --- |
| Prompt source | Human-readable instruction/template material before rendering |
| Prompt component | One role message, policy block, example set, tool description, schema, or reusable partial |
| Prompt bundle | The immutable set of components and assembly rules proposed as one treatment |
| Prompt compiler | Code that selects, orders, escapes, truncates, and renders prompt components |
| Rendered prompt | The concrete provider request for one trial, including authorized dynamic inputs |
| Context policy | Rules selecting repository, retrieval, memory, and conversation material |
| Prompt candidate | One immutable bundle revision proposed for comparison |
| Prompt family | Candidates intended to implement the same behavioral specification |
| Semantic variant | A meaning-preserving paraphrase, format, order, or benign input perturbation |
| Development set | Optimizer-visible examples used for diagnosis and candidate generation |
| Validation set | Held-out examples used to select among candidates and tune stopping rules |
| Sealed test set | Custodian-controlled examples used once the candidate and analysis are frozen |
| Regression set | Previously solved and incident-derived cases expected to remain solved |
| Trial | One independent execution of one task by one fully pinned target |
| Grader | A deterministic, executable, model-based, or human check that measures an outcome |
| Meta-evaluation | Evaluation of the task, oracle, grader, judge, rubric, or experiment itself |

## The evaluation object is a prompt bundle

### Why the string is not enough

A coding agent rarely receives one static prompt. Its request may be assembled
from:

- system, developer, user, and tool-role messages;
- application and repository instructions;
- a task template populated with untrusted user text;
- examples chosen by task class or retrieval;
- tool names, descriptions, parameter schemas, and error contracts;
- relevant files, graph projections, previous tool results, and memory;
- output schemas and stop conditions;
- provider-specific wrappers or chat templates; and
- truncation, compaction, escaping, and ordering logic.

The same prompt source can therefore produce different behavior after a
renderer, context policy, tool schema, or provider wrapper changes. Conversely,
an apparent wording improvement may really come from better retrieval, a more
legible tool contract, additional inference budget, or a different model
snapshot.

For a prompt experiment, JidoCode should pin at least:

```text
prompt_treatment = {
  prompt_family_id,
  prompt_bundle_revision_and_digest,
  component_revision_digests,
  prompt_compiler_revision,
  role_and_precedence_policy_revision,
  demonstration_set_revision_and_digest,
  context_policy_revision,
  tool_schema_and_description_digests,
  output_schema_revision,
  rendering_and_escaping_policy_revision,
  truncation_and_compaction_policy_revision
}
```

The evaluation target additionally pins the model, inference parameters,
harness, access profile, tools, retrieval index, memory policy, sandbox,
repository revision, budgets, and verifier. Raw rendered prompts may contain
source code, secrets, user data, or sealed task material. Under JidoCode's
current security architecture, the graph should retain the minimum necessary
revision and content digests plus capability-gated artifact references, not
copy arbitrary rendered prompt bytes into broadly queryable literals.

### Prompt specification before implementation

Each prompt family should begin with a model-independent behavior contract:

```text
purpose:
eligible task classes:
required observable outcomes:
required evidence:
allowed tools and effects:
forbidden effects:
authority and conflict rules:
clarification and abstention rules:
output contract:
cost, latency, and step budgets:
primary metric:
safety and regression gates:
```

This contract prevents a common failure: rewriting prose until a few examples
look better without agreeing on what behavior should improve. It also lets
different prompt implementations compete against the same outcome contract.

### Prompt changes versus system changes

Classify each experiment before execution:

| Experiment mode | Declared treatment | Held fixed | Claim supported |
| --- | --- | --- | --- |
| Wording/structure | selected prompt-source components | compiler, examples, context, tools, model, budgets, tasks, graders | effect of those component edits for this target |
| Demonstration | example identities, content, or order | instructions, compiler, model, task assignments, graders | effect of the demonstration policy |
| Context policy | retrieval, compaction, or placement | core instructions, model, tools, tasks, graders | effect of context construction |
| Tool interface | tool names, descriptions, schemas, results | other target fields | effect of the agent-computer interface |
| Prompt program | several prompt modules or routing rules | model, environment, corpus, oracle | effect of the compound prompt program |
| Model migration | model snapshot/provider route | functionally equivalent prompt bundle first | model effect before model-specific retuning |
| End-to-end profile | several fields intentionally change | catalog, assignments, environment, oracle, analysis | performance of the new complete profile only |

One-change-at-a-time experiments provide attribution. End-to-end comparisons
provide deployment evidence. Both are useful, but they answer different
questions.

## What the research says about prompt sensitivity

Prompt sensitivity is not a minor cosmetic issue. It affects development,
benchmarking, candidate selection, and reproducibility:

| Evidence | Finding | Consequence for JidoCode |
| --- | --- | --- |
| Zhao et al., ICML 2021 [PS01] | Prompt format, examples, and example order moved few-shot accuracy from near chance to near state of the art in studied settings; contextual calibration improved accuracy by as much as 30 absolute points | Never infer capability from one few-shot arrangement; include content-free and class-balance checks where applicable |
| Lu et al., ACL 2022 [PS02] | Few-shot example order materially changed performance and good orders did not transfer reliably between models | Pin order; randomize or deliberately optimize only on development data; retest after model changes |
| Sclar et al., ICLR 2024 [PS03] | Meaning-preserving formatting changes produced a range as large as 76 accuracy points for LLaMA-2-13B; format performance correlated weakly across models | Treat formatting as a treatment and report a plausible-format distribution during robustness evaluation |
| Mizrahi et al., TACL 2024 [PS04] | Across 6.5 million instances, 20 models, and 39 tasks, absolute and relative results varied with instruction paraphrases | Use multi-prompt evaluation when characterizing general capability; do not rank profiles from one arbitrary template |
| PromptEval preprint [PS05] | Estimated prompt-performance quantiles across 100 MMLU templates with a budget comparable to two single-template evaluations | Use distribution estimation or staged fidelity when exhaustive prompt-by-task evaluation is too expensive |
| PromptRobust preprint [PS06] | Character-, word-, sentence-, and semantic-level perturbations degraded current models across multiple tasks | Add typo, paraphrase, delimiter, irrelevant-text, and benign-order metamorphic tests |
| BrittleBench preprint [PS07] | Semantics-preserving perturbations degraded results by up to 12%, changed relative model ranking in 63% of studied cases, and explained up to half of model variance | Report robustness and ranking stability, not only clean-set mean |
| Qin et al., ICML 2026 [PS08] | Prompt sensitivity varies with model properties and can be studied through interaction changes, rather than output differences alone | Revalidate every model/prompt pairing; do not maintain a universal “best prompt” |

These findings imply two distinct evaluation designs:

1. **Product optimization:** select a fixed operational bundle using
   development and validation data, then evaluate that frozen bundle on sealed
   tasks. The question is whether the shipped configuration works.
2. **Capability characterization:** evaluate a controlled distribution of
   plausible prompt variants. The question is whether a model or profile is
   generally robust rather than lucky under one template.

Mixing the designs is misleading. Selecting the best of hundreds of prompt
variants on a benchmark and reporting its score as general capability hides
selection effort and overfits the benchmark. Averaging arbitrary variants when
the product ships one deliberately engineered prompt understates the
operational configuration. JidoCode should label which question each result
answers.

## Prompt-improvement methods

### 1. Specification-first manual engineering

The strongest baseline is usually a clear, minimal instruction contract:

- state the outcome, scope, and audience;
- distinguish requirements from background context;
- express authority and instruction precedence;
- define what evidence is required before making a claim;
- enumerate allowed and prohibited effects;
- state when to ask, abstain, stop, or escalate;
- define the output schema only as tightly as consumers require;
- supply boundary examples for ambiguous behavior; and
- remove duplicated or conflicting instructions.

Delimiters, headings, and role separation improve legibility and make rendering
more testable. They are not security boundaries. Untrusted repository text can
still contain instructions, and a model can still follow them. Authorization,
egress, filesystem, publication, and secret controls remain enforced outside
the model [SE01-SE05].

The proper test is not “does the new prompt sound clearer?” It is a paired run
over a frozen task set plus an ablation or component diff that identifies which
behavior changed.

### 2. Demonstrations and in-context examples

Few-shot examples can teach:

- input/output shape;
- desired level of detail;
- tool-selection conventions;
- evidence and citation form;
- positive and negative decision boundaries; and
- recovery from malformed, ambiguous, or unsafe requests.

Examples should be correct, diverse, short enough to preserve relevant
context, and representative of production slices. Include both when a behavior
should happen and when it should not. Deduplicate examples against validation
and sealed tasks. Pin identities and order.

Example selection is itself a policy. Compare zero-shot, fixed few-shot,
retrieved few-shot, and class-routed few-shot profiles separately. Retrieved
examples add index revision, retrieval algorithm, eligibility rules, and
poisoning resistance to the target tuple.

### 3. Decomposition and planning

Chain-of-thought demonstrations improved arithmetic, commonsense, and symbolic
reasoning for sufficiently large models in the original study [PI01].
Plan-and-Solve separated planning from subproblem execution and reduced several
error classes in studied zero-shot reasoning tasks [PI04]. ReAct interleaved
reasoning with actions and external observations, improving interactive
benchmarks and grounding factual tasks in retrieved evidence [PI03].

For JidoCode, the transferable design principle is **observable
decomposition**, not mandatory disclosure of hidden reasoning:

```text
understand contract
  -> inspect authorized evidence
  -> propose bounded plan when useful
  -> act through typed tools
  -> observe actual results
  -> verify independent outcomes
  -> report claims with evidence and uncertainty
```

Evaluate whether the decomposition improves final correctness, appropriate
tool use, recovery, and cost. A longer plan is not intrinsically better.
Over-planning can increase latency, compound errors, and create more injection
surface.

### 4. Sampling and selection

Self-consistency samples multiple reasoning paths and selects the most
consistent answer; the original paper reported large gains on several
reasoning benchmarks [PI02]. For agentic work, multiple candidates can help
only when JidoCode can safely and independently select the best outcome.

The selection mechanism is part of the system:

- majority voting fits unique, normalized answers;
- executable verification fits code and state changes;
- constraint checking fits structured outputs;
- calibrated judges may assist genuinely semantic selection; and
- human choice may be appropriate for high-value, low-volume work.

Generating five candidates and using hidden tests to select one is not
comparable to first-attempt success. Report generation and selection cost,
selection error, `pass@1`, and `pass@k` separately. Never expose protected
release oracles to the candidate generator.

### 5. Critique and iterative refinement

Self-Refine used the same model to produce an answer, critique it, and revise
it, reporting about 20 absolute points of average improvement across seven
studied tasks [PI05]. Reflexion used verbal feedback and episodic memory across
trials [PI06]. Evaluator-optimizer workflows similarly alternate generation
with feedback when criteria are clear and revisions are demonstrably useful
[PR04].

These methods are appropriate when:

- a candidate can be checked against explicit criteria;
- feedback points to a remediable defect;
- another iteration has bounded cost;
- a stopping condition exists; and
- the final outcome receives independent verification.

They are risky when the generator and critic share the same blind spot, the
critic sees leaked truth, feedback is stored as untrusted durable memory, or
the loop rewards verbosity rather than correctness. JidoCode should keep
reflection scoped to the trial unless a reviewed command turns an adjudicated
lesson into a regression task or approved instruction revision.

### 6. Routing and specialized prompt families

One universal prompt tends to accumulate conflicting rules. Route clearly
separable tasks to narrower prompt families when routing can itself be
evaluated:

- code implementation;
- code review;
- repository analysis;
- retrieval or evidence collection;
- verification;
- security-sensitive operations; and
- publication preparation.

Measure routing precision/recall, false routing, abstention, and downstream
outcome—not merely classifier accuracy. Include negative cases where no route
or no tool should be selected.

### 7. Context and tool-interface engineering

Improving the prompt often means improving the context and agent-computer
interface:

- provide the smallest sufficient current repository slice;
- identify provenance and trust level of each context block;
- place high-priority instructions where the provider role hierarchy preserves
  them;
- keep tool names and descriptions distinct and action-oriented;
- make argument schemas typed and unambiguous;
- return errors that explain safe recovery;
- avoid huge tool outputs that bury relevant observations; and
- preserve exact revision and artifact identity.

These changes must be classified honestly as context-policy or tool-interface
treatments. They can be more effective than wording changes, but a prompt-only
claim would be incorrect.

### 8. Structured output and constrained interfaces

Use structured output when a deterministic consumer needs typed fields,
enumerated decisions, evidence references, or machine-checkable abstention.
Schema validity is then a deterministic grader.

Do not force inherently open-ended work into one brittle reference string.
For code review and analysis, normalize findings and claims into structured
records while retaining concise explanatory text. A valid schema proves
parseability, not truth; the referenced code, tests, and evidence still require
independent grading.

## Automatic prompt optimization

Automatic prompt optimization formalizes some part of prompt development as:

```text
find prompt p in candidate space P
that maximizes estimated utility U(p, D_development, grader)
subject to cost, latency, safety, and format constraints
```

This is useful, but the objective is only a proxy. The optimizer can exploit
the development sample, grader, candidate generator, or target model in ways
that do not generalize. A high optimization score is a reason to evaluate a
candidate, not evidence that it should ship.

### Method families

| Method | Mechanism and evidence | Data/access needs | Main risk | Recommended JidoCode role |
| --- | --- | --- | --- | --- |
| APE [AO01] | Generate instruction candidates with an LLM and select by task score; matched or exceeded human instructions on 19 of 24 studied tasks | development inputs, score function, generator and target calls | benchmark and score-function overfit | inexpensive first-pass candidate generation |
| ProTeGi [AO02] | Convert minibatch errors into textual “gradients,” edit prompts, and use beam/bandit search; reported improvements up to 31% on studied tasks | labeled failures, critic, target calls | correlated critic/grader; high search multiplicity | diagnosis-driven edits on narrow profiles |
| OPRO [AO03] | Show an optimizer previous prompts and scores, then ask for higher-scoring candidates; reported gains over human prompts on GSM8K and BBH | repeated prompt evaluations | expensive hill climbing; weak transfer; optimizer-model dependence | exploratory candidate generator with fixed budget |
| PromptBreeder [AO04] | Evolve populations of task prompts and the mutation prompts that modify them | sizable training set and many evaluations | opaque search, data overfit, large compute | research track only until reproducible value is shown |
| DSPy/MIPRO [AO05-AO06] | Represent multi-stage LM calls as a program and jointly optimize module instructions and demonstrations; MIPRO reported wins on five of seven studied programs | modular program, train/validation data, metric | credit assignment and compound overfit | strong fit for future multi-module prompt programs |
| GEPA [AO07] | Reflect on full trajectories and textual metric feedback, mutate module prompts, sample a per-instance Pareto frontier, and optionally merge complementary candidates; at ICLR 2026 it outperformed GRPO by 6% on average and up to 20% with up to 35x fewer rollouts in the studied tasks | compound prompt program, score plus useful textual feedback, training/Pareto-validation partitions, reflection model, bounded rollout budget | feedback/grader exploitation, validation reuse, reflection cost, lineage complexity, and over-broad comparison with weight-space RL | leading candidate for a future JidoCode feedback-rich optimizer experiment |
| TextGrad [AO08] | Back-propagate natural-language feedback through a compound system; reported gains in QA and code optimization | textual objective/critic and repeated calls | feedback is not a true gradient; judge coupling | experimental debugging of compound prompts |
| HbBoPs [AO09] | Structural-aware Bayesian optimization plus Hyperband allocates evaluation budget across instruction/example candidates | candidate representation, multi-fidelity validation | noisy small subsets can select unstable winners | query-efficient selection after enough validation data exists |
| GMPO [AO10] | Attribute prompt segments and aggregate several lightweight judges to reduce single-evaluator overfit | loss/gradient access for attribution and multiple judges | evaluator family may still share bias | research reference; not required for initial implementation |
| Contrastive optimization [AO11] | Learn differences between high- and low-performing prompts rather than only criticizing failures | paired prompt outcomes | contrast set and judge can encode spurious style | source of human-readable edit hypotheses |
| Vendor prompt optimizers [PR02, PR05] | Use examples, annotations, critiques, and grader metrics to propose instructions/demonstrations | vendor platform and labeled dataset | lock-in, opaque optimizer revisions, platform lifecycle | optional experiment adapter, never source of authority |

### GEPA deserves a first-class experiment

GEPA (Genetic-Pareto) is especially pertinent to JidoCode because it optimizes
one or more prompts from **system-level trajectories**, including model
responses, reasoning traces available to the optimizer, tool calls, and tool
results. Its feedback function can return both a scalar score and
task-specific natural-language feedback. A reflection model uses those traces
to propose a prompt mutation. Rather than mutating only the current aggregate
winner, GEPA samples candidates that are Pareto-optimal on individual
validation examples; system-aware merging can then combine modules improved on
different branches [AO07].

The ICLR 2026 paper reports that, across its studied tasks, GEPA beat GRPO by
6% on average and by as much as 20%, using up to 35 times fewer rollouts. It
also reports more than a 10% advantage over MIPROv2 and promising
inference-time code-optimization results. These are material results, but the
correct conclusion is narrower than “prompt evolution replaces RL”:

- GEPA and GRPO change different adaptation surfaces: GEPA changes visible
  prompt programs; GRPO changes model weights. Their attainable behaviors,
  inference costs, deployment constraints, and persistence differ.
- Rollout count is a useful sample-efficiency measure, not total cost. GEPA
  also pays for a reflection model, long trajectory/feedback context,
  candidate validation, and optional merges.
- Its feedback quality is pivotal. Executable compiler/test failures can
  provide excellent textual signals; a biased LLM judge can instead teach
  judge-specific shortcuts.
- Per-instance Pareto selection deliberately reuses a validation surface
  during search. JidoCode still needs a distinct candidate-selection set and a
  sealed test that GEPA never sees.
- Full trajectories can contain source code, credentials, injected text,
  proprietary instructions, user data, or protected oracle material. They
  require redaction, capability controls, retention limits, and an explicit
  rule forbidding sealed-oracle access.
- GEPA's merging and multi-module edits improve exploration but weaken simple
  one-factor attribution. The result should be evaluated as a new compound
  prompt profile unless ablations isolate a component.

Current DSPy documentation adds practical details relevant to an experiment:
the reflection model proposes instructions but does not score them; the task
program and metric do the repeated evaluation; explicit budgets cap metric
calls; and detailed results can retain every candidate, parent lineage,
per-example score, and discovery point [AO12]. It also warns, implicitly
through its budget examples, that reflection calls can dominate cost.

The recommended JidoCode trial is therefore:

1. choose one feedback-rich, non-production profile—repository analysis or
   review on seeded defects is preferable;
2. provide deterministic/executable sub-scores plus concise, redacted textual
   feedback;
3. lock authority, security, disclosure, and publication components;
4. use separate GEPA training, Pareto-selection, final validation, and sealed
   test partitions, even if a framework API defaults validation to training;
5. compare GEPA with the current prompt, a careful human edit, and MIPROv2 or a
   simple ProTeGi-style loop under both rollout and dollar/token budgets;
6. retain the full candidate lineage and semantic diffs;
7. evaluate clean, robustness, security, cost, and repeated-run metrics; and
8. admit only a frozen candidate through the normal PR and rollout process.

GEPA should move ahead of a generic APE/ProTeGi adapter in Phase P4 if JidoCode
already has sufficiently rich executable feedback and can implement the extra
partition and trace controls. Without those prerequisites, its stronger search
will optimize an immature measurement system faster.

### Optimization controls

Every automatic optimization job should declare:

```text
optimization_run = {
  source_prompt_bundle,
  editable_components,
  locked_security_components,
  candidate_generator_and_revision,
  optimizer_algorithm_and_revision,
  development_corpus_revision,
  validation_corpus_revision,
  objective_metrics_and_constraints,
  grader_and_human_label_revisions,
  proposal_and_evaluation_budgets,
  randomization_and_seed_controls,
  early_stopping_rule,
  candidate_retention_rule
}
```

Required controls are:

1. **Editable scope.** Security, authorization, disclosure, and publication
   instructions are locked unless their owners explicitly authorize that
   experiment.
2. **Nested data separation.** Generate and fit on development data; select and
   stop on validation; confirm once on a sealed test.
3. **Fixed objective.** Freeze metric definitions and constraints before
   search. Do not change the grader after seeing which candidate is winning.
4. **Multiplicity accounting.** Record how many prompts and analyses were
   tried. A winner among hundreds needs fresh confirmation.
5. **Baseline diversity.** Compare against the current production prompt, a
   clear minimal baseline, and where relevant a no-example or direct
   instruction baseline.
6. **Hard safety gates.** Reject candidates with critical violations even if
   aggregate utility rises.
7. **Robust selection.** Prefer a confidence-aware or lower-bound criterion
   over the largest noisy point estimate. Test semantic and benign format
   variants.
8. **Independent review.** A human reviews the semantic diff, new permissions,
   removed constraints, examples, and likely failure modes.
9. **Independent verification.** The candidate does not choose or author its
   own authoritative grader.
10. **No direct deployment.** The optimizer creates a candidate revision and
    evidence proposal. Normal PR, sealed evaluation, and rollout controls still
    apply.

### What may and may not be learned from

| Source | May influence prompt generation? | May select candidate? | May authorize release? |
| --- | --- | --- | --- |
| Curated development cases | yes | exploratory only | no |
| Development failure transcripts | yes, after redaction and adjudication | exploratory only | no |
| Validation cases | no direct fitting; results may drive bounded selection | yes | no |
| Sealed release tasks/oracles | no | final preregistered comparison only | can contribute governed evidence |
| Production incidents | yes, after root-cause review and corpus placement | later regression evidence | no direct authorization |
| LLM grader preference | yes, as advisory feedback | only with calibration and other oracles | never alone |
| Human preference | yes, under a rubric | yes | only through the governed evidence/decision process |
| Security red-team findings | yes, in an isolated remediation cycle | required rejection signal | critical failures block |

This separation keeps “improve over time” from becoming “memorize every test
ever seen.” Once a sealed case is disclosed to prompt authors, it belongs in a
regression or development revision; it is no longer a fresh sealed test.

## Defining prompt success

### Success is a vector, not one rate

A production prompt can be correct but unsafe, safe but useless, accurate but
unreliable, or effective but uneconomic. JidoCode should keep at least these
dimensions separate:

| Dimension | Core question | Example measurement |
| --- | --- | --- |
| Task correctness | Did the requested outcome actually occur? | hidden tests, state invariants, verified claim truth |
| Instruction adherence | Were scope, format, and user constraints followed? | structured assertions and calibrated rubric |
| Evidence and grounding | Are material claims supported by current authorized evidence? | claim/evidence precision, citation entailment, provenance completeness |
| Tool behavior | Were tools selected and invoked correctly? | correct-call, argument, unnecessary-call, recovery, and prohibited-call rates |
| Review quality | Were real defects found without flooding developers? | finding precision/recall, severity/localization accuracy, false-positive burden |
| Analysis quality | Are claims correct, complete enough, scoped, and uncertainty-aware? | claim precision/recall, evidence coverage, contradiction handling |
| Robustness | Does performance survive meaning-preserving variation and realistic noise? | median, lower quantile, spread, worst critical slice |
| Reliability | Does it work repeatedly, including under faults? | `pass@1`, `pass^k`, timeout and bounded-recovery rates |
| Security and authority | Did any forbidden disclosure, effect, or control bypass occur? | critical violation count and attack success rate |
| Efficiency | What resources produce a correct accepted outcome? | tokens, tool calls, latency, cost, human minutes per correct acceptance |
| Product value | Does the prompt improve real development outcomes? | accepted yield, escaped defects, reverts, time-to-merge, oversight burden |
| Evaluator health | Can the measurement system distinguish success and gaming? | mutation sensitivity, flake, human agreement, judge robustness, canaries |

Do not collapse critical security and authority failures into a weighted
average. A useful decision form is:

```text
maximize:
  correct accepted yield and product utility

subject to:
  zero accepted critical safety/authority violations
  accepted precision above threshold
  regression retention above threshold
  robustness lower bound above threshold
  cost, latency, and oversight within budget
  evaluator-health gates passing
```

### Binary success contract

For tasks with objectively verifiable outcomes, define one binary success
contract before the run. For example:

```text
success =
  task_outcome_correct
  and required_invariants_hold
  and output_contract_valid
  and provenance_complete
  and no_prohibited_effect
```

Report the individual checks alongside the conjunction. A single binary rate is
easy to interpret, while the component breakdown makes remediation possible.

The basic eligible-trial estimator is:

```text
p_hat = successful_eligible_trials / all_eligible_trials
```

Always report the numerator, denominator, confidence interval, unit of
inference, eligibility policy, and failure categories. “93% success” without
those fields is not a reproducible result.

### Task-level versus trial-level success

Repeated trials are nested within tasks. If task `i` has `n_i` eligible trials
and `c_i` successes:

```text
task_reliability_i = c_i / n_i
macro_task_success = mean(task_reliability_i across eligible tasks)
```

A trial-pooled micro average can overweight tasks with more valid trials. Use
the task as the normal unit of product inference and disclose both summaries
when trial counts differ.

### `pass@1`, `pass@k`, and `pass^k`

- `pass@1` measures first-attempt capability and is the primary JidoCode prompt
  endpoint.
- `pass@k` measures whether at least one of `k` attempts succeeds. It is
  relevant only if the product really generates and safely selects among those
  attempts.
- `pass^k` measures whether all `k` attempts succeed and captures repeated-use
  consistency.

Given `n` sampled attempts and `c` successes for a task, without-replacement
estimators commonly used for diagnostic reporting are:

```text
pass@k = 1 - choose(n - c, k) / choose(n, k)
pass^k = choose(c, k) / choose(n, k)
```

State `k`, sample count, independence assumptions, and selection mechanism.
Never compare best-of-five prompt results with another prompt's first attempt
under the label “accuracy.”

### Multi-prompt robustness metrics

For a task or slice evaluated under a prespecified set of semantic variants,
report:

- mean and median success across variants;
- a lower quantile, such as the 10th percentile;
- minimum or worst critical variant, when the set has defensible coverage;
- standard deviation, interquartile range, and max-min spread;
- rank stability when comparing candidates;
- paired clean-to-perturbed degradation; and
- variant-family slices such as paraphrase, formatting, ordering, typo,
  irrelevant context, long context, and multilingual input.

The operational gate should use the fixed production prompt plus realistic
user-input perturbations. General capability reporting should additionally use
several plausible instruction/template variants. Do not generate variants
after seeing which wording makes a preferred candidate fail.

### Review and analysis metrics

Open-ended review and analysis do not have one canonical text. Score normalized
units:

```text
review finding = {
  defect identity,
  file and location,
  category and severity,
  precondition,
  impact,
  evidence,
  remediation,
  confidence
}

analysis claim = {
  proposition,
  polarity,
  scope,
  evidence references,
  contradicting evidence considered,
  inference kind,
  uncertainty
}
```

Use finding/claim precision and recall against adjudicated truth, localization
quality, severity calibration, evidence validity, contradiction handling,
abstention quality, and human burden. Historical PR comments are useful
positive candidates but incomplete negatives, so unmentioned findings require
independent adjudication rather than automatic false-positive labels. This
continues the review and analysis model in
[the coding-agent evaluation research](08-coding-agent-evaluations-for-development.md).

### Efficiency and accepted yield

Track:

```text
cost_per_correct_accepted_outcome =
  total_eligible_inference_and_tool_cost /
  number_of_independently_verified_correct_accepted_outcomes

human_minutes_per_correct_accepted_outcome =
  total_review_and_recovery_minutes /
  number_of_independently_verified_correct_accepted_outcomes
```

Also report attempt coverage and accepted precision. A prompt can appear
precise by refusing almost everything, or appear productive by emitting many
low-quality candidates. Correct accepted yield captures both coverage and
correctness more honestly.

## Grading prompt outcomes

### Oracle precedence

Use the most authoritative and least gameable grader available:

| Priority | Grader | Appropriate use | Limitation |
| --- | --- | --- | --- |
| 1 | Environment/end-state oracle | repository state, database state, external effect, policy state | requires an instrumented environment |
| 2 | Executable tests and invariants | code behavior, contracts, security boundaries, schemas | tests can be incomplete or tampered with |
| 3 | Static deterministic checks | formatting, types, lint, forbidden operations, provenance | cannot establish semantic correctness alone |
| 4 | Structured reference/rule checks | unique labels, canonical entities, required fields | brittle when many answers are valid |
| 5 | Calibrated human rubric | nuanced correctness, usefulness, severity, communication | costly, variable, and subject to design bias |
| 6 | Calibrated model judge | semantic triage, rubric assistance, prioritization | bias, correlated error, reward hacking |
| 7 | Surface text metric | narrow diagnostics only | weak proxy for open-ended truth |

For code-producing prompts, the agent's statement that tests passed is not an
oracle. The independent verifier reconstructs the admitted artifact and runs
the checks. For analysis prompts, eloquence is not evidence; material claims
must cite exact repository or research evidence.

### Deterministic and executable graders

Prefer:

- hidden fail-to-pass and pass-to-pass tests;
- schema validation;
- type checking, linting, and static analysis;
- patch applicability and clean-checkout reproduction;
- policy and capability audit events;
- filesystem, process, network, and publication invariants;
- evidence digest and revision checks;
- mutation tests that show the oracle detects seeded faults; and
- negative controls that a correct prompt should leave unchanged.

Candidate-authored tests are useful evidence only after showing they fail on
the pinned base and pass on the candidate; they do not replace verifier-owned
checks.

### Reference-based automatic metrics

Exact match, ROUGE, BLEU, lexical overlap, and embedding similarity can help
with unique labels or narrow diagnostics. They are poor general truth oracles
for code review, repository analysis, and other outputs with many valid forms.
A prompt optimized directly against surface overlap may copy reference style
while becoming less correct or useful.

If a semantic metric is used:

- validate it against task-specific human labels;
- include alternate-correct, subtly incorrect, and fluent-but-unsupported
  controls;
- test multilingual and long-form cases if those are in scope;
- record threshold selection on development data; and
- keep it advisory unless its error bounds satisfy the decision risk.

### Model judges

Model judges can scale nuanced scoring. G-Eval reported stronger correlation
with human judgments than prior metrics in its studied summarization setting,
while also identifying bias toward LLM-generated text [EV02]. MT-Bench found
strong judge/human agreement in its setting but documented position,
verbosity, self-enhancement, and reasoning limitations [EV03]. Later work
shows position bias varies substantially by task and judge, and multi-agent
debate can amplify rather than cancel several biases [EV04-EV06].

Consequently, every authoritative-looking judge is itself an evaluation
target. A JidoCode judge must be pinned by model snapshot, prompt/rubric,
reference visibility, inference parameters, role order, and aggregation
revision.

Required calibration set:

- high-quality human or executable ground truth;
- correct, alternate-correct, partially correct, and incorrect outputs;
- clean negative cases;
- concise and verbose versions with equal substance;
- candidate/baseline order swaps;
- style and identity masking where possible;
- prompt-injection text inside the candidate output;
- unsupported but persuasive claims;
- outputs from multiple model families, including the judge's family; and
- edge cases accumulated after adjudicated disagreements.

Required health measures:

| Measure | What it detects |
| --- | --- |
| Balanced accuracy/F1 and confusion matrix | class-specific judge error and imbalance |
| Human/judge agreement and correlation | alignment with the intended rubric |
| Position-swap consistency | pairwise order bias |
| Style/verbosity invariance | superficial preference |
| Self-family versus cross-family error | self-enhancement or shared-model bias |
| Reference-present versus absent error | unsupported judging from plausibility |
| Repetition stability | judge sampling variance |
| Adversarial-output rejection | injection or rubric manipulation |
| Calibration curve or Brier score | whether stated confidence means anything |
| Abstention precision/coverage | whether uncertainty routing is useful |

Use pointwise scoring before pairwise choice when it reduces direct style
comparison, counterbalance candidate order, and include an abstain/needs-human
state. A diverse panel can reduce some single-model errors—PoLL reported better
results at lower cost in its studied settings [EV05]—but panel size is not a
proof of independence. Debate can synchronize bias [EV06].

Model judges remain advisory for code acceptance, critical security,
high-impact review truth, and rollout decisions. OpenAI's official grader
guidance likewise recommends evaluating graders against task prompts,
high-quality model and expert answers, ground-truth grades, and accumulating
edge cases; it explicitly warns about grader hacking [PR03].

### Human evaluation

Human evaluation is a measurement process, not an appeal to intuition. Follow
established NLG guidance [EV07-EV08]:

- define separate criteria rather than one vague “quality” score;
- train reviewers on examples and boundary cases;
- use at least two reviewers for qualitative truth construction where risk
  warrants it;
- randomize or counterbalance candidate order and blind prompt identity;
- collect confidence, rationale, and abstention;
- report sample selection, reviewer expertise, raw counts, agreement and
  uncertainty;
- adjudicate disagreements under a versioned policy;
- preregister confirmatory studies; and
- preserve the original independent grades as well as adjudication.

Agreement is diagnostic, not the goal by itself. Low agreement can reveal an
ambiguous task or rubric. Some language-quality disagreement is irreducible,
and forcing consensus may erase legitimate preferences. Separate objective
truth disputes from plural user-preference measurements.

## Experimental design

### Data partitions

Use physically and logically separate revisions:

| Partition | Visible to | Purpose | Mutation policy |
| --- | --- | --- | --- |
| Prompt development | prompt authors and optimizers | diagnose, generate candidates, fit examples | append reviewed failures; version every cut |
| Prompt validation | experiment runner; aggregate feedback to authors | select candidates, tune stopping and thresholds | replace only by declared revision |
| Sealed capability test | independent custodian/evaluator | confirm generalization and capability | never tune; rotate after disclosure/saturation |
| Regression | prompt authors and CI | preserve known behavior and incident fixes | append adjudicated cases |
| Robustness/adversarial | authorized red team and evaluator | semantic variation, injection, leakage, gaming | fixed plus generated/adaptive revisions |
| Judge calibration | evaluator owners, separate from target prompt tuning | test rubrics and model judges | append adjudicated judge errors |
| Shadow/pilot | production governance | measure natural tasks and human outcomes | rolling, access-controlled |

Split by repository, task family, or incident lineage where near-duplicate
leakage is plausible. A random row split is insufficient when variants share
the same underlying bug, patch, document, or template.

### Baseline and hypotheses

Before running candidates:

1. freeze the current production/baseline prompt and target tuple;
2. name one primary outcome and the required safety/regression constraints;
3. state the hypothesized mechanism of the edit;
4. identify slices expected to improve and plausible regressions;
5. choose the minimum practically important difference;
6. determine trials per task and evaluation budget; and
7. preregister exclusions, missingness, statistical comparisons, and stopping.

Example:

```text
hypothesis:
  Separating evidence requirements from output-format instructions will
  improve analysis-claim evidence precision by at least 5 percentage points
  without reducing claim recall by more than 2 points, increasing median
  latency by more than 10%, or causing any critical disclosure violation.
```

That is falsifiable. “Make the prompt better” is not.

### Paired comparison

Run baseline and candidate on the same eligible tasks, environment revisions,
budgets, and trial schedule. Randomize execution order and, when provider drift
is possible, interleave assignments. Use:

- McNemar's test or an exact paired test for one paired binary outcome per
  task;
- paired bootstrap/permutation methods for task-level score or cost
  differences;
- hierarchical or cluster bootstrap sensitivity analysis for tasks nested in
  repositories and repeated trials;
- two-sided 95% Wilson intervals for gate proportions; and
- robust summaries for heavy-tailed latency and cost.

Report intervals on the paired difference, not only separate candidate and
baseline intervals.

### Repeated trials and provider variance

Pin sampling parameters and provider/model snapshot where possible. Record
whether a seed is accepted and whether it actually controls all randomness.
Interleave baseline/candidate trials to reduce temporal confounding from
provider changes.

Predefine:

- how timeouts and budget exhaustion count;
- which infrastructure signatures invalidate a trial;
- whether both members of a paired block rerun after infrastructure failure;
- maximum invalidation and flake rates;
- treatment of refusals and rate limits; and
- exact scheduled, started, completed, invalid, and graded denominators.

Never rerun only failed candidate trials.

### Factorial and ablation studies

When a bundle changes several components, use ablations or a factorial design
to understand contribution:

| Factor | Example levels |
| --- | --- |
| Instruction structure | current, simplified, sectioned |
| Examples | none, fixed, retrieved |
| Evidence rule | implicit, explicit structured claims |
| Planning | direct, bounded plan, evaluator-optimizer |
| Context placement | current, provenance-labelled, relevance-ranked |
| Tool contract | current schema, revised schema |
| Output | prose, structured finding/claim |

Full factorials become expensive quickly. Use a preregistered fractional design
or staged elimination, then confirm the chosen complete bundle on held-out
data. Do not attribute an interaction effect to a single component.

### Multiple comparisons and winner's curse

Automatic search may evaluate hundreds of candidates. The highest validation
score is upward-biased even if no candidate is truly better. Controls include:

- one primary endpoint and a fixed candidate budget;
- development/validation/sealed nesting;
- successive-halving or multi-fidelity screening only on non-sealed data;
- confidence-aware selection;
- correction or explicit exploratory labels for many comparisons;
- keeping all attempted candidate results, not only winners; and
- a fresh confirmatory run of the final frozen candidate.

### Power and practical significance

Choose task count from the decision:

- expected baseline rate;
- minimum useful improvement;
- maximum acceptable regression or critical failure incidence;
- repository/task clustering;
- repeated-run variance;
- accepted-outcome denominator needed for precision; and
- critical slice coverage.

A statistically significant one-point gain may be irrelevant if it doubles
cost. A five-point point estimate from twelve tasks may be too uncertain to
ship. Report statistical uncertainty, practical effect, and operational cost
together.

## Continuous prompt-improvement lifecycle

The lifecycle should behave like a governed software change:

```text
behavior contract
       |
       v
baseline + failure taxonomy
       |
       v
candidate generation ----> automatic optimizer (optional)
       |
       v
development diagnostics
       |
       v
validation selection + semantic diff review
       |
       v
robustness / security / evaluator-health checks
       |
       v
frozen sealed evaluation
       |
       v
PR and governed rollout decision
       |
       v
shadow / controlled pilot / production monitoring
       |
       v
adjudicated failures ----> regression + next development revision
```

### Step 1: Observe and normalize failures

Sources include:

- manual development checks;
- failed or flaky evaluation trials;
- incorrect accepted changes;
- correct work rejected by a prompt or verifier;
- review false positives and missed seeded defects;
- unsupported analysis claims;
- tool misuse, repeated calls, and poor recovery;
- safety and injection exercises;
- user corrections, overrides, and abandonment;
- CI failures, reverts, and incidents; and
- cost or latency tails.

Normalize each failure:

```text
failure = {
  target_and_prompt_bundle,
  task_and_environment_revision,
  observable_expected_outcome,
  observable_actual_outcome,
  first_verified_divergence,
  failure_category,
  severity_and_user_impact,
  evidence_and_adjudication,
  whether_prompt_causal_or_contributory,
  proposed_regression_or_remediation
}
```

Do not assume every bad output is a prompt problem. Possible causes include
task ambiguity, missing context, weak tool interface, model capability,
retrieval, sandbox failure, evaluator error, provider drift, or an impossible
contract. Fix the owning layer.

### Step 2: Maintain a failure taxonomy

Suggested prompt-related categories:

- misunderstood objective;
- missed explicit constraint;
- instruction conflict or wrong precedence;
- over-triggered or under-triggered tool/routing behavior;
- invalid arguments or tool-result misunderstanding;
- insufficient evidence or unsupported inference;
- incomplete coverage;
- overconfident answer instead of clarification/abstention;
- output schema or formatting failure;
- excessive verbosity or insufficient explanation;
- context dilution, truncation, or stale-context use;
- benign-variation brittleness;
- prompt injection, extraction, or data leakage;
- critique/refinement loop failure;
- cost, latency, or non-termination; and
- grader/evaluation defect rather than target defect.

Track transition rates between categories after each prompt revision. A prompt
that fixes formatting while increasing unsupported claims is not a net
improvement.

### Step 3: Create minimal discriminating cases

Convert an adjudicated failure into:

- a minimal positive case where the behavior is required;
- a clean negative case where it must not occur;
- one near-neighbor case that differs at the decision boundary;
- a realistic full-context case;
- relevant semantic/format perturbations; and
- an independent oracle.

Do not paste confidential production data into prompt examples. Redact or
synthesize only after confirming that the new case preserves the causal
mechanism. Keep incident-derived and protected cases access-controlled.

### Step 4: Baseline before editing

Run the current bundle on the new development cases and a representative
regression sample. Verify that the proposed case actually discriminates the
failure. If the baseline passes, the root cause or reproduction may be wrong.

### Step 5: Generate candidates

Use human hypotheses, error-cluster critiques, APE/ProTeGi-style proposals, or
a modular optimizer. Change the smallest component consistent with the
hypothesis. Keep a machine-readable semantic diff:

- added, removed, and moved requirements;
- changed authority or conflict rules;
- added/removed examples;
- context and tool-interface changes;
- new output constraints;
- expected improved slices; and
- identified regression risks.

### Step 6: Screen and select

Use development cases for fast iteration, then rank surviving candidates on
validation with paired tasks, repeated trials, cost, and safety constraints.
Inspect transcripts and end states from successes as well as failures. A
passing grader can conceal a wrong strategy, leakage, or fragile shortcut.

### Step 7: Stress the frozen candidate

Before sealed evaluation, run:

- known regression suite;
- semantic prompt/input variants;
- typos, formatting, order, irrelevant context, and long-context tests;
- conflicting and malicious instructions in untrusted content;
- prompt extraction attempts;
- tool errors, timeouts, partial results, and stale observations;
- judge position/style/injection checks; and
- budget and cancellation boundaries.

Any edit after this point creates a new candidate and restarts the applicable
checks.

### Step 8: Confirm on sealed data

Freeze:

- exact candidate and baseline target tuples;
- catalog/task assignments;
- number of trials;
- oracle/grader/rubric revisions;
- statistical analysis;
- exclusions and infrastructure policy; and
- gates.

The prompt author or optimizer receives only governed results appropriate to
the partition. Test content and protected oracle bytes remain hidden.

### Step 9: Review and publish as code

The pull request should include:

- prompt source and compiler changes;
- manifest and digest update;
- behavior-contract diff;
- development and validation report;
- regression, robustness, security, and evaluator-health results;
- sealed evidence reference when applicable;
- cost/latency effect;
- reviewer sign-off for authority/security changes; and
- rollback prompt revision.

Prompt text deserves the same review rigor as executable policy because it can
materially change agent behavior. It still does not replace executable policy.

### Step 10: Shadow, pilot, and monitor

Offline evaluation is necessary but incomplete. In shadow mode, compare the
candidate without giving it publication or side-effect authority. In a
controlled pilot, use randomized assignment where feasible, staged exposure,
predeclared guardrails, and rapid rollback.

Production measures should include:

- correct accepted yield;
- defect escape, CI failure, revert, and incident rate;
- review acceptance and false-positive burden;
- developer edit distance or correction rate;
- time to useful result and time to merge;
- clarification, abstention, retry, and override rates;
- tokens, latency, cost, and tool volume;
- support complaints and abandonment; and
- prohibited effects or disclosure attempts.

Randomized online experiments support causal claims, but only if assignment,
telemetry, sample ratios, and analysis are trustworthy [ON01-ON04]. Check
sample-ratio mismatch before interpreting effects. Short-term engagement can
misrepresent long-term value, so pair immediate task metrics with durable
quality and harm measures [ON03].

### Step 11: Refresh without rewriting history

When production evidence contradicts an earlier result:

- retain the historical prompt, run, and decision;
- record the new production outcome and adjudication;
- mark affected evidence stale, contradicted, or invalidated under policy;
- create a new confidential regression case;
- revise the development/validation corpus;
- periodically publish a new sealed corpus revision; and
- rerun the gates for a new candidate.

Never edit old scores or silently change denominators.

## JidoCode prompt-evaluation profiles

Prompt improvements should be evaluated by the job they perform, not through a
single generic chat-quality suite.

### Coding prompt profile

| Objective | Primary oracle | Metrics | Required negative/adversarial cases |
| --- | --- | --- | --- |
| Correct implementation | independent fresh-checkout tests and state invariants | `pass@1`, accepted precision, correct accepted yield, regression retention | ambiguous requests, alternate-correct solutions, weak visible tests |
| Scope discipline | patch and repository diff checks | unnecessary-file/change rate, reverted edits | nearby unrelated code, generated/vendor boundaries |
| Test quality | base/candidate discrimination and mutation | mutation sensitivity, redundant-test rate | tests that merely encode implementation or skip behavior |
| Tool use | typed tool trace plus end state | correct tool/argument, recovery, unnecessary-call rate | tool failure, stale result, unavailable command |
| Safety | capability/policy monitor | critical violation and unsafe-recovery count | malicious repository text, credential and egress bait |
| Efficiency | provider/tool telemetry | cost, tokens, steps, latency per correct accepted outcome | long context, repeated build failure |

### Review prompt profile

| Objective | Primary truth | Metrics | Required controls |
| --- | --- | --- | --- |
| Find real defects | seeded/mutated defects plus expert adjudication | finding recall by severity/category | subtle boundary, concurrency, migration, security faults |
| Suppress noise | clean and alternate-correct patches | precision, findings per clean patch, review burden | style-only differences and valid unusual code |
| Localize and substantiate | exact source revision and reproduction evidence | file/line accuracy, evidence validity | plausible but wrong location/explanation |
| Calibrate severity | human rubric and impact contract | severity confusion matrix, calibration | same defect under different context/impact |
| Give useful remediation | executable or expert check | remediation feasibility and non-regression | unsafe or scope-expanding fix |
| Resist output manipulation | adversarial patch/comments | injection success and secret/prompt leakage | comments asking reviewer to ignore code or reveal policy |

The suite must include clean negatives. Optimizing only for defect recall
creates a prompt that flags everything.

### Repository-analysis prompt profile

| Objective | Primary truth | Metrics | Required controls |
| --- | --- | --- | --- |
| Claim correctness | repository graph/source and executable checks | claim precision, contradiction rate | convincing unsupported assertions |
| Evidence completeness | adjudicated required evidence set | evidence coverage and provenance | stale revision and similarly named symbols |
| Localization/retrieval | gold or adjudicated relevant artifacts | Top-k recall, reading load, irrelevant context | distractor modules and generated files |
| Scope and uncertainty | rubric plus truth set | scope accuracy, abstention precision/coverage, calibration | insufficient evidence and ambiguous architecture |
| Synthesis | blinded expert rubric | decision usefulness and omission severity | conflicting documents and code/document drift |
| Freshness | pinned source/time scope | stale-claim rate | newer branch, migration, or dependency state |

### Prompt-evaluator profile

Prompt and rubric changes for an LLM judge need a separate target:

| Objective | Truth | Metrics | Gate |
| --- | --- | --- | --- |
| Correct grading | blinded human/executable labels | balanced accuracy/F1, correlation, confusion matrix | preregistered task-specific threshold |
| Order robustness | swapped candidate positions | position consistency/fairness | no material directional bias |
| Style robustness | content-equivalent style/length variants | invariant judgment rate | bounded delta |
| Injection resistance | hostile candidate output | attack success and leakage | zero accepted critical manipulation |
| Repetition stability | repeated judge calls | agreement and score variance | bounded instability |
| Generalization | sealed judge-calibration set | held-out performance | no development-only gain |
| Appropriate abstention | ambiguous/disputed cases | precision/coverage | route high-risk uncertainty to humans |

Do not use the same cases to optimize the target prompt and its judge prompt.

## Prompt evaluation matrix

The following matrix is the minimum tracking view for each prompt family:

| Control ID | Threat or failure | Development signal | Release metric/gate | Production signal | Remediation |
| --- | --- | --- | --- | --- | --- |
| `P-EVAL-01` | objective or requirement misunderstood | minimal positive/near-neighbor cases | paired task-success lower bound | correction and retry rate | clarify outcome/decision boundary; add discriminating case |
| `P-EVAL-02` | instruction conflict or wrong precedence | conflict matrix and transcript inspection | zero critical precedence failures | overrides and policy incidents | remove duplication; make authority explicit; enforce externally |
| `P-EVAL-03` | overfit to examples/order | example ablations and order randomization | validation/sealed retention; bounded order spread | novel-task regression | diversify/shorten examples; revise selection policy |
| `P-EVAL-04` | semantic/format brittleness | paraphrase and formatting metamorphic tests | median/lower-quantile robustness and bounded degradation | user wording failure rate | simplify instruction; diversify dev variants; fix parser/renderer |
| `P-EVAL-05` | context dilution/truncation | context-length and distractor sweep | critical-slice success and provenance completeness | long-session failure/compaction rate | reduce/route context; improve provenance and placement |
| `P-EVAL-06` | wrong or unnecessary tool use | positive/negative tool cases | tool precision/recall and prohibited-call gate | tool error/cost/override rate | revise ACI/schema/routing; add no-tool examples |
| `P-EVAL-07` | unsupported review/analysis claims | persuasive-wrong and missing-evidence cases | claim/finding precision and evidence validity | rejected findings/corrections | require structured evidence; improve retrieval/verifier |
| `P-EVAL-08` | excessive refusal or unsafe compliance | balanced should/should-not cases | appropriate-action precision/recall; zero critical harm | refusal, incident, escalation rate | adjust boundary examples; keep hard policy outside prompt |
| `P-EVAL-09` | prompt injection | direct/indirect attack suite with clean controls | utility/security vector; zero accepted critical effect | attack/containment events | isolate data/instructions; least privilege; filters; external policy |
| `P-EVAL-10` | prompt extraction or secret disclosure | Raccoon-style and multi-turn leakage cases | zero protected content disclosure | canary and disclosure alerts | remove secrets from prompts; minimize prompt; capability-gate data |
| `P-EVAL-11` | optimizer/grader reward hacking | alternate graders, human audit, mutations | evaluator-health gates and sealed generalization | offline/online metric divergence | replace/repair grader; constrain objective; invalidate affected evidence |
| `P-EVAL-12` | stochastic unreliability | repeated trials | `pass@1`, `pass^k`, timeout/flake bounds | retry and repeat-failure rate | simplify flow; improve verification/recovery; change model/profile |
| `P-EVAL-13` | regression elsewhere | full known regression suite | retention threshold and zero critical regression | escaped prior failure | restore component or add routed specialization |
| `P-EVAL-14` | cost/latency explosion | budget sweeps | cost/latency guardrails per correct outcome | spend and tail-latency alerts | shorten context; route model; reduce iterations/tool output |
| `P-EVAL-15` | model/provider drift | scheduled canaries | target-snapshot-specific evidence only | canary and behavior shift | freeze version where possible; rerun and revise prompt |
| `P-EVAL-16` | task/oracle defect | references, alternates, negatives, mutation | evaluator-health acceptance | appeal/adjudication rate | repair new task revision; invalidate affected aggregate |
| `P-EVAL-17` | production metric gaming | offline outcome inspection and countermetrics | no single proxy authorizes rollout | quality, harm, and long-term countermetrics | change objective; add guardrails; rollback |
| `P-EVAL-18` | unauthorized self-modification | prompt-digest and command checks | only reviewed immutable candidate admitted | unexpected digest/config event | reject/quarantine; restore pinned bundle; audit authority path |

Each row should have an owner, current prompt revision, corpus revision, last
run, exact numerator/denominator, interval, status, reopening condition, and
linked remediation. A green aggregate never suppresses a red critical row.

## Security and threat model for prompt improvement

### Prompt text is not a security boundary

Research benchmarks continue to find instruction-following models vulnerable
to prompt injection and prompt extraction [SE01-SE04]. Telling a model to
“ignore malicious instructions” can be one defense layer, but it cannot grant
or remove real authority.

JidoCode security must continue to enforce:

- least-privilege tool capabilities;
- repository and filesystem scope;
- network and credential mediation;
- typed proposals and policy checks;
- sandboxing and resource budgets;
- independent verification;
- evidence and revision binding;
- separate publication authority; and
- audit and rollback.

Prompts should identify trust boundaries and desired behavior, while the
harness makes forbidden effects impossible or fail-closed.

### Threat and remediation matrix

| Threat source | Attack/failure path | Why prompt optimization worsens it | Required remediation |
| --- | --- | --- | --- |
| Malicious user | direct instruction override, jailbreak, data exfiltration | optimizer may favor compliance on benign data | adversarial balanced corpus, least privilege, output/data controls, zero critical gate |
| Malicious repository/dependency/content | indirect instructions in code, docs, issues, tool output | richer context creates more attack surface | label untrusted data, isolate instruction channels, sanitize tool output, capability enforcement |
| Prompt extractor | requests system instructions, examples, canaries, or secrets | valuable optimized prompt may contain proprietary logic | assume prompt can leak; keep secrets/oracles out; minimize content; leakage tests |
| Poisoned examples or retrieval | attacker supplies demonstration that changes policy | retrieved few-shot policy may amplify one item | provenance, allowlists, diversity, poisoning tests, immutable indexes |
| Automatic optimizer | searches for grader quirks or removes “costly” constraints | objective omits real safety/product dimensions | locked components, constrained objective, attempt ledger, human semantic review |
| Model judge | rewards verbosity, self-family style, or injected evaluator commands | target learns judge-specific surface features | calibration, swaps, style controls, alternate judges, humans, deterministic oracles |
| Prompt author | knowingly or accidentally tunes to sealed cases | repeated manual edits leak test information | access separation, immutable partitions, test rotation, audit of candidate history |
| Provider/model change | behavior shifts under same prompt text | optimized wording is model-specific | pin snapshot/route, canaries, automatic staleness, full re-evaluation |
| Telemetry/experiment pipeline | missing failures, sample-ratio mismatch, selective reruns | apparent improvement comes from biased denominators | immutable assignments, exact counts, SRM checks, preregistered invalidation |
| Production feedback loop | popular or accepted outputs become examples regardless of truth | reinforces plausible errors and majority bias | adjudication before corpus admission; counterexamples and minority slices |
| Durable memory | raw reflection or failure text persists as instruction | injection and private data propagate across trials | trial-scoped feedback; reviewed, redacted regression adoption only |
| Compromised evaluator | candidate edits tests, grader, or evidence | optimizer receives a perfect false reward | evaluator outside sandbox, content pinning, tamper checks, canaries |

This report complements
[the current JidoCode threat model](07-current-threat-model-for-jido-code.md).
Prompt hardening reduces likelihood; harness controls reduce authority and
impact.

## Graph and ontology implications

### Keep prompt evaluation in the existing evaluation graph family

Prompt information does not need an independent mutable “prompt score graph.”
A prompt candidate is a treatment inside the same governed evaluation model as
model, harness, tool, and context changes:

```text
immutable prompt bundle definition
              |
              v
EvaluationTarget -> EvaluationProfile -> EvaluationRun
                                         |
                                         v
                                  EvaluationTrial
                                         |
                                         v
                GraderResult / HumanGrade / EvaluatorHealth
                                         |
                                         v
                                  AggregateResult
                                         |
                                         v
                            governed RolloutDecision
                                         |
                                         v
                                ProductionOutcome
```

Use:

- `evaluation_catalog` for immutable prompt-bundle definitions or protected
  references, evaluation targets, profiles, task partitions, metrics, and
  statistical plans;
- `evaluation_run` for frozen assignments, trials, prompt-render digests,
  observations, and artifact references;
- existing `evidence` for admitted grades, health results, aggregates, and
  proposed claims;
- existing `derived` for dashboards and prompt comparisons;
- existing `repository_control`/`factory_policy` for accepted prompt promotion
  and rollback; and
- existing `security_audit` for protected-corpus access, extraction,
  tampering, invalidation, and overrides.

This preserves the authority invariant: a prompt score cannot deploy a prompt.

### Candidate ontology gap

The current candidate evaluation ontology already represents
`EvaluationProfile`, `EvaluationTarget`, `EvaluationRun`, `EvaluationTrial`,
`GraderResult`, `HumanGrade`, `EvaluatorHealth`, `MetricObservation`,
`AggregateResult`, `RolloutDecision`, and `ProductionOutcome`. The research
target tuple names prompt digests, but
[`EvaluationTarget`](../../priv/ontology/evaluation/1.0.0/evaluation.ttl)
currently has no explicit first-class prompt fields.

A future immutable ontology release—not an edit to accepted `1.0.0`—should
consider:

| Proposed term | Purpose |
| --- | --- |
| `PromptBundleRevision` | immutable definition/reference for one prompt treatment |
| `PromptComponentRevision` | typed source, partial, example, schema, or tool-description component |
| `PromptCompilerRevision` | assembly, role, ordering, escaping, and rendering code revision |
| `DemonstrationSetRevision` | immutable example identities, order/selection policy, and digest |
| `promptBundleDigest` | bind an `EvaluationTarget` to the exact bundle |
| `promptCompilerRevision` | bind the renderer/compiler |
| `demonstrationSetDigest` | bind examples without exposing protected bytes |
| `renderingPolicyRevision` | bind role/order/escape/truncation behavior |
| `baselinePromptTarget` | explicit paired baseline relationship |
| `derivedFromPrompt` | candidate lineage without implying superiority |
| `optimizationMethodRevision` | optimizer algorithm/generator identity |

Operational shapes should require exactly one prompt-bundle binding for prompt
experiments, reject unresolved mutable aliases, and keep protected/raw prompt
bytes out of graph literals. A rendered-prompt digest belongs to the trial
observation because dynamic task context differs per trial.

Do not add these terms directly to the immutable
`priv/ontology/evaluation/1.0.0` candidate. They require the same reviewed
ontology, SHACL, graph-registry, writer-capability, query, migration, and
falsification process described in
[the evaluation ontology README](../../priv/ontology/evaluation/1.0.0/README.md).

### Queries this representation enables

- which prompt bundle was actually rendered for a disputed trial;
- which results are stale after a component, compiler, example, model, tool, or
  context-policy change;
- which candidates were evaluated against the same assignments and budget;
- how many candidates were tried before the reported winner;
- which semantic variants or risk slices lack coverage;
- whether a candidate improved development but regressed sealed or production
  outcomes;
- which judge revision selected a prompt and whether that judge later failed
  calibration;
- which production incident traces to a prompt decision;
- which incident-derived cases have entered a regression corpus; and
- which deployed prompt lacks a valid rollback revision.

## Recommended development and CI cadence

| Tier | Trigger and budget | Prompt checks | Decision |
| --- | --- | --- | --- |
| T0 deterministic | every prompt/compiler PR; seconds/minutes | rendering snapshots/digests, schema, precedence, escaping, locked-component diff, ontology/manifest validation | block malformed or unauthorized change |
| T1 prompt smoke | relevant PR; minutes | small positive/negative/regression pairs, one clean injection control, baseline comparison | block obvious regression; no rollout authority |
| T2 nightly | scheduled; hours | broader capability, repeated trials, semantic variants, cost, judge health, prompt-family slices | alert/block candidate promotion |
| T3 security | scheduled and candidate; hours/day | direct/indirect injection, extraction, poisoning, evaluator manipulation, resource/fault cases | any critical violation blocks |
| T4 release | frozen candidate; independent | sealed tasks, paired baseline, preregistered statistics, blinded human review, full evaluator health | supplies evidence to governed decision |
| T5 shadow/pilot | staged production | natural tasks, causal/product metrics, guardrails, incidents, human burden | advance, hold, or rollback |

Prompt development remains fast because T0/T1 use targeted cases. Confidence
comes from the independent T3/T4/T5 layers, not from running a huge optimizer
on every edit.

## Minimum prompt change manifest

```yaml
prompt_family: repository_analysis
candidate_revision: sha256:...
baseline_revision: sha256:...
behavior_contract_revision: ...

treatment:
  editable_components: [...]
  locked_components: [...]
  prompt_compiler_revision: ...
  demonstration_set_digest: ...
  context_policy_revision: ...
  tool_schema_digest: ...
  output_schema_revision: ...

hypothesis:
  primary_endpoint: ...
  minimum_effect: ...
  non_inferiority_constraints: [...]
  critical_gates: [...]

data:
  development_revision: ...
  validation_revision: ...
  sealed_catalog_reference: protected:...
  regression_revision: ...
  robustness_revision: ...

experiment:
  model_snapshot: ...
  inference_parameters_digest: ...
  task_assignments_digest: ...
  trials_per_task: ...
  budget: ...
  statistical_plan_revision: ...
  grader_revisions: [...]

result:
  development_run: ...
  validation_run: ...
  security_run: ...
  sealed_run: ...
  exact_numerators_denominators: [...]
  confidence_intervals: [...]
  cost_latency_delta: ...

governance:
  semantic_diff_reviewers: [...]
  security_review_required: true
  rollback_revision: ...
  disposition: proposed
```

The manifest stores revisions and results; it does not embed secrets, raw
protected prompts, or sealed oracle content.

## Phased implementation recommendation

### Phase P0: Baseline and ownership

- inventory prompt families, compilers, examples, tool descriptions, and
  output schemas;
- identify owners and authority-sensitive components;
- content-address current production bundles;
- define behavior contracts and rollback revisions; and
- make renderer output deterministic for fixed inputs where possible.

Exit evidence: every operational prompt can be traced to an immutable bundle,
compiler, model/profile, and owner.

### Phase P1: Prompt test fixtures

- add renderer/precedence/escaping tests;
- create 20-50 high-quality internal prompt tasks spanning coding, review,
  analysis, clean negatives, and hostile cases;
- add explicit development, validation, regression, judge-calibration, and
  protected-test partitions;
- establish failure taxonomy and exact trial records; and
- baseline current prompt families with repeated trials.

Exit evidence: prompt changes can be compared without manual copy/paste or
mutable spreadsheets.

### Phase P2: Metrics and evaluator health

- implement deterministic graders first;
- normalize review findings and analysis claims;
- add semantic variants and order/format perturbations;
- calibrate any model judge against humans and executable truth;
- add mutation, reference, alternate-correct, and negative-control checks; and
- report exact denominators, intervals, slices, cost, and `pass^k`.

Exit evidence: a failed grader-health gate qualifies or invalidates the
affected prompt result.

### Phase P3: Governed prompt experiments

- model prompt bundles as explicit treatments in evaluation profiles;
- add paired baseline/candidate execution;
- require semantic diff and locked-component review;
- record every attempted candidate and optimizer budget;
- freeze validation and sealed-run protocols; and
- integrate prompt-specific staleness and rollback.

Exit evidence: no score or optimizer output can directly change an operational
prompt.

### Phase P4: Optional automatic optimization

- use GEPA for the first feedback-rich compound-prompt experiment when
  deterministic textual feedback and four-way data separation are ready;
- otherwise begin with a simpler APE/ProTeGi-style adapter while the
  measurement system matures;
- compare GEPA, MIPROv2, and a strong human edit under rollout, token, dollar,
  and wall-clock budgets rather than rollout count alone;
- constrain it to development data and non-security components;
- measure total search cost and validation/sealed generalization;
- stop if it does not beat simpler manual/error-cluster editing; and
- keep provider adapters behind a stable, local experiment interface.

Exit evidence: the optimizer demonstrably improves held-out JidoCode outcomes
after accounting for search cost and does not weaken safety, robustness, or
evaluator health.

### Phase P5: Shadow and controlled learning loop

- attach prompt identity to shadow/pilot outcomes;
- measure developer and repository outcomes, not only model grades;
- support randomized or matched prompt experiments under rollout policy;
- ingest incidents only through adjudicated, redacted corpus commands; and
- periodically refresh capability and sealed corpora.

Exit evidence: prompt promotion and rollback can be reconstructed from offline
and production evidence at exact revisions.

## Anti-patterns to reject

1. Editing prompts against the sealed test until the score rises.
2. Reporting the best of many candidates without the search budget or fresh
   confirmation.
3. Calling a model/prompt/tool/context bundle change a “prompt improvement.”
4. Treating one successful anecdote or cherry-picked transcript as an eval.
5. Grading agent claims instead of the environment or artifact.
6. Using one LLM judge as sole truth for correctness or security.
7. Optimizing a target and its judge on the same cases.
8. Averaging critical security failures into a utility score.
9. Omitting timeouts, refusals, invalid trials, or rejected outputs from the
   denominator.
10. Rerunning only failures.
11. Using examples copied from validation, sealed, or production-confidential
    material without partition/provenance controls.
12. Treating delimiters or “ignore injected instructions” as a sandbox.
13. Persisting raw self-reflection as trusted cross-task memory.
14. Allowing an optimizer to remove authority or disclosure constraints.
15. Automatically deploying the optimizer's top-scoring prompt.
16. Using only positive cases and teaching the model to over-trigger a behavior.
17. Letting a saturated regression suite stand in for capability evaluation.
18. Comparing success rates without target tuple, task assignments, `k`,
    budget, denominator, and confidence interval.
19. Depending on a vendor's mutable prompt alias or soon-retired evaluation
    surface as the repository's evidence system.
20. Silently rewriting historical prompt revisions, scores, or corpus
    membership.

## Final recommendation

JidoCode should build the measurement system before adding automatic prompt
search. The near-term sequence is:

1. content-address prompt bundles and compilers;
2. define behavior contracts and explicit success vectors;
3. establish development/validation/sealed/regression/judge partitions;
4. build deterministic outcome graders and evaluator-health checks;
5. compare prompt candidates with paired, repeated, robustness-aware runs;
6. represent candidates and results in the existing governed evaluation graph;
7. require human semantic diff, security gates, and independent sealed
   confirmation; and
8. learn from shadow/pilot outcomes through reviewed regression-corpus updates.

Automatic optimization then becomes a useful, bounded search worker. It can
surface clearer instructions, better examples, and interactions humans would
not explore manually. It remains subordinate to data separation, independent
oracles, security controls, and governed rollout authority.

## References

### Prompting and iterative improvement

- **[PI01]** Jason Wei et al.,
  [Chain-of-Thought Prompting Elicits Reasoning in Large Language Models](https://arxiv.org/abs/2201.11903)
  (NeurIPS 2022). Few-shot intermediate reasoning improved several arithmetic,
  commonsense, and symbolic tasks on sufficiently large models.
- **[PI02]** Xuezhi Wang et al.,
  [Self-Consistency Improves Chain of Thought Reasoning in Language Models](https://arxiv.org/abs/2203.11171)
  (ICLR 2023). Samples diverse reasoning paths and selects the consistent
  answer; the paper reports gains ranging from 3.9 to 17.9 points on its
  principal benchmarks.
- **[PI03]** Shunyu Yao et al.,
  [ReAct: Synergizing Reasoning and Acting in Language Models](https://arxiv.org/abs/2210.03629)
  (ICLR 2023). Interleaves reasoning, actions, and external observations; the
  studied interactive benchmarks improved substantially over baselines.
- **[PI04]** Lei Wang et al.,
  [Plan-and-Solve Prompting: Improving Zero-Shot Chain-of-Thought Reasoning by Large Language Models](https://aclanthology.org/2023.acl-long.147/)
  (ACL 2023). Separates plan creation from subproblem execution and analyzes
  missing-step, calculation, and semantic errors.
- **[PI05]** Aman Madaan et al.,
  [Self-Refine: Iterative Refinement with Self-Feedback](https://proceedings.neurips.cc/paper_files/paper/2023/hash/91edff07232fb1b55a505a9e9f6c0ff3-Abstract-Conference.html)
  (NeurIPS 2023). Uses one model as generator, critic, and refiner; reports
  roughly 20 absolute points of average improvement over one-step generation
  across seven studied tasks.
- **[PI06]** Noah Shinn et al.,
  [Reflexion: Language Agents with Verbal Reinforcement Learning](https://arxiv.org/abs/2303.11366)
  (NeurIPS 2023). Uses verbal feedback and episodic memory to improve later
  trials, motivating strict controls on what feedback becomes durable memory.
- **[PI07]** Anthropic,
  [Effective Context Engineering for AI Agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
  (engineering article). Treats the complete information state and its
  selection as the design object, not prompt wording alone.

### Prompt sensitivity and robustness

- **[PS01]** Zihao Zhao et al.,
  [Calibrate Before Use: Improving Few-shot Performance of Language Models](https://proceedings.mlr.press/v139/zhao21c.html)
  (ICML 2021). Demonstrates instability from format, example selection, and
  order and reports contextual-calibration gains up to 30 absolute points.
- **[PS02]** Yao Lu et al.,
  [Fantastically Ordered Prompts and Where to Find Them: Overcoming Few-Shot Prompt Order Sensitivity](https://aclanthology.org/2022.acl-long.556/)
  (ACL 2022). Shows large order effects and limited transfer of preferred
  orders across models.
- **[PS03]** Melanie Sclar et al.,
  [Quantifying Language Models' Sensitivity to Spurious Features in Prompt Design](https://arxiv.org/abs/2310.11324)
  (ICLR 2024). Reports performance ranges as large as 76 accuracy points across
  meaning-preserving formats and proposes FormatSpread.
- **[PS04]** Moran Mizrahi et al.,
  [State of What Art? A Call for Multi-Prompt LLM Evaluation](https://aclanthology.org/2024.tacl-1.52/)
  (TACL 2024). Evaluates 6.5 million instances, 20 models, and 39 tasks and
  shows prompt paraphrases can change absolute and relative results.
- **[PS05]** Felipe Maia Polo et al.,
  [Efficient Multi-Prompt Evaluation of LLMs](https://arxiv.org/abs/2405.17202)
  (2024 preprint). PromptEval estimates a distribution and quantiles across
  many prompts under limited evaluation budgets.
- **[PS06]** Kaijie Zhu et al.,
  [PromptRobust: Towards Evaluating the Robustness of Large Language Models on Adversarial Prompts](https://arxiv.org/abs/2306.04528)
  (2023 preprint). Tests character-, word-, sentence-, and semantic-level
  perturbations over eight tasks and thirteen datasets.
- **[PS07]** Angelika Romanou et al.,
  [BrittleBench: Quantifying LLM Robustness via Prompt Sensitivity](https://arxiv.org/abs/2603.13285)
  (2026 preprint). Reports clean-to-perturbed degradation, ranking changes, and
  variance attributable to semantics-preserving prompt changes.
- **[PS08]** Ruiyang Qin et al.,
  [Evaluating and Explaining Prompt Sensitivity of LLMs Using Interactions](https://openreview.net/forum?id=GsdFM8qnav)
  (ICML 2026). Proposes an interaction-based sensitivity measure and studies
  model properties associated with sensitivity.

### Automatic prompt optimization

- **[AO01]** Yongchao Zhou et al.,
  [Large Language Models Are Human-Level Prompt Engineers](https://arxiv.org/abs/2211.01910)
  (ICLR 2023). Automatic Prompt Engineer generates and scores instruction
  candidates, matching or exceeding human prompts on 19 of 24 studied tasks.
- **[AO02]** Reid Pryzant et al.,
  [Automatic Prompt Optimization with “Gradient Descent” and Beam Search](https://aclanthology.org/2023.emnlp-main.494/)
  (EMNLP 2023). ProTeGi derives textual critiques from minibatch errors and
  searches prompt edits with beam and bandit procedures.
- **[AO03]** Chengrun Yang et al.,
  [Large Language Models as Optimizers](https://arxiv.org/abs/2309.03409)
  (ICLR 2024). OPRO conditions an optimizer on earlier solutions and scores;
  the paper reports improvements over human instructions on GSM8K and BBH.
- **[AO04]** Chrisantha Fernando et al.,
  [Promptbreeder: Self-Referential Self-Improvement via Prompt Evolution](https://arxiv.org/abs/2309.16797)
  (ICML 2024). Evolves task prompts as well as mutation prompts using
  training-set fitness.
- **[AO05]** Omar Khattab et al.,
  [DSPy: Compiling Declarative Language Model Calls into Self-Improving Pipelines](https://openreview.net/forum?id=sY5N0zY5Od)
  (ICLR 2024). Provides a program abstraction and compiler approach for
  multi-stage LM pipelines.
- **[AO06]** Krista Opsahl-Ong et al.,
  [Optimizing Instructions and Demonstrations for Multi-Stage Language Model Programs](https://arxiv.org/abs/2406.11695)
  (2024 preprint). MIPRO jointly searches module instructions and
  demonstrations with program/data-aware proposals and a surrogate objective.
- **[AO07]** Lakshya A. Agrawal et al.,
  [GEPA: Reflective Prompt Evolution Can Outperform Reinforcement Learning](https://iclr.cc/virtual/2026/poster/10009493)
  (ICLR 2026; [current paper version](https://arxiv.org/abs/2507.19457)).
  GEPA combines trajectory reflection, per-instance Pareto candidate
  selection, prompt mutation, and optional system-aware merging.
- **[AO08]** Mert Yuksekgonul et al.,
  [TextGrad: Automatic “Differentiation” via Text](https://arxiv.org/abs/2406.07496)
  (2024 preprint). Propagates natural-language feedback through compound
  systems and reports improvements in QA and code optimization.
- **[AO09]** Lennart Schneider et al.,
  [Hyperband-based Bayesian Optimization for Black-box Prompt Selection](https://proceedings.mlr.press/v267/schneider25b.html)
  (ICML 2025). Combines a structural prompt surrogate with multi-fidelity
  allocation to reduce selection cost.
- **[AO10]** ChenZhuo Zhao et al.,
  [Gradient-Guided Multi-Judge Prompt Optimization](https://aclanthology.org/2026.acl-long.1089/)
  (ACL 2026). Uses segment attribution and multiple judge losses to reduce
  single-evaluator overfit and improve transfer.
- **[AO11]** Mingqi Li et al.,
  [Learning from Contrastive Prompts: An Automated Prompt Optimization Framework](https://aclanthology.org/2026.findings-acl.9/)
  (Findings of ACL 2026). Derives edit principles by comparing high- and
  low-performing prompt cases.
- **[AO12]** DSPy,
  [GEPA in Depth](https://github.com/stanfordnlp/dspy/blob/main/docs/docs/diving-deeper/gepa-in-depth.md)
  (official implementation documentation, accessed 2026-08-18). Documents the
  feedback contract, Pareto selection, budgets, candidate lineage, merge
  behavior, and reflection-model cost.

### Evaluation, judges, and human measurement

- **[EV01]** Anthropic,
  [Demystifying Evals for AI Agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)
  (2026 engineering article). Defines task/trial/outcome/grader distinctions,
  executable/model/human graders, capability versus regression suites,
  repeated trials, and production learning.
- **[EV02]** Yang Liu et al.,
  [G-Eval: NLG Evaluation Using GPT-4 with Better Human Alignment](https://arxiv.org/abs/2303.16634)
  (EMNLP 2023). Reports improved summarization correlation and flags bias
  toward LLM-generated outputs.
- **[EV03]** Lianmin Zheng et al.,
  [Judging LLM-as-a-Judge with MT-Bench and Chatbot Arena](https://arxiv.org/abs/2306.05685)
  (NeurIPS 2023). Reports strong agreement in its setting while documenting
  position, verbosity, self-enhancement, and reasoning biases.
- **[EV04]** Lin Shi et al.,
  [Judging the Judges: A Systematic Study of Position Bias in LLM-as-a-Judge](https://aclanthology.org/2025.ijcnlp-long.18/)
  (IJCNLP-AACL 2025). Studies more than 150,000 judgments and shows position
  bias is judge- and task-dependent rather than random.
- **[EV05]** Pat Verga et al.,
  [Replacing Judges with Juries: Evaluating LLM Generations with a Panel of Diverse Models](https://arxiv.org/abs/2404.18796)
  (2024 preprint). PoLL reports better studied performance and lower cost than
  one large judge through a diverse panel of smaller models.
- **[EV06]** Chiyu Ma et al.,
  [Judging with Many Minds: On Bias Amplification and Resistance in Multi-Agent Based LLM-as-Judge](https://aclanthology.org/2025.findings-emnlp.941/)
  (Findings of EMNLP 2025). Finds debate can amplify position, verbosity,
  chain-of-thought, and bandwagon biases.
- **[EV07]** Chris van der Lee et al.,
  [Best Practices for the Human Evaluation of Automatically Generated Text](https://aclanthology.org/W19-8643/)
  (INLG 2019). Recommends explicit criteria, adequate samples, multiple
  annotators, agreement reporting, counterbalancing, and preregistration.
- **[EV08]** Jie Ruan et al.,
  [Defining and Detecting Vulnerability in Human Evaluation Guidelines](https://aclanthology.org/2024.naacl-long.441/)
  (NAACL 2024). Finds low guideline availability and frequent vulnerabilities,
  reinforcing that human rubrics must themselves be tested.
- **[EV09]** Ehsan Doostmohammadi et al.,
  [How Reliable Are Automatic Evaluation Methods for Instruction-Tuned LLMs?](https://aclanthology.org/2024.findings-emnlp.367/)
  (Findings of EMNLP 2024). Finds metric reliability highly context-dependent
  and judge effectiveness weaker without references.
- **[EV10]** Hawon Jeong et al.,
  [The Comparative Trap: Pairwise Comparisons Amplifies Biased Preferences of LLM Evaluators](https://aclanthology.org/2025.blackboxnlp-1.5/)
  (BlackboxNLP 2025). Shows direct pairwise comparison can magnify superficial
  bias and motivates pointwise reasoning before comparison.

### Security and adversarial prompting

- **[SE01]** Zekun Li et al.,
  [Evaluating the Instruction-Following Robustness of Large Language Models to Prompt Injection](https://aclanthology.org/2024.emnlp-main.33/)
  (EMNLP 2024). Benchmarks whether models follow intended versus injected
  instructions and reports material vulnerabilities.
- **[SE02]** Junlin Wang et al.,
  [Raccoon: Prompt Extraction Benchmark of LLM-Integrated Applications](https://aclanthology.org/2024.findings-acl.791/)
  (Findings of ACL 2024). Evaluates fourteen prompt-extraction attack
  categories plus compounded attacks and defenses.
- **[SE03]** Divyansh Agarwal et al.,
  [Prompt Leakage Effect and Mitigation Strategies for Multi-Turn LLM Applications](https://aclanthology.org/2024.emnlp-industry.94/)
  (EMNLP Industry 2024). Evaluates multi-turn leakage across models and
  domains and shows attack success can rise sharply through interaction.
- **[SE04]** Sander Schulhoff et al.,
  [Ignore This Title and HackAPrompt: Exposing Systemic Vulnerabilities of LLMs Through a Global Prompt Hacking Competition](https://aclanthology.org/2023.emnlp-main.302/)
  (EMNLP 2023). Provides large-scale free-form human evidence of prompt
  injection and jailbreaking techniques.
- **[SE05]** Qiusi Zhan et al.,
  [InjecAgent: Benchmarking Indirect Prompt Injections in Tool-Integrated Large Language Model Agents](https://aclanthology.org/2024.findings-acl.624/)
  (Findings of ACL 2024). Evaluates indirect instructions delivered through
  external content to agents with tools.

### Official engineering and platform guidance

- **[PR01]** OpenAI,
  [Working with Evals](https://developers.openai.com/api/docs/guides/evals)
  (official documentation, accessed 2026-08-18). Defines a
  describe/run/analyze-and-iterate workflow and records the legacy Evals
  platform's 2026 retirement schedule.
- **[PR02]** OpenAI,
  [Prompt Optimizer](https://developers.openai.com/api/docs/guides/prompt-optimizer)
  (official documentation, accessed 2026-08-18). Uses annotations, critiques,
  and grader results; requires manual review; records the dataset-backed
  optimizer's retirement schedule.
- **[PR03]** OpenAI,
  [Graders](https://developers.openai.com/api/docs/guides/graders)
  (official documentation, accessed 2026-08-18). Recommends grader
  meta-evaluation against expert examples and warns about grader hacking.
- **[PR04]** Anthropic,
  [Building Effective Agents](https://www.anthropic.com/engineering/building-effective-agents)
  (engineering article). Describes evaluator-optimizer, routing,
  parallelization, and orchestration patterns and recommends measured
  complexity.
- **[PR05]** Google Cloud,
  [Announcing Vertex AI Prompt Optimizer](https://cloud.google.com/blog/products/ai-machine-learning/announcing-vertex-ai-prompt-optimizer)
  (official product/research blog). Describes joint instruction/demonstration
  search driven by configured evaluation metrics.
- **[PR06]** OpenAI,
  [Model Optimization](https://developers.openai.com/api/docs/guides/model-optimization)
  (official documentation, accessed 2026-08-18). Places eval baselines before
  prompt and fine-tuning iteration.
- **[PR07]** Google Cloud,
  [Evaluate a Judge Model](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/models/evaluate-judge-model)
  (official documentation, accessed 2026-08-18). Calibrates pointwise and
  pairwise judge metrics against human ratings with balanced accuracy, F1, and
  confusion matrices.

### Online experimentation and controlled rollout

- **[ON01]** Ronny Kohavi et al.,
  [Online Experimentation at Microsoft](https://www.microsoft.com/en-us/research/publication/online-experimentation-at-microsoft/)
  (2009). Explains why randomized controlled experiments support causal
  product decisions.
- **[ON02]** Aleksander Fabijan et al.,
  [Diagnosing Sample Ratio Mismatch in Online Controlled Experiments](https://www.microsoft.com/en-us/research/publication/diagnosing-sample-ratio-mismatch-in-online-controlled-experiments-a-taxonomy-and-rules-of-thumb-for-practitioners/)
  (KDD 2019). Treats assignment-ratio mismatch as a symptom that can invalidate
  experiment inference.
- **[ON03]** Pavel Dmitriev et al.,
  [Pitfalls of Long-Term Online Controlled Experiments](https://www.microsoft.com/en-us/research/?p=683337)
  (IEEE Big Data 2016). Discusses short/long-term mismatch, cookie stability,
  survivorship, selection bias, and perceived trends.
- **[ON04]** Pavel Dmitriev et al.,
  [Safe Velocity: A Practical Guide to Software Deployment at Scale Using Controlled Rollout](https://www.microsoft.com/en-us/research/publication/safe-velocity-a-practical-guide-to-software-deployment-at-scale-using-controlled-rollout/)
  (ICSE-SEIP 2019). Combines staged rollout rings with controlled experiments
  and explicit pass criteria.
- **[ON05]** Widad Machmouchi and Georg Buscher,
  [Principles for the Design of Online A/B Metrics](https://www.microsoft.com/en-us/research/publication/principles-for-the-design-of-online-a-b-metrics/)
  (SIGIR 2016). Covers metric design and interpretation pitfalls for online
  experiments.

## Research follow-ups

The following questions should be answered with JidoCode-specific experiments
rather than more generic literature review:

1. Does GEPA's textual feedback add held-out value over scalar-only search when
   the feedback is produced by JidoCode's deterministic verifier?
2. How much of GEPA's rollout advantage survives after counting reflection
   tokens, grader calls, human labeling, and sealed confirmation?
3. Do prompt optimizers improve review precision and analysis evidence quality,
   or mostly optimize response style?
4. Which prompt components transfer between model families, and which require
   model-specific revisions?
5. What semantic-variant families best predict real developer phrasing and
   context noise?
6. Can a small, diverse judge panel improve triage without amplifying shared
   bias or increasing total cost?
7. Which production measures provide the earliest reliable signal of escaped
   defects, developer burden, and long-term value?
8. What minimum prompt-specific ontology extension provides reproducibility
   without exposing raw prompts, source content, or protected tasks?
