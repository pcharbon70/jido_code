import {createHash} from "node:crypto"

// HUI-D1 repair: retained Vue must not request an unused policy at bootstrap.
// This is a build-time, exact-input adaptation, not a CSP allowance. Remove
// with the retained Vue runtime in HUI-H2. See the architecture repair record.
export const vueRuntimeDigest = "f80dd6a47a4c38b18a7a6b0cc5f2b67493ce2dd337ae601f41a5d7cd52d83aa1"
const runtimeSuffix = "/@vue/runtime-dom/dist/runtime-dom.esm-bundler.js"
const start = "let policy = void 0;"
const end = "const unsafeToTrustedHTML = policy ? (val) => policy.createHTML(val) : (val) => val;"

export function deferVuePolicy(source) {
  if (createHash("sha256").update(source).digest("hex") !== vueRuntimeDigest) {
    throw new Error("HUI-D1 Vue runtime source changed; requalify the CSP compatibility adaptation")
  }
  const first = source.indexOf(start)
  const last = source.indexOf(end, first) + end.length
  if (first < 0 || last < end.length) throw new Error("HUI-D1 Vue policy boundary missing")
  const initialization = source.slice(first, last - end.length)
  // Preserve the upstream factory, exception handling, and conversion exactly;
  // only the first-use timing changes. A denied policy still grants nothing.
  return source.slice(0, first) + `let convertHTML;
const unsafeToTrustedHTML = (value) => {
  if (!convertHTML) {
    ${initialization}
    convertHTML = policy ? (val) => policy.createHTML(val) : (val) => val;
  }
  return convertHTML(value);
};` + source.slice(last)
}

export function vueCSPCompatibility() {
  return {
    name: "jido-vue-csp-first-use",
    enforce: "pre",
    transform(source, id) {
      if (id.replaceAll("\\", "/").split("?")[0].endsWith(runtimeSuffix)) {
        return {code: deferVuePolicy(source), map: null}
      }
    },
  }
}
