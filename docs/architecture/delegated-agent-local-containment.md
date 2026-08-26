# Delegated Agent Developer-Local Containment

## Status And Scope

This document records the Phase 3 developer-local security boundary for the
disabled DGA1 Codex profile. The implementation proves readiness, consent,
credential, workspace, network, check, and cleanup mechanics without enabling
the profile or granting publication or merge authority.

## Readiness And Consent

`CodexReadiness` performs prompt-free discovery against the exact executable
registry entry. The only CLI authentication operation is bounded `codex login
status`; no prompt-bearing provider request is made, and neither provider nor
JidoCode actor identity is inferred from the result. The expiring receipt pins
the profile, adapter release, local security release, executable, CLI,
credential reference and revocation generation, worker, sandbox, network,
candidate capture, check registry, verifier, and policy revisions. Any expiry
or drift makes the receipt non-current.

`DelegatedAgentConsent` is a short-lived foreground authorization for one
exact effect. It binds actor, repository, task, attempt, lease, fence, profile,
opaque credential reference, revocation generation, subscription billing
classification and terms, purpose, and expiry. Background dispatch, managed
eligibility, reusable credential export, missing billing acknowledgement, and
lifetimes over fifteen minutes fail closed. Live-smoke and qualification
effects require their own effect-bound consent.

Durable credential and consent records contain only opaque resource identity,
current generation, bounded policy bindings, digests, and expiry. Local login
keys and reusable authentication material are never part of those records.
