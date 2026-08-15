## 3. Total Agent Memory For Long-Lived Software Engineering

- Status: research proposal, not an accepted architecture decision
- Evidence cutoff: 2026-08-15
- Scope: JidoCode agent execution, repository maintenance, provenance,
  retrieval, learning, privacy, and retention

This document analyzes extensions but does not itself override:

- [Graph-Only Source Of Truth](../adr/0001-graph-only-source-of-truth.md)
- [TripleStore Backend Contract](../adr/0002-triple-store-backend-contract.md)
- [Graph Identity And Topology](../architecture/graph-identity-and-topology.md)
- [Execution Runtime Boundary](../architecture/execution-runtime-boundary.md)
- [Execution Effects And Provenance](../architecture/execution-effects-provenance.md)
- [Execution Provenance And Recovery](../architecture/execution-provenance-and-recovery.md)
- [Verification And Evidence Boundary](../architecture/verification-evidence-boundary.md)
- [Governed Decision Outcomes](../architecture/governed-decision-outcomes.md)
- [Governed Knowledge Memory](../architecture/governed-knowledge-memory.md)
- [Product Security, Privacy, And Threat Model](../architecture/product-security-privacy-and-threat-model.md)
- [Secure And Effective Agent Harness](./secure-effective-agent-harness.md)

Any profile below that would retain a content class currently required to remain
ephemeral is a conditional alternative. It cannot ship until an explicit
superseding privacy/harness contract and, where needed, ADR is accepted.

## Executive Decision

JidoCode should pursue **total memory as complete accounting of experience, not
as indiscriminate retention or automatic reuse of every byte**.

The useful target is:

> Preserve every authorized, decision-relevant event with provenance and an
> explicit state for its content; retain enough governed evidence to
> reconstruct and investigate work; derive episodic, semantic, procedural, and
> artifact-grounded memories; retrieve only a small authorized and time-correct
> evidence packet; and never let archived content become authority merely
> because it was remembered.

This means the system should be able to answer a body's capture outcome,
representation, storage location, availability, retention/erasure progress, and
hold state, even when policy forbids retaining the body itself. That is **total
accounting**. It is more defensible and more useful than claiming that every
prompt, transcript, tool byte, or hidden thought remains forever.

The research supports five conclusions:

1. Long-lived memory can improve task continuity, failure recovery, repair
   reuse, test selection, localization, migration work, incident response, and
   organizational learning.
2. The strongest software-agent value comes from exact events, failures,
   artifact-grounded claims, and validated procedures, not from replaying an
   undifferentiated chat transcript.
3. Raw evidence must remain available behind lossy summaries when exact
   debugging, re-interpretation, or audit is a stated purpose. A digest without
   retrievable content proves identity but does not provide recall.
4. More retrieved memory can reduce performance. Retrieval needs authorization,
   temporal eligibility, provenance, applicability, freshness, diversity, and
   strict context budgets.
5. Automatic retention plus automatic retrieval creates a persistent integrity
   boundary. Memory poisoning, stale procedures, secrets, personal data, and
   cross-tenant leakage can influence future actions long after the source event.

The recommended architecture is an append-only evidence foundation with
separate derived memory products:

```text
governed episode events and multidimensional content state
  -> temporal semantic facts and causal links
  -> episodic cases and failure memories
  -> validated procedural skills and workflows
  -> artifact-grounded verification claims
  -> accepted repository knowledge
  -> disposable lexical, graph, dense, and summary indexes
  -> phase-aware retrieval packet for a future agent
```

The graph remains the durable authority for identity, provenance, policy,
sequence, scope, retention, evidence, and memory status. A literal large-payload
archive requires a separate architecture decision: either store bounded chunks
inside new governed graph families, or supersede ADR 0001 to permit an
application-owned encrypted content vault whose objects have no authority
without their graph records.

## Research Questions

This research asks:

- What can a future software agent gain from prompts, messages, model outputs,
  tool outputs, patches, tests, reviews, incidents, and outcomes from earlier
  work?
- Which memory forms have demonstrated benefits, and under what benchmarks and
  limitations?
- What should remain verbatim, what should be normalized, what should be
  promoted into reusable knowledge, and what should never be retained?
- How should a graph-native system represent time, contradiction, causality,
  provenance, confidence, retention, and erasure?
- How can future agents query a large history without context overload,
  benchmark leakage, memory poisoning, or stale guidance?
- What changes would JidoCode need without creating a second source of truth?

## Method And Evidence Quality

The review covers peer-reviewed papers, public preprints, standards, official
project documentation, and practitioner reports available through the evidence
cutoff. Evidence is interpreted conservatively:

- Results are not compared across different models, prompts, harnesses, context
  budgets, judges, or benchmark versions as if they were one leaderboard.
- Vendor-authored memory benchmarks are implementation evidence, not neutral
  proof of architectural superiority.
- Conversational-memory results are not assumed to transfer directly to
  repository maintenance.
- Very recent 2026 software-agent preprints are design signals requiring
  independent reproduction.
- Human cognitive categories are useful responsibility boundaries, not proof
  that an agent should imitate human biology.
- Legal discussion identifies design obligations and is not jurisdiction-
  specific legal advice.

## Definitions

### Total Capture

Every eligible event crosses one capture decision. The system either retains
its content or records why it did not. Silent loss is not allowed.

### Total Accounting

Every attempted capture has a durable identity, actor, source, sequence,
classification, policy, and content-state dimensions. Accounting can be complete even
when sensitive content is deliberately absent.

### Total Recall

Authorized queries can locate any retained event or derived memory within its
declared retention and completeness boundary. Recall is not guaranteed for
redacted, erased, provider-private, or never-observed content.

### Working Memory

The bounded context used for the current model turn: objective, plan phase,
selected evidence, recent observations, and remaining budget. It is not the
durable memory system.

### Episodic Memory

What happened in one attempt or related sequence of attempts: inputs, actions,
observations, failures, corrections, artifacts, decisions, and outcomes.

### Semantic Memory

Versioned facts about repositories, systems, APIs, architecture, conventions,
ownership, incidents, and constraints. Facts retain their source and temporal
validity.

### Procedural Memory

Reusable workflows and skills: triggers, preconditions, ordered steps, expected
evidence, stop conditions, known exceptions, success/failure history, and last
validation.

### Prospective Memory

Authorized future intentions such as deferred checks, unresolved questions,
follow-up migrations, review dates, or actions waiting on an external condition.

### Artifact-Grounded Memory

A claim tied to exact repository revision, path or symbol, content hash,
verification command, result, evidence strength, and freshness. It can be
invalidated when the supporting artifact changes without erasing history.

### Archive, Memory, And Authority

These are distinct:

| Concept | Purpose | Trust |
| --- | --- | --- |
| Archive | Preserve eligible historical evidence | Untrusted content with governed provenance |
| Retrieval memory | Select potentially relevant past material | Suggestive and non-authoritative |
| Accepted knowledge | Represent a proposition accepted through policy and evidence | Authoritative only in its stated scope and validity |
| Security/control state | Decide what may happen | Never derived automatically from archive frequency or similarity |

## Current JidoCode Baseline

### Binding Invariant

ADRs 0001 and 0002 require all durable application-owned control, workflow,
knowledge, user-authored state, and factory history to remain RDF in one embedded
TripleStore dataset. Named graphs define authority, lifecycle, provenance, and
retention. A new application-owned blob store requires a superseding ADR.

Provider systems, Git, CI, and issue trackers remain external authorities.
Credentials remain in external secret providers. Worktrees, sandboxes, process
state, telemetry, and caches are disposable. Large artifacts can currently be
provider-owned while the graph stores immutable URI, digest, media type, byte
count, provenance, and verification.

### Existing Memory Surfaces

JidoCode already retains more historical information than a narrow knowledge
graph:

| Surface | Existing durable information |
| --- | --- |
| Observation graphs | Normalized provider events, source/retrieval time, digests, completeness, limitations |
| Source graphs | Paths, content digests, symbols, relations, language, analyzer provenance |
| Control graphs | Goals, tasks, plans, leases, policies, interaction sessions, messages, decisions |
| Run graphs | Attempt instructions, constraints, context digest, graph revisions, transitions, tool invocations, bounded outputs, artifacts, sandbox and closure provenance |
| Evidence graphs | Verification methods, activities, check results, claims, limitations, source and artifact bindings |
| Memory graphs | Accepted propositions, provenance, scope, confidence, validity, contradiction, invalidation, supersession |
| Audit graphs | Command, actor, scope, policy, change-set and canonical addition digests |
| Derived graphs | Rebuildable inferences and indexes with source/rule revisions |

Current execution and memory are deliberately separated. A completed run does
not prove correctness, evidence does not accept itself, a decision does not
perform publication, and an archived event does not become accepted memory.

### Current Content Reality

The accepted prose and current implementation need reconciliation before total
memory work begins:

| Content | Policy/document claim | Current implementation |
| --- | --- | --- |
| Prompt | No durable graph location | One bounded execution `Instruction.content` literal is persisted in the run graph; source items, knowledge, system contract, tools, and serialization are separate, so this is not an exact assembled model prompt, but its placement still conflicts with the unresolved prompt classification |
| Interaction message | Bounded semantic messages are graph resources | Up to 4,096 bytes of normalized content is stored in control or run graphs, or `[REDACTED]` |
| Tool output | Policy says no raw durable location and evidence reads only references | `ToolInvocation` stores up to 65,536 combined bytes of stdout/stderr after secret checks; ordinary projections expose digests, not bodies |
| Transcript | No transcript store | A transcript can be reconstructed as a bounded query over message resources, but provider-internal turns are not complete |
| Source body | Source graph or governed artifact only | Source analysis normally stores structural facts and digests, not complete file bodies |
| Artifact content | Bounded embedded text or provider-owned external object | Embedded public/internal text is capped; external content is digest-checked on use |
| Private reasoning | Not required or represented | No accepted private chain-of-thought resource |

Renaming a full prompt as an instruction or bounded stdout as non-raw does not
resolve classification. The ontology, shared data policy, command validation,
query authorization, retention, export, backup, and erasure contracts must agree
on the actual bytes stored.

### Current Retention Reality

The current graph-family defaults retain run history for 180 days, observations
for 90 days, source history for 365 days, and control/evidence/knowledge/audit
history for 2,555 days before archive eligibility. The current retention planner
implements `archive`, `remove`, and `erase` as removal from the active dataset;
there is no cold queryable archive. Restore floors prevent removed data from
being reactivated, but backup artifact deletion is not yet a physical-erasure
guarantee.

Literal long-term total recall therefore requires new retention semantics,
resource-level classification, queryable archival design, and backup/key
erasure. The current graph-family retention granularity is too coarse for a run
that mixes instructions, personal messages, tool output, metadata, and durable
provenance.

## What Complete Historical Evidence Can Provide

### Continuity Across Attempts And Agents

An agent can resume from an exact accepted checkpoint without depending on a
surviving process or provider session. It can see what was attempted, which
assumptions were disproved, which artifacts exist, which checks remain, and why
the prior attempt ended. This prevents repeated exploration and supports agent
replacement over projects that last longer than one model context or process.

### Failure As A First-Class Asset

