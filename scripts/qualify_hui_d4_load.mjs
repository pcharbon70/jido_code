import {chromium, expect} from "@playwright/test"
import assert from "node:assert/strict"
const browser = await chromium.launch()
const started = Date.now()
const rounds = Number(process.env.HUI_D4_LOAD_ROUNDS || 3)
assert.ok(Number.isInteger(rounds) && rounds >= 3 && rounds <= 20)
let patches = 0
let patchBytes = 0
let activeRound = 0
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
  for (let round = 0; round < rounds; round++) {
    activeRound = round + 1
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
      await expect(page.locator("#factory-fleet a[href='/projects/d4_alpha']")).toHaveCount(2)
      await expect(page.locator("#factory-fleet a[href='/projects/d4_beta']")).toHaveCount(2)
      await expect(page.locator("a[href*='d4_hidden']")).toHaveCount(0)
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
      await expect(page.locator("#factory-fleet a[href='/projects/d4_alpha']")).toHaveCount(2)
      await expect(page.locator("#factory-fleet a[href='/projects/d4_beta']")).toHaveCount(2)
      await expect(page.locator("a[href*='d4_hidden']")).toHaveCount(0)
    }))
  }
  assert.ok(patches >= rounds * 8)
  // Start a burst at the four-lease ceiling. Existing owners may retire while
  // admissions authorize, so a newly free slot can legitimately be reused.
  // The server-side sampler asserts the cap; successful newcomers must still
  // receive a scoped snapshot. Saturation/unavailability never grants access.
  const storm = await Promise.all(Array.from({length: 12}, async () => {
    const page = await pages[0].context().newPage()
    try {
      assert.equal((await page.goto(`${process.env.HUI_D4_BASE}/factory/fleet`)).status(), 200)
      const response = page.waitForResponse(r => r.url().includes("/ui/streams/"))
      await page.locator("#product-stream-connect").click()
      const status = (await response).status()
      assert.ok([200, 409, 429, 503].includes(status))
      if (status === 200) {
        await expect(page.locator("#product-stream-status")).toContainText("Connected.")
        await expect(page.locator("#factory-fleet a[href='/projects/d4_alpha']")).toHaveCount(2)
        await expect(page.locator("#factory-fleet a[href='/projects/d4_beta']")).toHaveCount(2)
        await expect(page.locator("a[href*='d4_hidden']")).toHaveCount(0)
      }
      return status
    } finally { await page.close() }
  }))
  assert.ok(storm.some(status => status !== 200))
  await pages[0].goto(`${process.env.HUI_D4_BASE}/factory/fleet`)
  await expect(pages[0].locator("#factory-fleet a[href='/projects/d4_alpha']")).toHaveCount(2)
  await expect(pages[0].locator("#factory-fleet a[href='/projects/d4_beta']")).toHaveCount(2)
  await expect(pages[0].locator("a[href*='d4_hidden']")).toHaveCount(0)
  console.log(JSON.stringify({load: "four tabs, two sessions, one named human, three repository scopes",
    rounds, patches, patchBytes, elapsed_ms: Date.now() - started, fifth_stream: "rejected",
    reconnect_burst_statuses: storm, native_recovery: "pass"}))
} catch {
  // Playwright's default error contains DOM attributes, including signed
  // correlation cursors. Retain only a fixed failure class and round number.
  console.error(JSON.stringify({qualification: "load", failure: "browser_assertion", round: activeRound}))
  process.exitCode = 1
} finally {
  await browser.close()
}
