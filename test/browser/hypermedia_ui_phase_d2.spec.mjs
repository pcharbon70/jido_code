import {expect, test} from "@playwright/test"

// All browser suites deliberately share the named operator fixture. Respect its
// production 30-read/16-stream per-minute budgets instead of widening them or
// retrying 429s. A fresh window also makes selected D1+D2 runs reproducible.
test.beforeAll(async ({}, info) => {
  info.setTimeout(90_000)
  await new Promise(resolve => setTimeout(resolve, 61_000))
})

test.afterEach(async ({context}) => {
  // Revoke this fixture session explicitly. Browser destruction alone may leave
  // an HTTP owner until its bounded idle deadline, consuming principal capacity.
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

const captureOrigins = async page => page.addInitScript(() => {
  document.addEventListener("datastar-fetch", ({detail}) => {
    if (detail.type === "started" && detail.el.tagName === "SPAN") window.streamOrigin = detail.el
  }, true)
})

const stalePatch = async page => page.evaluate(() => {
  document.dispatchEvent(new CustomEvent("datastar-fetch", {detail: {
    el: window.streamOrigin, type: "datastar-patch-elements",
    argsRaw: {selector: "#product-owned-content", elements: '<div id="product-owned-content"><p id="stale-stream-row">STALE</p></div>'},
  }}))
})

test("manual stream starts a current private snapshot without replacing shell or focus", async ({page}, info) => {
  test.skip(info.project.name === "chromium-no-js")
  const errors = [], violations = []
  page.on("pageerror", error => errors.push(error.message))
  await page.exposeFunction("recordD2CSPViolation", event => violations.push(event))
  await page.addInitScript(() => document.addEventListener("securitypolicyviolation", event => {
    window.recordD2CSPViolation({directive: event.violatedDirective, sample: event.sample})
  }))
  await signIn(page)
  await page.evaluate(() => { window.originalShell = document.getElementById("product-shell") })
  const pending = page.waitForResponse(response => response.url().includes("/ui/streams/fleet"))
  const connect = page.locator("#product-stream-connect")
  await connect.focus()
  await connect.press("Enter")
  const response = await pending
  expect(response.status()).toBe(200)
  expect(response.headers()["content-type"]).toContain("text/event-stream")
  expect(response.headers()["cache-control"]).toBe("no-store, private")
  const payload = response.request().postDataJSON()
  expect(Object.keys(payload).sort()).toEqual(["read_fleet", "stream"])
  expect(payload.stream.tab).toMatch(/^[A-Za-z0-9_-]{22}$/)
  expect(payload.stream.request).toMatch(/^[A-Za-z0-9_-]{22}$/)
  expect(payload.read_fleet).toEqual({})
  await expect(page.locator("#product-stream-status")).toContainText("Connected.")
  await expect(page.locator("#product-owned-content")).toHaveAttribute("data-stream-cursor", /.+/)
  await expect(connect).toBeFocused()
  expect(await page.evaluate(() => window.originalShell === document.getElementById("product-shell"))).toBe(true)
  expect(violations).toEqual([])
  expect(errors).toEqual([])
})

test("finite intent cancels delivery and suppresses already-buffered old stream patches", async ({page}, info) => {
  test.skip(info.project.name !== "chromium")
  await captureOrigins(page)
  await signIn(page)
  const streams = []
  page.on("request", request => { if (request.url().includes("/ui/streams/")) streams.push(request) })
  await page.locator("#product-stream-connect").click()
  await expect(page.locator("#product-stream-status")).toContainText("Connected.")
  await page.locator("#product-filter-search-query").fill("beta")
  await page.locator("#product-filter-search-query").press("Enter")
  await expect(page).toHaveURL(/q=beta$/)
  await expect(page.locator("#product-stream-status")).toContainText("paused")
  await expect(page.locator("#product-owned-content")).not.toHaveAttribute("data-stream-cursor", /.+/)
  await stalePatch(page)
  await expect(page.locator("#stale-stream-row")).toHaveCount(0)
  await expect(page.locator("#product-owned-content")).toHaveAttribute("data-read-url", "/factory/fleet?q=beta")
  expect(streams).toHaveLength(1)
})

test("session revocation from another tab clears all protected shell content without reconnect", async ({page, context}, info) => {
  test.skip(info.project.name !== "chromium")
  await signIn(page)
  let connects = 0
  page.on("request", request => { if (request.url().includes("/ui/streams/")) connects++ })
  await page.locator("#product-stream-connect").click()
  await expect(page.locator("#product-stream-status")).toContainText("Connected.")
  const other = await context.newPage()
  await other.goto("/factory/fleet")
  await other.locator("#product-sign-out-submit").click()
  await expect(other).toHaveURL(/\/sign-in/)
  await expect(page.locator("#product-shell")).toHaveAttribute("data-stream-terminal", "revoked")
  await expect(page.locator("#product-stream-status")).toHaveAttribute("role", "alert")
  await expect(page.locator("#product-context, #product-account-menu, #product-owned-content")).toHaveCount(0)
  await expect(page.locator("#product-stream-reload")).toBeVisible()
  await page.waitForTimeout(1_200)
  expect(connects).toBe(1)
  await other.close()
})

test("transient retries have new nonces and a fixed ceiling; terminal errors never retry", async ({page}, info) => {
  test.skip(info.project.name !== "chromium")
  await signIn(page)
  const payloads = []
  await page.route("**/ui/streams/fleet", route => {
    payloads.push(route.request().postDataJSON())
    return route.fulfill({status: 502, body: ""})
  })
  await page.locator("#product-stream-connect").click()
  await expect(page.locator("#product-stream-status")).toContainText("Reload to check access")
  expect(payloads).toHaveLength(3)
  expect(new Set(payloads.map(payload => payload.stream.request)).size).toBe(3)
  expect(new Set(payloads.map(payload => payload.stream.tab)).size).toBe(1)
  await expect(page.locator("#product-read-reload")).toBeVisible()
  await page.unroute("**/ui/streams/fleet")
  await page.route("**/ui/streams/fleet", route => {
    payloads.push(route.request().postDataJSON())
    return route.fulfill({status: 401, body: ""})
  })
  await page.locator("#product-stream-connect").click()
  await expect(page.locator("#product-account-menu")).toHaveCount(0)
  await page.waitForTimeout(1_200)
  expect(payloads).toHaveLength(4)
})

test("a late visibility wake cannot reuse expired DOM, socket or delayed patches", async ({page}, info) => {
  test.skip(info.project.name !== "chromium")
  await captureOrigins(page)
  await signIn(page)
  let connects = 0
  page.on("request", request => { if (request.url().includes("/ui/streams/")) connects++ })
  await page.locator("#product-stream-connect").click()
  await expect(page.locator("#product-stream-status")).toContainText("Connected.")
  await page.evaluate(() => {
    const original = Date.now
    Date.now = () => original() + 31_000
    document.dispatchEvent(new Event("visibilitychange"))
  })
  await stalePatch(page)
  await expect(page.locator("#product-account-menu, #stale-stream-row")).toHaveCount(0)
  await expect(page.locator("#product-read-reload")).toBeVisible()
  expect(connects).toBe(1)
})

test("without JavaScript the connection link is an ordinary authorized page refresh", async ({page}, info) => {
  test.skip(info.project.name !== "chromium-no-js")
  await signIn(page)
  const pending = page.waitForRequest(request => request.isNavigationRequest())
  await page.locator("#product-stream-connect").click()
  expect((await pending).method()).toBe("GET")
  await expect(page).toHaveURL(/\/factory\/fleet$/)
  await expect(page.locator("#product-stream-status")).toContainText("Not connected")
  await expect(page.locator("#product-owned-content")).not.toHaveAttribute("data-stream-cursor", /.+/)
})

for (const [protocol, origin] of [
  ["HTTP/1", `http://127.0.0.1:${process.env.HUI_B3_PROXY_PORT || 4414}`],
  ["HTTP/2", `https://127.0.0.1:${process.env.HUI_B4_HTTP2_PROXY_PORT || 4415}`],
]) {
  test(`${protocol} proxy delivers the initial event without buffering until EOF`, async ({page}, info) => {
    test.skip(info.project.name !== "chromium")
    const violations = []
    await page.exposeFunction("recordProxyCSPViolation", value => violations.push(value))
    await page.addInitScript(() => document.addEventListener("securitypolicyviolation", event => {
      window.recordProxyCSPViolation(event.violatedDirective)
    }))
    await page.goto(`${origin}/factory/fleet`)
    await page.locator("input[name='session[login]']").fill("operator@example.test")
    await page.locator("input[name='session[credential]']").fill("test-named-human-credential")
    await page.locator("#human-sign-in-submit").click()
    await expect(page).toHaveURL(/\/factory\/fleet$/)
    const pending = page.waitForResponse(response => response.url().includes("/ui/streams/fleet"))
    await page.locator("#product-stream-connect").click()
    const response = await pending
    expect(response.status()).toBe(200)
    expect(response.headers()["x-hui-b3-proxy-mode"]).toBe("unbuffered-sse")
    expect(response.headers()["cache-control"]).toBe("no-store, private")
    if (protocol === "HTTP/2") expect(response.headers()["x-hui-b4-ingress-protocol"]).toBe("h2")
    await expect(page.locator("#product-stream-status")).toContainText("Connected.")
    for (const selector of ["script[src]", "link[rel='stylesheet']"]) {
      const urls = await page.locator(selector).evaluateAll(nodes => nodes.map(node => node.src || node.href))
      expect(urls).toHaveLength(1)
      expect(new URL(urls[0]).origin).toBe(origin)
    }
    expect(violations).toEqual([])
    await page.locator("#product-sign-out-submit").click()
    await expect(page).toHaveURL(/\/sign-in/)
  })
}

test("copied tab correlation takes over only inside the same trusted session", async ({page, context, browser}, info) => {
  test.skip(info.project.name !== "chromium")
  await signIn(page)
  let correlation
  page.on("request", request => {
    if (request.url().includes("/ui/streams/fleet")) correlation = request.postDataJSON().stream.tab
  })
  await page.locator("#product-stream-connect").click()
  await expect(page.locator("#product-stream-status")).toContainText("Connected.")
  const copy = await context.newPage()
  await copy.goto("/factory/fleet")
  await copy.route("**/ui/streams/fleet", route => {
    const payload = route.request().postDataJSON()
    payload.stream.tab = correlation
    return route.continue({postData: JSON.stringify(payload)})
  })
  await copy.locator("#product-stream-connect").click()
  await expect(copy.locator("#product-stream-status")).toContainText("Connected.")
  await expect(page.locator("#product-shell")).toHaveAttribute("data-stream-terminal", "closed")
  const separate = await browser.newContext()
  try {
    const isolated = await separate.newPage()
    await signIn(isolated)
    await isolated.route("**/ui/streams/fleet", route => {
      const payload = route.request().postDataJSON()
      payload.stream.tab = correlation
      return route.continue({postData: JSON.stringify(payload)})
    })
    await isolated.locator("#product-stream-connect").click()
    await expect(isolated.locator("#product-stream-status")).toContainText("Connected.")
    await expect(copy.locator("#product-stream-status")).toContainText("Connected.")
    await isolated.locator("#product-sign-out-submit").click()
  } finally { await separate.close() }
  await copy.locator("#product-sign-out-submit").click()
  await copy.close()
})

test("blocked browser storage does not prevent connection or acquire authority", async ({page}, info) => {
  test.skip(info.project.name !== "chromium")
  await page.addInitScript(() => {
    for (const key of ["sessionStorage", "localStorage"]) {
      Object.defineProperty(window, key, {get() { throw new Error("storage unavailable") }})
    }
  })
  await signIn(page)
  await page.locator("#product-stream-connect").click()
  await expect(page.locator("#product-stream-status")).toContainText("Connected.")
  await page.locator("#product-sign-out-submit").click()
  await expect(page).toHaveURL(/\/sign-in/)
})

test("a pending finite refresh cannot race a stream for the earlier query", async ({page}, info) => {
  test.skip(info.project.name !== "chromium")
  await signIn(page)
  let release
  const held = new Promise(resolve => { release = resolve })
  const streams = []
  page.on("request", request => { if (request.url().includes("/ui/streams/fleet")) streams.push(request) })
  await page.route("**/ui/reads/fleet", async route => {
    const response = await route.fetch({headers: {...await route.request().allHeaders(), "sec-fetch-site": "same-origin", "accept-encoding": "identity"}})
    await held
    await route.fulfill({response})
  })
  try {
    await page.locator("#product-filter-search-query").fill("beta")
    const started = page.waitForRequest(request => request.url().includes("/ui/reads/fleet"))
    await page.locator("#product-filter-search-query").press("Enter")
    await started
    await page.locator("#product-stream-connect").click()
    await expect(page.locator("#product-stream-status")).toContainText("after this refresh finishes")
    expect(streams).toHaveLength(0)
  } finally { release() }
  await expect(page).toHaveURL(/q=beta$/)
  await page.locator("#product-stream-connect").click()
  await expect(page.locator("#product-stream-status")).toContainText("Connected.")
  expect(streams).toHaveLength(1)
  expect(streams[0].postDataJSON().read_fleet).toEqual({q: "beta"})
  await expect(page.locator("#product-owned-content")).toHaveAttribute("data-read-url", "/factory/fleet?q=beta")
})
