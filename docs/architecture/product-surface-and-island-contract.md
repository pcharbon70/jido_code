# Product Surface And Island Contract

- Status: Superseded for target presentation ownership by HUI-A3; durable
  projection and command invariants remain accepted
- Contract version: `2.0.0`
- Supersession: [Runtime contract supersession](./hypermedia-ui-runtime-contract-supersession.md)

## Decision

The target repository factory uses the closed durable route vocabulary in the
[secure product shell](./secure-product-shell-and-information-architecture.md).
Routes and opaque references are presentation selections, not graph, query,
command, actor, or authority selectors. The deployed `GET /` workbench remains
a compatibility route until its Milestone H cutover gate closes; it is not the
target owner defined by this contract.

| Area | Reviewed projection | Scope | Durable actions |
| --- | --- | --- | --- |
| Factory | fleet posture and substrate revision | factory | semantic command gateway only |
| Repositories | enrollment, observation, source, freshness | factory and selected repository | semantic command gateway only |
| Work | desired state, goals, tasks, blockers, eligibility | selected repository | semantic command gateway only |
| Execution | leases, attempts, interactions, artifacts | selected repository and exact attempt | semantic command gateway only |
| Outcomes | evidence, decisions, follow-up, satisfaction | selected repository and exact goal | semantic command gateway only |
| Knowledge | adopted assertions and evolution | selected repository or accepted cohort | semantic command gateway only |

Development-only diagnostic routes are not part of the product contract.
LiveDashboard must be removed, replaced, or separately approved before a
literal zero-LiveView claim. There is no arbitrary graph browser, query
authoring surface, or product JSON API.

## Ownership

Explicit Phoenix controllers own route parameters and invoke the trusted
identity/authority builder. Application handlers own current repository and
resource selection, reviewed projection refresh, closed form validation,
semantic command submission, receipts, and navigation. One authorized
application coordinator may deliver bounded fragments over Dstar/SSE. A graph
change is only a refresh hint; every response or patch reauthorizes and
re-runs its reviewed query instead of applying PubSub or browser payloads as
truth.

Datastar signals and DOM state own only bounded presentation intent. They may
carry JSON-safe filters, labels, opaque presentation references, cursor, and
disclosure state. They cannot carry or select RDF, SPARQL, graph handles,
credentials, actor/scope authority, query/command identities, trusted
revisions, fences, durable results, complete datasets, or a command writer. A
changed identity, scope, route, or source clears stale browser selection.

## Projection States

Every product projection renders one explicit state: `ready`, `empty`, `stale`,
`incomplete`, `contradicted`, `truncated`, `unauthorized`, `unavailable`,
`maintenance`, or `recovery`. Unknown and unauthorized resources use the same
concealment-oriented presentation. Unavailable projections clear rendered
rows; the browser never falls back to stale DOM, stream, or process state.

## Commands And Handoffs

Workbench links carry only a closed surface ID and, when required, a bounded
URL-safe presentation reference encoding a canonical resource IRI. The server
decodes, validates, authorizes, and verifies cohort membership before reading
the resource. A URL reference grants no graph visibility or command authority.

Product forms submit finite semantic intents. Server code resolves the actor,
scope, graph family, current dataset and graph revisions, command type, command
version, and semantic identities. Repository enrollment demonstrates this
contract with a validation preview, explicit confirmation, idempotency key,
atomic semantic command, and bounded receipt. Browser-supplied command, graph,
revision, actor, or SPARQL fields are ignored.

## Interface System

The root shell, JidoCode-owned HEEx composites, the narrow
`JidoCodeWeb.Components.UI` primitive facade, Vite pipeline, and shared
Tailwind semantic tokens form one target interface system. ShadcnUI remains
unavailable until Milestone B qualification. System, light, and dark modes use
synchronized reviewed root attributes and tokens. Product surfaces favor
dense operational bands, native HTML, stable fragment roots, and bounded
repeated items.
