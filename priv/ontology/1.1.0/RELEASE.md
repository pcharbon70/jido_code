# Jido Factory Ontology 1.1.0

This additive release imports the immutable `1.0.0` semantic baseline and adds
the total-agent-memory resource vocabulary and SHACL shapes. The local release
loader composes the verified `1.0.0` schema sources into the `1.1.0` ontology
graph; it never resolves imports over the network.

The release defines `run_event_segment`, `experience`, `content_lifecycle`, and
`episode_content` graph-kind concepts plus shapes for capture manifests,
segment manifests, content captures, cases, procedures, artifact claims,
retrieval activities, lifecycle activities, access permits, and encrypted
content chunks.

Ontology terms are descriptive. `GraphRegistry` and `ShapeCatalog` remain the
closed executable placement boundary, and every new family is disabled at the
MG1 baseline. No resource in this package can grant capability, policy,
approval, evidence, decision, accepted knowledge, retrieval, or content
access.
