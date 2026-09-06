import {expect, test} from "@playwright/test"

const signIn = async (page, path = "/factory/fleet") => {
  await page.goto(path)
  await page.locator("input[name='session[login]']").fill("operator@example.test")
  await page.locator("input[name='session[credential]']").fill("test-named-human-credential")
  await page.locator("#human-sign-in-submit").click()
  await expect(page).toHaveURL(new RegExp(`${path}$`))
}

test("finite reads preserve the shell, typed intent, focus and production CSP", async ({page}, info) => {
  test.skip(info.project.name === "chromium-no-js")
  const errors = []
  page.on("pageerror", error => errors.push(error.message))
  await signIn(page)
  await page.evaluate(() => {
    window.originalShell = document.getElementById("product-shell")
    window.cspViolations = []
    document.addEventListener("securitypolicyviolation", e => window.cspViolations.push(e.violatedDirective))
  })
  const input = page.locator("#product-filter-search-query")
  await input.fill("beta")
  await input.focus()
  const requestPromise = page.waitForRequest(r => r.url().includes("/ui/reads/fleet"))
  const responsePromise = page.waitForResponse(r => r.url().includes("/ui/reads/fleet"))
  await input.press("Enter")
  const request = await requestPromise
  const response = await responsePromise
  expect(request.method()).toBe("POST")
  expect(request.postDataJSON()).toEqual({read_fleet: {q: "beta", state: "all"}})
  expect(response.status()).toBe(200)
  expect(response.headers()["datastar-selector"]).toBe("#product-owned-content")
  expect(response.headers()["cache-control"]).toBe("no-store, private")
  await expect(page).toHaveURL(/\/factory\/fleet\?q=beta$/)
  await expect(input).toBeFocused()
  await expect(input).toHaveValue("beta")
  await expect(page.locator("#product-read-status")).toContainText("View refreshed")
  expect(await page.evaluate(() => window.originalShell === document.getElementById("product-shell"))).toBe(true)
  expect(await page.evaluate(() => window.cspViolations)).toEqual([])
  expect(errors).toEqual([])
  await page.locator("#product-pagination-next").click()
  await expect(page).toHaveURL(/page=2/)
  await expect(page.locator("#product-pagination")).toContainText("2")
})

test("all ten registered surfaces return one coherent region without navigation", async ({page}, info) => {
  test.skip(info.project.name !== "chromium")
  await signIn(page)
  for (const path of ["/factory", "/factory/fleet", "/projects", "/projects/project_browser_alpha", "/projects/project_browser_alpha/attempts", "/projects/project_browser_alpha/wiki", "/projects/project_browser_alpha/dependencies", "/projects/project_browser_alpha/attempts/attempt_browser_alpha", "/account", "/account/sessions"]) {
    await page.goto(path)
    const response = page.waitForResponse(r => r.url().includes("/ui/reads/"))
    await page.locator("#product-read-refresh").click()
    expect((await response).status(), path).toBe(200)
    await expect(page.locator("#product-owned-content")).toHaveAttribute("data-read-receipt", /.+/)
    await expect(page.locator("#product-shell")).toHaveCount(1)
    await expect(page.locator("#product-owned-content")).toHaveCount(1)
    await expect(page.locator("#product-read-errors")).toHaveCount(1)
    await expect(page.locator("#product-owned-content script")).toHaveCount(0)
  }
})

test("failed or empty responses clear prior rows and leave a native reload", async ({page}, info) => {
  test.skip(info.project.name === "chromium-no-js")
  await signIn(page)
  for (const status of [401, 403, 404, 409, 429, 503, 204]) {
    await page.goto("/factory/fleet")
    await page.locator("#product-owned-content").evaluate(root => {
      const row = document.createElement("p")
      row.id = "earlier-protected-row"
      row.textContent = "Must be cleared"
      root.append(row)
    })
    await page.route("**/ui/reads/fleet", route => route.fulfill({status, body: ""}))
    await page.locator("#product-read-refresh").click()
    await expect(page.locator("#earlier-protected-row")).toHaveCount(0)
    await expect(page.locator("#product-read-reload")).toBeVisible()
    await expect(page.locator("#product-read-status")).toHaveAttribute("role", "alert")
    await page.unroute("**/ui/reads/fleet")
  }
})

test("selection, disclosure, dialog and current user focus survive a delayed read", async ({page}, info) => {
  test.skip(!["chromium", "firefox", "webkit"].includes(info.project.name))
  await signIn(page)
  // Local overlays remain outside the protected projection root.
  await page.locator("#product-shell").evaluate(shell => {
    const details = document.createElement("details")
    details.id = "local-disclosure"
    details.open = true
    const summary = document.createElement("summary")
    summary.textContent = "Reading options"
    details.append(summary)
    const dialog = document.createElement("dialog")
    dialog.id = "local-dialog"
    dialog.textContent = "Local reading overlay"
    shell.append(details, dialog)
    dialog.show()
  })
  await page.route("**/ui/reads/fleet", async route => {
    const response = await route.fetch({headers: {...await route.request().allHeaders(), "sec-fetch-site": "same-origin", "accept-encoding": "identity"}})
    expect(response.status()).toBe(200)
    await new Promise(resolve => setTimeout(resolve, 250))
    await route.fulfill({response})
  })
  await page.locator("#product-read-refresh").click()
  const input = page.locator("#product-filter-search-query")
  await input.fill("still editing")
  await input.focus()
  await input.evaluate(el => el.setSelectionRange(2, 7, "forward"))
  await expect(page.locator("#product-read-status")).toContainText("View refreshed")
  await expect(input).toBeFocused()
  expect(await input.evaluate(el => [el.value, el.selectionStart, el.selectionEnd])).toEqual(["still editing", 2, 7])
  await expect(page.locator("#local-disclosure")).toHaveAttribute("open", "")
  await expect(page.locator("#local-dialog")).toHaveAttribute("open", "")
})

test("disabled JavaScript keeps filtering, pagination, refresh and sign-out native", async ({page}, info) => {
  test.skip(info.project.name !== "chromium-no-js")
  await signIn(page)
  await page.locator("#product-filter-search-query").fill("beta")
  await page.locator("#product-filter-search-submit").click()
  await expect(page).toHaveURL(/q=beta/)
  await page.locator("#product-pagination-next").click()
  await expect(page).toHaveURL(/page=2/)
  await page.locator("#product-read-refresh").click()
  await expect(page).toHaveURL(/page=2/)
  await page.locator("#product-sign-out-submit").click()
  await expect(page).toHaveURL(/\/sign-in$/)
})
