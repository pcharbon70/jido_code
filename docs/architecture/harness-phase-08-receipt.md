# Harness Phase 8 Optional Extensions Receipt

## Status

This receipt records the Harness Phase 8 candidate verified locally and
accepted after pull request merge on 2026-08-18. Pull request #43 passed
clean-checkout CI and merged on 2026-08-18. The harness plan is complete at
that exact baseline. No optional extension ships runtime-enabled in this
candidate.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Phase baseline and merged HG7 closure | `b911c32dd20d4433738e6f37e8a199bb062f427b` |
| Accepted Phase 7 candidate | `c8e5fc54642319149311921866104a2b642c0c2f` |
| Section 8.1 | `5daf1c0bd43531f938fbc088b3ace5e44e73122a` |
| Section 8.2 | `7bcfe4c5f91c1263b19194a76f98bdd0d5a9c245` |
| Section 8.3 | `ec9628231f26d05745fdbb44e426b9df795d162f` |
| Section 8.4 | `f7a8598ae0621d4afecd5e2e9484b2dd37180544` |
| Section 8.5 and receipt | `10a388733ce894cda5df199feb274545c9c2920a` |
| Merged candidate | `35275337031c5c085c4060801fe67079ec00be18` |

## Contract Revisions

| Boundary | Revision |
| --- | --- |
| MCP accepted-server specification and call gate | `1.0.0` |
| Remote-agent accepted protocol and provenance gate | `1.0.0` |
| Multi-agent evaluation and accepted graph-work gate | `1.0.0` |
| Autonomous-merge blocker | `1.0.0` |
| Runtime extension enablement registry | `1.0.0` |
| Phase 7 adversarial scenario catalog reused by HG8 | `1.0.0` |

## Extension Posture

| Extension | Shipped runtime state | Specification and evidence posture | Required monitor |
| --- | --- | --- | --- |
| MCP tool transport | Disabled; control plane implemented | No deployment specification or evidence is registered; any future enablement must pin server, package, protocol, adapter, descriptor, local closed schemas, and evidence digests | Phase 3 reference monitor and effect journal |
| Remote-agent delegation | Disabled; control plane implemented | No deployment specification or evidence is registered; any future enablement must bind remote identity, protocol versions, local attempt, lease, fence, capability receipt, and evidence digest | Delegated result gate plus independent verification and decision |
| Selective multi-agent work | Disabled; control plane implemented | No task class is registered; each future class needs Phase 7 measurements, a graduated digest-bound decision, and a separate graph-work specification | Per-worker graph work contract and Factory coordinator |
| Autonomous merge | Blocked | Separate accepted ADR, release gate, production shadow, pull-request evidence, and rollback evidence are absent | Human merge remains mandatory; no merge monitor or adapter exists |

The committed default registry contains no specification, evidence, or monitor
entry for any extension. Enabling MCP, remote-agent, or multi-agent work
requires the exact accepted specification type, matching specification and
evidence digests, and its named monitor. Autonomous merge cannot be registered
or authorized by this revision.

## MCP Boundary

The MCP adapter specification pins protocol version, server package and
digest, configured server identity, adapter identity and digest, complete
descriptor pins, and server-namespaced tools. Only locally reviewed closed
schemas enter authority. Every call derives a one-call registered command from
the full call digest, so the Phase 3 capability and approval bind the exact
arguments, endpoint, OAuth metadata, and external argument reference.

HTTPS discovery admits only public HTTPS origins, binds redirects and the
connected address to the reviewed resolution, and rejects private, local,
link-local, carrier-grade, multicast, and rebinding addresses. OAuth binds
issuer, audience, scopes, redirect URI, and S256 PKCE while exact shapes forbid
token passthrough. Local or stdio servers require a separate no-network
sandbox with brokered credential references. The Phase 3 gateway reauthorizes
immediately before transport dispatch. Results contain only a bounded digest
and external reference and remain observations requiring local verification
and decision.

## Remote-Agent Boundary

Each remote task is a local execution request whose attempt, lease, task,
repository, snapshot, actor, remote agent, and fence exactly match its bounded
tool capability. A digest-bound capability receipt records the remote agent
identity, protocol versions, attempt, lease, fence, and capability digest.
Delegation sets reject shared task, attempt, lease, or repository-fence
identity.

