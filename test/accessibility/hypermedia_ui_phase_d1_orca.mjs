import {chromium, expect} from "@playwright/test"

const browser = await chromium.launch({
  headless: false,
  executablePath: "/usr/bin/google-chrome",
  args: ["--force-renderer-accessibility", "--disable-gpu", "--no-sandbox"],
})

try {
  const page = await browser.newPage({viewport: {width: 1280, height: 800}})
  await page.goto("http://127.0.0.1:4423/factory/fleet")
  await page.locator("input[name='session[login]']").fill("operator@example.test")
  await page.locator("input[name='session[credential]']").fill("test-named-human-credential")
  await page.locator("#human-sign-in-submit").click()
  await page.waitForURL(/\/factory\/fleet$/)
  await page.getByRole("heading", {level: 1, name: "Fleet"}).focus()
  await page.waitForTimeout(700)
  const input = page.locator("#product-filter-search-query")
  await input.fill("beta")
  await input.press("Enter")
  await expect(page.locator("#product-read-status")).toContainText("View refreshed")
  await expect(input).toBeFocused()
  await page.waitForTimeout(1000)
  await page.locator("#product-read-status").evaluate(node => node.setAttribute("tabindex", "-1"))
  await page.locator("#product-read-status").focus()
  await page.waitForTimeout(1000)
  process.stdout.write(JSON.stringify({result: "pass", journey: "named sign-in, fleet, keyboard filter, finite patch, retained input focus, refreshed live status"}) + "\n")
} finally {
  await browser.close()
}
