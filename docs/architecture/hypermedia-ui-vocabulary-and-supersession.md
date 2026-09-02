# Hypermedia UI Vocabulary And Supersession Matrix

## Status And Rule

This document is the HUI-A1 vocabulary and no-silent-supersession record. It
defines names used by the proposed program without accepting the proposed
runtime. Accepted graph, product, security, wiki, and release contracts remain
in force until a later Milestone A receipt explicitly changes their authority.

The machine-readable source is
[`priv/architecture/hypermedia_ui/phase_a1_vocabulary_and_supersession.json`](../../priv/architecture/hypermedia_ui/phase_a1_vocabulary_and_supersession.json).
Architecture validation treats duplicate terms, ambiguous aliases, missing
source clauses, incomplete dispositions, or orphaned target owners as HUI-A1
failures.

## Durable And Ephemeral Identity Vocabulary

| Term | Meaning and authority boundary |
|---|---|
| Factory | Durable managed-repository factory resource and policy boundary in the graph |
| Tenant | Durable authorization/isolation boundary; the current deployment exposes one configured default scope |
| Conceptual repository | Canonical managed repository identity, independent of provider locator, checkout, branch, or worktree |
| Project | Presentation alias for exactly one conceptual repository until a later ADR defines a different durable resource |
| Task | Graph-owned proposed or adopted work with dependencies, eligibility, and policy |
| Attempt | One immutable execution try under an exact lease/fence; retry means a new attempt |
| `InteractionSession` | Bounded purpose/audience interaction resource linked to an attempt; not a browser session or provider thread |
| Candidate | Content-addressed proposed change awaiting independent evidence and disposition |
| Edition | Immutable complete repository-wiki compilation; activation is separate |
| Preview | Noncurrent audience-scoped projection or wiki candidate bound to exact source/session/attempt/fence |
| Browser session | Ephemeral signed authentication context; never product truth |
| Tab | Ephemeral browser/DOM context with no authority |
| Provider thread | External provider identity observed as evidence, not an `InteractionSession` |
| Runtime | Exact execution class/profile, separate from semantic agent and process |
| Process | Disposable OS/BEAM instance; never required for graph recovery |
| Agent | Cataloged semantic capability/profile independent of the process that runs it |

Normative target documents must qualify the bare words `session`, `patch`,
`agent`, `complete`, and `current`. In particular, project is only the product
alias for one conceptual repository; session must identify browser,
interaction, or provider scope; and runtime completion is not goal
satisfaction.

## Presentation And Authority Vocabulary

| Term | Meaning and authority boundary |
|---|---|
| Page | Complete authorized server-rendered document for one durable route |
| Fragment | Bounded independently authorized HEEx subtree for a declared region |
| Projection | Reviewed bounded value with revisions, freshness, completeness, truncation, warnings, and provenance |
| Signal | Ephemeral browser input used to request rendering or a command; never authority |
| Stream | Expiring reauthorized delivery channel with bounded queues |
| Hint | Lossy notification to re-query, never an event store |
| Patch | Qualified presentation-fragment patch or candidate source patch; neither is accepted truth alone |
| Command | Versioned semantic intent with actor, scope, preconditions, revisions, idempotency, and authorization |
| Effect | External operation admitted only after durable invocation and current-fence authorization |
| Receipt | Immutable bounded graph record of a command outcome and recovery identity |
| Evidence | Attributable observation or verification about an exact subject; does not accept it |
| Decision | Policy-authorized disposition at exact evidence and graph revisions |
| Freshness | Declared relation between a projection and its authoritative inputs |
| Readiness | Honest evidence-backed capability composition state; module existence is insufficient |
| Satisfaction | Final-goal outcome after application, post-change verification, and authorized decision |

## No-Silent-Supersession Matrix

The complete matrix contains 17 entries. Each entry names a source path and
clause, old and proposed owners, one of preserve/supersede/amend/defer, target
phase, migration evidence, rollback dependency, removal phase, and status.

| Scope | Disposition | Required handling |
|---|---|---|
| ADR 0001 presentation and migration clauses | Amend | Preserve graph authority while Milestone A explicitly changes presentation ownership |
| Module boundaries | Amend | Replace LiveView/LiveVue names without reversing plane dependencies |
| Product surface and island contract | Supersede | Freeze routes/interfaces, prove parity, and keep rollback until HUI8 |
| Product threat model | Amend | Retain CSRF/session protections and add controller/stream/Datastar threats |
| Repository-wiki product contract | Amend | Preserve opt-in, citations, cost, and bounded projection behavior |
| G9, MCG4, and DCG5 receipts | Preserve | Receipts remain immutable historical evidence and rollback baselines |
| Current architecture snapshot | Amend | HUI-A1 inventory becomes the current product-runtime evidence |
| Pre-graph current-state inventory | Preserve | Keep as historical graph-introduction evidence |
| README and operator handbook | Defer | They must describe the actually deployed runtime until HUI8 migration |
| `ProductAuth` fixed operator mapping | Supersede | Named-human authority requires A2 acceptance and later implementation proof |
| Router/live session | Supersede | Controller ownership needs route, deep-link, auth, and rollback parity |
| Browser entry point | Supersede | Datastar delivery must pass CSP/reconnect/asset qualification first |
| Mix/npm dependency graph | Defer | Remove dependencies only after a zero-consumer scan in HUI8 |
| LiveView product tests | Defer | Trace every behavior to target request/browser coverage before removal |

`Preserve` for a receipt means the evidence is never rewritten. It does not
freeze the current implementation forever. A new accepted ADR and receipt may
change future ownership while citing the old candidate as the behavior and
rollback baseline.

## Interface Freeze Consequences

Until Milestone A Phase 3 accepts a target interface freeze:

- current routes, API paths, authentication behavior, graph boundaries, and
  release gating remain authoritative;
- target components or transport cannot claim ownership of a route or command;
- unavailable capability stays unavailable instead of gaining mock readiness;
- no current dependency, asset, test, dashboard, or operations instruction is
  removed merely because a proposed replacement exists; and
- every later supersession must point back to a matrix entry or add a new one
  with the same evidence and rollback fields.

