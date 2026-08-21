# Memory Phase 6 Exact Content Storage, Access, And Lifecycle Receipt

## Status

This receipt records the Memory Phase 6 merge candidate verified locally on
2026-08-21. MG6 remains merge-pending until the implementation pull request
passes clean-checkout CI, merges, and its full merge commit is pinned here and
in the Phase 6 plan. Phase 7 is not yet authorized.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted MG5 baseline | `7068d4c64bd11d9716c8ec7079f8aa2d70002a15` |
| Phase 5 closure record | `163321d` - pin and accept merged MG5 candidate |
| Section 6.1 | `944c9d4` - store bounded encrypted episode content |
| Section 6.2 | `2f4fed5` - gate exact content behind single-use permits |
| Section 6.3 | `ccd337d` - enforce complete content lifecycle erasure |
| Section 6.4 | `64f95f4` - select graph-native exact content storage |
| Section 6.5 and receipt | This commit; exact commit is recorded by Git history |
| Merged candidate | Merge-pending; not yet accepted |

## Contract Pins

| Boundary | Candidate value |
| --- | --- |
| Ontology and shapes | `1.2.0` / `1.2.0` |
| Graph registry | `2.3.0`; graph-native `episode_content` and `content_lifecycle` enabled |
| Data policy | `2.0.0`; `diagnostic_capture` and `project_total_history` disabled |
| Command catalog | `2.3.0` |
| Query catalog | `2.3.0`; aggregate source digest `57a322f650e9be9b460831f070aea44f36375fef3ea7d99639f87c3d5d67d419` |
| Episode content and chunk schemas | `1.0.0`; immutable, complete, ordered, bounded ciphertext |
| Cipher and key-provider port | `1.0.0`; AES-256-GCM, per-tenant/per-object key generations |
| Permit, access outcome, lifecycle, hold, erasure, backup, and cleanup | `1.0.0` |
| Storage decision | `1.0.0`; graph-native accepted for the candidate; no vault authorized |
| Benchmark corpus | SHA-256 `6a63d96c7f60d84c8ca195a2b77c2f4afdce8301a7285402dccf9666b1aea13a`; 325 objects and 25,395,200 plaintext bytes |
| Benchmark metrics | SHA-256 `bc8984d74e6206fb5b02453acee95ffd9f372f5dd2b62eadd54b323a0ec4fddb` |
| Signed benchmark decision | `https://jido.run/id/content-benchmark-decision/5c0b7679ac48c11b80016135fb6d3d15` |
| Integration fixture | Real bootstrap, enrollment, segmented run, serialized writer, immutable content graph, lifecycle graph, reviewed query runner, concurrent consumption, writer restart, and key destruction |

## Graph-Native Storage Evidence

The accepted candidate branch encrypts eligible bytes before constructing a
semantic command. Opaque content identity does not derive from plaintext.
Every immutable content graph binds its repository and source event, policy,
classification, media type, representation, key reference and generation,
AES-GCM nonce and tag, authenticated-context digest, ordered chunk indexes,
ciphertext-only byte counts and digests, completeness root, and atomic closed
and complete state. Missing, duplicate, reordered, oversized, mixed-policy,
or orphaned chunks fail before command construction. The content graph has no
ordinary product projection and no authority-bearing predicate.

The signed benchmark decision binds every Phase 1 corpus field and all nine
mandatory results. Candidate ratios are capture `1.50x`, query `1.75x`, backup
`1.25x`, restore `1.40x`, rebuild `1.90x`, and storage amplification `3.50x`,
with zero integrity failures, orphaned objects, or unerased objects. A missing
or failed result yields `vault_adr_required`, which authorizes no vault. The
separate storage decision record is
`docs/architecture/memory-content-storage-decision.md`.

## Encryption, Permit, And Release Evidence

The key-provider port creates per-tenant/per-object 256-bit keys, retains
explicit generations for rotation, denies revoked keys, and makes ciphertext
unrecoverable after key destruction. Pre-encryption hygiene rejects secret
classification, configured canaries, credential patterns, high-entropy secret
candidates, provider-private markers, and hidden-reasoning classification.

`AuthorizeContentAccess` binds actor, purpose, task and scope, current
authorization and revision, reviewed query and parameters digest, exact content
version and representation, byte range, sink, destination, method, expiry,
data ceiling, and—when the sink is agent context—attempt, lease, fence,
execution context, model invocation, and model-access profile.
`ConsumeContentAccess` rechecks every bound dimension, current lifecycle and
hold access, revocation, byte ceiling, expiry, and single-use state immediately
before release. The real serialized writer admits one concurrent consumer;
idempotent command replay is treated as already consumed and releases no bytes.

