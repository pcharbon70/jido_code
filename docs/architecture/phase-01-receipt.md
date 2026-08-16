# Phase 1 Architecture And Compatibility Receipt

## Status

This receipt records the Phase 1 candidate verified on 2026-07-31. The
architecture decisions, backend capability proof, guardrails, and integration
gates are accepted. Pull request 3 passed its clean-checkout CI run and was
merged as `e3d2b2cdd26cee36fdfc464f2d75154e8206ac53`. Phase 2 is authorized.

There is no unresolved source-of-truth exception, backend capability, native
prerequisite, dependency-direction question, or remaining G0 gate.

## Accepted Inputs

The accepted architectural authorities are:

- [ADR 0001: Graph-only source of truth](../adr/0001-graph-only-source-of-truth.md)
- [ADR 0002: TripleStore backend contract](../adr/0002-triple-store-backend-contract.md)
- [Module and plane boundaries](./module-boundaries.md)
- [Backend compatibility contract](./backend-compatibility.md)
- [Failure, health, and telemetry contract](./failure-health-and-telemetry.md)
- [Architecture guardrails](./architecture-guardrails.md)
- [Phase 1 implementation plan](../../.planning/phase-01-architecture-contract-compatibility-and-guardrails.md)

The [research proposal](../research/1-graph-native-managed-repository-factory.md)
remains design rationale, not a higher authority than the ADRs. This repository
has no `.spec` tree at this checkpoint; the ADRs, architecture contracts, and
tracked implementation plan are the repository-local specifications.

## Candidate Provenance

| Scope | Commit |
|---|---|
| Phase baseline | `54cda0fd34cc687f0c1be6322513a790d3a9c37e` |
| Section 1.1 | `e729eb1` - ratify graph-native architecture boundaries |
| Section 1.2 | `1cae9da` - prove TripleStore backend compatibility |
| Section 1.3 | `c9e3706` - enforce graph-native architecture guardrails |
| Section 1.4 | `f08826f` - complete Phase 1 integration gates |
| Merged candidate | `e3d2b2cdd26cee36fdfc464f2d75154e8206ac53` |

## Accepted Dependency And Toolchain Pins

| Component | Accepted pin |
|---|---|
| TripleStore | Git commit `6dc1b6d985f4805f9856858e0c0047b9f2d5ad7f` |
| RDF | 2.1.0 |
| Decimal | 3.1.1 direct override |
| erlang-rocksdb | 1.9.0 |
| bundled RocksDB | 9.10.0 |
| Rustler | 0.38.0 |
| Erlang/OTP | 27.3 |
| Elixir | 1.18.4 for OTP 27 |
| Rust/Cargo | 1.92.0 |
| Node.js/npm | 24.3.0 / 11.4.2 |
| CMake and C/C++ | 3.28.3 and GCC/G++ 13.3, or Ubuntu 24.04 equivalents |
| Canonical CI | Ubuntu 24.04 x86_64 |

Machine-readable pins live in `mix.exs`, `mix.lock`, `.tool-versions`,
`rust-toolchain.toml`, and `.github/workflows/ci.yml`. The native build requires
Git, CMake, `pkg-config`, a C/C++ build toolchain, and Rust. A clean
`MIX_DEPS_PATH` must remain beneath a Git worktree because erlang-rocksdb 1.9.0
runs an unconditional Git submodule pre-hook. The CI checkout layout satisfies
that upstream constraint.

The npm manifest links Phoenix, LiveView, LiveVue, SaladUI, and PhoenixVite
from `deps`. Run `mix deps.get` before `npm ci`, and regenerate
`package-lock.json` with the pinned npm whenever `mix.lock` changes one of
those packages. Their package metadata participates in npm's lock validation.

## Fixture Identity

