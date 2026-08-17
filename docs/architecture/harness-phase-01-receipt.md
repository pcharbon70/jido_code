# Harness Phase 1 Contract And Threat Model Receipt

## Status

This receipt records the Harness Phase 1 candidate verified locally on
2026-08-16 and accepted after pull request merge on 2026-08-17. Harness
graph resources, the model-access-profile contracts, the invocation command
protocol, context-manifest bounds, and the trust model with conformance
fixtures are implemented through the graph-only authority boundary.

HG1 is accepted at merged candidate
`1fd544b901168b3a1130097bf5723644cb1aac83` after the pull request passed
clean-checkout CI on 2026-08-17. No
local evidence found an unmapped harness resource, an invocation that can
bypass its semantic command, a manifest exceeding an accepted bound, or an
untrusted fixture gaining authority.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Phase baseline and merged G9 | `1133ad0` - research plan and numbered docs |
| Section 1.1 | `53e084e` - define harness graph resources and access-profile contracts |
| Section 1.2 | `1e1d10d` - extend command protocol for harness model invocations |
| Section 1.3 | `5933299` - define context manifest bounds and reconstruction contracts |
| Section 1.4 | `e97bec6` - add harness trust model and conformance fixtures |
| Section 1.5 | This receipt and its integration tests; exact commit recorded by Git history |
| Dependency security fix | `73cbb95` - bump phoenix_live_view 1.1.33 for CVE-2026-64941 plus regenerated npm lock |
| CI recovery | `ac277bc` - provide CI-only operator token for asset build (main CI had been red since the phase-10 runtime-config change) |
| Merged candidate | `1fd544b901168b3a1130097bf5723644cb1aac83` |

## Contract Pins

| Component | Accepted pin |
| --- | --- |
| Command protocol version | `1.8.0` (`@harness_contract_version`) |
| Ontology release | `1.0.0` (immutable; harness terms admitted via the Elixir admission layer per the established additive pattern) |
| Shape catalog | `1.0.0` |
| New capability | `:harness` (granted by operator bootstrap alongside all capabilities) |
| New graph families | None. `ModelAccessProfile`, `HarnessProfile`, `ToolDefinitionRevision` → `factory_policy`; `ContextManifest`, `ModelInvocation`, `ActionProposal`, `SandboxInstance` → `run_attempt`; `ApprovalRequest` → `repository_control`; `CredentialReference` additionally admitted in `factory_policy` |

## Accepted Contract

New semantic commands (registry `1.8.0`, capability `:harness` unless noted):

- `EnrollModelAccessProfile` - appends a profile with access mode
  (`host_api`/`host_subscription`/`delegated_cli`), external
  `CredentialReference`, credential class
  (`static_reusable`/`short_lived_bearer`/`workload_exchange`/`attaching_proxy`),
  billing mode (`metered_api`/`subscription`/`unknown`), provider surface,
  readiness evidence, and revocation generation `>= 1`; guarded by
  `subject_absent`.
- `RevokeModelAccessProfile` - appends the next monotonic revocation
  generation plus `revokedAt`; guarded by `subject_present` and an exact
  `triple_present` on the expected current generation.
- `AdoptHarnessProfile` - pins workflow, prompt-template, tool-catalog,
  policy, and budget versions to an enrolled access profile; guarded by the
  profile's `subject_present`.
- `PublishToolDefinition` - pins tool name (closed format), semver, input
  and output schema digests (`sha256:` hex), effect class
  (`read`/`write`/`external`/`publish`), adapter digest, approval
  requirement, and bounded timeout.
- `CreateApprovalRequest` - creates a digest-bound approval request
  (`actionDigest` hex-64, approver, expiry, evidence references) in the
  repository control graph; consumption and single-use enforcement remain
  with the Phase 6 decision boundary.
- `RecordModelInvocationStart` (capability `:execution`) - commits the
  started invocation before provider dispatch; references the existing
  first manifest via `subject_present` or creates the next immutable
  manifest in the same atomic append via `subject_absent`; guarded by the
  attempt transition endpoint and the current lease fence.
- `RecordModelInvocationOutcome` (capability `:execution`) - closes the
  invocation under the same sequence identity with terminal classes
  `completed`/`failed`/`timed_out`/`cancelled`/`ambiguous`; ambiguous is an
  explicit class, never overwritten history.

Protocol extensions:

