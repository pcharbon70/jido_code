# Total Memory Content Contract

## Status And Boundary

Memory contract `2.0.0` defines complete accounting of eligible observable
events plus selective governed retention. It does not promise that every byte
is observed or retained. Secret values, provider-private state, and hidden
chain-of-thought are outside the observable-memory claim in every profile.
Unavailable provider events remain unavailable and must never be synthesized.

This contract grants no new capture, query, content-access, or write
capability. The only eligible runtime profile is `semantic_history`; the
profile registry and its disabled alternatives are established by the shared
data-policy section of this phase.

## Current Durable Content Inventory

| Content | Current durable reality | `semantic_history` posture | Required limitation |
| --- | --- | --- | --- |
| `Instruction.content` | A bounded instruction literal in a legacy `run_attempt` graph | Selected normalized instruction representation | It is not the exact assembled model prompt; system contract, selected sources, tools, serialization, and provider state are separate |
| Interaction message | Up to 4,096 bytes of normalized or `[REDACTED]` content in control or run graphs | Selected semantic message under actor, scope, and classification policy | Provider-internal turns and drafts are not a complete transcript |
| Model outcome | Status, usage, digest, reference, and bounded diagnostic in the run graph | Normalized result and digest | Raw provider response and private reasoning are not retained |
| Tool stdout/stderr | Legacy run graphs may contain up to 65,536 combined bytes plus digests after bounded secret checks | Normalized result, digests, references, and explicit body-capture state | Existing exact bodies are legacy evidence, not automatically recallable memory |
| Embedded artifact | Public/internal normalized text up to 32 KiB or an external digest-checked reference | Governed artifact | External availability is independently verified on every use |
| Command receipt commitment | Audit graph contains canonical assertion digests | Ciphertext commitment, or a protected keyed commitment only for an accepted equality purpose | A legacy unkeyed digest may remain plaintext-derived and is not an erasure claim |
| RDF export | External exact derivative of eligible dataset graphs | Separately purpose-bound export only | It inherits every source classification, retention, hold, and erasure obligation |
| Backup | External exact store derivative plus manifest and checksums | Restore-only derivative | Current backup deletion is not yet a physical- or cryptographic-erasure guarantee |

The executable inventory is
`JidoCode.Knowledge.Memory.Contract.content_inventory/0`. Unknown content
classes fail closed.

## Prompt And Output Decisions

An execution instruction is classified as a `prompt_representation`, not as an
exact assembled prompt. Under `semantic_history`, the exact assembled prompt is
omitted while its digest, capture outcome, context manifest, template/model/
policy revisions, and reconstruction limitations remain eligible. Merely
renaming an exact prompt as an instruction does not make it eligible.

Legacy bounded stdout/stderr remains honest historical evidence. New memory
protocol events under `semantic_history` retain normalized results, digests,
references, and the exact capture outcome; they do not retain raw tool bodies.
Diagnostic or project-total representations remain unauthorized until their
own superseding contracts and later gates pass.

## Complete Accounting

Every expected body identity has exactly one outcome from this closed set:

- `captured`
- `omitted`
- `unavailable`
- `redacted`
- `failed`
- `expired`
- `erased`

Omission is therefore recorded evidence, not absence of evidence. Capture
outcome does not imply representation, storage location, availability,
retention/erasure, or hold state. Those dimensions are orthogonal and are
ratified in the shared memory data-policy contract.

## Legacy Runs

All existing `1.x` `run_attempt` graphs retain their recorded protocol and
closed immutable bytes. They claim only a bounded observable subset, not total
event accounting or an exact transcript. Reconstruction is limited to stored
representations and explicit references. Closed history is never rewritten to
add capture outcomes, remove an old literal, or pretend an unavailable event
was observed.

New `2.0.0` segmented execution is active only in the MG2 candidate command
line. Legacy `1.x` commands cannot target event-segment graphs. The profile
still widens no exact-content access: semantic capture shells are eligible,
while diagnostic/project-total bodies and episode-content storage remain
disabled.

## Sensitive Commitments

No new exact sensitive graph literal may enter the memory protocol. Eligible
exact sensitive content must be encrypted before semantic commit so command
receipts commit to ciphertext. A keyed commitment is allowed only when an
accepted policy requires equality testing and protects the key outside the
graph. Secret values, low-entropy plaintext hashes, provider-private state,
and hidden reasoning remain forbidden.

Legacy plaintext-derived assertion digests are retained as immutable integrity
history with an explicit limitation. Removing their source literal does not
claim that the commitment is physically erased or resistant to dictionary
recovery.
