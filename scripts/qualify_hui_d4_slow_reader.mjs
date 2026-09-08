import {chromium, expect} from "@playwright/test"
import http from "node:http"
import {randomBytes} from "node:crypto"
import readline from "node:readline"
import assert from "node:assert/strict"
const browser = await chromium.launch()
let request
try {
  const page = await browser.newPage()
  await page.goto(`${process.env.HUI_D4_BASE}/factory/fleet`)
  await page.locator("input[name='session[login]']").fill(process.env.HUI_D4_LOGIN)
  await page.locator("input[name='session[credential]']").fill(process.env.HUI_D4_CREDENTIAL)
  await page.locator("#human-sign-in-submit").click()
  await expect(page).toHaveURL(/\/factory\/fleet$/)
  const csrf = await page.locator("meta[name='csrf-token']").getAttribute("content")
  const cookie = (await page.context().cookies()).map(c => `${c.name}=${c.value}`).join("; ")
  const payload = JSON.stringify({stream: {tab: randomBytes(16).toString("base64url"), request: randomBytes(16).toString("base64url")}, read_fleet: {}})
  const messages = readline.createInterface({input: process.stdin})[Symbol.asyncIterator]()
  const response = await new Promise((resolve, reject) => {
    request = http.request(`${process.env.HUI_D4_BASE}/ui/streams/fleet`, {
      method: "POST", highWaterMark: 1024,
      headers: {accept: "text/event-stream", "content-type": "application/json",
        "content-length": Buffer.byteLength(payload), cookie, "x-csrf-token": csrf,
        origin: process.env.HUI_D4_BASE, "sec-fetch-site": "same-origin", "datastar-request": "true"}
    }, resolve)
    request.on("error", reject)
    request.end(payload)
  })
  assert.equal(response.statusCode, 200)
  response.pause() // Deliberately never consume protected response bytes.
  console.log("D4_SLOW_READY")
  assert.equal((await messages.next()).value, "retired")
  response.destroy()
  assert.equal((await page.goto(`${process.env.HUI_D4_BASE}/factory/fleet`)).status(), 200)
  await expect(page.locator("a[href*='d4_hidden']")).toHaveCount(0)
  console.log("D4_SLOW_DONE")
} catch {
  console.error(JSON.stringify({qualification: "nonreading_client", failure: "browser_assertion"}))
  process.exitCode = 1
} finally {
  request?.destroy()
  await browser.close()
  process.stdin.destroy()
}
