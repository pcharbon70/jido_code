# Hypermedia UI Milestone C Phase 2 Receipt

## Status

Status: **accepted-at-merged-candidate**

This receipt accepts HUI-C2 only at merged implementation candidate
`da7ab6a4478bb278aa31a7636fa92135843249ff`. Implementation pull request #119
passed the required clean-checkout verify and Dialyzer jobs and merged on
2026-09-05. This narrowly scoped closure transition pins that immutable
candidate and authorizes Milestone C Phase 3 subject to every reopening
condition below.

All HUI-B2/HUI-B4 and HUI-C1 reopening conditions remain cumulative and binding.
Nothing in this receipt weakens, replaces, or silently reinterprets them.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted HUI-C1 closure baseline | `73326538cefcc6b136cc96c621062f44f2346c24` - closure PR #118 |
| Accepted HUI-C1 implementation candidate | `4a6fa78443463a8c8cd8ed039119cef8ba6e3b1b` - implementation PR #117 |
| Accepted HUI-B4 dependency candidate | `63d2689321121775a46bf531d004ac4de44b81f2` - implementation PR #115 |
| Section 2.1 | `956f372796e6f5afee7a7f6c3838d1f8e694dc9e` - primitive facade, semantic tokens, themes, and accessibility modes |
| Section 2.2 | `b221e76df601dc1c9dae8eea837e060204e48a2c` - factory shell and navigation composites |
| Section 2.3 | `1f39ed57b7414e6ab944a2110efa993e48d5a5a5` - projection-state and factory-domain composites |
| Section 2.4 | `3569921642900e1651ed3efd9a6a2e6514d8efb4` - integration matrix, executable evidence, and receipt preparation |
| Implementation PR head | `3569921642900e1651ed3efd9a6a2e6514d8efb4` - implementation PR #119 |
| Merged candidate | `da7ab6a4478bb278aa31a7636fa92135843249ff` - merge commit for implementation PR #119 |

Merged candidate: `da7ab6a4478bb278aa31a7636fa92135843249ff`
Merge date: `2026-09-05`

## Section Gates

### Gate HUI-C2.1 - Primitive Facade And Semantic Theme

Status: **accepted-at-merged-candidate**

Section 2.1 closes only when every supported primitive is available through
the application-owned `JidoCodeWeb.Components.UI` facade; form, label, help,
error, slot, escaping, native fallback, and reviewed global-attribute behavior
is exact; variant, size, and state inputs are closed; and no product module
imports ShadcnUI directly. The application token layer must cover typography,
spacing, layout, density, elevation, border, focus, status, chart, and code/diff
semantics without encoding status by color alone.

The resolved system/light/dark theme must be server-first, flash-safe, safely
persisted as presentation preference only, CSP-compatible, and synchronized
across `data-appearance`, `data-theme`, and `data-shadcn-theme`. Reduced motion,
forced colors/high contrast, RTL, zoom/reflow, touch, print, and narrow-screen
behavior must be independently verified.

### Gate HUI-C2.2 - Factory Shell And Navigation Composites

Status: **accepted-at-merged-candidate**

Section 2.2 closes only when stateless HEEx components implement the skip link,
masthead, primary and utility navigation, project switcher, breadcrumbs,
attempt context, account/session actions, responsive disclosure, page header,
action region, filter/search shell, pagination, empty state, error summary,
maintenance/degraded banners, and footer/support metadata with stable DOM and
focus contracts.

Components may render only already-authorized presentation inputs. They do not
resolve a resource, select a route, inspect authority, union roles, infer a
grant from visibility, or retain scope. Inaccessible destinations are omitted
by the trusted caller, and ordinary anchors, forms, and disclosures remain the
native baseline. Future fragment roots are reserved without adding Datastar,
Dstar, SSE, or product LiveView delivery.

### Gate HUI-C2.3 - Projection And Factory-Domain Composites

Status: **accepted-at-merged-candidate**

Section 2.3 closes only when the projection status/trust API preserves the ten
canonical states and exposes safe revision, freshness, source, as-of,
completeness, contradiction, truncation, and retry explanations. Unauthorized
and unknown exteriors remain indistinguishable; unavailable and unauthorized
states clear protected rows rather than retaining stale content.

