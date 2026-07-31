# Factory Ontology Contract

## Release Boundary

The first immutable semantic release is `1.0.0`. Its digest-pinned sources,
manifest, and release notes live under `priv/ontology/1.0.0`. The loader parses
only those local sources, canonicalizes them as sorted N-Quads, verifies both
source and canonical digests, and writes every statement to
`https://jido.run/graph/ontology/1.0.0`. Imports are alignment declarations;
they are never fetched at runtime.

The namespaces deliberately separate concerns:

| Concern | Namespace |
| --- | --- |
| Versioned ontology | `https://jido.run/ontology/factory/1.0.0` |
| Project terms | `https://jido.run/ontology/factory#` |
| Operational shapes | `https://jido.run/ontology/shapes#` |
| Controlled concepts | `https://jido.run/ontology/concept/` |
| Product resources | `https://jido.run/id/` |
| Named graphs | `https://jido.run/graph/` |

`JidoCode.Knowledge.Ontology.Release` is a package reader and transient load
command builder. It is not a second ontology authority. `manifest.json` and
the canonical RDF statements are the reviewable release contract.

## Vocabulary Design

The ontology represents identity, knowledge, intent, execution, governance,
interaction, and actors as RDF resources and direct relationships. It aligns
entities, activities, agents, generation, use, derivation, association,
invalidation, and time with PROV-O. SKOS owns controlled concepts. Dublin Core
Terms is used for release labels, dates, and identifiers. SPDX is imported for
later software artifact assertions only when its published term semantics fit.

No class or predicate exists merely to encode an Elixir module, struct field,
enum atom, or storage codec. Elixir values passed to the loader are transient
command envelopes; graph identity and relationships remain RDF IRIs.

## Predicate Contract

Cardinalities below are operational guidance. Closed-world enforcement belongs
to the versioned shapes and validator, while ontology domain and range remain
open-world semantic guidance. `1` means exactly one for an admitted resource,
`0..1` means optional single value, and `*` means an open set.

