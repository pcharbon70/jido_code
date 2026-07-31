# Backend Compatibility Contract

## Purpose And Status

This document is the executable compatibility record for Phase 1 Section 2.
It defines the only backend/toolchain combination accepted for production
adapter work in Phase 2. The candidate is **accepted with constraints**. Those
constraints are part of the contract, not optional implementation advice.

Evidence was collected on 2026-07-31 from
`test/jido_code/knowledge/triple_store_compatibility_test.exs`, direct source
inspection at the pinned revisions, dependency audits, clean native builds,
and bounded local timing probes.

## Accepted Dependency Set

| Component | Accepted version | Pinning rule |
|---|---|---|
| TripleStore | Git commit `6dc1b6d985f4805f9856858e0c0047b9f2d5ad7f` | Exact Git `ref`; no released Hex package exists |
| RDF | 2.1.0 | Direct `~> 2.1` dependency and lockfile |
| Decimal | 3.1.1 | Direct `~> 3.1` override of RDF 2.1's stale 2.x constraint |
| erlang-rocksdb | 1.9.0 | Transitive lock through TripleStore |
| bundled RocksDB | 9.10.0 | Source bundled by erlang-rocksdb 1.9.0 |
| Rustler | 0.38.0 | Transitive lock through TripleStore |
| SPARQL parser NIF | TripleStore commit above | Cargo lock embedded in the pinned Git dependency |

The Elixir constraint moves from `~> 1.15` to `~> 1.18` because the selected
TripleStore revision requires Elixir 1.18. Rollback means reverting all graph
dependencies and graph-backed code together; the application must not attempt
to run the pinned backend on Elixir 1.15-1.17.

RDF 3 is not accepted because TripleStore currently constrains RDF to 2.x and
has only been exercised against the RDF 2 term and parser behavior. Decimal 3
is an intentional override: RDF's used API remains compatible, the suite
exercises ordinary and over-limit decimal parsing, and Decimal 3 bounds the
exponent-allocation issue described by CVE-2026-32686.

## Toolchain Matrix

| Tool | Canonical version | Supported scope |
|---|---|---|
| Erlang/OTP | 27.3 | Local development and Linux CI |
| Elixir | 1.18.4 compiled for OTP 27 | Local development and Linux CI |
| Rust/Cargo | 1.92.0 | Builds the SPARQL parser NIF |
| Node.js/npm | 24.3.0 / 11.4.2 | Existing Vite asset pipeline |
| CMake | 3.28.3 or Ubuntu 24.04 equivalent | Builds erlang-rocksdb |
| C/C++ compiler | GCC/G++ 13.3 or Ubuntu 24.04 equivalent | C++ NIF build |
| Operating system | Ubuntu 24.04 x86_64 | Canonical CI environment |
| Verified workstation | Linux Mint 22.1, Ubuntu 24.04 base, kernel 6.8, x86_64 | Development evidence only |

`.tool-versions`, `rust-toolchain.toml`, and `.github/workflows/ci.yml` are the
machine-readable pins. Other operating systems, OTP releases, architectures,
and RocksDB builds are unverified rather than implicitly supported.

## Native Build Contract

Install Git, CMake, `pkg-config`, and the Ubuntu `build-essential` toolchain
before running `mix deps.get` or `mix compile`. Rust must be available through
`rustup` or an equivalent toolchain installation. The canonical build uses
erlang-rocksdb's bundled RocksDB 9.10.0 with bundled compression libraries;
system RocksDB development packages are neither required nor accepted in CI.

CI sets:

```sh
ERLANG_ROCKSDB_OPTS=-DCMAKE_POLICY_VERSION_MINIMUM=3.5
```

This only acknowledges the minimum policy used by the dependency's older
CMake files. It does not select system RocksDB. `WITH_SYSTEM_ROCKSDB=ON` and
shared-filesystem database paths are outside the accepted matrix.

Typical failures are interpreted as follows:

