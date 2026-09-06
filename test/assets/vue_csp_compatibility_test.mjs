import {test} from "node:test"
import assert from "node:assert/strict"
import {readFileSync} from "node:fs"
import vm from "node:vm"
import {deferVuePolicy, vueCSPCompatibility} from "../../assets/vue_csp_compatibility.mjs"

const source = readFileSync(new URL("../../node_modules/@vue/runtime-dom/dist/runtime-dom.esm-bundler.js", import.meta.url), "utf8")
const adapted = deferVuePolicy(source)
const policyCode = adapted.slice(adapted.indexOf("let convertHTML;"), adapted.indexOf("const svgNS"))

test("unused Vue creates no policy; first use preserves upstream conversion once", () => {
  const names = []
  const context = vm.createContext({window: {trustedTypes: {createPolicy(name, options) {
    names.push(name)
    return {createHTML: value => ({trusted: options.createHTML(value)})}
  }}}})
  vm.runInContext(policyCode, context)
  assert.deepEqual(names, [])
  assert.equal(vm.runInContext('unsafeToTrustedHTML("first").trusted', context), "first")
  assert.equal(vm.runInContext('unsafeToTrustedHTML("second").trusted', context), "second")
  assert.deepEqual(names, ["vue"])
})

test("denied policy is still denied, creates no trusted value, and is not retried", () => {
  let attempts = 0
  const context = vm.createContext({process: {env: {NODE_ENV: "production"}}, window: {trustedTypes: {createPolicy() {
    attempts++
    throw new TypeError("policy denied")
  }}}})
  vm.runInContext(policyCode, context)
  assert.equal(attempts, 0)
  assert.equal(vm.runInContext('unsafeToTrustedHTML("plain")', context), "plain")
  assert.equal(vm.runInContext('unsafeToTrustedHTML("still plain")', context), "still plain")
  assert.equal(attempts, 1)
})

test("SSR and browsers without Trusted Types preserve the original string", () => {
  for (const globals of [{}, {window: {}}]) {
    const context = vm.createContext(globals)
    vm.runInContext(policyCode, context)
    assert.equal(vm.runInContext('unsafeToTrustedHTML("plain")', context), "plain")
  }
})

test("source drift fails the build and unrelated modules are not transformed", () => {
  assert.throws(() => deferVuePolicy(source + "\n"), /source changed/)
  assert.equal(vueCSPCompatibility().transform(source, "/unrelated.js"), undefined)
  assert.equal(vueCSPCompatibility().transform(source, "/node_modules/@vue/runtime-dom/dist/runtime-dom.esm-bundler.js").code, adapted)
})
