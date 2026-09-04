# Hypermedia UI Product Consumption Baseline

- Status: Accepted HUI-B4 product-consumption baseline at merged candidate
  `63d2689321121775a46bf531d004ac4de44b81f2`
- Recorded: 2026-09-04
- Baseline: `e14ee7fa268eb6bd5a4d7bb7e519cce748d7b5e2`
- Machine record: `priv/architecture/hypermedia_ui/phase_b4_consumption_baseline.json`
- Scope: the exact dependency, facade, asset, browser, and protocol combination
  qualified by Milestone B

## Authorized Consumption

Milestone C may consume ShadcnUI only through
`JidoCodeWeb.Components.UI`. The currently qualified primitive names are
`button`, `field_input`, `link`, `badge`, `table`, `disclosure`, `dialog`, and
`status`. The existing application `<.input>` remains the default form input;
`field_input` is the deliberately distinct ShadcnUI qualification boundary.
Product HEEx keeps explicit Phoenix routes/controllers, `to_form/2`, ordinary
anchors and forms, stable unique DOM IDs, and native behavior before adding
enhancement.

The only approved ShadcnUI import sites are the facade and the local CSS
bundle. The only approved Datastar product asset import is
`assets/js/app.js`. Product Dstar calls may appear only in an explicit Phoenix
controller or application-owned bounded SSE adapter, after trusted admission
and authorization. The selected helper surface is exactly `start/1`,
`patch_elements/3`, `patch_signals/3`, and `SSE.send_event!/3`. Dstar Scripts,
dynamic module/action dispatch, and authority derived from browser state are
not authorized.

The selected enhancement vocabulary is `data-signals:*`, `data-bind:*`,
`data-on:click__prevent`, `data-attr:*`, `data-indicator:*`, and `data-text`,
with GET reads and non-GET POST effects. These names are an allowlist, not
permission to send identity, tenant, project, graph, delegation, assurance,
policy, grant, or authoritative revision data as signals. Each product action
still requires its own closed schema, stable patch roots, bounded payloads,
CSRF, Origin/Fetch Metadata checks, fresh server-side scope, and exact
resource/action authorization.

## Assets And Configuration

The candidate pins Datastar 1.0.3 bundle digest
`5d6b7794a50a83d82da962aec5e382f5ae83ac7afbc751f903f7a9c6bd433c65`
and ShadcnUI source commit
`fe40eae63504adc4375aead4f0e741f158a4d86e` with compiled stylesheet digest
`ed0768e9582e980f3fd1b3ca0076afc573fc269514f527aef9dc942d1f8e9f41`.
The local `app.js`, `app.css`, and facade digests are pinned in the machine
record. One local application script and stylesheet remain the only product
bundles. Remote/CDN product assets, inline scripts, and unsafe CSP modes are
prohibited.

The isolated HUI-B3 consumer remains available as deterministic source and a
test-build fixture. `hypermedia_qualification_build` is false by default and
true only in `config/test.exs`. Consequently, a production compilation has
zero `__qualification` routes and zero qualification supervision children,
even if runtime configuration attempts to enable it. Run
`MIX_ENV=prod mix hui.b4.production_boundary` to verify this invariant.

## Supported Profiles And Operating Envelope

The evidence applies to Chromium, Firefox, WebKit, a no-JavaScript Chromium
profile, and a Pixel 7 touch/narrow Chromium profile. It covers direct
HTTP/1.1, an unbuffered HTTP/1.1 reverse-proxy fixture, and an unbuffered
HTTP/2 TLS reverse-proxy fixture under enforcing CSP. The local HTTP/2
certificate proves the test seam only and grants no production trust,
termination, capacity, or deployment claim.

Accessibility evidence covers landmarks, names, labels, visible keyboard
focus, disclosure semantics, dialog entry/Escape/focus return, table caption
and headers with bounded horizontal overflow, live status, light/dark themes,
320px reflow, reduced motion, forced colors, RTL, 200% zoom, and touch. Named
screen-reader speech output on supported production OS/browser pairs remains a
recorded risk and must be reviewed with the first Milestone C composition.

The qualified fixture ceiling is four global streams, one per tab, eight
events and 12,288 accounted bytes per connection, no queue, a 1,200 ms maximum
lifetime, and at most two retries within 3,000 ms. Product routes must adopt
equal or tighter limits until a separately reviewed capacity decision changes
them. Missing/stale assets use native recovery; malformed/unsupported signals,
missing CSRF, cross-origin writes, duplicate/excess streams, browser authority,
and terminal reconnect attempts fail closed.

## Milestone C-Owned Composite Gaps

Milestone B qualifies primitives, not the product composition layer.
Milestone C owns `FactoryShell`, `ProjectContextSwitcher`, `AttentionQueue`,
`ProjectionStatusStrip`, `AgentFleetTable`, `AgentAttemptWorkspace`,
`StageRail`, `AttemptTimeline`, `CodeDiff`, the artifact manifest,
`EvidenceMatrix`, `ScopedCommandDialog`, `CommandReceipt`, `GraphLens` with an
accessible table/outline, `ProvenancePanel`, and `CostBudgetMeter`. Existing
LiveView, LiveVue/Vue, and SaladUI consumers remain compatibility-only; this
baseline authorizes no new consumer of those runtimes.

## Rollback, Upgrade, And Reopening

Rollback restores the whole prior Mix/npm locks, local Datastar bundle,
ShadcnUI source and stylesheet, facade, asset configuration, and release.
There is no HUI data migration. An upgrade follows the deterministic HUI-B4
workflow and renews immutable provenance, license/usage authority, advisories,
dependency/consumer diffs, browser/protocol evidence, manual accessibility,
release startup, and rollback evidence as one candidate.

HUI2 reopens on any source, version, checksum, license, advisory, dependency
edge, import, facade API, attribute/event, asset, configuration, CSP, browser,
proxy, accessibility, protocol, operational-bound, failure-mode, rollback,
production-exclusion, evidence, residual-risk, or exception drift; on a new
forbidden consumer or ineffective drift check; or when any predecessor gate
reopens. There are no HUI-B4 exceptions.
