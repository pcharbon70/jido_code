import { chromium } from "@playwright/test";

const baseURL = process.env.HUI_C5_APP_URL || "http://127.0.0.1:4413";
const executablePath = process.env.HUI_C5_CHROME || "/usr/bin/google-chrome";

const browser = await chromium.launch({
  headless: false,
  executablePath,
  args: ["--force-renderer-accessibility", "--disable-gpu", "--no-sandbox"],
});

try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
  await page.goto(`${baseURL}/factory`);
  await page.locator("input[name='session[login]']").fill("operator@example.test");
  await page
    .locator("input[name='session[credential]']")
    .fill("test-named-human-credential");
  await page.locator("#human-sign-in-submit").click();
  await page.waitForURL(/\/factory$/);

  const journey = [
    ["/factory", "Needs attention"],
    ["/factory/fleet", "Fleet"],
    ["/projects", "Projects"],
    ["/projects/project_browser_alpha", "Project overview"],
    [
      "/projects/project_browser_alpha/attempts/attempt_browser_alpha",
      "Attempt workspace",
    ],
  ];

  const observations = [];
  for (const [path, heading] of journey) {
    await page.goto(`${baseURL}${path}`);
    const title = page.getByRole("heading", { level: 1, name: heading });
    await title.focus();
    await page.waitForTimeout(700);
    observations.push({ path, heading, snapshot: await title.ariaSnapshot() });
  }

  await page.keyboard.press("Home");
  await page.keyboard.press("Tab");
  await page.waitForTimeout(700);
  await page.locator("#product-main").focus();
  await page.waitForTimeout(700);

  process.stdout.write(`${JSON.stringify({ result: "pass", observations }, null, 2)}\n`);
} finally {
  await browser.close();
}
