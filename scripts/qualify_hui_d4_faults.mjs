import {chromium, expect} from "@playwright/test"
import assert from "node:assert/strict"
import readline from "node:readline"

const messages = readline.createInterface({input: process.stdin})[Symbol.asyncIterator]()
const acknowledge = async expected => {
  const {value, done} = await messages.next()
  assert.equal(done, false)
  assert.equal(value, expected)
}
const browser = await chromium.launch()
try {
  const page = await browser.newPage()
  page.on("response", response => {
    if (response.url().includes("/ui/streams/")) console.error(JSON.stringify({stream_status: response.status()}))
  })
  await page.goto(`${process.env.HUI_D4_BASE}/factory/fleet`)
  await page.locator("input[name='session[login]']").fill(process.env.HUI_D4_LOGIN)
  await page.locator("input[name='session[credential]']").fill(process.env.HUI_D4_CREDENTIAL)
  await page.locator("#human-sign-in-submit").click()
  await expect(page).toHaveURL(/\/factory\/fleet$/)
  for (const fault of ["query", "identity", "coordinator"]) {
    await page.locator("#product-stream-connect").click()
    await expect(page.locator("#product-stream-status")).toContainText("Connected.")
    console.log(`D4_READY_${fault}`)
    await acknowledge("applied")
    await expect(page.locator("#factory-fleet")).toHaveCount(0, {timeout: 10_000})
    console.log(`D4_RECOVER_${fault}`)
    await acknowledge("restored")
    await page.goto(`${process.env.HUI_D4_BASE}/factory/fleet`)
    await expect(page.locator("#factory-fleet")).toHaveAttribute("data-projection-state", /^(ready|empty)$/)
  }
  console.log("D4_DONE")
} finally {
  await browser.close()
  process.stdin.destroy()
}
