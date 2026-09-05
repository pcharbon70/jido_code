import { expect, test } from "@playwright/test";

const login = "operator@example.test";
const credential = "test-named-human-credential";
const projectAlpha = "project_browser_alpha";
const projectBeta = "project_browser_beta";
const attemptAlpha = "attempt_browser_alpha";
const candidateAlpha = "candidate_browser_alpha";

const signIn = async (page, returnPath = "/factory") => {
  await page.goto(returnPath);
  await expect(page).toHaveURL(/\/sign-in\?/);
  await page.locator("input[name='session[login]']").fill(login);
  await page.locator("input[name='session[credential]']").fill(credential);
  await page.locator("#human-sign-in-submit").click();
  await expect(page).toHaveURL(new RegExp(`${returnPath.replaceAll("/", "\\/")}$`));
};

test("authenticated shell owns semantic navigation, focus, canonical, and safe asset contracts", async ({
  page,
}) => {
  await signIn(page);

  await expect(page.locator("#product-shell")).toHaveAttribute(
    "data-application-shell",
    ""
  );
  await expect(page.locator("main#product-main")).toHaveCount(1);
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(
    "Needs attention"
  );
  await expect(page.locator("#product-primary-navigation")).toHaveCount(1);
  await expect(page.getByRole("navigation", { name: "Breadcrumbs" })).toHaveCount(
    1
  );
  await expect(page.locator("link[rel='canonical']")).toHaveAttribute(
    "href",
    /\/factory$/
  );

  const duplicateIds = await page.locator("[id]").evaluateAll((nodes) => {
    const ids = nodes.map((node) => node.id);
    return [...new Set(ids.filter((id, index) => ids.indexOf(id) !== index))];
  });
  expect(duplicateIds).toEqual([]);

  const unsafeAssets = await page.evaluate(() => ({
    remote: [...document.querySelectorAll("script[src], link[href], img[src]")]
      .map((node) => node.src || node.href)
      .filter((url) => url && !url.startsWith(location.origin)),
    inlineHandlers: [...document.querySelectorAll("*")].flatMap((node) =>
      [...node.attributes]
        .filter((attribute) => attribute.name.toLowerCase().startsWith("on"))
        .map((attribute) => `${node.id || node.tagName}:${attribute.name}`)
    ),
  }));
  expect(unsafeAssets).toEqual({ remote: [], inlineHandlers: [] });
});

test("explicit route groups and durable deep links render from independently checked resources", async ({
  page,
}, testInfo) => {
  test.skip(testInfo.project.name !== "chromium");
  await signIn(page);

  const routes = [
    "/factory/fleet",
    "/projects",
    `/projects/${projectAlpha}`,
    `/projects/${projectAlpha}/attempts`,
    `/projects/${projectAlpha}/wiki`,
    `/projects/${projectAlpha}/dependencies`,
    `/projects/${projectAlpha}/attempts/${attemptAlpha}`,
    `/projects/${projectAlpha}/knowledge/security`,
    `/reviews/${candidateAlpha}`,
    "/operations",
    "/operations/costs",
    "/security",
    "/security/incidents",
    "/governance",
    "/account",
    "/account/sessions",
  ];

  for (const route of routes) {
    const response = await page.goto(route);
    expect(response.status(), route).toBe(200);
    await expect(page.locator("[data-product-route]")).toHaveCount(1);
    await expect(page.getByRole("heading", { level: 1 })).toHaveCount(1);
  }

  const concealed = await page.goto("/projects/project_unknown");
  expect(concealed.status()).toBe(404);
  await expect(page.locator("body")).toHaveText("Not found.");
});

test("JavaScript-disabled project switching, filtering, pagination, history, reload, and sign-out stay native", async ({
  page,
}, testInfo) => {
  test.skip(testInfo.project.name !== "chromium-no-js");
  await signIn(page);

  await page.locator("#product-project-switcher-select").selectOption(projectBeta);
  await page.locator("#product-project-switcher-submit").click();
  await expect(page).toHaveURL(new RegExp(`/projects/${projectBeta}$`));

  await page.goto("/factory/fleet");
  await page.locator("#product-filter-search-query").fill("waiting");
  await page.locator("#product-filter-search-filter-state").selectOption("blocked");
  await page.locator("#product-filter-search-submit").click();
  await expect(page).toHaveURL(/\/factory\/fleet\?q=waiting&state=blocked$/);
  await page.locator("#product-pagination-next").click();
  await expect(page).toHaveURL(/page=2/);
  await page.goBack();
  await expect(page).toHaveURL(/q=waiting&state=blocked$/);
  await page.reload();
  await expect(page.locator("#product-filter-search-query")).toHaveValue("waiting");

  await page.locator("#product-sign-out-submit").click();
  await expect(page).toHaveURL(/\/sign-in$/);
});

test("keyboard, RTL, zoom, and narrow/touch layouts preserve the main task", async ({
  page,
}, testInfo) => {
  await signIn(page);

  if (["chromium", "firefox", "webkit"].includes(testInfo.project.name)) {
    await page.keyboard.press("Tab");
    await expect(page.locator("#product-shell-skip-link")).toBeFocused();
    await page.keyboard.press("Enter");
    await expect(page.locator("#product-main")).toBeFocused();
  }

  await page.locator("html").evaluate((root) => root.setAttribute("dir", "rtl"));
  await expect(page.locator("#product-main")).toBeVisible();

  await page.evaluate(() => {
    document.documentElement.style.zoom = "2";
  });
  await expect(page.getByRole("heading", { level: 1 })).toBeVisible();

  if (testInfo.project.name === "chromium-touch") {
    const geometry = await page.locator("#product-shell").evaluate((root) => ({
      viewport: document.documentElement.clientWidth,
      overflow: document.documentElement.scrollWidth,
      mainWidth: root.querySelector("#product-main").getBoundingClientRect().width,
    }));
    expect(geometry.overflow).toBeLessThanOrEqual(geometry.viewport + 1);
    expect(geometry.mainWidth).toBeGreaterThan(0);
    await expect(page.locator("#product-responsive-navigation")).toBeVisible();
  }
});

test("recovery and unavailable step-up remain generic and usable without JavaScript", async ({
  page,
}, testInfo) => {
  test.skip(!["chromium", "chromium-no-js"].includes(testInfo.project.name));
  await page.goto("/recovery");
  await expect(page.locator("#human-recovery-unavailable")).toBeVisible();
  await page.locator("input[name='recovery[login]']").fill("unknown@example.test");
  await page.locator("#human-recovery-submit").click();
  await expect(page.locator("#human-recovery-notice")).toContainText(
    "If recovery is available"
  );

  await signIn(page);
  await page.goto("/step-up?return_to=/security");
  await expect(page.locator("#human-step-up-unavailable")).toBeVisible();
  await expect(page.locator("input[type='password']")).toHaveCount(0);
});
