# Hypermedia UI Milestone A Phase 1 Current-State Authority Receipt

## Status

This receipt records the HUI-A1 implementation candidate verified locally on
2026-09-02. The exact current-state authority, route/runtime/dependency,
identity, graph/query/command, readiness, research-gap, vocabulary, and
supersession inventories are implemented and enforced by architecture tests.

Status remains **merge-pending**. The implementation pull request must pass
clean-checkout CI and merge before a documentation-only closure may pin the
full merge commit and authorize Milestone A Phase 2. ADRs 0008 through 0011 and
the proposed hypermedia specifications remain nonbinding.

## Candidate Provenance

| Scope | Commit |
|---|---|
| Starting PR #100 baseline | `7c91977921c7b170d6def6bd390af93ddd4af09e` |
| Section 1.1 | `01ee499387d10affcc6b3f6734b3efe730387346` - pin authority and toolchain baseline |
| Section 1.2 | `da6a24696f28bdb325f806f757fb9038429ad5c7` - inventory runtime, semantic surfaces, readiness, and gaps |
| Section 1.3 | `a170b8db2bef399a11497107f9d0ebb7033bda28` - freeze vocabulary and supersession ownership |
| Section 1.4 | Merge-pending implementation commit containing this receipt |
| Merged candidate | Merge-pending |

## Inventory Identity

| Artifact | SHA-256 |
|---|---|
| Authority baseline manifest | `628bf1a57292417aa15f2c56316f118b1e740b742d91de66802b2bca2d7be1ab` |
| Runtime and authority inventory | `0bc748bd9d759628f26b80d83f884f291bfbbdadb89e30f17205d86183cc5991` |
| Vocabulary and supersession manifest | `fbebc762f759f820498006957660a3a38787b3cf91aeccb53cf67a129d6d9d02` |
| Authority baseline document | `47d84cdecc8509b17357b17df2ae5f38f836c3a799287055147158b7e89fdf3f` |
| Runtime inventory document | `ee410568e0a89ef42aa76fe15adce08de178166c418d8b74f3605e770b0225f3` |
| Vocabulary/supersession document | `b080282f7f8afa9e18da34d8c6d40b9dc9195018eb27f800666349fb41cb9813` |
| HUI-A1 validator source | `403b1bde2eaab3d6943e265698f479b9a678e430140adf0e7e2fd27d88948d55` |
| HUI-A1 integration test | `237f9c59d729fba369949f7c229818660cf88592264b268375f68b831a2f64df` |

The starting-candidate document tree contains 245 entries at digest
`4a538d6a02359fd536f7e4db7dfd97920ccdfb316e6346222b7b5a7f21038c44`.
The starting implementation/build tree contains 761 entries at digest
`ce73aad3e129592cd279148a70683bc52a27bd93395fc67d28231660c1b2909a`.
Both are reproducible from Git objects at the PR #100 merge commit.

## Accepted Current-State Evidence

- Eleven non-development product routes plus the authenticated development
  dashboard family have exact owners, state classification, authorization,
  readiness, replacement disposition, rollback consequence, tests, and
  operations evidence.
- The application, Knowledge, and Runtime supervision trees are pinned and
  compared with live OTP child IDs. Important non-supervised production seams
  are recorded explicitly.
- Client, SSR, CSS, LiveView, LiveVue, SaladUI, component, hook, Vite, and
  target-absent dependency consumers are owned.
- The current fixed operator mapping, session fields, authority construction,
  delegation absence, and revocation limit are explicit.
- Graph registry `2.5.0` exposes 17 families; command and query protocols
  `2.11.0` expose 117 semantic commands and 158 reviewed queries.
- Thirteen P0, nine P1, and two P2 research gaps each have an owner, blocking
  gate, required closure evidence, rollback consequence, and open status.
- Thirty-one canonical terms distinguish durable identities, ephemeral
  contexts, presentation values, commands, effects, evidence, decisions,
  readiness, and satisfaction.
- Seventeen supersession entries cover accepted presentation, security, wiki,
  identity, route, asset, dependency, test, operations, and receipt clauses
  using explicit preserve, supersede, amend, or defer dispositions.

## Verification Record

| Command or gate | Candidate result |
|---|---|
| Focused HUI-A1 manifest, route, supervision, registry, and falsification suite | 6 tests, 0 failures |
| Architecture plus operator authentication/session regression matrix | 28 tests, 0 failures |
| `mix architecture.check` | Passed; source guardrails, Git baseline reproduction, inventory schema, ownership, links, anchors, vocabulary, and supersession checks returned zero findings |
| `mix precommit` | Passed; 1,158 tests, 0 failures, with formatting, unused-dependency, compile, and architecture gates clean |
| Dependency audits and production asset build | Pending clean-checkout CI |
| Clean-checkout CI | Merge-pending |

## Discrepancies And Accepted Limits

- The runtime inventory has no delta from the PR #100 starting commit. Future
  changes before HUI1 must append an owned delta rather than rewrite starting
  hashes silently.
- This phase inventories and enforces current truth. It does not accept the
  proposed ADRs, implement named-human identity, adopt ShadcnUI, install
  Datastar/Dstar, or change a route.
- LiveDashboard remains an explicitly unresolved retain/remove decision.
- The current one-operator deployment, disabled DGA1 profile, incomplete
  default factory composition, and absent target hypermedia runtime remain
  visible limitations.
- Clean-checkout CI and the merged implementation SHA cannot be recorded until
  the implementation pull request completes.

## Gate HUI-A1

Status: **merge-pending**

HUI-A1 remains open until clean-checkout CI passes, the implementation pull
request merges, and a closure receipt pins the exact merge SHA and date.
Milestone A Phase 2 is not authorized from this merge-pending candidate.

HUI-A1 reopens regardless of checklist state if a current route, dependency,
asset, process, identity path, graph family, query, command, projection,
capability, test, document, operation, research gap, or supersession clause is
missing or unowned; a baseline digest is not reproducible; document status or
authority order is ambiguous; vocabulary conflates project, attempt,
`InteractionSession`, browser session, provider thread, runtime, process,
evidence, decision, completion, or satisfaction; a proposed contract silently
overrides accepted authority; a receipt is rewritten instead of preserved as
historical evidence; a target capability is advertised as composed without
release evidence; a route/runtime change bypasses the inventory delta rule;
the fixed-operator exception widens; a graph-only, authorization, secrecy,
fencing, wiki opt-in/cost, or no-autonomous-merge invariant weakens; or
architecture checks, documentation checks, precommit, or clean-checkout CI
fails at the exact candidate.
