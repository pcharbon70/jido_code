# Product Surface And Island Contract

## Decision

The repository factory retains one product route, `GET /`, owned by
`JidoCodeWeb.HomeLive`. Workbench areas are verified query parameters on that
route. They are presentation selections, not graph, query, or command
selectors. The route surface from `mikehostetler/jido_code` remains out of
scope.

| Area | LiveView projection | Scope | Durable actions |
| --- | --- | --- | --- |
| Factory | fleet posture and substrate revision | factory | semantic command gateway only |
| Repositories | enrollment, observation, source, freshness | factory and selected repository | semantic command gateway only |
| Work | desired state, goals, tasks, blockers, eligibility | selected repository | semantic command gateway only |
| Execution | leases, attempts, interactions, artifacts | selected repository and exact attempt | semantic command gateway only |
| Outcomes | evidence, decisions, follow-up, satisfaction | selected repository and exact goal | semantic command gateway only |
| Knowledge | adopted assertions and evolution | selected repository or accepted cohort | semantic command gateway only |

Development-only LiveDashboard routes are operational diagnostics and are not
part of the product contract. There is no arbitrary graph browser, query
authoring surface, or product JSON API.

## Ownership

LiveView owns route parameters, authenticated actor scope, current repository
and resource selection, subscriptions, projection refresh, form validation,
semantic command submission, receipts, flash, and navigation. Collections use
LiveView streams. A relevant graph change is only a refresh hint; the LiveView
re-runs bounded queries and never applies PubSub payloads as truth.

LiveVue owns only local interaction state inside explicitly mounted islands.
An island receives JSON-safe counts, labels, presentation identities, dataset
revision, freshness, completeness, and truncation metadata. It cannot receive
RDF structs, SPARQL, graph handles, credentials, complete datasets, or a
command writer. Its finite semantic events are revalidated by its owning
LiveView. A changed source identity clears stale client selection.

## Projection States

Every product projection renders one explicit state: `ready`, `empty`, `stale`,
`incomplete`, `contradicted`, `truncated`, `unauthorized`, `unavailable`,
`maintenance`, or `recovery`. Unknown and unauthorized resources use the same
concealment-oriented presentation. Unavailable projections clear collection
streams; the browser never falls back to stale process state.

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

The root shell, SaladUI server primitives, shadcn-vue islands, Vite pipeline,
and shared Tailwind semantic tokens remain one interface system. System, light,
and dark modes use the same root data attribute and color tokens. Product
surfaces favor dense, unframed operational bands and bounded repeated items.
