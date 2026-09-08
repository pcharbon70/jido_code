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
  }
  for (let round = 0; round < 3; round++) {
    if (round) {
      await Promise.all(pages.map(page => page.goto(`${process.env.HUI_D4_BASE}/factory/fleet`)))
      // A disconnected socket is discovered by the bounded write/heartbeat
      // path. Do not demand a fifth lease while old owners are still retiring.
      await pages[0].waitForTimeout(8_000)
    }
    for (const page of pages) {
      await page.evaluate(() => document.addEventListener("datastar-fetch", event => {
        if (event.detail.type === "datastar-patch-elements") {
          window.countD4Patch(new TextEncoder().encode(event.detail.argsRaw.elements || "").byteLength)
        }
      }))
      await page.locator("#product-stream-connect").click()
      await expect(page.locator("#product-stream-status")).toContainText("Connected.")
    }
    if (round === 0) {
      const extra = await pages[0].context().newPage()
      await extra.goto(`${process.env.HUI_D4_BASE}/factory/fleet`)
      const rejected = extra.waitForResponse(response => response.url().includes("/ui/streams/"))
      await extra.locator("#product-stream-connect").click()
      assert.equal((await rejected).status(), 429)
      await extra.close()
    }
    await pages[0].waitForTimeout(18_000)
    await Promise.all(pages.map(async page => {
      const before = await page.locator("#product-owned-content").getAttribute("data-read-receipt")
      await expect(page.locator("#product-owned-content")).not.toHaveAttribute("data-read-receipt", before, {timeout: 8_000})
      await expect(page.locator("#product-stream-status")).toContainText("Connected.")
    }))
  }
  assert.ok(patches >= 24)
  console.log(JSON.stringify({load: "four tabs, two sessions, one named human, empty factory",
    rounds: 3, patches, patchBytes, elapsed_ms: Date.now() - started, fifth_stream: "rejected"}))
} finally {
  await browser.close()
}
