import {chromium, firefox, webkit, expect} from "@playwright/test"
import assert from "node:assert/strict"
for (const [engine, launcher] of Object.entries({chromium, firefox, webkit})) {
  const browser = await launcher.launch()
  try {
    const context = await browser.newContext({javaScriptEnabled: false})
    const page = await context.newPage()
    await page.goto(`${process.env.HUI_D4_BASE}/factory/fleet`)
    await page.locator("input[name='session[login]']").fill(process.env.HUI_D4_LOGIN)
    await page.locator("input[name='session[credential]']").fill(process.env.HUI_D4_CREDENTIAL)
    await page.locator("#human-sign-in-submit").click()
    await expect(page).toHaveURL(/\/factory\/fleet$/)
    await expect(page.locator("#factory-fleet")).toBeVisible()
    await expect(page.locator("#product-stream-controls, [data-read-endpoint]")).toHaveCount(0)
    const response = await page.reload()
    assert.equal(response.status(), 200)
    await expect(page.locator("#factory-fleet")).toBeVisible()
    await page.locator("#product-sign-out-submit").click()
    await expect(page).toHaveURL(/\/sign-in$/)
    console.log(JSON.stringify({rollback: "native-only", engine, browser: browser.version(), result: "pass"}))
  } finally { await browser.close() }
}
