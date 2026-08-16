# Phase 4 Controlled Mutation Receipt

## Status

This receipt records the Phase 4 candidate verified locally on 2026-07-31 and
accepted after pull request merge on 2026-08-01.
Versioned intent commands, graph-native change sets, current semantic
authorization, one-time bootstrap, atomic assertion provenance, semantic
audit, idempotency recovery, and disposable change delivery are implemented
and pass the local repository gates.

G3 is accepted at merged candidate `b99826b447260cef998b62b3053586aa857eea4f`
after the pull request passed clean-checkout CI on 2026-08-01. No
local evidence found a partial semantic commit, unauthorized outcome
disclosure, duplicate idempotent effect, authoritative PubSub dependency, raw
secret in RDF or public receipts, or visible assertion without deterministic
change-set provenance.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Phase baseline and merged G2 | 3b59f8e659f5bcc9453897236b70893351157b81 |
| Section 4.1 | 3c4b3ee - define semantic command contracts |
| Section 4.2 | 499fb67 - implement governed semantic command pipeline |
| Section 4.3 | d1a03d6 - implement semantic authority and bootstrap |
| Section 4.4 | 2eb3276 - implement change delivery and command recovery |
| Section 4.5 | This receipt and its integration tests; exact commit recorded by Git history |
| Merged candidate | `b99826b447260cef998b62b3053586aa857eea4f` |

## Contract Pins

| Contract | Accepted candidate value |
| --- | --- |
| Command registry version | 1.0.0 |
| Registered intent commands | 12 |
| Factory ontology version | 1.0.0 |
| Operational shape version | 1.0.0 |
| Validator version | 1.0.0 |
| Graph registry revision | 1.0.0 |
| Ontology package SHA-256 | 5ce8be304d026d5eeaaf3693caceee6dc675e4325089f33e1e3f8b73535c5903 |
| Canonical ontology N-Quads SHA-256 | fe260c98204872ace7369728c4db13696f76c724cc5f06b4bfe7bf5b18569e41 |
| Ontology manifest SHA-256 | 90414444e0034823f1a4d411a8a7b6611415af3e35f167da2591db5d0c07ed56 |
| TripleStore pin | 6dc1b6d985f4805f9856858e0c0047b9f2d5ad7f |
| Transaction strategy | One synchronous atomic multi-graph write batch; no staging graph |
| Request/assertion digest | SHA-256 over deterministic command material/canonical N-Quad |
| Audit partition | Registered monthly security-audit graph |
| Notification transport | Phoenix PubSub, fixed SHA-256 scope topic, non-authoritative |

The registry contains EnrollRepository, RecordObservationBatch,
AssertDesiredOutcome, ProposeGoal, AdoptPlan, AcquireExecutionLease,
RecordExecutionAttempt, RecordVerificationEvidence, DecideGoalOutcome,
AdoptKnowledge, SupersedeClaim, and RetireEnrollment.

The capability model separates observation, proposal, control, execution,
evidence, decision, ontology, security, and administrative authority. Grants
and delegations are RDF in the factory policy graph. Authentication and route
admission remain outside the writer.

## Accepted Contract

- A command envelope is transient and redacted. Its stable command, request,
  change-set, receipt, actor, cause, scope, and validation identities are RDF
  or deterministically reconstructable from RDF-bound material.
- Every successful semantic command commits domain additions, canonical
  assertion digests, provenance, audit outcome, graph revisions, and substrate
  receipt in one synchronous batch.
- Authorization and validation read one bounded semantic snapshot. Exactly one
  matching current grant and, when delegated, exactly one constrained current
  delegation are required.
- Bootstrap is local, token-digest guarded, one-time, and permanently disabled
  by initialized graph state. The operator token is never persisted.
- Equivalent idempotency replay returns the original durable result. Divergent
  reuse conflicts, stale revisions fail without partial visibility, and an
  unknown response is resolved by the retained identity.