The application catalog must include trust header, attention card/list, health
summary, bounded fleet/project table, attempt summary, lifecycle and outcome
rails, budget meter, receipt/evidence link, and readiness badge compositions.
Tables and cards require bounded responsive alternatives, column priorities,
accessible sorting labels, pagination summaries, and explicit no-result
states. Hostile content, long labels, missing fields, high counts, narrow
layouts, keyboard use, screen-reader structure, and visual states remain part
of the gate.

### Gate HUI-C2.4 - Integrated Component Candidate

Status: **accepted-at-merged-candidate**

Section 2.4 closes only when representative full compositions cover the shell,
forms, navigation, every projection state, fleet tables, attempt summaries,
overlays, errors, and long or hostile content under every supported theme and
layout. Unique roots and focus targets, native and no-JavaScript behavior,
dependency/import isolation, production-fixture exclusion, and absence of
authority, graph queries, commands, inline/remote assets, and new product
LiveView/LiveVue/Vue/SaladUI consumers must be executable assertions.

Component, accessibility, visual, architecture, dependency, strict production
compile, repository-wiki capacity, and `mix precommit` evidence must pass
locally. Clean-checkout CI and merged-candidate provenance remain pending until
the implementation pull request exists and merges.

## Exact Supported Primitive Catalog

The HUI-C2 public facade catalog is exactly:

`form`, `input`, `field_input`, `select`, `checkbox`, `radio_group`, `button`,
`link`, `badge`, `table`, `disclosure`, `dialog`, `menu`, `tooltip`, `toast`,
`status`, and `skeleton`.

`form` preserves `Phoenix.Component.form/1`; `input` preserves the project
`JidoCodeWeb.CoreComponents.input/1` contract; and `field_input` remains the
distinct qualified ShadcnUI field boundary. `menu` is an ordinary native list
of links/buttons backed by Dropdown Actions and deliberately does not claim an
ARIA application-menu interaction model. `toast` is application-owned
transient visible feedback and never represents durable acknowledgement,
delivery, authorization, or semantic outcome. `status` owns bounded live-region
presentation. `table` and `link` retain native application-owned semantics.

Every primitive keeps stable deterministic identity, escaped content, closed
semantic variants, useful no-JavaScript behavior, and reviewed global
attributes on the exact intended native element. Caller classes may arrange
layout but cannot supply status, authority, hidden state, or an unreviewed
variant.

## Per-Primitive Dependency And API Diff Checklist

The selected ShadcnUI source remains commit
`fe40eae63504adc4375aead4f0e741f158a4d86e`; its exact stylesheet remains
SHA-256 `ed0768e9582e980f3fd1b3ca0076afc573fc269514f527aef9dc942d1f8e9f41`.
No upstream source or dependency update receives credit from this phase.