Remote outputs pass the current-fence delegated result gate and retain only
closed bounded output, external references, result and claim digests, and
exact provenance. The remote agent, execution actor, independent verifier,
and governed decision actor must all be distinct. Remote claims are marked
untrusted, verification-required, decision-pending, and never accepted.

## Multi-Agent Boundary

The only eligible task classes are independent research, disjoint write sets,
unboundable single-worker context, specialized isolated tools, and verified
candidate diversity. A class graduates only from valid Phase 7 evidence that
measures verified correctness, elapsed time, cost, conflicts, duplicated work,
and merge failures against its single-agent baseline and passes every pinned
threshold.

Every worker receives unique graph-task, context-manifest, attempt, lease, and
capability identities plus its own fence, aggregate-contained budget, output
schema digest, write set, and isolated tool namespaces. Disjoint-write and
specialized-tool classes prove pairwise independence. Worker output is closed,
bounded, coordinator-only, and unable to express acceptance; free-form group
chat is not a contract field.

## Autonomous-Merge Boundary

The current policy records a missing separate accepted ADR and cannot express
autonomous merge authority. Even a fully populated future pilot envelope is
human-merge shadow only and must be reversible, low-risk, evidence-bound, and
immediately disabled on evidence mismatch, protected-branch mutation, sandbox
escape, secret exposure, or a stale fence. The blocker and future requirements
are also recorded in
`docs/architecture/harness-autonomous-merge-blocker.md`.

## Integration And Disabled-Harness Evidence

The integration matrix proves every runtime extension is disabled by default,
malformed or incomplete proofs cannot enable one, an accepted specification
cannot enable a different extension, and exact monitor identities are
mandatory. A disabled registry is pure immutable data: Phase 3 authorization,
delegated-result fencing, and verification admission produce bit-identical
results before and after it is constructed.

The Phase 7 adversarial catalog remains unchanged and includes malicious tool
descriptions, changed schemas, SSRF, DNS rebinding, redirect escape,
cross-actor credential reuse, stale workers, forged results, resource
exhaustion, sandbox escape, and branch movement. The complete prior-phase suite
is rerun by `mix precommit`.

## Verification Record

| Command or gate | Result |
| --- | --- |
| `phase_h08_mcp_test.exs` | 6 tests, 0 failures |
| `phase_h08_remote_agents_test.exs` | 5 tests, 0 failures |
| `phase_h08_multi_agent_test.exs` | 6 tests, 0 failures |
| `phase_h08_autonomous_merge_test.exs` | 5 tests, 0 failures |
| `phase_h08_integration_test.exs` | 5 tests, 0 failures |
| Complete Phase 8 focused suite | 27 tests, 0 failures |
| `mix compile --warnings-as-errors` | Pass |
| `mix architecture.check` | Pass |
| `mix precommit` | 589 tests, 0 failures; pass |
| Pull request #43 clean-checkout CI | Pass; merged 2026-08-18 |

## Known Limitations

This candidate implements and verifies extension control planes, not a claim
that production use is justified. It includes no live MCP server transport,
remote-agent protocol deployment, accepted multi-agent production class,
merge credential, or protected-branch mutation adapter. Test specifications
exercise the gates but are not deployment registrations. Real provider and
sandbox adapters, private evaluation corpora, production shadow results,
operator grants, and durable evidence projection remain deployment work and
must enter through the pinned contracts without weakening them.

## Gate HG8

HG8 is accepted at merged candidate
`35275337031c5c085c4060801fe67079ec00be18`, pinned in this receipt and the
Harness Phase 8 plan. The harness plan is complete at that baseline. HG8
reopens if any extension is reachable without its accepted specification,
pinned digests, evidence, and required monitor; if disabled extensions change
base authorization, fencing, or verification; if remote or multi-agent claims
bypass independent verification and governed decision; or if autonomous merge
authority exists without its separate accepted ADR, release gate, production
shadow, pull-request evidence, rollback evidence, and human-merge transition.
These reopening conditions remain in force regardless of checklist state.