| Failure | Required response |
|---|---|
| CMake or C++ compiler missing | Stop with the native compiler output; install the declared packages |
| Rust/Cargo missing or wrong version | Stop before application startup; install Rust 1.92.0 |
| RocksDB or parser NIF cannot load | Mark the knowledge substrate unavailable; never fall back to another store |
| TripleStore Git revision unavailable | Fail dependency resolution; do not float to a branch head |
| Schema mismatch | Refuse to open or mutate the path |

## Security, License, And Persistence Review

The accepted lock passes `mix hex.audit`; an OSV query of every locked Hex
package reports no affected version after upgrading the existing Phoenix HTTP
stack and overriding Decimal. The root npm production audit reports zero known
vulnerabilities. TripleStore's repository security-advisory endpoint reported
no published advisories at review time, although Dependabot alerts are not
enabled there; the exact revision and local audits therefore remain required.

The parser Cargo lock contains 34 crates. RustSec advisory RUSTSEC-2026-0097
names `rand` 0.8.5 only when its `log` feature is enabled. `cargo tree -e
features -i rand` proves that feature is not enabled by the pinned parser, so
the vulnerable behavior is not reachable. Updating the upstream lock to
`rand >= 0.8.6` remains recommended and must be re-evaluated when the
TripleStore ref changes.

Direct and graph-specific transitive libraries use MIT or Apache-2.0 licenses:
TripleStore, erlang-rocksdb, Flow, GenStage, Decimal, JCS, and Uniq are
Apache-2.0; RDF, Rustler, and ProtocolEx are MIT. The dependency tree adds no
second persistence engine. RocksDB is the sole durable backend.

Review references:

