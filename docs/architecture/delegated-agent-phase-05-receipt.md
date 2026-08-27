# Delegated Coding Agent Phase 5 Developer Product Workflow Receipt

## Status

This receipt records the Phase 5 implementation candidate produced from the
accepted Phase 4 closure baseline
`513b64427f0af8ee5bb07bb5c205baa042c6185b`. DCG5 remains merge-pending until
the implementation pull request passes clean-checkout CI, merges, and a
documentation-only closure commit pins the full merge SHA and merge date.
Phase 6 is not authorized from this receipt yet.

The candidate exposes one authenticated, scope-bounded coding-agent catalog,
semantic submission, attempt, and finite-control workflow through browser,
versioned JSON API, and developer CLI surfaces. All three reuse the same
product identity, authority construction, projections, gateways, stable
outcomes, and state constraints. DGA1 remains disabled and unqualified; no
surface gains publication, protected-ref update, acceptance, or merge
authority.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted Phase 4 closure baseline | `513b64427f0af8ee5bb07bb5c205baa042c6185b` |
| Section 5.1 | `27b06569285b7822c4cbdb4de48bc55dea7b93c2` - product gateways and versioned JSON API |
| Section 5.2 | `05709a3bf139940e1bcb9aba5d736d50d8ebb404` - authenticated browser workflow and attempt experience |
| Section 5.3 | `358aafcf13d93d923a9775a6f3a2889736287944` - protected authenticated developer CLI |
| Section 5.4 | Implementation PR head - integration matrix and merge-pending receipt |
| Merged candidate | Merge-pending |

## Product Surface Pins

| Contract or implementation | Candidate value |
| --- | --- |
| Agent catalog gateway SHA-256 | `11f79e2a8871adfeafa2da0f75f347c5c76c88b4977bfca03f1142058d223006` |
| Coding submission gateway SHA-256 | `88e1cda8c84c8f1566fc46049846a32c69087b6775cb492d90a5289096dedbdb` |
| Managed attempt projection SHA-256 | `a1dff747294654edece40ec3589ae870c14398b8c081a5551c5d7f8fb75b4f94` |
| Managed control gateway SHA-256 | `9a9166282b21972e2e0c4b91c979438d7447fc762e72ebdd1dbf690284623bb3` |
| Developer CLI gateway SHA-256 | `e0f43ed2887428ec9de4b2a9ae9aee7471f4fe28e51fe032d7afceacec0343aa` |
| Protected CLI input SHA-256 | `6fb81d11f124ac14f5f4d83e2ba1e4f90770a3f2e61e3d1bf0f2670882c7f16d` |
| Coding-agent LiveView SHA-256 | `e4cdd4a1d73ab8d40f4b5032e0935c11d31ee56848e3aed4f5070d7709e75fcd` |
| Managed-attempt LiveView SHA-256 | `28f6981ba86005d3cca8c446527afd2f3d8f9ef821420a7d4e69942e1b1748fe` |
| Agent-offering API controller SHA-256 | `285a6491a705ac4a049210219b6a43a93854ee01a26d251212276ffcc459108d` |
| Coding-attempt API controller SHA-256 | `d5542d04fa6afc4e76565cba60ec58297ace92600c9e7ce029cb9ccee1ba1b93` |
| Integration matrix SHA-256 | `fef41854be0f845d80a8f62c517c2c8626f2bdab440a9947204ca839200f29b7` |

## Catalog, Submission, And Authentication Evidence

- Catalog requests are bound to the authenticated actor, factory scope,
  repository, snapshot, task, language, capability, rollout stage, and query
  time. Offerings are disposable projections with opaque references, bounded
  public fields, explicit readiness age, billing, deployment, capability,
  rollout, limitations, and selectability.
- Semantic submissions contain only bounded intent, repository and snapshot
  references, task class, acceptance requirements, opaque offering,
  idempotency, foreground consent, and billing acknowledgement. Modules,
  executables, raw commands, credentials, graph names, RDF, sandbox settings,
  and provider options are rejected before admission.
- Browser sessions, bounded bearer API authentication, and the protected local
  CLI credential file all reconstruct the same product identity and
  `AuthorityContext`. Credentials are neither persisted nor echoed.
- Admitted, duplicate, stale, incompatible, unavailable, rejected,
  unauthorized, and conflict outcomes are finite and machine-readable. Stale
  and unavailable offerings cannot silently become selectable.

## Browser, API, And CLI Evidence

- The authenticated LiveView uses the application layout and current scope,
  streams catalog offerings, drives forms through `to_form`, uses stable DOM
  IDs, and exposes explicit selection, foreground consent, billing
  acknowledgement, empty, loading, outcome, and attempt-navigation states.
