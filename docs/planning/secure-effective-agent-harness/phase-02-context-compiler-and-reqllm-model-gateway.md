---
id: plan.jido_code_secure_effective_agent_harness_phase_02
parent_plan: plan.jido_code_secure_effective_agent_harness
status: planned
intent: feature
---

# Harness Phase 2 - Context Compiler And ReqLLM Model Gateway

This phase builds the revision-pinned context compiler and the pinned
ReqLLM model gateway, starting with one buffered API-key profile under the
hardened adapter contract, then streaming, then host-controlled
subscription profiles.

Back to plan: [README](./README.md)

- [ ] 2 Phase - Give the harness attributable context and one controlled model seam.

  This phase makes every model input digest-attributable and every model
  call a brokered, pinned, recorded interaction before tools or sandboxes
  exist.

  - [x] 2.1 Section - Implement the revision-pinned context compiler.

    This section assembles host context exclusively through reviewed
    queries so the manifest is reproducible and authorized.

    - [x] 2.1.1 Task {#sah-p02-context-compiler} [repo: jido_code] [after: {#sah-p01-phase-receipt}] - Compile bounded context manifests from reviewed queries.

      This task produces the exact context package every model invocation
      receives, with ordering, digests, and recorded omissions.

      - [x] 2.1.1.1 Subtask {#sah-p02-2-1-1-1} - Implement the recommended context order (system contract and role, lease-derived authority summary, task and acceptance criteria, policy and repository metadata, selected graph resources and source excerpts, stable tool definitions, recent structured observations, current objective and checklist) as a deterministic compiler.
      - [x] 2.1.1.2 Subtask {#sah-p02-2-1-1-2} - Resolve every item through reviewed catalog queries pinned to repository, snapshot, analysis profile, and graph revisions, and never substitute a branch tip or nearby index for the requested commit.
      - [x] 2.1.1.3 Subtask {#sah-p02-2-1-1-3} - Implement just-in-time retrieval tools for large data and lossy compaction that creates an explicitly linked summary without replacing source observations.
      - [x] 2.1.1.4 Subtask {#sah-p02-2-1-1-4} - Record content digests, classification labels, and per-item provenance into the manifest within the accepted bounds.

  - [x] 2.2 Section - Pin ReqLLM and implement the model-interaction port.

    This section isolates provider normalization behind one port so JidoCode
    owns every cross-call decision.

    - [x] 2.2.1 Task {#sah-p02-reqllm-pin} [repo: jido_code] [after: {#sah-p02-context-compiler}] - Pin and prove the ReqLLM dependency.

      This task turns a moving provider dependency into a reviewed,
      reproducible pin.

      - [x] 2.2.1.1 Subtask {#sah-p02-2-2-1-1} - Select a released ReqLLM version or exact reviewed commit, record its digest, and prove compatibility under JidoCode's pinned Req, Elixir, and OTP versions including a Req compatibility spike if the lock requires it.
      - [x] 2.2.1.2 Subtask {#sah-p02-2-2-1-2} - Complete dependency, security, license, and fixture review and record results in the phase receipt.

    - [x] 2.2.2 Task {#sah-p02-model-port} [repo: jido_code] [after: {#sah-p02-reqllm-pin}] - Implement the model-interaction port and ReqLLM adapter.

      This task keeps runtime agents, web modules, and Jido processes away
      from provider calls and from ReqLLM's execution helpers.

      - [x] 2.2.2.1 Subtask {#sah-p02-2-2-2-1} - Define the `model_interaction` port covering one buffered call or stream, normalized response, usage, tool calls, errors, and call metadata.
      - [x] 2.2.2.2 Subtask {#sah-p02-2-2-2-2} - Implement the ReqLLM integrations adapter depending only on stable public functions, never on tool-execution helpers or provider-internal modules.
      - [x] 2.2.2.3 Subtask {#sah-p02-2-2-2-3} - Route every call through the Factory model gateway so runtime agents never reach ReqLLM directly.

  - [x] 2.3 Section - Implement the hardened buffered API-key profile.

    This section launches the most controlled access path first with every
    adapter hardening from the research enforced.

    - [x] 2.3.1 Task {#sah-p02-buffered-profile} [repo: jido_code] [after: {#sah-p02-model-port}] - Enforce the strict buffered-profile contract.

      This task proves the gateway refuses every ambient, caching, retry,
      repair, and native-effect path before dispatch.

      - [x] 2.3.1.1 Subtask {#sah-p02-2-3-1-1} - Enforce the exact allowlisted model and server-owned endpoint, per-call credentials from the credential broker with an adapter precondition failing before ReqLLM is called when the broker result is missing, and no application-global keys, dotenv discovery, or ambient credential paths reached.
      - [x] 2.3.1.2 Subtask {#sah-p02-2-3-1-2} - Disable the ReqLLM application response cache and serialized contexts, set `max_retries: 0` so Factory reauthorizes every retry, set finite receive, total, stream-idle, and metadata timeouts, and force the provider `store` request field false where applicable.
      - [x] 2.3.1.3 Subtask {#sah-p02-2-3-1-3} - Disable JSON and output repair in both structured generation and `ReqLLM.ToolCall.resolve/3`, reject any repair or legacy-coercion diagnostic, independently validate retained raw tool arguments before transformed values are trusted, and run a second JidoCode schema and semantic authorization pass.
      - [x] 2.3.1.4 Subtask {#sah-p02-2-3-1-4} - Prove with fixture and wire conformance tests that the final encoded request contains no provider-executed tools, no auto-injected native tool from model metadata, and no arbitrary base URL, HTTP hooks, custom providers, or provider options; disable deep-research or auto-tool model categories.
      - [x] 2.3.1.5 Subtask {#sah-p02-2-3-1-5} - Restrict effect-bearing structured output to models with proven strict JSON behavior and keep provider contractual retention and caching posture as explicit residual profile data.
      - [x] 2.3.1.6 Subtask {#sah-p02-2-3-1-6} - Disable telemetry payload capture, bound error normalization, and record bounded invocation provenance, observed usage and cost with enforcement class, and outcomes through the Phase 1 command protocol.

  - [x] 2.4 Section - Implement the streaming contract.

    This section enables streaming only after buffered conformance, with one
    supervised consumer and exactly one terminal outcome.

    - [x] 2.4.1 Task {#sah-p02-streaming} [repo: jido_code] [after: {#sah-p02-buffered-profile}] - Implement supervised stream consumption.

      This task keeps partial deltas from becoming tool executions and
      cancellation from leaking responses.

      - [x] 2.4.1.1 Subtask {#sah-p02-2-4-1-1} - Choose one `ReqLLM.StreamResponse` view, retain the response handle, wait for complete assembled tool calls and one terminal event, and never execute a tool from a partial delta.
      - [x] 2.4.1.2 Subtask {#sah-p02-2-4-1-2} - Own enumeration in one supervised stream-consumer task that closes the retained response in an `after` block on success, error, early stop, and cancellation, and never materializes a second view.
      - [x] 2.4.1.3 Subtask {#sah-p02-2-4-1-3} - On committed cancellation or lease loss, have a separate coordinator close the stream, wait a finite interval, and forcibly terminate the consumer, with revision and sequence guards allowing exactly one completed, cancelled, timed-out, or failed outcome to win.

  - [x] 2.5 Section - Implement host-controlled subscription profiles.

    This section extends OAuth and subscription access without ambient
    discovery and with explicit enrollment.

    - [x] 2.5.1 Task {#sah-p02-subscription-profiles} [repo: jido_code] [after: {#sah-p02-streaming}] - Add reviewed OAuth/subscription access paths.

      This task gives subscription developers host-controlled mediation
      where providers support it, under pinned integration contracts.

      - [x] 2.5.1.1 Subtask {#sah-p02-2-5-1-1} - Enroll explicit short-lived access tokens, developer-local credential adapters wrapping `gh auth token`, and explicitly enrolled OAuth files that live outside the repository, store, and sandbox, are non-symlinked, permission-checked, and owner-verified, with default current-directory discovery disabled.
      - [x] 2.5.1.2 Subtask {#sah-p02-2-5-1-2} - Limit direct file-backed OAuth refresh to explicit developer-local profiles; block managed or multi-user deployments until a dedicated broker owns refresh and supplies access tokens, and prevent one profile from letting ReqLLM and a provider CLI refresh the same credential file concurrently.
      - [x] 2.5.1.3 Subtask {#sah-p02-2-5-1-3} - Pin each subscription path (OpenAI Codex OAuth, Anthropic subscription compatibility, GitHub Copilot tokens) as a version-sensitive integration contract with consent-gated live tests and provider-terms review before release.
      - [x] 2.5.1.4 Subtask {#sah-p02-2-5-1-4} - Keep provider conversation and response IDs as external references only; recovery always starts another explicit interaction from graph state.

  - [ ] 2.6 Section - Phase 2 Integration Tests.

    This final section proves gateway behavior against fixtures, wire
    conformance, and failure injection.

    - [x] 2.6.1 Task {#sah-p02-integration} [repo: jido_code] [after: {#sah-p02-subscription-profiles}] - Execute the gateway conformance and failure matrices.

      This task certifies the model seam before any tool or sandbox is
      authorized.

      - [x] 2.6.1.1 Subtask {#sah-p02-2-6-1-1} - Prove context manifests match reviewed-query outputs at pinned revisions, record every omission, and reject any silently substituted revision.
      - [x] 2.6.1.2 Subtask {#sah-p02-2-6-1-2} - Prove missing broker credentials fail before dispatch, fail-first transports never retry, sentinel cache backends are unused, telemetry canaries are absent, repair callbacks are never invoked, and repair or coercion diagnostics are rejected.
      - [x] 2.6.1.3 Subtask {#sah-p02-2-6-1-3} - Prove wire fixtures show `store: false` where applicable and no auto-injected provider tool; prove streaming assembly, cancellation propagation, cleanup on every early-exit path, and exactly one terminal outcome.
      - [x] 2.6.1.4 Subtask {#sah-p02-2-6-1-4} - Prove revocation before release yields no-dispatch, revocation after release blocks later dispatch, and no profile silently falls back across provider, model, or billing mode.
      - [x] 2.6.1.5 Subtask {#sah-p02-2-6-1-5} - Rerun Phase 1 suites, architecture scans, and `mix precommit`.

    - [ ] 2.6.2 Task {#sah-p02-phase-receipt} [repo: jido_code] [after: {#sah-p02-integration}] - Publish the Phase 2 model-gateway receipt.

      This task records the gateway evidence in
      `docs/architecture/harness-phase-02-receipt.md` and authorizes Phase 3
      only from the pinned merged baseline.

      - [x] 2.6.2.1 Subtask {#sah-p02-2-6-2-1} - Record the ReqLLM pin and digest, enabled profiles with their credential classes, adapter hardening proofs, and the candidate commit.
      - [x] 2.6.2.2 Subtask {#sah-p02-2-6-2-2} - Attach conformance, wire, streaming, revocation, and no-fallback results with known limitations.
      - [x] 2.6.2.3 Subtask {#sah-p02-2-6-2-3} - Keep HG2 blocked while any dispatch can bypass the broker, any cache or retry path survives, or any fallback is silent.
      - [ ] 2.6.2.4 Subtask {#sah-p02-2-6-2-4} - Pin the merged candidate commit before authorizing Phase 3.
