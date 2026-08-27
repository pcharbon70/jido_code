# Delegated Coding Agent Phase 4 Trustworthy Candidate Receipt

## Status

This receipt records the Phase 4 implementation accepted after pull request
#85 passed clean-checkout CI and merged on 2026-08-27 as
`c64084448772b0dd18b6d6abd7a3d94fc6324852`. DCG4 is accepted at that exact
merged candidate, which is the authorized baseline for Phase 5.

The candidate accounts only for the observable outer Codex runtime, captures
accepted turn checkpoints as immutable artifacts, recomputes candidates from
the controller-custodied Git view, verifies them in a separate fresh clone,
and derives recovery from current graph facts plus rehashed checkpoints. It
does not enable DGA1 or grant acceptance, publication, merge,
goal-satisfaction, policy-mutation, or knowledge-adoption authority.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted Phase 3 closure baseline | `1f70d3b1a73fde3a2429c7f99e09f32256a1a75d` |
| Section 4.1 | `cf26aba` - honest outer accounting and content-addressed checkpoints |
| Section 4.2 | `8879bb5` - controller-recomputed immutable candidate closure |
| Section 4.3 | `f083146` - fresh-clone verification, cancellation, and graph-only recovery |
| Section 4.4 | `8005d457969e1a636bf5dcbcdc83d214b21e7aba` - integration matrix and merge-pending receipt |
| Merged candidate | `c64084448772b0dd18b6d6abd7a3d94fc6324852` - merged 2026-08-27 |

## Accounting, Candidate, And Verifier Pins

| Contract or implementation | Candidate value |
| --- | --- |
| Accounting source SHA-256 | `8d6aca27afe6d6514123968b62930ba69950fa342faf76fca318458c5a75f6d8` |
| Checkpoint source SHA-256 | `f98efe7754757cbec7cf7f22684fd899a5cd642506d552805813598dfbf409b8` |
| Candidate source SHA-256 | `d673b141a3546d7466befafcbc9c28c19da5e7e086eaebf46fe5e4ac9538abd0` |
| Verification-result source SHA-256 | `78e8e6a8c4c88266d556615838de3e0f9403b6be4a1f2ce7997ad54f4e89bb15` |
| Recovery source SHA-256 | `e6268fb81ff3f0ace3ce45bc7260008c2603ff911622e25212d37eb8432f6e35` |
| Cancellation-sequence source SHA-256 | `a9a1bf2b871ffe923a3bbd8b85cadcace56e84e3162e3a9b6b115c91e6ddf0f1` |
| Artifact repository source SHA-256 | `e7b0baf19ddfbe8b6ed015c320889a3c56abe0893b7ede707863ebf25ec3a219` |
| Workspace controller source SHA-256 | `d4f49ad200e1296822bd65f540260a5125e9c419830cf254f1ba68de6235a6bd` |
| Candidate-capture source SHA-256 | `08adf1a8bc864a2c8ddf4dfb49bc3629aaf1b9f82a830ff0af2ca7d244b339c0` |
| Fresh-checkout verifier source SHA-256 | `7446166e9b3608e134ed7a39b19c04b9ab8200886448d8061dcb9580033fc61d` |
| Recovery-coordinator source SHA-256 | `e10abed2bffff2831c25b1b59874213b5f42e21b8472de64f0c30e349f592fda` |
| Integration fixture SHA-256 | `5a154a8aeccbd971ed9080785354cd1e5a540b0292ab7b4ddfaaf6589b3f5a92` |

## Outer Accounting And Checkpoint Evidence

- Accounting admits only bounded lifecycle, usage, changed-path,
  check-request, terminal, workspace, patch, tree, artifact, and omission
  observations. Internal prompts, hidden reasoning, provider context, internal
  tool mediation, and provider-private state are explicitly unavailable.
- Raw prompts, transcripts, reasoning, output, credentials, secrets,
  environment, argv, process and provider-session references are rejected.
  Every controlled effect has a committed invocation identity and a terminal
  or ambiguous outcome.
- Timeout is an attributable failure outcome. Ambiguity is an effect
  classification that requires identity reconciliation and never invents a
  lifecycle success or authorizes generic retry.
- Accepted turn and handoff boundaries export one bounded normalized patch to
  an immutable SHA-256 artifact. Checkpoints bind exact attempt, lease, fence,
  source, base, workspace, tree, paths, turn, accounting, and artifact digests
  while requiring neither provider-session nor process state.

## Candidate And Verification Evidence

- Candidate closure rescans the ready workspace, requires a clean admitted
  source base, rehashes immutable checkpoint bytes, and recomputes the patch,
  result tree, ordered add/modify/delete operations, files, generated
  artifacts, registered-check receipts, and clean secret scan.
- Candidate identity binds source, attempt, fence, checkpoint, delegated
  profile, adapter, CLI, model, sandbox, policy, tool manifest, check registry,
  candidate protocol, terminal summary, accounting, and omissions. Check
  receipts must match the exact profile and registry; CLI claims have no
  authority.
- Dirty bases, Git control recreation, symlinks, special files, forbidden
  paths, limits, sensitive content, generated-file violations, corrupt
  artifacts, and digest mismatches fail closed and quarantine the workspace.
