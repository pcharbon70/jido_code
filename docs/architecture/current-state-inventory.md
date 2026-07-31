# Current-State Inventory

## Purpose

This inventory establishes the persistence and ownership baseline before the
knowledge substrate is introduced. It is evidence for Phase 1 Section 1 and is
not a proposal for future product behavior.

## Evidence Boundary

| Item | Recorded value |
|---|---|
| Repository | `pcharbon70/jido_code` |
| Starting commit | `54cda0fd34cc687f0c1be6322513a790d3a9c37e` |
| Commit subject | `Merge pull request #2 from pcharbon70/agent/graph-native-implementation-plan` |
| Recorded | 2026-07-31 |
| Application | Phoenix 1.8 LiveView application with LiveVue islands and Vite assets |

The inventory was produced from tracked source, `mix deps`, direct toolchain
commands, and repository-wide persistence-pattern scans. Generated dependency
and build directories were excluded from the source scan.

## Toolchain Baseline

| Tool | Project constraint | Verified environment |
|---|---|---|
| Elixir | `~> 1.15` at the starting commit | Elixir 1.18.4 |
| Erlang/OTP | README states OTP 26 or newer | OTP 27 / ERTS 15.2.3 |
| Rust | Not yet declared | `rustc` and Cargo 1.92.0 |
| Node.js | Not yet declared | 24.3.0 |
| npm | Not yet declared | 11.4.2 |
| Git | Not yet declared | 2.49.0 |
| Operating system | Linux development is implicit | Linux Mint 22.1, Ubuntu 24.04 base, x86_64, kernel 6.8 |
| System RocksDB | Not required by the current app | No `rocksdb.pc` was installed |

The graph candidate requires Elixir 1.18 and builds its Erlang RocksDB and Rust
NIF dependencies from source. Phase 1 Section 2 owns the toolchain ratchet and
native prerequisite decision; this inventory records the pre-candidate state.

## Runtime Topology

`JidoCode.Application` starts a `:one_for_one` supervisor with these children:

| Child | Current responsibility | State classification |
|---|---|---|
| `JidoCodeWeb.Telemetry` | Phoenix/VM telemetry poller and metrics definitions | Operational telemetry; not product truth |
| `TwMerge.Cache` | CSS class merge cache used by SaladUI | Disposable runtime cache |
| `DNSCluster` | Optional node discovery from runtime configuration | External/runtime topology |
| `Phoenix.PubSub` as `JidoCode.PubSub` | LiveView and application message delivery | Ephemeral notification transport |
| `JidoCodeWeb.Endpoint` | HTTP, WebSocket, LiveView, and static asset endpoint | Ephemeral presentation/runtime state |

There is no knowledge supervisor, repository, database owner, durable queue,
runtime worker pool, or application-owned cache in the starting tree.

## Route And Presentation Contract

The browser pipeline provides session fetching, LiveView flash, CSRF
protection, the root layout, and secure browser headers.

| Environment | Route | Owner | Contract |
|---|---|---|---|
| All | `GET /` via LiveView | `JidoCodeWeb.HomeLive` | Current product workbench root |
| Development only | `/dev/dashboard` | Phoenix LiveDashboard | Operational diagnostics, not a product route |

There is no product JSON API route. The unused `:api` pipeline and commented
example scope do not establish an API contract.

`HomeLive` currently owns these socket-local values:

- page title and connection status;
- process-local start timestamp and derived uptime;
- heartbeat count; and
- at most six recent demonstration events.

All are recreated on mount and disappear with the LiveView process. The
`HeartbeatStatusIsland` receives bounded copies and can emit only the semantic
`ping` and `reset` events. `ToolchainStatusIsland` receives a static bounded
projection. Vue component state, DOM state, LiveView assigns, and LiveView
session data are not durable product knowledge.

The root route, LiveView-owned shell, SaladUI server components, bounded
LiveVue islands, Vite client/SSR bundles, and light/dark/system theme contract
are repository-owned. No routes or record-shaped domain model are inherited
from the older `mikehostetler/jido_code` implementation.

## State-Holder Classification

