# Phase 9 Accepted Outcome And Learning Receipt

## Status

This receipt records the Phase 9 candidate verified locally on 2026-08-03 and
accepted after pull request merge on 2026-08-04.
Verification, evidence, explicit decisions, final satisfaction, knowledge
adoption/evolution, bounded reasoning, and cross-repository proposals are
implemented through the graph-only authority boundary.

G8 is accepted at merged candidate `de5e5a34e50bd23d71ee14742bccb18cdae0711d`.
The pull request passed its required checks and the merge was fast-forwarded
into the Phase 10 baseline. No local
evidence found runtime output becoming accepted directly, knowledge losing its
decision/evidence provenance, or inference mutating command, control,
acceptance, lease, satisfaction, or adoption state.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Phase baseline and merged G7 | `6a0b3d192e5b87862d2735ccfcfc7f4dcff28631` |
| Section 9.1 | `82101b922de55cde1ad7a27a212e9e70516005a5` - govern verification evidence |
| Section 9.2 | `766f304418880242659dac3f70723280ade05f1a` - govern outcome decisions |
| Section 9.3 | `6a9a2ebab74fd4d2f884e59d337a8512d5c0caea` - govern knowledge adoption |
| Section 9.4 | `dda6b26a118ebb5bee962ffef9990b6eebf767cc` - bound graph reasoning |
| Section 9.5 | This receipt and its integration tests; exact commit recorded by Git history |
| Merged candidate | `de5e5a34e50bd23d71ee14742bccb18cdae0711d` |

## Contract Pins

| Contract | Accepted candidate value |
| --- | --- |
| Verification method fixture | `test_execution` / `1.0.0`; complete mandatory checks |
| Policy/evidence rule | `protected-main/1.0.0`; sufficiency recomputed from exact source revisions |
| Command protocol | `1.7.0`; 38 registered intent commands |
| Query catalog | `1.7.0`; 102 reviewed queries |
| Query catalog SHA-256 | `cbf055c75813021b4f8d25df01a52061f48511f4f3d0e3bf363a4ff6d9ab28e0` |
| Reasoning profiles | class/capability hierarchy, repository cohort, safe dependency transitivity, knowledge applicability, and safe OWL 2 RL |
| Reasoning rule/query fixture | rule revisions `0` and `1`; `phase-nine-integration/1.0.0` |
| Factory ontology / operational shapes | `1.0.0` / `1.0.0` |
| Ontology package SHA-256 | `5ce8be304d026d5eeaaf3693caceee6dc675e4325089f33e1e3f8b73535c5903` |
| TripleStore pin | `6dc1b6d985f4805f9856858e0c0047b9f2d5ad7f` |
| Source snapshot IRI | `https://jido.run/id/repository-snapshot/47c4434f3f3a830fae73502eb2a1fe43` |
| Patch artifact / digest | `https://jido.run/id/patch-artifact/d60cdb5f8112c9c587d625c86fb11973`; `sha256:85c1e25255455dad35ecfeb199f7b6d4da3e688cbb150e3c7a9ce60444313d2a` |
| Evidence bundle | `https://jido.run/id/evidence-bundle/18ff7188eec9d660c5acaed3c23680de` |
| Accepted decision | `https://jido.run/id/goal-outcome-decision/2a2452ca4d0495fe5944aaa3fd8fff61` |
| Knowledge assertion | `https://jido.run/id/knowledge-assertion/d9b52239437f5d8a31dd536a26f001cd` |
| Adoption activity | `https://jido.run/id/adoption-activity/185dc463b1011570ce5e8a6df8ddb65b` |

## Accepted Contract

- Runtime completion remains operational provenance. A versioned verification
  activity evaluates exact attempt, snapshot, artifact, environment, check,
  and source revisions before an evidence bundle can be recorded.
- Evidence records support, contradiction, method, evaluator, coverage,
  completeness, validity, limitations, and proposed claims atomically. A
  sufficiency receipt is advisory and has no transition or acceptance authority.
- A decision independently recomputes sufficiency, enforces actor separation,
  policy and revision freshness, and records authored rationale. It may append
  accepted transitions and proposed follow-up work but cannot perform direct
  external effects.
- Final goal satisfaction requires a post-change snapshot plus an exact
  external confirmation. The final command can atomically append the accepted
  goal path and explicitly related task, obligation, and desired-outcome
  transitions.
- Knowledge adoption accepts only claim successors from a current accepted
  decision. The memory graph preserves evidence, policy, source snapshot,
  actor, applicability, validity, limitations, confidence, and initial state.
- Later evidence never edits an assertion. Review, contradiction,
  invalidation, and supersession are append-only transitions caused by an
  explicit decision, and retrieval resolves the accepted endpoint.
- Reasoning runs a closed TripleStore profile under fact, iteration, time, byte,
  graph, and source limits. Complete output is validated in isolation and
  atomically replaces a disposable derived graph with exact source metadata.
- Inference cannot issue a command, grant authority/lease, accept evidence,
  satisfy a goal, or adopt knowledge. Derived classifications always retain
  `authority?: false` in feedback projections.
- Cross-repository queries are not exposed through the generic public query
  boundary. The dedicated insight boundary filters invisible rows before
  grouping and returns only thresholded proposals requiring independent
  evidence and target policy authorization.
- Reconciliation and execution feedback packages bind exact memory, derived,
  rule, query, and source revisions. Prompt context remains ephemeral, and any
  revision change invalidates the package.
