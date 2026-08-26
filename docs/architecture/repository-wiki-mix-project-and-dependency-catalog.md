# Repository Wiki Mix Project And Dependency Catalog

- Status: Approved and normative under accepted ADR 0005
- Specification version: `0.1.0`
- Owners: JidoCode source-analysis, security, and documentation maintainers
- Decision: [ADR 0005](../adr/0005-repository-wikis-as-compiled-knowledge-projections.md)
- Compilation protocol: [Repository wiki compilation and update](./repository-wiki-compilation-and-update-protocol.md)
- HTTP boundary: Factory-owned metadata adapters use the existing `Req`
  dependency; repository code cannot choose another client or endpoint

## Purpose And Required Outcome

Every admitted Elixir project wiki MUST contain:

1. a general project page derived from the exact `mix.exs` and related pinned
   project inputs; and
2. a complete repository-scoped dependency index with one page or explicit
   gap for every admitted direct and transitive dependency in the resolved Mix
   graph.

The catalog answers what the project declares, what is locked, what Mix
actually resolves for each supported environment and target, why each
dependency is present, where its exact documentation and source live, and
which facts remain unavailable. It never treats `mix.exs` as safe data merely
because its syntax is Elixir.

## Threat Model

`mix.exs`, dependency project files, aliases, compilers, plugins, environment
reads, path dependencies, and package hooks are executable or attacker-
controlled input. Static parsing can consume hostile syntax and very large
terms. Dynamic evaluation can execute arbitrary code, traverse the filesystem,
read credentials, spawn processes, or reach the network.

Therefore:

- the host application MUST NOT call `Code.eval_*`, `Mix.Project.in_project`,
  a repository alias, dependency fetch, compile, or arbitrary `mix` command on
  an untrusted checkout;
- static parsing and normalization are bounded and execute no repository
  expression;
- dynamic introspection, when necessary, runs only inside the exact accepted
  production sandbox profile;
- repository-controlled output remains untrusted and is validated against a
  closed schema; and
- external metadata retrieval is a separate host-owned `Req` effect after
  link/endpoint policy, never network access from the repository sandbox.

## Input Manifest

The extractor binds at least:

- repository and exact Git tree/object identity;
- root and umbrella-child `mix.exs` relative paths and content digests;
- exact `mix.lock` path and digest, or explicit absence;
- admitted `elixir`, `erlang`, `otp`, and Mix toolchain image/revision;
- supported Mix environments and targets from Factory policy;
- environment-name/value allowlist with values redacted from durable output;
- static extractor, lock parser, resolver, sandbox, network, metadata adapter,
  and link-policy revisions;
- dependency/path/file/count/byte/AST/process/memory/disk/time/output/network
  bounds; and
- source visibility, tenant, credential class, lease, and fence.

The repository cannot change these inputs through a project function, alias,
config file, prompt, prior wiki, or dependency metadata.

## Extraction Phases

### Static Project Parse

The first phase reads bounded project files and uses pinned
`Code.string_to_quoted/2` plus explicit AST traversal. It does not macro-
expand, compile, load, or evaluate the AST.

It extracts literal and structurally provable fields from `project/0`,
`application/0`, `deps/0`, aliases, preferred CLI environment declarations,
and umbrella configuration. It records every field as:

- `static_exact` — fully determined from allowed literals and closed forms;
- `static_partial` — some alternatives or values are unresolved;
- `dynamic_required` — evaluation is required for the admitted semantic
  result;
- `unsupported` — valid project behavior outside this profile; or
- `invalid` — malformed or policy-forbidden input.

Allowed static normalization includes literal lists, tuples, maps, keywords,
atoms from source as bounded strings, booleans, numbers, binaries, module
aliases, simple local variable binding, and closed list concatenation when all
operands are statically known. It never creates new atoms from extracted
strings.

Function calls, system/environment reads, file reads, imports, macros,
comprehensions, arbitrary conditionals, remote calls, and unknown expressions
remain unresolved unless a future extractor revision explicitly proves a safe
form.

### Lock Parse

The lock parser reads exact committed `mix.lock` data under a pinned safe
parser profile. It extracts only supported Hex and Git lock tuple shapes into
bounded neutral values. It rejects executable expressions, unexpected term
shapes, unknown digest algorithms, excessive nesting, duplicates, and
unbounded values.

