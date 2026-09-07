import {chromium, expect} from "@playwright/test"
import assert from "node:assert/strict"
const browser = await chromium.launch()
const started = Date.now()
let patches = 0
let patchBytes = 0
try {
  const pages = []
  for (let session = 0; session < 2; session++) {
    const context = await browser.newContext()
    const first = await context.newPage()
    await first.goto(`${process.env.HUI_D4_BASE}/factory/fleet`)
    await first.locator("input[name='session[login]']").fill(process.env.HUI_D4_LOGIN)
    await first.locator("input[name='session[credential]']").fill(process.env.HUI_D4_CREDENTIAL)
    await first.locator("#human-sign-in-submit").click()
    await expect(first).toHaveURL(/\/factory\/fleet$/)
    const second = await context.newPage()
    await second.goto(`${process.env.HUI_D4_BASE}/factory/fleet`)
    pages.push(first, second)
  }
  for (const page of pages) {
    await page.exposeFunction("countD4Patch", bytes => { patches++; patchBytes += bytes })
    await page.evaluate(() => document.addEventListener("datastar-fetch", event => {
      if (event.detail.type === "datastar-patch-elements") {
        window.countD4Patch(new TextEncoder().encode(event.detail.argsRaw.elements || "").byteLength)
      }
    }))
    await page.locator("#product-stream-connect").click()
    await expect(page.locator("#product-stream-status")).toContainText("Connected.")
  }
  const extra = await pages[0].context().newPage()
  await extra.goto(`${process.env.HUI_D4_BASE}/factory/fleet`)
  const rejected = extra.waitForResponse(response => response.url().includes("/ui/streams/"))
  await extra.locator("#product-stream-connect").click()
  assert.equal((await rejected).status(), 429)
  await extra.close()
  await Promise.all(pages.map(async page => {
    const before = await page.locator("#product-owned-content").getAttribute("data-read-receipt")
    await expect(page.locator("#product-owned-content")).not.toHaveAttribute("data-read-receipt", before, {timeout: 10_000})
  }))
  assert.ok(patches >= 8)
  console.log(JSON.stringify({load: "four tabs, two sessions, one named human, empty factory",
    patches, patchBytes, elapsed_ms: Date.now() - started, fifth_stream: "rejected"}))
} finally {
  await browser.close()
}
