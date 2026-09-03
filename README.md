# JidoCode

JidoCode is a Phoenix server project with a graph-native managed repository
factory.

The root route (`/`) renders the graph-backed managed repository factory
workbench. Its currently deployed LiveView/LiveVue surface is a compatibility
runtime with tracked removal gates. New product work targets explicit Phoenix
controllers, server-rendered HEEx, native links/forms, and qualified Datastar
enhancement while preserving server-owned identity, authorization, semantic
commands, and receipts.

## Architecture

The managed repository factory uses an embedded knowledge graph as its only
application-owned durable source of truth. See the
[architecture index](docs/architecture/README.md),
[accepted ADRs](docs/adr/README.md), and
[implementation plan](docs/planning/graph-native-managed-repository-factory/README.md).
Contributor rules for the target browser stack are in the
[hypermedia product contribution contract](docs/contributing/hypermedia-product-work.md).

## Requirements

- Elixir 1.18 or newer
- Erlang/OTP 27 or newer
- Rust 1.92 or newer
- CMake, a C/C++ build toolchain, Git, and `pkg-config`; the accepted build uses
  the bundled RocksDB source, so system RocksDB libraries are not required

See the [backend compatibility record](docs/architecture/backend-compatibility.md)
for exact versions and native-build troubleshooting.

## Setup

Install dependencies and build assets:

```sh
mix setup
```

## Run

Start the development server:

```sh
JIDO_CODE_OPERATOR_TOKEN='replace-with-a-long-random-value' mix phx.server
```

If port 4000 is already in use:

```sh
PORT=4001 mix phx.server
```

Then open <http://localhost:4000> or the port you selected.

## Verify

Run the test suite and precommit checks:

```sh
mix test
mix precommit
```

Operational workflows are documented in the
[operator handbook](docs/operations/operator-handbook.md). Exact release gates
are available through `mix jido_code.release verify|preflight|audit`; initialize
a pristine dataset only with
`mix jido_code.bootstrap --confirm INITIALIZE`.
