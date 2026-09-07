import {expect, test} from "@playwright/test"

test.beforeAll(async ({}, info) => {
  info.setTimeout(90_000)
  await new Promise(resolve => setTimeout(resolve, 61_000))
})

test.afterEach(async ({context}) => {
  const cleanup = await context.newPage()
  await cleanup.goto("/factory/fleet")
  if (!new URL(cleanup.url()).pathname.startsWith("/sign-in")) {
    await cleanup.locator("#product-sign-out-submit").click()
    await expect(cleanup).toHaveURL(/\/sign-in/)
  }
  await cleanup.close()
})

const signIn = async page => {
  await page.goto("/factory/fleet")
  await page.locator("input[name='session[login]']").fill("operator@example.test")
  await page.locator("input[name='session[credential]']").fill("test-named-human-credential")
  await page.locator("#human-sign-in-submit").click()
  await expect(page).toHaveURL(/\/factory\/fleet$/)
}

test("periodic server re-query patches current truth while keeping shell and focus", async ({page}, info) => {
  test.skip(info.project.name === "chromium-no-js")
  const errors = []
  page.on("pageerror", error => errors.push(error.message))
  await signIn(page)
  await page.evaluate(() => { window.d3Shell = document.getElementById("product-shell") })
  const connect = page.locator("#product-stream-connect")
  await connect.focus()
  await connect.press("Enter")
  await expect(page.locator("#product-stream-status")).toContainText("Connected.")
  const root = page.locator("#product-owned-content")
  const initial = await root.getAttribute("data-read-receipt")
  await expect(root).not.toHaveAttribute("data-read-receipt", initial, {timeout: 10_000})
  await expect(connect).toBeFocused()
  expect(await page.evaluate(() => window.d3Shell === document.getElementById("product-shell"))).toBe(true)
  await expect(page.locator("#factory-fleet")).toHaveAttribute("data-projection-state", "recovery")
  expect(errors).toEqual([])
})

test("paused visual nudges discard payloads but live session revocation still clears the shell", async ({page, context}, info) => {
  test.skip(info.project.name === "chromium-no-js")
  await page.addInitScript(() => document.addEventListener("datastar-fetch", ({detail}) => {
    if (detail.type === "started" && detail.el.tagName === "SPAN") window.d3Origin = detail.el
  }, true))
  await signIn(page)
  let requests = 0
  page.on("request", request => { if (request.url().includes("/ui/streams/")) requests++ })
  await page.locator("#product-stream-connect").click()
  await expect(page.locator("#product-stream-status")).toContainText("Connected.")
  const pause = page.locator("#product-stream-pause")
  await pause.focus()
  await pause.press("Enter")
  await expect(pause).toHaveAttribute("aria-pressed", "true")
  await page.evaluate(() => document.dispatchEvent(new CustomEvent("datastar-fetch", {detail: {
    el: window.d3Origin, type: "datastar-patch-elements", argsRaw: {
      selector: "#product-owned-content", nudge: "fleet", delivery: "visual",
      elements: '<div id="product-owned-content"><p id="d3-paused-row">Do not retain me</p></div>',
    },
  }})))
  await expect(page.locator("#d3-paused-row")).toHaveCount(0)
  await expect(page.locator("#product-stream-status")).toContainText("New data is available")
  await expect(pause).toBeFocused()
  const other = await context.newPage()
  await other.goto("/factory/fleet")
  await other.locator("#product-sign-out-submit").click()
  await expect(page.locator("#product-shell")).toHaveAttribute("data-stream-terminal", "revoked")
  await expect(page.locator("#product-owned-content")).toHaveCount(0)
  await expect(page.locator("#product-stream-status")).toBeFocused()
  expect(requests).toBe(1)
})

test("resuming requests a fresh snapshot with fresh nonce and no buffered replay", async ({page}, info) => {
  test.skip(info.project.name !== "chromium")
  await signIn(page)
  const bodies = []
  page.on("request", request => { if (request.url().includes("/ui/streams/")) bodies.push(request.postDataJSON()) })
  await page.locator("#product-stream-connect").click()
  await expect(page.locator("#product-stream-status")).toContainText("Connected.")
  await page.locator("#product-stream-pause").click()
  await page.locator("#product-stream-pause").click()
  await expect(page.locator("#product-stream-status")).toContainText("Connected.")
  expect(bodies).toHaveLength(2)
  expect(bodies[1].stream.tab).toBe(bodies[0].stream.tab)
  expect(bodies[1].stream.request).not.toBe(bodies[0].stream.request)
  expect(bodies[1].stream.cursor).toBeUndefined()
  expect(bodies[1].read_fleet).toEqual({})
  await expect(page.locator("#product-stream-pause")).toHaveAttribute("aria-pressed", "false")
})

test("native fallback never exposes an inert pause control", async ({page}, info) => {
  test.skip(info.project.name !== "chromium-no-js")
  await signIn(page)
  await expect(page.locator("#product-stream-pause")).toBeHidden()
  await page.locator("#product-stream-connect").click()
  await expect(page).toHaveURL(/\/factory\/fleet$/)
  await expect(page.locator("#product-stream-pause")).toBeHidden()
})
