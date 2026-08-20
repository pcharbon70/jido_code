# Memory Phase 3 Governed History Retrieval Receipt

## Status

This receipt records the Memory Phase 3 candidate verified locally on
2026-08-20. MG3 is merge-pending: the candidate must still pass clean-checkout
CI and merge before this receipt can accept a merged commit or authorize Phase
4. No MG3 blocking invariant was observed in the local verification matrix.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted MG2 baseline | `87e2c002973bdb030f5be90e7818ab1ecd6d5bac` |
| Phase branch baseline | `04bdba6ee411429a156da398f80063f8744e1c08` |
| Section 3.1 | `5e2d4cbcdf3f27647229af5c454fc8bee826858c` - publish governed history query catalog |
| Section 3.2 | `caff03d2ed824e69d65301abdfef247c9665a515` - authorize memory retrieval before search |
| Section 3.3 | `13325d730e8e807d7e449746191b5a56db90500d` - build bounded memory evidence packets |
| Section 3.4 | `7a3053e73733a3748f29fc1a081a4ea05d11514d` - integrate memory evidence with harness context |
| Section 3.5 and receipt | merge-pending branch candidate; the commit containing this receipt |
| Merged candidate | merge-pending; must be replaced by the full merge-commit SHA after clean-checkout CI and merge |

## Contract Pins

| Boundary | Candidate value |
| --- | --- |
| History query catalog | `2.0.0`; aggregate source-digest pin `a4d91edcdc363319dd5da39875cd879efd23fce16e3ac26884196c23cd7bc445` |
| Candidate-access contract | `1.0.0`; authorization-bound partition before generator invocation |
| Deterministic ranker | `1.0.0` |
| Disposable retrieval index | `1.0.0` |
| Evidence-packet contract | `1.0.0`; packet digest binds query, ranker, index, items, omissions, and usage |
| Memory guardrail/profile revision | `1.1.0`; `history_queries` and `retrieval_index` enabled |
| Benchmark corpus | 4 immutable cases; SHA-256 `6a63d96c7f60d84c8ca195a2b77c2f4afdce8301a7285402dccf9666b1aea13a` |
| Dense retrieval | Port defined, production adapter disabled |
| Retrieval channels | Exact identifier, lexical, temporal graph, failure signature, recency, and current state |
| Request bounds | At most 100 items, 20 graphs, 256,000 bytes, 65,536 tokens, and 5,000 milliseconds |
| Candidate fan-in | At most 1,000 structurally valid candidates per authorized channel invocation |
| Integration fixture | Real Phase 4/5 bootstrap, enrollment, evidence, serialized writer, segmented run, capture shell, and TripleStore queries |

The history source digests are:

| Query | SHA-256 |
| --- | --- |
| `attempt_timeline` | `9d1eca8180f0baa7dd850b4e79365ef19627270a0cff375593ef032a1c80aacc` |
| `attempt_capture_completeness` | `7633649eb416d896219d8b4350b3758d934ee999c44818cc5cad3797551b5c1c` |
| `task_attempt_lineage` | `d9a9fd654ca5c7edb2b8f3aeb031bfbee64edccd6a484da1baa3e4687f930977` |
| `attempt_event_range` | `a1a7103d8b947be0d8444215168b9d752d968fd9858852eed304a9c5f8144df1` |
| `segment_event_range` | `2a3c856e689e760dd0910092803bb512e857d775442f38f9cadf42e338530b7a` |
| `exact_failure_occurrences` | `2a75321b771b51ee9f9e6f2095c7f263b1f8e0324170f6a20fa810d46d13e5f6` |
| `issue_change_test_lineage` | `003e879194d9d752163677db3eb597bc80aaeae829389b2eca419b8e586dd10f` |
| `incident_linkage` | `34821519599f04a215a40f120ff23609ef6cd5a361b123a1fe1ba634a6076f89` |
| `why_does_this_exist` | `904386c9a343116980ea9aa271e06106251c6b1ae1ee4e7419a9b78799437748` |

## Authorization, Temporal, And Adversarial Evidence

