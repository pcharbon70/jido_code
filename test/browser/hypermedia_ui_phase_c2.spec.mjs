import { expect, test } from "@playwright/test";

const path = "/__qualification/hypermedia?view=c2";
const appURL = `http://127.0.0.1:${Number(
  process.env.HUI_B3_APP_PORT || 4413
)}`;
const canonicalStates = [
  "ready",
  "empty",
  "stale",
  "incomplete",
  "contradicted",
  "truncated",
  "unauthorized",
  "unavailable",
  "maintenance",
  "recovery",
];
const stateLabels = [
  "Ready",
  "No results",
  "Stale",
  "Incomplete",
  "Contradicted",
  "Truncated",
  "Not available",
  "Unavailable",
  "Maintenance",
  "Recovery",
];
const desktopProjects = new Set(["chromium", "firefox", "webkit"]);

const expectRootTheme = async (page, appearance, resolved) => {
  const root = page.locator("html");
  await expect(root).toHaveAttribute("data-appearance", appearance);
  await expect(root).toHaveAttribute("data-theme", resolved);
  await expect(root).toHaveAttribute("data-shadcn-theme", resolved);
};

const persistedTheme = async (page) =>
  page.evaluate(() => ({
    storage: localStorage.getItem("phx:theme"),
    cookies: Object.fromEntries(
      document.cookie.split("; ").map((entry) => {
        const separator = entry.indexOf("=");
        return [entry.slice(0, separator), entry.slice(separator + 1)];
      })
    ),
  }));

const setServerFirstTheme = async (page, appearance, resolved) => {
  await page.goto(path);
  await page.evaluate(
    ({ appearance, resolved }) => {
      if (appearance === "system") localStorage.removeItem("phx:theme");
      else localStorage.setItem("phx:theme", appearance);

      document.cookie = `jido_appearance=${appearance}; Path=/; SameSite=Lax`;
      document.cookie = `jido_resolved_theme=${resolved}; Path=/; SameSite=Lax`;
    },
    { appearance, resolved }
  );
  await page.reload();
  await expect(page.locator("#hui-c2-qualification")).toBeVisible();
  await expectRootTheme(page, appearance, resolved);
};

