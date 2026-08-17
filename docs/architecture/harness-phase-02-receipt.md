# Harness Phase 2 Context And Model Gateway Receipt

## Status

This receipt records the Harness Phase 2 candidate verified locally and
accepted after pull request merge on 2026-08-17. The context compiler, governed
ReqLLM gateway, hardened buffered and subscription profiles, supervised stream
consumer, and complete conformance matrix are accepted at the merged baseline.

HG2 is accepted at merged candidate
`49453d05fe72c45431420c05591f89d4ff09f0a8` after pull request #28 passed
clean-checkout CI and merged on 2026-08-17. Phase 3 is authorized from that
exact baseline.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Phase baseline and merged HG1 | `850b9a7` - pin the Phase 1 merged candidate and close HG1 |
| Section 2.1 | `43b84e0` - compile revision-pinned model context |
| Section 2.2 | `8f035e1` - add governed ReqLLM model gateway |
| Section 2.3 | `09d5c75` - harden buffered model profile |
| Section 2.4 | `7ff236f` - supervise model response streams |
| Section 2.5 | `779ad56` - add host-controlled subscription profiles |
| Section 2.6 | This receipt and its integration certification; exact commit recorded by Git history |
| Merged candidate | `49453d05fe72c45431420c05591f89d4ff09f0a8` |

## ReqLLM Dependency Review

The selected dependency is the released Hex package `req_llm` `1.20.0`,
published on 2026-08-10 and pinned exactly in `mix.exs`. Its annotated Git tag
`v1.20.0` has tag object
`a4c12351f2931c026e96a53ed3b18d66eb86b045` and resolves to source commit
`9e3ad0f07825bbf277690dcbaa920876586f8b72`.

| Evidence | Reviewed result |
| --- | --- |
| Hex package checksum | `0dbeb6784477d4284201aab6ea3bea03f741752adcb5e280378dcb4ffc2374a4` |
| Hex registry outer checksum | `f173ec035d69d9d9804456e118083f9c4aad78b1733d519446e8cf26b5d5f0d2` |
| Declared runtime bounds | Elixir `~> 1.15`; Req `~> 0.5` |
| Candidate toolchain | Elixir/Mix `1.18.4`, Erlang/OTP `27` |
| Existing Req pin | `0.6.3`; retained unchanged after dependency resolution |
| Compile spike | `mix compile --warnings-as-errors` passes on the candidate toolchain |
| Catalog spike | Public `ReqLLM.model/1` resolves `openai:gpt-4.1-mini` from the locked catalog |
| Retirement audit | `mix hex.audit`: no retired packages |
| Published repository advisories | GitHub repository advisory API returned no published advisories on 2026-08-17 |
| License | Apache License 2.0, copyright 2026 Mike Hostetler |

The dependency review covered the locked runtime dependency set introduced by
ReqLLM: `dotenvy`, `jsv`, `llm_db`, `server_sent_events`, `websockex`, `toml`,
`abnf_parsec`, and `texture`, while retaining the existing Req `0.6.3` lock.
Optional cloud-provider dependencies were not selected. The retirement and
published-advisory checks are point-in-time evidence, not a claim that future
vulnerabilities cannot be disclosed.

The Hex archive intentionally excludes upstream tests. The upstream tagged
tree contains provider recordings, response projection tests, tool-call
fixtures, and stream-response fixtures; JidoCode does not copy those recordings
because they are broader than the admitted profile and can drift with provider
wire formats. Instead, the candidate starts with a local, bounded public
`ReqLLM.Response` fixture and a fake public facade for normalization and
no-network compatibility checks. Phase 2.3 adds admitted-profile wire fixtures,
and Phase 2.4 adds single-view streaming fixtures.

## Accepted Model Boundary So Far

- `JidoCode.Factory.Ports.ModelInteraction` covers one buffered generation or
  one stream start, returning only a normalized response, opaque stream handle,
  or stable redacted `AdapterError`.
- `JidoCode.Factory.ModelGateway` is the sole Factory dispatch seam. A caller
  selects exactly one adapter, and the gateway has no provider, model, access
  mode, or billing fallback.
- `JidoCode.Integrations.ReqLLM` uses the stable public `ReqLLM.generate_text/3`,
  `stream_text/3`, `Response.classify/1`, `usage/1`, and `call_metadata/1`
  surfaces. It does not use provider implementation modules, tool execution
  helpers, automatic tool loops, or provider-owned retries across interactions.
- Model requests are bounded and carry the already-recorded invocation,
  profile, context-manifest, provider, model, and deadline identities. Secret
  bytes and provider sessions are absent from this contract.

## Hardened Buffered Profile

The only enabled buffered profile is exact and has no fallback:

