# Hypermedia UI ShadcnUI Source, License, And Risk Baseline

- Status: HUI-B1 source baseline accepted; dependency adoption blocked
- Recorded: 2026-09-03
- Owner: HUI-B supply-chain and component-facade owners
- Candidate: [`pcharbon70/shadcn_ui@fe40eae`](https://github.com/pcharbon70/shadcn_ui/tree/fe40eae63504adc4375aead4f0e741f158a4d86e)
- Machine record: [`phase_b1_shadcn_source.json`](../../priv/architecture/hypermedia_ui/phase_b1_shadcn_source.json)

## Selection And Integrity

The selected review input is exact commit
`fe40eae63504adc4375aead4f0e741f158a4d86e`, tree
`75980039b06222dcba51ba642ef06fb596aa8cfa`, committed on 2026-09-03. A
canonical `git archive --format=tar` has SHA-256
`a71b35c1102102ee38935d80b1d21e41c68aa3966bca4fb77e8d816383831a1c`
and the tree has 689 entries. The candidate declares application
`shadcn_ui`, module namespace `ShadcnUI`, and version `1.0.0`, but has no
public immutable tag or Hex release. The version string is not provenance;
later work may consume only the exact commit and digest recorded here.

This candidate supersedes the architecture research revision `78d3dfeb`,
which declared `LicenseRef-LECO-Proprietary`, named a different canonical
owner, and had no root license grant. That historical revision remains
rejected and receives no usage authority.

## License And Usage Authority

The selected candidate contains an MIT `LICENSE` whose SHA-256 is
`125c269356102a6f23c6fcf0285d7921e9dd8ac28c19d03fa197388402050405`.
It grants use, copying, modification, publication, distribution,
sublicensing, and sale of the software subject to retaining the copyright and
permission notice. That grant covers source, the compiled stylesheet,
examples, copied or modified component code, and redistribution. The package
ships no icon dependency or icon asset. Applicable third-party notices have
SHA-256 `32d61e76c847c0eab4510ff19eec28776b84e7401a984aa948e23a353182e8de`
and remain mandatory.

This is a source-usage decision, not legal advice and not product-release
approval. A changed license, notice, owner, archive, or source identity
reopens HUI-B1.

## Package And Component Surface

The package exposes 41 stateless Phoenix function components across
foundation, form, disclosure, navigation, content, overlay, media, and motion
categories. It has no JavaScript runtime, routes, sockets, processes, hooks,
state, authorization, persistence, or commands. Runtime dependencies are
`phoenix_html ~> 4.1` and `phoenix_live_view ~> 1.2`, the latter solely for
`Phoenix.Component`, HEEx, attrs, and slots.

The single packaged runtime asset is `priv/static/shadcn_ui.css`, SHA-256
`ed0768e9582e980f3fd1b3ca0076afc573fc269514f527aef9dc942d1f8e9f41`.
It uses `sui:` utilities and `--shadcn-ui-*` tokens. JidoCode must copy that
exact file into its controlled local build; no CDN or runtime fetch is
authorized. Broad `use ShadcnUI` imports expose known `button/1` and `input/1`
collisions. Product code therefore consumes only reviewed wrappers through
`JidoCodeWeb.Components.UI`. Datastar-shaped globals are merely rendered
attributes; Phase 2 and Phase 3 must prove the exact target element for every
facade wrapper.

The package does not supply JidoCode's shell, context switcher, attention
queue, fleet table, attempt workspace/timeline, diff, evidence, command
receipt, graph lens, provenance, or cost/budget compositions. Those remain
application-owned.

## CI, Accessibility, Advisory, And Maintenance Record

The repository is public, active, unarchived, and had no open issues or
repository security advisories returned by GitHub at review time. Those
observations are time-bounded and do not prove absence of transitive or future
vulnerabilities.

[Exact-head workflow run 33771257223](https://github.com/pcharbon70/shadcn_ui/actions/runs/33771257223)
failed in `npm run browser:milestone-e-phase4`. Dependency installation,
deterministic assets, package precommit, docs/archive build, clean-consumer
precommit, SpecLed checks, and browser suites through Milestone E Phase 3 had
passed; later browser suites were skipped. Upstream candidate metadata also
marks `1.0.0` unqualified pending exact archive/consumer reproduction, manual
accessibility, review, green final CI, matching gallery identity, Hex
publication, and public tag.

Historical locked Chromium, Firefox, and WebKit evidence is useful input but
does not qualify this exact candidate. Six bounded manual scenarios covering
keyboard, overlays/focus, zoom/RTL, forced colors/reduced motion, physical
touch, and screen readers remain pending.

## Decision And Reopening Conditions

HUI-B1 accepts this immutable source and MIT usage baseline while blocking
adoption. Phase 2 must solve the current `phoenix_live_view ~> 1.1.0` versus
`~> 1.2` constraint and prove compile-only use. Phase 4 must obtain green
exact-revision upstream or independently reproduced equivalent evidence and
retain the manual accessibility risk for its later owner.

The record expires on 2026-10-03 or immediately on upstream commit, tag,
license, dependency, compiled CSS, CI, or advisory change. It reopens if a
mutable branch or version string replaces the exact pin; the failed CI run is
represented as passing; historical browser evidence is transferred to this
candidate; automated checks are called manual acceptance; package APIs bypass
the facade; or source, CSS, notices, modifications, or redistribution lose
their recorded authority.
