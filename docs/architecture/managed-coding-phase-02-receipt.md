# Managed Coding Phase 2 Governed Tool Plane Receipt

## Status

This receipt records the Phase 2 implementation candidate verified locally and
awaiting clean-checkout CI and pull request merge. MCG2 remains merge-pending;
Phase 3 is not authorized until this receipt is updated with the full merged
candidate commit.

The candidate establishes isolated disposable Git workspaces, bounded and
revision-pinned source reads, digest-guarded mutation, server-owned registered
checks, bounded candidate inspection and immutable local capture, unique
adapter registration, and invocation-before-effect mediation through
`ToolGateway`. Publication, governed commands, protected-branch writes, and
merge remain outside the ordinary coding capability.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Authorized Phase 2 baseline | `36ff62d23d77c047c740535764ed8688bc51b783` |
| Section 2.1 | `16a2dec` - establish managed coding workspaces |
| Section 2.2 | `1030d5a` - implement governed source read tools |
| Section 2.3 | `a6b8d87` - implement guarded workspace mutations |
| Section 2.4 | `1d2c63d` - add registered checks and candidate capture |
| Section 2.5 | `55d130e` - mediate managed coding adapters |
| Section 2.6 | This receipt, real-worktree integration, and final gate evidence; exact commit recorded by Git history |
| Merged candidate | **merge-pending** |

## Contract Pins

| Contract | Candidate value |
| --- | --- |
| Workspace contract | exact attempt, lease, fence, repository, snapshot, base commit, sandbox revision, allowed paths, and ceilings |
| Workspace specification SHA-256 | `4384f152c2c7cc2b59b71b1f3b475d16ac3b3a3276648318c049ee6ae5d4ef24` |
| Canonical workspace digest SHA-256 | `6cff19a86bab92cab199571ad9dac510c9c946182b4b7b717da46e2b1571e231` |
| Tool catalog | `1.0.0`; eight ordinary managed coding tools have concrete adapters |
| Adapter registry SHA-256 | `47eae3c58c173aaf17e52ea1e083dfa72befd564aece369efc26739736d81226` |
| Registered check contract | fixed executable, arguments, cwd, environment, network, toolchain digest, timeout, output, resources, and retry policy |
| Candidate schema | `managed-candidate/1.0.0`; immutable local artifact with no publication field or side effect |
| Candidate adapter SHA-256 | `8fa55db50b413bef2bcbedfa4bb2e6fc8da898cbd356ddf3e9463812b4068ca0` |
| Effect identity SHA-256 | `d69bf5c3ae5f76fc6408c3a3e1c91688d7138c29caab41386ad3e46971a521ef` |
| Disabled coder capabilities | governed commands, network publication, `submit_candidate`, protected-branch writes, and merge |

## Workspace And Tool Evidence

- Git worktrees are provisioned from an exact commit with Git credentials,
  prompts, SSH agent, Docker socket, host home, and system/global Git config
  unavailable to workspace commands. Cleanup distinguishes destroyed,
  quarantined, held, and retained-candidate dispositions without treating the
  directory as recovery truth.
- Canonical tree and path guards reject traversal, absolute paths, symlinks,
  special files, non-NFC paths, and paths outside authorized prefixes. File,
  byte, disk, output, changed-path, diff, process, memory, wall, and idle
  ceilings are bound by the workspace and sandbox contracts.
- Source search has deterministic ranking and scope-bound continuation tokens.
  Symbol inspection pins the accepted analysis revision. File reads require an
  exact digest and bounded range and classify binary/UTF-8 content. Repository
  content stays explicitly untrusted and secret-bearing reads fail closed.
- Apply, create, and delete revalidate lease, fence, workspace, snapshot,
  capability, and policy immediately before effect. Apply requires one exact
  match and digest; create requires an absent target and parent digest; delete
  moves content into recoverable effect state. Deterministic effect identities
  reconcile retries, and failed post-effect limit checks roll back.
- Registered checks are chosen only by stable catalog name; the server owns the
  executable and all execution policy. Adapter observations, rather than agent
  claims, classify success, failure, timeout, cancellation, infrastructure
  failure, unavailable evidence, flake suspicion, truncation, and redaction.
