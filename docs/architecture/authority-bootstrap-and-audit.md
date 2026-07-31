# Authority, Bootstrap, And Audit

## Authority Context

Authentication and route admission remain in the web boundary. That boundary
provides a bounded transient projection containing an authenticated principal,
accountable actor, optional delegated software agent, and delegation IRI. It
contains no session or credential value.

Authorization reads only the factory policy graph from the same bounded
snapshot used for command validation. Exactly one current grant must match the
actor, semantic capability, and scope. Delegated execution additionally
requires exactly one delegation matching actor, agent, capability, command
class, validity interval, scope, and every optional graph boundary. Expired,
invalidated, ambiguous, self-expanded, and cross-scope authority is concealed
as unauthorized.

The capability set separates observation, proposal, control, execution,
evidence, decision, ontology, security, and administrative effects.

## Authority RDF

The command registry owns the operational authority vocabulary at version
`1.0.0`. The following terms have closed write-admission semantics even where
OWL remains open-world guidance:

| Term | Meaning and cardinality | Ownership and query use |
| --- | --- | --- |
| `AuthorizationGrant` | One grantee, capability, scope policy, `validFrom`, and `validTo`; optional invalidation | Factory policy; pre-commit authorization |
| `Delegation` | One delegating actor, delegated agent, capability, command class, scope policy, and validity interval; zero or more graph boundaries | Factory policy; delegated pre-commit authorization |
| `grantee` / `grantsCapability` | IRI links to the accountable actor and one controlled capability | Factory policy; exact capability match |
| `scopeMode` | Controlled `AllScopes` only for explicitly administrative root grants | Factory policy; scope containment |
| `delegatingActor` / `delegatedAgent` | IRI links defining accountability and the executing principal | Factory policy; delegation resolution |
| `commandClass` / `graphBoundary` | Exact command identity and optional allowed target graph IRIs | Factory policy; least-privilege command admission |

No free-form status string or dynamically created atom participates in an
authority decision.

## Bootstrap

Bootstrap is a distinct writer operation, disabled unless trusted local
operator configuration supplies a SHA-256 token digest. It is admitted only
after the ontology exists and before catalog, policy, or audit graphs exist.
One atomic batch creates:

- the repository factory, initial actor, and permanent `bootstrapComplete`
  assertion;
- one initial grant for each controlled capability;
- graph-local metadata for catalog, policy, and the current monthly audit
  partition; and
- bootstrap provenance, audit outcome, revisions, and substrate receipt.

The token is checked only in memory and is excluded from fingerprints, RDF,
operation metadata, receipts, and returned projections. Existing initialized
graphs block bootstrap even after restore.

## Audit Policy

Audit graphs use the bounded `YYYY-MM` registry partition and the
`security_audit` append-only retention contract. Audit payload admission rejects
credential values, tokens, prompts, source bodies, arbitrary SPARQL, stack
traces, oversized literals, and secret-like content. Audit reads require a
separate security or administrative capability. Product projections and PubSub
events never include audit statement bodies.
