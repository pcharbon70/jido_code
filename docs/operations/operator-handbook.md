# Operator Handbook

## Routine Commands

```bash
mix jido_code.release verify
mix jido_code.release preflight
mix jido_code.release audit
mix jido_code.knowledge health
mix jido_code.knowledge integrity
mix jido_code.knowledge backup
mix jido_code.knowledge export --format nquads
mix jido_code.capacity --profile small
```

Restore and initial bootstrap require explicit repeated confirmation; see the
install and disaster-recovery runbooks. Command output is bounded operational
evidence, not a second product database.

## Product Operations

- **Enrollment:** sign in, open Repositories, validate the locator preview,
  confirm, and retain the semantic receipt. Provider credentials are external
  references, never form literals.
- **Refresh:** request a source/provider observation. A stale or incomplete
  projection must remain labeled; do not infer current state from cached UI.
- **Blocked work:** inspect fixed blocker reasons and their source revisions.
  Change policy or evidence through its owning command rather than editing a
  task status.
- **Lease recovery:** compare graph lease/fence and runtime observation. Expire,
  release, or reacquire only through accepted transitions.
- **Attempts:** cancellation creates a cancellation request and fenced runtime
  effect. Local process termination alone does not change semantic state.
- **Evidence and decisions:** review artifact provenance, mandatory checks,
  waivers, and follow-ups before accepting an outcome.
- **Knowledge:** inspect provenance, contradiction, applicability, and
  supersession. New assertions do not replace history.
- **Policy:** apply versioned policy changes, then reconcile affected cohorts;
  graph policy may narrow trusted fleet ceilings but cannot widen them.

## Health And Alerts

Readiness, availability, unresolved commit outcomes, backup age, recovery time,
projection freshness, bounded query p95, fleet queue depth, and UI projection
errors are release objectives. `unavailable`, `maintenance`, stale,
incomplete, unauthorized, and conflict states are distinct and must not be
collapsed into an empty/current UI.

Use the fleet capacity/observability runbook for thresholds. Use the security
threat model for credential, cross-scope, sandbox, provider, or restore
incidents. Rotate `JIDO_CODE_SESSION_GENERATION` after suspected browser-session
compromise.

Repository wiki enrollment, deterministic regeneration, automatic maintenance,
opt-out, reservation reconciliation, graph repair, backup/restore verification,
and V1 synthesis-unavailable incidents use the
[repository wiki deterministic V1 runbook](./repository-wiki-v1-runbook.md).

## Architecture Map

The Knowledge plane owns TripleStore, ontology, graph topology, semantic
commands, bounded queries, revisions, audit, backup/restore, and retention.
Factory owns policy evaluation and disposable control loops. Integrations own
external effects without semantic authority. Runtime owns ephemeral Jido,
sandbox, and tool processes. Web owns authenticated presentation and bounded
LiveVue islands. Every user-visible durable fact must trace to one graph commit
and immutable provenance/transition chain.
