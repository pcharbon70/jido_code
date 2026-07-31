# Knowledge Store Runbook

This runbook covers the embedded authoritative quad store. Operator commands
are intentionally bounded: they do not accept SPARQL, RDF payloads, raw backend
operations, or arbitrary source and destination paths.

## Runtime Configuration

Production requires durable, local filesystem paths owned by the application
user:

```text
JIDO_CODE_STORE_ROOT=/var/lib/jido_code/knowledge
JIDO_CODE_BACKUP_ROOT=/var/lib/jido_code/backups
```

Both roots must be absolute, separate, non-symlinked, non-world-writable, and
on storage that survives application replacement. A store root cannot be
shared by concurrent application instances. Monitor free space for both the
active dataset and at least one full checkpoint in the backup root.

## Startup And Shutdown

At startup, `JidoCode.Knowledge.StoreServer` opens the selected dataset in quad
mode, verifies backend and graph metadata, then changes readiness to `ready`.
Durable commands fail closed in every earlier or failed state.

Use the runtime's normal graceful stop. `StoreServer.terminate/2` closes the
dictionary manager and RocksDB adapter. After restart, verify:

```bash
mix jido_code.knowledge health
mix jido_code.knowledge integrity
```

Health output is bounded to open/readiness state, schema compatibility,
dataset revision, last in-process integrity result, checkpoint age, and a
redacted failure class.

## Backup And Export

Create a checkpoint:

```bash
mix jido_code.knowledge backup
```

Create a complete RDF export:

```bash
mix jido_code.knowledge export --format nquads
mix jido_code.knowledge export --format trig
```

The command returns an artifact identifier, checksum, revision, counts, and
consistency mode. Files are written only beneath `JIDO_CODE_BACKUP_ROOT`.
Checkpoint and export creation temporarily reports `backing_up`; writes queue
behind the exclusive `StoreServer` operation. Retention candidates are only
reported by the internal maintenance API. No Phase 2 command deletes backups.

## Verified Restore

Select a checkpoint artifact and repeat its exact identifier as confirmation:

```bash
mix jido_code.knowledge restore \
  --artifact artifact-YYYYMMDDTHHMMSSZ-0123456789abcdef \
  --confirm artifact-YYYYMMDDTHHMMSSZ-0123456789abcdef
```

Restore enters maintenance, validates the manifest and payload, closes the
active handle, checks a separate candidate, records graph-native restore
provenance, atomically selects the candidate, reopens it, and reruns integrity.
The previous selected dataset remains on disk. Any candidate failure triggers
automatic selector rollback and verification of that prior dataset. The
service returns to `ready` only after the active selection is verified.

Do not move files into the active store root or edit the `ACTIVE` selector by
hand. There is no destructive repair command in Phase 2.

## First Response

| Health state | Meaning | First action |
| --- | --- | --- |
| `opening` / `verifying_*` | Startup has not completed | Wait for the configured open timeout, then inspect redacted application logs. |
| `backing_up` | Exclusive checkpoint/export is active | Allow the bounded operation to complete; do not restart unless it exceeds the operator timeout. |
| `maintenance` / `recovering` | Restore or controlled maintenance is active | Do not send durable commands; verify the initiating operator command. |
| `locked` | Another process owns the store | Stop the unexpected owner; never delete lock files from a running store. |
| `incompatible` | Schema or backend contract differs | Use a compatible binary or an approved migration; do not force-open. |
| `corrupt` | Metadata or integrity contract failed | Preserve the store and backups, run integrity, and restore a verified checkpoint. |
| `unavailable` / `degraded` | Backend, path, native library, or persistence failure | Check volume availability, ownership, free space, and native dependency loading. |

Telemetry uses only fixed operation, outcome, error, health, and retry labels.
Paths, artifact identifiers, graph identifiers, query text, credentials, and
graph contents are never telemetry tags.
