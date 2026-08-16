# Phase 10 Product And Release Acceptance Receipt

## Status

This receipt records the Phase 10 candidate verified locally on 2026-08-04 and
accepted after pull request merge on 2026-08-04.
The graph-backed product workbench, product security boundary, fleet controls,
retention, release operations, and final acceptance suites are implemented.
The pull request passed clean-checkout CI and merged on 2026-08-04 as
`6c15f152abab457a93273a5a4863dca0e2fb7bd5`; G9 is accepted.

The embedded TripleStore quad dataset remains the only durable source of
truth. Browser state, LiveView streams, LiveVue island state, PubSub,
scheduler queues, runtime workers, caches, telemetry, worktrees, and sandbox
contents are disposable projections or effects. No accepted product fact
depends on any of them surviving restart.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Phase baseline and merged G8 | `de5e5a34e50bd23d71ee14742bccb18cdae0711d` |
| Section 10.1 | `fb18d244dd2f180ae50f7e792182cc86c97942be` - deliver graph-backed product workbench |
| Section 10.2 | `a3b29b321481e48dbcb1d3935011f16ebaee6f67` - harden product security boundaries |
| Section 10.3 | `a1c5704ba6f7fefe251e1350f0ddf89252efa516` - harden fleet operations and retention |
| Section 10.4 | `97f208f886320572405ea438baf6e974f49d3efd` - complete release operations readiness |
| Section 10.5 | This receipt, final integration fixes, and acceptance tests; exact commit recorded by Git history |
| Merged candidate | `6c15f152abab457a93273a5a4863dca0e2fb7bd5` |

## Contract Pins

| Contract | Accepted candidate value |
| --- | --- |
| Application | `jido_code` `0.1.0` |
| TripleStore | Git commit `6dc1b6d985f4805f9856858e0c0047b9f2d5ad7f` |
| Store / backend schema | `1` / `2` |
| Graph registry | `1.0.0` |
| Factory ontology / operational shapes | `1.0.0` / `1.0.0` |
| Command protocol | `1.7.0`; 38 registered semantic commands |
| Query catalog | `1.7.0`; 102 reviewed queries |
| Query catalog SHA-256 | `cbf055c75813021b4f8d25df01a52061f48511f4f3d0e3bf363a4ff6d9ab28e0` |
| Reasoning profiles SHA-256 | `ca63e8b7b646f20b79bdcfb9154cedca7bfe0ca33ec2a5802a7f9469100d7f93` |
| Jido / runtime contract | `2.3.2` / `jido:2.3.2/runtime-contract:1.0.0` |
| Runtime storage | ephemeral ETS; graph-backed recovery |
| Redaction classification | `1.0.0` |
| Release contract SHA-256 | `f75f2b2242d2095803eb33e7ddcecf1457a0342e6f854d14453dad2521185816` |
| Release source manifest | 287 files; SHA-256 `09679f10f6c1bbe23b3d1a155d124e11e0f37d7f297070bfcb8f585796c75a7d` |

## Accepted Product Contract

- The authenticated LiveView owns route, actor, scope, selected repository,
  projection refresh, subscriptions, forms, and semantic command submission.
  LiveVue receives bounded JSON-safe workflow props and emits semantic intents
  back to the owning LiveView.
- Product queries are fixed catalog entries. Browser input cannot choose
  SPARQL, query modules, graph variables, authority, or arbitrary graph scope.
- Repository route references are opaque presentation values. Selection is
  reauthorized against the visible catalog, and unknown, malformed,
  cross-scope, or revoked resources use the same concealed presentation.
- Repository enrollment uses `to_form/2`, validation preview, confirmation,
  idempotency, command validation, atomic graph commit, audit provenance, and a
  bounded receipt. Product feedback does not expose RDF, SPARQL, backend
  errors, credentials, or hidden resource details.
- Repository, work, execution, outcome, and knowledge surfaces are bounded
  graph projections with explicit revision, freshness, completeness,
  truncation, and safe failure state. A newly enrolled repository with no
  control or memory graph renders honest empty projections.
