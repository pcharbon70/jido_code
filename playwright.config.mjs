import { defineConfig, devices } from "@playwright/test";

const appPort = Number(process.env.HUI_B3_APP_PORT || 4413);
const proxyPort = Number(process.env.HUI_B3_PROXY_PORT || 4414);
const appURL = `http://127.0.0.1:${appPort}`;
const proxyURL = `http://127.0.0.1:${proxyPort}`;

export default defineConfig({
  testDir: "./test/browser",
  outputDir: "./test-results/hui-b3",
  fullyParallel: false,
  workers: 1,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 1 : 0,
  timeout: 30_000,
  expect: { timeout: 7_500 },
  reporter: process.env.CI ? [["line"], ["html", { open: "never" }]] : "line",
  webServer: [
    {
      command:
        `MIX_ENV=test PHX_SERVER=true PORT=${appPort} ` +
        "PHX_HOST=127.0.0.1 " +
        "JIDO_CODE_HUI_QUALIFICATION_ENABLED=true " +
        "JIDO_CODE_HUI_QUALIFICATION_HOSTS=127.0.0.1 " +
        "JIDO_CODE_HUI_BROWSER_ASSETS=production mix phx.server",
      url: `${appURL}/__qualification/hypermedia`,
      timeout: 120_000,
      reuseExistingServer: false,
    },
    {
      command:
        `HUI_B3_PROXY_PORT=${proxyPort} HUI_B3_UPSTREAM_PORT=${appPort} ` +
        "node test/browser/support/streaming_proxy.mjs",
      url: `${proxyURL}/__proxy_health`,
      timeout: 30_000,
      reuseExistingServer: false,
    },
  ],
  use: {
    baseURL: appURL,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
  },
  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"] } },
    { name: "firefox", use: { ...devices["Desktop Firefox"] } },
    { name: "webkit", use: { ...devices["Desktop Safari"] } },
    {
      name: "chromium-no-js",
      use: { ...devices["Desktop Chrome"], javaScriptEnabled: false },
    },
    {
      name: "chromium-touch",
      use: { ...devices["Pixel 7"] },
    },
  ],
});
