# Hypermedia UI Operation Authorization Matrix

## Status And Scope

This is an accepted HUI-A2 architecture contract under ADR 0009. It defines
the server-owned authority builder and the reviewable operation matrix for
future named-human product surfaces. It creates no route, adapter, grant,
query, command, stream, or export capability.

The machine-readable authority is
[`priv/architecture/hypermedia_ui/phase_a2_authorization_matrix.json`](../../priv/architecture/hypermedia_ui/phase_a2_authorization_matrix.json).
Later implementation must consume an exact current registry binding or remain
unavailable; a role explanation, visible navigation item, opaque reference,
browser signal, cached decision, or prior patch is never a grant.

## Trusted Authority Builder

The one conceptual builder is shared by controller, page, fragment, query,
field, search, detail, stream, patch, API, command, approval, incident, export,
and download entry points:

```text
verified session identity
  + server-resolved requested resource
  + current memberships, grants, delegations, and policy/graph revisions
  + server-observed environment, lifecycle, incident posture, and fence
  -> current_scope + product_identity + exact authority + obligations
     + safe decision reason + policy revision + audit correlation
     + concealment/redaction posture
```

Browser actor, role, tenant, project, graph, capability, delegation, assurance,
revision, fence, classification, environment, and incident fields are ignored
as authority and rejected when a closed input schema does not allow them.

## Role Explanations

| Role label | Navigation/explanation responsibility | Grant behavior |
| --- | --- | --- |
| Observer | authorized project summaries and status | no implicit grant |
| Project developer | admitted workspaces, attempts, source, and wiki | no implicit grant |
| Project maintainer | repository policy, lifecycle, and review | no implicit grant |
| Independent verifier | evidence and verification disposition | no implicit grant |
| Factory operator | bounded runtime, queues, leases, and incidents | no implicit grant |
| Security auditor | classified security-audit views | no implicit grant |
| Factory administrator | identity/policy administration without project-content clearance | no implicit grant |
| Knowledge steward | wiki, memory quality, citations, and retention | no implicit grant |
| Cost observer | bounded cost/capacity aggregates | no implicit grant |

Role labels may organize navigation and explain why a current exact grant is
needed. Combining labels never unions capabilities.

## Operation Classes

The JSON matrix contains independently reviewable rows for pages, fragments,
queries, fields, search, detail, streams, patches, commands, approvals,
incidents, exports, and download retrieval. Current rows pin query or command
protocol `2.11.0`, its exact capability, and graph families. A current registry
entry does not imply that a named-human product adapter exists: rows marked
`current_registry_no_product_adapter` remain unavailable until their later
milestone gate closes.

Rows marked `future_contract_only` name their owner and required capability but
do not invent a query or command. They remain unavailable until a separately
reviewed versioned registry entry and implementation receipt exist.

Every row binds all of the following before it can allow: subject and session,
current account state, tenant/project membership, exact grant, exact optional
delegation, assurance and authentication age, resource containment,
classification, environment, lifecycle, policy revision, current graph
revisions, incident posture, and fence when applicable.

## Closed Outcomes

| Outcome | Safe exterior behavior |
| --- | --- |
| `allowed` | minimum authorized projection only |
| `concealed_not_found` | unknown and unauthorized share the same status/body/timing class |
| `redacted` | only already-authorized resource remains; protected field is omitted |
| `denied` | known non-concealed operation refused without protected policy detail |
| `unavailable` | capability or adapter not composed; no target inference |
| `revoked` | terminal protected delivery and no privileged reconnect |
| `step_up_required` | accessible action-bound challenge without target-existence disclosure |

## Reauthorization

Authorization is recomputed before response start, query execution, field
shaping, stream subscription, each protected patch, command construction and
gateway admission, approval commit, export creation, and every export/download
retrieval. Navigation visibility, an earlier response, a signed link, and an
open connection do not satisfy a later checkpoint.

## Reopening Conditions

This matrix reopens if a role supplies a grant; a browser value widens an
input; a current binding does not match the reviewed registry; a future row is
advertised as available; an operation class lacks an independent row; any
binding dimension or reauthorization point is skipped; concealed outcomes
diverge; redaction happens after rendering; or a route, field, patch, command,
approval, incident action, export, or download exists outside this matrix.
