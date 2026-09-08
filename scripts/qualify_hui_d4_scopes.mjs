import {chromium, expect} from "@playwright/test"
import assert from "node:assert/strict"
const browser = await chromium.launch()
try {
  const page = await browser.newPage()
  await page.goto(`${process.env.HUI_D4_BASE}/factory/fleet`)
  await page.locator("input[name='session[login]']").fill(process.env.HUI_D4_LOGIN)
  await page.locator("input[name='session[credential]']").fill(process.env.HUI_D4_CREDENTIAL)
  await page.locator("#human-sign-in-submit").click()
  await expect(page).toHaveURL(/\/factory\/fleet$/)
  await page.locator("#product-stream-connect").click()
  await expect(page.locator("#product-stream-status")).toContainText("Connected.")
  await expect(page.locator("[data-projection-trust] dl > div:first-child dd")).toHaveText(process.env.HUI_D4_REVISION)
  for (const label of ["alpha", "beta"]) {
    // Desktop table and responsive card each have an explicit project link.
    await expect(page.locator(`#factory-fleet a[href='/projects/d4_${label}']`)).toHaveCount(2)
    const response = await page.request.get(`${process.env.HUI_D4_BASE}/projects/d4_${label}`)
    assert.equal(response.status(), 200)
  }
  await expect(page.locator("a[href*='d4_hidden']")).toHaveCount(0)
  assert.equal((await page.request.get(`${process.env.HUI_D4_BASE}/projects/d4_hidden`)).status(), 404)
  console.log(JSON.stringify({production_scopes: 3, authorized: 2, concealed: 1, graph_revision: process.env.HUI_D4_REVISION, result: "pass"}))
} catch {
  console.error(JSON.stringify({qualification: "scopes", failure: "browser_assertion"}))
  process.exitCode = 1
} finally {
  await browser.close()
}
