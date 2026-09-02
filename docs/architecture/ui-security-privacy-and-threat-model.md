# Hypermedia UI Security, Privacy, And Threat Model

- Status: Proposed under ADRs 0008, 0009, and 0011
- Specification version: `0.2.0`
- Owners: JidoCode security, identity, product, Knowledge, and operations
  maintainers
- Milestone: G — Security And Release Qualification
- Extends: [Current product threat model](./product-security-privacy-and-threat-model.md)

## Purpose

This specification extends the accepted threat model for named humans,
controller-rendered HEEx, Datastar signals, Dstar/SSE, attempt workspaces,
bounded agent conversations, canonical approvals, graph lenses, several tabs,
and restricted governance areas. Existing classification, concealment,
credential, graph authorization, and audit requirements remain binding.

## Assets And Trust Boundaries

Protected assets include identity/authenticators, grants/delegations, source,
candidates, private previews, memory/episode content, policy, security audit,
credentials, prompts/tool output, provider metadata, costs, receipts, and graph
topology.

Untrusted inputs include URLs, params, headers, cookies before verification,
Datastar signals/expressions, tab IDs, cursors, replay IDs, source/wiki/memory/
graph literals, model/provider/tool output, filenames/links, client connection
state, and agent rationale.

Trusted enforcement points are authentication/authority Plugs, reviewed query
authorization/redaction, semantic gateways, stream admission/reauthorization,
classification, and immutable receipts.

## Threat Matrix

| Threat | Required controls |
|---|---|
| IDOR/cross-scope ref | Server containment and exact capability on page/query/stream/command/export |
| Signal/DOM tampering | Closed schemas; server-derived identity/action/state; no hidden-field authority |
| Stale preview/TOCTOU | Re-query canonical state and bind expected revisions/fence/action digest |
| Approval spoofing | Trusted transaction component separate from escaped untrusted rationale |
| Content/expression injection | HEEx escaping, bounded sanitization, static expressions, CSP nonce, no Dstar Scripts |
| CSRF/cross-site action/stream | Phoenix CSRF, body/header token, Origin/Fetch Metadata, SameSite, no GET effects |
| Stream survives revocation | Hard expiry, independent generation/revocation, periodic/pre-patch auth, terminal close |
| Replay/tab confusion | Scope-bound opaque cursor; stable-session+tab dedup; current snapshot on reconnect |
| Cache/proxy/log leak | TLS, no-store, strict referrer, buffering policy, query/header/log redaction |
| Graph inference | Authorize before aggregate, concealed parity, bounded error/timing vocabulary |
| Connection/query exhaustion | Per-principal/factory limits, bounded queues/queries/expansion/export, cleanup |
| Supply-chain drift | Exact versions/SHAs/digests/licenses, local assets, CSP, clean-checkout evidence |
| Clickjacking/base/form abuse | CSP frame-ancestors/base-uri/form-action and canonical target/consequence |
| Concurrent-human overwrite | Compare-and-set semantic commands and immutable conflict receipts |
| Cross-attempt/session message delivery | Resolve containment and audience server-side; exact attempt/session/reply binding; conceal unauthorized sessions |
| Prompt/message injection | Treat every human/agent message as bounded untrusted text; escape output; no executable HTML/Markdown or message-derived authority |
| Stale or duplicate answer | Bind current clarification, sequence, revision, lease/fence, profile, digest, and idempotency; return conflict/current receipt |
| False delivery/read state | Derive labels only from durable message, command receipt, and runtime observations; no typing/read/seen inference |
| Draft disclosure | Keep drafts tab-local, omit them from URLs/logs/telemetry, clear on identity/scope/session change, and reauthorize after step-up |

## Privacy And Classification

The server classifies/redacts before HEEx rendering. CSS, collapsed content,
tooltips, client roles, and hidden signals are not privacy boundaries. The
minimum necessary projection omits credentials, secrets, raw prompts/reasoning,
unbounded output, internal graph IRIs/query text, process/sandbox identifiers,
private sibling resources, complete memory, and high-cardinality telemetry
unless exact policy admits them.

Operational telemetry, security audit, semantic receipts, and user-facing
activity are separate retention/access classes.

## Browser And Transport Controls

- TLS and HTTP/2 for qualified live delivery;
- secure HTTP-only SameSite cookies and session generation;
- CSP response header with fresh nonce and no external runtime;
- no-store for confidential pages/streams and safe proxy buffering;
- bounded request/body/header/query/signal/event/patch sizes;
- rate, concurrency, retry, queue, and export limits;
- no secrets/CSRF in URL/referrer/logs;
- same-origin local assets with integrity/digest provenance; and
- secure browser headers including frame and MIME protections.

## Security Test Program

The release corpus covers hostile repositories/wiki/memory/graph/model/tool and
conversation content, XSS/expression/prompt injection, cross-attempt/session
message delivery, stale/duplicate clarification answers, draft leakage, false
delivery state, IDOR, role/grant/delegation churn, step-up bypass, CSRF, Origin,
clickjacking, cache/log leak, aggregate inference, reconnect/replay, live
revocation, stream/query exhaustion, malformed fragments, concurrent humans,
approval mismatch, supply-chain drift, and incident/recovery.

Unsafe effect, credential disclosure, cross-scope or cross-session disclosure/
delivery, authority escalation through message content, approval mismatch,
protected reconnect after revocation, and unbounded graph/export have zero
tolerance.

## Acceptance And Reopening

Milestone G security closes only with independent review, real browser/proxy/
identity adapters, zero-tolerance results, remediation evidence, and a pinned
merged candidate. It reopens on any zero-tolerance finding, classification/
retention drift, dependency change, new signal/event/route/lens/action,
authorization bypass, CSP relaxation, or missing revocation/incident drill.
