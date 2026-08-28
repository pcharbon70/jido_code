# Repository Wiki Deterministic V1 User Guide

Repository Wiki turns an exact repository revision into a navigable,
attributable view of the project, its source areas, Mix identity,
dependencies, authored guides, accepted architecture material, and visible
known gaps. It is a derived knowledge product: Git, reviewed graph facts, and
fresh verification remain authoritative.

## Availability And Enrollment

Every repository starts **Off**, including newly enrolled coding projects.
Repository enrollment does not create a wiki, start a maintainer, reserve a
budget, or incur model-token cost.

An authorized repository operator may select:

- **Manual deterministic** — compile only after an explicit refresh request;
- **Automatic deterministic** — maintain after admitted source changes; or
- **Off** — admit no new wiki compilation or maintainer work.

Both enabled V1 modes use the same pinned deterministic compiler. Hosted
model synthesis, providers, prices, and production synthesis adapters are not
available. Existing readable editions and creation permission are separate:
turning creation Off does not silently delete history.

## Reading And Trusting A Wiki

Use the page trust header to check the repository, edition purpose, source
revision, freshness, completeness, compiler, and warnings. Authored guides,
deterministically extracted facts, accepted graph facts, live panels, and
known gaps retain distinct labels.

The wiki includes:

- project identity and visible unresolved `mix.exs` fields;
- direct and transitive dependency pages with declaration, lock, parent, SCM,
  scope, and safe-link provenance;
- repository-authored user, developer, contributor, operator, upgrade,
  security, release, ADR, research, and reference material;
- source-area navigation and citations to exact authorized revisions; and
- freshness, drift, incomplete coverage, and contradiction information.

A wiki page is useful context, not proof that a proposed code change is
correct and not authority to run a command, choose a tool, change policy,
access credentials, publish, or merge.

## Search, Previews, And Parallel Sessions

Search authorizes the selected repository before candidate generation and
returns only bounded page references from one exact edition. A slug, copied
link, dependency name, stale browser reference, or guessed identifier grants
no access.

Candidate previews are private to the exact repository, coding session,
attempt, candidate, audience, and fence. They never appear in ordinary
current-edition navigation, search, or default agent context. Parallel
sessions can have separate previews, but a reviewed source-fenced transition
can activate only one current edition.

## Cost And Resource Meaning

Deterministic V1 records exactly zero model calls, input/output/cached/
reasoning tokens, model reservations, and measured model cost. This does not
claim that CPU, storage, metadata retrieval, or operator time is free; those
local resources are reported separately where measured.

The `Usage & cost` view distinguishes exact zero, pending usage, unknown
liability, reservations, and currencies. A deterministic attempt reporting a
model token, model reservation, unknown model liability, or model cost is a
release-blocking incident.

## Opt Out, Retention, And Privacy

Disabling a repository commits an Off enrollment before cancellation. New and
late work is fenced; maintainers stop; deterministic model cost remains zero.
Current editions, usage, accounting, and audit history follow their separate
retention policies and are not corrupted by opt-out or rollback.

Repository content is treated as untrusted data. Product projections and
telemetry omit raw graph names, SPARQL, absolute checkout paths, credentials,
provider payloads, private dependency endpoints, and complete source bodies.
Unsafe markup is escaped or blocked, suspicious credentials are redacted, and
external links are admitted through fixed safe-link rules.

## Limitations And Help

V1 supports bounded Elixir single-application and umbrella repositories with
Hex, git, path, private, optional, and transitive dependency evidence. Dynamic
Mix expressions remain visible gaps unless a separately authorized fixed
sandbox observation exists. Oversized, malformed, unsupported, missing, or
private content stays explicit rather than being guessed.

For refresh, staleness, disable, recovery, or synthesis-unavailable incidents,
follow the [Repository Wiki V1 runbook](../operations/repository-wiki-v1-runbook.md).

