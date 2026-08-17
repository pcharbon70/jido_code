# Harness Phase 5 JidoHarness Subscription Runtime Receipt

## Status

This receipt is being assembled with the Harness Phase 5 implementation. The
current candidate is merge-pending; HG5 remains blocked until every section is
complete, the adoption, lifecycle, cancellation, containment, privacy,
readiness, restart-recovery, and full regression matrices pass, clean-checkout
CI passes, and the pull request merges. Phase 6 is not authorized from this
document yet.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Phase baseline and merged HG4 closure | `3d1d1d05c42cf34b1ef94505a1931fb8be80b014` |
| Accepted Phase 4 candidate | `c7ea711abacee22924d1ab23751da1ebbe23cc85` |
| Section 5.1 | `d52501ddb9573e1064f642a85bc209550c395afc` |
| Section 5.2 | `faa3aea92008fae1cf087d4e72dd8bb8480b7f98` |
| Section 5.3 | `bf4ab8e4afb5ff3637365bcbbb6dab5e9e85ac9b` |
| Section 5.4 | `557c8f95cf5070d37d48cae6d92934eee5ea6eb8` |
| Section 5.5 | This section's exact commit is recorded by Git history |
| Merged candidate | Merge-pending; full merge-commit SHA must be pinned after clean-checkout CI and merge |

## Adoption Contract

JidoHarness is pinned as an exact unreleased Git dependency at revision
`e41fc1651282469f2db4219a48d9f7feef1b0dbc`; the reviewed source archive has
SHA-256 digest
`fbe4d49edf2e5ae7843231e45c47158a15fdcdbc494b40a3d766967c1b81f8b3`.
The accepted toolchain is Elixir 1.19.5 on Erlang/OTP 28.3.1. No floating
branch, tag, or unverified archive is admitted.

Every upstream built-in finite-run adapter remains blocked because the
reviewed revision does not satisfy JidoCode's protected prompt, journal, and
tool-profile contract as a whole. The Z.AI adapter additionally remains
disabled while native cancellation is unproven. JidoCode admits only its own
developer-local Pi RPC process profiles through the pinned structured process
manager:

| Profile | Prompt transport | Tools | Journal | Managed fleet |
| --- | --- | --- | --- | --- |
| `pi_rpc_deny_all` | stdin JSONL | explicit `--no-tools` | controller-owned, memory-only, bounded | blocked |
| `pi_rpc_read_only` | stdin JSONL | `read,grep,find,ls` only | controller-owned, memory-only, bounded | blocked |

Both profiles disable sessions, extensions, skills, context files, approval,
additional directories, MCP servers, and provider/project configuration. An
empty tool list is represented by the explicit deny flag and cannot be
interpreted as an omitted setting. The controller supplies a regular-file
journal barrier so the reviewed upstream journal fails closed to its bounded
memory tail instead of creating descendant-accessible JSONL storage.

## Delegated Runtime Boundary

`JidoCode.Runtime.JidoHarnessAdapter` remains behind the existing
execution-runtime port. Every prepare, start, signal, status, cancellation, and
termination call is re-authorized before adapter dispatch. One run or session
turn is metadata for one graph-authorized attempt; the adapter receives no
graph handle and has no second model authority.

Run, process, provider-session, cursor, and journal identifiers live only in a
bounded BEAM-lifetime registry. Restart recovery deliberately does not reopen
them. Missing runtime state is classified from graph facts through the closed
vocabulary `recover`, `supersede`, `propagated_cancellation`, `abandon`, or
`retry_later`; the adapter never invents a `crashed` graph state. Accepted
observations contain only bounded normalized lifecycle fields and digests.
Terminal records may retain exact component versions, bounded usage,
workspace and candidate-diff digests, and artifact IRIs, but never raw prompts
or provider-internal context claims.

## Developer-Local Isolation

Subscription CLI use requires explicit local consent and an attested Phase 4
Firecracker-style microVM worker at the exact snapshot. The launch replaces
the environment with a minimal allowlist, mounts one disposable worktree,
uses brokered provider-endpoint egress, and contains no store handle,
publication credential, SSH agent, Docker socket, unrelated repository, or
subscription credential bytes. It records only an opaque reference to an
existing local login.

Run count, session turns, CPU, memory, process count, disk, output, wall time,
and idle time all have finite hard outer ceilings. CLI-internal token, cost,
and turn enforcement is reported as unavailable where it cannot be proven;
subscription usage is observation only. These profiles are explicitly
developer-local and make no managed-fleet security claim.

## Cancellation, Containment, And Readiness

The pinned process manager is exercised against a resistant descendant and
proves bounded process-group escalation. The product runner waits for graceful
termination within a bound, escalates to group kill, waits for terminal proof,
and records the enforcement class. The same runner and cancellation primitive
serve both admitted Pi RPC profiles.

Lease expiry or supersession first commits the semantic cancellation. Adapter
stop is bounded independently, after which the outer-worker port terminates
the entire process namespace and destroys the disposable sandbox even when
the adapter stalls. Candidate capture is byte-bounded and crosses the result
boundary only as a digest receipt. Every event, diff, artifact, callback, and
result sink repeats the active lease and current fencing-token check; expired
or superseded output cannot trigger a durable or external effect.

Readiness discovery performs no prompt-bearing provider request and reports
only bounded installation, compatibility, version, and authentication-signal
evidence. It never infers actor identity. Live smoke is unavailable by default
and requires explicit, unexpired, actor-bound consent plus a billing
acknowledgement for the exact profile before a configured probe can run.

## Integrated Boundary And Privacy

The integration suite rejects an unauthorized start before process creation,
then proves the admitted launch uses the exact isolated workspace, replacement
environment, stdin prompt channel, and memory-only journal barrier. A simulated
BEAM registry restart discards all runtime references and derives its recovery
classification solely from supplied graph state.

The privacy matrix runs both admitted profiles under separate actor attempts.
Prompt, journal, cross-actor, and subscription-credential canaries are absent
from argv, launch metadata, retained registry records, and journal files. The
credential-shaped environment is rejected before process creation; the prompt
appears only in its intended stdin JSONL message. Per-attempt run identifiers
remain distinct, and termination removes both controller retention roots.

These tests specify the JidoCode boundary and exercise the pinned local process
manager, but they do not provide a production Firecracker deployment, a
provider credential helper, or real subscription login. No billable live
smoke was run. Managed delegated execution remains blocked until the Phase 4
credential-helper or attaching-proxy boundary is proven for the provider.
Clean-checkout CI and the merged commit remain the final candidate evidence.

## Verification Record

| Command or gate | Result |
| --- | --- |
| `phase_h05_adoption_gates_test.exs` | Pass |
| `phase_h05_adapter_registry_test.exs` | Pass |
| `phase_h05_developer_local_test.exs` | Pass |
| `phase_h05_cancellation_test.exs` | 9 tests, 0 failures; includes resistant descendant process-group proof |
| `phase_h05_integration_test.exs` | 4 tests, 0 failures |
| Complete Phase 5 focused suite | 29 tests, 0 failures |
| Phase 1 through Phase 5 harness regression suites | 192 tests, 0 failures |
| `mix compile --warnings-as-errors` | Pass |
| `mix architecture.check` | Pass |
| `mix precommit` | 505 tests, 0 failures; pass on the merge-pending candidate tree |

## Gate HG5

HG5 is merge-pending and remains blocked. It reopens—or remains blocked—while
any adapter lacks a cancellation bound, any journal or prompt can leak, or any
late output can enter durable state. These reopening conditions remain in
force regardless of checklist state.