| Facade primitive | Owned implementation boundary | Required candidate diff evidence | Status |
| --- | --- | --- | --- |
| `form` | `Phoenix.Component.form/1` | Preserve `to_form/2`, native method/action, CSRF, slots, globals, and submit behavior | passed — facade native-semantics test and composed qualification native-form test |
| `input` | `JidoCodeWeb.CoreComponents.input/1` | Preserve project field/error/options API and avoid collision with ShadcnUI input | passed — facade catalog and complete field-association tests |
| `field_input` | `ShadcnUI.Components.Forms.Input` | Review exact attrs, field relationships, errors, globals, escaping, and source API | passed — facade catalog, field-association, and hostile-content tests |
| `select` | `ShadcnUI.Components.Forms.NativeSelect` | Review native submission, options, multiple state, relationships, fallback, and source API | passed — facade catalog, native-semantics, and JavaScript-disabled browser tests |
| `checkbox` | `ShadcnUI.Components.Forms.Checkbox` | Review boolean/repeated-value submission, hidden value, relationships, and source API | passed — facade catalog, native-semantics, and composed qualification tests |
| `radio_group` | `ShadcnUI.Components.Forms.RadioGroup` | Review fieldset/legend, exclusive choice, option IDs, keyboard behavior, and source API | passed — facade catalog, association, keyboard, and semantic-order tests |
| `button` | `ShadcnUI.Components.Foundation.Button` | Review closed variant/size translation, loading/disabled semantics, globals, slots, and source API | passed — facade catalog and open-ended-variant rejection tests |
| `link` | application-owned native anchor | Review destination ownership, current state, focus, globals, escaping, and no client router | passed — native-semantics, hostile-content, and JavaScript-disabled browser tests |
| `badge` | `ShadcnUI.Components.Foundation.Badge` | Review passive-only semantics, closed variants, non-color label, globals, and source API | passed — facade catalog, variant rejection, and non-color composition tests |
| `table` | application-owned semantic table | Review caption, headers, bounded overflow, slots, responsive alternative, and sorting labels | passed — projection catalog, high-count cap, semantic-order, and narrow browser tests |
| `disclosure` | `ShadcnUI.Components.Disclosure.Accordion` | Review native details/summary behavior, keyed IDs, focus, globals, slots, and source API | passed — native-semantics and keyboard-order tests in JS and no-JS profiles |
| `dialog` | `ShadcnUI.Components.Overlays.Dialog` | Review native root, invoker, fallback, initial/return focus, Escape, globals, and source API | passed — facade native-semantics and browser keyboard/focus-return tests |
| `menu` | `ShadcnUI.Components.Overlays.DropdownActions` | Review ordinary link/button semantics, grouping, fallback, focus order, globals, and source API; prohibit ARIA-menu claims | passed — facade native-semantics and browser keyboard/visible-action tests |
| `tooltip` | `ShadcnUI.Components.Overlays.Tooltip` | Review supplemental-only text, described-by merge, focus/hover fallback, escaping, and source API | passed — association, hostile-content, and browser semantic-name tests |
| `toast` | application-owned status/alert composition | Review live-region priority, visible title/content, non-durable semantics, actions, and non-color state | passed — facade catalog, hostile-content, and accessibility semantics tests |
| `status` | application-owned live region | Review polite/assertive use, atomic updates, non-color message, stable identity, and bounded content | passed — facade association and projection non-color tests |
| `skeleton` | `ShadcnUI.Components.Foundation.Skeleton` | Review decorative-only loading geometry, surrounding visible label, reduced motion, and source API | passed — facade catalog plus reduced-motion and semantic browser matrix |

The completed candidate must replace every `merge-pending` status above with
an exact test, rendered-contract, or source/API-diff reference. A wrapper
addition, change, or removal without renewed evidence reopens HUI-C2.

## Canonical Projection States And Alias Policy

The exact canonical projection-state vocabulary is:

1. `ready`;
2. `empty`;
3. `stale`;
4. `incomplete`;
5. `contradicted`;
6. `truncated`;
7. `unauthorized`;
8. `unavailable`;
9. `maintenance`; and
10. `recovery`.

Compatibility and view-model vocabulary is normalized before rendering:

- `partial` maps only to `incomplete`;
- `contradiction` maps only to `contradicted`;
- `concealed` or `denied` maps to the `unauthorized` exterior and never adds a
  protected target label, count, reason, or retry;
- `unconfigured` maps to `unavailable`, with an unconfigured explanation only
  when that posture is independently authorized for the enclosing surface;
- `loading` is a separate connection/composition state and never claims a
  durable projection result; and
- undifferentiated `error` maps to `unavailable` unless trusted server state
  selects the narrower `maintenance` or `recovery` outcome.

Rendered canonical state attributes use only the ten values above. Aliases are
not additional truth states, do not weaken concealment, and cannot preserve
rows. Connection state and command state remain separate from projection
state.

## Theme, Token, Asset, And Accessibility Evidence

| Evidence | Required result | Candidate result |
| --- | --- | --- |
| Application token catalog | typography, spacing, layout, density, elevation, border, focus, status, chart, and code/diff semantics pinned by source digest | passed — token/source contract test plus pinned `app.css` digest below |
| Qualified Shadcn mapping | local immutable stylesheet, qualified variable mapping, Tailwind v4 import order, and no `@apply` | passed — facade source/API and architecture boundary tests |
| Theme resolution | server-first system/light/dark resolution with synchronized root attributes and no visible theme flash | passed — controller theme test and five-profile browser persistence matrix |
| Preference persistence | closed presentation-only preference, safe failure, CSP compatibility, and no identity/scope/authority storage | passed — facade cookie contract, controller CSP, and browser reload tests |
| Non-color semantics | every status, readiness, lifecycle, projection, and outcome has text/structure in addition to color | passed — projection non-color and composed accessibility tests |
| Responsive modes | 320 CSS-pixel reflow, 200% zoom, localization growth, RTL, touch targets, and narrow-screen alternatives | passed — browser responsive/mode test and Pixel touch-target test |
| User preference modes | reduced motion, forced colors/high contrast, system/light/dark, and print | passed — browser preference/mode test across applicable profiles |
| Focus and keyboard | visible focus, logical order, skip target, native disclosure/dialog behavior, and overlay focus return | passed — browser keyboard-order and semantic-name tests |
| Content safety | escaped hostile content, long labels, missing fields, bounded high counts, and no executable source/wiki/graph/log content | passed — primitive, projection, controller, and browser hostile-content tests |
| Local assets | one local `app.js` and `app.css`, no inline script, remote/CDN font/icon/style/script, or unsafe CSP mode | passed — controller and architecture source scans plus production asset build |

