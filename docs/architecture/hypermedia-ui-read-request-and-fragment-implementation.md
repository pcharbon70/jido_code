# HUI-D1 Request And Fragment Implementation

Authorized baseline: `4d0e3918d732d87ebaad36e56ef90cc781e51d62`.
Accepted HUI-C5 candidate: `5987a7a4a43505b035f5a566588d5201e98686f7`.
Owner: JidoCode web, identity, projection, accessibility, and operations maintainers.

## Closed Read Intent

Every read request has exactly one `read_<surface>` namespace. The eight graph
surfaces are `factory`, `fleet`, `projects`, `project`, `project_attempts`,
`project_wiki`, `project_dependencies`, and `attempt`; `account` and `sessions`
are identity-only surfaces. Collection queries admit `q`, `state`, `sort`,
`direction`, and `page`. Attempt reads admit only `q`, `state`, and `page`.
Account/session refresh has an empty query. Each handler has its own fixed
namespace; another page's namespace is rejected.

`ReadSignals` admits at most 2,048 UTF-8 bytes, one namespace plus five fields,
two object levels, zero list items, and 128 bytes per search scalar. Page is
1–100. State, sort, and direction use the existing native enumerations. Search
uses NFC and trimming; default values normalize to the native empty query.
Duplicate keys (including escaped names), unknown keys, invalid scalar types,
control characters, excessive depth, and oversized values return closed atom
diagnostics, never raw submitted values. Depth is checked before JSON decoding.

`_pending`, `_overlay`, `_pauseVisualUpdates`, and `_selectedRow` describe
local presentation state only and are never transmitted. All ephemeral state
is discarded on a full route/resource change. Filter submission resets page
and sort intent; pagination/sort links carry the native server-authored query.
Cursors and alternative views remain unavailable until a reviewed query
defines their semantics; sending them is rejected. No actor, session, tenant,
project authority, graph, grant, delegation, assurance, profile, fence,
revision, CSRF, idempotency, or command field is admitted.

## Reopening Conditions

Reopen HUI-D1 if a signal gains authority, an unknown/duplicate/deep/oversized
input is admitted, errors reflect protected values, a page accepts another
namespace, local state survives a scope change, or an unreviewed query mode is
introduced. All HUI-C5 native behavior, authorization, privacy, accessibility,
truthfulness, and bounded-resource invariants remain binding.
