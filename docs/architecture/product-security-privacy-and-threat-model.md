# Product Security, Privacy, And Threat Model

## Security Boundary

The browser authentication boundary is separate from graph authorization.
`JIDO_CODE_OPERATOR_TOKEN` supplies an external credential at runtime. Only its
SHA-256 digest is held in application configuration. A successful sign-in
renews and clears the prior session, then stores an authentication timestamp,
random nonce, and trusted session generation in the signed Phoenix session.
Credentials never enter the session, graph, logs, telemetry, flash, or forms
returned to the browser.

The root product route and development dashboard require the authenticated
pipeline. `ProductAuth` reconstructs principal and actor IRIs from trusted
configuration, not browser values. The authenticated `live_session` repeats
this check on mount and validates expiry plus the trusted generation before
every semantic event. Changing `JIDO_CODE_SESSION_GENERATION` revokes all
existing sessions. Logout drops the complete session.

Route admission does not grant resource or command authority. Product query
code admits a closed query/version/parameter matrix and the knowledge boundary
repeats graph capability authorization. Repository selection must be a member
of the actor-authorized cohort. Unknown, malformed, unauthorized, cross-scope,
and revoked selections all return the same unavailable presentation.

## Data Classification

| Classification | Durable location | Product output |
| --- | --- | --- |
| Public | ontology | UI, documentation, low-cardinality telemetry |
| Internal | catalog and control graphs | authorized UI and audit |
| Confidential | observation and source graphs | bounded authorized UI and audit |
| Secret reference | factory policy | reference and status only |
| Secret value | none | never |
| Source body | source revision or governed artifact | exact bounded inspection only |
| Prompt | none | never |
| Raw tool output | none | governed bounded artifact only |
| Personal | security audit when policy requires | authorized audit only |
| Audit | security audit | authorized audit only |

`JidoCode.Security.Redactor` is the shared fail-closed sanitizer for product,
diagnostic, telemetry, and export values. It bounds depth, entries, key size,
and string size; redacts classified keys, credential URLs, authorization
headers, token patterns, private-key material, and private home paths; and
returns a transient bounded receipt. Semantic command input containing these
values is rejected before graph reads. A durable redaction receipt, when
required, must itself use the semantic command pipeline.

## Threat Review

| Boundary or abuse case | Prevent | Detect and recover | Proof |
| --- | --- | --- | --- |
| Credential guessing or reflection | constant-shape failure, bounded token, secure digest comparison | authentication failure metrics without values; rotate token and generation | `AuthControllerTest` |
| Session fixation or copied stale session | renew and clear on login; expiry; signed cookie; generation | revoke generation and force reauthentication | `ProductAuthTest` |
| CSRF command submission | Phoenix CSRF pipeline on sign-in, sign-out, and LiveView | reject request before event or controller action | controller and LiveView tests |
| Actor or delegation forgery | actor built from trusted config; command gateway ignores browser actor fields | command/audit actor mismatch blocks commit | `CommandGatewayTest` |
| Route/resource enumeration | closed route values, bounded refs, cohort membership, concealment | safe unavailable state with no stale stream rows | `HomeLiveTest`, `QuerySecurityTest` |
| SPARQL injection or catalog bypass | no raw query endpoint; closed names, versions, keys, graph families, states | stable `invalid_input` before adapter invocation | `QuerySecurityTest` |
| Expensive graph amplification | catalog limits, finite work states, repository cap, empty adapter options | timeout/limit telemetry and truncated projection | projection provider tests |
| Secret, prompt, source, or path leakage | one classification/redaction policy; no raw errors | bounded redaction counts without values; fail closed | `RedactorTest` |
| Provider/webhook forgery | provider observations remain adapter input and require semantic validation | source provenance, completeness, and reconciliation diagnostics | Phase 6 suites |
| Git/worktree or artifact confusion | exact snapshot/artifact identities and digests | provenance closure and post-write verification | Phase 6 and 8 suites |
| Ontology/import mutation | pinned releases, startup gate, shape validation | incompatible readiness and maintenance recovery | Phase 3 suites |
| Lease replay or confused deputy | actor/scope binding, idempotency, revision guards, fencing | accepted transition history and recovery scan | Phase 7 and 8 suites |
| Tool or sandbox escape | typed ports, effect policy, sandbox ownership, no durable worktree authority | cancel, quarantine artifacts, recover from graph | Phase 8 suites |
| Backup disclosure or erased-data reintroduction | trusted paths, access controls, checksums, lineage and erasure manifests | isolated restore validation and derived rebuild | Phase 10 recovery tests |
| Persistent memory poisoning | source-linked memory remains untrusted and cannot grant authority | invalidate the source and rebuild disposable derivatives | MG3 adversarial suite |
| Delayed prompt injection in retained content | retrieved history is structurally non-instructional with bounded sinks | quarantine the source and rebuild affected packets/indexes | MG3 adversarial suite |
| Cross-scope memory retrieval | authorization-bound repository/tenant/actor/purpose/time/erasure partitions before candidate generation | revoke the partition and rebuild indexes from authorized graph truth | MG3 scope matrix |
| Stale remembered procedures | exact effective-time, source revision, applicability, and freshness checks | supersede or invalidate the procedure and reassess influenced attempts | MG5 procedure suite |
| False causal memory | typed temporal lineage; later associations cannot fabricate earlier attempt identity | challenge the claim and recompute source-linked projections | MG4 lineage suite |
| Memory context overload | hard item, graph, byte, token, time, guard, and command budgets | truncate with explicit omissions and preserve direct recovery handles | MG3 budget suite |
| Secret capture in memory | forbidden-content policy and structural non-placement for secret values/private reasoning | block retrieval first, then execute classified erasure without overstating external deletion | MG1 and MG6 secret canaries |
| Incomplete erasure across derivatives | generation-bound indexes, derivative inventory, restore floors, and key lifecycle | keep erasure pending and restore blocked until every required derivative is accounted | MG6 erasure/restore suite |

## Residual Risk And Release Blocks

The first accepted deployment uses one externally managed operator credential;
federated identity, per-human principals, and hardware-backed sessions are not
implemented. This is acceptable only for a single-operator deployment behind
TLS and network access controls. Expanding the deployment requires a new
authentication adapter that preserves graph actor/delegation mapping.

Release remains blocked by any credential reflection, arbitrary query or graph
selection, cross-scope resource visibility, command actor widening, sandbox
escape, unverified backup restore, or secret-value persistence. The exact
lockfile was checked with `mix hex.audit` on 2026-08-04 and contained no retired
Hex packages. Git/native dependencies and all licenses remain part of the
release-candidate operator audit; no dependency pin is advanced implicitly.