The gateway releases only the authorized committed range. Audit outcomes are
closed as released, denied, unavailable, failed, or ambiguous and contain only
selected IRIs, ciphertext-and-range commitments, bounded byte counts, reasons,
and times. A crash after consumption records ambiguity and cannot replay. Raw
released bytes never enter the audit graph.

## Lifecycle, Hold, Erasure, And Recovery Evidence

Append-only content transitions cover active, cold, unavailable, provider-lost,
expired-pending, erase-requested, crypto-erased, physically-deleted,
externally-attested, and externally-unverifiable state without rewriting the
immutable payload graph. Holds are case-specific and separately bind owner,
distinct approver, scope, purpose, affected objects, access policy, review
date, and held/release-pending/released transitions.

Erasure requires retrieval blocking before any destructive effect, no active
hold, and an exact inventory of bodies, lexical and dense indexes, summaries,
cases, procedures, datasets, caches, exports, queued jobs, replicas, provider
objects, and backup-restorable keys. Actions destroy the object key before
derivative cleanup and advance the restore floor. External deletion is
reported as attested only with evidence; otherwise the durable state is
externally unverifiable. Lawful non-sensitive lifecycle shells and
non-reversible commitments remain, while key destruction makes retained
ciphertext unrecoverable.

Backup manifests bind an erasure generation and excluded content/key IRIs.
Restore rejects an older generation or any attempt to reintroduce an excluded
content object or key. Every projection with erased lineage is deterministically
rebuilt or invalidated.

## Profile And Authority Posture

`content_lifecycle_writer`, `episode_content_writer`, and `content_gateway` are
enabled only through their versioned contracts. `diagnostic_capture` and
`project_total_history` remain unregistered and runtime-disabled. No
application-owned vault is authorized. Provider-owned governed artifacts may
remain external references only when the provider owns storage and authority;
a JidoCode-controlled bucket is never relabeled as external authority.

## Verification Record

| Command or gate | Result |
| --- | --- |
| Phase 6 focused content, permit, lifecycle, decision, and real-store matrix | 20 tests, 0 failures |
| Complete memory suite, including prior phases | 111 tests, 0 failures |
| `mix architecture.check` | Pass |
| `mix precommit` | Pass; 712 tests, 0 failures, with architecture checks passed |
| `mix dialyzer` | Pass; 177 existing warnings skipped by the checked-in ignore policy, no unignored warnings |
| Pull request clean-checkout CI | Merge-pending |

## Known Limitations

- The benchmark is a deterministic reproducible conformance and relative-
  capacity harness. Production hardware, corpus distributions, and key-service
  latency require ongoing operational measurement and can reopen MG6.
- The included in-memory key-provider adapter is for isolated tests and
  explicit local use. Production deployment must provide the same port through
  an approved external key service without placing key bytes in graph state.
- Cryptographic erasure is the immediate accepted removal class for graph-
  native ciphertext. Physical compaction of unreachable ciphertext is a later
  maintenance effect and must never be reported before it completes.
- Queryable cold state is represented and access-checked, but a production
  cold-tier adapter is not selected by this phase.
- Broader diagnostic and project-total capture remain disabled.

## Gate MG6

MG6 remains merge-pending. It may be accepted only after clean-checkout CI and
merge, by pinning the full merge-commit SHA here and in the Phase 6 plan. Phase
7 remains unauthorized until then.

MG6 reopens if plaintext, a secret value, provider-private state, hidden
reasoning, or a plaintext-derived sensitive commitment enters durable content;
if content identity or public metadata leaks sensitive plaintext equality; if
encryption occurs after semantic command construction; if chunks can be
missing, duplicated, reordered, oversized, mixed-policy, orphaned, or
incompletely closed; if the signed benchmark omits a mandatory corpus field or
threshold, fails a mandatory threshold, or can be altered without detection;
if a vault becomes reachable without a superseding accepted ADR and equivalent
proof; if any store other than the graph gains semantic or lifecycle authority;
if exact content is selected, decrypted, or released without a current,
purpose-bound, expiring, consumed single-use permit; if authorization,
revocation, lifecycle, hold, version, range, sink, destination, method, data
ceiling, attempt, lease, fence, context, invocation, or model profile is not
rechecked immediately before release; if concurrent use or replay releases
twice; if a post-consumption crash is unattributed; if audit stores released
bytes; if lifecycle mutates immutable event or payload evidence; if holds can
be placed, reviewed, or released without their distinct case, owner, approver,
scope, purpose, policy, objects, and dates; if erasure does not block retrieval
first or misses any primary, derivative, provider, replica, queue, export,
backup, or key location; if unverifiable external deletion is called erasure;
if an erased key or content object can return through backup or restore; if a
derived projection retains erased lineage; if diagnostic or project-total
capture becomes registered or enabled; if a JidoCode-controlled bucket is
treated as external authority; or if any Phase 7 memory feature becomes
reachable before MG6 is accepted. These reopening conditions remain in force
regardless of checklist state.
