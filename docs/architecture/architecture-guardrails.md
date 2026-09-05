# Architecture Guardrails

## Scope

`mix architecture.check` enforces ADR 0001, ADR 0002, and the module-boundary
map before tests run. It parses Elixir source into AST and scans presentation
source only for syntax that has no Elixir AST. Errors are sorted, capped at 50,
and include file, line, rule, and remediation-oriented context.

The default scan covers runtime Elixir under `lib`, HEEx templates, and
JavaScript, TypeScript, and Vue source under `assets`. The checker and Mix task
implementation are excluded because they must name prohibited patterns as
data. Dependencies, generated output, `_build`, `deps`, and test source are not
part of the production-source scan. Section 4 exercises prohibited test
fixtures directly through `check_sources/2`.

## Enforced Rules

The checker rejects:

- Ecto repositories/schemas, Ash resources, CubDB, LevelDB-style stores,
  Postgrex, Redis clients used as persistence, DETS, and Mnesia;
- direct RocksDB calls outside `JidoCode.Knowledge.Backend`;
- `TripleStore.open/2` outside `JidoCode.Knowledge.StoreServer` and any
  TripleStore access outside `JidoCode.Knowledge`;
- direct `TripleStore.update/2` outside the empty-store metadata bootstrap and
  the `Writer`-owned atomic compiler;
- unclassified filesystem write/copy/rename APIs;
- browser persistence other than the current digest-pinned `phx:theme`
  implementation in `assets/js/theme.js`; an authorized UI phase may advance
  that digest only with theme-contract evidence and hostile mutation tests;
- dependency directions prohibited by the accepted plane matrix;
- raw SPARQL in Factory, Runtime, Integrations, Web, HEEx, JS, TS, or Vue;
- generic entity/record/CRUD store modules; and
- JSON-derived structs with multiple foreign-key-shaped `*_id` fields.

The parser also rejects multiple modules in one file because a single caller
namespace is required for reliable ownership analysis.

## Filesystem Roles

Filesystem effects require an explicit `@architecture_file_role` and an owner
namespace:

| Role | Allowed owner | Meaning |
|---|---|---|
| `temporary` | `JidoCode.Runtime`, `JidoCode.Integrations` | Bounded scratch data whose deletion cannot lose product truth |
| `build_artifact` | `JidoCode.Runtime`, `JidoCode.Integrations` | Reproducible build output |
| `external_worktree` | `JidoCode.Runtime`, `JidoCode.Integrations` | Disposable Git/provider working material |
| `graph_backup` | `JidoCode.Knowledge` | Owner-coordinated checkpoint of the authoritative graph |
| `identity_authority` | `JidoCode.Identity` | Integrity-protected named-human account, authenticator-verifier, generation, and immutable security evidence authority |

The module must consume or persist the custom attribute so Elixir does not
report it as unused. The marker does not authorize arbitrary state: reviewers
and tests must still prove the file is reconstructable or is a graph
checkpoint. The identity authority role is limited to the HUI-C1 named-human
store: it cannot hold graph grants, product content, command authority, or a
browser-derived authorization decision. Adding a role requires changing the
checker and this contract.

## Public Knowledge Dependencies

Factory may depend on the root `JidoCode.Knowledge` facade and its `Commands`,
`Queries`, `Projections`, `Health`, and `Error` public namespaces. Web may use
only `Projections`, `Health`, and `Error`. Knowledge internals remain private to
Knowledge; Integrations and Runtime report through their owning ports and
Factory services.

Static checks cannot prove semantic authorization, graph completeness, or
runtime data flow. Those remain responsibilities of semantic command/query
tests and the Section 4 falsification suite.