Browser evidence is required across the accepted HUI-B4 Chromium, Firefox,
WebKit, Chromium-with-JavaScript-disabled, and touch/narrow Chromium profiles.
The candidate must record exact browser and fixture revisions, commands,
applicable passes/skips, viewport/theme/mode coverage, visual fixture digests,
and accessibility-tree or equivalent semantic evidence.

Candidate browser evidence uses Node `24.3.0` and Playwright `1.62.0` with
Chromium revision 1234/browser 151.0.7922.34, Firefox revision 1538/browser
153.0, and WebKit revision 2336/browser 26.5. The exact command
`npx playwright test test/browser/hypermedia_ui_phase_c2.spec.mjs
--update-snapshots` passed 23 applicable cases, skipped 27 deliberately
profile-inapplicable cases, and failed 0 in 36.1 seconds across `chromium`,
`firefox`, `webkit`, `chromium-no-js`, and `chromium-touch`. It covers the
semantic shell and all ten projection states; hostile/bounded content;
keyboard and semantic name/order/status contracts; skip, disclosure, dialog,
menu, native form/navigation and focus return; JS-disabled fallbacks;
system/light/dark persistence; 320-pixel narrow, 200% zoom, localization
growth, RTL, reduced motion, forced colors, print, and Pixel touch targets.
The browser specification SHA-256 is
`13b374b4c77930316c5738c02e329fbfb23c6aa81153d7df1793f43d9702e54e`.

The accepted Chromium visual fixtures are desktop dark
`36a04c99262dab0b20f4999f5c1f780ae6f2b18f9a2e0de68b8c1f220275090f`,
desktop light
`69e0499caa4277b8772a8e86012b2a9d52c8dd145abf6bbe2d44e0b0dedeebca`,
touch dark
`829fdaafb4b396e5be4ec153a311ceb2bf93f19bb5454201a694598182998e74`,
and touch light
`767cb04d4ca08ba8b5d5e8d1b1c2b4a3f3fb40e9687098fd158502dd53d75a21`.
The sans token names the locally installed `Liberation Sans` family before
generic fallbacks so Linux hosts do not select different `system-ui` metrics;
no font is downloaded or treated as application authority.

This phase makes **no named-screen-reader speech-output claim**. HUI-B4 risk
HUI-B4-R03 is not silently closed by ARIA snapshots, accessibility-tree
inspection, or keyboard testing. Named screen-reader/browser/OS speech and task
evidence is carried forward explicitly to the complete HUI-C5 accessibility
and acceptance matrix, with the accessibility maintainer as owner. Any earlier
release or stronger conformance claim requires separately recorded evidence.

## Repository-Wiki Capacity Requalification

HUI-C2 source and normative documentation are inputs to the accepted
self-hosted repository-wiki pilot. The bounded successor recorded in
`docs/architecture/repository-wiki-inventory-capacity-successor.md` advances
the signed inventory profile to `wiki-source-inventory/1.1.0`, with at most
2,000 files and 16,777,216 total bytes across its registered `lib` and
documentation roots. The 262,144-byte per-file and 512-byte path ceilings stay
unchanged. The compiler recomputes the inventory digest, qualification
thresholds derive from the live profile, and the signed corpus and pilot
advance together to their `1.1.0` revisions.

The complete repository-wiki suite passes 165 tests locally with zero
failures. Replay against merged implementation candidate
`da7ab6a4478bb278aa31a7636fa92135843249ff` admits 1,067 files and 8,642,765
bytes under inventory digest
`0f0adbce7fa61aedb1be2986812e01b7ae67337d742dcd7882a32d7d8789366a`.
The exact signed tuple and deterministic zero-model-call/token/cost evidence is
pinned in the capacity-successor record.