test("renders one semantic shell, hostile text, bounded collections, and all ten projection states", async ({
  page,
}, testInfo) => {
  const response = await page.goto(path);
  expect(response.status()).toBe(200);
  const csp = response.headers()["content-security-policy"];
  expect(csp).not.toContain("unsafe-inline");
  expect(csp).not.toContain("unsafe-eval");

  await expect(page.locator("#hui-c2-qualification")).toBeVisible();
  await expect(page.locator("#hui-c2-shell")).toHaveAttribute(
    "data-application-shell",
    ""
  );
  await expect(page.locator("#hui-c2-masthead")).toHaveAttribute(
    "data-application-masthead",
    ""
  );
  await expect(page.locator("main#hui-c2-main")).toHaveCount(1);
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(
    "Application component qualification"
  );

  const primaryLabels = await page
    .locator("#hui-c2-primary-navigation a")
    .allTextContents();
  expect(primaryLabels.map((label) => label.trim())).toEqual([
    "Overview",
    "Projection states",
    "Primitive catalog",
  ]);

  for (const [index, state] of canonicalStates.entries()) {
    const projection = page.locator(`#hui-c2-state-${state}`);
    await expect(projection).toHaveAttribute("data-projection-state", state);
    await expect(projection.locator("h3")).toHaveText(stateLabels[index]);
  }

  for (const state of [
    "unauthorized",
    "unavailable",
    "maintenance",
    "recovery",
  ]) {
    const protectedCollection = page.locator(`#hui-c2-protected-${state}`);
    await expect(protectedCollection).toHaveAttribute(
      "data-projection-state",
      state
    );
    await expect(
      protectedCollection.locator("[data-fleet-row], [data-fleet-card]")
    ).toHaveCount(0);
  }

  await expect(page.getByText("PROTECTED-ROW-MUST-CLEAR")).toHaveCount(0);
  await expect(page.getByText("Hidden administration destination")).toHaveCount(
    0
  );
  await expect(page.locator("#hui-c2-attention [data-attention-item]")).toHaveCount(
    24
  );
  await expect(page.locator("#hui-c2-health [data-health-item]")).toHaveCount(
    12
  );
  await expect(page.locator("#hui-c2-attention-bounded-notice")).toContainText(
    "first 24"
  );
  await expect(page.locator("#hui-c2-health-bounded-notice")).toContainText(
    "first 12"
  );

  const hostileText =
    "<script id=\"hui-c2-hostile-script\">alert('unsafe')</script><img src=x onerror=alert(1)>";
  await expect(page.locator("#hui-c2-trust")).toContainText(hostileText);
  await expect(page.locator("#hui-c2-hostile-script")).toHaveCount(0);
  await expect(
    page.locator("#hui-c2-qualification script, #hui-c2-qualification [onerror]")
  ).toHaveCount(0);

  const identityFailures = await page.locator("#hui-c2-qualification").evaluate(
    (root) => {
      const allIds = [...document.querySelectorAll("[id]")].map(
        (element) => element.id
      );
      const duplicates = allIds.filter(
        (id, index) => allIds.indexOf(id) !== index
      );
      const missingReferences = [];

      for (const element of root.querySelectorAll(
        "[aria-labelledby], [aria-describedby], [aria-controls]"
      )) {
        for (const attribute of [
          "aria-labelledby",
          "aria-describedby",
          "aria-controls",
        ]) {
          const value = element.getAttribute(attribute);
          if (!value) continue;

          for (const id of value.trim().split(/\s+/)) {
            if (!document.getElementById(id)) {
              missingReferences.push(`${element.id || element.tagName}:${attribute}:${id}`);
            }
          }
        }
      }

      return { duplicates: [...new Set(duplicates)], missingReferences };
    }
  );
  expect(identityFailures).toEqual({ duplicates: [], missingReferences: [] });

  const assetFailures = await page.evaluate(() => {
    const remote = [...document.querySelectorAll("script[src], link[href], img[src]")]
      .map((element) => element.src || element.href)
      .filter((url) => url && !url.startsWith(location.origin));
    const inlineScripts = [...document.querySelectorAll("script:not([src])")].filter(
      (element) => element.textContent.trim() !== ""
    ).length;
    const inlineHandlers = [...document.querySelectorAll("*")].flatMap((element) =>
      [...element.attributes]
        .filter((attribute) => attribute.name.toLowerCase().startsWith("on"))
        .map((attribute) => `${element.id || element.tagName}:${attribute.name}`)
    );

    return { remote, inlineScripts, inlineHandlers };
  });
  expect(assetFailures).toEqual({
    remote: [],
    inlineScripts: 0,
    inlineHandlers: [],
  });

  if (testInfo.project.name !== "chromium-no-js") {
    await expect(page.locator("#application-theme-controls")).toBeVisible();
    await expect(page.locator("#application-theme-controls")).not.toHaveAttribute(
      "hidden",
      ""
    );
  }
});