| Field | Accepted value |
| --- | --- |
| Access mode | `host_api` |
| Provider/model | `openai` / `gpt-4.1-mini` |
| Server-owned endpoint | `https://api.openai.com/v1` |
| Credential class | `static_reusable`, fetched per call from the explicit `CredentialReference` |
| Billing mode | `metered_api` |
| Provider retention/training | Explicit residual external contractual posture |
| Provider prompt cache | Explicit provider-managed residual posture; no cache key supplied |
| Effect-bearing structured output | Disabled because the locked catalog does not mark this model strict-JSON capable |
| Cost enforcement | Observed post-dispatch, normalized to integer micro-USD `cost_units` where exposed |

The gateway validates the request/profile match and caller option allowlist
before credential release, revalidates graph-owned authority before release and
again immediately before dispatch, and never selects another profile after a
denial. The adapter independently validates the hardened dispatch and exact
catalog model before invoking ReqLLM.

The admitted ReqLLM option set supplies only the broker result as `api_key`,
sets application cache to `nil`, `max_retries: 0`, finite receive/total/stream
idle/metadata timeouts, `json_repair: false`, strict final validation,
metadata-only telemetry, `provider_options: [store: false]`, empty tools, and
`tool_choice: :none`. It omits alternate base URLs, request/Finch hooks,
fixtures, custom providers, arbitrary provider options, previous response IDs,
prompt-cache keys, and output-repair callbacks. `config/config.exs` disables
dotenv loading in both ReqLLM and LLMDB and disables telemetry payload capture.

The pinned OpenAI Responses encoder conformance fixture produces `store: false`
with no `tools`, `previous_response_id`, or `prompt_cache_key`. The selected
catalog model is not a deep-research model, so the reviewed ReqLLM 1.20.0
auto-native-tool path is not reached. Any returned tool call is resolved without
JSON repair, its retained raw JSON is decoded independently and compared with
ReqLLM's projection, then rejected by the JidoCode semantic policy because Phase
2 has no authorized tool effects. Cache-hit markers and repair or legacy
coercion diagnostics are rejected.

Successful responses carry bounded invocation/profile/context provenance,
redacted call metadata, observed usage and cost, and a helper projection that
matches the Phase 1 `RecordModelInvocationOutcome` attribute contract. Failures
produce only stable adapter kind/operation diagnostics.

## Supervised Streaming Contract

The ReqLLM adapter chooses only `ReqLLM.StreamResponse.events/1`; no other
chunk, token, classifier, or materialization view is created. The opaque
response handle remains attached to the Factory stream contract. One task under
`JidoCode.Factory.Model.StreamSupervisor` owns the complete enumeration and
closes the handle in an `after` block for success, provider error, malformed
events, and cooperative cancellation.

The integration projects only bounded Factory events. Text deltas may be sent
to a subscriber while the outcome remains open. Reasoning deltas are discarded,
partial tool start/argument events are never published, and a complete tool call
is considered only after ReqLLM emits its assembled terminal projection. Because
Phase 2 authorizes no tools, any partial, complete, provider-executed, or
provider-native tool/output event fails the stream policy without exposing tool
arguments.

A separate `StreamCoordinator` commits the first completed, cancelled,
timed-out, or failed `StreamResult`. A committed cancellation or lease loss
closes the response from the coordinator, waits a finite grace interval, then
terminates an unresponsive supervised consumer. The request deadline, profile
total timeout, and profile metadata timeout cap materialization. Duplicate,
missing, or post-terminal events fail closed. Later competing results cannot
replace the first committed result; the result projects to the Phase 1 outcome
attributes, whose existing invocation sequence and graph revision guards make
the durable winner unique.

## Host-Controlled Subscription Profiles

The candidate pins three ReqLLM 1.20.0 subscription contracts without a
provider, model, endpoint, access-mode, credential-class, or billing fallback:

| Contract | Exact provider/model | Credential sources | Release boundary |
| --- | --- | --- | --- |
| `req_llm-1.20.0/openai-codex-oauth/1` | `openai_codex:gpt-5.3-codex` | Explicit access token or enrolled OAuth file | Token expires within one hour; OAuth file is developer-local only |
| `req_llm-1.20.0/anthropic-subscription/1` | `anthropic:claude-sonnet-4-5-20250929` | Explicit access token or enrolled OAuth file | Token expires within one hour; OAuth file is developer-local only |
| `req_llm-1.20.0/github-copilot/1` | `github_copilot:gpt-4o-mini` | Explicit token or developer-local `gh auth token` | `gh` output is supplied explicitly in ReqLLM token mode |

Every profile requires graph-owned provider-terms evidence and a consented live
verification IRI before enrollment. Live provider calls remain opt-in behind
the explicit `JIDO_CODE_LIVE_SUBSCRIPTION_TESTS=1`, `consent: :granted`, and
`live_test: true` gate; the default test suite contacts no provider and consumes
no subscription usage. Acceptance of provider terms and live verification are
operator-owned release evidence, not assertions made by this candidate.