- Command status reauthorizes at trusted lookup time and combines the system
  receipt with semantic audit outcome. Guessed identities and revoked or
  expired authority return an inaccessible projection.
- Change events contain revisions, graph families, scope, command class, and
  receipt IRI only. Subscribers re-query graph state and remain correct under
  loss, duplication, delay, and reordering.

## Fixture Identity

| Evidence fixture | SHA-256 |
| --- | --- |
| Shared real-substrate command fixture | 863a9a74faf7918be676d6734dd7ec20ef9de5ead900cdb8367e1b3dddbc1d70 |
| Cross-graph command, provenance, and restore integration | 2950d79222e90db5cb4902c33939b42e5f60d9a26c2bc3e9a378c246d79269be |
| Race, process-loss, concealment, notification, and secret falsification | 4985ad5a95cb5c8c30ad3c65a028922d68ca9d545fcf2675ed1b9e1d3e073076 |

The fixtures start the real StoreServer, Writer, QueryRunner, and Maintenance
processes, load the pinned ontology, execute secure bootstrap, and use semantic
command envelopes plus fixed maintenance operations. They do not obtain a raw
store handle or create an alternate persistence authority.

## Executable Evidence

The Phase 4 integration suite proves:

- catalog enrollment, policy assertion, control graph creation, monthly audit,
  and immutable observation-batch creation through the production writer;
- deterministic trace from a visible canonical assertion digest to change set,
  command, actor, cause, ontology/shape/validator versions, authority grant,
  semantic receipt, substrate commit, and affected graph revisions;
- rejection of unauthorized, invalid-shape, stale-revision, revoked,
  cross-boundary, immutable-rewrite, conflicting-idempotency, and generic CRUD
  cases without a partial domain effect;
- checkpoint backup, standards-based export, restore, status lookup, and
  equivalent replay preserve audit and idempotency identities;
- equivalent concurrent replay has one effect, divergent reuse conflicts, and
  stale concurrent commands have exactly one winner;
- writer death before dispatch yields authoritative unknown, writer/client
  response loss after dispatch recovers the committed receipt, and restart
  never duplicates the effect;
- expired and revoked delegation, graph-boundary widening, guessed command
  identities, and direct audit enumeration fail closed;
- dropped, duplicated, delayed, and reordered notifications converge by
  re-querying the authoritative dataset revision; and
- fixture secrets are absent from captured logs, inspected envelopes,
  receipts, events, status projections, and canonical RDF export.

The full suite also reruns the Phase 2 external-BEAM/store crash tests and all
Phase 1-3 architecture, substrate, ontology, topology, validation, temporal,
transition, migration, restore, and inference evidence.

## Verification Record

| Command or gate | Result |
| --- | --- |
| Phase 4 integration files | 6 tests, 0 failures |
| mix precommit | 138 tests, 0 failures; compile, architecture, lock, and format gates passed |
| mix jido_code.ontology verify | Package and canonical digests verified |
| mix hex.audit | No retired packages found |
| npm audit --omit=dev | 0 vulnerabilities |
| MIX_ENV=prod mix assets.build | Vite client and SSR bundles built successfully with an ephemeral SECRET_KEY_BASE |

## Operational Limits

- One command admits at most 1,000 effective additions and 16 target graphs.
  One semantic snapshot admits at most 20 registered graphs and 10,000 quads.
- Audit graphs are append-only monthly partitions. Protected payload classes,
  secret-like literals, prompts, source bodies, raw SPARQL, and stack traces
  are rejected from audit data.
- The accepted atomic backend has no staged/uncommitted state. The status
  vocabulary reserves that outcome but never fabricates process-local staging.
- PubSub is node-local and disposable. Phase 5 query projections own
  authorization-aware product subscription and periodic reconciliation.
- Rejected/superseded status requires a separately persisted authorized audit
  receipt; transient failures never become durable outcome claims.

## Gate G3

G3 is accepted at merged candidate `b99826b447260cef998b62b3053586aa857eea4f`.
Phase 5 was authorized from that baseline.