| Fixture set | SHA-256 |
|---|---|
| Named-graph compatibility TriG | `e579a91e4b5dbb7c483bc664510d34580418ae7aafac2e17832507928be0e0f9` |
| Architecture fixture manifest | `0a409b54dcc9b8c787f198ef838524489ae40ba67345b9484a1abaee07d50d2c` |
| Permitted `phx:theme` browser preference source | `b5c950f5dfe08d10ad0eb9e72144a7440452d628f1ce330101341dc45a74eba2` |

The architecture manifest digest is the SHA-256 of the sorted per-file
`sha256sum` output for `test/fixtures/architecture`. Changing any fixture or
its repository-relative path requires updating this receipt after rerunning
the falsification suite. The graph fixture digest is also asserted at runtime.

## Capability And Failure Evidence

The executable suite proves:

- quad-schema open, close, and reopen with multiple named graphs and an empty
  default graph;
- bounded `ASK`, `SELECT`, and `CONSTRUCT`, plus one atomic multi-graph update;
- invalid-update rollback and all-or-none visibility after caller and database
  owner termination at pre-commit, committed, and graceful post-commit points;
- asserted and derived graph separation through the tested OWL 2 RL kernel;
- N-Quads/TriG export, RocksDB checkpoint restore, and dictionary identity;
- one writable path owner, expected second-open locking, and bounded concurrent
  reads;
- fail-closed handling for lock contention, incompatible schema, invalid RDF,
  invalid query/update SPARQL, and filesystem permission failure;
- public error and telemetry projections that omit backend reasons, paths, raw
  graph content, and unbounded labels; and
- rejection of alternate persistence, raw store access, reverse imports,
  store-handle leakage, record codecs, foreign-key-shaped models, and raw UI
  SPARQL without rejecting classified disposable filesystem effects.

## Atomicity Decision

An accepted semantic command compiles to exactly one ground `INSERT DATA`
operation containing both domain assertions and its immutable command receipt
across the required named graphs. The operation is limited to 10,000 quads and
uses `sync: true`. TripleStore applies it through one RocksDB `WriteBatch`, so
the change and receipt are visible together or not at all.

No separate commit-marker graph is required. If a caller loses the response
after commit, recovery queries the deterministic command IRI and returns the
recorded receipt before deciding whether any retry is allowed. Multiple SPARQL
update operations are not one accepted transaction and remain prohibited for
atomic semantic commands.

## Verification Record

The candidate passed the following local gates:

| Command or gate | Result |
|---|---|
| Clean `mix deps.get` and `mix compile --warnings-as-errors` with isolated in-worktree dependency/build paths | Pass; 1:56.05 elapsed, 465,188 KB peak RSS |
| `mix deps.get` followed by `npm ci` | Clean npm install passed with Mix-linked package metadata |
| Compatibility, crash-recovery, failure-mode, and guardrail integration files | 16 tests, 0 failures |
| `mix precommit` | Architecture checks passed; 39 tests, 0 failures |
| `mix hex.audit` | No retired packages found |
| `npm audit --omit=dev` | 0 vulnerabilities |
| `MIX_ENV=prod mix assets.build` with a CI-only runtime key | Client and SSR Vite bundles built |

The clean native build used:

```sh
MIX_ENV=test \
ERLANG_ROCKSDB_OPTS=-DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
MIX_DEPS_PATH="$PWD/tmp/jido-code-clean-build/deps" \
MIX_BUILD_PATH="$PWD/tmp/jido-code-clean-build/build" \
mix deps.get

MIX_ENV=test \
ERLANG_ROCKSDB_OPTS=-DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
MIX_DEPS_PATH="$PWD/tmp/jido-code-clean-build/deps" \
MIX_BUILD_PATH="$PWD/tmp/jido-code-clean-build/build" \
mix compile --warnings-as-errors
```

Third-party dependencies emit existing compiler warnings; application code
compiled with warnings treated as errors. GitHub CI repeats `mix precommit`,
both dependency audits, and the production asset build from a clean checkout.

## Gate G0

G0 is complete. Pull request 3 passed the required clean-checkout gates, was
merged, and its immutable merge commit is pinned above and in plan subtask
1.4.3.4. Phase 2 work is authorized from that baseline.
