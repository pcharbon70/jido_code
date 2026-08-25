# Managed Coding Phase 5 Resilience Receipt

## Status

This receipt records the Phase 5 implementation candidate verified locally and
accepted after pull request merge on 2026-08-25. The implementation pull
request passed clean-checkout CI and merged as
`4319ff50fe123a3050bab26b72b3d91826799cf1`; MCG5 is accepted at that merged
candidate and Phase 6 is authorized from this pinned baseline.

The candidate adds graph-authoritative recovery, explicit effect ambiguity
contracts, race-safe cancellation, hostile-input and tenant isolation controls,
bounded fair capacity, low-cardinality health evidence, and an operator runbook.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Authorized Phase 5 baseline / accepted MCG4 | `b5985947074fbde248e36cebb3ceac05dca666ff` |
| Section 5.1 | `c2888e82016963a9c9f064676677366277078606` - graph-driven recovery |
| Section 5.2 | `f6922eff69820c61e600015cc35942e0694e78c5` - bounded effect reconciliation |
| Section 5.3 | `d583e56bece316dc262e409f3a8fed6f11d6abb4` - race-safe cancellation |
| Section 5.4 | `384d45bc08f5f34ed0521315b95e7d18e8c714c1` - hostile-input isolation |
| Section 5.5 | `8c0417f9b7fb2a3913a0bb2391b9a17fb20f8592` - bounded capacity and health |
| Section 5.6 | This receipt and integration matrix; exact commit recorded by Git history |
| Merged candidate | `4319ff50fe123a3050bab26b72b3d91826799cf1` - merged 2026-08-25 |

## Contract Pins

| Contract | Candidate SHA-256 |
| --- | --- |
| Recovery record | `1a1f2fc0936d8597b56ffd44161c08932626ec00531e6faf700222fd87933eee` |
| Recovery plan | `f05a7746bcb18b1a5296dab2ef4968c49af8883ab86f2bdb4324dbd1377f54d0` |
| Recovery coordinator | `85a595128484f1dd33f7f6e49f6b4fc5e970f57f7ee4e874c7329463a813bb67` |
| Effect policy | `e49fb0c559d265d378877923e2eeeac4dd107c4ea6cc0aa57d674857e4840a7f` |
| Effect reconciler | `8bc39cefa79b6fc246fe0ef9a5e374a6fe855cf525430af9b02476a28c054fc2` |
| Retry policy | `520a4b909f510dc5ef29f78fd9b509f68c5301b0853d26621e106f2c47edfd90` |
| Cancellation protocol | `47f2f4d03567f35ef8a7670ef22db26cc21cb046aa3c70ffcebd6f5cc61dde55` |
| Security policy | `50048861f32c2d2e6b84f470ba7c41bca7ef1216583ec23cc89b7b6d9fefd6b7` |
| Capacity scheduler | `f1af38e9182ed5681bce6d51257c7f2a8f495292465c7cc2e5ce6680e3a8d499` |
| Capacity configuration | `56bb5cf836b80bb14a7c0cdb6b1bd8968db41fdeabc4ab3d7065f8c323df582a` |
| Operator runbook | `3f22cd3cc818a7a7225b5f05324a6a68fc7d6f1887c4662d59389fa57350ed0c` |
| Phase 5 integration fixture | `d1159b234b17d01dab45e39ffd6b82dc25898ed1361e8cbef92b0075b8fab7d9` |

## Recovery And Reconciliation Evidence

- Recovery validates ordered lifecycle facts, reconstruction watermark,
  invocation identities, budget use, candidate evidence, terminal facts, schema
  version, immutable artifact digests, and every pinned baseline input.
- Nonterminal continuation acquires a strictly newer graph fence before a
  disposable workspace or agent is recreated. Orphan process and filesystem
  state is explicitly discarded. Terminal attempts do not restart.
- Contradictory, incomplete, unverifiable, and future-version evidence is
  quarantined for authorized resolution. No recovery path guesses progress.
- Context, model, tool, filesystem, credential, artifact, verifier,
  interaction, and publication effects have a closed replay, query,
  compensation, or manual-resolution contract. Intent precedes dispatch and
  stable invocation/idempotency/fence identity binds every outcome.
- Timeout and caller loss are ambiguous, never proof of non-execution. Retries
  are bounded by count, elapsed time, exponential backoff, deterministic
  jitter, and resource use, with every decision durably recordable.

## Cancellation And Security Evidence

