---
id: plan.jido_code_graph_factory_phase_09
intent: control_plane_change
source:
  - docs/research/graph-native-managed-repository-factory.md
---

# Phase 9 - Evidence, Decision, Knowledge Adoption, And Reasoning

This phase turns raw execution outcomes into governed verification evidence,
accepts or rejects precise claims and goals through policy-authorized decisions,
adopts durable repository knowledge with provenance and supersession, and
materializes bounded OWL/rule inferences that remain rebuildable and
non-authoritative.

Back to plan: [README](./README.md)

- [ ] 9 Phase - Govern how execution results become accepted outcomes and reusable knowledge.

  This phase closes the epistemic boundary: tools and agents may generate
  claims and artifacts, but only verification plus an authorized decision can
  satisfy work or adopt knowledge for future factory behavior.

  - [x] 9.1 Section - Implement verification activities and evidence bundles.

    This section evaluates exact artifacts, snapshots, claims, and goals under
    versioned methods and packages the result as support or contradiction
    rather than a generic success flag.

    - [x] 9.1.1 Task {#jcf-p09-verification-contract} [repo: jido_code] [after: {#jcf-p08-phase-receipt}] - Define verification method and activity contracts.

      This task makes tests, reviews, policy checks, source comparisons, and
      provider confirmations reproducible and explicit about what they can
      prove.

      - [x] 9.1.1.1 Subtask {#jcf-p09-9-1-1-1} - Define verification method identity/version, input classes, expected claims, completeness requirements, evaluator capability, environment, bounds, and interpretation limits.
      - [x] 9.1.1.2 Subtask {#jcf-p09-9-1-1-2} - Define verification activities with attempt/task/goal, exact source/proposed/post-change snapshot, artifact digests, method/version, actor/evaluator, start/end, and raw bounded outcome refs.
      - [x] 9.1.1.3 Subtask {#jcf-p09-9-1-1-3} - Distinguish test execution, static analysis, semantic comparison, human review, policy check, security review, and external-provider confirmation.
      - [x] 9.1.1.4 Subtask {#jcf-p09-9-1-1-4} - Require strict input freshness and reject unavailable/mismatched artifacts, stale source graphs, incomplete suites, wrong environments, and unsupported method versions.
      - [x] 9.1.1.5 Subtask {#jcf-p09-9-1-1-5} - Keep evaluator conclusions advisory until evidence construction and decision policy accept them.

    - [x] 9.1.2 Task {#jcf-p09-evidence-bundle} [repo: jido_code] [after: {#jcf-p09-verification-contract}] - Implement `RecordVerificationEvidence` and evidence-bundle construction.

      This task creates a governed semantic collection that connects precise
      verification outputs to the claims and goals they support or contradict.

      - [x] 9.1.2.1 Subtask {#jcf-p09-9-1-2-1} - Require verification activity/method, input graph/artifact/snapshot revisions, generated claims, support/contradiction targets, evaluator, completeness, limitations, and idempotency.
      - [x] 9.1.2.2 Subtask {#jcf-p09-9-1-2-2} - Validate every cited artifact digest, attempt provenance, source snapshot, claim proposition, and authorized evidence writer capability.
      - [x] 9.1.2.3 Subtask {#jcf-p09-9-1-2-3} - Record evidence strength/classification, coverage, failures, skipped/unknown checks, environmental limits, validity interval, and supersession links without equating confidence with acceptance.
      - [x] 9.1.2.4 Subtask {#jcf-p09-9-1-2-4} - Commit evidence and generated claim resources atomically in the repository evidence graph with provenance and audit.
      - [x] 9.1.2.5 Subtask {#jcf-p09-9-1-2-5} - Reject evidence bundles that cite unverified content, broaden scope, hide failed mandatory checks, or originate from the same agent when policy requires independent evaluation.

    - [x] 9.1.3 Task {#jcf-p09-evidence-requirements} [repo: jido_code] [after: {#jcf-p09-evidence-bundle}] - Implement policy-driven evidence sufficiency evaluation.

      This task compares collected evidence with goal/policy requirements and
      returns an explainable readiness assessment, not a decision.

      - [x] 9.1.3.1 Subtask {#jcf-p09-9-1-3-1} - Resolve required method classes, independent reviewers, freshness, coverage, environments, security checks, post-change observations, and waiver rules from exact policy/plan revisions.
      - [x] 9.1.3.2 Subtask {#jcf-p09-9-1-3-2} - Evaluate supporting/contradicting evidence, supersession, validity, artifact/snapshot consistency, missing/unknown checks, and policy conflicts under declared complete graphs.
      - [x] 9.1.3.3 Subtask {#jcf-p09-9-1-3-3} - Return sufficient, insufficient, contradicted, stale, incomplete, policy-conflicted, or waiver-required with exact explanation paths.
      - [x] 9.1.3.4 Subtask {#jcf-p09-9-1-3-4} - Prohibit sufficiency output from transitioning goals or accepting claims directly.

    - [x] 9.1.4 Task {#jcf-p09-evidence-projections} [repo: jido_code] [after: {#jcf-p09-evidence-requirements}] - Implement evidence and verification projections.

      This task gives operators and decision services bounded views over what
      was checked, what was proved, what failed, and what remains unknown.

      - [x] 9.1.4.1 Subtask {#jcf-p09-9-1-4-1} - Add evidence-by-goal/claim/attempt/artifact, verification timeline, support/contradiction, sufficiency, stale evidence, and missing requirement queries.
      - [x] 9.1.4.2 Subtask {#jcf-p09-9-1-4-2} - Include exact method/policy/source/run/query revisions, evaluator authority, validity, coverage, limitations, and truncation.
      - [x] 9.1.4.3 Subtask {#jcf-p09-9-1-4-3} - Preserve failed/skipped checks and contradictory evidence in projections instead of summarizing them away.
      - [x] 9.1.4.4 Subtask {#jcf-p09-9-1-4-4} - Redact sensitive artifacts and require separate authorization for raw retained outputs.

  - [x] 9.2 Section - Implement governed decisions and outcome transitions.

    This section grants acceptance authority only through explicit decisions
    that cite policy, evidence, actor, scope, and exact graph revisions.

    - [x] 9.2.1 Task {#jcf-p09-decision-command} [repo: jido_code] [after: {#jcf-p09-evidence-projections}] - Implement `DecideGoalOutcome` and claim disposition semantics.

      This task records accept, reject, defer, waive, supersede, or request-more
      outcomes without letting the decider mutate external systems implicitly.

      - [x] 9.2.1.1 Subtask {#jcf-p09-9-2-1-1} - Require decision IRI/type, actor/delegation, goal/claim/evidence targets, exact sufficiency/policy/source/control revisions, disposition, rationale refs, validity, and idempotency.
      - [x] 9.2.1.2 Subtask {#jcf-p09-9-2-1-2} - Authorize human, policy-automatic, or delegated agent decisions separately by risk, scope, evidence class, and disposition.
      - [x] 9.2.1.3 Subtask {#jcf-p09-9-2-1-3} - Reevaluate evidence sufficiency, contradictions, stale inputs, policy version, actor separation, and goal/lease/attempt state in the transaction snapshot.
      - [x] 9.2.1.4 Subtask {#jcf-p09-9-2-1-4} - Atomically record decision, accepted/rejected/waived claim state, goal/task/obligation transitions, follow-up relation, provenance, audit, and revisions.
      - [x] 9.2.1.5 Subtask {#jcf-p09-9-2-1-5} - Reject self-acceptance, stale evidence, policy bypass, cross-scope disposition, contradictory mandatory evidence, and direct side effects.

    - [x] 9.2.2 Task {#jcf-p09-goal-satisfaction} [repo: jido_code] [after: {#jcf-p09-decision-command}] - Implement goal, obligation, and desired-outcome satisfaction semantics.

      This task ensures satisfaction describes an accepted observed outcome,
      not merely a completed attempt or approved patch.

      - [x] 9.2.2.1 Subtask {#jcf-p09-9-2-2-1} - Require evidence that addresses the goal's precise proposition and accepted policy requirements at the applicable repository/post-change snapshot.
      - [x] 9.2.2.2 Subtask {#jcf-p09-9-2-2-2} - Permit patch approval to create an application/follow-up goal while reserving final satisfaction for post-change observation/verification where policy requires it.
      - [x] 9.2.2.3 Subtask {#jcf-p09-9-2-2-3} - Propagate satisfaction to tasks, obligations, and desired outcomes only through explicit graph rules and decision transitions.
      - [x] 9.2.2.4 Subtask {#jcf-p09-9-2-2-4} - Reopen or supersede satisfaction when later valid evidence contradicts the accepted claim according to policy, preserving original decision history.
      - [x] 9.2.2.5 Subtask {#jcf-p09-9-2-2-5} - Reconcile dependent goals and plans after acceptance/rejection without mutating them inside the decision implementation.

    - [x] 9.2.3 Task {#jcf-p09-follow-up-control} [repo: jido_code] [after: {#jcf-p09-goal-satisfaction}] - Implement decision-triggered follow-up and external-change confirmation.

      This task feeds governed outcomes back into the control loop instead of
      hiding additional actions in decision callbacks.

      - [x] 9.2.3.1 Subtask {#jcf-p09-9-2-3-1} - Express apply-patch, open/update pull request, request review, remediate failure, gather evidence, rollback, or monitor outcomes as new or related goals/tasks.
      - [x] 9.2.3.2 Subtask {#jcf-p09-9-2-3-2} - Require new leases/attempts for every effectful follow-up and preserve causation to the decision.
      - [x] 9.2.3.3 Subtask {#jcf-p09-9-2-3-3} - Observe provider/Git post-change state through Phase 6 ingress and link confirmations or contradictions to the decision/goal.
      - [x] 9.2.3.4 Subtask {#jcf-p09-9-2-3-4} - Make follow-up derivation idempotent and supersede it when decision or external state changes.

    - [x] 9.2.4 Task {#jcf-p09-decision-projections} [repo: jido_code] [after: {#jcf-p09-follow-up-control}] - Implement decision and accepted-outcome projections.

      This task lets operators inspect who decided what, under which policy and
      evidence, and what downstream state changed.

      - [x] 9.2.4.1 Subtask {#jcf-p09-9-2-4-1} - Add decision-by-goal/claim/evidence/actor, satisfaction path, waiver, rejection, deferred action, supersession, and follow-up queries.
      - [x] 9.2.4.2 Subtask {#jcf-p09-9-2-4-2} - Project evidence sufficiency, contradictory evidence, actor/delegation, policy/decision versions, exact source snapshots, transitions, and current validity.
      - [x] 9.2.4.3 Subtask {#jcf-p09-9-2-4-3} - Distinguish attempt completion, patch approval, external application, post-change verification, and final goal satisfaction.
      - [x] 9.2.4.4 Subtask {#jcf-p09-9-2-4-4} - Bound rationale display to authored explanation refs and never require or expose chain-of-thought.

  - [x] 9.3 Section - Implement governed knowledge adoption and retrieval.

    This section makes durable repository memory a set of accepted knowledge
    assertions linked to evidence and decisions rather than a separate record
    store or transcript cache.

    - [x] 9.3.1 Task {#jcf-p09-adoption-command} [repo: jido_code] [after: {#jcf-p09-decision-projections}] - Implement `AdoptKnowledge` semantics.

      This task promotes a bounded accepted claim into reusable repository or
      factory knowledge under explicit scope, classification, and validity.

      - [x] 9.3.1.1 Subtask {#jcf-p09-9-3-1-1} - Require accepted source claim/decision/evidence, adoption actor/policy, repository/cohort scope, knowledge classification, validity, confidence/limitations, and expected memory revision.
      - [x] 9.3.1.2 Subtask {#jcf-p09-9-3-1-2} - Define classifications for fact, convention, decision, lesson, pattern, known issue, risk, workaround, preference, and open question as controlled concepts.
      - [x] 9.3.1.3 Subtask {#jcf-p09-9-3-1-3} - Record `KnowledgeAssertion` and `AdoptionActivity` in the memory graph with direct links to all source claims, evidence, decisions, snapshots, actors, and policy versions.
      - [x] 9.3.1.4 Subtask {#jcf-p09-9-3-1-4} - Reject raw prompt/tool output, unaccepted claims, stale/contradicted evidence, over-broad scope, unsupported classification, and secret-bearing content.
      - [x] 9.3.1.5 Subtask {#jcf-p09-9-3-1-5} - Make identical adoption idempotent and preserve independently adopted compatible assertions as explicit support.

    - [x] 9.3.2 Task {#jcf-p09-knowledge-evolution} [repo: jido_code] [after: {#jcf-p09-adoption-command}] - Implement knowledge update, contradiction, invalidation, and supersession.

      This task preserves the history and evidence behind changing repository
      knowledge instead of editing a memory record in place.

      - [x] 9.3.2.1 Subtask {#jcf-p09-9-3-2-1} - Implement `SupersedeClaim` and knowledge supersession with replacement assertion, evidence, decision, actor, scope, validity, and expected memory revision.
      - [x] 9.3.2.2 Subtask {#jcf-p09-9-3-2-2} - Link later contradictory observations/evidence to active knowledge and derive a review-required state without automatic deletion.
      - [x] 9.3.2.3 Subtask {#jcf-p09-9-3-2-3} - Distinguish superseded, invalidated, expired, contradicted, under-review, and still-valid assertions through transition/epistemic semantics.
      - [x] 9.3.2.4 Subtask {#jcf-p09-9-3-2-4} - Preserve prior adoption/decision context and prevent current retrieval from returning obsolete assertions without explicit historical mode.

    - [x] 9.3.3 Task {#jcf-p09-knowledge-retrieval} [repo: jido_code] [after: {#jcf-p09-knowledge-evolution}] - Implement bounded, policy-aware knowledge retrieval.

      This task supplies future reconciliation and execution with relevant
      accepted knowledge while exposing provenance, conflicts, and omissions.

      - [x] 9.3.3.1 Subtask {#jcf-p09-9-3-3-1} - Query by repository/cohort, goal/task, source entity, policy, classification, validity, and relationship neighborhood under exact memory/source revisions.
      - [x] 9.3.3.2 Subtask {#jcf-p09-9-3-3-2} - Rank through reviewed deterministic policy using scope specificity, recency/validity, supporting decisions/evidence, contradiction, and task relevance.
      - [x] 9.3.3.3 Subtask {#jcf-p09-9-3-3-3} - Return bounded assertions with source/evidence/decision refs, confidence/limitations, validity, contradiction, truncation, and selection explanation.
      - [x] 9.3.3.4 Subtask {#jcf-p09-9-3-3-4} - Keep short-term prompt context ephemeral; persist it only when a separate adoption command accepts a durable takeaway.
      - [x] 9.3.3.5 Subtask {#jcf-p09-9-3-3-5} - Reauthorize and re-query knowledge for every new execution context rather than carrying stale prompt memory between attempts.

  - [ ] 9.4 Section - Implement bounded reasoning and cross-graph learning.

    This section uses `TripleStore` reasoning and versioned rules to enrich
    classification and discovery while retaining asserted/derived and
    proposed/accepted authority boundaries.

    - [ ] 9.4.1 Task {#jcf-p09-reasoning-service} [repo: jido_code] [after: {#jcf-p09-knowledge-retrieval}] - Implement versioned OWL 2 RL and rule materialization.

      This task produces rebuildable derived graphs from exact asserted inputs
      under bounded resource and publication controls.

      - [ ] 9.4.1.1 Subtask {#jcf-p09-9-4-1-1} - Define allowed OWL 2 RL profiles and project rules for class hierarchy, capability hierarchy, repository/cohort classification, dependency transitivity where safe, and knowledge applicability.
      - [ ] 9.4.1.2 Subtask {#jcf-p09-9-4-1-2} - Build each rule-set output in an isolated derived graph with source revisions, ontology/rule version, generation activity, counts, limits, and validation report.
      - [ ] 9.4.1.3 Subtask {#jcf-p09-9-4-1-3} - Atomically publish complete output, mark it stale on source commits, and retain prior derived revisions only under explicit retention policy.
      - [ ] 9.4.1.4 Subtask {#jcf-p09-9-4-1-4} - Prevent inference from issuing commands, granting authorization/leases, accepting evidence, satisfying goals, or adopting knowledge.
      - [ ] 9.4.1.5 Subtask {#jcf-p09-9-4-1-5} - Bound entailment size, iterations, time, memory, graph scope, and recursive/pathological ontology inputs.

    - [ ] 9.4.2 Task {#jcf-p09-cross-graph-insight} [repo: jido_code] [after: {#jcf-p09-reasoning-service}] - Implement explainable cross-repository knowledge discovery.

      This task exploits the knowledge graph for fleet patterns and candidate
      improvements without turning correlations into accepted truth.

      - [ ] 9.4.2.1 Subtask {#jcf-p09-9-4-2-1} - Add bounded queries for shared dependencies, repeated findings/failures, policy outcome patterns, reusable evidence methods, related source symbols, and applicable accepted lessons.
      - [ ] 9.4.2.2 Subtask {#jcf-p09-9-4-2-2} - Generate proposed findings or goals with source repository set, rule/query version, confidence, limitations, and no automatic acceptance.
      - [ ] 9.4.2.3 Subtask {#jcf-p09-9-4-2-3} - Preserve tenant/repository visibility and prevent one repository's confidential knowledge from leaking through cohort counts, labels, or explanations.
      - [ ] 9.4.2.4 Subtask {#jcf-p09-9-4-2-4} - Require independent evidence and policy authorization before applying learned proposals to another repository.

    - [ ] 9.4.3 Task {#jcf-p09-learning-feedback} [repo: jido_code] [after: {#jcf-p09-cross-graph-insight}] - Feed accepted outcomes into future reconciliation and execution safely.

      This task closes the learning loop through reviewed projections rather
      than hidden mutable agent memory.

      - [ ] 9.4.3.1 Subtask {#jcf-p09-9-4-3-1} - Add accepted knowledge and valid derived classifications to reconciliation input with exact versions, provenance, and contradiction state.
      - [ ] 9.4.3.2 Subtask {#jcf-p09-9-4-3-2} - Add bounded relevant knowledge to execution context with selection explanation, visibility, and prompt budget.
      - [ ] 9.4.3.3 Subtask {#jcf-p09-9-4-3-3} - Invalidate/rebuild affected reconciliation, eligibility, and context projections when knowledge or reasoning revisions change.
      - [ ] 9.4.3.4 Subtask {#jcf-p09-9-4-3-4} - Measure whether adopted knowledge improved outcomes as new observations/evidence, never by editing confidence silently.

  - [ ] 9.5 Section - Phase 9 Integration Tests.

    This final section proves the complete execution-to-acceptance-to-learning
    loop preserves evidence, policy, actor, temporal, contradiction, and
    asserted/derived authority under stale data, self-approval attempts,
    retries, and later contradictory observations.

    - [ ] 9.5.1 Task {#jcf-p09-outcome-integration} [repo: jido_code] [after: {#jcf-p09-learning-feedback}] - Execute verification, evidence, decision, and final satisfaction scenarios.

      This task validates that runtime completion alone is insufficient and
      that accepted outcomes cite complete policy/evidence paths.

      - [ ] 9.5.1.1 Subtask {#jcf-p09-9-5-1-1} - Verify a completed patch with tests/review, record supporting and contradictory evidence, evaluate sufficiency, decide, apply through follow-up work, observe post-change state, and satisfy the goal.
      - [ ] 9.5.1.2 Subtask {#jcf-p09-9-5-1-2} - Exercise failed/skipped checks, stale artifacts, mismatched snapshots, missing independent review, policy conflict, waiver, defer, reject, and request-more-evidence paths.
      - [ ] 9.5.1.3 Subtask {#jcf-p09-9-5-1-3} - Attempt agent self-approval, decision replay, stale sufficiency receipt, cross-scope evidence, hidden mandatory failure, and direct decision side effects.
      - [ ] 9.5.1.4 Subtask {#jcf-p09-9-5-1-4} - Verify goal/task/obligation/desired-outcome transitions and follow-up reconciliation remain atomic, causal, idempotent, and explainable.

    - [ ] 9.5.2 Task {#jcf-p09-learning-reasoning-integration} [repo: jido_code] [after: {#jcf-p09-outcome-integration}] - Exercise adoption, supersession, reasoning, and cross-repository reuse.

      This task proves durable knowledge remains governed and derived insight
      remains disposable and non-authoritative.

      - [ ] 9.5.2.1 Subtask {#jcf-p09-9-5-2-1} - Adopt an accepted lesson, retrieve it for a related goal/context, then introduce contradictory evidence and supersede/invalidate it through a new decision.
      - [ ] 9.5.2.2 Subtask {#jcf-p09-9-5-2-2} - Reject adoption of raw prompt/tool output, unaccepted claims, stale evidence, over-broad scope, and secret-bearing content.
      - [ ] 9.5.2.3 Subtask {#jcf-p09-9-5-2-3} - Materialize, query, stale, delete, and rebuild OWL/rule graphs and prove asserted truth, decisions, and accepted knowledge remain unchanged.
      - [ ] 9.5.2.4 Subtask {#jcf-p09-9-5-2-4} - Derive a cross-repository candidate insight, preserve authorization/concealment, and require independent adoption before it affects the target repo.
      - [ ] 9.5.2.5 Subtask {#jcf-p09-9-5-2-5} - Backup/restore and reconstruct an exact decision plus knowledge retrieval context from graph revisions.
      - [ ] 9.5.2.6 Subtask {#jcf-p09-9-5-2-6} - Rerun Phases 1-8 suites and `mix precommit`.

    - [ ] 9.5.3 Task {#jcf-p09-phase-receipt} [repo: jido_code] [after: {#jcf-p09-learning-reasoning-integration}] - Publish the Phase 9 accepted-outcome and learning receipt.

      This task binds G8 to exact verification, evidence, policy, decision,
      satisfaction, adoption, supersession, reasoning, retrieval, and
      cross-repository evidence.

      - [ ] 9.5.3.1 Subtask {#jcf-p09-9-5-3-1} - Record method/policy/query/rule/ontology versions, scenario/snapshot/artifact/evidence digests, decision/adoption refs, and candidate commit.
      - [ ] 9.5.3.2 Subtask {#jcf-p09-9-5-3-2} - Attach positive/negative sufficiency, self-approval, stale evidence, follow-up, contradiction, supersession, rebuild, cross-repo authorization, restore, and explanation results.
      - [ ] 9.5.3.3 Subtask {#jcf-p09-9-5-3-3} - Keep G8 blocked if runtime output can become accepted directly, knowledge can lose provenance, or inference can mutate control/acceptance state.
      - [ ] 9.5.3.4 Subtask {#jcf-p09-9-5-3-4} - Pin the merged candidate commit before authorizing Phase 10.