OAuth file enrollment accepts only an explicit absolute regular file outside
the supplied repository, store, and sandbox roots. It rejects symlinks in the
file or any path component, mismatched ownership, and group/world permissions,
and revalidates those invariants at every credential release. ReqLLM is the sole
refresh owner for this developer-local mode, while a node-visible exclusive
lease rejects overlapping refresh attempts. Managed and multi-user file-backed
OAuth remain blocked until a dedicated broker can own refresh and supply a
short-lived access token. Current-directory and ambient OAuth discovery are not
admitted dispatch paths.

OpenAI Codex dispatch forces `store: false`, SSE, and no reusable WebSocket
session. GitHub Copilot dispatch forces explicit token mode. All subscription
profiles retain the buffered profile's no-cache, zero-retry, bounded-timeout,
metadata-only-telemetry, no-repair, and no-tool controls. Provider response and
conversation identifiers are bounded external call metadata only; they are
never sent as continuation options, and recovery is recorded as a new explicit
interaction reconstructed from graph state.

## Phase 2 Conformance And Failure Matrix

| Required proof | Executable evidence | Result |
| --- | --- | --- |
| Exact reviewed-query context and omission recording | `phase_h02_context_compiler_test.exs` | 5 tests pass; exact pins, stale dataset/graph/snapshot denial, linked lossy summaries, and explicit budget omissions |
| Broker, retry, cache, telemetry, and repair hardening | Buffered-profile and gateway-integration suites | Missing credentials stop before dispatch; injected cache/repair/hook/provider options stop before release; one failed transport produces one ReqLLM call with `max_retries: 0` |
| Wire and streaming cleanup | Buffered-profile and streaming suites | OpenAI fixture encodes `store: false` with no tools; every stream path retains and closes one handle; cancellation, lease loss, timeout, duplicate terminal, and tool-call paths fail closed |
| Revocation and no fallback | `phase_h02_gateway_integration_test.exs` | Revocation before release exposes no credential; revocation after release stops dispatch; runtime revalidation rejects mutated provider, model, endpoint, access mode, credential class, and billing mode |
| Subscription enrollment | `phase_h02_subscription_profile_test.exs` | Exact catalog contracts, consent and terms gates, short-lived tokens, developer-local `gh`, file ownership/mode/path checks, refresh serialization, and graph-state recovery pass |

The final integration matrix added runtime profile-invariant validation in
addition to constructor admission. An already-built profile is therefore
rechecked before credential release and again when the adapter validates its
dispatch; mutating a struct cannot turn an accepted profile into a provider,
endpoint, access-mode, credential-class, or billing-mode fallback.

## Verification Record

| Command or gate | Result |
| --- | --- |
| `mix compile --warnings-as-errors` | Pass |
| `mix architecture.check` | Pass |
| `mix hex.audit` | Pass; no retired packages |
| `phase_h02_model_gateway_test.exs` | 6 tests, 0 failures |
| `phase_h02_buffered_profile_test.exs` | 9 tests, 0 failures |
| `phase_h02_streaming_test.exs` | 6 tests, 0 failures |
| `phase_h02_subscription_profile_test.exs` | 11 tests, 0 failures |
| `phase_h02_gateway_integration_test.exs` | 4 tests, 0 failures |
| Complete Phase H02 harness | 41 tests, 0 failures |
| Phase H01 regression files | 49 tests, 0 failures |
| `mix precommit` (compile, architecture, dependency cleanup, format, full suite) | Pass; 403 tests, 0 failures |

## Known Limits At Accepted Candidate

- No live provider call was made while assembling this receipt. Subscription
  release remains conditional on explicit operator consent, accepted
  provider-terms evidence, and a successful live-verification record.
- File-backed OAuth and `gh auth token` are developer-local only. Managed and
  multi-user use remains blocked until a dedicated credential broker is proven.
- Provider contractual retention, training, prompt-cache behavior, and
  subscription accounting remain explicit external residuals; JidoCode
  disables its own cache and records observed cost but does not claim hard
  subscription-budget enforcement.
- Subscription profiles remain subject to their recorded provider-contract and
  live-verification evidence after merge; a later violation reopens HG2 under
  the gate conditions below.

## Gate HG2

HG2 is accepted at merged candidate
`49453d05fe72c45431420c05591f89d4ff09f0a8`, pinned in this receipt and the
Harness Phase 2 plan. Harness Phase 3 is authorized from that baseline. Any
model dispatch that can bypass the credential broker or Factory gateway, any
surviving ReqLLM cache or hidden retry path, any provider-executed effect that
can be auto-injected, any stream that can emit more than one terminal outcome
or leak a response, or any profile that silently falls back across provider,
model, access mode, credential class, or billing mode reopens HG2. These
reopening conditions remain in force regardless of checklist state.
