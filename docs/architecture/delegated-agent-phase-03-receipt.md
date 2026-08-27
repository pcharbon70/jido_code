# Delegated Coding Agent Phase 3 Local Containment Receipt

## Status

This receipt records the Phase 3 implementation accepted after pull request
#83 passed clean-checkout CI and merged on 2026-08-27 as
`f66e0da1c1548895fc3394182d348b9f0e8bcbf5`. DCG3 is accepted at that exact
merged candidate, which is the authorized baseline for Phase 4.

The candidate keeps the exact DGA1 Codex profile disabled while implementing
prompt-free readiness, effect-bound foreground consent, opaque local-login
resolution, fixed process isolation and egress contracts, controller-custodied
Git control data, bounded workspace effects, server-owned registered checks,
quarantine, revocation, and complete disposable-workspace cleanup.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted Phase 2 closure baseline | `aad56e85dd1f76d9ddf350750a03bd786f3645ca` |
| Concurrent synchronized main baseline | `d715358` - accepted repository wiki Phase 1 closure |
| Section 3.1 | `5b2a7f3` - readiness, foreground consent, and opaque credential references |
| Section 3.2 | `2d022fc` - local Codex credential, namespace, environment, and egress isolation |
| Section 3.3 | `5408532` - bounded workspace effects, quarantine, and registered checks |
| Section 3.4 | `4665fcc72a766e4d1ad9013d1aa44becb905fe46` - integration matrix and merge-pending receipt |
| Merged candidate | `f66e0da1c1548895fc3394182d348b9f0e8bcbf5` - merged 2026-08-27 |

## Local Security And Component Pins

| Contract | Candidate value |
| --- | --- |
| Codex local-security release digest | `61ad8cc525848cc6775d97581989fc2676221486453fb70c16e2824882d6756b` |
| Disabled DGA1 profile digest | `708e1dbd3f24e3bc83e20d573e1da28feb86e005d60521fe4311900a54c9be5d` |
| Adapter release digest | `965a8af8be140834822b56737ae6d1ce4e0bab6e1407efcf91465e4d0888ae57` |
| Readiness revision | `4fdb696b41b9fcf4f4250b55a0298e37f86662dd13d97ae795afbc6dd7ae0c2b` |
| Credential revision | `546000e28bbb15d7f1477673ae71936971c528e05bb506105743c6d9bedefbf7` |
| Worker revision | `fdb7b8eb91de05bc323c9b2becb1bb2e38d7ddb66c72e7c9d6ebde55aecd0082` |
| Sandbox revision | `8679d15dbea6901b42b8b7f47f48f979fe0fc2ad4e49edfca823d1bfe8eac1ed` |
| Network revision | `b65a4daa01b31e2e3234f07439d950999cab70a38dd26587919e9da057ebe1d8` |
| Candidate-capture revision | `906e16f0517cea1d67636a89076fdb4f2e56fbde9e7aa312f0d4d09ec0c4255a` |
| Check-registry revision | `21402eedab2000ead8d4c3951b7c661410d10ad04c3210320d26ca15b0dc837a` |
| Verifier revision | `23741ae21b4f861aedc074c76d06e8091da62c2dcd35aa7430d90f0755268b00` |
| Policy revision | `c3dbc7caad676b86d52d8880d681ae27d2db84921dd0e820bf0368530fb1a764` |
| Consent source SHA-256 | `5dcd45fec656970a9f37e50b89b71b26b15c6e49ef47c07da8549662e0343ea3` |
| Credential connector source SHA-256 | `137bcbe749795bfe0864f5a00fd8e3f9759204cf512d5f70cce68cc527a7e05d` |
| Provider egress source SHA-256 | `d3a40f11b739ddb64688f4b5e983c76f559e021ee9037a07d99c130000dd65a0` |
| Readiness source SHA-256 | `8fa51acbcc9aa89c75f177531970c7598d5df74a610ae4dce605179a184bb80b` |
| Developer-local launch source SHA-256 | `099af48ac7fd26b9a864d074b92a7e07d44efb0dafbbb0d2608bb1035f8cc832` |
| Workspace controller source SHA-256 | `730c732b7e1426cfa1edd5bec257aee1a6cf055eb73984eb76901621cee37eaf` |
| Registered-check controller source SHA-256 | `50bf3dc6476069d618b3ab11a8091859ab1fef8af9470d241e747e071a1a26a9` |

## Readiness, Consent, And Credential Evidence

- Readiness is a five-minute, non-billable, prompt-free observation over the
  exact executable digest and version, `codex login status`, opaque credential
  generation, and every local-security component revision. It claims no
  provider-to-JidoCode actor identity equivalence and fails on expiry or drift.
- Consent is a maximum-fifteen-minute foreground authorization for one actor,
  repository, task, effect, attempt, lease, fence, profile, credential
  generation, subscription billing terms, and purpose. Background, managed,
  reusable-export, changed-billing, expired, cross-actor, and cross-repository
  requests fail closed.
- The credential broker passes only a local reference to the trusted Codex
  connector. The source path remains connector-private and never appears in
  graph records, request data, attachment receipts, runner metadata, or
  durable evidence. The source must be a bounded owner-only regular file below
  an owner-only approved root with no symlinked parent and outside the
  workspace.