- Candidate diffs have stable path order, base/current digests, binary patch
  representation, explicit truncation/redaction omissions, and secret scanning.
  Capture records patch/artifact digests, paths, modes, submodules, workspace,
  toolchain, and profile pins but performs no publication.

## Mediation, Recovery, And Threat Evidence

- Every enabled ordinary coding tool maps to one unique concrete module and
  exact adapter digest. Missing, substituted, privileged, or duplicate
  registrations fail closed. `run_governed_command`, `submit_candidate`, and
  actor interaction are not in the ordinary adapter registry.
- `ToolGateway` authorizes closed arguments, commits invocation start, obtains a
  current authority projection, claims the fenced effect identity, dispatches
  the registered adapter, bounds the result, completes or marks ambiguity, and
  commits one terminal outcome. Completed identities return replay receipts;
  stale fences reject before adapter dispatch.
- Adapter results contain bounded JSON observations, safe classifications, and
  redaction status. Gateway failure diagnostics expose only controlled error
  kinds and operation names, not source content, host paths, secrets, backend
  errors, or sandbox internals.
- Architecture enforcement denies Runtime dependencies on Integrations and
  proves the managed loop can reach effects only through Factory ports. Real
  worktree integration executes search, inspection, read, edit, create, delete,
  registered check, and candidate diff through `ToolGateway`, then proves
  deterministic local capture.
- Focused hostile tests inject traversal, symlink, stale digest, stale fence,
  duplicate effects, protected paths, oversized observations, sensitive
  content, raced content, timeout, cancellation, infrastructure failure, and
  process-loss replay. Workspace tests exercise cleanup and quarantine while
  effect receipts preserve semantic recovery identity.

| Evidence | SHA-256 |
| --- | --- |
| Real-worktree mediated integration | `7cb1ba02112acd3cd54e621771e2c1eb6a63c6d896ba328b295ee5363f02ea65` |
| Mutation and replay fixture | `f209486626dac09f7d09e30ff60d33773b19e9e40bea3be76bff047c86578e93` |
| Registered-check and candidate fixture | `536533939222adedfacc04f45910f689f0a8887bd9ca182e85cd9b9f01fce534` |

## Verification Record

| Command or gate | Candidate result |
| --- | --- |
| Real-worktree mediated integration | 2 tests, 0 failures |
| Managed workspace/read/write/check/candidate focused suites | Passed locally |
| Harness MCG1 and tool/sandbox/security suites | Included in full suite; passed |
| Architecture checks | Passed locally |
| Dialyzer | Passed; zero unignored candidate warnings |
| `mix precommit` | 774 tests, 0 failures; compile, architecture, lock, format, and test gates passed |
| Clean-checkout CI | **merge-pending** |

## Known Limits And Disabled Posture

- Phase 2 provides the effect plane, not the model-driven strategy loop. Context
  compilation, model turns, bounded continuation, and candidate completion
  directives begin only after MCG2 closes.
- Registered checks execute through a supplied sandbox runner; catalog entries
  never grant raw shell, arbitrary executable, environment, cwd, egress, or
  retry control to an agent.
- Candidate capture is local and immutable but is neither verification nor
  acceptance evidence. Publication and merge remain separately authorized
  human-controlled effects.
- The initial runtime remains single-agent. Pods and specialists remain disabled
  until later topology and equivalence gates are accepted.

## Gate MCG2

Status: **merge-pending**

MCG2 remains open until the implementation pull request passes clean-checkout
CI, merges, and this receipt pins the full merged candidate SHA and merge date.
Phase 3 is not authorized from an unmerged branch or this provisional receipt.

MCG2 reopens regardless of checklist state if any enabled tool lacks a concrete
adapter; any managed runtime effect bypasses `ToolGateway`, invocation-before-
effect accounting, current policy, the effect sink, or the current fence; any
retry can duplicate a write; any path guard permits traversal, symlink escape,
special files, Unicode ambiguity, or unauthorized scope; any read or diagnostic
can disclose secrets or unbounded content; any check accepts agent-controlled
execution policy or agent-relabeled results; any candidate capture publishes,
writes a protected branch, claims verification, or merges; cleanup loss makes
workspace state required recovery truth; MCG1 reopens; or the exact architecture,
Dialyzer, precommit, and clean-checkout gates fail.
