# Phase 2 Durable Substrate Receipt

## Status

This receipt records the Phase 2 pull-request candidate verified locally on
2026-07-31. Store ownership, synchronous atomic commits, immutable receipts,
dataset and graph revisions, checkpoint backup, RDF export, verified restore,
rollback, integrity diagnostics, health, telemetry, and operator commands are
implemented and pass the repository gates.

G1 remains pending until this pull request passes clean-checkout CI, is merged,
and its immutable merge commit is pinned here. Phase 3 is not authorized by a
branch-head receipt.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Phase baseline and merged G0 | `e3d2b2cdd26cee36fdfc464f2d75154e8206ac53` |
| Section 2.1 | `815d642` - implement authoritative store lifecycle |
| Section 2.2 | `0012d14` - implement atomic graph writes and revisions |
| Section 2.3 | `b2d33a8` - implement graph store backup, restore, and integrity |
| Section 2.4 | `e89cd58` - harden knowledge store operations and telemetry |
| Section 2.5 | This receipt and its integration tests; exact commit recorded by Git history |
| Merged candidate | Pending pull-request merge |

## Accepted Substrate Contract

- Exactly one supervised `StoreServer` owns a quad-schema `TripleStore`; raw
  handles never leave `JidoCode.Knowledge`.
- Backend adapter and dictionary processes are linked to the owner. A hard
  owner death terminates its backend lifetime before supervision reopens the
  selected path.
- `Writer` is the ordinary persistent mutation ingress. A semantic batch and
  its graph-native commit/revision receipt use one ground `INSERT DATA`, one
  synchronous RocksDB write batch, and a 10,000-quad limit.
- Expected dataset and graph revisions provide optimistic concurrency. A lost
  response is resolved by retained commit identity, never assumed absent.
- The default graph is empty. Substrate metadata, revisions, commit receipts,
  and restore activity are RDF in the system named graph.
- Checkpoints flush dictionary counters and RocksDB synchronously. Backup and
  complete N-Quads/TriG exports use a serialized owner boundary, private
  configured destinations, deterministic payload checksums, and bounded
  manifests.
- Restore validates an exact confirmed artifact, opens a separate candidate,
  verifies metadata and integrity, records restore provenance in the graph,
  atomically selects the candidate, reopens it, and rolls back to the preserved
  prior selection on failure.
- Integrity detection checks backend and dictionary readability, metadata,
  lineage, revisions, named-graph metadata, an empty default graph, and bounded
  committed-receipt closure. Detection has no repair side effect.
- `ACTIVE` and backup manifests are operational filesystem metadata. They
  select and verify graph-store artifacts but contain no product facts and are
  never queried as application truth.

## Accepted Pins

The Phase 1 dependency and toolchain contract remains unchanged:

| Component | Accepted pin |
| --- | --- |
| TripleStore | Git commit `6dc1b6d985f4805f9856858e0c0047b9f2d5ad7f` |
| TripleStore physical schema | Quad |
| JidoCode store schema | 1 |
| TripleStore backend schema metadata | 2 |
| Durability | Synchronous |
| RDF | 2.1.0 |
| Decimal | 3.1.1 direct override |
| erlang-rocksdb / bundled RocksDB | 1.9.0 / 9.10.0 |
| Rustler | 0.38.0 |
| Erlang/OTP and Elixir | 27.3 / 1.18.4 for OTP 27 |
| Rust | 1.92.0 |
| Node.js / npm | 24.3.0 / 11.4.2 |
| CMake / GCC | 3.28.3 / 13.3.0 |

Machine-readable dependency pins remain in `mix.exs`, `mix.lock`,
`.tool-versions`, and `rust-toolchain.toml`.

## Fixture Identity

| Evidence fixture | SHA-256 |
| --- | --- |
| Named-graph compatibility TriG | `e579a91e4b5dbb7c483bc664510d34580418ae7aafac2e17832507928be0e0f9` |
| External BEAM crash writer | `9c92f2562d7b869ac39333927a5a33532fcec9e6990b0152e2a39e8a0d9ca6a4` |
| Supervised restart native gate | `6f14169e541a4448f05eaca8737ca90d888567134e3b7796a9693d28fe502b52` |
| Sorted architecture and graph fixture manifest | `b481cdf9b800f451bbac0f70ecaaa8df19ec1cbf8dd9268e06bc0538efdad1b6` |

The crash writer is an isolated test harness. It does not provide an alternate
persistence path and uses the same `StoreServer`, `Writer`, and graph-native
receipt contract as the application.

## Executable Evidence

The suite proves:

- empty-store bootstrap, graceful close, reopen, unchanged lineage/revisions,
  lock contention, invalid paths, permission failure, missing native support,
  incompatible physical/schema metadata, and nonempty unmanaged-store refusal;
- one winner for revision races, deterministic stale receipts, serialized
  queue deadlines, response-loss recovery, replay idempotency, and rejection of
  partial receipts and unmanaged graph revisions;
- supervised `StoreServer` `:kill` during queued work, non-ready replacement
  verification, backend lifetime cleanup, reopen, and no fabricated receipt;
- external BEAM `SIGKILL` before commit and after acknowledged commit, followed
  by absent-outcome or durable-receipt recovery respectively;
- private checkpoint/export artifacts, language/datatype preservation,
  checksums, retention listing without deletion, confirmed restore, reopen,
  graph-native restore activity, and continued writes;
- checksum rejection before restore and automatic rollback after a
  checksum-valid candidate fails semantic integrity;
- canonical asserted named-graph equality before backup and after restore;
- stable, bounded integrity issues for default-graph and committed-receipt
  corruption without mutation or repair; and
- fixed telemetry spans for open, verify, read, write, commit, backup, restore,
  export, integrity, and maintenance with numeric-only measurements and no
  graph, artifact, path, query, credential, or content labels.

## Verification Record

| Command or gate | Result |
| --- | --- |
| `mix precommit` | Architecture checks passed; 79 tests, 0 failures |
| Phase 2 cross-boundary integration file | 4 tests, 0 failures |
| `mix hex.audit` | No retired packages found |
| `npm audit --omit=dev` | 0 vulnerabilities |
| `MIX_ENV=prod mix assets.build` with a verification-only runtime key | Client and SSR Vite builds passed |
| Bounded operator task help and health execution | Passed; redacted JSON status returned |

`mix precommit` includes application compilation with warnings as errors,
architecture enforcement, unused dependency lock checking, formatting, and the
complete ExUnit suite. GitHub CI must repeat the clean-checkout gates before
merge.

## Operational Limits

- One local BEAM may own a store path. Active-active nodes, NFS, and shared
  writable store volumes remain unsupported.
- Phase 2 lists retention candidates but never deletes backups.
- Integrity checks inspect at most 1,000 committed receipts online; exceeding
  that bound returns an explicit issue requiring a future offline check.
- No destructive repair or schema migration command is authorized yet.
- Startup verifies backend and required metadata. Full integrity is explicit,
  runs during restore, and is reflected in health only after an in-process
  check.

## Gate G1

The local G1 candidate satisfies the implementation and recovery criteria. No
test or architecture scan found a mutation bypass, visible partial commit,
fallback persistence path, raw handle leak, or restore reproduction failure.

G1 is nevertheless **pending**, not complete. Completion requires clean CI,
pull-request merge, and replacement of the pending provenance entry with the
immutable merge commit. Until then, Phase 3 remains blocked.