The retrieval request derives its first-stage partition only from an allowed,
revisioned authorization decision. The generator receives repository, tenant,
actor, actor scope, provider profile, purpose, data ceiling, effective-time
generation, and erasure generation before it can return candidates. Candidate
access rejects partition, repository, tenant, actor, actor-scope, provider,
purpose, classification, category, trust, future-time, availability, erasure,
invalidation, compatibility, stale, poisoned, and unauthorized-hold mismatches
before ranking. Malformed candidates fail the boundary closed.

Real-store queries proved exact segment sequences, capture shells, failure
signatures, evidence lineage, and rationale links. Failure, lineage, and
rationale records present at the current cutoff disappeared at a cutoff one
second earlier. Query results retain exact scope and graph revisions; direct
recovery handles retain source IRI, graph IRI, and graph revision.

Packet assembly omitted an individually oversized candidate under the byte
budget, retained contradiction state as evidence rather than authority, and
recursively rejected authority-bearing payload keys. Every serialized memory
item is structurally separated from instruction context, labeled
`non_instructional_data`, and marked `authority?: false`. Disabled memory mode
delegates to the base compiler and produces bit-identical context behavior.

## Rebuild And Ablation Evidence

Deleting and rebuilding the disposable lexical index from the same authorized
candidate set produced the same index digest and ordered entries. Durable graph
truth remained the source of each recovery handle. Under one fixed request
budget, the integration matrix compared no-memory, recent-context,
full-eligible, lexical-only, graph-only, and hybrid packets. Observed item
counts were respectively 0, 1, 3, 1, 1, and 2; every report retained the exact
same item, graph, byte, token, and time budget map.

## Verification Record

| Command or gate | Result |
| --- | --- |
| Phase 3 history, authorization, retrieval, harness, and real-store integration matrix | 17 tests, 0 failures |
| Disposable index, oversized packet, contradiction, and harness regression subset after contract pinning | 10 tests, 0 failures |
| `mix architecture.check` | Pass |
| `mix precommit` | 664 tests, 0 failures; pass |
| Pull request clean-checkout CI | merge-pending |

## Known Limitations

- Dense retrieval remains disabled. No embedding model, vector store, or
  production adapter is authorized by this phase.
- Retrieval indexes are disposable in-process projections, not durable memory
  authorities. They must be rebuilt from authorized graph candidates.
- The ordinary packet exposes semantic evidence and recovery commitments only.
  Exact retained content still requires a separate permit and is never embedded
  merely because a candidate was selected.
- Ranking is deterministic and transparent but is not yet supported by delayed
  production outcome evaluation; that evidence belongs to later memory gates.
- Provider-private state, hidden reasoning, secrets, prompts, encrypted content,
  and backup derivatives remain outside the retrievable classification set.

## Gate MG3

MG3 remains merge-pending. After the pull request passes clean-checkout CI and
merges, this receipt and the Phase 3 plan must pin the full merge-commit SHA and
merge date before Phase 4 is authorized.

MG3 reopens if authorization does not precede every candidate lookup; if an
index can inspect or combine candidates across repository, tenant, actor,
actor-scope, provider-profile, purpose, data-ceiling, effective-time, or erasure
partitions; if future, erased, unavailable, invalidated, stale, poisoned,
malformed, incompatible, or unauthorized-held evidence can reach ranking; if a
packet can grant instructions, tools, capabilities, policy, credentials,
destinations, approvals, commands, or durable-write authority; if any packet
can exceed its item, graph, byte, token, or time budget; if source identity,
graph revision, temporal scope, classification, trust, evidence strength,
freshness, limitation, contradiction, applicability, or recovery requirements
are lost; if exact content bypasses its separate permit; if no-memory mode
changes base authorization or tool behavior; if an index cannot be deleted and
deterministically rebuilt from graph truth; if self-reported usefulness is
treated as evidence; if dense retrieval becomes reachable without its own
evaluation; or if any MG4-MG6 feature becomes reachable before its owning gate.
These reopening conditions remain in force regardless of checklist state.
