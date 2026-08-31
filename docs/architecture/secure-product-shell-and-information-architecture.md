# Secure Product Shell And Information Architecture

- Status: Proposed under ADRs 0009 and 0011
- Specification version: `0.1.0`
- Owners: JidoCode product, web, security, and accessibility maintainers
- Milestone: C — Read-Only Hypermedia Shell
- Decisions:
  [ADR 0009](../adr/0009-human-identity-scoped-authorization-and-separation-of-duty.md)
  and [ADR 0011](../adr/0011-attention-oriented-control-plane-and-knowledge-lenses.md)

## Purpose

This specification defines the authenticated server-rendered shell, route
vocabulary, navigation, scope changes, attention/fleet projections, project and
attempt identities, responsive layout, projection states, search, and read-
only release boundary.

## Route Vocabulary

Routes use opaque bounded presentation references:

| Route | Product purpose |
|---|---|
| `/factory` | Scoped attention, health, capacity, and fleet overview |
| `/projects` | Authorized repository-backed project catalog |
| `/projects/:project_ref` | Project overview |
| `/projects/:project_ref/work` | Work/task hierarchy |
| `/projects/:project_ref/attempts` | Authorized attempts for the project |
| `/projects/:project_ref/attempts/:attempt_ref` | Durable attempt workspace |
| `/projects/:project_ref/knowledge/:lens` | Closed reviewed knowledge lens |
| `/projects/:project_ref/wiki/...` | Current wiki, guides, dependencies, history, authorized previews |
| `/reviews/:candidate_ref` | Candidate/evidence/disposition view |
| `/operations/...` | Capacity, provider, cost, recovery, service posture |
| `/governance/...` | Separately authorized identity, policy, profile, security, audit, retention |

Route containment is checked independently. A valid project ref does not grant
an attempt, interaction session, candidate, wiki preview, lens, or governance
resource beneath it.

`Project` is a presentation alias for one conceptual repository in V1. An
independent Project ontology resource is out of scope.

## Global Shell

Every page renders:

- skip link, landmarks, one page heading, and stable main/focus target;
- authenticated human identity and assurance summary;
- current factory/tenant/project scope and safe scope switcher;
- authorized navigation derived from current capabilities;
- scoped attention, active/waiting counts, health, and projection freshness;
- bounded authorized global search/navigation; and
- sign-out, reauthentication, and delegated/impersonated-context exit.

Changing scope clears stale project, attempt, candidate, preview, graph lens,
cursor, and action selection. No local signal carries selection across scope
without server validation.

## Factory Command Center

The read-only command center contains three ordered projections:

1. `Needs attention`, derived from durable facts with severity, age, scope,
   owner, reason, evidence, next authorized navigation/action class, and stable
   link;
2. factory health/capacity/readiness, including truthful disabled,
   unconfigured, contract-only, maintenance, and recovery posture; and
3. a stable server-filtered/paginated fleet table showing project, task,
   logical agent/profile, attempt stage, last meaningful effect, wait,
   lease/fence, budget, evidence, source outcome, and owner.

Rows do not reorder while a user is reading. A bounded "newer data available"
state permits deliberate refresh.

Attention acknowledgement, snooze, assignment, durable saved views, and batch
actions are unavailable until semantic resource/command contracts exist.

## Project And Attempt Read Models

The project overview includes repository/source identity, owner, enrollment,
policy/readiness, active/queued/blocked/verifying work, attempts grouped by
task, source/dependency summary, wiki posture/cost, evidence/incidents, and
budget/capacity.

The attempt route initially presents a read-only canonical header, lifecycle,
last meaningful effect, waits, plan, interactions, candidate/artifact summary,
checks/evidence, costs, authority, and receipts. Existing
`InteractionSession` records are displayed as distinct related resources.

## Projection State Component

Every projection uses the accepted states:

- ready;
- empty;
- stale;
- incomplete;
- contradicted;
- truncated;
- unauthorized;
- unavailable;
- maintenance; and
- recovery.

Unavailable clears projection rows and offers only separately authorized shell
identity/recovery guidance. Unknown and unauthorized share concealed exterior
behavior. Connection state and command state are separate from data state.

## Search And Filtering

Search and filters use closed per-surface schemas, server-side authorization,
count/byte/time/depth limits, opaque refs, and cursor pagination. Durable/
shareable view state belongs in the URL; protected or high-sensitivity search
terms use POST and no-store/log-redaction policy.

There is no arbitrary SPARQL, graph name, query name, command name, source path,
or free-form server module field.

## Responsive And Native Baseline

Desktop may use authorized navigation, main content, and contextual inspector.
Narrow layouts preserve main content first; navigation and inspector use native
drawers without hiding essential status/actions in hover. Ordinary anchors and
forms work without Datastar where feasible. CSS-disabled/no-script states remain
safe and understandable.

## Stable DOM Contract

Every shell, projection, table, row, filter, form, status, and receipt has a
unique deterministic DOM ID suitable for HEEx and browser tests. Background
updates do not replace navigation, focused forms, open overlays, reading
position, or unrelated projection roots.

## Acceptance And Reopening

Milestone C closes only when named identity/scope is enforced, all initial
routes are read-only and authorized, current readiness is honest, projection
states are complete, several tabs/scopes remain isolated, native navigation and
responsive/accessibility tests pass, and no raw graph/internal identity is
exposed. The gate reopens on scope retention, concealed-resource divergence,
unavailable stale rows, unbounded search/table data, or a control effect on a
read-only route.
