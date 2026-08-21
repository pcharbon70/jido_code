# Total Memory Data Policy

## Policy And Profile Posture

`JidoCode.Security.DataPolicy` `2.0.0` is the shared closed contract for durable
graph placement, representation, product/operational output, approved export,
provider egress, Personal data, and sensitive commitments.

| Profile | Runtime state | Posture | Activation requirement |
| --- | --- | --- | --- |
| `semantic_history` | Enabled | semantic envelopes, normalized facts, digests, selected messages/results, governed artifacts; no exact assembled prompt, raw provider response, or raw tool body | MG1 accepted contract |
| `diagnostic_capture` | Disabled | deterministically redacted prompt/response/tool representations for bounded diagnostics | superseding privacy contract and its evidence |
| `project_total_history` | Disabled | maximum policy-authorized observable project content | accepted diagnostic evaluation plus explicit project contract |
| `incident_hold` | Disabled | case-scoped frozen eligibility | dual approval and periodic hold review |

Listing a disabled profile is not authorization. The graph-native
`episode_content` family is enabled only for already-encrypted, independently
authorized content through command version `2.3.0`; release still requires a
purpose-bound consumed permit. This does not enable either broader capture
profile.

Secret values, reusable credentials, provider-private state, and hidden
reasoning remain forbidden in every profile. Personal data is confined to the
security-audit contract, has no normal export sink, and has no provider-egress
posture.

## Orthogonal Content State

Each expected body records six independent dimensions:

1. capture outcome: captured, omitted, unavailable, redacted, failed, expired,
   or erased;
2. representation: semantic metadata, normalized/redacted/exact text, digest,
   external reference, ciphertext/commitment, keyed commitment, legacy
   commitment, or none;
3. storage location: one accepted graph family, governed artifact, external
   provider, or omitted;
4. availability: available, cold, pending, unavailable, or failed;
5. retention/erasure: active, archive-eligible, archived, expired,
   erasure-pending, cryptographically erased, physically deleted, or externally
   unverifiable; and
6. hold: not held, held, or release-pending.

No value in one dimension implies a value in another. In particular,
`captured` does not mean available, retained, exact, or recallable, and `erased`
must name the achieved erasure class rather than hide an unverifiable external
copy.

The MG2 semantic-history path now admits normalized or commitment-only tool
accounting in `run_event_segment`; it still rejects exact raw tool bodies.
Prompt-representation shells may record omission or a digest in the segment,
but the exact assembled prompt remains forbidden.

## Archive And Removal

`archive` means queryable cold retention. It is not deletion from the active
dataset, expiry, cryptographic erasure, physical deletion, or an external
deletion claim. JidoCode has no accepted cold tier in MG1, so the retention
planner fails with `retention_archive_unavailable` when an archive-eligible
resource exists. It never removes those quads or reports them archived.

`remove` is an explicit non-erasure deletion action for disposable data.
`erase` is an explicit legal/policy request subject to reachability and hold
checks. Retention plans and receipts report archive, remove, and erase counts
separately. Queryable cold storage and content-level lifecycle transitions are
owned by MG6.

Semantic capture manifests and content-capture shells use the longer
`semantic_shell` class. Exact payload uses the shorter `exact_payload` class,
and `episode_content` availability is now governed by its append-only MG6
lifecycle. Closed legacy run graphs are not selectively mutated.

## Sensitive Commitments

New sensitive exact content is encrypted before semantic commit. A new
ciphertext commitment is accepted only when encryption already occurred. A
keyed commitment is accepted only for the explicit `equality_verification`
purpose with its key outside the graph. New legacy unkeyed commitments and all
secret-value commitments are rejected.

Existing plaintext-derived audit digests remain immutable legacy limitations;
their presence is not evidence that source content can be recovered or erased.
