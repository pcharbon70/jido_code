# Delegated Coding Agent Governance Baseline

Status: accepted Phase 1 governing input

## Candidate Provenance

The delegated-agent decisions, specifications, and implementation plan were
accepted by pull request #76 and merged on 2026-08-26 as
`e5f029718543e3ca77feec36a7316f8a2c19441f`. Phase 1 starts only from that
merged candidate.

| Governing input at the merged candidate | SHA-256 |
| --- | --- |
| ADR 0003 | `b1e6fe3ff300bb9d885a5a7d2e3979ec2e63d44dc2b43c62cd316bfb423eef03` |
| ADR 0004 | `ce289c79143f96b1bd835939b5949ce8f111ab06731f052926d5fc12b147f237` |
| Delegated profile and catalog specification | `941fab6fb96aa8708231ff8eeb40ffaab86db8aa9d8739cc22ebcf52f3460cae` |
| Delegated runtime protocol specification | `6a47d4fc071cc429f678fda579b2f6bdacba15665a6165a2dbae11284843d6f7` |
| Delegated product and qualification specification | `e7f1973bfe050f10be45a6b1be1d389ee22e103d03f73d87a2931d34f32f59dc` |

These digests pin the approved inputs; later section commits record their own
source digests without rewriting this provenance.

## DGA1 Decision

The first delegated coding-agent milestone is fixed as:

| Dimension | Accepted value |
| --- | --- |
| Runtime class | `delegated_cli` |
| Provider and CLI | OpenAI Codex CLI `0.144.6` |
| Model | `gpt-5.3-codex` |
| Process substrate | JidoHarness revision `e41fc1651282469f2db4219a48d9f7feef1b0dbc` |
| Adapter ownership | JidoCode protected runner over the JidoHarness Process API |
| Deployment class | `developer_local` |
| Repository envelope | `jido_code` only |
| Capability | `workspace_write_registered_checks` |
| Session protocol | two controller-reconstructed ephemeral turns |
| Rollout | `evaluation`, labeled developer preview |
| Publication and merge | unavailable |

Codex through JidoHarness is the selected route. Only the reviewed built-in
Codex launch policy remains blocked because it transports prompts in argv and
admits request-controlled launch options. Phase 2 replaces that launch policy;
it does not replace JidoHarness or implement a second subprocess authority.

## Binding Authority And Scope

- `TripleStore` is the only application-owned durable authority.
- A graph-owned immutable profile selects exactly one runtime class, provider,
  access mode, billing mode, deployment, capability, adapter release, sandbox,
  verifier, repository envelope, and rollout.
- `AgentOffering` is a disposable filtered projection and never authority.
- JidoHarness processes, Codex sessions, journals, cursors, workspaces, and
  streams are disposable observations.
- The delegated runtime can create candidate workspace effects only. It cannot
  authorize graph writes, credentials, checks, verification, decisions,
  publication, memory adoption, protected refs, or merge.
- DGA1 is foreground-only, developer-local, and `jido_code`-only. DGA2,
  managed fleet, other providers, other repositories, background scheduling,
  publication, and merge are outside this plan.

## Terminology

- `host_controlled` is the native JidoCode-owned coding loop using
  `Jido.Agent` and ReqLLM.
- `delegated_cli` is an accepted external coding loop governed at its outer
  boundary through JidoHarness.
- `developer_local` is the canonical semantic deployment class.
  `developer_local_cli` remains a read-compatible adapter-boundary value only
  and cannot appear in new semantic writes.
- Developer preview is the product label for
  `rolloutStage=evaluation` plus `deploymentClass=developer_local`; it is not a
  new graph rollout value.

## Gate Reopening Conditions

DCG1 reopens regardless of checklist state if a task, repository, environment,
display identifier, model, process, or provider response can select a runtime,
adapter, executable, credential, billing mode, capability, or rollout; an
offering is persisted as authority; selection falls back across an exact
tuple; an actor can observe or select another scope; legacy vocabulary grants
new eligibility; disposable state competes with the graph; developer-local
evidence authorizes managed fleet; or a delegated runtime gains verification,
publication, knowledge-adoption, protected-ref, or merge authority.