test("keyboard order reaches the skip target and native disclosure, dialog, and menu controls", async ({
  page,
}, testInfo) => {
  test.skip(!desktopProjects.has(testInfo.project.name));
  await page.goto(path);

  await page.keyboard.press("Tab");
  await expect(page.locator("#hui-c2-shell-skip-link")).toBeFocused();
  await page.keyboard.press("Enter");
  await expect(page.locator("#hui-c2-main")).toBeFocused();

  const disclosure = page.locator("#hui-c2-disclosure-item-details");
  const disclosureSummary = page.locator(
    "#hui-c2-disclosure-item-details-summary"
  );
  await expect(disclosure).toHaveAttribute("open", "");
  await disclosureSummary.focus();
  await page.keyboard.press("Space");
  await expect(disclosure).not.toHaveAttribute("open", "");
  await page.keyboard.press("Enter");
  await expect(disclosure).toHaveAttribute("open", "");

  const dialogInvoker = page.locator("#hui-c2-dialog-invoker");
  const dialog = page.locator("#hui-c2-dialog-surface");
  const dialogClose = page.locator("#hui-c2-dialog-close");
  await page.keyboard.press("Tab");
  await expect(dialogInvoker).toBeFocused();
  await page.keyboard.press("Enter");
  await expect(dialog).toHaveAttribute("open", "");
  await expect(dialog).toBeVisible();
  await expect(dialogClose).toBeFocused();
  await page.keyboard.press("Escape");
  await expect(dialog).not.toHaveAttribute("open", "");
  await expect(dialogInvoker).toBeFocused();

  const menuInvoker = page.locator("#hui-c2-menu-invoker");
  const menuSurface = page.locator("#hui-c2-menu-surface");
  await page.keyboard.press("Tab");
  await expect(menuInvoker).toBeFocused();
  await page.keyboard.press("Enter");
  await expect(menuSurface).toBeVisible();
  await expect(
    menuSurface.getByRole("link", { name: "Inspect projection states" })
  ).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(menuSurface).not.toBeVisible();
  await expect(menuInvoker).toBeFocused();
});

test("accessible names and reading order remain explicit without duplicate control semantics", async ({
  page,
}, testInfo) => {
  test.skip(!desktopProjects.has(testInfo.project.name));
  await page.goto(path);

  await expect(
    page.getByRole("navigation", { name: "Primary navigation" })
  ).toHaveCount(1);
  await expect(page.getByRole("navigation", { name: "Breadcrumbs" })).toHaveCount(
    1
  );
  await expect(page.getByRole("search")).toHaveCount(1);
  await expect(
    page.getByRole("searchbox", { name: "Search the fixture" })
  ).toHaveCount(1);
  await expect(
    page.getByRole("combobox", { name: "Projection state" })
  ).toHaveCount(1);
  await expect(
    page.getByRole("checkbox", { name: "Include archived fixture rows" })
  ).toHaveCount(1);
  await expect(
    page.getByRole("group", { name: "Presentation mode" })
  ).toHaveCount(1);
  await expect(page.getByRole("radio", { name: "Summary" })).toHaveCount(1);
  await expect(
    page.getByRole("button", { name: "Open qualification dialog" })
  ).toHaveCount(1);
  await expect(
    page.getByRole("button", { name: "Read supplemental description" })
  ).toHaveCount(1);

  const navigationSnapshot = await page
    .locator("#hui-c2-primary-navigation")
    .ariaSnapshot();
  const overview = navigationSnapshot.indexOf('link "Overview"');
  const states = navigationSnapshot.indexOf('link "Projection states"');
  const catalog = navigationSnapshot.indexOf('link "Primitive catalog"');
  expect(overview).toBeGreaterThanOrEqual(0);
  expect(states).toBeGreaterThan(overview);
  expect(catalog).toBeGreaterThan(states);

  await page.locator("#hui-c2-dialog-invoker").click();
  await expect(
    page.getByRole("dialog", { name: "Native qualification dialog" })
  ).toBeVisible();
});

