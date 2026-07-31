# JidoCode

JidoCode is a Phoenix LiveView server project.

The root route (`/`) renders `JidoCodeWeb.HomeLive`, a small server console that
keeps state over a LiveView socket and verifies that server-rendered events are
working.

## Architecture

The managed repository factory uses an embedded knowledge graph as its only
application-owned durable source of truth. See the
[architecture index](docs/architecture/README.md),
[accepted ADRs](docs/adr/README.md), and
[implementation plan](.planning/README.md).

## Requirements

- Elixir 1.15 or newer
- Erlang/OTP 26 or newer

## Setup

Install dependencies and build assets:

```sh
mix setup
```

## Run

Start the development server:

```sh
mix phx.server
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
