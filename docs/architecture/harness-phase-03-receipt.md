# Harness Phase 3 Tool Reference Monitor Receipt

## Status

This receipt is being assembled with the Harness Phase 3 implementation. The
current candidate is merge-pending; HG3 remains blocked until every section is
complete, the hostile-input, race, replay, and full regression matrices pass,
clean-checkout CI passes, and the pull request merges. Phase 4 is not authorized
from this document yet.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Phase baseline and merged HG2 closure | `3be8e017849a56da286e143eb9d61c638caaaf5e` |
| Accepted Phase 2 candidate | `49453d05fe72c45431420c05591f89d4ff09f0a8` |
| Section 3.1 | `c2a61e1` - publish closed tool catalog |
| Section 3.2 | `31cd7cb` - govern tool action proposals |
| Section 3.3 | This section's exact commit is recorded by Git history |
| Merged candidate | Merge-pending; full merge-commit SHA must be pinned after clean-checkout CI and merge |

## Closed Tool Catalog

The initial model-facing catalog is exact at version `1.0.0`. Schema changes
change their digest and require an intentional contract replacement; adapter
identity changes likewise invalidate the pinned supply-chain digest.

| Tool | Input schema digest | Output schema digest |
| --- | --- | --- |
| `search_source` | `sha256:bfe42d6df844a51f9ecdf611d12cbfcf575e4b1cecff1fc3fb16e91834d260b0` | `sha256:bb18f1a89129c5cb561607c95be05e21fadb69f43e4f1c18727938dc47fd9a0a` |
| `inspect_symbol` | `sha256:d447329b6fb7e9d9bf4d64b0db54b6088fc10f5dc6f10e8cd31ec80066333794` | `sha256:bb18f1a89129c5cb561607c95be05e21fadb69f43e4f1c18727938dc47fd9a0a` |
| `read_file` | `sha256:fba95abe33f41a1acb24da2481d3c62da1509e002485821645a06da63dee0653` | `sha256:bb18f1a89129c5cb561607c95be05e21fadb69f43e4f1c18727938dc47fd9a0a` |
| `apply_edit` | `sha256:3353d0619140ac37f2ed68eb2142fa6b3835df803e495baee2816d6ea60256fc` | `sha256:33a00d40ddc77177ddcdfc5ebccd5607f0d879c5fefa4099ad3745876b12c6ac` |
| `create_file` | `sha256:66c65761b5af89932dc1a2196169120ea1fe5c8df13aab1817a234556884351c` | `sha256:33a00d40ddc77177ddcdfc5ebccd5607f0d879c5fefa4099ad3745876b12c6ac` |
| `delete_file` | `sha256:2612347acb2120ee10ac3afabb6ce5c3419655de1177c0eb5ffa8b604807ac8b` | `sha256:33a00d40ddc77177ddcdfc5ebccd5607f0d879c5fefa4099ad3745876b12c6ac` |
| `run_registered_check` | `sha256:be9d87d2421614573290ae73212327ba178442c3f259a16be9668eb635f9ae69` | `sha256:f983fdb597e22ecfb7a27a492d7e20fe197e65679796400b0816690401881893` |
| `run_governed_command` | `sha256:31d8174f18dca8a76e2c458574255c6f531d20cdc72bd37e7a8f47b58f70fd61` | `sha256:f983fdb597e22ecfb7a27a492d7e20fe197e65679796400b0816690401881893` |
| `show_candidate_diff` | `sha256:74b555d2b2d0a94f10e4e382d099de46d818c2a388b49bbe6ee503522a8d58cc` | `sha256:bb18f1a89129c5cb561607c95be05e21fadb69f43e4f1c18727938dc47fd9a0a` |
| `submit_candidate` | `sha256:b6b2533cf4aa9698542b3a10d151c783951219bdd5bc3d539cd9e971f90012e4` | `sha256:19ff83049e2dd788f2208d727f5adbb030fa3afca0224f1f8eac9998270ce500` |
| `request_clarification` | `sha256:0113e3a9d92bd90862aa3558a551971e166f5908995eca864e6e71a3a0f76f66` | `sha256:184dc716b0c9dcb3ebdf563924c68a6fa7fe51ada1ce81ca5624f25e64beb04b` |