- Cancellation commits request identity, actor, reason, time, target fence, and
  retention rule before stopping dispatch or signalling runtime components.
  Capabilities are revoked, queued work cancelled, effects terminated after a
  bounded grace, capacity released, and terminal state compare-and-committed.
- Late results lose state, candidate, and disposition authority and survive
  only as attributable observations. Cleanup can destroy or quarantine
  disposable workspaces while immutable audit evidence remains.
- Tenant and repository scope is exact. Repository/task text, model/tool
  output, dependency hooks, and retrieved memory remain untrusted data and
  cannot select adapters, policy, credentials, capabilities, or sandboxes.
- Coding and verification require unprivileged, read-only-root,
  copy-on-write, no-host-filesystem, no-device, no-ambient-credential,
  capability-empty, no-new-privilege, network-denied bounded isolation.
- Sensitive values are redacted recursively while stable digests remain for
  audit. The adversarial matrix covers prompt injection, traversal, symlinks,
  fork bombs, floods, exfiltration, cross-tenant references, forged signals,
  and dependency lifecycle scripts.

## Capacity And Operational Evidence

- Global, tenant, repository, provider, sandbox, verifier, and adapter active
  and queue ceilings are explicit. Reserved slots retain recovery and
  cancellation capacity; queued work expires and rotates fairly by tenant.
- Admission returns admit, defer, or reject before durable workflow admission.
  Saturation never creates an unbounded internal queue.
- Queue age, active count, latency, budget burn, crashes, retries, ambiguity,
  cancellation lag, verifier lag, and saturation use bounded samples without
  tenant, repository, or attempt dimensions.
- Health reports stuck attempts, orphaned leases/workspaces, missing outcomes,
  fence conflicts, evidence gaps, and sustained pressure. The runbook covers
  safe drain, restart, reconciliation, quarantine, and emergency disablement.

## Verification Record

| Command or gate | Candidate result |
| --- | --- |
| Managed-coding component, runtime, verifier, UI, and integration regressions | 106 tests, 0 failures |
| Repository-wide `mix precommit` | 846 tests, 0 failures; compile, architecture, lock, format, and test gates passed |
| Architecture checks | Passed; zero findings |
| Dialyzer | Passed; 177 existing warnings skipped by policy, zero unignored errors |
| Clean-checkout CI | Passed on PR #70; verify and Dialyzer succeeded |

## Known Limits And Disabled Posture

- The integration matrix exercises deterministic contract adapters and local
  fault fixtures; hosted provider, external sandbox, and infrastructure load
  certification remain deployment responsibilities.
- Publication remains manual-resolution-only after ambiguous outcomes.
  Autonomous push, approval, publication, and merge remain disabled.
- Capacity is a pure scheduler contract for embedding by the durable admission
  service; cross-node quota consensus is not claimed by this phase.
- MCG5 closed only after PR #70 clean-checkout CI passed and the exact merged
  candidate was pinned; later discovery of a reopening condition overrides
  this accepted status.

## Gate MCG5

Status: **accepted at merged candidate**

MCG5 is accepted at merged candidate
`4319ff50fe123a3050bab26b72b3d91826799cf1` after clean-checkout CI and merge
on 2026-08-25. Phase 6 is authorized only from this exact pinned baseline.

MCG5 reopens regardless of checklist state if recovery trusts process,
workspace, cache, snapshot, or orphan state; reconstruction continues from
unordered, incomplete, contradictory, unverifiable, or future-version
evidence; a replacement acts before acquiring a newer fence; timeout, caller
death, or missing evidence is treated as non-execution; retry lacks a stable
identity or exceeds admitted count, elapsed, backoff, jitter, or resource
limits; ambiguity can widen capability or erase evidence; cancellation signals
before durable commit, fails to revoke authority, leaks capacity, or permits a
late result to advance state, close a candidate, or change disposition; a
completion, cancellation, expiry, restart, verification, or disposition race
bypasses compare-and-commit; tenant or repository scope can cross through any
lookup, command, signal, artifact, cache, workspace, credential, projection, or
telemetry path; untrusted content can alter host policy or adapter selection;
coding or verification can escape process, filesystem, network, environment,
resource, child-process, or symlink boundaries; a secret or sensitive source
leaks through prompts, results, logs, signals, errors, artifacts, metrics, or
operator views; active work, queues, mailboxes, retry state, metric samples, or
cardinality is unbounded; reserved recovery/cancellation capacity is lost;
admission proceeds while capacity is unavailable; cleanup or health evidence is
incomplete; any MCG1-MCG4 gate reopens; or the exact architecture, Dialyzer,
precommit, and clean-checkout gates fail.
