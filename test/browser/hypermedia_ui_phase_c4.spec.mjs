import { expect, test } from "@playwright/test";

const login = "operator@example.test";
const credential = "test-named-human-credential";
const project = "project_browser_alpha";
const attempt = "attempt_browser_alpha";
const desktopProjects = new Set(["chromium", "firefox", "webkit"]);

const signIn = async (page, returnPath = "/factory") => {
  await page.goto(returnPath);
  await expect(page).toHaveURL(/\/sign-in\?/);
  await page.locator("input[name='session[login]']").fill(login);
  await page.locator("input[name='session[credential]']").fill(credential);
  await page.locator("#human-sign-in-submit").click();
  await expect(page).toHaveURL(new RegExp(`${returnPath.replaceAll("/", "\\/")}$`));
};

const assertSafeUnavailable = async (page, rootId) => {
  const root = page.locator(`#${rootId}`);
  await expect(root).toHaveAttribute("data-projection-state", "unavailable");
  await expect(root.locator("[data-projection-status]")).toHaveAttribute(
    "data-projection-state",
    "unavailable"
  );
  await expect(root.locator("[data-attention-item], [data-fleet-row], [data-read-collection-item]")).toHaveCount(0);
};

test("factory attention and fleet clear protected rows and expose only safe native retry", async ({
  page,
}) => {
  await signIn(page);

  for (const [path, rootId] of [
    ["/factory", "factory-attention"],
    ["/factory/fleet", "factory-fleet"],
    ["/projects", "project-catalog"],
  ]) {
    const response = await page.goto(path);
    expect(response.status(), path).toBe(200);
    expect(response.headers()["cache-control"]).toContain("no-store");
    await assertSafeUnavailable(page, rootId);
    await expect(page.locator(`#${rootId}-status-retry`)).toHaveAttribute("href", path);
    await expect(page.locator("main#product-main")).not.toContainText(/https?:\/\/[^\s]+/);
  }
});

test("project and attempt workspaces preserve identity separation without decorative controls", async ({
  page,
}, testInfo) => {
  test.skip(testInfo.project.name !== "chromium");
  await signIn(page);

  const workspaces = [
    [`/projects/${project}`, "project-overview-identity"],
    [`/projects/${project}/attempts`, "project-attempts"],
    [`/projects/${project}/wiki`, "project-wiki-summary"],
    [`/projects/${project}/dependencies`, "project-dependencies"],
    [`/projects/${project}/attempts/${attempt}`, "attempt-workspace-summary"],
  ];

  for (const [path, rootId] of workspaces) {
    const response = await page.goto(path);
    expect(response.status(), path).toBe(200);
    await expect(page.locator(`#${rootId}`)).toHaveAttribute(
      "data-projection-state",
      "unavailable"
    );
    await expect(
      page.getByRole("button", { name: /pause|stop|retry|approve/i })
    ).toHaveCount(0);
    await expect(
      page.locator(
        "main#product-main form[action*='pause'], main#product-main form[action*='stop'], main#product-main form[action*='retry'], main#product-main form[action*='approve']"
      )
    ).toHaveCount(0);
    await expect(page.locator("main#product-main")).not.toContainText(
      /urn:|graph:|PROTECTED-|attempt_browser_beta/
    );
  }
});

test("JavaScript-disabled projection retry, filtering, and reload remain native", async ({
  page,
}, testInfo) => {
  test.skip(testInfo.project.name !== "chromium-no-js");
  await signIn(page, "/factory/fleet");

  await page.locator("#product-filter-search-query").fill("blocked");
  await page.locator("#product-filter-search-filter-state").selectOption("blocked");
  await page.locator("#product-filter-search-submit").click();
  await expect(page).toHaveURL(/\/factory\/fleet\?q=blocked&state=blocked$/);
  await page.locator("#factory-fleet-status-retry").click();
  await expect(page).toHaveURL(/q=blocked&state=blocked$/);
  await page.reload();
  await expect(page.locator("#factory-fleet")).toHaveAttribute(
    "data-projection-state",
    "unavailable"
  );
});

test("projection workspaces retain keyboard, semantic-reference, zoom, RTL, and touch contracts", async ({
  page,
}, testInfo) => {
  await signIn(page, `/projects/${project}/attempts/${attempt}`);

  if (desktopProjects.has(testInfo.project.name)) {
    await page.keyboard.press("Tab");
    await expect(page.locator("#product-shell-skip-link")).toBeFocused();
    await page.keyboard.press("Enter");
    await expect(page.locator("#product-main")).toBeFocused();
  }

  const identityFailures = await page.locator("#product-main").evaluate((root) => {
    const ids = [...document.querySelectorAll("[id]")].map((node) => node.id);
    const duplicates = [...new Set(ids.filter((id, index) => ids.indexOf(id) !== index))];
    const missingReferences = [];

    for (const node of root.querySelectorAll("[aria-labelledby], [aria-describedby], [aria-controls]")) {
      for (const attribute of ["aria-labelledby", "aria-describedby", "aria-controls"]) {
        const value = node.getAttribute(attribute);
        if (!value) continue;
        for (const id of value.trim().split(/\s+/)) {
          if (!document.getElementById(id)) missingReferences.push(`${node.id}:${attribute}:${id}`);
        }
      }
    }

    return { duplicates, missingReferences };
  });
  expect(identityFailures).toEqual({ duplicates: [], missingReferences: [] });

  await page.locator("html").evaluate((root) => root.setAttribute("dir", "rtl"));
  await page.evaluate(() => {
    document.documentElement.style.zoom = "2";
  });
  await expect(page.locator("#attempt-workspace-summary")).toBeVisible();

  if (testInfo.project.name === "chromium-touch") {
    const geometry = await page.locator("#product-shell").evaluate((root) => ({
      viewport: document.documentElement.clientWidth,
      overflow: document.documentElement.scrollWidth,
      mainWidth: root.querySelector("#product-main").getBoundingClientRect().width,
    }));
    expect(geometry.overflow).toBeLessThanOrEqual(geometry.viewport + 1);
    expect(geometry.mainWidth).toBeGreaterThan(0);
  }
});