test("JavaScript-disabled navigation and GET forms retain server-first theme and content fallbacks", async ({
  page,
  context,
}, testInfo) => {
  test.skip(testInfo.project.name !== "chromium-no-js");
  test.slow();
  await context.addCookies([
    {
      name: "jido_appearance",
      value: "dark",
      url: appURL,
      sameSite: "Lax",
    },
    {
      name: "jido_resolved_theme",
      value: "dark",
      url: appURL,
      sameSite: "Lax",
    },
  ]);
  await page.goto(path);
  await expectRootTheme(page, "dark", "dark");

  const themeControls = page.locator("#application-theme-controls");
  await expect(themeControls).toHaveAttribute("hidden", "");
  await expect(themeControls).toBeHidden();
  await expect(page.locator("#application-theme-dark")).toHaveAttribute(
    "aria-pressed",
    "true"
  );
  await expect(page.locator("#application-theme-light")).toHaveAttribute(
    "aria-pressed",
    "false"
  );
  await expect(page.locator("#application-theme-system")).toHaveAttribute(
    "aria-pressed",
    "false"
  );
  await expect(page.locator("#application-theme-current")).toHaveText(
    "Current appearance: Dark. Controls require scripting."
  );
  expect(
    await page.locator("#application-theme-light").evaluate((control) => {
      control.focus();
      return document.activeElement === control;
    })
  ).toBe(false);

  await page.locator("#hui-c2-filter-search-query").fill("native qualification");
  await page
    .locator("#hui-c2-filter-search-filter-state")
    .selectOption("stale");
  await page.locator("#hui-c2-filter-search-submit").click();
  await expect(page.locator("#hui-c2-qualification")).toBeVisible();
  const filterURL = new URL(page.url());
  expect(filterURL.searchParams.get("q")).toBe("native qualification");
  expect(filterURL.searchParams.get("state")).toBe("stale");
  expect(filterURL.searchParams.get("view")).toBe("c2");
  await expect(page.locator("#hui-c2-filter-search-query")).toHaveValue(
    "native qualification"
  );
  await expect(
    page.locator("#hui-c2-filter-search-filter-state")
  ).toHaveValue("stale");
  await expect(page.locator("#hui-c2-native-result")).toHaveAttribute(
    "data-query",
    "native qualification"
  );
  await expect(page.locator("#hui-c2-native-result")).toHaveAttribute(
    "data-selected-state",
    "stale"
  );
  await expect(page.locator("#hui-c2-native-result-summary")).toContainText(
    "state stale"
  );
  await expect(page.locator("#hui-c2-native-projection")).toHaveAttribute(
    "data-projection-state",
    "stale"
  );
  await expect(page.locator("#hui-c2-native-projection")).toContainText("Stale");
  await expectRootTheme(page, "dark", "dark");

  await page.locator("#hui-c2-page-header-action-states").click();
  await expect(page).toHaveURL(/#hui-c2-state-matrix$/);
  await expect(page.locator("#hui-c2-state-matrix")).toBeVisible();

  const disclosure = page.locator("#hui-c2-disclosure-item-details");
  await page.locator("#hui-c2-disclosure-item-details-summary").click();
  await expect(disclosure).not.toHaveAttribute("open", "");

  await page.locator("#hui-c2-dialog-fallback-summary").click({ force: true });
  await expect(page.locator("#hui-c2-dialog-fallback")).toHaveAttribute(
    "open",
    ""
  );
  await expect(page.locator("#hui-c2-dialog-fallback")).toContainText(
    "remains available without scripting"
  );

  await page.locator("#hui-c2-menu-fallback-summary").click({ force: true });
  await expect(page.locator("#hui-c2-menu-fallback")).toHaveAttribute(
    "open",
    ""
  );
  await expect(page.locator("#hui-c2-menu-fallback-link")).toHaveAttribute(
    "href",
    "#hui-c2-state-matrix"
  );

  await page.locator("#hui-c2-application-pagination-page-1").click();
  await expect(page.locator("#hui-c2-native-result")).toHaveAttribute(
    "data-page",
    "1"
  );
  await expect(page.locator("#hui-c2-application-pagination-page-1")).toHaveAttribute(
    "aria-current",
    "page"
  );
  await expect(page.locator("#hui-c2-filter-search-query")).toHaveValue(
    "native qualification"
  );
  await expect(
    page.locator("#hui-c2-filter-search-filter-state")
  ).toHaveValue("stale");

  await page.locator("#hui-c2-fleet-health-heading-sort").click();
  await expect(page.locator("#hui-c2-fleet-health-heading")).toHaveAttribute(
    "aria-sort",
    "ascending"
  );
  await page.locator("#hui-c2-fleet-health-heading-sort").click();
  await expect(page.locator("#hui-c2-native-result")).toHaveAttribute(
    "data-sort",
    "health"
  );
  await expect(page.locator("#hui-c2-native-result")).toHaveAttribute(
    "data-direction",
    "descending"
  );
  await expect(page.locator("#hui-c2-fleet-health-heading")).toHaveAttribute(
    "aria-sort",
    "descending"
  );
  await expect(page.locator("#hui-c2-fleet [data-fleet-row]").first()).toContainText(
    "Stale"
  );

  await page.locator("#hui-c2-core-input").fill("native primitive form");
  await page.locator("#hui-c2-catalog-select").selectOption("compact");
  await page.locator("#hui-c2-catalog-checkbox").uncheck();
  await page.getByRole("radio", { name: "Details" }).check();
  await page.locator("#hui-c2-primitive-submit").click();
  await expect(page.locator("#hui-c2-qualification")).toBeVisible();
  const primitiveURL = new URL(page.url());
  expect(primitiveURL.searchParams.get("catalog_label")).toBe(
    "native primitive form"
  );
  expect(primitiveURL.searchParams.get("density")).toBe("compact");
  expect(primitiveURL.searchParams.get("mode")).toBe("details");
  expect(primitiveURL.searchParams.get("include_archived")).toBe("false");
  expect(primitiveURL.searchParams.get("view")).toBe("c2");
  await expect(page.locator("#hui-c2-core-input")).toHaveValue(
    "native primitive form"
  );
  await expect(page.locator("#hui-c2-catalog-select")).toHaveValue("compact");
  await expect(page.locator("#hui-c2-catalog-checkbox")).not.toBeChecked();
  await expect(page.getByRole("radio", { name: "Details" })).toBeChecked();
});

test("enhanced profiles hide fallback duplicates while preserving one visible action", async ({
  page,
}, testInfo) => {
  test.skip(testInfo.project.name === "chromium-no-js");
  await page.goto(path);

  for (const fallback of [
    "#hui-c2-account-menu-fallback-disclosure",
    "#hui-c2-dialog-fallback",
    "#hui-c2-menu-fallback",
  ]) {
    await expect(page.locator(fallback)).toHaveAttribute("hidden", "");
    await expect(page.locator(fallback)).toBeHidden();
  }

  const duplicateFallbackLabels = [
    "Open native baseline",
    "Jump to catalog",
    "Inspect projection states",
  ];
  const visibleLabelCounts = async () => {
    const labels = (await page.locator("a:visible").allTextContents()).map((label) =>
      label.trim()
    );
    return Object.fromEntries(
      duplicateFallbackLabels.map((label) => [
        label,
        labels.filter((candidate) => candidate === label).length,
      ])
    );
  };

  expect(Object.values(await visibleLabelCounts()).every((count) => count <= 1)).toBe(
    true
  );

  await page.locator("#hui-c2-menu-invoker").click();
  await expect(page.locator("#hui-c2-menu-surface")).toBeVisible();
  expect((await visibleLabelCounts())["Inspect projection states"]).toBe(1);
  await page.keyboard.press("Escape");

  if (desktopProjects.has(testInfo.project.name)) {
    await page.locator("#hui-c2-account-menu-invoker").click();
    await expect(page.locator("#hui-c2-account-menu-surface")).toBeVisible();
    const accountCounts = await visibleLabelCounts();
    expect(accountCounts["Open native baseline"]).toBe(1);
    expect(accountCounts["Jump to catalog"]).toBe(1);
  }
});

test("system, light, and dark choices synchronize and persist across reload", async ({
  page,
}, testInfo) => {
  test.skip(!desktopProjects.has(testInfo.project.name));
  await page.emulateMedia({ colorScheme: "dark" });
  await page.goto(path);

  await page.locator("#application-theme-light").click();
  await expectRootTheme(page, "light", "light");
  await expect(page.locator("#application-theme-light")).toHaveAttribute(
    "aria-pressed",
    "true"
  );
  let persisted = await persistedTheme(page);
  expect(persisted.storage).toBe("light");
  expect(persisted.cookies.jido_appearance).toBe("light");
  expect(persisted.cookies.jido_resolved_theme).toBe("light");
  await page.reload();
  await expectRootTheme(page, "light", "light");

  await page.locator("#application-theme-dark").click();
  await expectRootTheme(page, "dark", "dark");
  await expect(page.locator("#application-theme-dark")).toHaveAttribute(
    "aria-pressed",
    "true"
  );
  await page.reload();
  await expectRootTheme(page, "dark", "dark");

  await page.locator("#application-theme-system").click();
  await expectRootTheme(page, "system", "dark");
  await expect(page.locator("#application-theme-system")).toHaveAttribute(
    "aria-pressed",
    "true"
  );
  persisted = await persistedTheme(page);
  expect(persisted.storage).toBeNull();
  expect(persisted.cookies.jido_appearance).toBe("system");
  expect(persisted.cookies.jido_resolved_theme).toBe("dark");
  await page.reload();
  await expectRootTheme(page, "system", "dark");
});

test("narrow, zoomed, localized, RTL, reduced-motion, forced-colors, and print modes remain bounded", async ({
  page,
}, testInfo) => {
  test.skip(testInfo.project.name !== "chromium");
  await page.setViewportSize({ width: 320, height: 900 });
  await page.goto(path);

  const documentOverflow = () =>
    page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth
    );
  expect(await documentOverflow()).toBeLessThanOrEqual(1);
  await expect(page.locator("#hui-c2-page-header-summary")).toContainText(
    "Long localized qualification label"
  );
  await expect(page.locator("#hui-c2-fleet-cards")).toBeVisible();
  await expect(page.locator("#hui-c2-fleet-wide")).not.toBeVisible();

  await page.setViewportSize({ width: 640, height: 900 });
  await page.locator("html").evaluate((element) => {
    element.style.zoom = "200%";
  });
  expect(await documentOverflow()).toBeLessThanOrEqual(1);
  await page.locator("html").evaluate((element) => {
    element.style.zoom = "";
    element.dir = "rtl";
  });
  await expect(page.locator("html")).toHaveAttribute("dir", "rtl");
  expect(
    await page.locator("#hui-c2-catalog-table table").evaluate(
      (element) => getComputedStyle(element).direction
    )
  ).toBe("rtl");

  await page.emulateMedia({ reducedMotion: "reduce", colorScheme: "dark" });
  const reducedMotionDuration = await page
    .locator("#hui-c2-dialog-invoker")
    .evaluate((element) => ({
      animation: getComputedStyle(element).animationDuration,
      transition: getComputedStyle(element).transitionDuration,
    }));
  expect(Number.parseFloat(reducedMotionDuration.animation)).toBeLessThanOrEqual(
    0.001
  );
  expect(Number.parseFloat(reducedMotionDuration.transition)).toBeLessThanOrEqual(
    0.001
  );

  await page.emulateMedia({ forcedColors: "active", reducedMotion: "reduce" });
  expect(
    await page.evaluate(() => matchMedia("(forced-colors: active)").matches)
  ).toBe(true);
  const currentOutline = await page
    .locator('#hui-c2-primary-navigation [aria-current="page"]')
    .evaluate((element) => ({
      style: getComputedStyle(element).outlineStyle,
      width: getComputedStyle(element).outlineWidth,
    }));
  expect(currentOutline.style).not.toBe("none");
  expect(Number.parseFloat(currentOutline.width)).toBeGreaterThanOrEqual(2);

  await page.emulateMedia({
    media: "screen",
    forcedColors: "none",
    reducedMotion: "reduce",
  });
  const dialog = page.locator("#hui-c2-dialog-surface");
  const menuSurface = page.locator("#hui-c2-menu-surface");
  await page.locator("#hui-c2-dialog-invoker").click();
  await expect(dialog).toHaveAttribute("open", "");
  await menuSurface.evaluate((surface) => surface.showPopover());
  await expect(menuSurface).toBeVisible();

  await page.evaluate(() => window.dispatchEvent(new Event("beforeprint")));
  await page.emulateMedia({ media: "print", forcedColors: "none" });
  await expect(dialog).not.toBeVisible();
  await expect(menuSurface).not.toBeVisible();
  await expect(page.locator("#hui-c2-dialog-fallback")).toBeVisible();
  await expect(page.locator("#hui-c2-dialog-fallback-copy")).toHaveText(
    "Dialog content remains available without scripting. No application state is changed."
  );
  await expect(page.locator("#hui-c2-menu-fallback")).toBeVisible();
  await expect(page.locator("#hui-c2-menu-fallback-link")).toBeVisible();
  await expect(page.locator("#hui-c2-menu-fallback-link")).toHaveAttribute(
    "href",
    "#hui-c2-state-matrix"
  );

  await page.emulateMedia({ media: "screen" });
  await page.evaluate(() => window.dispatchEvent(new Event("afterprint")));
  await expect(page.locator("#hui-c2-dialog-fallback")).toHaveAttribute(
    "hidden",
    ""
  );
  await expect(page.locator("#hui-c2-menu-fallback")).toHaveAttribute(
    "hidden",
    ""
  );
});

