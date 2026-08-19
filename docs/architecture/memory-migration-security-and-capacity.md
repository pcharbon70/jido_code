# Total Memory Migration, Security, And Capacity Guardrails

## Compatibility And Activation

`JidoCode.Knowledge.Memory.Guardrails` `1.0.0` defines the inherited
preconditions for every later memory phase. The `1.x` run protocol remains
readable as immutable, bounded-observable evidence. It is never rewritten and
never relabeled as complete event accounting. The `2.0.0` segmented protocol
may activate only after every legacy attempt is closed in a terminal state or
is closed as an explicitly governed abandoned attempt. A terminal transition
is required in either case, and abandonment also requires its decision.

The ontology startup gate recognizes only exact `1.0.0/1.0.0` and
`1.1.0/1.1.0` ontology/shape pairs. This preserves legacy dual-read projections
without accepting mixed or unknown releases. New writes continue to use exact
command versions; read compatibility does not authorize migration or mutation.

## Authorization Before Retrieval

A first-stage candidate partition can be derived only from an allowed,
revisioned authorization decision. Its SHA-256 identity binds all of:

- authorization identity and revision;
- repository and tenant;
- actor scope;
- closed purpose;
- data-class ceiling;
- effective-time generation; and
- erasure generation.

Missing, denied, malformed, or unknown values fail as unauthorized. Later
lexical, graph, or dense candidate generators must consume this partition
result; accepting caller-selected fields or filtering a shared search result
after inspection is forbidden. Changing any generation produces a different
partition identity, so stale time or erasure indexes cannot silently remain
eligible.

## Capacity Profile

| Bound | Memory profile | Existing ceiling |
| --- | ---: | ---: |
| Segment quads | 7,500 | 10,000 snapshot quads |
| Attempt-root quads | 2,000 | 10,000 snapshot quads |
| Event resources per segment | 80 | protocol bound |
| Ordinary additions | 800 | 1,000 command additions |
| Reserved closure additions | 200 | included in the 1,000 total |
| Guards | 80 | 100 precommit guards |
| Target graphs | 8 | 16 command target graphs |
| Segments per attempt | 80 | protocol bound |
| Ciphertext chunk | 16,384 bytes | protocol bound |
| Chunks per command | 8 | 131,072 bytes before envelope overhead |
| Command payload | 196,608 bytes | 262,144 envelope bytes |

Closure headroom is not reusable ordinary capacity. Work that would exceed a
root, segment-count, or payload bound must stop safely and continue, when
policy permits, through a linked attempt rather than create an uncloseable run.

## Phase 6 Benchmark Decision

The pinned corpus contains 100 normalized 8 KiB prompt representations, 100
64 KiB tool logs, 100 128 KiB source artifacts, and 25 mixed 192 KiB attempt
objects. The executable corpus digest binds identifiers, media types, sizes,
counts, and classifications.

Graph-native encrypted content is accepted only when every mandatory result is
present: capture and query latency are at most `2.0x` their semantic-only
baseline, backup and restore are at most `1.5x`, rebuild is at most `2.0x`,
storage amplification is at most `4.0x` plaintext bytes, and integrity
failures, orphaned objects, and unerased objects are all zero. Any missing or
failed threshold yields `vault_adr_required`; it does not itself authorize a
vault. Exact content stays blocked until Phase 6 either accepts graph-native
storage or accepts and proves a superseding encrypted-vault ADR.

## Disabled Posture

The segmented writer is activated only by the MG2 candidate; history queries and retrieval
indexes until MG3; the experience writer until MG4; and diagnostic/project
capture, lifecycle/content writers, episode content, and the content gateway
until MG6. Listing an owning gate is not evidence that the gate has passed.