- `RecordExecutionAttempt` now creates the first immutable `ContextManifest`
  (index 0, digest equal to the attempt context digest, reconstruction
  `exact`) atomically with the run graph, prepared and starting transitions,
  task and lease transitions, and graph metadata.
- `RecordToolInvocation` accepts an optional `ActionProposal` whose
  statements ride atomically with the started invocation; proposals carry
  bounded classified digests only, never raw secret-bearing arguments.
- `FinalizeExecutionRun` requires `model_invocation_iris` and
  `model_invocation_outcome_iris` reference sets (each `subject_present` in
  the run graph) and always guards the first context manifest's presence.

Context-manifest bounds (closed-world admission):

- at most 20 source graphs with revision references, 200 items, 262,144
  serialized bytes, 65,536 estimated tokens, 16,384-byte instructions, and
  32,768 bytes per item; graph and item lists must be supplied together;
  truncation and omissions are recorded as bounded classified literals.
- delegated-input manifests must declare provider-internal fields
  (`prompts`, `context_assembly`, `memory`, `internal_model_turns`,
  `tool_manifests`) explicitly unavailable.
- `partial`/`unavailable` reconstruction requires missing-class reporting
  (`raw_prompt`, `raw_response`, `raw_tool_output`, `provider_session`,
  `retention_gap`); a digest alone never implies replayability.

Trust model (`JidoCode.Knowledge.Trust`):

- eight source classes with fixed integrity levels; six authority sinks
  (`capability_grant`, `policy_mutation`, `accepted_memory`,
  `sink_selection`, `declassification`, `ontology_mutation`) reachable only
  by authorized decisions and accepted policy; verifier results enter
  memory only through governed adoption; every other flow fails closed.
- runtime diagnostics map only onto the accepted attempt lifecycle;
  invented terminal states such as `:crashed` are rejected at the command
  boundary.

## Executable Evidence

The phase adds 39 tests across five files:

- `phase_h01_harness_resources_test.exs` (10) - resource round-trips,
  idempotent replay, duplicate/stale revocation conflicts, orphan-profile
  adoption rejection, malformed identities, wrong-family class rejection.
- `phase_h01_invocation_protocol_test.exs` (11) - manifest atomicity with
  the attempt, sequence-guarded starts/outcomes, unstarted-outcome
  rejection, orphan-manifest rejection, next-manifest atomic creation,
  malformed outcome rejection, proposal atomicity and mismatch rejection,
  finalize completeness acceptance and ghost-invocation conflict.
- `phase_h01_manifest_bounds_test.exs` (12) - host content contract,
  counterpart-list rule, graph/item/byte/token/instruction ceilings,
  per-item cap, omission recording, delegated unavailable-field contracts,
  reconstruction missing-class reporting.
- `phase_h01_trust_conformance_test.exs` (14) - information-flow matrix,
  diagnostic lifecycle mapping, invented-state transition rejection,
  unauthorized-actor denial, stale-fence builder rejection, stale
  transition-endpoint conflict, idempotent replay, injection containment
  for proposals, diagnostics, and manifest bytes.
- `phase_h01_harness_contract_integration_test.exs` (2) - the complete
  enroll → adopt → publish → attempt-with-manifest → invocations →
  proposal-bearing tool effect → complete-closure flow, terminal-state
  dispatch rejection, and the incomplete-run closure path.

## Verification Record

| Command or gate | Result |
| --- | --- |
| `mix compile --warnings-as-errors` | Pass |
| Phase H01 test files | 39 tests, 0 failures |
| `mix precommit` (architecture checks + full suite) | Pass; 362 tests, 0 failures |

## Operational Limits

- Approval-request consumption, single-use enforcement, and pre-effect
  revalidation are Phase 6 contract surface; Phase 1 only creates the
  digest-bound request.
- The context compiler, ReqLLM gateway, credential broker, and tool
  reference monitor are Phase 2-3 deliverables; Phase 1 provides their
  admission contracts only.
- Initial model-access profiles are single-operator and shadow-only; the
  independent decision-actor prerequisite for later rollout stages is
  recorded in the plan README.

## Gate HG1

HG1 is accepted at merged candidate
`1fd544b901168b3a1130097bf5723644cb1aac83`,
pinned in this receipt and the Harness Phase 1 plan. Harness Phase 2 is
authorized from that baseline. Any evidence that a mapped harness resource
lacks a shape, an invocation
can bypass its semantic command, a manifest can exceed an accepted bound,
or an untrusted fixture gains authority reopens the gate.
