import { expect, test } from "@playwright/test";

const path = "/__qualification/hypermedia";
const proxyURL = `http://127.0.0.1:${Number(
  process.env.HUI_B3_PROXY_PORT || 4414
)}`;

test("native workflow remains complete with JavaScript disabled", async ({
  page,
}, testInfo) => {
  test.skip(testInfo.project.name !== "chromium-no-js");

  await page.goto(path);
  await expect(page.locator("#hui-b3-consumer")).toBeVisible();
  await page.locator("#filters_q").fill("hostile");
  await page.locator("#hui-b3-filter-submit").click();
  await expect(page).toHaveURL(/filters%5Bq%5D=hostile/);
  await expect(page.locator("#fixture-hostile")).toContainText(
    "<unsafe>& hostile label"
  );

  await page.goBack();
  await page.goForward();
  await page.reload();
  await expect(page.locator("#fixture-hostile")).toBeVisible();

  await page.locator("#qualification_note").fill("native note");
  await page.locator("#hui-b3-note-submit").click();
  await expect(page.locator("#hui-b3-submit-success")).toContainText(
    "native note"
  );

  await page.locator("#hui-b3-disclosure-item-protocol-summary").click();
  await expect(
    page.locator("#hui-b3-disclosure-item-protocol")
  ).toHaveAttribute("open", "");
});

test("enhanced fragments preserve focus, selection, overlays, and hostile text", async ({
  page,
}, testInfo) => {
  test.skip(testInfo.project.name === "chromium-no-js");

  await page.goto(path);
  const note = page.locator("#qualification_note");
  await note.fill("selection survives");
  await note.focus();
  await note.evaluate((input) => input.setSelectionRange(2, 8));

  await page.locator("#filters_q").fill("hostile");
  await note.focus();
  await page.locator("#hui-b3-filter-submit").dispatchEvent("click");
  await expect(page.locator("#fixture-hostile")).toContainText(
    "<unsafe>& hostile label"
  );
  await expect(note).toBeFocused();
  expect(
    await note.evaluate((input) => [input.selectionStart, input.selectionEnd])
  ).toEqual([2, 8]);
  await expect(page.locator("#hui-b3-results-region script")).toHaveCount(0);

  await page.locator("#hui-b3-disclosure-item-protocol-summary").click();
  await page.locator("#hui-b3-dialog-invoker").click();
  await expect(page.locator("#hui-b3-dialog-surface")).toHaveAttribute(
    "open",
    ""
  );
  await page.locator("#hui-b3-filter-submit").dispatchEvent("click");
  await expect(
    page.locator("#hui-b3-disclosure-item-protocol")
  ).toHaveAttribute("open", "");
  await expect(page.locator("#hui-b3-dialog-surface")).toHaveAttribute(
    "open",
    ""
  );

  await page.locator("#hui-b3-dialog-close").click();
  await expect(page.locator("#hui-b3-dialog-invoker")).toBeFocused();
  await page.locator("#qualification_note").fill("x");
  await page.locator("#hui-b3-note-submit").dispatchEvent("click");
  await expect(page.locator("#hui-b3-enhanced-outcome")).toContainText(
    "3 through 80"
  );
});

test("bounded stream separates connection state from fixture freshness", async ({
  page,
}, testInfo) => {
  test.skip(testInfo.project.name === "chromium-no-js");

  await page.goto(path);
  await page.locator("#hui-b3-stream-submit").click();
  await expect(page.locator("#hui-b3-connection-value")).toHaveText("closed");
  await expect(page.locator("#hui-b3-freshness-value")).toHaveText("patched");
  await expect(page.locator("#hui-b3-stream-state")).toHaveAttribute(
    "data-connection-state",
    "closed"
  );
  await expect(page.locator("#hui-b3-stream-state")).toHaveAttribute(
    "data-fixture-freshness",
    "patched"
  );
  await expect(page.locator("#hui-b3-stream-submit")).toBeEnabled();
  await page.locator("#hui-b3-stream-reload").click();
  await expect(page.locator("#hui-b3-results-region")).toBeVisible();
});

