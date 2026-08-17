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
| Section 2.2 | This section's exact commit is recorded by Git history |
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

## Section 2.2 Verification Record

| Command or gate | Result |
| --- | --- |
| `mix compile --warnings-as-errors` | Pass |
| `mix architecture.check` | Pass |
| `mix hex.audit` | Pass; no retired packages |
| `phase_h02_model_gateway_test.exs` | 6 tests, 0 failures |

## Gate HG2

HG2 is merge-pending and remains blocked. It reopens—or remains blocked—if any
model dispatch can bypass the credential broker or Factory gateway, any ReqLLM
cache or hidden retry path survives, any provider-executed effect can be
auto-injected, streaming can emit more than one terminal outcome or leak a
response, or any profile silently falls back across provider, model, access
mode, credential class, or billing mode. These reopening conditions remain in
force regardless of checklist state.
