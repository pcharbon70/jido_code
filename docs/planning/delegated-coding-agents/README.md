---
id: plan.jido_code_delegated_coding_agents
status: approved
intent: feature
source:
  - docs/adr/0003-first-class-delegated-coding-agents.md
  - docs/adr/0004-delegated-agent-credentials-and-isolation.md
  - docs/architecture/delegated-agent-profile-catalog.md
  - docs/architecture/delegated-agent-runtime-protocol.md
  - docs/architecture/delegated-agent-product-and-qualification.md
---

# Delegated Coding Agents Implementation Plan

This six-phase plan closes the immediate developer-facing coding-agent gap by
turning one exact Codex CLI profile into a first-class JidoCode agent. Codex
runs through the protected JidoHarness process API, receives compiled context
through stdin or a protected controller-owned file, writes only inside an
isolated disposable `jido_code` workspace, and produces candidates that
JidoCode captures and verifies independently.

The upstream Codex adapter remains the intended behavioral reference for
Codex JSONL events, lifecycle, file changes, usage, resume, and cancellation.
Its current finite-run launch remains blocked because it places prompts in
process arguments and accepts request-controlled launch options. DGA1 uses a
JidoCode-owned protected runner over JidoHarness rather than rejecting the
Codex/JidoHarness route.

## Goal

Deliver one exact delegated profile that:

1. is selectable as a foreground `developer_local` offering;
2. runs Codex CLI `0.144.6` with `gpt-5.3-codex` through the pinned
   JidoHarness structured process API;
3. has `workspace_write_registered_checks` capability against `jido_code`;
4. uses an existing local login reference with explicit consent and billing
   disclosure;
5. creates controller-recomputed candidates;
6. passes independent fresh-checkout verification;
7. supports bounded clarification, steering, cancellation, containment, and
   cleanup;
8. cannot publish or merge; and
9. passes a signed developer-preview qualification gate.

This is milestone DGA1. Managed-fleet operation, background scheduling,
additional providers, additional repository envelopes, draft publication, and
merge authority belong to DGA2 or later plans.

## Governing Inputs And Baseline

The governing decisions and specifications are:

- [ADR 0003: First-class delegated coding agents](../../adr/0003-first-class-delegated-coding-agents.md)
- [ADR 0004: Delegated-agent credentials and isolation](../../adr/0004-delegated-agent-credentials-and-isolation.md)
- [Delegated coding agent profile and catalog](../../architecture/delegated-agent-profile-catalog.md)
- [Delegated coding agent runtime protocol](../../architecture/delegated-agent-runtime-protocol.md)
- [Delegated coding agent product and qualification](../../architecture/delegated-agent-product-and-qualification.md)
- [Delegated coding agent governance baseline](../../architecture/delegated-agent-governance-baseline.md)

The completed graph-native factory, secure harness, total memory, and managed
coding plans remain binding. This plan adds no second durable store, runtime
authority, verification authority, publication authority, or merge authority.

## Exact Initial Profile

| Dimension | DGA1 value |
| --- | --- |
| Runtime class | `delegated_cli` |
| Provider and CLI | OpenAI Codex CLI `0.144.6` |
| Model | `gpt-5.3-codex` |
| JidoHarness | revision `e41fc1651282469f2db4219a48d9f7feef1b0dbc` |
| Adapter ownership | JidoCode protected runner over JidoHarness Process API |
| Deployment | `developer_local` |
| Repository envelope | `jido_code` only |
| Capability | `workspace_write_registered_checks` |
| Session protocol | two controller-reconstructed ephemeral turns |
| Rollout | `evaluation`, labeled developer preview |
| Publication and merge | unavailable |

## Contract Versions And Public Interfaces

- Ontology `1.4.0` adds `DelegatedAdapterRelease`,
  `DelegatedAgentProfile`, and `DelegatedAgentReadiness`.
- Semantic command and query protocol `2.9.0` adds:
  `RegisterDelegatedAdapterRelease`, `RegisterDelegatedAgentProfile`,
  `TransitionDelegatedAgentProfile`, `RecordDelegatedAgentReadiness`,
  `SelectableAgentOfferingsByScope`, `DelegatedAgentProfileDetail`,
  `DelegatedAgentReadinessByProfile`, and
  `DelegatedAgentProfileHistory`.
- `AgentOffering` is a disposable, scope-filtered projection with an opaque
  selection reference. It is never persisted authority.
- Managed-coding release contract `8.0.0` adds explicit runtime and delegated
  profile identity while preserving the accepted native profile.
- `JidoCode.Factory.Ports.ExecutionRuntime` retains `prepare`, `start`,
  `signal`, `status`, `cancel`, and `terminate`.
- Authenticated browser, JSON API, and `mix jido_code.agent` surfaces use the
  same product gateways, semantic commands, and reviewed queries.

## Gate And Phase Mapping

