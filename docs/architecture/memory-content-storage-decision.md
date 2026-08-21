# Memory Exact-Content Storage Decision

## Decision

The Phase 6 candidate selects graph-native encrypted content. No application-
owned vault is authorized. `TripleStore` remains the sole application-owned
durable authority for content identity, immutable ciphertext chunks, access
permits, lifecycle, holds, erasure generations, and audit outcomes.

The decision is merge-pending with MG6. It becomes an accepted baseline only
after the Phase 6 implementation pull request passes clean-checkout CI, merges,
and its full merge commit is pinned in the phase receipt.

## Benchmark Basis

The signed decision uses the Phase 1 corpus digest
`6a63d96c7f60d84c8ca195a2b77c2f4afdce8301a7285402dccf9666b1aea13a`.
The reproducible candidate measurement covers capture, reviewed lifecycle
query, backup, restore, erasure, index rebuild, and storage growth. The
candidate ratios are:

| Measurement | Result | Mandatory maximum |
| --- | ---: | ---: |
| Capture latency | `1.50x` | `2.00x` |
| Query latency | `1.75x` | `2.00x` |
| Backup latency | `1.25x` | `1.50x` |
| Restore latency | `1.40x` | `1.50x` |
| Rebuild latency | `1.90x` | `2.00x` |
| Storage amplification | `3.50x` | `4.00x` |
| Integrity failures | `0` | `0` |
| Orphaned objects | `0` | `0` |
| Unerased objects | `0` | `0` |

Section 6.5 reruns these measurements through the accepted real graph path and
records the exact decision and metrics digests in the phase receipt.

## Consequences

- `content_lifecycle_writer`, `episode_content_writer`, and `content_gateway`
  are enabled through command/query protocol `2.3.0`.
- Ciphertext is complete and encrypted before its immutable graph-create
  command is constructed.
- The gateway consumes a single-use permit before decryption and release.
- `diagnostic_capture` and `project_total_history` remain disabled. Future
  activation requires its own accepted policy/profile and evidence decision.
- A failed or incomplete future mandatory benchmark reopens MG6 and yields
  `vault_adr_required`; it does not authorize a vault.
- Provider-owned governed artifacts may remain externally referenced when the
  provider owns both storage and authority. A JidoCode-controlled bucket is
  never classified as external authority.

## Rejected Vault Branch

No vault ADR exists because every mandatory graph-native threshold passed. A
future vault branch remains blocked unless a superseding ADR proves
inaccessible pending writes, graph activation ordering, immutable ciphertext
versions, orphan cleanup, backup consistency, gateway-only access,
graph-authoritative lifecycle, and complete classified erasure.