Failed commands, rejected patches, flaky tests, invalid assumptions, provider
errors, and unsuccessful migrations often carry more information than a final
success summary. [Reflexion](https://proceedings.neurips.cc/paper_files/paper/2023/hash/1b44b878bb782e6954cd888628510e90-Abstract-Conference.html)
improved retries by retaining verbal feedback, and
[ExpeL](https://doi.org/10.1609/aaai.v38i17.29936) learned editable insights
from successful and failed trajectories. For software, the memory must retain
the exact failing evidence behind any generated diagnosis so the diagnosis can
later be challenged.

### Problem Localization

Past issue-to-patch links, error signatures, changed symbols, call/dependency
neighbors, failing tests, ownership, and incidents can help rank where to look.
[BugLocator](https://doi.org/10.1109/ICSE.2012.6227210) showed the value of
similar fixed bugs for file localization, while
[RepoGraph](https://arxiv.org/abs/2410.14684) improved several SWE-bench Lite
systems with repository relations. RepoGraph also found that broad two-hop
flattening could underperform a baseline, directly warning against indiscriminate
history expansion.

### Repair And Workflow Reuse

Past trajectories can be distilled into repository comprehension patterns,
repair procedures, and executable skills.
[Agent Workflow Memory](https://proceedings.mlr.press/v267/wang25bx.html)
reported relative success gains on web-navigation tasks by inducing reusable
workflows. [Voyager](https://arxiv.org/abs/2305.16291) demonstrated an executable
skill library with environmental feedback. The software-specific
[SWE-Exp](https://arxiv.org/abs/2507.23361) reports gains from successful and
failed repair experiences, but also reports that inserting multiple experiences
can hurt. The product implication is selective, applicability-checked reuse,
not a prompt full of precedents.

### Historical Test Selection And Flake Reasoning

Historical change/test outcomes can reduce feedback cost and improve test
ordering. Facebook's
[Predictive Test Selection](https://arxiv.org/abs/1810.05286) reported roughly
halving test infrastructure cost while retaining more than 95% of individual
failures and more than 99.9% of faulty changes in its production setting.
Historical environment, order, timing, and root-cause data also helps distinguish
flakiness from regressions. Those results are organization-specific, but they
are direct evidence that complete execution history can create measurable
software value without being shown verbatim to a language model.

### API And Dependency Migrations

Memory can retrieve earlier upgrades, codemods, call-site transformations,
exceptions, failed versions, compatibility decisions, and rollout outcomes.
Google's
[Large-Scale Changes](https://abseil.io/resources/swe-book/html/ch22.html)
describes dependency indexes, automated sharding, testing, historical flake
handling, and migration playbooks. The reusable memory is the versioned
procedure plus exact exceptions and evidence, not only the final diff.

### Intent And Rationale Recovery

Review discussions, issue context, architectural decisions, incidents, and
behavioral tests can explain why an unusual compatibility shim or constraint
exists. This is especially valuable when source shape looks accidental but
encodes a customer, security, migration, or operational requirement. Rationale
must remain attributed and separated from private model reasoning.

### Incident Response And Recurrence Prevention

Past telemetry patterns, deploys, configuration changes, mitigations, failed
actions, postmortems, and follow-up outcomes can accelerate diagnosis and reveal
recurring systemic risks. The Google SRE
[Postmortem Culture](https://sre.google/sre-book/postmortem-culture/) emphasizes
impact, response, contributing causes, and preventive actions followed by review
and publication. A useful memory connects those records to exact code,
configuration, deployments, and later recurrence rather than storing a prose
postmortem in isolation.

### Re-Evaluation With Better Models Or Policies

Retained evidence can be re-indexed or reinterpreted when retrieval, models,
ontologies, security policies, or analysis improve. This requires preserving
source events behind summaries. [RAPTOR](https://arxiv.org/abs/2401.18059),
[GraphRAG](https://arxiv.org/abs/2404.16130), and
[HippoRAG](https://arxiv.org/abs/2405.14831) demonstrate different useful
derived views, but none makes the original evidence unnecessary.

### Evaluation, Training, And Product Learning

Chronologically eligible trajectories can support verifier training, workflow
induction, retrieval evaluation, and controlled fine-tuning.
[SWE-Gym](https://arxiv.org/abs/2412.21139) reports substantial improvements
from executable tasks and sampled trajectories. This use must prevent future
patch leakage, repository overlap, secret inclusion, and survivorship bias.
Training data is a separate approved use, not an automatic consequence of
retention.

### Accountability And Forensics

Exact event sequence, actor, model/tool/policy versions, authorization result,
input/output commitments, artifacts, and outcomes allow incident reconstruction
and challenge. [W3C PROV-O](https://www.w3.org/TR/prov-o/) supplies entity,
activity, agent, derivation, association, delegation, revision, and invalidation
relations. Provenance describes relationships; signatures, commit receipts, and
integrity checks are still needed to establish tamper evidence.

## Value By Retained Content Class

| Content class | Future value | Required caveat |
| --- | --- | --- |
| System and task prompts | Reconstruct what policy and objective the model saw; compare prompt revisions; diagnose injection and regressions | May contain secrets or proprietary instructions; exact prompt does not reproduce nondeterministic output |
| Human/agent messages | Recover clarifications, steering, decisions, unresolved questions, and handoffs | Personal/confidential data; distinguish semantic message from provider transcript |
| Full transcript | Reconstruct conversational sequence, omitted context, retries, and misunderstanding | High privacy and poisoning surface; provider-internal context may still be unavailable |
| Raw model response | Re-run parsers and policy checks; audit normalization loss; improve schemas | Untrusted; can contain secrets, injection, unsafe content, or plausible but false rationales |
| Tool request | Reproduce action intent, exact parameters, working directory, environment, and expected effect | Secret values and capabilities must not be copied into a general archive |
| Tool output | Diagnose failures, recover exact evidence, compare later tool versions, induce error patterns | Often contains credentials, source, personal data, huge logs, or attacker instructions |
| Workspace diff and artifact | Reconstruct candidate, compare attempts, verify and learn edit patterns | Must bind exact base commit, paths, modes, binary content, and digest |
| Test/build result | Learn change-test associations, flakes, environment failures, and verification patterns | A passing result is not timeless truth; environment and source revision are mandatory |
| Review and decision | Preserve intent, acceptance rationale, rejection themes, and human constraints | Decision authority and actor separation must remain explicit |
| Deployment/incident outcome | Measure delayed correctness, regressions, rollback, and operational impact | Sensitive operational/customer data and uncertain causality require controls |
| Derived summary or fact | Efficient retrieval and cross-task transfer | Lossy and potentially hallucinated; retain source links and invalidation |
| Procedure or skill | Reuse validated workflows and reduce repeated exploration | Preconditions, version scope, failures, stop conditions, and revalidation are required |
| Private chain-of-thought | Little reliable provenance value | Often unavailable, unfaithful, privacy-sensitive, and should not be retained |

## Agent-Memory Research

### Cognitive Separation Is Useful

[CoALA](https://arxiv.org/abs/2309.02427) organizes language agents around
modular memory, internal/external actions, and decision processes. Its working,
episodic, semantic, and procedural distinctions are useful for JidoCode because
they prevent one transcript or vector index from being asked to serve every
purpose. The framework is conceptual; it does not prove one storage design.

The practical translation is:

| Memory type | JidoCode interpretation |
| --- | --- |
| Working | Current bounded `ContextManifest` and plan phase |
| Episodic | Attempt events, actions, observations, artifacts, failures, outcomes |
| Semantic | Versioned source, architecture, dependency, policy, incident, and ownership facts |
| Procedural | Validated workflows, skills, repair patterns, and anti-patterns |
| Prospective | Authorized unresolved work, deadlines, review points, and external waits |

### Event Plus Reflection

[Generative Agents](https://doi.org/10.1145/3586183.3606763) combined an
append-only observation stream with retrieval by recency, importance, and
relevance, then derived reflections and plans. The enduring architectural lesson
is not its simulated-town score; it is that reflections supplement rather than
replace observations.

[Reflexion](https://doi.org/10.52202/075280-0377) retained verbal feedback in an
episodic buffer and reported 91% HumanEval pass@1 versus the cited 80% GPT-4
baseline. The result includes generated tests, iterative attempts, and the
specific scaffold. For JidoCode, an objective failure and its evidence should
precede a generated reflection, and later evidence must be able to invalidate
the reflection.

### Context Paging Is Not Durable Authority

[MemGPT](https://arxiv.org/abs/2310.08560) treats context like virtual memory and
lets an agent move information among active, recall, and archival stores. It
reported 93.4% on a short deep-memory-retrieval benchmark versus 35.3% for a
lossy recursive-summary baseline. Later Zep work reported its system at 94.8%
and a reproduced full-context baseline at 94.4%, showing that the benchmark was
close to saturation. The paging pattern is useful;
self-edited archival text should not become project truth without provenance and
validation.

### Hierarchy, Graphs, And Temporal Relations Are Complementary

| Work | Useful result | Limitation for JidoCode |
| --- | --- | --- |
| [RAPTOR](https://arxiv.org/abs/2401.18059) | Recursive clusters and summaries support multiple abstraction levels | Headline gains cross complete systems; controlled reader gains are smaller; summaries are lossy |
| [GraphRAG](https://arxiv.org/abs/2404.16130) | Community summaries improved generated global sensemaking questions | Evidence does not establish superiority for local factual or code retrieval |
| [HippoRAG](https://arxiv.org/abs/2405.14831) | Graph plus personalized PageRank improved associative multi-hop QA in evaluated settings | Extracted edges can be false or stale; code needs exact source bindings |
| [A-MEM](https://arxiv.org/abs/2502.12110) | Dynamic note links improved LoCoMo multi-hop F1 | Temporal F1 remained low; explicit valid time and supersession are still needed |
| [Zep/Graphiti](https://arxiv.org/abs/2501.13956) | Episodes, entities, facts, and temporal validity in a graph | Vendor-authored evidence; configuration and benchmark saturation matter |

The correct conclusion is hybrid retrieval over one provenance model, not
choosing a graph instead of raw evidence or dense retrieval.

### Compression Saves Cost But Can Lose Correctness

[Mem0](https://arxiv.org/abs/2504.19413) reported major token/latency reductions
and better results than one OpenAI-memory baseline, but its own LoCoMo table put
full context above Mem0 and its graph variant. [LongMemEval](https://arxiv.org/abs/2410.10813)
found about a 30% accuracy drop for commercial assistants and long-context models
over sustained histories and separated indexing, retrieval, and reading.

Recent benchmarks reinforce the point:

- [MemBench](https://arxiv.org/abs/2506.21605) reports settings where retrieval
  substantially outperformed full memory at 100K tokens.
- [HaluMem](https://arxiv.org/abs/2511.03506) studies hallucinations introduced
  during extraction and updating that propagate to later answers.
- [AMA-Bench](https://arxiv.org/abs/2602.22769) finds that agent trajectories need
  causal, symbolic, and objective details that dialogue-oriented compression
  often loses.
- [EvoMemBench](https://arxiv.org/abs/2605.18421) reports no consistently winning
  memory method across task families and context budgets.

JidoCode should therefore retain recoverable evidence behind every compact
packet and benchmark memory against full evidence, not only against weak
recursive summaries.

### Procedural Memory Is The Highest-Value Cross-Task Layer

| Work | Mechanism | Cautious implication |
| --- | --- | --- |
| [ExpeL](https://doi.org/10.1609/aaai.v38i17.29936) | Similar successful trajectories plus insights from success/failure pairs | Store cases and generalized insights separately; score applicability |
| [Voyager](https://arxiv.org/abs/2305.16291) | Executable skills with feedback | Prefer verified code/workflows to prose-only tips |
| [Agent Workflow Memory](https://proceedings.mlr.press/v267/wang25bx.html) | Offline/online workflow induction and selective reuse | Model workflows as versioned procedures with triggers and exceptions |
| [SWE-Exp](https://arxiv.org/abs/2507.23361) | Comprehension and modification experiences from repair trajectories | Retrieve very few strong matches; multiple experiences can reduce performance |
| [CODESKILL](https://arxiv.org/abs/2605.25430) | Execution/judge-rewarded skill extraction, evolution, merge, and deletion | Skills need lifecycle and objective verification; evidence is a recent preprint |
| [PMCoder](https://arxiv.org/abs/2608.06811) | Phase planning plus phase-conditioned episodic retrieval | Retrieval should depend on investigation/edit/verification phase |

## Software-Maintenance Memory Products

### Product 1: Attempt Continuity

Answer:

- What was the exact objective and accepted plan?
- Which files, symbols, issues, policies, and graph revisions were in context?
- What has already been tried?
- Which assumptions failed?
- Which actions remain ambiguous?
- Which candidate and evidence are current?
- Why did work stop, and what authority is required to continue?

This is the minimum memory needed to replace an agent process safely.

### Product 2: Failure And Recovery Search

Answer:

- Has this exception, assertion, compiler message, stack frame, or exit signature
  occurred before?
- Under which repository revision, platform, dependency set, seed, and command?
- Which attempted fixes failed in the same way?
- What distinguished the eventual success?
- Was the result a product defect, test defect, infrastructure failure, or flake?

### Product 3: Historical Localization

Answer:

- Which files and symbols changed for similar issues?
- Which callers, dependencies, tests, owners, and incidents are graph-near the
  current symptom?
- Which old changes introduced or fixed related behavior, with what confidence?
- Which source regions were actually inspected or edited by successful attempts?

### Product 4: History-Aware Verification

Answer:

- Which tests historically fail when these symbols change?
- Which tests are flaky under this exact configuration?
- Which verifier-owned checks caught similar incorrect patches?
- Which candidate-authored tests fail on base and pass on the candidate?
- Which verification claim became stale after a later source change?

### Product 5: Repair And Migration Playbooks

Answer:

- Which human-approved edit patterns previously fixed this analyzer warning or
  API misuse?
- How was this deprecated API migrated elsewhere?
- Which codemod, ordering, and validation worked?
- Which manual exceptions, rollbacks, and backsliding checks were required?
- Under which versions and repository constraints is the procedure still valid?

### Product 6: Intent And Behavior Archaeology

Answer:

- Why does this compatibility shim, validation, branch, or configuration exist?
- Which issue, review, incident, customer requirement, or external contract
  introduced it?
- Which tests and downstream consumers establish intentional edge behavior?
- Which later evidence contradicted or superseded that rationale?

### Product 7: Incident Similarity And Change Risk

Answer:

- Which prior incidents share telemetry, dependency, topology, or deploy
  patterns?
- Which mitigations worked, failed, or caused secondary damage?
- Which similar changes were reverted or caused delayed regressions?
- Which postmortem actions remain open or have recurred?

### Product 8: Memory Quality

Answer:

- Which memories were retrieved for an attempt?
- Were they authorized, available at the task time, applicable, current, and
  represented accurately?
- Did they improve localization, success, cost, or safety?
- Which memories repeatedly cause stale recommendations or negative transfer?
- What would the outcome have been with the memory withheld?

## Why Private Reasoning Should Remain Outside Total Memory

Private chain-of-thought is neither complete provenance nor reliable causal
explanation. [Turpin et al.](https://arxiv.org/abs/2305.04388) showed models
rationalizing biased answers without disclosing the biasing feature.
[Reasoning Models Don't Always Say What They Think](https://arxiv.org/abs/2505.05410)
reported that tested reasoning models often disclosed injected hints in fewer
than 20% of cases where the hints affected the answer. Recent
[Safer Reasoning Traces](https://arxiv.org/abs/2603.05618) reports increased PII
leakage from chain-of-thought in its evaluated settings.

Providers may not expose private reasoning at all. A visible rationale can still
be retained as ordinary untrusted model output when policy permits, but it must
not be labeled the true internal cause of an action.

For accountability, record a structured decision trace instead:

```text
objective and requested action
evidence references actually supplied
model, prompt template, policy, and tool revisions
normalized proposal
authorization and capability checks
selected action and observable tool result
uncertainty and alternatives
verification outcome
human approval or rejection
final external effect and delayed outcome
```

This trace is more challengeable, more compact, and less privacy-sensitive than
an unrestricted reasoning transcript.

## Risks Of Total Retention

### Persistent Memory Poisoning

[AgentPoison](https://arxiv.org/abs/2407.12784) reported roughly 82% retrieval
success and 63% end-to-end attack success in its evaluated settings, with poison
rates below 0.1% and less than 1% benign-performance impact. Its threat model
assumes the attacker can inject memory/knowledge records and uses white-box
embedder access while optimizing triggers. [MINJA](https://arxiv.org/abs/2503.03704)
removes direct-store access but assumes a shared cross-user memory bank in which
attacker-generated interaction records are persisted. [PoisonedRAG](https://www.usenix.org/conference/usenixsecurity25/presentation/zou-poisonedrag)
reported targeted attacks using a handful of injected texts in databases with
millions of records.

Retention alone creates a confidentiality risk. Retention plus automatic
retrieval turns old data into an integrity and control-plane risk. No successful
interaction, passing test, accepted model answer, or frequently repeated claim
may automatically authorize memory promotion.

### Indirect Prompt Injection Across Time

[Indirect Prompt Injection](https://arxiv.org/abs/2302.12173) demonstrates that
instructions embedded in retrieved content can influence tools and cause data
theft. A repository comment, issue, email, log, web page, or prior tool output
can become a delayed attack if retrieved months later. Retrieved history must be
typed as data, structurally separated from instructions, and stripped of
authority.

### Secrets And Personal Data

Prompts and tool outputs routinely contain credentials, authorization headers,
signed URLs, environment variables, customer data, emails, file paths, source,
or incident details. Aggregated histories can reveal sensitive attributes even
when direct identifiers are removed. Embeddings are also sensitive derivatives;
[Text Embeddings Reveal (Almost) As Much As Text](https://aclanthology.org/2023.emnlp-main.765/)
demonstrated reconstruction attacks in evaluated embedding settings.

### Cross-Scope Leakage

A similarity index can return a semantically close result from another tenant,
repository, actor, or confidential incident before an application filter runs.
Authorization must constrain candidate generation itself, not only filter the
final prompt.

### Staleness And Negative Transfer

Old APIs, policies, tools, ownership, dependencies, branch rules, and repository
state can make once-correct procedures harmful. Frequency is not validity. Every
derived fact and procedure needs source time, valid time, scope, compatibility,
freshness, contradiction, and supersession.

### Context Overload

More history can lower performance, increase latency, and hide the decisive
evidence. LongMemEval, RepoGraph, SWE-Exp, and recent memory benchmarks all show
that retrieval granularity and selection matter. A total archive must support
small evidence packets, not pressure the agent to consume the archive.

### False Causality

Issue/commit linking, blame, and SZZ-style analyses are probabilistic.
[Evaluating SZZ Implementations](https://doi.org/10.1109/TSE.2024.3406718)
found lower recall than earlier reports and untraceable ghost commits in its
Linux study. The graph must represent candidate causes, evidence, confidence,
and unknown status rather than one asserted culprit.

### Erasure And Backup Conflict

Copies can survive in the active graph, embeddings, caches, exports, backups,
provider logs, and model-training datasets. A tombstone that hides active data
does not physically erase backup bytes. Every derivative needs a deletion
inventory and propagation contract.

### Legal And Purpose Constraints

The [GDPR](https://eur-lex.europa.eu/eli/reg/2016/679/oj) establishes purpose
limitation, data minimization, storage limitation, security, privacy by design,
and erasure duties where it applies. “It may be useful later” is not a complete
purpose specification. The
[EU AI Act](https://eur-lex.europa.eu/eli/reg/2024/1689/oj/eng) contains logging
requirements for applicable high-risk systems, but it does not require blanket
retention of every prompt and response.

### Cost And Operational Complexity

Full content increases write volume, dictionary/index size, backups, restore
time, integrity checks, encryption/key management, search-index rebuilds,
retention work, incident response, and disclosure scope. Capacity must be
measured with realistic large logs and binary artifacts, not inferred from
metadata-only run counts.

## Recommended Design: Complete Evidence, Selective Memory

### Core Principle

The architecture should separate five concerns:

| Plane | Question | Authority |
| --- | --- | --- |
| Episode evidence | What exactly happened and what was observed? | Historical evidence, never self-authorizing |
| Derived memory | What facts, cases, patterns, and procedures can be extracted? | Candidate guidance with source links |
| Accepted knowledge | What proposition has been independently accepted? | Scoped and time-bounded repository authority |
| Retrieval | What small subset is relevant now? | Context suggestion after authorization |
| Control | What may the current agent do? | Current policy, lease, capability, revision, and approval only |

The archive cannot grant capability. A retrieved procedure cannot override
current repository policy. A repeated statement cannot become true by
frequency. A prior approval cannot authorize a new effect.

### Memory Layers

#### Layer 1: Episode Evidence

The durable execution episode is the complete observable execution history for
one attempt through its terminal sequence:

- task, goal, plan, repository, snapshot, actor, agent, and lease identity;
- exact sequence and causal predecessor;
- context-selection manifest and content states;
- model invocation start, provider/model/profile, options, usage, and outcome;
- normalized proposal and authorization result;
- tool invocation, environment, command, inputs, bounded or referenced outputs,
  and effect identity;
- workspace/artifact changes and hashes;
- human/agent messages that occur before run closure;
- cancellation, runtime terminal outcome, and closure;
- initial capture outcomes, omissions, redactions, unavailable provider state,
  and run completeness.

Execution evidence is append-only until `FinalizeExecutionRun` marks the run
complete or incomplete. It remains untrusted content even when its provenance is
high integrity.

Verification, evidence assessment, decision, publication, CI, deployment,
rollback, incidents, regressions, and delayed human review happen after the run
is closed. They remain in their accepted evidence, control, observation, and
follow-up run graphs and link back to the immutable attempt. A `WorkLineage`
projection can traverse the full task history as of an exact dataset/effective-
time boundary, but it is not another aggregate persisted in the closed run.
Time-bounded lineage manifests can attest which later graph revisions were
considered for an evaluation; no manifest can claim completeness over events
that may occur indefinitely in the future.

#### Layer 2: Temporal Semantic Memory

Reviewed deterministic rules may derive atomic statements such as:

- error signature `E` occurred under environment `V`;
- symbol `S` was changed while resolving issue `I`;
- test `T` failed after changes near symbol `S` under configuration `C`;
- API `A` was replaced by `B` for version range `R`;
- procedure `P` was used and verified for task class `K`;
- claim `C` was supported by artifact revision `R` and later invalidated.

Each statement needs source events, derivation activity, recorded time, valid
time, repository/version scope, confidence, limitations, contradiction, and
supersession. Reviewed-rule statements can use the existing replaceable derived
graph protocol. Model-proposed facts or summaries are not reasoner output: they
remain untrusted `experience` candidates or disposable process views until the
existing evidence and decision boundary accepts a proposition.

#### Layer 3: Episodic Cases

An `ExperienceCase` packages a reusable episode without hiding the raw lineage:

```text
problem signature
repository and version scope
environment and dependency constraints
symptoms and reproduction
investigated files and symbols
attempted interventions
disproved assumptions
successful or terminal intervention
verification and delayed outcome
known exceptions and limitations
source event and artifact references
```

Cases include successes, failures, reverts, abandoned work, infrastructure
failures, and ambiguous outcomes. A case is not an accepted procedure merely
because one attempt succeeded.

#### Layer 4: Procedural Memory

A `ProcedureRevision` represents a reusable workflow:

```text
purpose and task class
trigger and applicability predicates
repository, language, framework, and version scope
ordered semantic steps
required tools and capabilities
expected observations and evidence
decision points and branches
stop, escalation, and rollback conditions
known failure patterns and exceptions
supporting cases
success, failure, revert, and incident counts
last independent validation
current state: candidate, validated, stale, invalidated, superseded
```

Procedure extraction may be model-assisted, but validation is based on execution
and evidence. Procedure use creates a new observation; it does not increase the
procedure's authority until the current outcome is independently assessed.

#### Layer 5: Artifact-Grounded Claims

An `ArtifactClaim` should minimally bind:

```text
claim
repository and revision
artifact path or IRI
symbol, line range, or selector
content digest
verification command and environment
evidence reference and strength
valid-from and checked-at times
freshness state
invalidating change or contradiction
```

Artifact drift updates freshness independently from the original evidence
strength. A strong old test can be stale; a fresh observation can be weak.

#### Layer 6: Accepted Knowledge

The existing governed memory remains the narrow authority layer. It stores
precise accepted propositions with evidence, decision, scope, confidence,
limitations, validity, contradiction, and supersession. Episode evidence and
procedural candidates do not bypass `AdoptKnowledge`.

#### Layer 7: Derived Retrieval Views

Lexical indexes, embeddings, graph communities, hierarchical summaries, failure
clusters, and organized filesystem views are disposable. They carry source
revision, construction version, scope, classification, and staleness. Deleting
them loses performance, not truth.

## Episode Event Contract

Every observable event should have a closed event-type-specific envelope. Common
fields are:

```text
event IRI and semantic event type
actor, delegated agent, tool/provider, and authority references
occurred-at and recorded-at
source system and source event identity
input and output content references or content states
classification, purpose, retention class, and allowed uses
model/tool/policy/template/environment versions
expected and actual effect class
status, usage, limitations, and completeness
derivation and supersession references
command and commit receipt
```

Required lineage depends on event type:

| Event type | Required lineage |
| --- | --- |
| Execution event | Attempt, task, goal, repository, snapshot, shared sequence/predecessor, current lease/fence where applicable |
| Provider observation | Enrollment, repository, locator/delivery identity, source sequence/time; no invented task or attempt |
| Interaction message | Session, sender, audience, scope, chronology, purpose; attempt only when the session is attempt-bound |
| Verification/decision | Closed run/candidate/evidence/control revisions and independent actor; no execution fence reuse |
| Delayed CI/deploy/incident | External resource/revision and observation time, then an attributed link to related task/attempt when proven |
| Retention/access activity | Content identity, actor, purpose, policy, lifecycle predecessor, and authorization permit |

The envelope is not one generic record-store API. Each semantic event type still
requires a closed command, shape, capability, graph-family writer, and query use.

### Content State

One status cannot represent content lifecycle correctly. Exactness, location,
availability, expiry, and legal hold are orthogonal. Every expected body records
these dimensions:

| Dimension | Example states |
| --- | --- |
| Capture outcome | `captured`, `omitted_by_policy`, `unavailable_at_source`, `capture_failed` |
| Representation | `exact`, `deterministically_redacted`, `normalized`, `commitment_only`, `none` |
| Storage location | `graph_segment`, `governed_external`, `encrypted_vault`, `none` |
| Availability tier | `hot`, `cold`, `temporarily_unavailable`, `provider_lost`, `deleted` |
| Retention/erasure | `active`, `expired_pending`, `erase_requested`, `crypto_erased`, `physically_deleted`, `externally_attested`, `externally_unverifiable` |
| Hold state | `none`, `active`, `released` |

A body can therefore be exact, encrypted-vault, cold, active, and held at the
same time. Hold state does not automatically authorize or forbid retrieval; the
hold's own access policy decides. This model avoids false replayability and lets
a future query report exactly what is known, accessible, missing, or unverifiable.

### Ordering And Completeness

Wall-clock time and caller-provided sequence values are not sufficient ordering.
`RecordExecutionAttempt` creates the first bounded `run_event_segment` graph and
its accepted event-head transition at sequence zero while keeping the root
`run/{attempt}` graph small. Every later execution event command targets the
active segment, consumes its exact current head, appends one contiguous
successor, and carries a guard against the predecessor. Concurrent writers using
the same predecessor conflict. Model/tool starts and outcomes use one shared
attempt sequence rather than independently chosen tool sequence numbers.

External events retain their source ordering plus occurred-at and ingestion
times. A later association can link an earlier observation to a task; it cannot
retroactively fabricate task/attempt identity inside an immutable source event.

Existing closure cannot safely enumerate a total-history event set: caller lists
are not proof of completeness, list/precommit guards cap ordinary references
near 100, and semantic snapshots reject target graphs above 10,000 quads. The
extended protocol therefore stores events in bounded immutable
`run_event_segment` graphs and keeps only segment roots in the attempt graph:

1. A segment covers one contiguous inclusive sequence range under one attempt.
2. Its close command enumerates a protocol-bounded set of typed event resources.
3. Precommit independently scans only the bounded segment graph and proves exact typed-set
   equality for that range, rejects sequence gaps and unlisted resources, and
   requires exactly one terminal outcome/content state for every start that must
   close within the segment.
4. A cross-segment start carries an explicit open-effect reference and the next
   segment must close or carry it forward; no effect silently disappears.
5. Every outcome is a new immutable successor event that points to its start; it
   never adds a `result` triple to a start in an earlier segment.
6. The segment records deterministic ordered-set and event-content root digests.
7. Segment closure atomically closes that graph, appends its root/revision to the
   small attempt graph, and optionally creates the next segment and carries the
   explicit open-effect set.
8. Precommit and graph lifecycle reject any later addition to a subject covered
   by a closed segment, and finalization rechecks each immutable segment root.
9. `FinalizeExecutionRun` references only ordered segment roots, proves their
   ranges are contiguous from zero through the terminal sequence, verifies no
   event exists outside a closed segment, and checks all open-effect sets are empty or
   explicitly classified ambiguous/cancelled.

Segment quads, event count, and maximum segments per attempt are fixed protocol
limits below the 10,000-quad semantic-snapshot, 100-guard/reference, and 16-graph
revision ceilings with reserved closure headroom. The root attempt graph also
has an explicit total-quad ceiling. A run approaching any limit stops safely and
continues, if policy permits, as a new linked attempt rather than creating an
unfinalizable graph.

The existing atomic command receipt and dataset revision order remain the
integrity foundation for commit order. The event-head chain supplies semantic
attempt order. Signed exports or transparency roots can strengthen off-system
verification, but they do not replace graph authorization.

## Capture Policy

### Proposed Profiles

Under the currently accepted privacy and harness contracts, only
`semantic_history` is eligible. The other profiles are research alternatives
that require explicit superseding contracts before implementation; listing them
does not authorize durable prompts, raw responses, or raw tool bodies.

| Profile | Intended use | Content posture |
| --- | --- | --- |
| `semantic_history` | Managed default | Durable envelopes, normalized facts, digests, selected messages/results, no full transcript |
| `diagnostic_capture` | Approved debugging/evaluation | Deterministically redacted prompt, response, and tool representations for a bounded period |
| `project_total_history` | Explicit single-tenant or contract-approved project memory | Maximum observable content except forbidden secrets/private reasoning, with per-class retention and erasure |
| `incident_hold` | Security/legal case | Case-scoped content, frozen eligibility, dual approval, periodic hold review |

The name `project_total_history` still means total observable and authorized
history. Secret values, provider-private state, and hidden reasoning remain
outside the claim.

### Content Policy Matrix

| Content | Semantic history | Diagnostic capture | Project total history |
| --- | --- | --- | --- |
| Event metadata and provenance | Retain | Retain | Retain |
| Context manifest | Retain | Retain | Retain |
| Exact assembled prompt | Omit; retain digest/capture state | Deterministically redacted representation, bounded TTL | Policy-authorized exact or deterministically redacted representation |
| Human semantic message | Existing bounded policy | Retain under classification | Retain under actor/scope policy |
| Raw provider response | Omit; retain normalized result/digest | Deterministically redacted representation, bounded TTL | Retain exact or redacted representation if provider and data policy allow |
| Private/hidden chain-of-thought | Never | Never | Never |
| Visible rationale | Bounded normalized proposal | Deterministically redacted representation plus normalized proposal | Retain as untrusted response, never causal authority |
| Tool request | Normalized args and input refs | Deterministically redacted request representation | Exact non-secret request plus environment manifest |
| Tool stdout/stderr | Bounded normalized result/digests | Deterministically redacted representation or governed artifact | Exact non-secret body with chunking and retention |
| Patch/artifact | Digest and governed artifact | Same | Same, with required availability period |
| Test/build result | Structured result and output refs | Exact governed output | Exact governed output |
| Provider-native internal events | Record observed subset and completeness | Same | Same; never claim unobserved events |
| Credentials and secret values | Never | Never | Never |

### Capture-Time Controls

Before persistence:

1. Establish actor, repository/tenant, purpose, policy, and retention profile.
2. Parse the event with an allowlisted semantic schema.
3. Remove credentials, authorization headers, cookies, signed URLs, secret
   environment variables, private keys, and provider tokens.
4. Detect personal, customer, proprietary, exploit, and special-category data.
5. Apply path, source, prompt, output, and incident classifications.
6. Normalize deterministically where the exact body is not authorized.
7. Encrypt eligible sensitive content before durable commit or fail closed.
8. Record every content-state dimension, redaction receipt, limitations, and capture
   policy revision.
9. For graph-native content, commit semantic metadata and content identity
   atomically. For a future vault, write encrypted bytes into an inaccessible
   pending namespace, commit the activating graph record, then expose only
   through the content gateway; failed graph commits leave removable orphans and
   an honest failed/incomplete capture.

Simple regex secret detection is not a proof that content is safe. Canary,
entropy, format, repository policy, and provider-specific classifiers can reduce
risk, but sensitive classes should be structurally unavailable to ordinary
retrieval.

## Retrieval Architecture

### Retrieval Is A Governed Effect

Memory retrieval changes what can influence the model. Every retrieval requires:

- authenticated actor and repository/tenant scope;
- task, purpose, and current plan phase;
- effective-time cutoff;
- data classifications allowed for the selected provider/model profile;
- query and ranking versions;
- item, graph, byte, token, and time budgets;
- memory categories and trust levels permitted;
- explicit exclusion of invalidated, erased, or future-ineligible data, with held
  content governed by the hold's separate access policy.

Authorization must happen before lexical, graph, or dense candidate generation.
A post-search tenant filter is insufficient. First-stage indexes are partitioned
by non-bypassable authorization scope, repository/tenant, data-class ceiling,
purpose class, effective-time generation, and erasure generation, or implement
an ACL-aware lookup whose authorization key is part of candidate generation.
Shared indexes that inspect cross-scope vectors or terms before filtering are
ineligible. Index identities and deletion receipts record these partition keys.

### Hybrid Retrieval Pipeline

```text
authorize scope, purpose, time, and data classes
  -> derive exact task features
  -> retrieve independent candidate channels
  -> reject unavailable, stale, invalid, and incompatible memories
  -> rerank by relevance, trust, freshness, evidence, and diversity
  -> assemble a small phase-specific evidence packet
  -> retain direct recovery handles to exact evidence
  -> mark all payloads as non-instructional while preserving integrity/epistemic labels
  -> record which memories influenced the attempt
  -> evaluate their later utility or harm
```

Candidate channels should remain separate until reranking:

| Channel | Strength |
| --- | --- |
| Exact identifiers and lexical search | Symbols, paths, error strings, commands, issue IDs, versions |
| Temporal graph traversal | Dependencies, causality, ownership, issue/change/test/incident paths |
| Dense retrieval | Paraphrased symptoms, semantically similar cases, review themes |
| Failure-signature index | Exceptions, assertions, exit statuses, test and build fingerprints |
| Procedure matching | Trigger, precondition, framework/version, risk, and phase compatibility |
| Artifact-claim lookup | Exact behavior and verification claims near changed content |
| Recency/current-state lens | Current facts, supersession, stale claims, changed owners or policies |

### Ranking

A candidate score should consider independent features rather than one opaque
similarity value:

```text
authorization eligibility
effective-time eligibility
semantic and lexical relevance
symbol/dependency overlap
repository/environment/version compatibility
task-phase relevance
source trust and evidence strength
freshness and contradiction state
outcome quality and delayed survival
novelty/diversity versus already selected memories
known negative-transfer history
```

Current policy, source, tests, and task evidence outrank historical frequency.

### Evidence Packet

The model receives a bounded packet, not a transcript dump. Each item includes:

```text
memory type and why it was selected
bounded content or structured fields
source event/case/procedure/claim IRI
repository and version scope
occurred-at, valid-at, and checked-at times
trust, evidence strength, confidence, and freshness
contradiction, limitation, and applicability warnings
direct recovery tool for authorized exact evidence
```

Retrieved payload text remains non-instructional data. Archive and derived
candidates default to untrusted, while accepted knowledge retains its scoped
epistemic status and provenance. No retrieved item can introduce tools, policy,
capability, credentials, destinations, approvals, or durable memory writes.

### Memory-Use Provenance

Record which memories were supplied, omitted for budget, opened in detail,
followed, contradicted, or ignored. After the attempt, record whether each memory
was useful, neutral, misleading, stale, unauthorized, or causally indeterminate.
This supports memory-quality evaluation without accepting the model's own claim
that a memory helped.

## Consolidation And Promotion

### Pipeline

```text
raw/normalized episode evidence
  -> deterministic extraction and model-proposed candidates
  -> quarantine
  -> source and scope validation
  -> contradiction and temporal analysis
  -> case construction
  -> repeated-case or explicit-review threshold
  -> procedure/claim proposal
  -> independent execution or evidence validation
  -> accepted knowledge decision where appropriate
```

### Quarantine Rules

Candidate memories remain untrusted. Quarantine checks:

- source and actor authorization;
- embedded instructions and hidden content;
- secrets, personal data, and cross-scope references;
- unsupported claims and missing evidence;
- contradiction with current facts or policy;
- task-specific details incorrectly generalized;
- benchmark/future-data leakage;
- duplicate or near-duplicate procedures;
- suspicious trigger concentration or poisoning patterns.

### Promotion Rules

No automatic rule based only on success count is sufficient. Common promotion
requirements are source attribution, scope, uncertainty/limitations, owner,
review/expiry policy, actor authorization appropriate to the target class, and
an append-only lifecycle activity.

Procedure or pattern validation additionally requires exact supporting and
contradicting cases, independently verified outcomes, explicit preconditions and
exceptions, and delayed outcomes where relevant, including reverts and
incidents. Repeated workflows can become non-authoritative validated procedural
candidates; compiling one into executable policy is a separate policy decision.

A unique fact, preference, open question, decision, or security finding does not
need an `ExperienceCase` or executable outcome. It may enter accepted knowledge
when sufficient governed evidence and the existing decision/adoption contract
support it; repetition is not a requirement for proposition truth.

### Invalidation

Memory is never silently edited. New events append:

- still-valid confirmation;
- under-review state;
- contradiction;
- stale-source indication;
- invalidation;
- expiry;
- supersession by a new revision.

Artifact claims become stale when their exact source/hash dependency changes.
Procedures become stale when tool, framework, policy, or environment
preconditions change. Retrieval excludes or strongly demotes them in current
mode while historical queries retain them.

## Security, Privacy, And Integrity

### Separate Integrity From Confidentiality

An exact signed provider response can be high-provenance and still contain
malicious instructions. A public source comment can be low confidentiality and
low integrity. Retrieval policy evaluates both axes.

### Encryption And Keying

If exact sensitive content is retained:

- use per-tenant and preferably per-object envelope encryption;
- keep keys outside the graph and payload substrate;
- bind ciphertext identity, key reference, algorithm, and policy in the graph;
- rotate keys without changing semantic event identity;
- support cryptographic erasure where physical backup deletion is delayed;
- never put plaintext secrets or low-entropy plaintext hashes into immutable
  audit records;
- use keyed commitments when an omitted sensitive value needs later equality
  verification.

Encryption at rest does not authorize retrieval. Decryption remains a scoped,
audited effect.

### Access

Use repository/tenant scope, data class, purpose, actor role, task, and provider
egress policy. Sensitive bulk export requires explicit approval and should be
audited.

Content release uses an effect protocol rather than best-effort logging:

1. `AuthorizeContentAccess` commits a purpose-bound, expiring, single-use permit
   for exact actor, task/scope, execution context when applicable, closed
   reviewed-query identity, parameter commitments, content object/version,
   allowed representation, byte range, sink class, destination/method, and
   destination-specific data-class ceiling. Agent-context permits additionally
   bind attempt, lease/fence, context/model invocation, and model-access profile.
2. Immediately before decryption, `ConsumeContentAccess` rechecks current scope,
   revocation, retention/hold policy, object version, permit state, and every
   bound sink/attempt/lease/fence/profile/destination field, then consumes the
   permit.
3. The content gateway releases at most the committed representation and range.
4. A terminal reporting command records released, denied, unavailable, failed,
   or ambiguous outcome and bounded byte count.

A crash after consumption leaves an attributable ambiguous access rather than
an unaudited disclosure. Audit stores query catalog/version, parameter
commitments, and selected object IRIs, never raw prompt/source query text or
released content.

### Tamper Evidence

W3C PROV-O models derivation and responsibility but does not authenticate them.
JidoCode should retain atomic command receipts, canonical addition digests, graph
revisions, and backup integrity. If external verification is required, signed
checkpoint manifests or Merkle roots can attest exported history. Public
transparency logs receive only non-sensitive commitments.

Current command receipts hash canonical plaintext N-Quads. If a sensitive
instruction or stdout literal was committed, removing the literal later does not
remove its unkeyed receipt commitment; low-entropy content may be dictionary-
recoverable. Phase 0 must inventory these receipt derivatives and forbid new
exact sensitive graph literals until the contract is resolved. Future exact
sensitive payloads are encrypted before the semantic command so receipts commit
to ciphertext, while equality testing uses a protected keyed commitment only
when policy requires it. If law requires removal of an existing plaintext-
derived commitment, the immutable receipt/integrity contract needs an explicit
superseding protocol; a tombstone alone is insufficient.

[SLSA provenance](https://slsa.dev/spec/v1.2/build-provenance),
[in-toto](https://www.usenix.org/conference/usenixsecurity19/presentation/torres-arias),
and [Sigstore](https://doi.org/10.1145/3548606.3560596) support selective
attestation of actors, inputs, steps, and outputs. They do not prove factual
correctness or privacy compliance.

### Erasure

An erasure workflow inventories and removes:

- primary content bodies;
- graph literals when permitted by the retention/authority contract;
- lexical and dense indexes;
- summaries, cases, procedures, and training examples derived from the content;
- training datasets, fine-tuned model/checkpoint versions, evaluations, and
  deployments whose lineage includes the content;
- caches, exports, queued jobs, replicas, and provider objects;
- backup-restorable keys or objects under the accepted backup policy.

Erasable payload bodies are separated from immutable run, evidence, decision,
and proposition shells. The workflow first appends invalidation and blocks
retrieval, then removes payloads and derivatives without changing the closed run
revision. Accepted knowledge normally preserves append-only history through an
invalidated or superseded non-sensitive proposition shell. If applicable law
requires deletion of that accepted resource or support link itself, a specific
superseding append-only/reachability contract is required; current retention
rules can reject deletion of reachable evidence.

The graph may retain a non-sensitive deletion activity and tombstone so erased
content is not resurrected. The tombstone must not retain a reversible plaintext
hash or the erased personal data. External/model derivatives report granular
states such as requested, crypto-erased, physically deleted, externally
attested, externally unverifiable, model decommissioned, or retrained; the system
must not collapse an unverifiable provider request into `erased`.

### Legal Hold

A hold is case-specific and records scope, purpose, legal/security owner,
approver, start, review date, affected objects, access policy, and release. It
does not silently convert held evidence into retrievable agent memory.

## Storage Alternatives

### Alternative A: Graph-Native Content Chunks

Store authorized payload chunks in immutable bounded segment graphs. Each
segment has its own identity, contiguous chunk range, homogeneous initial
classification/retention policy, ordered membership, media type, byte count,
digest/commitment class, capture provenance, and atomic completeness root.
Sensitive bytes are encrypted before they enter semantic commands. The immutable
run graph stores only the owning event, opaque content IRI, capture state, and
segment root; later availability/erasure state lives outside the closed run.

Advantages:

- preserves the current sole-store ADR;
- can commit metadata and bounded content atomically;
- uses existing backup, revision, authorization, and integrity boundaries;
- makes content lifecycle explicit in graph topology.

Disadvantages:

- large dictionary, quad, WAL, backup, restore, and query cost;
- current 1,000-addition/262,144-byte command ceilings require a separately
  specified chunk transaction and completeness protocol;
- binary data and very large logs are poor RDF payloads;
- graph-family retention and encryption granularity require substantial work;
- derived full-text/vector indexes still need rebuildable external process state.

### Alternative B: Provider-Owned Governed Artifacts

Retain exact bodies in a genuinely external provider/object authority and store
immutable URI, digest, media type, size, classification, availability, and
provenance in the graph. External means JidoCode does not control the storage
namespace, lifecycle, encryption keys, or retention for the purpose of keeping
its own product history. A JidoCode-controlled cloud bucket is application-owned
regardless of its provider URL and belongs to Alternative C.

Advantages:

- currently compatible with ADR 0001;
- avoids putting large bytes into RDF;
- content addressing and on-use verification already have precedent.

Disadvantages:

- availability, retention, deletion, residency, and access depend on the
  provider;
- cannot guarantee complete project history if provider objects expire;
- content and graph metadata cannot generally commit atomically;
- provider retention can conflict with JidoCode policy.

### Alternative C: Application-Owned Encrypted Content Vault

Use an encrypted object vault for payload bytes. A stable opaque semantic content
IRI identifies the captured content. Immutable versioned ciphertext object IRIs
and ciphertext digests identify each encryption version; key rotation/re-
encryption appends supersession to a new ciphertext object rather than changing
the semantic identity. A plaintext digest is not used as a public address;
protected keyed commitments are optional when equality is an accepted purpose.
The graph is the only semantic/control authority and stores object version, byte
count, key reference, classification, lifecycle, provenance, availability, and
deletion state. An object without a current authorized graph record is
inaccessible and has no product meaning.

Advantages:

- scales better for logs, prompts, responses, source snapshots, and binary
  artifacts;
- allows per-object encryption, retention, legal hold, and cryptographic erasure;
- provides direct exact recovery behind compact memory packets;
- keeps RDF optimized for relationships and semantic queries.

Disadvantages:

- it is durable application-owned state and therefore requires a superseding
  ADR, new backup/restore/integrity contracts, and architecture checks;
- metadata/object atomicity and orphan recovery need an explicit protocol;
- a compromised vault or key broker increases breach impact;
- vector/full-text indexes must remain derived rather than quietly becoming
  another authority.

### Alternative D: Transcript Or Vector Database As Memory

Rejected. It creates a parallel durable authority, loses graph lifecycle and
provenance semantics, makes cross-scope filtering easy to get wrong, and tends to
conflate similarity with validity. A vector index can be a disposable projection
over authorized graph/content sources, not the memory of record.

### Recommendation

Start with complete semantic accounting and bounded exact capture in the current
TripleStore. Benchmark realistic volume and retrieval. If product requirements
confirm long-lived exact prompts, responses, logs, or binary artifacts at scale,
write a superseding ADR for Alternative C rather than forcing large opaque bytes
into RDF or introducing an undeclared sidecar store.

The ADR must preserve:

- graph authority over identity, authorization, lifecycle, and deletion;
- content-addressed immutable objects;
- atomic intent and recoverable object/graph commit ordering;
- orphan detection and cleanup;
- graph and object backup consistency;
- complete erasure including keys and derivatives;
- no runtime, vector, or transcript store as workflow authority.

## JidoCode Graph Mapping

### Reuse Existing Families

| Resource | Graph family | Lifecycle |
| --- | --- | --- |
| Episode/attempt root metadata and event-segment roots | `run/{attempt}` | Append until `FinalizeExecutionRun`, then immutable and explicitly bounded below the semantic-snapshot ceiling |
| Execution semantic events | Proposed bounded `run_event_segment` family | Append within one active segment, then immutable after exact-set segment closure |
| Human/agent interaction session and semantic messages | Existing control/run family | Existing interaction lifecycle |
| Source/repository temporal facts | Existing source/observation families | Immutable revision/batch |
| Verification activities and artifact claims | Evidence graph | Append/supersede under evidence rules |
| Accepted propositions | Memory graph | Existing adoption/evolution lifecycle |
| Candidate cases/procedures and memory-use assessments | Proposed repository-scoped `experience` family | Non-authoritative append/supersede lifecycle |
| Sanitized executable procedure/profile accepted as control policy | Factory policy | Separate authorized policy command; versioned append/supersede |
| Reviewed-rule inferences and authorized retrieval indexes | Derived graph or disposable process index | Replaceable/rebuildable under the existing reasoner/index contract |
| Model-proposed facts and summaries | Proposed `experience` family or disposable process view | Untrusted candidate lifecycle; never written by the reasoner merely because a model generated it |
| Payload availability, retention, hold, and erasure transitions | Proposed `content_lifecycle` family | Append/supersede without mutating closed run/payload graphs |
| Capture/access/retention audit | Security audit | Append-only |

### Candidate New Resources

Names are illustrative and need ontology review:

| Resource | Family and writer/lifecycle | Purpose |
| --- | --- | --- |
| `EpisodeCaptureManifest` | `run/{attempt}`; revised execution-start/segment/finalization commands; immutable after run closure | Declare expected execution event/content classes, capture profile, limits, and completeness roots |
| `EventSegmentManifest` | Proposed `run_event_segment`; execution writer; immutable after segment close | Prove one contiguous bounded event set and open-effect state |
| `ContentCapture` | Owning `run_event_segment`; atomic part of event command; immutable shell | Bind one event role to opaque content identity, initial capture dimensions, purpose, and policy |
| `ModelInvocationStart`/`ModelInvocationOutcome` | Owning `run_event_segment`; separate immutable successor resources | Record one provider/model interaction without mutating a closed start resource |
| `ContextManifest` | First in attempt root, later in owning `run_event_segment`; attempt/model-start commands; immutable | Name selected sources, serialization, prompt/template/model/policy versions, and reconstruction status |
| `RetrievalActivity` | Active `run_event_segment` only; retrieval-start/outcome commands | Record the agent's authorized query, selected memories, omissions, and packet identity before closure |
| `ExperienceCase` | Proposed `experience`; dedicated experience writer; candidate/validated/stale/invalidated/superseded | Package reusable problem/attempt/outcome lineage without authority |
| `CandidateFactOrSummary` | Proposed `experience`; dedicated experience writer; untrusted candidate lifecycle | Retain source-linked model extraction without misclassifying it as reviewed-rule inference |
| Candidate `ProcedureRevision` | Proposed `experience`; dedicated experience writer; non-authoritative lifecycle | Represent evidence-backed workflow guidance with applicability and lifecycle |
| Executable workflow/profile | `factory/policy`; existing/new policy writer through separate authorized command | Compile a sanitized reviewed procedure into control policy; never automatic from a candidate |
| `ArtifactClaim` | Evidence graph; evidence writer; append/supersede and freshness transitions | Tie a claim to exact content, verification, evidence, and freshness |
| `MemoryUseAssessment` | Proposed `experience`; independent evaluation command after attempt closure | Record measured utility or harm from memories used by a closed attempt |
| `ContentAccessPermit` | Repository control; authorized control writer; append, consume, expire, revoke | Bind one exact purpose/scope/query commitment/content version/range and final sink, plus attempt/lease/fence/model profile for agent context, to a single release |
| `ContentLifecycleActivity` | Proposed `content_lifecycle`; dedicated lifecycle writer; append-only transitions/current-state projection | Record availability, expiry, erasure progress, hold, restoration prohibition, or provider loss without changing the run |
| Time-bounded lineage evaluation | Evidence graph; evaluation/verification command | Bind delayed outcomes observed through exact graph/effective-time revisions; does not claim future completeness |

The proposed `experience` and `content_lifecycle` families require explicit
scope, retention, writer capabilities, allowed predicates/links, completeness,
shapes, and reviewed queries. They do not exist in the current closed registry.
Candidate procedures remain suggestive. `AdoptKnowledge` may accept propositions
about them, while executable policy requires a distinct authorized policy
command and sanitized policy representation.

Every new family, including `run_event_segment` and `episode_content`, must also
extend the shared `Security.DataPolicy`: allowed classifications and durable
locations, Personal-data placement, product/query projection rules, export and
redaction rules, provider egress, and erasure behavior are release-blocking parts
of the family contract. Unknown families remain denied by current policy.

### Proposed Run Event Segment Family

`run_event_segment` keeps the root attempt graph and every command snapshot
bounded. It needs:

- graph identity derived from attempt plus monotonically allocated segment;
- owner scope inherited from the attempt and an exact predecessor segment root;
- one active segment per attempt, enforced through guarded root transitions;
- a dedicated execution-writer capability and only closed event predicates;
- append while active, then immutable `Closed`/`Complete` segment lifecycle;
- a hard event/quad/addition limit with closure headroom below 10,000 quads;
- independent exact-set, sequence, start/outcome, and open-effect validation;
- event outcome resources that reference but never mutate prior start subjects;
- links to policy/source/control/content/evidence only in permitted directions;
- run-history retention for semantic shells, independent from payload retention;
- reviewed timeline queries that compose ordered roots without loading an
  unbounded graph.

The root `run/{attempt}` stores attempt transitions, exact repository-control
revision/reference links, first context identity, segment roots/revisions/ranges,
terminal outcome, and closure completeness. Lease and task transitions remain
solely in repository control and are committed atomically with corresponding run
changes; they are not duplicated in the run graph. Root quads and segment count
are hard-bounded, and work continues as a new retry/continuation attempt before
either bound is reached.

### Potential Content Graph Family

If raw bodies have access or retention rules materially different from run
metadata, a dedicated `episode_content` family may be required for graph-native
chunks. It would need:

- repository/attempt plus unique segment identity and homogeneous initial
  content-class/retention scope;
- bounded immutable segment graphs closed atomically by a completeness manifest;
- a dedicated `content_writer` capability;
- an exact literal/content-safe predicate allowlist, owning-event presence guard,
  and no predicate capable of granting policy, decision, evidence, or knowledge
  authority;
- resource-level or class-specific retention;
- strict query capability and no ordinary product projection;
- encryption and erasure behavior, with lifecycle state outside immutable
  segments;
- exact source-to-target link directions and command-specific shapes for
  run/evidence/audit references.

This cannot be added by accepting arbitrary graph names. `GraphRegistry`,
topology, shapes, retention, migration, query catalog, and release manifests all
need versioned changes. Current graph-family checks recognize graph-IRI links,
not the owning family of every ordinary resource IRI, so predicate/shape guards
are required in addition to `allowed_link?/2`.

## Semantic Command Extensions

The secure harness research already proposes the core model-call protocol:

1. Revise `RecordExecutionAttempt` to create the first context/capture manifest
   and first `run_event_segment` event-head atomically with the new root run
   graph and initial transitions.
2. `RecordModelInvocationStart` commits the invocation and exact context
   reference before provider dispatch while consuming the current event head.
3. `RecordModelInvocationOutcome` records the normalized result, usage, body
   capture dimensions, and terminal status as a contiguous successor.
4. Existing tool-start/outcome commands bind exact content captures or explicit
   omission/content-state records; outcomes become separate immutable successor
   resources and participate in segment start/outcome cardinality.
5. `CloseEventSegment` independently proves exact typed-set equality, contiguous
   sequence, and start/outcome/open-effect cardinality for a bounded range.
6. `FinalizeExecutionRun` references bounded ordered segment roots and proves no
   unsegmented execution event or unresolved effect exists through the terminal
   sequence.

Additional semantic commands may be needed for:

- proposing, validating, invalidating, and superseding an `ExperienceCase`;
- proposing, validating, invalidating, and superseding a `ProcedureRevision`;
- recording an artifact freshness check;
- recording a governed retrieval packet and later memory-use assessment;
- authorizing, consuming, and reporting an exact-content access permit;
- placing, reviewing, and releasing retention holds;
- content expiry/erasure and derivative cleanup receipts.

These must be domain-specific commands. A generic `put_event`, `put_memory`, or
record-shaped persistence API would violate accepted architecture.

## Reviewed Query Products

The query catalog should expose bounded semantic questions rather than raw
SPARQL or unrestricted transcript search:

```text
attempt_timeline(attempt, sequence_range, event_classes)
attempt_capture_completeness(attempt)
task_attempt_lineage(task)
exact_failure_occurrences(repository, signature, effective_time)
similar_resolved_cases(repository, task_features, effective_time)
failed_interventions(case_or_signature)
historical_test_risk(repository, changed_symbols, environment)
artifact_claims(repository, symbols, current_revision)
procedures_for_task(repository, task_class, environment, phase)
procedure_evidence(procedure_revision)
issue_change_incident_lineage(resource)
why_does_this_exist(repository, source_selector, effective_time)
memory_source_trace(memory_resource)
memory_contradictions(memory_resource)
memory_use_outcomes(memory_resource)
retained_content_status(event_or_attempt)
```

Every result includes graph/query revisions, scope, completeness, truncation,
effective time, classifications, freshness, and source references. Raw content
requires a separate purpose-bound fetch.

## Retention And Lifecycle

### Retain Metadata Longer Than Payloads

Durable provenance can usually outlive sensitive bodies. A content removal
should preserve non-sensitive facts such as event identity, type, actor IRI,
time, policy, digest/commitment class, capture/lifecycle states, and deletion activity only
when that metadata remains lawful and useful.

### Resource-Level Retention

Graph-family retention is insufficient if payload bodies share a run graph with
immutable provenance. Removing one body advances the closed run revision, makes
revision-pinned evidence stale, and contradicts its closure completeness.
Therefore closed run resources are never selectively deleted. Fine-grained
payload retention uses separately partitioned immutable payload segments or the
governed vault, while append-only `content_lifecycle` transitions describe later
availability. At minimum, retention varies among:

- event metadata;
- exact prompts and responses;
- human messages and personal data;
- tool outputs and source content;
- artifacts and test evidence;
- accepted decisions and knowledge;
- security audit;
- derived indexes and summaries;
- training/evaluation datasets.

### Retention Is Purpose-Bound

Each capture names purposes such as restart recovery, debugging, security audit,
quality evaluation, procedure induction, or accepted organizational memory.
Later training, cross-repository learning, or product analytics requires an
allowed use or a new authorization; it is not implied by collection.

### Queryable Archive

If long-lived recall is a product goal, `archive` cannot mean deletion from the
only queryable dataset. The design must define whether archival content remains
in a cold graph partition, an authorized content vault, or is genuinely removed.
UI and query results must distinguish active, cold, held, expired, and erased.

## Evaluation Program

### Experimental Design

Use chronological cutoffs so an attempt cannot retrieve its eventual patch,
future review, or later incident. Where possible, use repository-level splits to
measure transfer rather than memorization. Fix model, harness, tools, token,
time, and effect budgets across conditions.

Required ablations:

| Condition | Purpose |
| --- | --- |
| No memory | Measure baseline task ability |
| Recent/sliding context | Measure simple recency |
| Full eligible raw evidence | Upper baseline when content fits |
| Recursive summary | Expose compression loss |
| Lexical/BM25 | Establish ordinary retrieval baseline |
| Dense retrieval | Measure semantic retrieval |
| Temporal graph retrieval | Measure relationship/time value |
| Episodic cases only | Measure case-based transfer |
| Procedures only | Measure workflow transfer |
| Hybrid governed memory | Measure target system |
| Oracle evidence | Separate retrieval from reading/reasoning failure |
| Stale/poisoned/mismatched memory | Measure safety and negative transfer |

Run multiple seeds and report memory results separately by model, repository,
task class, access mode, memory age, and retrieval channel.

### Retrieval Metrics

- exact evidence Recall@k and Precision@k;
- file/symbol localization Recall@k and MRR;
- temporal eligibility violations;
- citation correctness and source availability;
- stale, contradicted, incompatible, and cross-scope retrieval rates;
- packet token/byte cost and direct-evidence recovery rate;
- abstention accuracy when no applicable memory exists;
- retrieval latency and index rebuild cost.

### Task Metrics

- accepted patch and independently verified resolution rate;
- review approval without major rework;
- post-merge survival, revert, incident, and regression at 7/30/90 days;
- time/tokens/tool calls/tests/cost per accepted outcome;
- duplicated failed action rate;
- retry-to-success rate;
- test compute, feedback latency, individual-failure recall, and faulty-change
  recall;
- migration completion, automated call sites, exceptions, and backsliding;
- incident time to identify, mitigate, and resolve;
- recurrence of known incident/failure families.

### Memory Quality Metrics

- utility when retrieved versus a matched withheld-memory control;
- negative-transfer incidence;
- procedure success/failure/revert rate by applicability class;
- time from source drift to memory invalidation;
- unsupported or hallucinated derived-memory rate;
- contradiction resolution accuracy;
- memory poisoning attack success;
- secret/personal/cross-tenant leakage;
- erasure completeness across graph, content, indexes, exports, and backups.

### Release Gates

Initial gates should require:

- zero cross-tenant/repository/actor retrieval in adversarial tests;
- zero secret-value capture under the accepted canary suite;
- 100% content-state accounting for expected event classes;
- 100% predecessor continuity, segment exact-set equality, start/outcome
  cardinality, and rejection of unsegmented run resources;
- 100% source and effective-time binding for retrieved memories;
- zero exact-content release without a committed and consumed purpose-bound
  access permit;
- no automatic capability, policy, approval, evidence, or knowledge mutation
  from retrieved content;
- exact invalidation of artifact claims after supporting content changes;
- complete and honestly classified deletion of test objects, indexes, datasets,
  model derivatives, and backups under the defined erasure contract;
- no benchmark future-patch leakage;
- statistically supported benefit on at least one launch product without a
  critical false-acceptance increase;
- immediate disablement on memory poisoning, unauthorized disclosure, or
  deletion failure.

## Rollout Plan

### Phase 0: Resolve Existing Contracts

- Reconcile `Prompt` versus durable `Instruction.content`.
- Reconcile `Raw tool output` versus stored bounded stdout/stderr.
- Align interaction-message classifications with shared `DataPolicy` graph
  placement.
- Define whether archive means cold retention or deletion.
- Define backup physical/cryptographic erasure.
- Resolve plaintext-derived command receipt commitments before storing new
  sensitive exact literals.
- Specify the attempt event-head, bounded segment, exact-set equality, and
  closure precommit protocol.
- Accept or reject proposed `experience`, `content_lifecycle`, and
  `run_event_segment`/`episode_content` graph families with complete
  topology/writer contracts.
- Extend shared `Security.DataPolicy` placement, projection, export, egress,
  Personal-data, redaction, and erasure rules for every accepted family.
- Decide the observable scope of “total memory” and explicitly exclude secrets,
  provider-private state, and hidden chain-of-thought.

### Phase 1: Total Semantic Accounting

- Add episode capture manifests and per-body content-state dimensions.
- Add model invocation start/outcome resources.
- Record exact predecessor-chained event sequence, causality, versions,
  classification, purpose, retention, and content-state dimensions.
- Close bounded event segments by independently proven exact set equality.
- Extend run closure to verify contiguous segment roots and reject missing or
  unsegmented expected execution events.
- Keep exact payload retention within current accepted bounds.

This phase already provides strong continuity and forensic value without a
large-payload archive.

### Phase 2: History Queries

- Add bounded attempt timeline, failure occurrence, issue/change/test lineage,
  rationale, and capture-completeness queries.
- Add temporal validity and current/historical lenses.
- Build disposable lexical indexes from authorized graph content.
- Record retrieval activities and packet manifests.

### Phase 3: Cases And Failure Memory

- Construct success, failure, revert, flake, infrastructure, and ambiguous
  `ExperienceCase` resources.
- Add similarity retrieval with repository/version/applicability filters.
- Evaluate localization, repeated-action avoidance, and retry recovery.
- Keep generated case summaries source-linked and challengeable.

### Phase 4: Artifact Claims And Procedures

- Add artifact-grounded verification claims and freshness checks.
- Induce candidate procedures from multiple cases.
- Require independent execution evidence and explicit lifecycle transitions.
- Add phase-aware procedure retrieval and negative-transfer tracking.

### Phase 5: Exact Content At Scale

- Benchmark graph-native payload chunks under realistic prompts, logs, artifacts,
  backups, retention, and restore.
- If insufficient, write and accept a superseding encrypted-content-vault ADR.
- Implement atomic/recoverable graph-object commit, orphan cleanup, encryption,
  content authorization, deletion, and backup consistency.
- Supersede the privacy/harness contract before enabling `diagnostic_capture`,
  then evaluate it before `project_total_history`.

### Phase 6: Cross-Repository And Training Use

- Require separate purpose and authorization for cohort/cross-repository use.
- Build chronologically clean evaluation and training datasets.
- Balance successes, failures, reverts, and incidents.
- Deduplicate repository/task leakage.
- Keep learned model behavior separate from queryable memory and preserve source
  dataset/version provenance.

## Immediate Product Priorities

The strongest evidence and lowest-risk value order is:

1. Attempt continuity and exact failure history.
2. History-aware test selection and flake evidence.
3. Issue/change/test/artifact provenance and “why does this exist?” queries.
4. Similar failure/resolution cases with strict time and applicability filters.
5. Artifact-grounded verification claims and stale-claim invalidation.
6. Migration and repair playbooks validated across multiple cases.
7. Incident similarity and delayed outcome learning.
8. Full prompt/response transcript retrieval only after privacy, poisoning,
   retention, and measurable-utility gates pass.

This ordering gains much of total memory's software value before creating an
indefinite conversational archive.

## Alternatives Considered

### Keep Only Accepted Knowledge

Rejected as the complete memory strategy. Accepted propositions are useful for
authority but omit attempts, failures, ambiguity, exact evidence, and procedural
learning. They should remain the top semantic layer over richer episodes.

### Keep Every Transcript Forever And Retrieve By Similarity

Rejected. It maximizes privacy, leakage, poisoning, staleness, and context-noise
risk while providing weak temporal and causal semantics. Similarity is not
validity or applicability.

### Summaries Only

Rejected. Summaries reduce cost but make later reinterpretation, parser replay,
forensics, and omitted-detail recovery impossible. They remain useful derived
indexes with direct evidence links.

### Knowledge Graph Only

Rejected. Graphs are strong for relationships, provenance, temporal state, and
multi-hop queries, but extraction can lose exact syntax, command output, and
artifact content. Keep exact governed evidence behind graph resources.

### Long Context Only

Rejected. It provides no cross-session durability, update/invalidation model,
purpose-bound access, erasure, procedural consolidation, or efficient selection.
It remains an important evaluation baseline.

### Model Fine-Tuning As Memory

Rejected as the queryable memory of record. Parametric learning obscures source,
scope, correction, and erasure. Fine-tuning may use separately governed datasets
after the evidence and evaluation system exists.

## Final Recommendation

JidoCode should expand from **governed accepted memory** to **governed total
experience**, while preserving the boundaries that make the graph trustworthy.

The desired system remembers:

- what happened;
- what information was available;
- what was attempted;
- what effects occurred;
- what failed and why that diagnosis was proposed;
- what evidence later established;
- what humans accepted or rejected;
- what changed afterward;
- which lessons remain valid;
- which procedures work under which conditions;
- and which content is missing, redacted, expired, or erased.

It does not pretend to remember unobserved provider state or hidden reasoning.
It does not make old text authoritative. It does not inject the full archive into
the prompt. It does not retain secrets for hypothetical future value. It does
not hide deletion or completeness gaps.

The durable principle should be:

> Capture every eligible event, account for every expected body, retain exact
> evidence when a declared purpose and policy justify it, derive memories without
> destroying provenance, retrieve selectively, validate in the current world,
> and promote only through governed evidence and decision.

## Sources

### JidoCode Architecture

1. JidoCode, [Graph-Only Source Of Truth](../adr/0001-graph-only-source-of-truth.md).
   Defines the sole durable application-owned RDF dataset and requires a
   superseding ADR for an application-owned blob store.
2. JidoCode, [TripleStore Backend Contract](../adr/0002-triple-store-backend-contract.md).
   Defines the pinned embedded backend and one-writer boundary.
3. JidoCode, [Graph Identity And Topology](../architecture/graph-identity-and-topology.md).
   Defines closed graph families, writer roles, lifecycle, links, and retention.
4. JidoCode, [Execution Runtime Boundary](../architecture/execution-runtime-boundary.md).
   Defines disposable runtime state and durable bounded interaction messages.
5. JidoCode, [Execution Effects And Provenance](../architecture/execution-effects-provenance.md).
   Defines tool invocation, bounded output, artifacts, and effect ordering.
6. JidoCode, [Execution Provenance And Recovery](../architecture/execution-provenance-and-recovery.md).
   Defines immutable run closure, completeness, and graph-driven recovery.
7. JidoCode, [Verification And Evidence Boundary](../architecture/verification-evidence-boundary.md).
   Separates raw outcomes, evidence, and acceptance.
8. JidoCode, [Governed Decision Outcomes](../architecture/governed-decision-outcomes.md).
   Defines decision dispositions, actor separation, and rationale references.
9. JidoCode, [Governed Knowledge Memory](../architecture/governed-knowledge-memory.md).
   Defines accepted proposition memory and excludes raw prompt/transcript/output
   adoption.
10. JidoCode, [Product Security, Privacy, And Threat Model](../architecture/product-security-privacy-and-threat-model.md).
    Defines current content classifications and durable locations.
11. JidoCode, [Secure And Effective Agent Harness](./secure-effective-agent-harness.md).
    Defines model access, context manifests, disposable runtime, and governed
    model/tool provenance.
12. JidoCode, [Backup, Restore, And Integrity](../architecture/backup-restore-and-integrity.md).
    Defines recovery artifacts, restore integrity, and backup-retention limits.

### Agent Memory Foundations And Systems

13. Theodore R. Sumers et al., [Cognitive Architectures for Language
    Agents](https://arxiv.org/abs/2309.02427), TMLR, 2024. Defines CoALA's
    modular working, episodic, semantic, and procedural memory architecture.
14. Joon Sung Park et al., [Generative Agents: Interactive Simulacra of Human
    Behavior](https://doi.org/10.1145/3586183.3606763), UIST, 2023. Combines an
    observation stream, relevance/recency/importance retrieval, reflection, and
    planning.
15. Noah Shinn et al., [Reflexion: Language Agents With Verbal Reinforcement
    Learning](https://doi.org/10.52202/075280-0377), NeurIPS, 2023. Retains
    feedback-derived reflections for iterative improvement.
16. Andrew Zhao et al., [ExpeL: LLM Agents Are Experiential
    Learners](https://doi.org/10.1609/aaai.v38i17.29936), AAAI, 2024. Retrieves
    successful trajectories and extracts insights from success/failure pairs.
17. Guanzhi Wang et al., [Voyager: An Open-Ended Embodied Agent With Large
    Language Models](https://arxiv.org/abs/2305.16291), 2023 preprint. Studies
    executable skills, curriculum, and environment feedback.
18. Charles Packer et al., [MemGPT: Towards LLMs As Operating
    Systems](https://arxiv.org/abs/2310.08560), 2023 preprint. Introduces
    self-directed context paging among active, recall, and archival memory.
19. Wanjun Zhong et al., [MemoryBank: Enhancing Large Language Models With
    Long-Term Memory](https://doi.org/10.1609/aaai.v38i17.29946), AAAI, 2024.
    Studies dialogue, summaries, user portraits, retrieval, and decay.
20. Weizhi Wang et al., [Augmenting Language Models With Long-Term Memory
    (LongMem)](https://arxiv.org/abs/2306.07174), NeurIPS, 2023. Uses a decoupled
    memory encoder and cached past states for long-context tasks.
21. Zora Zhiruo Wang et al., [Agent Workflow
    Memory](https://proceedings.mlr.press/v267/wang25bx.html), ICML, 2025.
    Induces and selectively reuses workflows across long-horizon web tasks.
22. Parth Sarthi et al., [RAPTOR: Recursive Abstractive Processing For
    Tree-Organized Retrieval](https://arxiv.org/abs/2401.18059), ICLR, 2024.
    Builds hierarchical clusters and summaries for multi-level retrieval.
23. Darren Edge et al., [From Local To Global: A Graph RAG Approach To
    Query-Focused Summarization](https://arxiv.org/abs/2404.16130), 2024
    preprint. Evaluates graph community summaries for global sensemaking.
24. Bernal Jiménez Gutiérrez et al., [HippoRAG: Neurobiologically Inspired
    Long-Term Memory For Large Language Models](https://arxiv.org/abs/2405.14831),
    NeurIPS, 2024. Uses a knowledge graph and personalized PageRank for
    associative retrieval.
25. Wujiang Xu et al., [A-MEM: Agentic Memory For LLM
    Agents](https://arxiv.org/abs/2502.12110), NeurIPS, 2025. Uses dynamically
    linked Zettelkasten-style notes and memory evolution.
26. Prateek Chhikara et al., [Mem0: Building Production-Ready AI Agents With
    Scalable Long-Term Memory](https://arxiv.org/abs/2504.19413), 2025
    vendor-authored preprint. Evaluates extracted vector and graph memory against
    conversational baselines and full context.
27. Preston Rasmussen et al., [Zep: A Temporal Knowledge Graph Architecture For
    Agent Memory](https://arxiv.org/abs/2501.13956), 2025 vendor-authored
    preprint. Represents episodes, entities, facts, and temporal validity.

### Memory Benchmarks And Recent Software-Agent Work

28. Adyasha Maharana et al., [Evaluating Very Long-Term Conversational
    Memory Of LLM Agents (LoCoMo)](https://aclanthology.org/2024.acl-long.747/),
    ACL, 2024. Evaluates long multi-session conversational recall and reasoning.
29. Di Wu et al., [LongMemEval: Benchmarking Chat Assistants On Long-Term
    Interactive Memory](https://arxiv.org/abs/2410.10813), ICLR, 2025. Separates
    indexing, retrieval, and reading over extraction, multi-session, temporal,
    update, and abstention tasks.
30. Haoran Tan et al., [MemBench: Towards More Comprehensive Evaluation On The
    Memory Of LLM-Based Agents](https://aclanthology.org/2025.findings-acl.989/), Findings of
    ACL, 2025. Evaluates factual/reflective memory, capacity, and read/write cost.
31. Ding Chen et al., [HaluMem](https://arxiv.org/abs/2511.03506), 2025 preprint,
    revised 2026. Studies hallucinations introduced during memory extraction,
    updating, and use.
32. Yujie Zhao et al., [AMA-Bench: Evaluating Long-Horizon Memory For Agentic
    Applications](https://arxiv.org/abs/2602.22769), 2026 preprint. Evaluates
    causal, symbolic, objective, and abstract memory over machine trajectories.
33. Yuyao Wang et al., [EvoMemBench](https://arxiv.org/abs/2605.18421), 2026
    preprint. Compares memory methods across context budgets and knowledge versus
    execution tasks.
34. Silin Chen et al., [SWE-Exp: Experience-Driven Software Issue
    Resolution](https://arxiv.org/abs/2507.23361), 2025 preprint, revised 2026.
    Distills successful and failed repair experiences for SWE-bench Verified.
35. [CODESKILL: Learning Self-Evolving Skills For Coding
    Agents](https://arxiv.org/abs/2605.25430), 2026 preprint. Learns procedural
    skill extraction, evolution, merge, and deletion using execution and judge
    rewards.
36. [SWE-MeM](https://arxiv.org/abs/2606.28434), 2026 preprint. Trains agents to
    decide when, what, and how to compress active software-task history.
37. [PMCoder](https://arxiv.org/abs/2608.06811), 2026 preprint. Combines phase
    planning, episodic retrieval, observations, verification, and stuck
    detection.
38. [ContextSniper](https://arxiv.org/abs/2607.01916), 2026 preprint. Evaluates
    recoverable multi-level context compression and hybrid retrieval for coding
    agents.
39. [EA-Graph](https://arxiv.org/abs/2608.04278), 2026 preprint. Studies
    artifact-anchored claims with separate evidence strength and freshness.
40. [Persistent Recursive Worlds](https://arxiv.org/abs/2608.10450), 2026
    preprint. Reports long-lived project continuity across finite-lived agents.

### Software Engineering And Organizational Memory

41. Carlos E. Jimenez et al., [SWE-bench: Can Language Models Resolve Real-World
    GitHub Issues?](https://arxiv.org/abs/2310.06770), ICLR, 2024. Defines
    repository issue-to-patch tasks and executable evaluation.
42. OpenAI, [Introducing SWE-bench
    Verified](https://openai.com/index/introducing-swe-bench-verified/), 2024.
    Documents expert filtering of ambiguous and unfair SWE-bench tasks.
43. John Yang et al., [SWE-agent: Agent-Computer Interfaces Enable Automated
    Software Engineering](https://doi.org/10.52202/079017-1601), NeurIPS, 2024.
    Shows the importance of semantic tool/interface design.
44. Xingyao Wang et al., [OpenHands: An Open Platform For AI Software Developers
    As Generalist Agents](https://arxiv.org/abs/2407.16741), ICLR, 2025. Provides
    sandboxed event-oriented software-agent infrastructure.
45. Chunqiu Steven Xia et al., [Demystifying LLM-Based Software Engineering
    Agents](https://doi.org/10.1145/3715754), PACMSE/FSE, 2025. Demonstrates a
    fixed localization, repair, and validation procedure through Agentless.
46. Shuzheng Gao et al., [RepoCoder: Repository-Level Code Completion Through
    Iterative Retrieval And Generation](https://doi.org/10.18653/v1/2023.emnlp-main.151),
    EMNLP, 2023. Shows iterative retrieval-generation improvements for
    repository completion.
47. Siru Ouyang et al., [RepoGraph: Enhancing AI Software Engineering With A
    Repository-Level Code Graph](https://arxiv.org/abs/2410.14684), ICLR, 2025.
    Evaluates definition/reference graph context and context-noise failure.
48. Jiayi Pan et al., [Training Software Engineering Agents And Verifiers
    With SWE-Gym](https://arxiv.org/abs/2412.21139), ICML, 2025. Uses executable
    repository tasks and trajectories for agent/verifier training.
49. Mateusz Machalica et al., [Predictive Test Selection](https://arxiv.org/abs/1810.05286),
    ICSE-SEIP, 2019. Reports production test-cost reduction with high failure
    retention at Facebook.
50. Qingzhou Luo et al., [An Empirical Analysis Of Flaky
    Tests](https://doi.org/10.1145/2635868.2635920), FSE, 2014. Classifies flaky
    test causes and fixes across open-source projects.
51. Google Testing Blog, [Flaky Tests At Google And How We Mitigate
    Them](https://testing.googleblog.com/2016/05/flaky-tests-at-google-and-how-we.html),
    2016. Practitioner observations on flake prevalence and mitigation.
52. David A. Tomassi et al., [BugSwarm: Mining And Continuously Growing A Dataset Of
    Reproducible Failures And Fixes](https://doi.org/10.1109/ICSE.2019.00048),
    ICSE, 2019. Captures reproducible fail/pass CI pairs and environments.
53. Johannes Bader et al., [Getafix: Learning To Fix Bugs
    Automatically](https://doi.org/10.1145/3360585), OOPSLA, 2019. Learns and
    ranks hierarchical fix patterns from human changes.
54. Jian Zhou et al., [Where Should The Bugs Be Fixed?
    BugLocator](https://doi.org/10.1109/ICSE.2012.6227210), ICSE, 2012. Uses bug
    report similarity and previously fixed bugs for localization.
55. Wu et al., [ReLink: Recovering Links Between Bugs And
    Changes](https://doi.org/10.1145/2025113.2025120), ESEC/FSE, 2011. Recovers
    missing issue/change links with explicit precision/recall limits.
56. Diego Rodriguez-Perez et al., [Evaluating SZZ Implementations: An Empirical
    Study On The Linux Kernel](https://doi.org/10.1109/TSE.2024.3406718), IEEE
    TSE, 2024. Quantifies uncertainty and ghost commits in bug-introducing change
    inference.
57. Betsy Beyer et al., [Postmortem Culture: Learning From
    Failure](https://sre.google/sre-book/postmortem-culture/), Google SRE Book,
    2016. Practitioner guidance for reviewed, blameless incident learning.
58. Titus Winters et al., [Knowledge
    Sharing](https://abseil.io/resources/swe-book/html/ch03.html), Software
    Engineering at Google, 2020. Discusses information islands, canonical
    sources, searchability, ownership, and staleness.
59. Titus Winters et al., [Large-Scale
    Changes](https://abseil.io/resources/swe-book/html/ch22.html), Software
    Engineering at Google, 2020. Describes dependency indexes, migration
    tooling, sharding, tests, flake handling, and playbooks.

### Security, Privacy, Provenance, And Governance

60. Zhaorun Chen et al., [AgentPoison: Red-Teaming LLM Agents Via Poisoning
    Memory Or Knowledge Bases](https://doi.org/10.52202/079017-4136), NeurIPS,
    2024.
    Demonstrates stealthy targeted poisoning of long-term agent retrieval.
61. Shen Dong et al., [Memory Injection Attacks On LLM Agents Via Query-Only
    Interaction](https://doi.org/10.52202/085713-1554), NeurIPS, 2025. The
    public preprint was revised in 2026. Shows memory injection without direct
    memory-store access.
62. Wei Zou et al., [PoisonedRAG: Knowledge Corruption Attacks To Retrieval-
    Augmented Generation Of Large Language Models](https://www.usenix.org/conference/usenixsecurity25/presentation/zou-poisonedrag),
    USENIX Security, 2025. Evaluates targeted corpus poisoning at scale.
63. Kai Greshake et al., [Not What You've Signed Up For: Compromising Real-World
    LLM-Integrated Applications With Indirect Prompt
    Injection](https://arxiv.org/abs/2302.12173), 2023. Demonstrates remote
    instructions embedded in retrieved data.
64. Miles Turpin et al., [Language Models Don't Always Say What They Think:
    Unfaithful Explanations In Chain-Of-Thought
    Prompting](https://arxiv.org/abs/2305.04388), NeurIPS, 2023. Shows
    rationalization and undisclosed bias effects.
65. Yanda Chen et al., [Reasoning Models Don't Always Say What They
    Think](https://arxiv.org/abs/2505.05410), 2025 preprint. Evaluates low
    faithfulness of disclosed hint use in reasoning traces.
66. [Safer Reasoning Traces](https://arxiv.org/abs/2603.05618), 2026 preprint.
    Studies privacy leakage and gatekeeping for chain-of-thought traces.
67. John X. Morris et al., [Text Embeddings Reveal (Almost) As Much As
    Text](https://aclanthology.org/2023.emnlp-main.765/), EMNLP, 2023.
    Demonstrates source reconstruction risks from embeddings.
68. W3C, [PROV-O: The PROV Ontology](https://www.w3.org/TR/prov-o/), W3C
    Recommendation, 2013. Defines interoperable entities, activities, agents,
    derivation, attribution, delegation, revision, and invalidation.
69. European Union, [General Data Protection Regulation](https://eur-lex.europa.eu/eli/reg/2016/679/oj),
    2016. Defines applicable purpose, minimization, storage, security, erasure,
    privacy-by-design, and impact-assessment obligations.
70. European Union, [Artificial Intelligence Act](https://eur-lex.europa.eu/eli/reg/2024/1689/oj/eng),
    2024. Defines logging and governance obligations for applicable systems
    without mandating universal payload retention.
71. NIST, [Artificial Intelligence Risk Management Framework
    1.0](https://doi.org/10.6028/NIST.AI.100-1), 2023, and [Generative AI
    Profile](https://doi.org/10.6028/NIST.AI.600-1), 2024. Define lifecycle
    governance and generative-AI privacy, integrity, security, and value-chain
    risk considerations.
72. NIST, [Privacy Framework 1.0](https://doi.org/10.6028/NIST.CSWP.01162020),
    2020. Defines lifecycle privacy-risk outcomes and data governance.
73. OWASP, [LLM01 Prompt Injection](https://genai.owasp.org/llmrisk/llm01-prompt-injection/),
    [LLM04 Data And Model Poisoning](https://genai.owasp.org/llmrisk/llm042025-data-and-model-poisoning/),
    and [LLM08 Vector And Embedding Weaknesses](https://genai.owasp.org/llmrisk/llm082025-vector-and-embedding-weaknesses/),
    2025. Practitioner guidance for least privilege, provenance, validation,
    isolation, and retrieval security.
74. SLSA, [Build Provenance v1.2](https://slsa.dev/spec/v1.2/build-provenance).
    Defines selective attestations for builder, inputs, dependencies, execution,
    and outputs rather than retaining every intermediate byproduct.
75. Santiago Torres-Arias et al., [in-toto: Providing Farm-To-Table Guarantees
    For Bits And Bytes](https://www.usenix.org/conference/usenixsecurity19/presentation/torres-arias),
    USENIX Security, 2019. Cryptographically verifies expected supply-chain
    steps, actors, and ordering.
76. Luke Hinds et al., [Sigstore: Software Signing For
    Everybody](https://doi.org/10.1145/3548606.3560596), CCS, 2022. Connects
    signatures, authenticated identities, transparency, and monitoring.

## Milestones

1. Contract reconciliation: content classifications, retention semantics, and
   proposed graph families accepted or rejected through architecture decisions.
2. Total semantic accounting: episode capture manifests, multidimensional content
   state, and bounded verifiable event segments for every attempt.
3. History queries: bounded timelines, failure search, and lineage lenses over
   disposable lexical indexes.
4. Cases and failure memory: ExperienceCase resources with applicability-filtered
   similarity retrieval.
5. Artifact claims and procedures: artifact-grounded claims with freshness, and
   validated ProcedureRevision workflows.
6. Exact content at scale: benchmarked payload storage, with an encrypted-content
   vault ADR only if graph-native chunks prove insufficient.
7. Cross-repository and training uses enabled under separate purpose and
   authorization with leakage-controlled datasets.
