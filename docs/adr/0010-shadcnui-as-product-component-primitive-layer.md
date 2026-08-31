# ADR 0010: ShadcnUI As The Product Component Primitive Layer

- Status: Proposed
- Date: 2026-08-31
- Owners: JidoCode product, design-system, web, security, and accessibility
  maintainers
- Decision scope: Server component dependency, facade, styling, asset,
  accessibility, and supply-chain boundaries
- Depends on:
  [ADR 0008](./0008-server-rendered-heex-and-datastar-product-runtime.md)
- Research:
  [Secure hypermedia control plane](../research/12-secure-hypermedia-coding-factory-ui.md)
- Specification:
  [ShadcnUI adoption and component contract](../architecture/shadcn-ui-adoption-and-component-contract.md)

## Context

The selected component source is
[`pcharbon70/shadcn_ui`](https://github.com/pcharbon70/shadcn_ui), an independent
Phoenix/HEEx implementation rather than the React shadcn/ui library. At the
researched revision it provides forty-one stateless semantic components and a
compiled stylesheet, preserves appropriate Datastar attributes, and owns no
routes, JavaScript, state, authorization, persistence, or commands.

The package is not a complete factory UI. It lacks the data table, timeline,
diff, log, graph, sidebar, breadcrumbs, command/search, split-pane, chart, and
notification compositions needed by JidoCode. It is also an unqualified
`0.1.0` candidate with namespace/metadata drift, a proprietary license
identifier, no visible root license, incomplete manual accessibility evidence,
and an observed GitHub Actions startup failure.

## Decision

JidoCode will use a qualified immutable revision of `pcharbon70/shadcn_ui` as a
semantic presentation **primitive layer** beneath application-owned product
components.

1. The dependency is pinned to an exact reviewed commit or immutable release,
   with recorded source, digest, license/usage authority, CI, and qualification
   evidence.
2. JidoCode retains `JidoCodeWeb.Components.UI` as a narrow facade. Product
   pages do not scatter broad `use ShadcnUI` imports.
3. Wrapper names and APIs resolve collisions with project core components such
   as `input/1` and `button/1` and preserve the established `to_form` and
   `<.input field={@form[:field]}>` form contract.
4. JidoCode owns factory composites, information architecture, routes, state,
   Datastar expressions, patch boundaries, authorization, commands, and
   recovery.
5. The exact compiled package stylesheet is copied into the controlled asset
   build, fingerprinted, and delivered locally through the permitted CSS
   bundle. No CDN or mutable remote asset is used.
6. JidoCode maps color, surface, focus, radius, and motion tokens to the package
   public variables. Typography and spacing remain application-owned.
7. Resolved `light` or `dark` values synchronize JidoCode `data-theme` and
   ShadcnUI `data-shadcn-theme`. `system` is a preference to resolve, not a
   package theme value.
8. Components retain their native semantics: Progress represents genuine
   bounded completion, Meter represents scalar utilization, Badge is passive,
   and decorative media/motion never carries operational status.
9. Native overlay roots are stable patch boundaries. Routine SSE changes patch
   children or siblings and preserve open/focus/form/scroll state.
10. Application compositions pass their own browser, keyboard, screen reader,
    zoom, touch, RTL, reduced-motion, forced-colors, CSS-disabled, and no-script
    qualification; upstream primitive evidence is not inherited as product
    certification.

## Consequences

### Positive

- JidoCode gains a coherent semantic HEEx primitive set aligned with the
  server-rendered target;
- native HTML, no package JavaScript, local CSS, and graceful fallback reduce
  runtime and CSP surface;
- the facade insulates product semantics from upstream API changes; and
- application-owned composites can reflect factory authority instead of
  forcing generic component metaphors.

### Costs And Constraints

- adoption is blocked until repository identity, usage rights, CI, dependency
  compatibility, and accessibility risk are resolved;
- current SaladUI delegates and assets require migration;
- missing operational components require JidoCode design and testing;
- native browser capabilities and fallbacks must be qualified against the
  actual supported matrix; and
- ShadcnUI currently requires `phoenix_live_view ~> 1.2` for
  Phoenix.Component, while JidoCode pins `~> 1.1`.

## Alternatives Rejected

- **Use React shadcn/ui:** it is not the user-selected Phoenix/HEEx library and
  would introduce a client application stack.
- **Treat ShadcnUI as the application framework:** it deliberately owns no
  state, transport, authorization, or factory patterns.
- **Import every component globally:** broad imports create name collisions and
  couple the product to upstream APIs.
- **Relabel a similar component to fill a gap:** Radio Panels are not Tabs,
  Dropdown Actions are not an ARIA menu, and Carousel is not a data selector.
- **Load package assets from a CDN:** this weakens provenance, CSP, rollback,
  and deterministic build control.
- **Claim WCAG conformance from automated primitive tests:** manual and composed
  product scenarios remain necessary.

## Compatibility And Rollback

The facade supports controlled coexistence while individual compositions move
from SaladUI/local components to ShadcnUI. A page cannot mix conflicting theme
or overlay ownership contracts. Removal of SaladUI occurs only after all
facade consumers, CSS sources, hooks, tests, and fallback behavior migrate.

Rollback selects the prior fingerprinted facade and stylesheet bundle. It does
not fetch a different upstream branch, widen imports, or preserve product state
inside a component library.

## Acceptance Conditions

This ADR may move to `Accepted` only when:

1. canonical namespace, immutable source, package digest, license/usage
   authority, dependency versions, and green CI evidence are recorded;
2. the Phoenix LiveView package-version conflict is resolved without adding
   LiveView product runtime;
3. a real JidoCode consumer proves Datastar attribute forwarding, forms,
   assets, themes, native fallback, and overlay patch behavior;
4. facade wrappers prevent name collisions and expose only intended product
   APIs;
5. the P0 application composite inventory has specifications and stable DOM
   identities;
6. the actual supported browser and manual accessibility matrix passes or has
   an explicit accepted risk posture; and
7. clean-checkout build, CSP, supply-chain, accessibility, and rollback
   evidence is pinned at the merged candidate.
