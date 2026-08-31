# ShadcnUI Adoption And Component Contract

- Status: Proposed under ADR 0010
- Specification version: `0.1.0`
- Owners: JidoCode web, design-system, supply-chain, security, and
  accessibility maintainers
- Milestones: B and C
- Decision: [ADR 0010](../adr/0010-shadcnui-as-product-component-primitive-layer.md)
- Inspected source:
  [`pcharbon70/shadcn_ui@78d3dfeb`](https://github.com/pcharbon70/shadcn_ui/tree/78d3dfeb56c269b81a2a74f6c0b7ce056393554d)

## Purpose

This specification defines the immutable dependency, asset, facade, semantic,
theme, overlay, browser, accessibility, and application-composite requirements
for consuming ShadcnUI as a primitive layer.

## Adoption Record

Before adding the dependency, record:

- canonical repository owner/name and immutable source commit/tag;
- archive/source and compiled stylesheet digests;
- package version, Elixir/Phoenix/Phoenix.Component constraints;
- license and explicit JidoCode usage authority;
- upstream CI run and qualification status;
- component index and public contract revisions;
- supported/observed browser versions and native feature requirements; and
- manual accessibility results or an explicit accepted risk.

Mutable branches and unaudited source substitutions are prohibited.

## Facade And Import Boundary

Only `JidoCodeWeb.Components.UI` and narrowly approved component modules import
ShadcnUI. The facade:

- gives wrappers stable JidoCode names and attrs/slots;
- preserves `Phoenix.Component.to_form/2`, `<.form>`, and the project `<.input>`
  contract;
- prevents `input/1`, `button/1`, and other import collisions;
- forwards only reviewed global/Datastar attributes to the intended element;
- assigns deterministic, unique DOM IDs to roots, relationships, and patch
  targets; and
- prevents a package primitive from selecting a route, command, scope, graph,
  or authorization outcome.

## Primitive Semantics

| Primitive | Allowed use | Prohibited use |
|---|---|---|
| Badge | Passive state/category label | Clickable command or sole status cue |
| Progress | Known bounded completion with meaningful max | Guessed agent progress |
| Meter | Scalar utilization with thresholds | Lifecycle stage |
| Alert | In-flow status requiring attention | Durable notification acknowledgement |
| Alert Dialog | Canonical high-consequence confirmation presentation | Authorization by itself |
| Dialog/Drawer/Popover | Bounded supplementary interaction | Permanent attempt workspace or privacy boundary |
| Media/motion | Optional explanatory presentation | Operational status or required notice |

## Application Composite Catalog

P0 application-owned components are:

- `FactoryShell` and `ProjectContextSwitcher`;
- `AttentionQueue` and `ProjectionStatusStrip`;
- `AgentFleetTable` and bounded filters/pagination;
- `AgentAttemptWorkspace`, `StageRail`, and `AttemptTimeline`;
- `CodeDiff`, artifact manifest, and `EvidenceMatrix`;
- `ScopedCommandDialog` and `CommandReceipt`;
- `GraphLens` plus accessible table/outline;
- `ProvenancePanel`; and
- `CostBudgetMeter`.

P1 includes sidebar/breadcrumbs, global search/navigation, dependency matrix,
project tree, security audit table, bounded charts, notification center, and
large-result virtualization.

## Assets, Tokens, And Themes

The exact compiled stylesheet is copied into the local controlled build,
fingerprinted, and imported in the qualified CSS order. Tailwind v4 imports and
source declarations remain intact. JidoCode owns typography and spacing;
package public variables cover qualified color/surface/focus/radius/motion
mapping.

The root sets synchronized resolved `data-theme` and
`data-shadcn-theme="light|dark"` values. Forced colors and reduced motion are
qualified independently of visual theme.

## Datastar And Overlay Composition

Rendered-contract tests prove the exact trigger/action element receives each
`data-on-*` attribute. Routine fragments do not replace native overlay roots,
focused forms, navigation, or scroll roots. A command patches a stable receipt
and explicitly chooses post-action focus.

## Qualification

The consumer test matrix covers exact-component HEEx rendering, escaping,
forms/errors, attribute forwarding, no CSS/JS fallback, CSP, themes, forced
colors, reduced motion, Dialog/Popover/invoker/anchor fallback, concurrent SSE
patches, keyboard, screen reader, 200% zoom, 320px reflow, touch, RTL, and the
actual supported Chromium/Firefox/WebKit/Safari-family versions.

## Acceptance And Reopening

Adoption remains blocked if namespace/license/usage authority is unclear, the
commit or stylesheet is mutable, CI is not green without accepted risk, the
dependency constraint conflicts, manual accessibility is unassessed, a facade
collision exists, or a product composition relies on unavailable package
state/JavaScript. The gate reopens on dependency, asset, API, semantic, browser,
or accessibility drift.