test("fault hints remain bounded fixture metadata across morph cycles", async ({
  page,
}, testInfo) => {
  test.skip(testInfo.project.name !== "chromium");
  await page.goto(path);

  for (const [scenario, hint] of [
    ["duplicate", "duplicate"],
    ["reorder", "reordered-earlier"],
    ["drop", "dropped-3-through-4"],
    ["sleep_wake", "sleep-wake"],
    ["restart", "server-restart"],
    ["terminal", "terminal-close"],
  ]) {
    await page.locator("#stream_scenario").selectOption(scenario);
    await page.locator("#hui-b3-stream-submit").click();
    await expect(page.locator("#hui-b3-fixture-hint")).toHaveText(hint);
    await expect(page.locator("#hui-b3-connection-value")).toHaveText("closed");
  }
});

test("several tabs converge and duplicate correlation fails fast", async ({
  browser,
}, testInfo) => {
  test.skip(testInfo.project.name !== "chromium");

  const context = await browser.newContext();
  const firstPage = await context.newPage();
  await firstPage.goto(path);

  const remainingPages = await Promise.all(
    [1, 2].map(async () => {
      const page = await context.newPage();
      await page.goto(path);
      return page;
    })
  );
  const pages = [firstPage, ...remainingPages];

  const statuses = await Promise.all(
    pages.map((page, index) =>
      page.evaluate(async (tabIndex) => {
        const csrf = document.querySelector('meta[name="csrf-token"]').content;
        const response = await fetch("/__qualification/hypermedia/stream", {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "datastar-request": "true",
            "sec-fetch-site": "same-origin",
            "x-csrf-token": csrf,
          },
          body: JSON.stringify({
            tabId: `tab_browser_parallel_${tabIndex}`,
            scenario: "slow",
          }),
        });
        await response.text();
        return response.status;
      }, index)
    )
  );
  expect(statuses).toEqual([200, 200, 200]);

  for (const page of pages) {
    await page.locator("#hui-b3-stream-submit").click();
    await expect(page.locator("#hui-b3-connection-value")).toHaveText("closed");
  }

  const duplicateStatus = await pages[0].evaluate(async () => {
    const csrf = document.querySelector('meta[name="csrf-token"]').content;
    const body = JSON.stringify({
      tabId: "tab_browser_duplicate",
      scenario: "slow",
    });
    const options = {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "datastar-request": "true",
        "sec-fetch-site": "same-origin",
        "x-csrf-token": csrf,
      },
      body,
    };
    const first = fetch("/__qualification/hypermedia/stream", options);
    await new Promise((resolve) => setTimeout(resolve, 75));
    const duplicate = await fetch(
      "/__qualification/hypermedia/stream",
      options
    );
    await (await first).text();
    return duplicate.status;
  });

  expect(duplicateStatus).toBe(429);
  await context.close();
});

test("streaming proxy exposes the first SSE bytes before completion", async ({
  page,
}, testInfo) => {
  test.skip(testInfo.project.name !== "chromium");
  const response = await page.goto(`${proxyURL}${path}`);
  expect(response.headers()["x-hui-b3-proxy"]).toBe("streaming-pass-through");

  const timing = await page.evaluate(async () => {
    const csrf = document.querySelector('meta[name="csrf-token"]').content;
    const started = performance.now();
    const response = await fetch("/__qualification/hypermedia/stream", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "datastar-request": "true",
        "sec-fetch-site": "same-origin",
        "x-csrf-token": csrf,
      },
      body: JSON.stringify({ tabId: "tab_proxy_stream", scenario: "slow" }),
    });
    const reader = response.body.getReader();
    const first = await reader.read();
    const firstAt = performance.now() - started;
    let chunks = first.done ? 0 : 1;
    while (!(await reader.read()).done) chunks += 1;
    return {
      chunks,
      firstAt,
      completedAt: performance.now() - started,
      proxyMode: response.headers.get("x-hui-b3-proxy-mode"),
    };
  });

  expect(timing.proxyMode).toBe("unbuffered-sse");
  expect(timing.chunks).toBeGreaterThan(1);
  expect(timing.firstAt).toBeLessThan(timing.completedAt - 100);
});

