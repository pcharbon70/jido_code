# Hypermedia UI Runtime And Authority Inventory

## Status And Evidence Boundary

This is the accountable HUI-A1 inventory of the product runtime at starting
commit `7c91977921c7b170d6def6bd390af93ddd4af09e`. It records current truth and
replacement ownership; it does not accept the target UI or implement a new
runtime.

The complete machine-checkable inventory is
[`priv/architecture/hypermedia_ui/phase_a1_runtime_inventory.json`](../../priv/architecture/hypermedia_ui/phase_a1_runtime_inventory.json).
That file owns exact route records, source/test/operations links, state-holder
classification, readiness posture, semantic registry counts, and all 24
research gaps.

## Current Route And Transport Surface

| Route | Current owner | State and readiness | Replacement disposition |
|---|---|---|---|
| `GET/POST /sign-in`, `DELETE /sign-out` | `AuthController` and `ProductAuth` | Live; external token and signed session | Preserve secure entry/exit semantics; supersede shared identity only after named-human parity |
| `GET /` | `HomeLive` | Live graph-backed workbench; LiveView projection/form/stream state is disposable | Controller/HEEx replacement after complete behavior and rollback parity |
| `GET /coding-agents` | `CodingAgentLive` | UI live; graph catalog/submission callbacks fail closed when absent | Replace after catalog, submission, readiness, and receipt parity |
| `GET /managed-coding/:attempt_ref` | `ManagedCodingAttemptLive` | UI live; attempt loader/control adapter fail closed when absent | Replace after attempt, conversation, evidence, and control parity |
| Five `/api/v1` agent/attempt routes | API controllers and Product gateways | Authenticated and bounded; some production graph callbacks are absent | Retain as the non-browser parity surface |
| `/dev/dashboard` family | Phoenix LiveDashboard | Authenticated, development-only LiveView | Explicitly qualify as retained or remove/replace in HUI8 |
| `/live/websocket` and `/live/longpoll` | Endpoint plus `Phoenix.LiveView.Socket` | Disposable transport/process state | Remove only after hypermedia parity and rollback observation |

All browser routes use CSRF protection and secure browser headers. Product
LiveViews also rebuild Product authority on mount and recheck session validity
before each event. The target controller and SSE paths do not yet exist.

## Runtime, Process, And Asset Ownership

`JidoCode.Application` starts telemetry, the disposable TwMerge cache,
DNSCluster, `Knowledge.Supervisor`, the model-stream task supervisor,
`Runtime.Supervisor`, PubSub, and the Phoenix endpoint.

The Knowledge tree owns readiness, the one `StoreServer`, `QueryRunner`,
serialized `Writer`, and maintenance. The Runtime tree owns the disposable
Jido instance, harness and attempt registries, attempt and wiki dynamic
supervisors, plus repository-wiki coordination/recovery processes.

The following important components are not default-supervised: the general
reconciler and scheduler, `ManagedCoding.Service`, production sandbox,
credential and egress brokers, continuous provider/source observation, and
production verifier/publication/post-change adapters. Product surfaces must
report those facts as unavailable, disabled, evaluation-only, or contract-only
rather than inferring readiness from module existence.

Current assets are rooted in `assets/js/app.js`, `assets/js/server.js`, and
`assets/css/app.css`. The browser bundle consumes Phoenix HTML, Socket,
LiveView, LiveVue, SaladUI hooks/components, colocated hooks, topbar, and the
theme preference. Vite builds the client and LiveVue SSR manifests before
Phoenix digesting. No Datastar client, Dstar delivery dependency, qualified
`pcharbon70/shadcn_ui` dependency, or controller-owned product page set exists.

## Identity And State Ownership

The operator credential remains external configuration. A browser session
contains only authentication time, revocation generation, and a random nonce.
`ProductAuth` reconstructs fixed factory, scope, principal, actor, policy
boundary, and policy identities from configuration and asks Product for the
current graph authority. API bearer authentication reconstructs the same fixed
identity. There is no named-human membership, delegation, MFA/step-up, or
per-human revocation model at this baseline.

| Holder | Classification |
|---|---|
| TripleStore quad dataset | Sole application-owned durable authority |
| Git/provider systems | External source and observation authority |
| Secret provider/environment | External secret-byte authority |
| Signed browser session | Framework security material, not product truth |
| LiveView assigns/streams and LiveVue/DOM state | Disposable projections and interaction state |
| PubSub, caches, registries, scheduler memory | Hints and disposable coordination |
| Worktrees, sandboxes, runtime workers | Disposable effects with exact identity/digest bindings |
| Telemetry/logs | Diagnostics unless explicitly adopted as bounded graph evidence |
| `localStorage["phx:theme"]` | Device-local presentation preference only |

## Graph, Projection, Command, And Readiness Surface

The closed graph registry is revision `2.5.0` with 17 families. The latest
semantic command and reviewed-query protocols are both `2.11.0`, containing
117 commands and 158 queries respectively. Browser code may use bounded
Product/Factory projections and governed gateways only; it may not issue raw
SPARQL, hold a store handle, or treat a projection state as authority.

The accepted product projection vocabulary includes ready, empty,
unavailable, degraded, stale, forbidden, and truncated states. Absence of a
default adapter is unavailable, not empty or healthy.

Readiness at the starting candidate is mixed:

- the knowledge substrate, semantic protocols, operator authentication,
  workbench, and repository enrollment are live;
- provider observation, source analysis, reconciliation, scheduling, native
  managed coding, memory, and wiki compilation have implemented components but
  incomplete default production composition;
- delegated Codex is disabled pending DCG6;
- production isolation, credentials, egress, publication, and parts of
  verification are contract-only or reference-adapter seams; and
- incident controls and the target Datastar/Dstar runtime are proposed or
  absent.

## Research Gap Accountability

Every gap in Research 12 remains open until its named gate produces merged,
pinned evidence. The machine inventory records an ID, priority, owner,
blocking gate, closure evidence, and rollback consequence for each.

| Priority | IDs | Accountable closure |
|---|---|---|
| P0 | HUI-GAP-01 through HUI-GAP-13 | Authority/runtime supersession; named-human auth; identity parity; honest readiness; dependencies; attention, streams, commands, conversation, approval, and incident semantics |
| P1 | HUI-GAP-14 through HUI-GAP-22 | Complete projections; unambiguous identities; operational composites; opaque references; cost/resume/visualization; target-stack tests; LiveDashboard disposition |
| P2 | HUI-GAP-23 through HUI-GAP-24 | Current composed accessibility evidence and final documentation/terminology migration |

Parallel-session failures are owned explicitly by HUI-GAP-08, 11, 15, and
19. Concurrent-human identity, authorization, separation-of-duty, approval,
and revocation failures are owned by HUI-GAP-02, 03, and 12. A later milestone
may close those gaps only with the exact evidence named in the inventory.

## Baseline Delta Rule

The inventory currently has no delta from the Section 1.1 starting candidate.
If source changes before HUI1 closes, the inventory appends a delta containing
the changed fact, source commit, owner, disposition, and rollback effect. It
must not silently rewrite the immutable starting hashes.