- The product principal is the same actor IRI represented by bootstrap
  authority. Route admission and resource/action authority remain separate,
  with every projection and command independently authorized.
- Every authoritative direct write synchronously persists both TripleStore's
  dictionary sequence and the RocksDB WAL before reporting success. This
  prevents process handoff from reusing dictionary IDs and corrupting graph
  metadata.
- The first command in a new UTC month creates its audit partition in the same
  optimistic atomic commit. Install can resume only a verified ontology-only
  bootstrap interrupted before authority creation; it refuses an already
  initialized dataset.

## Executable Evidence

The Phase 10 product acceptance fixture starts the real StoreServer, Writer,
QueryRunner, Maintenance, embedded TripleStore, ontology release, authority
bootstrap, product gateway, projection provider, router, and LiveView. It
proves:

- clean bootstrap at authority dataset revision 2, an abrupt dictionary
  manager loss, full substrate restart, browser-style repository enrollment at
  revision 3, graph projection refresh, command receipt, exact audit revision,
  selection, deep-link reconnection, and concealment;
- a second full substrate restart reopens revision 3 and reconstructs the same
  authorized repository from graph only;
- present repository graphs are queried with their exact repository scope,
  authorized missing graphs are represented as empty, and mismatched owner
  metadata fails closed;
- command failures never produce a committed flash, monthly audit rollover is
  atomic, and interrupted bootstrap recovery is narrowly constrained; and
- the existing Phase 6-9 integration suites exercise observation/source
  publication, desired state and work planning, leases and scheduling,
  execution/tool provenance, evidence and decisions, final satisfaction,
  knowledge evolution, reasoning, restart recovery, and restore equivalence
  through the same semantic command and projection boundaries.

| Acceptance fixture | SHA-256 |
| --- | --- |
| Product LiveView acceptance | `bc620fee00958c6fc4c67c274f0014312be4da192a2d677ece207bb6c186baab` |
| Product graph adapter | `4509e83bc1bb2d43517ad5515b8cdb008a5bb1e503eefda290b119ad7491a0ed` |
| Capacity fixture | `50ad2b178153d3ddde53cd9d9ea8313672abca5acbc28c7acc5d4cccd43221d9` |

## Browser Verification

The browser run used a clean isolated store and backup root. Bootstrap ran in
one BEAM process, Phoenix opened the dataset in a second process, enrollment
committed revision 3, Phoenix was terminated normally, and a third process
reopened the same revision and repository.

| Surface or behavior | Result |
| --- | --- |
| Desktop, 1440 x 1000 | Light and dark workbench rendered without overlap or horizontal overflow |
| Mobile, 390 x 844 | Responsive single-column content rendered without document overflow; navigation scroll remained bounded |
| Theme | Explicit light and dark modes retained usable contrast and stable layout |
| Accessibility | Axe WCAG 2 A/AA: zero violations on desktop light, desktop dark, and mobile dark |
| Keyboard and focus | Theme control reached by Tab and exposed `:focus-visible` |
| LiveVue island | Server-rendered island hydrated, remained nonblank, and emitted a semantic surface-selection event |
| Navigation | Deep link, selected repository, back, forward, reload, and process restart preserved authorized state |
| Security presentation | Unauthorized repository reference remained concealed |
| Runtime diagnostics | Current run had no browser console errors after a clean console reset |

Screenshots were retained outside the repository at
`/tmp/jido-code-phase10-workbench-light-desktop-v3.png`,
`/tmp/jido-code-phase10-workbench-dark-desktop-v3.png`,
`/tmp/jido-code-phase10-workbench-light-mobile-v3.png`, and
`/tmp/jido-code-phase10-workbench-dark-mobile-v3.png`.

## Fleet, Security, And Recovery Evidence

- Fleet admission enforces trusted ceilings over graph policy for global,
  cohort, repository, provider, capability, rate, budget, risk, and campaign
  dimensions. Deterministic priority/fairness ordering, starvation pressure,
  storm coalescing, and per-candidate isolation are covered by integration
  tests.
