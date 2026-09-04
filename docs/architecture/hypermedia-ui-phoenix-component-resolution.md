# HUI-B2 Phoenix Component Resolution

## Decision

HUI-B2 resolves the HUI-B1 candidate to Phoenix 1.8.11, Phoenix.HTML 4.3.0,
Phoenix LiveView 1.2.9, ShadcnUI at
`fe40eae63504adc4375aead4f0e741f158a4d86e`, and Dstar 0.2.0. Every selected
input is exact. ShadcnUI is a Git dependency at the reviewed commit; Dstar and
the Phoenix packages use exact Hex constraints and lock checksums.

Phoenix LiveView is retained because `Phoenix.Component` is distributed in
that package and because existing compatibility-only product code still uses
LiveView. This phase does not authorize a new LiveView route, socket, process,
event, stream, hook, or state owner. Dstar is loaded in the release but no
Dstar Page, Router, Component, Dispatch, Scripts, StreamRegistry, or product
transport consumer is introduced.

## Solver Resolution

The first exact solve correctly selected the HUI-B1 graph but demonstrated
that SaladUI 1.0.0-beta.3 does not compile with the LiveView 1.2.9 HEEx
tokenizer. The stable SaladUI 1.0.0 release is therefore pinned exactly. It
declares LiveView `~> 1.2`, fixes the invalid breadcrumb markup, preserves the
existing compatibility boundary, and avoids a local fork or implicit
override. Its removal remains governed by HUI-H.

Hex also proposed unrelated Phoenix.PubSub 2.3.0 and Spitfire 0.4.1 upgrades.
All selected constraints admit the already-qualified 2.2.0 and 0.4.0
resolutions, so their accepted lock entries are retained. No override was
added. The authoritative edge list and exact decisions are recorded in
`phase_b2_dependency_graph.json`; the resolved dependency inventory is in
`phase_b2_resolved_sbom.json`.

## Compile, Runtime, And Release Evidence

`mix deps.get` is stable with the checked-in lock, and
`mix compile --warnings-as-errors` completes. A production release assembles
with Dstar 0.2.0, ShadcnUI 1.0.0, SaladUI 1.0.0, and Phoenix LiveView 1.2.9.
Starting that release with isolated temporary graph storage returns
`{:ok, applications}` for `:jido_code`; its expected pre-asset warning about a
missing digest manifest is closed by Section 2.3.

ShadcnUI and Dstar declare no registered application processes. Dstar's
StreamRegistry is not started by JidoCode. A diff against the accepted HUI-B1
baseline shows no endpoint, router, application-supervision, or product
consumer change in this section.

## Upgrade, Rollback, And Exceptions

The upgrade requires no data or graph migration. Rollback reverts the Section
2.1 commit and restores the accepted HUI-B1 lock; Section 2.1 changes no
browser asset or cache identity. The stable SaladUI pin must remain until its
existing consumers are migrated under their accepted removal gate. There are
no HUI-B2 dependency exceptions.

Any version, Git revision, Hex checksum, dependency edge, application-loading
behavior, or consumer boundary drift reopens this decision. Compilation,
release startup, a new LiveView or Dstar product consumer, an implicit
override, or a local/unreviewed fork also reopens it.
