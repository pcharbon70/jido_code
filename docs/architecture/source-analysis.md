# Source Analysis Boundary

Source analysis consumes an exact, disposable Git worktree and emits RDF for a
single repository snapshot. The analyzer has no store handle and no command
authority. Publication is a separate Knowledge command that validates and
atomically closes the revision-scoped source graph.

## Analyzer Choice

Phase 6 uses Elixir's pinned `Code.string_to_quoted/2` parser and `Macro`
traversal instead of adding a source-intelligence dependency. The supported
profile is identified as `elixir-ast/1.0.0` and is therefore tied to the
repository's pinned Elixir toolchain. The profile extracts modules, public and
private functions, calls, dependencies, and common OTP behaviours without
compiling or executing source.

This choice keeps the initial extractor deterministic and auditable. A future
analyzer may add richer expression or Git-evolution semantics, but must use a
new analyzer version and configuration digest so its output cannot collide
with this profile.

## Bounds And Retention

Requests bound file count, individual and aggregate bytes, symbols,
expressions, emitted statements, and elapsed time. Symlinks and unsupported
file types are skipped, malformed files produce partial coverage, and limit
exhaustion stops analysis with an explicit warning or adapter error.

The RDF result contains identities, relative paths, digests, names, arities,
relations, coverage, and analyzer provenance. It excludes source bodies,
credentials, absolute checkout paths, and raw parser terms. Persisting source
literals requires a future explicit governed policy and a separately versioned
command contract.

## Publication Contract

The `PublishSourceGraph` command derives
`repo/{repository}/source/{snapshot}` through graph identity policy. It checks
the exact observation graph revision that introduced the snapshot, rejects
schema triples and noncanonical source entities, and commits graph metadata and
analysis output in one immutable create operation. Identical replay returns the
existing command outcome; divergent output under the same analyzer identity is
a conflict and requires a new analyzer version or configuration.
