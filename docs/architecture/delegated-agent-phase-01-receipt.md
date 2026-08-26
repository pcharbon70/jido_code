# Delegated Coding Agent Phase 1 Semantic Contract Receipt

## Status

This receipt records the Phase 1 implementation accepted after pull request
#77 passed clean-checkout CI and merged on 2026-08-26 as
`5d79d798de87a8c652ad429fd677b6e82c69e764`. DCG1 is accepted at that exact
merged candidate, which is the authorized baseline for Phase 2.

The candidate publishes ontology `1.4.0` and semantic protocol `2.9.0`, adds
closed delegated adapter, profile, readiness, catalog, and admission contracts,
and resolves opaque product selections to exact graph-authorized runtime tuples
before any effect can begin.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted plan and authorized Phase 1 baseline | `e5f029718543e3ca77feec36a7316f8a2c19441f` |
| Section 1.1 | `d530ae8` - delegated-agent governance baseline |
| Section 1.2 | `79a1f65` - ontology and semantic command/query protocol |
| Section 1.3 | `8177b0e` - exact catalog projection and admission |
| Section 1.4 | `7c5acdaad7c9fb649cc5ad51b86e707711f86e69` - integration matrix, release metadata correction, and merge-pending receipt |
| Merged candidate | `5d79d798de87a8c652ad429fd677b6e82c69e764` - merged 2026-08-26 |

## Contract Pins

| Contract | Candidate SHA-256 |
| --- | --- |
| ADR 0003 | `529428026eb1decf6a3f8562b98c6ff70de8d8a607649a8e477585a704d6dba2` |
| ADR 0004 | `09b0e1ece6ad09e1b25dd428a29bfed850d1b4fd74e3384dc686058d3168128b` |
| Governance baseline | `73808ff1ac5e853ce5a55445b7f34bb73bc1cccc9bfc8e594b7782d2c13f5ab2` |
| Product and qualification specification | `2a8e5ee775304942b5e04ebf2aeba427652ca1b0c59771b5b0c4ecbb4fd605d0` |
| Profile catalog specification | `6b509fedf587dc0fa3552579d85194d707796ff9adb9d74b16f69bba2dc25b6c` |
| Ontology 1.4.0 manifest | `00d8b18f3f2dbd0e93407c670790b0d8ce55b0f28c19445abf0c79ab76d25b97` |
| Delegated-agent ontology source | `92601e000421360742d9e72f19c26442f8c7345ec22da1ef76dfeff597fc26f7` |
| Delegated-agent SHACL source | `93c38dbab2725f2c2fb17f85f9cdd54f41b96b7f61a8873a4315a70547e3a115` |
| Semantic command registry | `04bb2bba8dd9251bce8cf298214f3693cc3b3852c9b0f1c78a6b8aad28c1be69` |
| Reviewed query catalog | `988cea1515996be1d6753862fbe70bb116d4ef41844ab1f5c2af365fca268b2c` |
| Reviewed query sources | `b3e1571eecded34d74cbc5662107d878604c19b743eb6f298ccd66b867927b64` |
| Delegated profile contract | `553efcba3ecbc3cf16eb0fab849915b37a061f1c5168c1c25a5f61e6df4b636f` |
| Unified agent catalog | `1465671da2340a7f98bbb0ac69dd321d338f581c4884160cc13c2de911a4e6ea` |
| Delegated admission contract | `baba25b6aacbb0138a60235ec7bf6d89eaf24530a8bb84be09180771ef6ed468` |
| Graph protocol suite | `ca600d0498a0ab22520ee9314b3ebd84e0b81ce7c1275ac2c792de1b0c5cf762` |
| Catalog and resolution suite | `5798292751afc6bf59dcf0a791865db3238c2fae6bc6ec7b24dd911ed1ab7972` |
| Real-store Phase 1 integration suite | `21a03681c0534504cbf64b60a5037adcb69fa54744f37f92a23b3edf1945814f` |

The ontology manifest pins package SHA-256
`0299861a5be5e38d7e716bff9dfbd194c2d5d45e147544064df9688dbb52dfc1`
and canonical N-Quads SHA-256
`8b787cc717043fd6cbbf6134f7e999361cec91708e774249cb9d7d5bbc4d5c66`
for 2,219 quads.

## Semantic Contract Evidence

- `DelegatedAdapterRelease`, `DelegatedAgentProfile`, and
  `DelegatedAgentReadiness` are closed, bounded values with exact digests,
  revisions, validity intervals, capability and deployment envelopes, and
  explicit signer identities.
- Registration, lifecycle transition, and readiness observation use the
  reviewed writer path with authorization, expected revisions, provenance,
  idempotency, and conflict outcomes. Concurrent identical registration
  produces one commit and one replay outcome.