- Attempt views expose normalized progress, clarification, workspace effects,
  checks, candidate, independent verification, disposition, cleanup, trust,
  readiness, billing, and limitation summaries. Internal semantic IRIs and
  prohibited runtime details stay behind the projection boundary.
- JSON routes provide catalog, submit, detail, refresh, steer, answer, cancel,
  handoff, and accepted recovery operations without exposing product stores or
  runtime implementation authority.
- `mix jido_code.agent` accepts bounded JSON only from stdin or a protected
  regular file. Command arguments contain only a finite subcommand and an
  optional request-file path; semantic task content and credentials are not
  accepted in argv. The credential itself is read from a separately protected
  file named by local configuration.
- Steer, answer, cancel, handoff, and accepted recovery are checked against the
  current projected state and fence. Boolean confirmations have equivalent
  JSON and form behavior. No surface defines publish, protected-branch, or
  merge controls.

## Verification Record

| Command or gate | Candidate result |
| --- | --- |
| Phase 5 catalog, submission, outcome, browser/API/CLI parity, control, recovery, redaction, bound, and no-publication matrix | 4 tests, 0 failures |
| Focused product gateway, API, LiveView, and CLI regression matrix | 29 tests, 0 failures |
| Architecture checks | Passed; zero findings |
| Dialyzer | Passed; 178 existing warnings skipped by policy, zero unignored errors, zero unnecessary skips |
| Repository-wide `mix precommit` | Passed at implementation candidate with 1,046 tests, 0 failures; compile, architecture, lock, format, and test gates passed |
| Clean-checkout CI | Merge-pending; must pass on the implementation pull request before DCG5 can close |

## Known Limits And Disabled Posture

- `codex_dga1` remains disabled, evaluation-stage, foreground-only,
  developer-local, and `jido_code`-only until Phase 6 qualification closes.
  The product workflow is available, but actual selectability still comes only
  from a current graph-authorized offering.
- The CLI does not accept semantic task content, credentials, arbitrary
  provider configuration, executable paths, or commands in argv. It does not
  expose an interactive provider session or disposable runtime identity.
- Phase 5 adds no background scheduling, managed fleet, provider-session
  recovery, arbitrary repository or provider support, publication,
  protected-ref update, acceptance, or merge path. Human review and merge
  remain mandatory.
- Ordinary CI performs no live provider request and consumes no subscription
  capacity. Phase 6 must qualify the exact signed DGA1 profile before developer
  preview selectability is accepted.

## Gate DCG5

Status: **merge-pending**

DCG5 becomes accepted only after clean-checkout CI passes, the implementation
PR merges, and the closure receipt pins the exact merged candidate and merge
date. Phase 6 is not authorized from this merge-pending state.

DCG5 reopens regardless of checklist state if browser, API, or CLI behavior
bypasses the shared product gateways, reviewed queries, semantic admission, or
current graph projection; any surface constructs a different actor, tenant,
policy, repository, offering, attempt, fence, or authorization context; an
offering is not bounded, scope-filtered, disposable, readiness-aware, and
opaque, or stale, incompatible, unavailable, or revoked offerings remain
selectable; explicit exact-profile selection, foreground consent, or billing
acknowledgement can be omitted; duplicate and stale requests lose stable
idempotent outcomes; semantic task content, credentials, prompts, transcripts,
hidden reasoning, graph IRIs or names, raw RDF, process IDs, provider sessions,
workspace paths, runtime metadata, unbounded output, executable paths, raw
commands, modules, provider options, or arbitrary sandbox settings enter argv,
public projections, responses, logs, diagnostics, or durable state; the CLI
accepts a non-regular, broadly readable, empty, oversized, or unbounded input
file; browser sessions, bearer authentication, and local CLI authentication do
not reconstruct the same product authority; LiveView collections abandon
streams, forms abandon `to_form`, or stable authenticated IDs and loading,
empty, error, and reconnect behavior regress; steer, answer, cancel, handoff,
or recovery bypasses current state, interaction, confirmation, idempotency, or
fence checks; browser, API, or CLI exposes publication, protected-ref update,
acceptance, goal-satisfaction, policy mutation, knowledge adoption, or merge;
DGA1 becomes selectable before signed Phase 6 qualification; any DCG1-DCG4,
harness, sandbox, memory, managed-coding, candidate, verifier, recovery,
accounting, or governing contract gate reopens; or architecture checks,
Dialyzer, precommit, or clean-checkout CI fails at the exact merged candidate.
