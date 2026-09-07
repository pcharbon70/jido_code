import {chromium, expect} from "@playwright/test"

const browser = await chromium.launch({
  headless: false,
  executablePath: "/usr/bin/google-chrome",
  args: ["--force-renderer-accessibility", "--disable-gpu", "--no-sandbox"],
})
try {
  const context = await browser.newContext({viewport: {width: 1280, height: 800}})
  const page = await context.newPage()
  await page.goto(process.env.HUI_D4_BASE + "/factory/fleet")
  await page.locator("input[name='session[login]']").fill(process.env.HUI_D4_LOGIN)
  await page.locator("input[name='session[credential]']").fill(process.env.HUI_D4_CREDENTIAL)
  await page.locator("#human-sign-in-submit").click()
  await page.waitForURL(/\/factory\/fleet$/)
  const connect = page.locator("#product-stream-connect")
  await connect.focus()
  await connect.press("Enter")
  await expect(page.locator("#product-stream-status")).toContainText("Connected.")
  await expect(connect).toBeFocused()
  await page.waitForTimeout(1500)
  const pause = page.locator("#product-stream-pause")
  await pause.focus()
  await pause.press("Enter")
  await expect(pause).toHaveAttribute("aria-pressed", "true")
  await expect(pause).toBeFocused()
  await expect(page.locator("#product-stream-status")).toContainText("Visual updates paused")
  await page.waitForTimeout(1500)
  const other = await context.newPage()
  await other.goto(process.env.HUI_D4_BASE + "/factory/fleet")
  await other.locator("#product-sign-out-submit").click()
  await expect(page.locator("#product-shell")).toHaveAttribute("data-stream-terminal", "revoked")
  await page.bringToFront()
  await expect(page.locator("#product-stream-status")).toBeFocused()
  await page.waitForTimeout(1500)
  await page.keyboard.press("Tab")
  await expect(page.locator("#product-stream-reload")).toBeFocused()
  await page.waitForTimeout(1500)
  process.stdout.write(JSON.stringify({result: "pass", journey: "named sign-in, keyboard connect and pause, truthful paused status, retained focus, cross-tab revocation while paused, concealed alert focus, native reload keyboard access"}) + "\n")
} finally { await browser.close() }
