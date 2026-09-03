# Hypermedia UI Approval And Live Revocation Authority

## Status And Scope

This is an accepted HUI-A2 architecture contract under ADR 0009. It defines
deterministic separation-of-duty and revocation models for later named-human
product implementation. It creates no named account, approval route, stream,
patch, export, incident command, or multi-human release capability.

The machine-readable authority is
[`priv/architecture/hypermedia_ui/phase_a2_approval_and_revocation.json`](../../priv/architecture/hypermedia_ui/phase_a2_approval_and_revocation.json).

The accepted current `JidoCode.Factory.Approval.Request` and
`JidoCode.Factory.Approval.Gateway` continue to provide single-use,
digest-bound, invocation-before-effect enforcement for their qualified backend
workflow. They do not provide named-human account lifecycle, browser quorum,
or live client revocation and receive no such release credit from HUI-A2.

## Canonical Action Binding

The server computes a lowercase SHA-256 digest over
`:erlang.term_to_binary(tuple, [:deterministic])`, where the versioned tuple is:

```text
{:hui_action_v1,
 action, target_refs, scope_refs, parameters_digest, effect_digest,
 expected_revisions, fence, policy_revision, environment, classification,
 expires_at, idempotency_key_digest}
```

Collections are bounded, unique, and sorted before tuple construction; times
are UTC and microsecond-truncated. Browser or agent text cannot supply the
digest. Changing any tuple value invalidates pending and quorum-met approval.

## Maker, Checker, And Quorum

An approval request records an immutable request reference, maker subject,
canonical action digest, target/scope, exact consequence, required capability,
policy and expected resource revisions, fence when applicable, evidence refs,
required assurance, required unique checker count, expiry, and idempotency
identity.

Every checker must be a current named human distinct from the maker and from
every other counted checker. Eligibility is an exact current capability and
resource decision, not a role label. The checker reauthenticates at the
required assurance, receives the exact consequence, and signs only the
canonical digest. Self-approval, agent approval, stale assurance, expired or
revoked membership/delegation, changed input, and duplicate-principal quorum
all fail closed.

The approval state machine is:

```text
pending --eligible unique approval--> pending | quorum_met
pending | quorum_met --reject--> rejected
pending | quorum_met --expiry--> expired
pending | quorum_met --input/revision/generation/fence change--> invalidated
quorum_met --reauthorize + compare-and-set winner--> committed
```

`rejected`, `expired`, `invalidated`, and `committed` are terminal. Approval
records are immutable evidence; invalidation creates a new request rather than
rewriting the old digest.

## Concurrent Commit Outcomes

Commit is compare-and-set over action digest, policy/resource revisions,
account/session/membership/grant/delegation generations, lifecycle, and fence.
The first exact transition commits one effect and one immutable winner receipt.
A duplicate with the same idempotency identity returns that same receipt. A
different concurrent action that loses returns `conflict_current_receipt`
pointing to the safe winner receipt and never dispatches an effect. A stale or
revoked request returns its closed safe outcome and never becomes the winner.

## Revocation Generations

Independent monotonic generation or revision values exist for account,
session, role explanation, delegation, project membership, tenant membership,
graph grant, and incident policy. A revocation event records dimension, exact
subject/resource scope, prior and next generation, policy revision, cause,
accountable actor, time, audit correlation, and receipt reference. The next
generation must be exactly prior plus one.

Role revision does not remove a grant because roles never grant authority; it
invalidates navigation/explanation state and forces reconstruction. Graph grant
or membership revocation independently invalidates authority even when a role
label is unchanged.

## Protected Client State

Protected delivery uses this state model:

```text
active --revocation or generation mismatch--> revocation_observed
revocation_observed --safe replacement prepared--> terminal_replacement
terminal_replacement --replacement sent or connection unavailable--> closed
closed --reconnect with revoked generation--> reconnect_suppressed
```

Future protected bytes stop immediately after the server observes revocation.
The server best-effort replaces protected fragments with a safe terminal
surface, closes the stream, suppresses privileged reconnect, invalidates signed
links and export/download retrieval, clears privileged browser state, and
records safe security/audit evidence. It does not claim to erase bytes already
delivered to an offline or malicious client.

Every patch and every export/download retrieval reauthorizes independently.
Periodic checks and hard expiry are defense in depth; they do not replace the
independent revocation event path.

## Reopening Conditions

This authority reopens if maker and checker can be the same human; roles decide
eligibility; duplicate humans count twice; digest fields are mutable or
browser-supplied; stale assurance, revision, generation, lifecycle, expiry, or
fence can commit; more than one conflicting effect wins; a loser lacks the
safe current receipt; revocation waits only for projection hints or periodic
polling; an open connection, fragment, reconnect, signed link, export, or
download survives changed authority; audit omits the accountable cause; or
offline bytes are falsely claimed erased.
