# HUI-B2 Datastar Asset Pipeline

## Exact Local Input

The browser runtime is the exact Datastar 1.0.3 bundle from signed tag
`v1.0.3` and source commit
`73ab00e7c06d8c2bad030fdddafba800fcccbde2`. The tracked file at
`assets/vendor/datastar/datastar.js` is 33,538 bytes and has SHA-256
`5d6b7794a50a83d82da962aec5e382f5ae83ac7afbc751f903f7a9c6bd433c65`.
`assets/js/app.js` imports this file directly. There is no CDN, remote fallback,
package resolver, or source substitution.

The accompanying MIT grant is retained at
`assets/vendor/datastar/LICENSE.md`; its only source normalization is a final
newline, recorded separately from the exact upstream license digest.

The exact source contains an upstream source-map reference, but the map is not
vendored and Vite explicitly builds with `sourcemap: false`. No `.map` file is
present in the production tree.

## CSP And HTTP Contract

Every endpoint response receives a fresh URL-safe nonce. The root `html`
element renders that nonce as `data-nonce` before the module executes; Datastar
removes the attribute and applies the same nonce to its transient expression
scripts. The enforcing policy permits self-hosted scripts plus that response
nonce and requires the `datastar` Trusted Types policy. It contains neither
`unsafe-eval`, `unsafe-inline`, a remote script source, nor Dstar Scripts.

Static responses include `nosniff` and same-origin resource policy. Versioned
requests receive one-year immutable caching; non-versioned ETag requests must
revalidate. Phoenix serves the registered MIME type and precompressed gzip
output. The qualification tests bind the exact response nonce to the rendered
root, reject empty/reused nonces, and exercise compressed static delivery.

Datastar is present but dormant in HUI-B2: no production template has a
Datastar action/signal attribute and no Dstar product module is used. Only the
test fixture contains static reviewed expressions. Identity, scope, action,
resource, graph, policy, and authoritative revision remain server-owned.

## Reproducible Build

`mix assets.deploy` clears prior generated digest output, builds the one local
application JS/CSS bundle, fingerprints it with Vite and Phoenix, normalizes
the non-semantic Phoenix manifest timestamps to the fixed HUI-B2 build epoch,
and emits gzip files. Two consecutive builds produced identical Vite and
Phoenix manifests plus the identical normalized uncompressed tree hash
recorded in `phase_b2_asset_pipeline.json`.

This clean-input rule is for building one immutable release. Stale clients are
served by the draining prior complete release during an atomic deployment;
the system never mixes a new manifest with old bytes or performs an in-place
asset replacement. Rollback restores the prior complete release and its
matching manifest.

The gate reopens on source or bundle digest drift, a map file, nonlocal asset,
remote fallback, CSP weakening, missing/empty nonce, dynamic or unreviewed
expression, Dstar Scripts, MIME/nosniff/cache/compression drift, mismatched
manifest and bytes, nondeterministic clean build, or any HUI-B2 product
consumer.