- The attachment is read-only at the fixed Codex home, authenticates only the
  parent, denies tool-descendant access, binds the exact attempt, fence,
  profile, generation, audience, permit, and expiry, and exports no reusable
  material. Cancellation, expiry, supersession, termination, and worker loss
  are closed revocation reasons; semantic revocation commits before
  attachment destruction.

## Process, Network, Workspace, And Check Evidence

- The launch replaces the environment with fixed non-secret `PATH`, `HOME`,
  `TMPDIR`, `CODEX_HOME`, and `LANG` values. It requires the accepted
  disposable Firecracker profile and independently binds CPU, memory,
  process-count, disk, output, wall, and idle ceilings. Host home, ambient
  credentials, store handles, SSH agent, Docker socket, publication
  credentials, unrelated repositories, extensions, MCP, skills, provider
  configuration, and additional directories remain absent.
- Parent provider egress is brokered only to
  `https://api.openai.com:443/v1`; redirects and tool-descendant egress are
  denied. The profile remains unable to select arbitrary destinations or
  fallback authentication.
- The exact admitted commit is materialized as a disposable worktree. Before
  worker handoff, its `.git` marker moves into owner-only controller custody.
  The controller's private Git view recomputes changed paths and tracked and
  untracked content evidence without exposing refs or Git control paths to the
  coding process.
- Every completed turn is rescanned. `.git` recreation, symlinks, FIFOs and
  other special files, disallowed paths, sensitive content, filesystem races,
  and file-count, per-file, disk, changed-file, or diff breaches quarantine
  immediately. Real tests cover creation, modification, deletion,
  quarantine, restoration for controller cleanup, and complete destruction.
- Codex command and check claims remain untrusted observations. At completed
  turns or handoffs, authority selects checks only from the revision-pinned
  server catalog. Receipts bind attempt, lease, fence, source, workspace,
  profile, catalog, command, resource limits, network denial, exit status,
  duration, and sanitized bounded-output digest while omitting output text.

## Verification Record

| Command or gate | Candidate result |
| --- | --- |
| Phase 3 readiness, credential, launch, workspace, attack, check, and cleanup matrix | 17 tests, 0 failures |
| DCG1-DCG2, sandbox, credential, egress, cancellation, and harness regression matrix | 92 tests, 0 failures |
| Architecture checks | Passed; zero findings |
| Dialyzer | Passed; 177 existing warnings skipped by policy, zero unignored errors |
| Repository-wide isolated `mix precommit` | Passed on synchronized main; 967 tests, 0 failures; compile, architecture, lock, format, and test gates passed |
| Clean-checkout CI | Passed on PR #83; verify and Dialyzer jobs succeeded before merge |

## Known Limits And Disabled Posture

- `codex_dga1` remains disabled, evaluation-stage, foreground-only, and not
  managed-eligible. Ordinary CI sends no provider request and consumes no
  subscription capacity. Live authentication and qualification remain
  separately consent-gated.
- This phase accepts only the developer-local existing-login class. It makes
  no managed-fleet, background scheduling, provider-session, arbitrary
  repository, other-provider, or other-model claim.
- Candidate closure, authoritative artifact capture, fresh-checkout
  verification, and recovery remain unavailable until DCG4. Product workflow
  and selection remain unavailable until DCG5 and DCG6.
- Publication, acceptance, protected-ref update, and merge authority remain
  unavailable. Human review and merge remain mandatory.

## Gate DCG3

Status: **accepted at merged candidate**

DCG3 is accepted at merged candidate
`f66e0da1c1548895fc3394182d348b9f0e8bcbf5` after clean-checkout CI and merge
on 2026-08-27. Phase 4 is authorized only from this exact pinned baseline.

DCG3 reopens regardless of checklist state if readiness sends a prompt-bearing
or billable request, outlives a bound revision, or claims unproved actor
identity; consent can be absent, expired, background, managed, reused across
effects, or widened across actor, repository, task, attempt, lease, fence,
profile, credential generation, billing terms, or purpose; credential bytes,
source paths, host home, ambient configuration, SSH agent, Docker socket,
publication authority, or reusable login material enter graph state, prompt,
argv, descendant-visible environment, journal, metadata, diagnostics,
receipts, candidates, or durable evidence; a wrong-owner, writable, symlinked,
out-of-root, workspace-owned, stale-generation, expired, revoked, wrong-audience,
wrong-attempt, or wrong-fence credential can attach or remain usable; a tool
descendant can read, copy, refresh, or reuse the login or obtain arbitrary
egress; provider, authentication, billing, endpoint, process, sandbox, or
credential delivery can fall back; the coding process can reach Git control
data, refs, external directories, host paths, sockets, devices, special files,
unrelated repositories, or out-of-policy paths; changed-file, file-count,
input, diff, disk, CPU, memory, process, output, idle, wall, or network limits
are accepted from Codex reporting or fail open; a workspace violation does not
quarantine immediately; repository content, task input, or Codex output can
add or change registered checks or make an untrusted observation authoritative;
check receipts fail to bind the accepted attempt, fence, source, workspace,
profile, command, limits, status, and output digest; cancellation or terminal
cleanup leaves a credential attachment, process namespace, workspace, Git
control link, or late result usable; the disabled profile becomes selectable
before DCG4-DCG6 close; any DCG1, DCG2, harness, sandbox, memory, managed-coding,
or governing contract gate reopens; or architecture checks, Dialyzer,
precommit, or clean-checkout CI fails at the exact merged candidate.
