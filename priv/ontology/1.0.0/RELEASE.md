# Jido Factory Ontology 1.0.0

This immutable release establishes the first project vocabulary, graph
metadata vocabulary, controlled concepts, and SHACL-compatible operational
shapes. It is additive relative to the substrate-only store schema.

## Namespaces

- Ontology terms: `https://jido.run/ontology/factory#`
- Shape terms: `https://jido.run/ontology/shapes#`
- Controlled concepts: `https://jido.run/ontology/concept/`
- Product resources: `https://jido.run/id/`
- Named graphs: `https://jido.run/graph/`
- Immutable ontology version: `https://jido.run/ontology/factory/1.0.0`
- Immutable shapes version: `https://jido.run/ontology/shapes/1.0.0`

## Compatibility

This release is the semantic baseline. Later releases must classify changes
as additive-compatible, validation-only, behaviorally-stricter,
transform-required, or breaking. Existing term meaning is never changed in
place.

The standard vocabulary imports are declarative alignments. Runtime loading
does not fetch network resources and admits only the files and digests in
`manifest.json` into `https://jido.run/graph/ontology/1.0.0`.