Lock data proves committed resolution identity, not dependency use, current
advisory status, successful build, or registry trust. A lock entry with no
resolved parent is retained as an orphan finding rather than silently added to
the project graph.

### Sandboxed Mix Introspection

When policy requires a complete semantic result and static extraction is
partial, the controller MAY run one fixed introspection adapter in an isolated
worker. The adapter is part of the signed JidoCode image and accepts no
repository-supplied command, module, task, alias, argument, executable,
configuration directory, plugin, tool, or endpoint.

The sandbox MUST have:

- a read-only exact repository tree plus separately disposable writable
  scratch;
- no host source tree, application data, sockets, Docker daemon, SSH agent,
  provider cache, user home, credential, or publication token;
- denied network and DNS;
- an unprivileged identity, isolated process/IPC/network/mount namespaces,
  read-only runtime image, and no privilege escalation;
- a minimal fixed environment with no ambient secrets;
- pinned Elixir/Erlang/Mix versions and checksum-verified preloaded dependency
  metadata needed by the accepted profile;
- finite process, CPU, memory, disk, file, output, and wall-time limits; and
- controller-enforced cancellation and descendant cleanup.

The operation evaluates only enough project semantics to return the closed
introspection schema. It does not run aliases, fetch dependencies, compile the
project, start the application, run tests, execute releases, or contact a
package registry. If Mix cannot establish the result without one of those
actions, the result is explicit `unsupported` or `incomplete`.

Sandbox success proves only the returned bounded observation under that exact
image and environment. It does not make repository code trusted.

### Resolved Dependency Traversal

The resolver combines declared dependencies, lock identities, umbrella/path
relationships, and authorized Mix observations into a graph per supported
environment and target. It includes optional dependencies only when admitted
by the selected environment/target semantics and records exclusions
explicitly.

Traversal is cycle-safe and deterministic. It records the complete parent set
and direct/transitive status. Human-facing “why present” paths are the
lexicographically canonical bounded shortest root paths; the full parent set
remains available through a bounded query. Truncated parents or paths are
marked, never represented as complete.

## Project Overview Schema

The general project page records each available field, value, source location,
authority class, and extraction outcome. Initial fields are:

| Group | Fields |
| --- | --- |
| Identity | Mix app, project name/display name when declared, version, umbrella root/child, source snapshot |
| Runtime | required Elixir version expression, admitted OTP/Mix toolchain, applications, extra applications, application callback/module |
| Build | build path, source/test paths when statically safe, compilers, start-permanent posture, build embeddings, consolidation posture |
| Quality | aliases by name only, preferred CLI environment, test coverage tool name, dialyzer/docs/package task metadata when declared |
| Package | description, package name, licenses, maintainers, included files, links, organization, source reference |
| Documentation | docs configuration metadata, main page, source URL/ref, extras, groups, canonical docs destination when verified |
| Repository | provider, canonical locator, default branch observation, exact immutable source link |
| Dependencies | counts by direct/transitive, environment, target, SCM, resolution state, metadata/link completeness, and findings |

Executable functions, secret environment values, absolute sandbox paths, raw
ASTs, arbitrary aliases, arbitrary compiler arguments, and unbounded project
terms are not persisted.

A project field can have multiple environment/target observations. The page
does not flatten conflicting values into one guessed answer. Fields absent
from `mix.exs` remain absent or `not_declared`; they are not populated from a
package registry as though authored by the project.

## Dependency Use Schema

One `WikiDependencyUse` represents one dependency name in one repository
edition, with environment/target variants as child observations. Required
fields are:

