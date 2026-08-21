# Total Memory Graph Topology

## Version And Activation Posture

Factory ontology and operational shapes `1.1.0` add the memory vocabulary over
the immutable `1.0.0` release. `GraphRegistry` `2.0.0` is the executable closed
topology. Both `1.0.0` and `1.1.0` ontology/shape pairs remain recognized for
honest legacy reads; mixed pairs and unknown versions are rejected.

`GraphRegistry` `2.4.0` activates `run_event_segment`, `experience`,
`content_lifecycle`, `episode_content`, and `memory_dataset` through their
accepted command lines. Phase 6 selected graph-native encrypted content after the pinned
benchmark passed every mandatory threshold. Content remains inaccessible
without the separately consumed gateway permit; graph-family activation alone
does not grant release authority.

## Closed Family Contracts

| Family | Scope and identity | Future writer | Lifecycle | Completeness | Retention | Owning gate |
| --- | --- | --- | --- | --- | --- | --- |
| `run_event_segment` | attempt plus integer segment `0..999999`; `/run/{attempt-token}/segment/{index}` | `execution_writer`; enabled only through commands `2.0.0` | create, append, close once; immutable after closure | building then complete/incomplete | `run_history` | MG2 candidate |
| `experience` | repository; `/repo/{repository-token}/experience` | `experience_writer` | append/supersede | complete | `experience_history` | MG4 |
| `content_lifecycle` | repository; `/repo/{repository-token}/content-lifecycle` | `content_lifecycle_writer` | append/supersede | complete | `content_lifecycle` | MG6 |
| `episode_content` | repository plus content identity; `/repo/{repository-token}/content/{content-token}` | `content_writer` | immutable create | complete | `governed_content` | MG6 |
| `memory_dataset` | cohort plus manifest identity; `/cohort/{cohort-token}/dataset/{dataset-token}` | `dataset_writer` | append/supersede | complete | `dataset_lifecycle` | MG7 |

The existing `run_attempt` root may link to event segments. A segment may link
to its attempt, predecessor segment, source/control context, evidence, and a
governed content object. Experience may cite source, run, segment, evidence,
and accepted-memory resources but cannot mutate them. Content lifecycle may
refer to a content object and its source history. Episode content can refer
only to its run/segment source, lifecycle, or its own chunk resources; it
cannot link directly into evidence or accepted knowledge. Security audit may
name all families. A memory-dataset graph may cite its authorization, exact
source lineage, content state, rows, export copies, lifecycle, and evaluation,
but contains no exported payload. Derived graphs remain disposable read
products.

Unknown graph identities, extra or missing scope keys, malformed segment
indexes, unknown classes, wrong writer capabilities, and unlisted link
directions fail closed.

## Resource Placement

| Resource | Admitted family |
| --- | --- |
| `CaptureManifest` | `run_attempt` |
| `SegmentManifest`, `ContentCapture` | `run_event_segment` |
| `ExperienceCase`, `ProcedureRevision`, `ArtifactClaim`, `RetrievalActivity`, `MemoryUseAssessment` | `experience` |
| `ContentLifecycleActivity`, `ContentLifecycleTransition`, `ContentAccessPermit`, `ContentAccessActivity`, `ContentAccessOutcome`, `ContentHold`, `ContentErasurePlan` | `content_lifecycle` |
| `EpisodeContent`, `ContentChunk` | `episode_content` |
| `MemoryDatasetManifest`, `MemoryDatasetRow`, `DatasetExportPermit`, `MemoryDatasetArtifact`, `DatasetLifecycleTransition`, `MemoryEvaluationRun` | `memory_dataset` |

The ontology also defines the required capture, segment, case, procedure,
claim, retrieval, lifecycle, permit, encryption, and chunk properties. SHACL
resources describe their minimum cardinalities and term kinds. The executable
`ShapeCatalog` placement remains authoritative at write admission.

None of these classes is a capability, policy, approval, evidence sufficiency
decision, governed decision, or accepted knowledge assertion. An ontology term
or graph link cannot promote a remembered item across those boundaries.

## Additive Release Composition

The local ontology loader verifies the digest-pinned `1.0.0` package, composes
only its schema sources into the `1.1.0` named ontology graph, then adds the
digest-pinned memory sources. It never resolves `owl:imports` over the network.
The `1.1.0` canonical digest therefore binds both the inherited baseline and
the new vocabulary while the original `1.0.0` graph remains independently
verifiable and immutable.
