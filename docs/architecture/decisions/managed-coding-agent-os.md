# ADR: AgentOS In The Managed Coding Runtime

Status: **rejected for the current release**  
Decision date: 2026-08-25  
Owner: JidoCode runtime maintainers

## Context

The evaluated AgentOS source revision is
`548b2a345765ba33e687341c661bbbcbdda73d94`. Candidate lifecycle, persistence,
registry, scheduling, telemetry, and operational services overlap services
already accepted in JidoCode. AgentOS is not a dependency in `mix.exs` or
`mix.lock`; no AgentOS supervisor, repository, schema, migration, configuration,
credential, backup, or restoration path exists.

The knowledge graph is exclusively authoritative for task, attempt, topology,
delegation, budget, candidate, verification, disposition, and recovery state.
An Ecto, file, Redis, checkpoint, or opaque AgentOS persistence path would split
that authority. A one-way graph-backed adapter adds reconciliation, migration,
retention, backup, disable, and incident cost without a measured runtime benefit
in the Phase 7 specialist experiment.

## Decision

Reject AgentOS integration for the current managed coding release. Implement no
adapter and add no dependency. Existing graph commands, Factory scheduling,
fixed Jido InstanceManagers, telemetry, and rollout governance remain the only
supported services. The managed Pod itself is also rejected for production, so
an additional long-lived Pod host has no justified role.

Graph-only reconstruction is the expected result under restart, split-state,
lag, duplicate delivery, conflict, migration, backup/restore, and disable
scenarios. Because AgentOS is absent, its availability cannot change an
accepted outcome and no dual-write conflict is possible.

## Reopening Conditions

Reopen only when all of the following are available:

1. a concrete operational gap with measured benefit over the accepted services;
2. a pinned compatible AgentOS revision with no competing persistence path;
3. an ephemeral-only service or reviewed one-way graph-backed adapter;
4. complete provenance, retention, reconciliation, migration, backup/restore,
   disable, incident, and ownership semantics; and
5. fault evidence proving graph-only reconstruction yields the identical
   accepted outcome when AgentOS is unavailable or removed.

Any proposal that makes AgentOS state authoritative for a listed domain, allows
dual writes, or changes agent acceptance/publication/merge authority is rejected
without further evaluation.