- Verification clones and checks out the exact base in a separate verifier
  root, rehashes and applies the immutable patch, compares paths, operations,
  modes, files, tree, generated artifacts, and secret scan, and runs commands
  from the controller registry. It cannot reuse the producer identity,
  delegated workspace, CLI process, provider session, or CLI check reports.
- Governed evidence remains separate from candidate status, sufficiency,
  disposition, goal satisfaction, acceptance, publication, and merge. Every
  such authority is false for DGA1.

## Cancellation And Recovery Evidence

- Cancellation order is graph intent, permit revocation, adapter cancellation,
  namespace kill, workspace cleanup, late-output rejection, and terminal
  accounting. Containment and cleanup continue if native stop is unavailable.
- Recovery rejects PID, runtime, provider-session, event-cursor,
  workspace-path, journal, and CLI-cache references. It reconstructs only from
  current graph facts, exact source identity, and a rehashed accepted
  checkpoint.
- Possibly completed effects select effect-identity reconciliation and forbid
  generic retry. Stale fences reject streams, files, callbacks, artifacts,
  candidates, verification results, ordinary results, and terminal events.

## Verification Record

| Command or gate | Candidate result |
| --- | --- |
| Phase 4 accounting, checkpoint, candidate, verifier, recovery, cancellation, corruption, and integration matrix | 18 tests, 0 failures |
| DCG1-DCG4 delegated-agent and applicable H05-H06 regression matrix | 80 tests, 0 failures |
| Architecture checks | Passed; zero findings |
| Dialyzer | Passed; 178 existing warnings skipped by policy, zero unignored errors |
| Repository-wide isolated `mix precommit` | Passed at implementation head with 985 tests and at the merged closure baseline with 1,023 tests; 0 failures; compile, architecture, lock, format, and test gates passed |
| Clean-checkout CI | Passed on implementation pull request #85; CI verify and Dialyzer checks succeeded before merge |

## Known Limits And Disabled Posture

- `codex_dga1` remains disabled, evaluation-stage, foreground-only,
  developer-local, and `jido_code`-only. Ordinary CI performs no live provider
  request and consumes no subscription capacity.
- The artifact repository is a content store, never semantic authority. Graph
  facts pin accepted artifact IRIs and digests; artifact presence authorizes
  nothing.
- Phase 4 adds no managed fleet, provider-session recovery, background
  scheduling, arbitrary repository or provider support, product workflow,
  publication, protected-ref update, or merge path.
- Product workflow remains unavailable until DCG5. Selection and preview
  qualification remain unavailable until DCG6. Human merge remains mandatory.

## Gate DCG4

Status: **accepted-at-merged-candidate**

DCG4 is accepted at merged candidate
`c64084448772b0dd18b6d6abd7a3d94fc6324852`, merged on 2026-08-27 after
clean-checkout CI passed. Phase 5 is authorized only from this pinned
baseline.

DCG4 reopens regardless of checklist state if JidoCode claims visibility into
internal prompts, hidden reasoning, provider context, internal tool mediation,
provider-private state, or complete provider-loop accounting; raw prompts,
transcripts, reasoning, unbounded output, credentials, secrets, reusable
authentication, argv, environment, process references, provider sessions,
journals, workspace paths, or provider-private state enter graph or durable
memory; a controlled effect lacks invocation-before-effect or a terminal or
ambiguous outcome; timeout becomes a success or lifecycle state, ambiguity
becomes success or failure without reconciliation, or a possibly completed
effect permits generic retry; an accepted checkpoint is not content-addressed,
does not bind exact attempt, lease, fence, source, base, workspace, tree, turn,
and accounting, or requires disposable process or provider-session state;
candidate patch, tree, path operation, file, generated artifact, check,
secret-scan, terminal, omission, or identity facts are accepted from Codex or
are not independently recomputed; candidate identity omits source, attempt,
fence, profile, adapter, CLI, model, sandbox, policy, tool manifest, check
registry, or candidate protocol; dirty bases, Git control data, symlinks,
special files, forbidden paths, generated-file violations, sensitive content,
limit breaches, corrupt artifacts, or digest mismatches do not quarantine;
candidate, verification, evidence sufficiency, disposition, publication,
goal satisfaction, acceptance, and merge become conflated; verification
reuses the delegated workspace, CLI process, provider session, producer
identity, CLI check claims, mutable cache, or credentials; the verifier does
not reconstruct the exact source and patch, run controller-registered checks,
compare every required digest, or emit governed evidence; cancellation occurs
before graph intent, fails to revoke permits, stop the adapter, terminate the
namespace, clean the workspace, reject late output, or account terminally;
recovery accepts runtime, process, session, cursor, path, journal, or cache
state instead of current graph facts and an accepted rehashed checkpoint;
stale fences or late streams, files, callbacks, artifacts, candidates,
verification results, or terminal events reach an authoritative sink; Codex
can verify, accept, publish, merge, mutate policy, adopt knowledge, or satisfy
a goal; the disabled profile becomes selectable before DCG5-DCG6 close; any
DCG1-DCG3, harness, sandbox, memory, managed-coding, verification, accounting,
or governing contract gate reopens; or architecture checks, Dialyzer,
precommit, or clean-checkout CI fails at the exact merged candidate.