If the candidate exceeds an accepted inventory ceiling, changes the signed
pilot/release tuple, or cannot reproduce the accepted invariants, HUI-C2 stays
merge-pending. The ceiling must not be weakened and normative evidence must not
be deleted merely to obtain a pass. A separately reviewed repository-wiki
capacity/profile and signed-corpus requalification, with renewed resource,
security, quality, replay, release, and reopening evidence, is required before
acceptance. Every RW1-RW5 gate and reopening condition remains in force.

## Integration Evidence

The implementation candidate records 69 focused server and architecture tests:
44 facade/application/projection/controller composition tests, 8 HUI-C2
architecture-evidence tests, and 17 inventory-helper/capacity-successor tests.
The exact source set and SHA-256 values are machine-checked by
`priv/architecture/hypermedia_ui/phase_c2_implementation_evidence.json`; that
set includes the facade, application and projection composites, root/layout
integration, local asset entry points, deterministic fixtures, browser
specification and snapshots, capacity-successor boundary, tests, receipt, plan,
and verifier. The manifest deliberately does not digest itself.

| Command or evidence | Candidate-local result |
| --- | --- |
| Focused facade, application, projection, qualification, and controller composition tests | 44 tests, 0 failures |
| `mix test test/jido_code/architecture/hypermedia_ui_phase_c2_test.exs` | 8 tests, 0 failures |
| Inventory helper boundary and capacity successor tests | 17 tests, 0 failures |
| Complete `test/jido_code/knowledge/repository_wiki` suite | 165 tests, 0 failures in 40.0 seconds |
| Five-profile Playwright command pinned above | 23 applicable passes, 27 deliberate profile skips, 0 failures in 36.1 seconds |
| `mix assets.build` | passed; client bundle built 63 modules and SSR bundle built 96 modules |
| `MIX_ENV=prod mix compile --warnings-as-errors` | passed with zero warnings |
| `mix hex.audit` | passed with no known retired or vulnerable Hex dependencies |
| `npm audit --omit=dev` | passed with 0 vulnerabilities |
| `mix precommit` | passed; 1,337 tests, 0 failures in 687.5 seconds after clean compile, architecture, dependency, and format gates |
| Clean-checkout implementation CI | passed — verify job `101360624510` in 20m0s and Dialyzer job `101360624559` in 1m53s on implementation head `3569921642900e1651ed3efd9a6a2e6514d8efb4` |
| Closure transition validation | `mix precommit` passed; 1,337 tests, 0 failures in 641.9 seconds before the closure commit |

The focused and browser matrices cover the supported primitive catalog, native
forms/navigation, every canonical projection state, shell and collection
compositions, overlays, errors, hostile/long/bounded content, keyboard and
semantic name/order/status behavior, responsive modes, preference modes,
visual regression, stable roots/focus targets, production-fixture exclusion,
and authority/import/asset boundaries. Section 2.4 provenance, the
implementation PR head, both clean-checkout jobs, the full merged candidate
SHA, and merge date are pinned exactly above.

## Exceptions And Limitations

There are no accepted HUI-C2 architecture exceptions. Any proposed exception
must name its owner, reason, exact path and symbol, expiry, evidence, and
reopening condition; an unrecorded, expired, widened, or unmatched exception
fails the gate.

HUI-C2 implements a stateless presentation layer. It authorizes no new product
route, controller action, page, fragment, stream, Datastar/Dstar delivery,
query, graph access, cache, durable state, acknowledgement, semantic command,
approval, export, download, or production capability. Navigation visibility
is explanatory only and never authority. Existing LiveView, LiveVue/Vue, and
SaladUI consumers remain compatibility-only and gain no new product use.

The application components are tested with bounded deterministic presentation
fixtures; they do not claim production projection adapters, real operational
data, deployment TLS/proxy/capacity, or complete HUI-C5 browser/OS/assistive-
technology release qualification. Repository-wiki capacity and named screen-
reader evidence remain governed exactly as described above.