| Gate | Required result | Phase |
| --- | --- | --- |
| DCG1 - semantic catalog | Delegated releases, profiles, readiness, offerings, and exact selection are graph-authorized and closed | Phase 1 |
| DCG2 - protected Codex runtime | One exact Codex process runs through JidoHarness with protected prompt transport and bounded turns | Phase 2 |
| DCG3 - local containment | Existing local authentication, workspace writes, checks, egress, limits, and cleanup are proven | Phase 3 |
| DCG4 - trustworthy candidate | Outer accounting, candidate capture, independent verification, and graph-only recovery are complete | Phase 4 |
| DCG5 - developer workflow | Browser, API, and CLI expose the same scoped submission and control workflow | Phase 5 |
| DCG6 - DGA1 qualification | The exact `jido_code` Codex profile passes signed developer-preview gates and becomes selectable | Phase 6 |

## Phase Plans

1. [Phase 1 - Semantic Contract, Profiles, And Agent Catalog](./phase-01-semantic-contract-profiles-and-agent-catalog.md)
2. [Phase 2 - Exact Codex Runtime And Protected JidoHarness Launch](./phase-02-exact-codex-runtime-and-protected-jidoharness-launch.md)
3. [Phase 3 - Developer-Local Credentials, Sandbox, And Workspace Effects](./phase-03-developer-local-credentials-sandbox-and-workspace-effects.md)
4. [Phase 4 - Accounting, Candidate Closure, Recovery, And Verification](./phase-04-accounting-candidate-closure-recovery-and-verification.md)
5. [Phase 5 - Developer Product Workflow](./phase-05-developer-product-workflow.md)
6. [Phase 6 - DGA1 Qualification And Developer-Preview Release](./phase-06-dga1-qualification-and-developer-preview-release.md)

Phase evidence is recorded in
`docs/architecture/delegated-agent-phase-01-receipt.md` through
`docs/architecture/delegated-agent-phase-06-receipt.md`.

## Planning Structure And Closure

Every phase follows this hierarchy:

~~~text
Phase
  description
  Section
    description
    Task
      description
      Subtask
~~~

- Phases use `N`; sections use `N.M`; tasks use `N.M.K`; subtasks use
  `N.M.K.L`.
- Every phase, section, and task begins with its own description.
- Stable anchors use `dca-pNN-*` and every task declares
  `[repo: jido_code]`.
- Every phase ends with a section named `Phase N Integration Tests`.
- Implementation uses one intentional commit per section and one
  implementation pull request per phase.
- After the implementation PR passes clean-checkout CI and merges, a
  documentation-only closure PR pins the full merge SHA and date, updates the
  receipt from merge-pending to accepted-at-merged-candidate, and checks the
  phase, integration, receipt, and pinning boxes.
- The next phase starts only from that pinned merged closure baseline.

## Non-Negotiable Invariants

1. `TripleStore` remains the only application-owned durable authority.
2. JidoHarness runs, Codex processes, sessions, cursors, journals, sandboxes,
   workspaces, and streaming fragments are disposable.
3. Graph values resolve only closed registry keys and digests; they never
   select modules, executable paths, arguments, mounts, environment variables,
   tools, or endpoints.
4. Compiled context never appears in argv, environment, process titles,
   diagnostics, or retained launch metadata.
5. Repository content cannot enable user configuration, project rules,
   additional directories, MCP, skills, extensions, web search, arbitrary
   egress, or dangerous sandbox bypasses.
6. The delegated CLI owns its opaque internal coding loop but cannot authorize
   graph, credential, policy, check, candidate, verification, publication,
   knowledge-adoption, or merge effects.
7. Registered checks and candidate facts are recomputed by JidoCode; CLI
   reports remain observations.
8. Cancellation commits before process termination, revokes permits, destroys
   the namespace, and rejects every late result by current fence.
9. Recovery reconstructs from graph state and accepted content-addressed
   checkpoints, never provider-session or process state.
10. DGA1 is foreground, developer-local, `jido_code`-only, evaluation-stage,
    and unable to publish or merge.

## Test And Evidence Rules

- Unit tests accompany every resource, shape, command, query, transition,
  resolver, launch rule, event mapping, limit, control, and release gate.
- Integration sections use the real TripleStore and real local filesystem
  effects at seams owned by the phase.
- Mocks cannot close process-argument, credential isolation, workspace,
  cancellation, candidate, verifier, recovery, or product-surface gates.
- Live Codex execution is consent-gated and excluded from ordinary CI.
- Fixed clocks, deterministic IRIs, pinned snapshots, immutable fixtures, and
  exact component digests make replay meaningful.
- Later phases rerun all earlier DCG gates and applicable factory, harness,
  memory, managed-coding, architecture, Dialyzer, precommit, and clean-checkout
  gates.
- A gate reopens whenever any listed invariant fails, regardless of checklist
  state.

## Completion Definition

The plan is complete only when one exact Codex profile is selectable for
foreground `jido_code` work, creates bounded isolated changes, yields a
controller-captured candidate, passes independent fresh-checkout verification,
supports bounded interaction and cancellation, passes its signed 30-task
developer-preview qualification, and has no publication or merge path.
