# Install, Upgrade, And Rollback

## Supported Environment

Use the exact toolchain and native dependency pins in
[`backend-compatibility.md`](../architecture/backend-compatibility.md). The
store and backup roots must be separate absolute directories on a local
filesystem, owned by the service account, mode `0700`, and not symlinks. NFS,
shared writable volumes, multiple BEAM writers, and alternate databases are
unsupported.

Production requires these secret/configuration references:

| Variable | Requirement |
| --- | --- |
| `SECRET_KEY_BASE` | independent high-entropy Phoenix cookie secret |
| `JIDO_CODE_OPERATOR_TOKEN` | at least 24 random bytes; never graph data |
| `JIDO_CODE_SESSION_GENERATION` | rotate to revoke all browser sessions |
| `JIDO_CODE_STORE_ROOT` | trusted absolute local path |
| `JIDO_CODE_BACKUP_ROOT` | separate trusted absolute local path |
| `PHX_HOST`, `PORT`, `PHX_SERVER` | deployment endpoint settings |

Provider credentials remain references resolved by the secret-provider port.
Do not place provider tokens in RDF, environment-independent configuration,
command reasons, logs, or browser storage.

## Clean Install

1. Install the pinned Erlang, Elixir, Rust, Node, CMake, compiler, Git, and
   `pkg-config` versions.
2. Set production environment variables and create the two private roots.
3. Build with `mix deps.get`, `mix compile --warnings-as-errors`, and
   `mix assets.deploy`.
4. Run `mix jido_code.release verify`. This verifies native loading, ontology
   source checksums, shapes, reviewed queries, reasoning profiles, graph/store
   schemas, runtime contract, and the exact release digest.
5. Against a pristine dataset only, run
   `mix jido_code.bootstrap --confirm INITIALIZE`. This atomically loads the
   immutable ontology and creates graph authority. A second run fails closed.
6. Run `mix jido_code.knowledge integrity` and
   `mix jido_code.release preflight`.
7. Start the server, sign in with the operator token, and enroll the first
   repository through the product command form.

Never delete a lock file, initialize over a non-empty unknown dataset, or
force an incompatible schema open.

The hypermedia target additionally requires an immutable product release
manifest containing route-owner, interface, dependency, browser asset, CSP,
proxy, signal-schema, fragment-root, and rollback-artifact versions. Until a
route's cutover gate closes, clean installation must identify the current
compatibility owner honestly and must not advertise unavailable Datastar,
Dstar, ShadcnUI, named-human, incident, or lens capability.

## Upgrade

`JidoCode.ReleaseContract.migration_order/0` is authoritative: application,
ontology, shapes, query catalog, reasoning, backend schema, store schema,
graph transforms, derived rebuild, then acceptance. `Migration.Workflow`
compares exact manifests and omits unchanged steps without reordering changed
ones.

Before any destructive step:

1. Stop admission and drain or cancel governed attempts.
2. Run `mix jido_code.release preflight`; retain its artifact ID.
3. Verify backup checksum, integrity status, and at least twice the estimated
   migration bytes as free local space.
4. Enter schema-migration maintenance and execute only versioned semantic graph
   migration commands. Source graphs and audit history stay immutable.
5. Rebuild derived graphs from retained asserted graphs.
6. Run integrity, release verification, bounded queries, product projection,
   and capacity smoke tests before leaving maintenance.
7. Create and verify a post-upgrade checkpoint. Preserve the pre-upgrade
   checkpoint until Phase 10 acceptance is complete.

Startup rejects incompatible graph ontology metadata, incomplete target
graphs, unsupported backend/store schemas, missing native code, and corrupt
release inputs. The safe response is migration or rollback, never an in-place
metadata edit.

## Rollback

If no post-upgrade command has committed, restore the verified pre-upgrade
artifact with matching `--artifact` and `--confirm` values. Restore stages the
checkpoint in isolation, validates manifest/checksum/schema/ontology/integrity,
records a new restore activity, switches the active dataset selector, and
reopens it before returning readiness.

If new authoritative commands have committed, do not silently discard them.
Fail stop, export evidence, and require an explicit forward migration or an
operator-approved reconciliation plan. Retention floors reject checkpoints
that could reactivate erased data.

Product-runtime rollback selects the last qualified route table, handler set,
dependency lock, fingerprinted `app.js`/`app.css` assets, CSP/proxy config, and
operations instructions as one compatible unit. It does not roll back graph
state, receipts, identity/revocation generations, or observed source outcomes.
Removal of a compatibility route, asset, socket, or dependency requires the
exact consumer manifest to be empty and the rollback observation window to be
accepted; a milestone label alone is insufficient.