The repository-wiki inventory helper is qualified on a trusted mutable Linux
host prerequisite, not a content-addressed runtime image: local evidence is
Linux Mint 22.1 (Ubuntu 24.04 base), CPython 3.12.3, GNU `timeout` 9.4, and
`prlimit` 2.39.3, while clean-checkout CI uses the mutable `ubuntu-24.04`
runner label. The application pins executable paths, file type/permissions,
the CPython 3.12 family, helper scripts, protocols, and resource ceilings; it
does not attest the standard library, ELF interpreter, shared libraries, or
host package contents. Such drift requires requalification, and a small
content-addressed native helper remains the portability successor.

## Gate HUI-C2 Reopening Conditions

HUI-C2 cannot be accepted, and after acceptance immediately reopens, if HUI-B4,
HUI-B2, HUI-C1, or any RW1-RW5 gate reopens; if the accepted ShadcnUI, Phoenix,
Tailwind, Datastar, Dstar, Vite, asset, license, lock, checksum, import, CSP,
browser, or production-exclusion tuple drifts without its required
requalification; or if a direct ShadcnUI product import, broad `use ShadcnUI`,
remote/CDN product asset, inline script, unsafe eval, extra product bundle,
unreviewed font/icon, `@apply`, or new LiveView/LiveVue/Vue/SaladUI product
consumer appears.

The gate reopens if the exact facade catalog, wrapper name, attr, slot, global-
attribute allowlist, variant, size, state, DOM identity, deprecation, or source
API mapping changes without renewed dependency diff and rendered-contract
evidence; if project `<.input>`, `to_form/2`, `<.form>`, CSRF, native submit,
link, select, checkbox, radio, table, disclosure, dialog, menu, tooltip, toast,
status, or skeleton semantics regress; if content is not escaped; if IDs or
relationships collide; if caller styling becomes an open semantic or authority
channel; or if required information exists only in tooltip, hover, motion,
color, icon, CSS, or JavaScript state.

The gate reopens if theme resolution flashes or produces inconsistent
`data-appearance`, `data-theme`, or `data-shadcn-theme` values; if persistence
stores identity, scope, role, grant, assurance, policy, revision, or another
authority value; if light, dark, system, reduced-motion, forced-color/high-
contrast, RTL, print, zoom/reflow, touch, localization-growth, or narrow-screen
behavior regresses; if contrast, visible focus, target size, landmark, heading,
label, description, error, live-region, keyboard order, Escape, initial focus,
focus return, or no-JavaScript/native behavior fails; or if named screen-reader
or WCAG conformance is claimed beyond the recorded evidence.

The gate reopens if shell or navigation components choose or retain scope,
resolve routes/resources, inspect authorization, treat a role or hidden/visible
item as a grant, expose a concealed destination, carry stale project/attempt/
candidate/preview/lens state, or lose stable roots, landmarks, page/main focus,
current-location semantics, ordinary navigation, or responsive disclosure. It
also reopens if a component adds a graph query, raw IRI, effect, command,
approval, acknowledgement, durable notification, cache authority, browser
authority, dynamic dispatch, Datastar/Dstar/SSE delivery, or product runtime
process.

The gate reopens if the ten canonical projection states or alias policy drifts;
if connection or command state is presented as data truth; if revision,
freshness, source, as-of, completeness, contradiction, truncation, readiness,
or provenance is fabricated or omitted; if unknown and unauthorized exteriors
diverge; if unavailable, unauthorized, maintenance, or recovery presentation
retains protected rows; if a retry reveals target existence or implies an
unauthorized action; if progress, meter, badge, lifecycle, outcome, cost,
budget, attention, health, fleet, project, attempt, evidence, or readiness
semantics are misleading; or if collection output, labels, counts, columns,
pagination, DOM size, or responsive alternatives become unbounded or
inaccessible.

Finally, the gate reopens if any source/catalog/token/asset/fixture/browser/
accessibility/dependency digest, section commit, test count, command, result,
exception, limitation, owner, expiry, evidence statement, or reopening
condition is missing, false, stale, weakened, or silently removed; if the
repository-wiki pilot exceeds its file/byte ceiling or a signed pilot/release
digest changes without requalification; if strict production compilation,
architecture, dependency, security, accessibility, visual, repository-wiki,
`mix precommit`, or clean-checkout CI fails; or if the accepted implementation
PR head, full merged candidate, and merge date are not pinned exactly in the
closure receipt.
