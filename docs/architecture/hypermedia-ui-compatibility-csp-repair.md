# HUI-D1 Compatibility CSP Repair

Owner: JidoCode web and asset maintainers. Scope: the retained Vue 3.5.40
runtime in the one local application bundle. Removal trigger: HUI-H2's accepted
Vue runtime removal. This does not authorize a new Vue consumer or CSP policy.

PR #127's successful CI reported 98 browser passes, 111 profile skips, and one
Firefox test passing on retry. Early CSP instrumentation subsequently reproduced
the failure in 15/15 runs: Vue's eager `createPolicy("vue")` at module bootstrap
was denied by `trusted-types datastar`. The previous test attached its listener
after sign-in and only intermittently captured the delayed startup event. The
same legacy import, dependency lock, and enforcing policy predate D1. CI retained
no failure artifact because the overall browser step passed on retry.

`assets/vue_csp_compatibility.mjs:deferVuePolicy` changes only the time of the
retained runtime's policy initialization: first `unsafeToTrustedHTML` use,
instead of module evaluation. The upstream policy name, factory, exception
handling, conversion, and denied-policy string fallback remain intact. A denied
policy is attempted once and does not create a trusted value; browser sink
enforcement remains unchanged. No `vue` policy is allowed, no default policy is
created, and nothing monkey-patches the browser or shares Datastar's policy.

The Vite pre-transform targets only `@vue/runtime-dom/dist/runtime-dom.esm-bundler.js`
with SHA-256 `f80dd6a47a4c38b18a7a6b0cc5f2b67493ce2dd337ae601f41a5d7cd52d83aa1`.
Any upstream byte drift fails the build for review. Vue is excluded from the
development prebundle so the same transform runs there. The client still has
one JS and one CSS output; SSR keeps its existing separate server artifact.
The dependency lock and pinned Datastar bytes are unchanged. This is a reviewed
build adaptation, not a new runtime or architecture exception; it does not
claim to make retained legacy Vue HTML sinks compatible with the product CSP.

The Node contract tests cover dormant bootstrap, exactly-once first use,
unchanged permitted conversion, denied policy, absent Trusted Types, SSR, source
drift, and exact module targeting. ExUnit invokes them in `mix precommit` and
clean-checkout CI. The production browser test now installs its detailed CSP
listener before the initial navigation and checks native sign-in plus finite
reads without filtering any violation or allowing retries locally.

Reopen on source/target drift, eager policy creation, a broadened policy or sink
bypass, alternate/chunked/remote product assets, a skipped transform path,
changed upstream semantics, ignored CSP event, test failure, or removed owner/
removal condition. All predecessor and HUI-D1 reopening conditions remain intact.

Validation: the four Node contracts and five focused ExUnit checks pass;
architecture checks, strict production compilation, and Dialyzer pass (178
existing filtered warnings, no new warning or filter). The complete browser/
proxy matrix passes with 99 applicable passes and 111 intentional profile skips
in 1.9 minutes, without retries. Ten additional Firefox startup/finite-read
repetitions pass in 31.2 seconds with no CSP event. A preceding 25-combination
repeat run deliberately exceeded the unchanged principal limit after 30 reads:
15 passed, five no-JS skips, five 429 responses; no rate limit was widened.
Client output remains one `app-C-LvkytP.js` and one `app-a07Tyb3v.css` bundle.
The full `mix precommit` rerun and clean-checkout CI must pass before repair
merge; final results and the accepted merged candidate belong in D1 closure.