| Field | Contract |
| --- | --- |
| Repository and edition | Exact owner partition and immutable wiki edition |
| Name | Bounded normalized Mix dependency name as data, never a runtime atom |
| Role | `direct`, `transitive`, or both across variants |
| Environments and targets | Complete admitted membership and explicit exclusion/unknown states |
| Requirement | Direct declared requirement text and exact `mix.exs` locator when available |
| Optional/runtime flags | Exact observed values per variant |
| SCM | `hex`, `git`, `path`, `umbrella`, or explicit unsupported class |
| Resolution | Exact package/version/checksum, Git URL/ref/object, or path/umbrella identity as appropriate |
| Parents | Complete bounded parent set plus canonical root paths and truncation state |
| Lock provenance | Exact lock digest/entry identity or explicit unlocked/path state |
| Project use | Bounded links to source modules/calls/config or explicit not-analyzed state |
| Package metadata | Description, licenses, retirement state, owners only if policy admits them, observation identity, observed/expiry time |
| Links | Verified typed destinations defined below |
| Security reference | Advisory query/link observation and freshness; never an automated decision |
| Completeness | `complete`, `partial`, `unsupported`, `unauthorized`, `unavailable`, or `contradicted` with issues |

Dependency identity is repository-scoped usage, not merely package name and
version. Two repositories may use the same package without sharing visibility,
parents, purpose, findings, or wiki page identity.

## Link Contract

Every dependency page attempts to provide the following typed destinations
when they exist and policy permits:

- package landing page;
- exact-version documentation;
- exact immutable source revision or archive;
- declared homepage;
- changelog or exact release notes;
- issue tracker;
- license text/source;
- package retirement/deprecation notice; and
- advisory/security information.

Links are generated or accepted only from one of these sources:

1. a closed deterministic template owned by the metadata/link profile for a
   verified Hex package and exact version;
2. a canonical provider URL constructed from a verified repository and exact
   immutable object;
3. a repository-authored `mix.exs` package/docs link with explicit authored
   provenance; or
4. a host metadata observation fetched from an allowlisted endpoint and
   validated as an allowed scheme, host, path class, and redirect chain.

The compiler MUST NOT invent a URL from a dependency display name, model
output, search-engine result, unverified README badge, or arbitrary package
payload. Only `https` links are presented by default. Credentials, query
secrets, fragments containing unsafe data, loopback/private-network targets,
userinfo, nonstandard schemes, and open redirects are rejected.

Exact-version documentation is preferred over `latest` or unversioned docs.
When it cannot be established, the page states `exact_docs_unavailable` and
may separately show a verified project documentation link labeled as not
version-pinned.

## External Metadata Adapter

JidoCode owns a closed adapter registry. The initial Hex adapter uses `Req`
with:

- fixed allowlisted HTTPS origins and endpoint templates;
- resolved dependency identity supplied as typed data;
- connection, redirect, response-byte, decompression, JSON-depth, field-count,
  total-request, and wall-time bounds;
- SSRF defenses before connection and after every redirect;
- TLS verification and no repository-supplied certificate policy;
- explicit user agent and bounded retry only for safe requests;
- response content-type/schema validation;
- cache identity including provider, endpoint revision, package, version, and
  authorization class; and
- invocation/effect/result provenance with observed and expiry times.

Raw registry payloads, response headers, cookies, access tokens, and verbose
errors are not wiki content. Only admitted normalized fields and payload
digest/provenance enter the graph. Cache is an optimization; an expired cache
cannot silently claim current metadata.

No metadata adapter may use `:httpc`, HTTPoison, Tesla, a repository-defined
client, or an endpoint taken directly from untrusted content.

## Project Use And Source Links

When the accepted source-analysis profile provides dependency relations, the
page links a dependency to bounded examples of:

- modules that call or alias its public modules;
- OTP application membership;
- configuration files/keys by safe relative path and key name;
- Mix aliases/tasks that name it without exposing arbitrary command bodies;
- tests or support modules that use it; and
- direct parents that introduce it.

These are syntactic/observational “uses,” not proof of runtime reachability.
Each has an exact source citation. Absence means `not_observed` under a named
coverage profile, not “unused.”

## Special Dependency Classes

### Hex

Hex dependencies require package, exact locked version, registry/checksum
identity when supplied by the lock, and metadata observation or explicit
unavailability. Package and documentation links use exact-version templates.

### Git

Git dependencies require canonical repository locator and exact immutable
object. A branch, tag, or ref is retained as declared intent but cannot replace
the resolved object. Mutable-source-only resolution is incomplete and may be
blocking under policy.

### Path And Umbrella