test("Pixel touch presentation gives every visible effective control a 44 pixel target", async ({
  page,
}, testInfo) => {
  test.skip(testInfo.project.name !== "chromium-touch");
  await page.goto(path);
  expect(await page.evaluate(() => navigator.maxTouchPoints)).toBeGreaterThan(0);

  const undersized = await page.locator("#hui-c2-qualification").evaluate(
    (root) => {
      const visible = (element) => {
        const style = getComputedStyle(element);
        const rect = element.getBoundingClientRect();
        return (
          style.display !== "none" &&
          style.visibility !== "hidden" &&
          rect.width > 0 &&
          rect.height > 0
        );
      };

      return [
        ...root.querySelectorAll(
          'a, button, input:not([type="hidden"]), select, summary'
        ),
      ]
        .filter(visible)
        .map((control) => {
          let target = control;
          if (control.matches('input[type="checkbox"], input[type="radio"]')) {
            target =
              root.querySelector(`label[for="${CSS.escape(control.id)}"]`) ||
              control.closest("label") ||
              control;
          }

          const rect = target.getBoundingClientRect();
          return {
            selector:
              control.id ||
              `${control.tagName.toLowerCase()}[name="${control.getAttribute("name") || ""}"]`,
            width: Math.round(rect.width * 10) / 10,
            height: Math.round(rect.height * 10) / 10,
          };
        })
        .filter(({ width, height }) => width < 43.5 || height < 43.5);
    }
  );

  expect(undersized).toEqual([]);
});

test("desktop light and dark visual fixtures remain deterministic", async ({
  page,
}, testInfo) => {
  test.skip(testInfo.project.name !== "chromium");
  await page.setViewportSize({ width: 1440, height: 900 });

  await setServerFirstTheme(page, "light", "light");
  await expect(page).toHaveScreenshot("hui-c2-desktop-light.png", {
    animations: "disabled",
    caret: "hide",
  });

  await setServerFirstTheme(page, "dark", "dark");
  await expect(page).toHaveScreenshot("hui-c2-desktop-dark.png", {
    animations: "disabled",
    caret: "hide",
  });
});

test("narrow touch light and dark visual fixtures remain deterministic", async ({
  page,
}, testInfo) => {
  test.skip(testInfo.project.name !== "chromium-touch");

  await setServerFirstTheme(page, "light", "light");
  await expect(page).toHaveScreenshot("hui-c2-touch-light.png", {
    animations: "disabled",
    caret: "hide",
  });

  await setServerFirstTheme(page, "dark", "dark");
  await expect(page).toHaveScreenshot("hui-c2-touch-dark.png", {
    animations: "disabled",
    caret: "hide",
  });
});