- Reviewed queries reconstruct profile history, current readiness, profile
  detail, and scope-filtered candidate rows from the real graph store. Ontology
  `1.3.0` and protocol `2.8.0` remain readable, but legacy records do not imply
  delegated eligibility.
- `developer_local` is canonical. Prompt-in-argv, repository-controlled
  executable selection, unknown provider/runtime/capability values, invalid
  intervals, and unsupported lifecycle transitions fail closed.

## Catalog And Admission Evidence

- Native and delegated profiles project into one disposable `AgentOffering`
  schema. Authorization remains in current graph state; an offering is never a
  durable grant.
- Actor, tenant, repository, task, language, capability, rollout, lifecycle,
  readiness generation, expiry, and policy context constrain visibility and
  selectability. Unauthorized scopes receive no cross-scope disclosure.
- Opaque HMAC references bind current profile, adapter, access, readiness,
  policy, and source identities. Any bound drift makes a prior reference stale.
- Exact resolution has bounded admitted, duplicate, stale, unauthorized,
  incompatible, unavailable, and rejected outcomes. It cannot fall back to a
  different provider, runtime, authentication mode, billing mode, adapter, or
  executable key.
- Admission pins the delegated tuple into the execution attempt before effect.
  The executable registry is closed and repository/model input cannot select a
  binary, module, process name, credential, graph writer, publication path, or
  merge authority.

## Verification Record

| Command or gate | Candidate result |
| --- | --- |
| Ontology, startup/restart, reviewed-query, product acceptance, and Phase 1 real-store suites | 13 tests, 0 failures |
| Catalog and Phase 1 integration suites after Dialyzer correction | 8 tests, 0 failures |
| Semantic backup/restore current-release regression | 1 test, 0 failures |
| Repository-wide isolated `mix precommit` | 899 tests, 0 failures; compile, architecture, lock, format, and test gates passed |
| Architecture checks | Passed; zero findings |
| Dialyzer | Passed; 177 existing warnings skipped by policy, zero unignored errors |
| Clean-checkout CI | Passed on PR #77; verify and Dialyzer jobs succeeded before merge |

The final precommit run used a dedicated temporary root because another active
repository session was concurrently executing tests; this prevents unrelated
BEAM instances from reusing test-directory names while leaving product behavior
unchanged.

## Known Limits And Disabled Posture

- Phase 1 authorizes semantic profile, catalog, and admission behavior only. It
  does not launch Codex or another delegated CLI, deliver credentials, create a
  delegated workspace, ingest a candidate, publish a draft, or merge code.
- The first executable route remains Codex through JidoHarness using protected
  standard-input context transport. The existing prompt-in-argv built-in route
  remains blocked because it exposes bounded context in process arguments.
- Only the `developer_local` deployment class and the `jido_code` qualification
  target are in DGA1 scope. Managed fleet, other providers, detached sessions,
  publication automation, and merge automation remain disabled.
- Readiness and catalog fixtures prove deterministic contract behavior; they do
  not claim live-provider qualification. Live conformance, credentials,
  workspace isolation, cancellation, candidate ingestion, and verification are
  later-phase gates.

## Gate DCG1

Status: **accepted at merged candidate**

DCG1 is accepted at merged candidate
`5d79d798de87a8c652ad429fd677b6e82c69e764` after clean-checkout CI and merge
on 2026-08-26. Phase 2 is authorized only from this exact pinned baseline.

DCG1 reopens regardless of checklist state if catalog selection bypasses current
graph authorization; an offering discloses another actor, tenant, repository,
task, language, capability, rollout, readiness, or time scope; an opaque
reference survives bound profile, adapter, credential-generation, readiness,
policy, or source drift; resolution falls back to another provider, runtime,
authentication, billing, deployment, capability, adapter, executable, or
session tuple; process creation or another effect can occur before exact
attempt, invocation, lease, and fence binding; older ontology, protocol, or
legacy deployment records imply current eligibility; a caller, model,
repository, environment value, projection, cache, process, or runtime state can
create or replace graph authority; unknown or malformed identities, lifecycle
states, revisions, digests, intervals, executable keys, prompt protocols, or
capabilities fail open; runtime code gains direct graph, credential,
publication, acceptance, or merge authority; DGA2 or another provider or
deployment becomes reachable without its own accepted evidence; any governing
ADR or specification pin changes without reevaluation; any prior semantic,
harness, memory, or managed-coding gate reopens; or ontology verification,
architecture checks, Dialyzer, precommit, or clean-checkout CI fails at the
exact merged candidate.
