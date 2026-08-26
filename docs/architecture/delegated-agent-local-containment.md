# Delegated Agent Developer-Local Containment

## Status And Scope

This document records the Phase 3 developer-local security boundary for the
disabled DGA1 Codex profile. The implementation proves readiness, consent,
credential, workspace, network, check, and cleanup mechanics without enabling
the profile or granting publication or merge authority.

## Readiness And Consent

`CodexReadiness` performs prompt-free discovery against the exact executable
registry entry. The only CLI authentication operation is bounded `codex login
status`; no prompt-bearing provider request is made, and neither provider nor
JidoCode actor identity is inferred from the result. The expiring receipt pins
the profile, adapter release, local security release, executable, CLI,
credential reference and revocation generation, worker, sandbox, network,
candidate capture, check registry, verifier, and policy revisions. Any expiry
or drift makes the receipt non-current.

`DelegatedAgentConsent` is a short-lived foreground authorization for one
exact effect. It binds actor, repository, task, attempt, lease, fence, profile,
opaque credential reference, revocation generation, subscription billing
classification and terms, purpose, and expiry. Background dispatch, managed
eligibility, reusable credential export, missing billing acknowledgement, and
lifetimes over fifteen minutes fail closed. Live-smoke and qualification
effects require their own effect-bound consent.

Durable credential and consent records contain only opaque resource identity,
current generation, bounded policy bindings, digests, and expiry. Local login
keys and reusable authentication material are never part of those records.

## Credential And Process Isolation

`CodexLocalConnector` is the only trusted component that resolves an approved
local Codex login reference. Its private state retains the source path; the
credential broker, execution request, graph records, launch metadata, and
attachment receipt receive no login bytes or source path. The connector accepts
only a regular owner-protected file below an owner-protected approved root,
rejects symlinked parents and workspace-owned paths, and attaches it read-only
at `/run/jido-code/codex-home` for the exact attempt, fence, profile, generation,
and permit expiry.

The Codex launch replaces the environment with fixed non-secret paths and runs
inside the accepted disposable Firecracker process namespace. Host home, SSH
agent, Docker socket, store handles, arbitrary provider configuration,
publication credentials, unrelated repositories, extensions, MCP servers,
skills, and additional directories remain absent. Only the Codex parent may
request brokered provider traffic; tool descendants are denied credential
access and egress. `CodexProviderEgress` admits HTTPS traffic only to
`api.openai.com:443/v1`, with redirects disabled.

An attachment remains usable only while its attempt, fence, generation, and
expiry are current. Cancellation, expiry, supersession, termination, and worker
loss are closed revocation reasons. Destruction occurs only after the matching
semantic transition is committed, and a revoked attachment cannot be looked up
or reused.

## Workspace Effects And Registered Checks

`DelegatedWorkspaceController` materializes the exact admitted commit through
the existing `GitWorkspace` provider, then moves the worktree `.git` marker into
an owner-only controller directory before handing the tree to the unprivileged
worker. The worker receives no Git control path, external directory, host path,
socket, device, or unrelated repository. Controller-owned Git commands use the
private worktree directory and work-tree binding only for change accounting,
registered checks, and cleanup.

Every completed turn is rescanned from the filesystem and private Git view.
Only regular files and directories are accepted. A symlink, special file,
recreated `.git`, disallowed changed path, sensitive-content finding,
filesystem race, file-count, per-file input, disk, changed-file, or diff-size
breach immediately changes the workspace to `quarantined`. The receipt binds
the admitted commit and snapshot to exact changed paths, canonical current-tree
and diff digests, counts, limits, attempt, lease, and fence. Untracked file
content participates in the diff digest. Cleanup restores the private marker
only inside the controller and destroys the entire disposable worktree.

Process CPU, memory, process-count, disk, output, wall, and idle ceilings are
bound to the accepted Firecracker isolation profile before launch. Filesystem
counts, disk use, paths, content, and diff bounds are independently recomputed
by the workspace controller rather than accepted from Codex output.

`DelegatedRegisteredChecks` ignores check claims or commands in repository and
Codex observations. At a completed-turn or handoff boundary it selects names
only from graph-derived authority and the revision-pinned server
`CheckCatalog`. The controller supplies the private Git environment directly to
the registered runner. Durable receipts omit output text and bind attempt,
lease, fence, source snapshot, workspace, profile, catalog, command, resource
limits, network denial, exit status, duration, and bounded sanitized-output
digest. Codex events remain explicitly untrusted observations.
