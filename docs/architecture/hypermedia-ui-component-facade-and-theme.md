# HUI-B2/HUI-C2 Component Facade And Theme Contract

## Facade Boundary

`JidoCodeWeb.Components.UI` is the application-owned boundary for the exact
ShadcnUI source selected in HUI-B1. HUI-C2 maintains the exact public catalog
`badge`, `button`, `checkbox`, `dialog`, `disclosure`, `field_input`, `form`,
`input`, `link`, `menu`, `radio_group`, `select`, `skeleton`, `status`, `table`,
`toast`, and `tooltip` under stable JidoCode names. Product modules do not `use
ShadcnUI` or reference its namespace. Existing SaladUI-only delegates remain
explicitly compatibility-only until HUI-H.

The qualified input is named `UI.field_input/1` so the project `<.input>`
contract remains unambiguous. `UI.input/1` delegates to that project contract,
while `UI.form/1` delegates to `Phoenix.Component.form/1`. They consume a
`Phoenix.HTML.FormField` created through `Phoenix.Component.to_form/2` and
render native form controls with ordinary submission and CSRF behavior.
Buttons and badges accept the existing closed legacy spellings but translate
them to the closed upstream atoms; arbitrary class/variant selection is
rejected. Links, forms, disclosures, tables, and dialogs keep useful native
behavior when JavaScript is absent.

`UI.menu/1` is a dropdown action list of ordinary links and buttons; it does
not claim the ARIA application-menu interaction model. `UI.tooltip/1` is only
a supplemental description for a complete native trigger. `UI.skeleton/1` is
decorative and relies on a visible loading label owned by its containing
region. The application-owned toast and status components communicate state
with visible text and structure in addition to color. A toast is transient
feedback, never a durable command receipt, delivery acknowledgement, or
authorization result.

Slots remain HEEx-safe, deterministic caller IDs are required for component
roots, and global attributes are forwarded only to the intended native
element. The qualification fixture proves exact `data-on:*` placement,
deterministic form relationships, unique component identities, and hostile-
content escaping. No primitive selects identity, scope, graph, authority,
route, command, or outcome.

## Adopted Primitive Diff Checklist

The selected ShadcnUI source remains commit
`fe40eae63504adc4375aead4f0e741f158a4d86e`; HUI-C2 changes no dependency
source. Each maintained facade entry has the following review boundary:

| Facade entry | Qualified or owned boundary | Required diff review |
| --- | --- | --- |
| `form` | Phoenix form | `to_form/2`, action/method, CSRF, globals, slots |
| `input` | project core input | field derivation, errors, options, naming collision |
| `field_input` | Shadcn input | label/help/error IDs, globals, pending and native states |
| `select` | Shadcn native select | option schema, selection, multiple name, native submission |
| `checkbox` | Shadcn checkbox | boolean sentinel, repeated values, checked state, relationships |
| `radio_group` | Shadcn radio group | fieldset/legend, option IDs, selection, native keyboard behavior |
| `button` | Shadcn button | closed variant/size, loading, disabled, accessible name, slots |
| `badge` | Shadcn badge | passive-only attributes, closed variants, visible meaning |
| `disclosure` | Shadcn accordion | native details/summary, keyed IDs, open state, slots |
| `dialog` | Shadcn dialog | native dialog, trigger/fallback, focus, dismissal, globals |
| `menu` | Shadcn dropdown actions | native actions, grouping, fallback, focus order, no ARIA-menu claim |
| `tooltip` | Shadcn tooltip | supplemental plain text, description merge, native trigger |
| `skeleton` | Shadcn skeleton | decorative tree, fixed geometry, reduced-motion behavior |
| `link` | application anchor | required identity/destination, native navigation, focus, globals |
| `table` | application table shell | caption, headers, bounded overflow, responsive caller contract |
| `status` | application live region | visible message, live priority, atomic state, stable identity |
| `toast` | application live region | visible title/body/icon, live priority, actions, non-durable meaning |

Every change to one of these entries renews its source/API diff, rendered
contract, accessibility assertions, and consumer review. Removal additionally
requires a deprecation cycle and migrated-consumer evidence. The conflicting
SaladUI skeleton and tooltip boundaries have no product consumers and remain
available only as deprecated `compatibility_skeleton/1` and
`compatibility_tooltip/1` migration names until HUI-H.

## Theme And Asset Order

The exact 54,389-byte ShadcnUI stylesheet is read from the immutable Git
dependency at `deps/shadcn_ui/priv/static/shadcn_ui.css` with SHA-256
`ed0768e9582e980f3fd1b3ca0076afc573fc269514f527aef9dc942d1f8e9f41`.
It is imported into the local application bundle after the required Tailwind
v4 and animation imports; application token overrides follow it. The locked
dependency is the source and the production bundle is the controlled copy.
There is no remote fallback and no `@apply` use.

Application surface, typography, spacing, layout, density, elevation, border,
focus, radius, motion, status, chart, code, and diff variables map into the
package's public `--shadcn-ui-*` variables. Status colors are presentation
tokens only; visible text, semantic structure, and icons carry meaning.

The server reads two closed, presentation-only cookies and emits the requested
`data-appearance` plus resolved `data-theme` and
`data-shadcn-theme="light|dark"` before the bundle executes. On a first system
visit, both resolved attributes are omitted and CSS resolves the operating-
system preference without script. The local theme module synchronizes all
three attributes and the controls, safely migrates the earlier `phx:theme`
preference, and refreshes the cookies when a system preference or another tab
changes. Invalid or unavailable persistence falls back to `system`; identity,
scope, grants, assurance, policy, revisions, or other authority values are
never stored.

The stylesheet includes explicit reduced-motion, forced-color/high-contrast,
RTL, print, coarse-pointer/touch-target, and narrow-screen behavior. Native
overflow, logical-direction rules, system fonts, and bounded widths preserve
320px reflow, 200% zoom, and localization growth. The deterministic render
fixture remains a visual and accessibility regression input for real-browser
qualification.

## Lifecycle

An escape hatch must be application-owned, narrowly reviewed, and cannot
directly import the upstream namespace or accept authority-bearing caller data.
Rollback reverts the HUI-C2 Section 2.1 commit and invalidates the changed
application source/asset digests; no data migration is involved.

The contract reopens on upstream revision or CSS digest drift, a broad import,
attribute/slot collision, unsafe HTML, duplicate identity, broken native
fallback, inaccessible focus/form/status behavior, a missing theme mode,
remote CSS/font/icon/script, authority-bearing browser persistence, or any
component-derived authority.
