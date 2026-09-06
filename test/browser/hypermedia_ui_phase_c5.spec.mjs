import { expect, test } from "@playwright/test";

const login = "operator@example.test";
const credential = "test-named-human-credential";
const projectAlpha = "project_browser_alpha";
const projectBeta = "project_browser_beta";
const attemptAlpha = "attempt_browser_alpha";
const desktopProjects = new Set(["chromium", "firefox", "webkit"]);

const signIn = async (page, returnPath = "/factory") => {
  await page.goto(returnPath);
  await expect(page).toHaveURL(/\/sign-in\?/);
  await page.locator("input[name='session[login]']").fill(login);
  await page.locator("input[name='session[credential]']").fill(credential);
  await page.locator("#human-sign-in-submit").click();
  await expect(page).toHaveURL(new RegExp(`${returnPath.replaceAll("/", "\\/")}$`));
};

const assertNoHorizontalPageOverflow = async (page) => {
  const geometry = await page.evaluate(() => ({
    viewport: document.documentElement.clientWidth,
    content: document.documentElement.scrollWidth,
  }));
  expect(geometry.content).toBeLessThanOrEqual(geometry.viewport + 1);
};

test("critical native read journey retains one understandable page structure", async ({
  page,
}) => {
  await signIn(page);

  const routes = [
    ["/factory", "Needs attention"],
    ["/factory/fleet", "Fleet"],
    ["/projects", "Projects"],
    [`/projects/${projectAlpha}`, "Project overview"],
    [`/projects/${projectAlpha}/attempts`, "Project attempts"],
    [`/projects/${projectAlpha}/attempts/${attemptAlpha}`, "Attempt workspace"],
  ];

  for (const [path, heading] of routes) {
    const response = await page.goto(path);
    expect(response.status(), path).toBe(200);
    expect(response.headers()["cache-control"], path).toContain("no-store");
    await expect(page.locator("main#product-main")).toHaveCount(1);
    await expect(page.getByRole("heading", { level: 1, name: heading })).toHaveCount(1);
    await expect(page.getByRole("navigation", { name: "Breadcrumbs" })).toHaveCount(1);
    await expect(page.getByRole("button", { name: "Sign out" })).toHaveCount(1);
    await expect(page.getByRole("status").first()).toBeVisible();
  }

  const snapshot = await page.locator("#product-shell").ariaSnapshot();
  expect(snapshot).toContain('- banner');
  expect(snapshot).toContain('- main');
  expect(snapshot).toContain('- heading "Attempt workspace" [level=1]');
  expect(snapshot).toContain('- button "Sign out"');
  expect(snapshot.indexOf('- banner')).toBeLessThan(snapshot.indexOf('- main'));
});

test("keyboard, errors, project switching, and concealment preserve recovery", async ({
  page,
}, testInfo) => {
  test.skip(!desktopProjects.has(testInfo.project.name));
  await signIn(page);

  await page.keyboard.press("Tab");
  await expect(page.locator("#product-shell-skip-link")).toBeFocused();
  await page.keyboard.press("Enter");
  await expect(page.locator("#product-main")).toBeFocused();

  await page.locator("#product-project-switcher-select").selectOption(projectBeta);
  await page.locator("#product-project-switcher-submit").click();
  await expect(page).toHaveURL(new RegExp(`/projects/${projectBeta}$`));

  await page.goto(`/factory/fleet?q=${"x".repeat(129)}`);
  const alert = page.getByRole("alert", { name: "Review the filter values" });
  await expect(alert).toBeVisible();
  await expect(alert).toContainText("Search must be at most 128 bytes");
  await alert.getByRole("link", { name: "Search must be at most 128 bytes." }).click();
  await expect(page.locator("#product-filter-search-query")).toBeFocused();

  const concealed = await page.goto("/projects/project_not_authorized");
  expect(concealed.status()).toBe(404);
  await expect(page.locator("body")).toHaveText("Not found.");
});

test("zoom, RTL, reduced motion, forced colors, print, and touch remain usable", async ({
  page,
}, testInfo) => {
  await signIn(page, `/projects/${projectAlpha}/attempts/${attemptAlpha}`);
  await page.locator("html").evaluate((root) => root.setAttribute("dir", "rtl"));

  if (desktopProjects.has(testInfo.project.name)) {
    for (const width of [640, 320]) {
      await page.setViewportSize({ width, height: 800 });
      await expect(page.getByRole("heading", { level: 1, name: "Attempt workspace" })).toBeVisible();
      await assertNoHorizontalPageOverflow(page);
    }
  }

  if (testInfo.project.name === "chromium") {
    await page.emulateMedia({ reducedMotion: "reduce" });
    const motion = await page.locator("#product-shell").evaluate((root) => {
      const probe = root.querySelector("[data-ui-status]");
      const styles = getComputedStyle(probe);
      return { animation: styles.animationDuration, transition: styles.transitionDuration };
    });
    expect(Number.parseFloat(motion.animation)).toBeLessThanOrEqual(0.00001);
    expect(Number.parseFloat(motion.transition)).toBeLessThanOrEqual(0.00001);

    await page.emulateMedia({ forcedColors: "active" });
    await expect(page.locator("#product-breadcrumbs [aria-current='page']")).toBeVisible();

    await page.emulateMedia({ media: "print", forcedColors: "none" });
    await expect(page.locator("#product-main")).toBeVisible();
  }

  if (testInfo.project.name === "chromium-touch") {
    await assertNoHorizontalPageOverflow(page);
    const undersized = await page.locator("a, button, input, select, summary").evaluateAll((nodes) =>
      nodes
        .filter((node) => {
          const style = getComputedStyle(node);
          const box = node.getBoundingClientRect();
          return style.display !== "none" && box.width > 0 && box.height > 0 && (box.width < 44 || box.height < 44);
        })
        .map((node) => ({ id: node.id, box: node.getBoundingClientRect().toJSON() }))
    );
    expect(undersized).toEqual([]);
  }
});

test("JavaScript-disabled filters, pagination, retry, and session exit are native", async ({
  page,
}, testInfo) => {
  test.skip(testInfo.project.name !== "chromium-no-js");
  await signIn(page, "/factory/fleet");

  await page.locator("#product-filter-search-query").fill("blocked");
  await page.locator("#product-filter-search-filter-state").selectOption("blocked");
  await page.locator("#product-filter-search-submit").click();
  await expect(page).toHaveURL(/q=blocked&state=blocked$/);
  await expect(page.locator("#factory-fleet")).toHaveAttribute(
    "data-projection-state",
    "unavailable"
  );
  await page.locator("#factory-fleet-status-retry").click();
  await expect(page).toHaveURL(/q=blocked&state=blocked$/);
  await page.locator("#product-sign-out-submit").click();
  await expect(page).toHaveURL(/\/sign-in$/);
});
