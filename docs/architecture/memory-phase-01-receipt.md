# Memory Phase 1 Contract, Topology, And Policy Receipt

## Status

This receipt records the Memory Phase 1 candidate verified locally and
accepted after pull request merge on 2026-08-18. Pull request #48 passed
clean-checkout CI and merged on 2026-08-18 as
`f65b25ef3410dd5bad8da9fcd4b07b99a6acc2b2`. MG1 is accepted, and Phase 2 is
authorized only from that exact merged baseline.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Phase baseline and total-memory plan merge | `7adc0ea2d2e4c1b0589b726c9a17eadc2aca7ad8` |
| Section 1.1 | `a22a4e33d1d04b6538f8143a6a55a117bb93c609` - define total memory content contract |
| Section 1.2 | `797f7dca32724f816bed43db725284740fffa272` - ratify total memory graph topology |
| Section 1.3 | `253ec7c6b45c4532e2851d054e02301d3b5fc0d7` - govern total memory data lifecycle |
| Section 1.4 | `0342ff7d4440aec4f4beb633c23799e17290fd33` - establish total memory guardrails |
| Section 1.5 and receipt | `a2ff588afc0ea6b0698c9bb3bfecef9e7311f391` - verify total memory Phase 1 contracts |
| Merged candidate | `f65b25ef3410dd5bad8da9fcd4b07b99a6acc2b2` |

## Contract Pins

| Boundary | Candidate value |
| --- | --- |
| Memory content contract | `2.0.0` |
| Graph registry | `2.0.0` |
| Factory ontology / operational shapes | `1.1.0` / `1.1.0`; legacy `1.0.0` pair readable |
| Data policy | `2.0.0` |
| Runtime capture profile | `semantic_history`; diagnostic, project-total, and incident profiles disabled |
| Retention policy | 14 closed classes; archive unavailable without a queryable cold tier |
| Migration, threat, capacity, and benchmark guardrails | `1.0.0` |
| Segmented protocol posture | `2.0.0` writes disabled until MG2; immutable `1.x` dual-read only |
| Phase 6 benchmark corpus SHA-256 | `6a63d96c7f60d84c8ca195a2b77c2f4afdce8301a7285402dccf9666b1aea13a` |

## Ratified Memory Boundary

Total memory means complete accounting for eligible observable events and
bodies, not retention of every byte. Secret values, provider-private state,
and hidden reasoning remain outside the claim. Every expected body must record
captured, omitted, unavailable, redacted, failed, expired, or erased. Capture
outcome, representation, location, availability, retention/erasure, and hold
are independent dimensions.

The durable inventory covers instructions, interaction messages, model
outcomes, tool output, embedded artifacts, receipt commitments, exports, and
backup derivatives. Legacy exact tool bodies and plaintext-derived receipt
commitments remain honest immutable limitations; they are not automatically
recallable and do not authorize new plaintext-sensitive commitments.

The only enabled capture posture is `semantic_history`: bounded envelopes,
normalized facts and selected text, digests, and governed references. Exact
assembled prompts, provider-private responses, raw tool bodies, reusable
credentials, and secret values are omitted. Sensitive new commitments require
already-encrypted ciphertext or an external protected key for an accepted
equality-verification purpose.

## Topology, Retention, And Compatibility Evidence

Ontology `1.1.0` composes the digest-pinned immutable `1.0.0` schema locally
and adds capture, segment, experience, lifecycle, permit, encrypted-content,
and chunk vocabulary plus shapes. Startup recognizes the exact `1.0.0` and
`1.1.0` release pairs, rejects unknown releases, and reopens both accepted
datasets without rewriting closed graphs.

`run_event_segment`, `experience`, `content_lifecycle`, and `episode_content`
have exact identities, scopes, writer capabilities, shapes, links,
completeness, lifecycles, and retention classes. All four are registered but
disabled. No current semantic command or reviewed history query can reach
them. Episode content cannot link into evidence or accepted memory.

Archive means queryable cold retention. No cold tier is accepted in this
candidate, so archive-eligible data produces
`retention_archive_unavailable`; it is neither removed nor reported as
archived. Disposable removal and legally requested erasure are distinct plan
and receipt counts. Semantic shells outlive exact payload classes, while
closed run graphs remain immutable.

Open legacy attempts block segmented activation. Terminal abandoned attempts
also require an explicit governed abandonment decision. Closed `1.x` runs are
dual-readable only as their stored bounded-observable representations and are
never relabeled as complete event histories.

## Security And Capacity Evidence

The threat catalog covers persistent poisoning, delayed prompt injection,
cross-scope retrieval, stale procedures, false causality, context overload,
secret capture, and incomplete erasure. Retrieval authorization must precede
candidate generation. Its partition identity binds authorization revision,
repository, tenant, actor scope, purpose, data ceiling, effective-time
generation, and erasure generation; changing any field changes the partition.

The capacity profile reserves 200 of 1,000 additions for closure and remains
below every existing 10,000-quad, 100-guard, 16-target-graph, and 262,144-byte
command ceiling. The Phase 6 corpus and relative capture, query, backup,
restore, rebuild, storage, integrity, orphan, and erasure thresholds are
digest-pinned. A failed threshold requires a separately accepted vault ADR; it
does not authorize a second store.

Future segmented/experience/lifecycle/content writers, history queries,
retrieval indexes, broader capture profiles, and the content gateway all
remain disabled until their owning MG2-MG6 gate is accepted.

## Verification Record

| Command or gate | Result |
| --- | --- |
| Content, topology, policy, guardrail, ontology, retention, and Phase 1 focused suite | 43 tests, 0 failures |
| Real TripleStore Phase 1 conformance fixture | 5 tests, 0 failures |
| `mix compile --warnings-as-errors` | Pass |
| `mix architecture.check` | Pass |
| `mix precommit` | 621 tests, 0 failures; pass |
| Pull request #48 clean-checkout CI | Pass; merged 2026-08-18 |

## Known Limitations

- Segmented event accounting, reviewed history retrieval, cases, procedures,
  exact encrypted content, lifecycle transitions, and datasets are later-phase
  work and remain runtime-disabled.
- The benchmark contract pins a reproducible corpus and decision thresholds;
  it contains no Phase 6 graph-native or vault performance measurements.
- There is no queryable cold archive, dense retrieval index, content gateway,
  application-owned encrypted vault, or enabled exact-content graph.
- Existing backups may retain immutable legacy representations. Physical,
  provider, and backup erasure cannot be claimed until the owning lifecycle and
  restore-floor evidence exists; unverifiable external deletion remains
  explicitly unverifiable.
- Dual-read compatibility reports only stored legacy evidence. It cannot
  reconstruct unavailable provider events, exact assembled prompts, or bodies
  that were never captured.

## Gate MG1

MG1 is accepted at merged candidate
`f65b25ef3410dd5bad8da9fcd4b07b99a6acc2b2`, pinned in this receipt and the
Phase 1 plan. Phase 2 is authorized only from that exact baseline. MG1 reopens
if any stored content is ambiguously classified, any family lacks a closed
contract, or any retained content can become authority;
if a secret value, provider-private state, or hidden reasoning becomes durable;
if archive, removal, erasure, hold, or legacy completeness is reported more
strongly than achieved; if authorization occurs only after candidate
generation; if a capacity bound can make a run uncloseable; or if any future
writer, query, profile, index, or content gateway becomes reachable before its
owning phase gate. These reopening conditions remain in force regardless of
checklist state.
