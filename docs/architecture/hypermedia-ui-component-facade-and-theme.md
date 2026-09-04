# HUI-B2 Component Facade And Theme Contract

## Facade Boundary

`JidoCodeWeb.Components.UI` is the application-owned boundary for the exact
ShadcnUI source selected in HUI-B1. It exposes button, field input, link,
passive badge, table shell, native disclosure, native dialog, and live-status
primitives under stable JidoCode names. Product modules do not `use ShadcnUI`
or reference its namespace. Existing SaladUI-only delegates remain explicitly
compatibility-only until HUI-H.

The qualified input is named `UI.field_input/1` so the project `<.input>`
contract remains unambiguous. Both consume a `Phoenix.HTML.FormField` created
through `Phoenix.Component.to_form/2` and render inside native `<.form>`.
Buttons and badges accept the existing closed legacy spellings but translate
them to the closed upstream atoms; arbitrary class/variant selection is
rejected. Links, forms, disclosures, tables, and dialogs keep useful native
behavior when JavaScript is absent.

Slots remain HEEx-safe, deterministic caller IDs are required for component
roots, and global attributes are forwarded only to the intended native
element. The qualification fixture proves exact `data-on:*` placement and
hostile-content escaping. No primitive selects identity, scope, graph,
authority, route, command, or outcome.

## Theme And Asset Order

The exact 54,389-byte ShadcnUI stylesheet is read from the immutable Git
dependency at `deps/shadcn_ui/priv/static/shadcn_ui.css` with SHA-256
`ed0768e9582e980f3fd1b3ca0076afc573fc269514f527aef9dc942d1f8e9f41`.
It is imported into the local application bundle after the required Tailwind
v4 and animation imports; application token overrides follow it. The locked
dependency is the source and the production bundle is the controlled copy.
There is no remote fallback and no `@apply` use.

Application surface/color/focus/radius/motion variables map into the package's
public `--shadcn-ui-*` variables. JidoCode retains typography and spacing
ownership. The root begins with a readable light no-JS state. The theme module
synchronizes the requested `data-appearance` with resolved `data-theme` and
`data-shadcn-theme="light|dark"`, including system preference changes.

The stylesheet includes explicit reduced-motion, forced-color, RTL, and print
behavior. Native overflow and logical-direction rules preserve 320px reflow
and zoom behavior. The render fixture is the visual-regression input for later
real-browser qualification in HUI-B3/HUI-B4.

## Lifecycle

Wrapper changes require an upstream API diff, render/accessibility tests, and
consumer review. A wrapper removal requires deprecation plus migrated-consumer
evidence. An escape hatch must be application-owned, narrowly reviewed, and
cannot directly import the upstream namespace or accept authority-bearing
caller data. Rollback reverts the Section 2.2 commit and invalidates the
changed application asset digest; no data migration is involved.

The contract reopens on upstream revision or CSS digest drift, a broad import,
attribute/slot collision, unsafe HTML, duplicate identity, broken native
fallback, inaccessible focus/status behavior, a missing theme mode, remote
CSS, or any component-derived authority.
