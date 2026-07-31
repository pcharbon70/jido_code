# ADR 0002: TripleStore Backend Contract

- Status: Accepted
- Date: 2026-07-31
- Owners: JidoCode maintainers
- Decision scope: Embedded graph backend, toolchain, and deployment topology
- Depends on: [ADR 0001](./0001-graph-only-source-of-truth.md)
- Evidence: [Backend compatibility contract](../architecture/backend-compatibility.md)

## Context

ADR 0001 requires one embedded quad dataset as the application-owned source of
truth. The architecture depends on named graphs, bounded SPARQL reads, atomic
multi-graph writes, explicit asserted/derived separation, export, backup,
restore, and stable dictionary identity. These behaviors cannot be inferred
from a library README or inherited from the older application.

The tested TripleStore candidate supplies the required storage kernel, but its
public convenience surface contains defects and atomicity limits that must not
leak into product modules.

## Decision

JidoCode accepts TripleStore commit
`6dc1b6d985f4805f9856858e0c0047b9f2d5ad7f`, RDF 2.1, Decimal 3.1, and
erlang-rocksdb 1.9 with bundled RocksDB 9.10 on the exact toolchain defined in
the compatibility contract.

Only `JidoCode.Knowledge` may own the store handle and adapt lower-level
TripleStore APIs. Production code must obey these rules:

1. Open exactly one local store path with `schema: :quad` under one supervised
   owner. No active-active or shared-filesystem writers are supported.
2. Expose semantic commands and reviewed bounded query functions. Do not
   expose raw store handles, arbitrary SPARQL, or lower-level RocksDB APIs.
3. Compile each atomic command to one ground `INSERT DATA` operation that
   includes its immutable receipt in the same synchronous RocksDB batch.
4. Normalize query bindings before returning projections.
5. Run OWL 2 RL through the tested in-memory kernel and persist only the
   derived delta into explicitly derived named graphs.
6. Perform backup through an owner-coordinated RocksDB checkpoint after
   dictionary counter flush, and restore with explicit quad-schema checks.
7. Fail closed on unavailable, locked, incompatible, corrupt, permission,
   disk-full, or NIF failures. Never substitute another persistence engine.

The excluded convenience APIs and exact operational limits in the backend
compatibility contract are binding.

## Consequences

The selected revision is sufficient to begin a production knowledge adapter,
but it is not accepted as a general-purpose API surface. Phase 2 must centralize
the workarounds and can replace them when upstream fixes are pinned and the
compatibility suite is rerun.

All accepted writes use `sync: true`. Bulk loading is reserved for rebuildable
imports with a successful final WAL flush. The deterministic command receipt
resolves an unknown caller outcome after a crash; no separate commit marker is
needed for a single accepted batch.

Changing TripleStore, RDF, Decimal, erlang-rocksdb, RocksDB, Elixir/OTP, Rust,
the supported OS, or the deployment topology requires a superseding evidence
record and rerunning the full compatibility suite.

## Alternatives Rejected

- **Trust the TripleStore public API as-is:** the spike found reproducible
  defects in named-graph loading, unbounded query conversion, graph-scoped
  reasoning, and quad backup/restore.
- **Use multiple SPARQL operations as one command:** the backend executes them
  sequentially, so they do not provide command-level atomicity.
- **Add a relational store for receipts or workflow state:** this violates ADR
  0001 and creates an ambiguous recovery boundary.
- **Use system RocksDB by default:** it adds an untested ABI/version dimension;
  the bundled 9.10 source is the canonical build.
