import {chromium, firefox, webkit, expect} from "@playwright/test"
import assert from "node:assert/strict"

const engine = process.env.HUI_D4_BROWSER || "chromium"
const browser = await ({chromium, firefox, webkit})[engine].launch({headless: true})
try {
  const context = await browser.newContext({reducedMotion: "reduce"})
  const page = await context.newPage()
  const errors = []
  page.on("pageerror", error => errors.push(error.message))
  const response = await page.goto(`${process.env.HUI_D4_BASE}/factory/fleet`)
  assert.equal(response.status(), 200)
  assert.ok(response.headers()["content-security-policy"].includes("nonce-"))
  await page.locator("input[name='session[login]']").fill(process.env.HUI_D4_LOGIN)
  await page.locator("input[name='session[credential]']").fill(process.env.HUI_D4_CREDENTIAL)
  await page.locator("#human-sign-in-submit").click()
  await expect(page).toHaveURL(/\/factory\/fleet$/)
  const cookie = (await context.cookies()).find(cookie => cookie.name === "_jido_code_key")
  assert.ok(cookie.httpOnly)
  assert.equal(cookie.sameSite, "Lax")
  assert.equal(cookie.secure, false)
  await expect(page.locator("#factory-fleet")).not.toHaveAttribute("data-projection-state", /recovery|error|unauthorized/)
  await page.locator("#product-stream-connect").click()
  await expect(page.locator("#product-stream-status")).toContainText("Connected.")
  const initial = await page.locator("#product-owned-content").getAttribute("data-read-receipt")
  await expect(page.locator("#product-owned-content")).not.toHaveAttribute("data-read-receipt", initial, {timeout: 10_000})
  await context.setOffline(true)
  await expect(page.locator("#factory-fleet")).toHaveCount(0)
  await expect(page.locator("#product-read-status")).toContainText("earlier content has been cleared")
  await context.setOffline(false)
  await page.goto(`${process.env.HUI_D4_BASE}/factory/fleet`)
  await page.locator("#product-stream-connect").click()
  await expect(page.locator("#product-stream-status")).toContainText("Connected.")
  await page.locator("#product-stream-pause").click()
  await expect(page.locator("#product-stream-pause")).toHaveAttribute("aria-pressed", "true")
  const other = await context.newPage()
  await other.goto(`${process.env.HUI_D4_BASE}/factory/fleet`)
  await other.locator("#product-sign-out-submit").click()
  await expect(page.locator("#product-shell")).toHaveAttribute("data-stream-terminal", "revoked")
  await expect(page.locator("#product-owned-content")).toHaveCount(0)
  assert.deepEqual(errors, [])
  assert.equal(await page.evaluate(async () => (await navigator.serviceWorker.getRegistrations()).length), 0)
  console.log(JSON.stringify({profile: "local-loopback-v1", engine, browser: browser.version(),
    production_build: true, named_human_graph: "pass", cookie: "pass",
    direct_stream: "pass", periodic_refresh: "pass", offline_recovery: "pass", paused_revocation: "pass",
    service_workers: 0, page_errors: 0}))
} finally {
  await browser.close()
}
