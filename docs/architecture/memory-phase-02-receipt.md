# Memory Phase 2 Total Semantic Accounting Receipt

## Status

This receipt records the Memory Phase 2 candidate verified locally on
2026-08-19. Acceptance remains merge-pending until the implementation pull
request passes clean-checkout CI and its full merge commit is pinned here.
Phase 3 is not authorized from an unmerged branch or an unpinned candidate.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Phase baseline and merged MG1 closure | `b3f55f4d3d8f23a13bdad06738957172e2a16e3f` |
| Accepted Phase 1 candidate | `f65b25ef3410dd5bad8da9fcd4b07b99a6acc2b2` |
| Section 2.1 | `7a5f1fac53c2da9f1cfd3be8d0273a5dae6a45c9` - implement bounded execution event segments |
| Section 2.2 | `d63749eae1741ae620dd1fbffebd751dc61b7b26` - account for segmented episode content |
| Section 2.3 | `1d2433023c02bde07b3e42db98f3a6a02205f3bc` - sequence immutable execution events |
| Section 2.4 | `ebeee150dad5d7aa3f2d27e4fb359849af7e00bf` - finalize and recover segmented runs |
| Section 2.5 and receipt | This commit; merge-pending |
| Merged candidate | Merge-pending |

## Contract Pins

| Boundary | Candidate value |
| --- | --- |
| Segmented execution command line | `2.0.0`; legacy command lines remain read-compatible |
| Event-segment and finalization protocol | `2.0.0` |
| Capture manifest | `2.0.0` |
| Graph registry | `2.1.0`; only `run_event_segment` is newly enabled |
| Factory ontology / operational shapes | `1.2.0` / `1.2.0`; exact `1.0.0` and `1.1.0` pairs remain readable |
| Ontology canonical N-Quads SHA-256 | `631bd63fbe3e79f8b320aa5290062ab54d2c5cdfeb60185d00f94141a9bc62a5` |
| Ontology package SHA-256 | `d4d7568c264bdac5d879186966c08889920615018ee6bec8e815f5e3d839b2b2` |
| Memory guardrails | `1.1.0` |
| Data policy and enabled capture profile | `2.0.0`; `semantic_history` only |
| Segment bounds | 80 events, 80 segments, 800 additions plus 200 reserved closure additions, 8 target graphs, and 80 guards |
| System bounds | 1,000 command additions, 16 target graphs, 100 guards, and 262,144 payload bytes |
| Integration fixture | Real Phase 4 bootstrap/enrollment, serialized writer, and TripleStore dataset export/reopen path |
| Legacy compatibility | `RecordToolInvocation` remains on `1.6.0`/`1.8.0` only; legacy runs retain bounded-observable projection and are never rewritten |

## Accounting And Closure Evidence

Every new attempt atomically creates its capture manifest, segment zero, and
sequence-zero head. Every later event consumes the exact active head and
creates one deterministic immutable successor. Graph revision compare-and-swap
and the predecessor-successor guard make concurrent head consumption resolve
to one commit and one conflict; replay of the winning command resolves to its
existing receipt.

Segment closure checks the exact event, typed-event, resource, capture, and
open-effect sets; contiguous inclusive sequence bounds; immutable ordered
event and content digests; and carried or ambiguous effects. One atomic command
closes the current graph, appends its root to the run, and optionally creates
the successor graph. The persistence boundary permits lifecycle removals only
for exact `CloseEventSegment` and `FinalizeExecutionRun` `2.0.0` commands (and
the already-accepted legacy exceptions); ordinary maintenance removals remain
rejected.

The capture manifest names every expected opaque body identity and class.
Each body has one immutable capture shell with independent outcome,
representation, location, availability, retention, hold, classification,
purpose, reconstruction, provider-availability, allowed-use, limitation, and
receipt fields. Closure rejects missing, duplicate, foreign, or unlisted
captures. A digest-only representation is never promoted to replayable
content, and forbidden exact content remains forbidden by data policy.

Finalization recomputes the ordered segment chain from sequence zero through
the terminal event, all segment/content roots, the capture completeness root,
and every resolved, cancelled, or explicit ambiguous effect. Unsegmented
events and late writes fail closed. Provider unavailability, capture failure,
cancellation ambiguity, and bounded termination remain explicit incomplete
outcomes rather than complete history claims.

## Restart, Projection, And Compatibility Evidence

Recovery derives the sole open segment, active head, next sequence, carried
and newly opened effects, and recorded identities from persisted graph state.
The real-store matrix restarts the writer before an event, after a start, on
both sides of atomic segment closure, and before finalization. Closed segments
never return a resumable head, and final run closure cannot reopen history.

The complete fixture spans two segments and records model start/outcome,
message capture, transition, normalized proposal, artifact, tool
start/outcome, sandbox, provider, cancellation, retry, and terminal events.
The incomplete fixture proves concurrent predecessor conflict, idempotent
replay, unsegmented-event rejection, explicit ambiguous effects, and honest
incomplete projection. Existing Phase 8 and harness execution suites retain
their legacy behavior.

Ontology `1.2.0` additively composes the immutable `1.1.0` memory vocabulary
and pins the new event, head, root, capture, and finalization terms and shapes.
Startup accepts only exact known ontology/shape pairs and verifies every source,
the package digest, and canonical RDF digest before loading. Prior release
packages are unchanged.

## Verification Record

| Command or gate | Result |
| --- | --- |
| Complete and incomplete real TripleStore Phase 2 matrix | 2 tests, 0 failures |
| Ontology release, startup, topology, Phase 2, legacy Phase 8, harness, and semantic round-trip compatibility matrix | Pass after updating the MG2 enablement assertion |
| `mix compile --warnings-as-errors` | Pass |
| `mix architecture.check` | Pass |
| `mix precommit` | 647 tests, 0 failures; pass |
| Pull request clean-checkout CI | Merge-pending |

## Known Limitations

- Phase 2 provides total accounting for expected observable events and bodies;
  it does not claim storage of provider-private state, hidden reasoning,
  secret values, or events unavailable at their source.
- Reviewed history queries and retrieval indexes remain disabled until MG3.
  Experience, content-lifecycle, episode-content, broader capture profiles,
  and the content gateway remain disabled until their owning later gates.
- The only enabled content profile is semantic history. There is no exact
  encrypted content vault, queryable cold archive, or external content
  gateway in this candidate.
- Legacy runs remain readable only at their stored bounded-observable
  completeness. Missing historical provider events or omitted bodies cannot
  be reconstructed or relabeled.

## Gate MG2

MG2 remains merge-pending. It becomes accepted only after clean-checkout CI
passes, the pull request merges, and the full merge commit and merge date are
pinned in this receipt and the Phase 2 plan. Phase 3 is authorized only from
that exact merged baseline.

MG2 reopens if any expected event can disappear; if one predecessor can gain
multiple accepted successors; if a closed segment or finalized run can mutate
or reopen; if event order, segment roots, content roots, or the run root cannot
be independently recomputed; if an unsegmented, duplicated, omitted, or late
event can pass finalization; if any expected body lacks exactly one explicit
capture state; if a digest is reported as replayable content; if an unresolved
effect or provider/capture/cancellation ambiguity is promoted to complete; if
a protocol bound can make closure impossible; if legacy history is rewritten
or overclaimed; if an unknown or mismatched ontology/shape pair is accepted;
or if any MG3-MG6 writer, query, profile, index, or content gateway becomes
reachable before its owning gate. These reopening conditions remain in force
regardless of checklist state.