- The bounded capacity harness completed all 17 operation classes for small,
  medium, and maximum profiles. Maximum scale reports soft-limit pressure and
  all callbacks retain explicit deadlines.
- Retention plans exact reachable statements, requires confirmation, enters
  maintenance, checkpoints first, commits deletion plus audit atomically,
  validates integrity, and raises a graph-authoritative restore floor.
- Product authorization, route/ref fuzzing, fixed query selection, SPARQL
  injection rejection, delegation/scope confinement, redaction, dependency,
  native backend, sandbox/tool, backup integrity, and restore rollback are
  covered by their owning adversarial suites.
- Backup restore verifies checksums, schema, ontology, metadata, and semantic
  integrity before lineage activation. Failed candidates reactivate the prior
  dataset; accepted restore and full process restart rebuild projections,
  scheduling, attempts, decisions, and memory from graph revisions.
- Final preflight opened dataset revision 3 with 1,315 quads in five graphs and
  created rollback checkpoint `artifact-20260804T110038Z-0ef85db43d878715`
  with payload SHA-256
  `8e31d13b52e7dfaf4c4b7cf36818dd0d019b73fc78b02533463291ad1f7bac67`.
- Upgrade preflight binds the exact release contract, integrity report,
  verified rollback checkpoint, free-space requirement, and maintenance
  availability. Incompatible or interrupted datasets stay unready.

## Verification Record

| Command or gate | Result |
| --- | --- |
| Product projection and Phase 10 acceptance files | 7 tests, 0 failures |
| Product acceptance plus backup/restore integrity | 8 tests, 0 failures |
| Architecture checker | Passed; zero findings |
| `mix precommit` | 313 tests, 0 failures; compile, architecture, lock, format, and test gates passed |
| `mix assets.deploy` | Production Vite/Tailwind/LiveVue assets built and digested |
| `mix jido_code.release verify` | Exact release contract accepted |
| `mix jido_code.release audit` | One durable store; zero hidden-authority findings and compatibility facades |
| `mix jido_code.release preflight` | Health, integrity, rollback backup, and migration preflight accepted |
| `mix hex.audit` | No retired Hex dependencies |
| `npm audit --omit=dev` | No production npm vulnerabilities |

## Configuration Posture

Production requires explicit `JIDO_CODE_OPERATOR_TOKEN`,
`JIDO_CODE_STORE_ROOT`, and `JIDO_CODE_BACKUP_ROOT`. Store and backup roots
must be absolute, distinct, private, and outside source and static trees.
Credentials and provider secrets remain external runtime inputs and are never
persisted in the graph. Non-production root overrides are paired so an
isolated store cannot accidentally write backup artifacts into another test or
operator root.

## Known Limits

- The browser-authored durable action in this release is repository enrollment.
  Downstream lifecycle acceptance is exercised through semantic APIs and then
  inspected through product projections; not every Phase 6-9 command has a
  dedicated browser form.
- Browser acceptance uses deterministic local adapters and an isolated
  TripleStore. It does not call a live Git provider, hosted model, or external
  sandbox and therefore does not certify third-party availability.
- The capacity command is a bounded synthetic operation matrix. Embedded-store
  startup, backup/restore, retention, restart, and concurrent command behavior
  are measured by their owning integration suites, not by that synthetic
  timing alone.
- G9 closed after clean-checkout CI passed on the pull request; the merged
  default-branch commit is `6c15f152abab457a93273a5a4863dca0e2fb7bd5`.

## Gate G9

G9 is accepted at merged candidate `6c15f152abab457a93273a5a4863dca0e2fb7bd5`.
Pull request CI and the default-branch merge confirmed the same candidate.
Discovery of a second
durable source of truth, an unexplained accepted fact, dictionary durability
regression, raw graph/UI bypass, cross-scope disclosure, unrecoverable process
state, restore-integrity failure, or a failed release objective reopens the
gate.