| State holder | Classification | Durable authority |
|---|---|---|
| LiveView assigns and process mailbox | Ephemeral runtime state | None |
| LiveVue props and component state | Ephemeral browser interaction state | None |
| `Phoenix.PubSub` messages | Ephemeral notification state | None |
| `TwMerge.Cache` | Rebuildable runtime cache | None |
| Telemetry measurements and process logs | Operational diagnostics | None unless a bounded result is later adopted into the graph |
| Browser `localStorage["phx:theme"]` | Device-local presentation preference | Explicitly allowed, never domain or workflow truth |
| CSRF token and Phoenix session cookie | Security/session material | Framework-managed and not product knowledge |
| Environment variables and runtime secrets | Secret/configuration material | External authority; values must not enter the graph |
| Vite manifests, bundles, digests, `_build`, `deps`, and `node_modules` | Reproducible build artifacts | None |
| Future local Git clones and sandboxes | Disposable external-system working material | None |
| Source files and `mix.lock` | Version-controlled application/build definition | Git is the authority, not runtime product persistence |

## Filesystem And Build Outputs

The tracked source contains no product-state output path. `.gitignore` excludes
the following generated classes:

- `_build`, `deps`, `doc`, coverage output, crash dumps, and Mix archives;
- `assets/node_modules` and root `node_modules`;
- Vite assets, manifests, the SSR bundle, and Phoenix digest output under
  `priv/static`; and
- the repository-local `tmp` directory used for bounded test/runtime scratch
  material.

`JidoCodeWeb.FrontendAssets` checks for generated Vite manifests and falls back
to a static manifest description. This is build/runtime discovery, not a write
path. No application module currently calls `File.write`, opens a database, or
serializes a product snapshot.

## Dependencies And Aliases

The starting application has Phoenix, LiveView, LiveVue, SaladUI, Vite support,
Req, Swoosh, telemetry, Gettext, Jason, DNSCluster, and Bandit as direct
dependencies. Notable locked versions are:

| Dependency | Locked version |
|---|---|
| Phoenix | 1.8.8 |
| Phoenix LiveView | 1.1.32 |
| Phoenix Vite | 0.4.3 |
| LiveVue | 1.2.1 |
| SaladUI | 1.0.0-beta.3 |
| Req | 0.6.2 |
| Bandit | 1.12.0 |
| LazyHTML | 0.1.11 |

An optional Ecto capability appears in transitive package metadata for LiveVue
and LiveDashboard, but Ecto is not locked, started, configured, or used by this
application.

The Mix aliases are:

| Alias | Behavior |
|---|---|
| `mix setup` | Fetch dependencies, install npm packages, and build assets |
| `mix assets.setup` | Install npm packages through `PhoenixVite.Npm` |
| `mix assets.build` | Compile and produce Vite client and SSR bundles |
| `mix assets.deploy` | Build assets and run `phx.digest` |
| `mix precommit` | Compile with warnings as errors, unlock unused dependencies, format, and test |

There is no migration, database setup, seed, queue, or snapshot alias.

## Persistence Scan

The baseline scan covered `lib`, `assets`, `config`, `test`, `mix.exs`,
`package.json`, and `README.md` for Ecto repositories, Ash resources, DETS,
Mnesia, RocksDB, SQL databases, Redis, LevelDB, LMDB, browser databases, file
writes, snapshots, and queues.

Findings:

- no Ecto repository or schema exists;
- no Ash resource exists;
- no DETS or Mnesia table exists;
- no RocksDB or other database is opened;
- no JSON/RDF/product snapshot is written;
- no durable queue or event log exists;
- no application-owned product state is written to the filesystem; and
- the generated `ConnCase` documentation mentions PostgreSQL/SQL sandboxing,
  but no such dependency or setup exists.

The only persistence-like application behavior is the theme preference in
browser local storage. ADR 0001 accepts that value solely as device-local
presentation state.

## Baseline Conclusion

The starting repository is a minimal presentation/runtime shell with no
application-owned durable product state. Adding `TripleStore` therefore creates
the first and only durable application knowledge path; it does not migrate or
compete with an existing domain store.
