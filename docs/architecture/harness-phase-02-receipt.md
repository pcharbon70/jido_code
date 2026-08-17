# Harness Phase 2 Context And Model Gateway Receipt

## Status

This receipt is being assembled with the Harness Phase 2 implementation.
The current candidate is merge-pending; HG2 remains blocked until every
section is complete, the full conformance matrix and `mix precommit` pass from
the candidate, clean-checkout CI passes, and the pull request merges. Phase 3
is not authorized from this document yet.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Phase baseline and merged HG1 | `850b9a7` - pin the Phase 1 merged candidate and close HG1 |
| Section 2.1 | `43b84e0` - compile revision-pinned model context |
| Section 2.2 | `8f035e1` - add governed ReqLLM model gateway |
| Section 2.3 | This section's exact commit is recorded by Git history |
| Merged candidate | Merge-pending; full merge-commit SHA must be pinned after clean-checkout CI and merge |

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

## Section 2.2 Verification Record

| Command or gate | Result |
| --- | --- |
| `mix compile --warnings-as-errors` | Pass |
| `mix architecture.check` | Pass |
| `mix hex.audit` | Pass; no retired packages |
| `phase_h02_model_gateway_test.exs` | 6 tests, 0 failures |
| `phase_h02_buffered_profile_test.exs` | 9 tests, 0 failures |

## Gate HG2

HG2 is merge-pending and remains blocked. It reopens—or remains blocked—if any
model dispatch can bypass the credential broker or Factory gateway, any ReqLLM
cache or hidden retry path survives, any provider-executed effect can be
auto-injected, streaming can emit more than one terminal outcome or leak a
response, or any profile silently falls back across provider, model, access
mode, credential class, or billing mode. These reopening conditions remain in
force regardless of checklist state.