| Predicate | Domain and range guidance | Cardinality | Provenance and graph ownership | Bounded query use |
| --- | --- | --- | --- | --- |
| `enrolls` | factory to enrollment | `*` | catalog, enrollment activity | factory enrollments |
| `manages` | enrollment to repository | `1` | catalog, enrollment activity | managed repositories |
| `locatedBy` | repository to locator | `*` | catalog, observation/enrollment | provider locations |
| `inScope` | scoped resource to scope | `1..*` | owning graph | scope filtering |
| `about` | claim, finding, or goal to resource | `1..*` | observation/control/evidence | subject context |
| `derivedFrom` | entity to source entity | `*` | immutable source/run or derived graph | lineage |
| `supports` | evidence or claim to claim/decision | `*` | evidence graph | support traversal |
| `contradicts` | claim/evidence to claim | `*` | evidence or memory graph | disagreements |
| `addresses` | goal to finding, claim, or outcome | `*` | control graph | intent gap |
| `decomposesInto` | goal to child goal | `*` | control graph | goal hierarchy |
| `dependsOn` | work resource to prerequisite | `*` | control graph | eligibility |
| `blocks` | work resource to blocked resource | `*` | control graph | blockers |
| `requiresCapability` | work to capability | `*` | policy/control graph | worker matching |
| `governedBy` | resource to policy | `*` | policy/control graph | effective policy |
| `executes` | attempt to task | `1` | run graph | task history |
| `evaluates` | verification to artifact, claim, or goal | `1..*` | run/evidence graph | verification evidence |
| `accepts` | decision to accepted resource | `*` | evidence/control graph | accepted facts |
| `rejects` | decision to rejected resource | `*` | evidence/control graph | rejected facts |
| `waives` | decision to waived resource | `*` | evidence/control graph | waivers |
| `satisfies` | evidence or decision to goal | `*` | evidence/control graph | goal completion |
| `supersedes` | new assertion to prior assertion | `*` | same authority family | current assertion |
| `claimedBy` | lease to actor | `1` | control graph | lease owner |
| `validFor` | grant, policy, or claim to scope | `1..*` | security/policy/evidence | scoped validity |
| `sourceActivity` | claim to activity | `1` | claim-owning graph | claim provenance |
| `graphScope` | claim to named graph resource | `1` | claim-owning graph | proposition scope |
| `epistemicState` | claim to SKOS concept | `1` | claim-owning graph | accepted/proposed views |
| `confidenceBand` | claim to SKOS concept | `0..1` | claim-owning graph | bounded confidence filter |
| `priorState` | transition to state concept | `0..1` | control graph | chain validation |
| `nextState` | transition to state concept | `1` | control graph | current state |
| `transitionSubject` | transition to governed resource | `1` | control graph | subject chain |
| `expectedPredecessor` | transition to transition | `0..1` | control graph | concurrency guard |
| `cause` | transition to causal resource | `0..1` | control graph | causal explanation |
| `decisionAuthority` | decision to actor | `1` | evidence/control graph | authority checks |
| `ontologyVersion` | named graph to ontology release | `1` | graph-local metadata | compatibility |
| `creationActivity` | named graph to activity | `1` | graph-local metadata | graph provenance |
| `ownerScope` | named graph to scope | `1` | graph-local metadata | authorization |
| `graphKind` | named graph to graph-kind concept | `1` | graph-local metadata | registry dispatch |
| `lifecycleState` | named graph to lifecycle concept | `1` | graph-local metadata | mutability gate |
| `completenessState` | named graph to completeness concept | `1` | graph-local metadata | visibility gate |
| `sourceRevision` | source graph to immutable Git identity | `0..1` | source graph metadata | snapshot lookup |
| `parentGraph` | named graph to predecessor graph | `0..1` | graph-local metadata | lineage |
| `sourceGraph` | derived/migration resource to source graph | `1..*` | derived/control metadata | reproducibility |
| `sourceGraphRevision` | derived graph to graph-revision reference | `1..*` | derived graph metadata | reproducibility |
| `targetGraph` | migration to target graph | `1..*` | migration activity graph | migration status |
| `sourceOntologyVersion` | migration to source ontology release | `1` | migration activity graph | migration audit |
| `targetOntologyVersion` | migration to target ontology release | `1` | migration activity graph | migration audit |
| `validationReport` | command/migration to report | `1` | audit/control metadata | admission evidence |
| `focusNode` | validation result to RDF node | `1` | quarantine/audit graph | issue location |
| `resultShape` | validation result to shape | `1` | quarantine/audit graph | constraint identity |
| `resultPath` | validation result to predicate | `0..1` | quarantine/audit graph | issue path |
| `severity` | validation result to severity concept | `1` | quarantine/audit graph | failure summary |
| `ruleSet` | derived graph to rule-set resource | `1` | derived graph metadata | reproducibility |
| `invalidationState` | derived graph to state concept | `1` | derived graph metadata | stale filtering |
| `canonicalLocator` | locator to normalized string | `1` | catalog graph | display/interoperability only |
| `displayId` | resource to external/display string | `*` | owning graph | display only, never joins |
| `contentDigest` | artifact to algorithm-qualified digest | `0..1` | source/run graph | immutable identity check |
| `confidenceValue` | claim to decimal in `[0,1]` | `0..1` | claim-owning graph | assessment, never acceptance |
| `recordedAt` | assertion to `xsd:dateTime` | `1` | committed graph | transaction-time query |
| `validFrom` | assertion to `xsd:dateTime` | `0..1` | owning graph | valid-time query |
| `validTo` | assertion to `xsd:dateTime` | `0..1` | owning graph | valid-time query |
| `sourceObservedAt` | observation to `xsd:dateTime` | `0..1` | observation graph | delayed observation |
| `subjectRevision` | transition to non-negative integer | `1` | control graph | causal ordering |
| `fencingToken` | lease to non-negative integer | `1` | control graph | stale worker rejection |
| `reason` | transition/decision to bounded string | `0..1` | control/evidence graph | operator explanation |
| `graphRevision` | named graph to non-negative integer | `1` | graph-local metadata plus substrate receipt | optimistic reads |
| `createdAt` | named graph to `xsd:dateTime` | `1` | graph-local metadata | lifecycle query |
| `closedAt` | named graph to `xsd:dateTime` | `0..1` | graph-local metadata | immutable closure |
| `retentionClass` | named graph to controlled string | `0..1` | graph-local metadata | retention selection |
| `sourceRevisionNumber` | graph-revision reference to non-negative integer | `1` | derived graph metadata | staleness check |
| `issueCode` | validation result to stable code | `1` | quarantine/audit graph | bounded diagnostics |
| `safeMessage` | validation result to bounded redacted text | `1` | quarantine/audit graph | operator diagnostics |
| `shapeVersion` | report/release to semantic version | `1` | ontology/audit graph | validator selection |
| `transformerVersion` | migration to immutable version | `1` | migration activity graph | replay/audit |
| `rollbackPosture` | migration to controlled posture | `1` | migration activity graph | recovery decision |
| `sourceCount` | migration to non-negative integer | `1` | migration activity graph | reconciliation |
| `targetCount` | migration to non-negative integer | `1` | migration activity graph | reconciliation |
| `credentialProvider` | credential reference to provider name | `1` | security graph | secret resolution |
| `credentialKey` | credential reference to opaque key | `1` | security graph | secret resolution |

There is intentionally no credential-value predicate. Graph relationships join
by canonical IRI; `displayId` and `canonicalLocator` literals are not identity
keys.

Direct statements are reserved for closed immutable graphs whose graph-level
provenance is sufficient. Consequential, disputable, temporal, assessed,
supported, contradicted, or superseded propositions are first-class claims.
Numeric confidence never implies acceptance; an accepted or rejected claim is
backed by an explicit decision relationship.

Derived source revisions use `GraphRevisionReference` resources linking a
source graph IRI to `sourceRevisionNumber`. They are not encoded tuple literals.

## Deterministic Operations

Run `mix jido_code.ontology verify` to parse and verify the current package,
`mix jido_code.ontology checksum` for bounded digest output, and
`mix jido_code.ontology canonical` for canonical N-Quads. The `load` command
uses the authoritative `Writer`, a deterministic commit identity, revision
preconditions, and replay recovery. It cannot select another graph or load an
unregistered source path.