- [EEF CVE-2026-32686](https://cna.erlef.org/cves/CVE-2026-32686.html)
- [RustSec RUSTSEC-2026-0097](https://rustsec.org/advisories/RUSTSEC-2026-0097.html)
- [Pinned TripleStore revision](https://github.com/pcharbon70/triple_store/tree/6dc1b6d985f4805f9856858e0c0047b9f2d5ad7f)

## Capability Matrix

| Capability | Result | Accepted production path |
|---|---|---|
| Quad-schema open/close/reopen | Pass | One supervised owner opens with `schema: :quad` |
| Multiple named graphs with empty default graph | Pass | `TripleStore.Loader.load_trig_string/4` or semantic write adapter |
| Bounded `ASK`, `SELECT`, `CONSTRUCT` | Pass with constraint | Reviewed query catalog with fixed graph/predicate bounds |
| Atomic multi-graph write | Pass with constraint | One ground `INSERT DATA` operation containing data and receipt, at most 10,000 quads |
| Invalid-update rollback | Pass | Parse and authorize before the single RocksDB write batch |
| Durable synchronous writes | Pass | `sync: true`; no bulk mode for accepted commands |
| OWL 2 RL materialization | Pass with adapter | TripleStore rules plus in-memory semi-naive kernel; persist only derived delta |
| Asserted/derived graph separation | Pass | Separate named graphs, never overwrite asserted facts |
| N-Quads and TriG export | Pass | Export dataset and compare RDF dataset semantics |
| Backup/restore | Pass with adapter | Flush dictionary counter, create RocksDB checkpoint, restore/open explicitly as quad |
| Dictionary identity after restore | Pass | Checkpoint preserves term IDs across restore and reopen |
| Concurrent bounded reads | Pass | Shared owner handle, bounded query catalog |
| Second writer/open handle | Rejected as expected | Filesystem lock enforces one open store path |

### Excluded Convenience APIs

The pinned revision has defects that the Phase 2 adapter must isolate:

1. Fully variable quad queries can crash binding conversion. Queries such as
   `GRAPH ?g { ?s ?p ?o }` are prohibited. Every production query is named,
   parameterized, bounded, and result-normalized; raw UI SPARQL is prohibited.
2. `TripleStore.load_string/4` did not preserve named graphs for N-Quads/TriG
   in the spike. Use the format-specific `TripleStore.Loader` functions.
3. Graph-scoped public materialization passes rule names where rule structs are
   required and later mixes RDF terms with dictionary IDs. Use the tested
   reasoning kernel path and persist a computed derived delta.
4. Public `TripleStore.backup/2`, `verify_backup/1`, and `restore/3` reopen quad
   data using triple-schema defaults and the backup copy is not a live RocksDB
   checkpoint. Production backup must be wrapped by the sole owner around the
   checkpoint contract. Direct `:rocksdb` access in the spike is test-only
   evidence until that wrapper exists.
5. `SELECT` bindings are not normalized consistently: a graph binding can be
   an RDF term while a subject is an internal parser tuple. Query adapters must
   normalize results before they leave `JidoCode.Knowledge`.
6. A SPARQL request containing multiple update operations is executed
   sequentially and is not one atomic unit. A semantic command must compile to
   exactly one ground `INSERT DATA` batch when atomicity is required.

These findings do not authorize application code to call lower-level APIs.
They define what the future knowledge adapter must own and test.

## Atomicity And Durability

An accepted semantic command writes its domain assertions, provenance,
decision/control changes, and immutable command receipt in one ground
multi-graph `INSERT DATA`. TripleStore converts that operation to one
synchronous RocksDB `WriteBatch`; either all indexed quads become visible or
none do. No separate commit-marker graph is required.

The receipt is still mandatory. If the caller dies or loses the response after
the batch commits, retry logic must query the deterministic command IRI and
return the recorded outcome rather than executing a second command. An update
that requires more than one SPARQL operation or exceeds 10,000 quads must be
redesigned or handled by a later explicitly journaled protocol.

Development, test, and production all use `sync: true` for accepted commands.
`bulk_mode: true` is allowed only for explicitly rebuildable imports and only
when the final synchronous WAL flush succeeds. It is never a durability
shortcut for control, workflow, evidence, or receipt state.

## Runtime And Deployment Constraints

- Exactly one BEAM owner process may hold the writable store handle and path.
- Concurrent callers submit writes through that owner; they do not open the
  path themselves. Bounded reads may execute concurrently against its handle.
- The database must be on a local filesystem owned by that runtime.
- Two BEAM nodes, two OS processes, shared writable volumes, NFS, and
  active-active writers against one path are unsupported.
- Graceful shutdown closes the store before path cleanup or replacement.
- A lock/open failure is a health failure, not a signal to delete lock files.
- Backup creation, restore, ontology verification, and schema verification are
  exclusive maintenance operations coordinated by the owner.

The future health contract must fail closed:

| Condition | Health/operation outcome |
|---|---|
| Store not opened or NIF unavailable | `unavailable`; no durable command accepted |
| Path locked by another owner | `locked`; bounded retry or operator action |
| Triple/quad or ontology incompatibility | `incompatible`; no mutation |
| Corruption/checksum failure | `corrupt`; stop writes and restore from verified checkpoint |
| Permission or disk-full write failure | `persistence_failure`; outcome resolved by receipt lookup before retry |
| Invalid RDF/SPARQL | `invalid_input`; no mutation and no raw query echoed to telemetry |

## Baseline Timing Evidence

The following medians are diagnostic baselines, not service-level objectives.
They came from five local runs against a 100-quad dataset with synchronous
writes on the verified Linux workstation.

| Operation | Median |
|---|---:|
| Open quad store | 148.419 ms |
| Write 100 quads | 19.970 ms |
| Query 100 quads | 4.416 ms |
| RocksDB checkpoint | 77.902 ms |
| Restore copy plus open | 36.832 ms |

## Reproduction

```sh
mix deps.get
mix compile --warnings-as-errors
mix test test/jido_code/knowledge/triple_store_compatibility_test.exs
mix hex.audit
npm audit --omit=dev
```

Any dependency, NIF, RocksDB, Elixir/OTP, toolchain, or supported-platform
change invalidates this record until the suite and security review are rerun.