Path dependencies are resolved only within the exact repository boundary and
accepted normalized relative paths. Symlink/traversal escape is invalid.
Their pages link to the repository wiki page for the target child project,
not an invented external package page.

### Private Packages And Repositories

Private metadata and links retain repository/tenant authorization and are
never moved into a fleet-global cache or index. The product uses opaque
references and concealment-oriented errors. Missing authorization is
`unauthorized`, not `not_found`, and reveals no package/repository existence.

### Optional, Dev, Test, And Target-Specific Dependencies

The catalog shows scope explicitly and permits filtering, but the complete
edition manifest includes every dependency admitted for every supported
environment and target. Production-only navigation cannot cause dev/test
dependencies to be omitted from completeness accounting.

## Advisories And Licenses

Advisory and license data are time-scoped observations. A wiki may show an
exact advisory identifier, affected range, observed status, and authoritative
link. It cannot decide exploitability, remediation, release acceptance, policy
compliance, or legal interpretation. Those require separate governed evidence
and decision workflows.

No advisory result means `not_observed`, `unavailable`, or a structured
`none_reported` observation with provider and time as appropriate—never a
claim that no vulnerability exists. License metadata retains its source and
conflicts with repository license files remain explicit.

## Completeness And Failure

The dependency catalog is complete only when:

- every supported environment/target was evaluated or explicitly unsupported;
- every resolved node has exactly one repository-scoped dependency page;
- every direct declaration maps to a resolved node or explicit finding;
- every admitted lock entry maps to a node or explicit orphan finding;
- every node has its parent set and bounded root-path completeness state;
- every SCM has the required exact resolution fields or an explicit gap;
- every required link type has a verified link, does-not-exist observation,
  or explicit unavailable/unauthorized/unsupported state; and
- all counts agree across project overview, dependency index, page manifests,
  and lint.

Metadata provider failure does not erase locked dependency truth. It produces
stale or unavailable metadata and link states. Static/sandbox disagreement is
`contradicted` and blocks a complete current edition until policy resolves or
explicitly admits the limited profile.

## Update Rules

- `mix.exs` digest change invalidates project metadata, direct dependency
  intent, environment/target semantics, and the complete resolved graph.
- `mix.lock` digest change invalidates exact resolution, transitive graph,
  checksums, source objects, and exact-version links.
- toolchain, environment allowlist, sandbox, resolver, or extractor change
  requires a new observation and compiler profile.
- source-analysis change may refresh project-use links without changing
  resolution identity.
- external metadata expiry schedules a metadata/link refresh; it does not
  require re-evaluating repository code when all source inputs are unchanged.
- visibility or credential change reauthorizes and may conceal private
  metadata immediately.

Every update creates a new wiki edition. It never edits the active dependency
pages in place.

## Required Queries

Reviewed queries MUST support:

- complete dependency index by repository edition;
- dependency detail by opaque page reference;
- direct parents and bounded canonical root paths;
- environment/target membership;
- dependency source-use examples;
- link/metadata freshness and findings;
- project overview fields with provenance; and
- privileged extraction diagnostics without raw code, secrets, sandbox paths,
  or unbounded provider payloads.

All queries authorize repository and tenant scope before matching package
names. A package name search cannot reveal which private repository uses it.

## Conformance Corpus

The implementation MUST test projects containing:

- a simple literal `mix.exs` and complete Hex lock;
- umbrella children and internal path dependencies;
- direct, transitive, optional, dev, test, prod, and target-specific edges;
- Git refs with exact objects and mutable-only failures;
- private packages and authorization loss;
- dynamic functions, environment reads, imports, aliases, macros, and hostile
  project code;
- malformed, huge, cyclic, duplicate, orphan, and unknown lock entries;
- dependency cycles and parent/path truncation;
- missing package metadata, retired packages, broken docs, redirects, SSRF
  destinations, oversized JSON, and provider outage;
- conflicting package/project license and homepage data;
- stale fences, timeout, cancellation, sandbox crash, descendant escape, and
  ambiguous results; and
- two repositories using the same dependency under different visibility and
  version scopes.

Tests MUST demonstrate no host code execution, network or credential access
from the sandbox, no fabricated project/dependency field or link, exact count
agreement, deterministic ordering/digests, and zero cross-repository metadata
disclosure.
