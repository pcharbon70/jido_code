# Local hypermedia delivery (D4 candidate)

Qualification is in progress; this is not an accepted HUI4 release profile.
The candidate is `local-loopback-v1`: Linux Mint 22.1 or Ubuntu 24.04 x86_64, one BEAM owning
local RocksDB and identity files, and a browser directly using HTTP/1.1.
Use the pinned repository toolchain. macOS, Windows, shared/network stores,
LAN/public exposure, TLS/HTTP2, tunnels, proxies and clusters are not claimed.
Existing proxy tests remain regressions, not deployment infrastructure.

## Install

Configure separate absolute private `JIDO_CODE_STORE_ROOT`,
`JIDO_CODE_BACKUP_ROOT`, and `JIDO_CODE_HUMAN_IDENTITY_STORE_PATH` paths.
Graph paths default to `.local/share/jido_code/{knowledge,backups}` in the
current user's home. Use private directories without symlink components.
Never put authoritative data in a checkout or network mount.

Load `SECRET_KEY_BASE`, a 24–512-byte `JIDO_CODE_OPERATOR_TOKEN`,
`JIDO_CODE_HUMAN_IDENTITY_ENABLED=true`, and
`JIDO_CODE_HUMAN_IDENTITY_INTEGRITY_KEY` (base64 of at least 32 random bytes)
from a private environment mechanism. Never place secrets in command arguments,
logs, support bundles or version control. Preserve the integrity key and both
stores across upgrades. The operator token is not browser identity.
Keep `PHX_SERVER=false` during installation.

Install the pinned toolchain and locked dependencies, then:

```sh
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix jido_code.local_install --confirm INITIALIZE
PHX_SERVER=true MIX_ENV=prod mix run --no-halt
```

The one-time ceremony also reads `JIDO_CODE_HUMAN_BOOTSTRAP_LOGIN`,
`JIDO_CODE_HUMAN_BOOTSTRAP_DISPLAY_NAME` and
`JIDO_CODE_HUMAN_BOOTSTRAP_CREDENTIAL`. Unset these after bootstrap. It creates
a named human and navigation membership, then grants that exact human graph
authority using the existing pristine-dataset semantic bootstrap. Roles grant
nothing. Every later read checks current grants and exact membership again.
Commands, exports, step-up and recovery are unsupported by the read-only adapter.

Open `http://127.0.0.1:4000`. `PHX_HOST=localhost` is an alternative exact host,
not an extra alias. PORT accepts 1024–65535. Binding always remains IPv4 loopback.
Unexpected hosts, peer addresses, schemes, ports or Forwarded/X-Forwarded-*
headers are rejected before cookies/assets. DNS clustering and other profiles
fail configuration. Only validated local HTTP uses a non-Secure session cookie;
encryption, signing, HttpOnly, SameSite=Lax, CSRF and Origin checks remain.

## Transport, diagnostics and upgrades

Dynamic response compression is disabled so SSE chunks are not held for it.
Static precompressed assets retain existing digest/cache rules; protected HTML
and SSE remain no-store. Transport ceilings are 128 connections (4 acceptors ×
32), 100 keepalive requests, 15-second read/idle timeout, 2-second socket-send
timeout with close, and 3-second shutdown. D2's smaller protected stream/query
and event ceilings still apply; 128 is not a supported stream count.

`JidoCode.LocalDeployment.readiness/0` in the owned runtime returns only readiness
and connection count, never human/resource identifiers. It is not a public
diagnostics route. Missing graph or identity readiness fails closed.

Stop new work, call `JidoCode.LocalDeployment.drain/0`, wait for stream cleanup,
stop the BEAM, and follow the accepted maintenance/checkpoint workflow before
starting an upgrade. Application shutdown also initiates drain before endpoint
termination. Never start another writer beside it or delete database locks.
Never restore an older graph merely to roll back UI delivery.

Streams are disposable on process death, offline events and page unload.
The client has a 30-second wall-clock lifetime, at most two retries, fresh
admission on every attempt, and visibility-expiry checks. Suspended browsers
cannot erase pixels until they execute again. Production sleep/wake, network,
restart and cleanup qualification remains pending, not inferred from unit tests.

## Partial installation recovery

If identity creation succeeds but graph bootstrap fails, preserve both stores.
Never delete identity files to repeat bootstrap. The local owner can resume
the graph half using `JidoCode.LocalInstall.complete_graph_bootstrap/2` with
the existing bootstrap human's subject reference and operator credential. It
still rejects a non-pristine graph. Existing graph authority needs governed
migration, never a shared-operator alias or silent re-bootstrap.

See [install/upgrade/rollback](./install-upgrade-and-rollback.md) for store
restrictions. Capacity measurements, production/browser/AT fault evidence and
independent review are required before D4 accepts this candidate.