test("missing asset and malformed stream preserve native recovery", async ({
  page,
}, testInfo) => {
  test.skip(testInfo.project.name !== "chromium");

  const applicationScript = /\/assets\/app-[^/]+\.js(?:\?.*)?$/;
  let blockedScripts = 0;
  await page.route(applicationScript, (route) => {
    blockedScripts += 1;
    return route.fulfill({
      status: 503,
      contentType: "text/javascript",
      body: "",
    });
  });
  await page.goto(path);
  expect(blockedScripts).toBe(1);
  await page.locator("#filters_q").fill("hostile");
  await page.locator("#hui-b3-filter-submit").click();
  await expect(page).toHaveURL(/filters%5Bq%5D=hostile/);

  await page.unroute(applicationScript);
  await page.reload();
  await expect(page.locator("#fixture-hostile")).toBeVisible();

  await page.route("**/__qualification/hypermedia/stream", (route) =>
    route.fulfill({
      status: 200,
      contentType: "text/event-stream",
      body: "event: datastar-patch-elements\ndata: malformed\n\n",
    })
  );
  await page.locator("#hui-b3-stream-submit").click();
  await expect(page.locator("#hui-b3-stream-reload")).toBeVisible();
});

test("browser requests fail closed for missing CSRF and oversized or authority signals", async ({
  page,
}, testInfo) => {
  test.skip(testInfo.project.name !== "chromium");
  const response = await page.goto(path);
  const csp = response.headers()["content-security-policy"];
  expect(csp).toContain("trusted-types datastar");
  expect(csp).not.toContain("unsafe-inline");
  expect(csp).not.toContain("unsafe-eval");

  const statuses = await page.evaluate(async () => {
    const missingCsrf = await fetch(
      "/__qualification/hypermedia/events/validate-note",
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "datastar-request": "true",
        },
        body: JSON.stringify({ note: "blocked without csrf" }),
      }
    );

    const oversized = encodeURIComponent(
      JSON.stringify({ q: "a".repeat(600) })
    );
    const oversizedResponse = await fetch(
      `/__qualification/hypermedia/fragments/results?datastar=${oversized}`,
      { headers: { "datastar-request": "true" } }
    );

    const authority = encodeURIComponent(
      JSON.stringify({ authority: "admin" })
    );
    const authorityResponse = await fetch(
      `/__qualification/hypermedia/fragments/results?datastar=${authority}`,
      { headers: { "datastar-request": "true" } }
    );

    return [
      missingCsrf.status,
      oversizedResponse.status,
      authorityResponse.status,
    ];
  });

  expect(statuses).toEqual([403, 422, 422]);
  await expect(page.locator("#hui-b3-results-region")).toBeVisible();
});

test("reconnect attempts are capped after a transport failure", async ({
  page,
}, testInfo) => {
  test.skip(testInfo.project.name !== "chromium");
  let attempts = 0;

  await page.route("**/__qualification/hypermedia/stream", (route) => {
    attempts += 1;
    return route.abort("failed");
  });

  await page.goto(path);
  await page.locator("#hui-b3-stream-submit").click();
  await page.waitForTimeout(7_000);
  expect(attempts).toBeGreaterThanOrEqual(1);
  expect(attempts).toBeLessThanOrEqual(3);
  await page.locator("#hui-b3-stream-reload").click();
  await expect(page.locator("#hui-b3-results-region")).toBeVisible();
});

test("semantic, keyboard, responsive, motion, contrast, RTL, touch, and theme smoke", async ({
  page,
}, testInfo) => {
  test.skip(testInfo.project.name === "chromium-no-js");
  await page.goto(path);

  await expect(page.getByRole("heading", { level: 1 })).toHaveText(
    "Datastar/Dstar consumer laboratory"
  );
  await expect(page.getByRole("main")).toHaveCount(1);
  expect(await page.locator("body").ariaSnapshot()).toContain(
    "Qualification only"
  );

  await page.keyboard.press("Tab");
  await expect(page.locator(":focus")).toBeVisible();
  await page.emulateMedia({
    reducedMotion: "reduce",
    colorScheme: "dark",
    forcedColors: testInfo.project.name.startsWith("chromium")
      ? "active"
      : "none",
  });
  await page.locator("html").evaluate((element) => {
    element.dir = "rtl";
    element.dataset.theme = "dark";
    element.style.zoom = "200%";
  });
  const overflow = await page.evaluate(
    () => document.documentElement.scrollWidth - innerWidth
  );
  expect(overflow).toBeLessThanOrEqual(1);

  if (testInfo.project.name === "chromium-touch") {
    expect(await page.evaluate(() => navigator.maxTouchPoints)).toBeGreaterThan(
      0
    );
  }
});