- Outcome improvement is a new evidence-backed measurement. It never silently
  changes assertion confidence or adoption state.

## Fixture Identity

| Evidence fixture | SHA-256 |
| --- | --- |
| Verification/evidence fixture | `e11c21262297d22f7669d8feaf80fe9217079dd25452b22ea80d6f89f2b0ed92` |
| Decision fixture | `5de3e63b7f1fddd8d5278a77fd1d5f0e00d11a050260d824e1ddc0bc2f56ab0c` |
| Knowledge fixture | `189aed8a2774cf047ce8fe13aa97b16e77223522e49cb13698c0ac318e078281` |
| Accepted-outcome/learning integration scenarios | `2256944fbb84719cd7168da92ce641d1e93fa1fa92e9058cdea50d7cc44214b2` |
| Evidence negative scenarios | `cac6b878b93b5a2c3dc547dd6ae246741576e57cf198264d492439be573cdfa1` |
| Decision negative scenarios | `5907c6abec5b25fa30a95dd6d29661e9e0097c65e30d84318d5380dda0bbad17` |
| Memory/evolution scenarios | `a04fe1f3c1cb395d41d1627dfbe5d35315e6b170efb22fd9d29974a4a826fb21` |
| Reasoning/learning scenarios | `a3d10b7826760931098bc1eca00b71fec8d0ea36a0bec35bae9aad8618374681` |

The fixtures start the real StoreServer, Writer, QueryRunner, Maintenance, and
embedded TripleStore; load the pinned ontology; reconstruct Phases 6-8 source,
control, lease, attempt, tool, and artifact provenance; and commit every durable
Phase 9 state through semantic commands. Fixed clocks, deterministic identities,
exact graph revisions, and isolated temporary stores make replay, stale,
restore, and reasoning results comparable.

## Executable Evidence

The Phase 9 focused and integration suites prove:

- one completed patch is verified, recorded as evidence, assessed, accepted by
  an independent decision actor, adopted as knowledge, verified after change,
  and finally satisfies the goal plus explicitly related obligation and desired
  outcome without direct effects;
- later contradictory evidence produces a contradicted sufficiency receipt, a
  superseding decision, superseded control endpoints, knowledge review, and
  final invalidation while preserving the complete historical assertion;
- failed, skipped, unknown, incomplete, stale, mismatched-snapshot,
  cross-scope, hidden mandatory failure, missing independent review, policy
  conflict, waiver, defer, reject, and request-more-evidence paths remain
  explicit and fail closed where required;
- self-approval, direct effects, stale sufficiency/revision replay, unsupported
  claims, raw prompt/tool output, secret-bearing content, over-broad scope, and
  unsupported knowledge classifications are rejected;
- command replay is idempotent, divergent/stale writes conflict, and accepted
  task/goal/obligation/desired-outcome plus follow-up reconciliation facts
  commit through one causal semantic command;
- derived output can be materialized, queried, detected stale, explicitly
  marked stale, deleted, and rebuilt from a new source/rule revision without
  changing the accepted decision or memory assertion;
- cross-repository candidate insight hides repositories below its visible
  source threshold and cannot be passed directly to knowledge adoption; and
- backup/restore reconstructs the same decision projection and exact knowledge
  retrieval result from graph revisions after later evidence is discarded.

## Verification Record

| Command or gate | Result |
| --- | --- |
| Phase 9 final integration file | 3 tests, 0 failures |
| Phase 9 focused and integration files | 22 tests, 0 failures |
| `mix precommit` | 261 tests, 0 failures; compile, architecture, lock, format, and test gates passed |
| `mix jido_code.ontology verify` | Package and canonical ontology digests verified |

No frontend or asset behavior changed in Phase 9, so browser and production
asset gates remain inherited from the merged Phase 8 baseline.

## Operational Limits

- Evidence evaluation admits at most 200 bundles, eight exact source graphs,
  20 environments/reviewers, 100 targets, checks, claims, support, or
  contradiction refs, and fixed method duration/artifact/check bounds.
- Decision records admit at most 30 rationale, confirmation, evidence, and
  supersession refs and 20 explicitly related control resolutions. Every
  confirmation includes an exact observation graph revision.
- Knowledge retrieval uses the reviewed 200-row query limit, returns at most
  the caller's bounded result count, and rechecks scope, classification,
  validity, contradiction, and every source revision for each execution context.
- Reasoning admits at most 2,000 input facts, 800 derived facts, 50 iterations,
  10 seconds, 5,000,000 encoded bytes, eight source graphs, and 900 published
  statements. Integration fixtures use 100/200 facts, 20 iterations, five
  seconds, and 250,000 bytes.
- Insight projection admits 500 reviewed rows, 200 authorized/visible
  repositories, and a two-to-20 visible source threshold. Learning execution
  packages admit at most 100 items, 100,000 bytes, and 25,000 estimated tokens.
- Reviewed queries retain the five-second, 200-row, 500-triple, 256,000-byte,
  20-graph, and 100-parameter defaults.

## Gate G8

G8 is accepted at merged candidate `de5e5a34e50bd23d71ee14742bccb18cdae0711d`,
pinned in this receipt and the Phase 9 plan. Any
evidence that runtime output can bypass verification/decision, accepted
knowledge can lose provenance or contradiction history, hidden repositories
can leak through insights, or inference can mutate accepted/control state
reopens the gate.