Every definition additionally pins its capability, effect class,
preconditions, side effects, reversibility, bounded timeout and output,
retry/idempotency policy, approval rule, network policy, adapter identity and
digest, and closed safe-error vocabulary. Only the bounded name, version,
description, input schema, and schema digest project into model context.

Input validation converts only known string keys to existing atoms, rejects
unknown or missing properties, and then applies semantic authorization. Paths
must be normalized repository-relative paths under a capability prefix. Refs,
registered commands, and publication destinations must occur in the derived
allowlists. Edits require one exact match. No raw-shell tool exists; registered
commands keep executable, working directory, fixed arguments, environment,
network policy, and resource limits in server-owned configuration.

## Deterministic Proposals And Authority

`JidoCode.Factory.Tool.Proposal` converts only closed Jido-directive or model
tool-call envelopes into the same normalized proposal. Raw arguments exist only
in the transient value and are omitted from inspection and durable attributes;
the persistent projection contains the invocation and command references plus
deterministic proposal and argument digests. Classification and authorized
input refs participate in the proposal digest and remain attached to the
transient authorization decision; the tool invocation separately persists its
bounded refs and classified digests.

The policy governor intersects, never unions, lease, task, repository-policy,
and actor constraints. The resulting capability pins attempt, lease, task,
repository, actor, agent, profile, model, catalog, snapshot and graph revisions,
permitted tools, relative path prefixes, input and graph refs, registered
commands, network destinations, data classes, resource ceilings, credential
refs, expiry, monotonic fence, policy and revocation revisions, and a
deterministic idempotency namespace. Its only authority class is
`tool_execution`; requests for decision, acceptance, ontology, security-policy,
durable-memory, verification, or publication authority fail closed.

The reference monitor validates catalog input under the derived constraints and
requires the exact current invocation, lease state, policy revision, source
graph revisions, snapshot, fence, revocation generation, data class, refs,
resource ceilings, and approval evidence. It repeats the same decision
immediately before effect. The returned explanation contains no reusable token;
a live capability and current facts are always required for revalidation.

## Invocation-Before-Effect Commit

`JidoCode.Factory.ToolGateway` admits a closed proposal, constructs a bounded
request, and requires an accepted durable start receipt before it can call an
adapter. The Factory-owned Knowledge ledger uses only the public
`JidoCode.Knowledge` facade: one accepted start command contains the durable
`ActionProposal`, `ToolInvocation`, authorization provenance, and audit
metadata; one accepted outcome command records the bounded terminal status and
result. Neither command receives raw arguments, and receipt inspection conceals
the opaque invocation context.

Pre-admission rejection creates no start, outcome, or effect. After a committed
start, the gateway fetches current facts and repeats exact reference-monitor
validation. A race-time denial records a rejected no-effect outcome. Adapter
errors and corrupt results become a single safe failed outcome; a failed start
prevents dispatch, and an unavailable outcome commit is returned explicitly.
The durable authorization digest explains why the start was admitted but is not
accepted as effect authority: dispatch still requires the live capability and
immediate current-state revalidation.

## Verification Record

| Command or gate | Result |
| --- | --- |
| `phase_h03_tool_catalog_test.exs` | 8 tests, 0 failures |
| `phase_h03_policy_governor_test.exs` | 8 tests, 0 failures |
| `phase_h03_tool_gateway_test.exs` | 7 tests, 0 failures |
| Phase H03 harness through Section 3.3 | 23 tests, 0 failures |
| `mix compile --warnings-as-errors` | Pass |
| `mix architecture.check` | Pass |

## Gate HG3

HG3 is merge-pending and remains blocked. It reopens—or remains blocked—if any
host-controlled effect can bypass the reference monitor, any effect sink
accepts a stale fence, or any proposal or tool input shape remains open. These
reopening conditions remain in force regardless of checklist state.
