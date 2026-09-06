import {chromium, expect} from "@playwright/test"

const browser = await chromium.launch({
  headless: false,
  executablePath: "/usr/bin/google-chrome",
  args: ["--force-renderer-accessibility", "--disable-gpu", "--no-sandbox"],
})
try {
  const context = await browser.newContext({viewport: {width: 1280, height: 800}})
  const page = await context.newPage()
  await page.goto("http://127.0.0.1:4423/factory/fleet")
  await page.locator("input[name='session[login]']").fill("operator@example.test")
  await page.locator("input[name='session[credential]']").fill("test-named-human-credential")
  await page.locator("#human-sign-in-submit").click()
  await page.waitForURL(/\/factory\/fleet$/)
  const connect = page.locator("#product-stream-connect")
  await connect.focus()
  await connect.press("Enter")
  await expect(page.locator("#product-stream-status")).toContainText("Connected.")
  await expect(connect).toBeFocused()
  await page.waitForTimeout(1500)
  const other = await context.newPage()
  await other.goto("http://127.0.0.1:4423/factory/fleet")
  await other.locator("#product-sign-out-submit").click()
  await expect(page.locator("#product-shell")).toHaveAttribute("data-stream-terminal", "revoked")
  await page.bringToFront()
  await expect(page.locator("#product-stream-status")).toBeFocused()
  await page.waitForTimeout(1500)
  await page.keyboard.press("Tab")
  await expect(page.locator("#product-stream-reload")).toBeFocused()
  await page.waitForTimeout(1500)
  process.stdout.write(JSON.stringify({result: "pass", journey: "named sign-in, keyboard connect, live status, retained focus, cross-tab revocation, concealed alert focus, native reload keyboard access"}) + "\n")
} finally { await browser.close() }
