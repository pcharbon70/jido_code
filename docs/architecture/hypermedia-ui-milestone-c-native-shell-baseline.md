# Hypermedia UI Milestone C Native Shell Baseline

- Status: HUI3 fragment candidate; merge-pending
- Manifest: `priv/architecture/hypermedia_ui/phase_c5_product_baseline.json`
- Authorized baseline: `2542e9ceed021d42dbbde6cdc9eb9e9613c8546f`
- Owners: product, web, identity, Knowledge, accessibility, security, release,
  and operations maintainers

## Accepted Native Product

The baseline manifest is the complete machine inventory for the Milestone C
native shell. It pins 27 explicit controller routes, their controller actions,
stable page roots and focus targets, server-side authority owners, and native
links or forms. It excludes the three compatibility-only LiveView routes from
the accepted product and adds no product LiveView, LiveVue, Vue island,
Datastar behavior, inline script, or remote asset.

`JidoCodeWeb.ProductRequest` owns route admission and safe response policy;
`JidoCodeWeb.ProductPageViewModel` owns the already-authorized page shape;
`JidoCode.Product.GraphReadProjectionProvider` owns reviewed bounded reads;
and `JidoCode.Product.ReadProjectionCache` owns disposable exact-context
caching. Presentation stays behind `ProductPage`, `Application`, `Projection`,
`ReadWorkspace`, and `UI` facades.

## Stable Read Roots

Eight projection surfaces are candidates for Milestone D enhancement:
factory attention, fleet, project catalog, project overview, project attempts,
project wiki, project dependencies, and attempt workspace. Their exact roots,
query protocol `2.11.0`, authorization checkpoints, native interactions, and
limits are listed in the manifest. Every root preserves the ten canonical
states: ready, empty, stale, incomplete, contradicted, truncated,
unauthorized, unavailable, maintenance, and recovery.

`product-main` remains the page focus target and `product-owned-content`
remains the outer owned-content boundary. A live replacement may target only
an inventoried inner projection root after current authorization and query
execution. It cannot silently replace page identity, route context, native
forms, breadcrumbs, errors, project switching, sign-out, or footer support.

## Reconciled Evidence

The manifest joins the accepted C1 identity/session/revocation boundary, C2
component/theme/asset boundary, C3 route/native-navigation boundary, C4
projection/cache/readiness/wiki/cost boundary, C5 accessibility evidence, and
C5 adapter/capacity/privacy/operations evidence. Earlier gate reopening
conditions remain cumulative.

The production graph-authority adapter, phishing-resistant step-up,
independent recovery, semantic controls, and projections owned by later
milestones remain explicitly unavailable. An unavailable capability has no
decorative button or effect path. Wiki remains default-off and missing cost is
never represented as zero.

## Milestone D Enhancement Boundary

Milestone D may add application-owned bounded SSE snapshots and replacements,
static reviewed Datastar expressions for ephemeral intent, focus/reading-
position preservation, and terminal revocation outcomes around the listed
roots. It may not remove native links/forms/retry/pagination, change stable
identity, accept browser authority, skip route/query/row/field/destination/
patch authorization, weaken state and freshness truth, widen bounds, or add
inline/remote/executable content or a second product runtime.

## Reopening

HUI3 reopens on any route, view-model, component, root, focus, state,
authorization, query, limit, native-interaction, or placeholder drift; on any
unreconciled identity/component/projection/accessibility/operations evidence;
if Milestone D breaks native behavior, stable identity, field authorization,
bounded reads, truthful state, privacy, or accessibility; if a new candidate
surface appears without qualification; or if a limitation, prohibition,
unsupported placeholder, or reopening condition is removed or weakened.
