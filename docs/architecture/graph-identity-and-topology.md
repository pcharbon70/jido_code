# Graph Identity And Topology

## Resource Identity

`JidoCode.Knowledge.ResourceIdentity` is the only product resource IRI
constructor. It keeps product resources under `https://jido.run/id/`, named
graphs under `https://jido.run/graph/`, and ontology terms under
`https://jido.run/ontology/`.

Natural external identity constructors canonicalize provider hosts,
repository locators, Git object IDs, and content digests. A repository locator
is a provider route and is never the conceptual repository identity. Display
and interoperability IDs remain RDF literals and cannot be relationship join
keys.

Local activities, claims, goals, attempts, decisions, transitions, migrations,
and validation resources use opaque 128-bit IDs containing a 48-bit millisecond
prefix and 80 caller-supplied entropy bits. The pure constructor accepts both
inputs. The runtime helper makes clock and randomness explicit injectable
ports, so deterministic tests never depend on wall time or process randomness.

All constructors enforce NFC normalization, bounded lengths, encoded path
segments, known identity kinds and digest algorithms, traversal and control
character rejection, and RDF IRI validity. No user input is converted to an
atom.

## Graph Registry

`JidoCode.Knowledge.GraphRegistry` is a closed registry at revision `1.0.0`.
Application code cannot supply graph templates or writer capabilities.

| Family | Scope inputs | Mutability | Writer capability | Completeness | Retention |
| --- | --- | --- | --- | --- | --- |
| `ontology` | version | immutable | `ontology_release` | complete | permanent |
| `factory_catalog` | none | append/supersede | `catalog_writer` | complete | permanent |
| `factory_policy` | none | append/supersede | `policy_writer` | complete | permanent |
| `observation_batch` | repository, batch | immutable | `observation_writer` | complete | observations |
| `source_revision` | repository, Git revision | immutable | `source_writer` | complete | source history |
| `repository_control` | repository | append/supersede | `control_writer` | complete | control history |
| `run_attempt` | attempt | mutable until closed | `execution_writer` | building | run history |
| `evidence` | repository | append/supersede | `evidence_writer` | complete | evidence history |
| `memory` | repository | append/supersede | `memory_writer` | complete | knowledge history |
| `security_audit` | calendar month | append-only | `security_auditor` | complete | security audit |
| `derived` | rule-set, revision | replaceable | `reasoner` | complete | disposable |

Repository and local resource scope inputs become deterministic bounded graph
tokens. This preserves repository, batch, source revision, attempt, authority,
and retention boundaries without creating a graph per ordinary entity.

Each family declares allowed cross-family graph links. A semantic command must
hold the exact writer capability and obey lifecycle rules. Immutable ontology,
observation, and source graphs are created closed and cannot be appended.
Closed run graphs cannot be reopened. Derived graphs can be replaced because
they are disposable projections, not asserted authority.

The default graph and unregistered names are never accepted by the semantic
graph command. `WriteBatch` remains the private substrate mechanism used to
prove atomicity and recovery; the architecture checker rejects production
callers that construct or submit one outside approved semantic commands and
the ontology release loader.

## Graph Metadata

Every admitted graph contains statements about its own graph IRI. Creation
requires exactly one graph kind, owner scope, ontology release, creation
activity, creation time, lifecycle state, completeness state, graph revision,
and retention class. Immutable graphs also require closure time. Source,
lineage, rule-set, and source graph revision metadata is required when the
family contract calls for it.

`JidoCode.Knowledge.Commands.Graphs.prepare_create/5` compiles graph metadata
and payload into the same `WriteBatch`, with graph revision zero as the create
precondition. The metadata therefore cannot become visible separately from
the graph payload or its substrate receipt.

`JidoCode.Knowledge.Queries.Graphs.metadata/2` executes through the supervised
`QueryRunner` and the raw-handle-owning `StoreServer`. Its fixed bounded query
selects only statements whose subject is the graph IRI. It does not return
graph contents and has no mutation capability.
