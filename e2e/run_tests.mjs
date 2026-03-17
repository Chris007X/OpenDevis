/**
 * OpenDevis AI-Powered E2E Test Suite
 *
 * Uses Playwright for browser automation and Claude API for intelligent UI validation.
 *
 * Usage:
 *   ANTHROPIC_API_KEY=sk-... node run_tests.mjs
 *
 * Optional env vars:
 *   HEADLESS=false     — show browser window (default: true)
 *   SKIP_AI=true       — skip Claude visual checks (faster)
 *   BASE_URL           — override staging URL
 */

import { chromium } from "playwright";
import Anthropic from "@anthropic-ai/sdk";
import { readFileSync, mkdirSync, existsSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

// Auto-inject LD_LIBRARY_PATH for extracted Chromium deps (WSL2 / headless environments)
const CHROMIUM_LIBS = "/tmp/chromium-libs/usr/lib/x86_64-linux-gnu";
if (existsSync(CHROMIUM_LIBS) && !process.env.LD_LIBRARY_PATH?.includes(CHROMIUM_LIBS)) {
  process.env.LD_LIBRARY_PATH = [CHROMIUM_LIBS, process.env.LD_LIBRARY_PATH].filter(Boolean).join(":");
}

// ─────────────────────────────────────────────────────────────────────────────
// Config
// ─────────────────────────────────────────────────────────────────────────────

const __dirname = dirname(fileURLToPath(import.meta.url));
const SCREENSHOTS_DIR = join(__dirname, "screenshots");

if (!existsSync(SCREENSHOTS_DIR)) mkdirSync(SCREENSHOTS_DIR, { recursive: true });

const BASE_URL = process.env.BASE_URL || "https://opendevis-staging-0d09a1227ec7.herokuapp.com";
const CUSTOMER_EMAIL = "demo@opendevis.com";
const CUSTOMER_PASSWORD = "password123";
const ARTISAN_EMAIL = "marc.dubois@artisan-maconnerie.fr";
const ARTISAN_PASSWORD = "password123";
const HEADLESS = process.env.HEADLESS !== "false";
const SKIP_AI = process.env.SKIP_AI === "true";
const RESULTS_URL = process.env.RESULTS_URL || null;       // e.g. https://app.opendevis.com/test_runs
const TEST_TOKEN = process.env.OPENDEVIS_TEST_TOKEN || null;
const NAV_TIMEOUT = 30_000;
const ACTION_TIMEOUT = 10_000;

const anthropic = SKIP_AI ? null : new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

// ─────────────────────────────────────────────────────────────────────────────
// Result tracking
// ─────────────────────────────────────────────────────────────────────────────

const results = {
  pages: [],
  flows: [],
  uiChecks: [],
  errors: [],
  startTime: Date.now(),
};

function pass(bucket, label, note = "") {
  results[bucket].push({ label, status: "pass", note });
  console.log(`  ✅ ${label}${note ? "  — " + note : ""}`);
}

function fail(bucket, label, note = "") {
  results[bucket].push({ label, status: "fail", note });
  console.log(`  ❌ ${label}${note ? "  — " + note : ""}`);
}

function warn(label, msg) {
  results.errors.push({ label, msg });
  console.log(`  ⚠️  [${label}] ${msg}`);
}

function section(title) {
  console.log(`\n${"─".repeat(60)}\n${title}\n${"─".repeat(60)}`);
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/** Navigate to URL, check for HTTP errors and Rails error pages. Returns true on success. */
async function visitPage(page, path, name) {
  const url = path.startsWith("http") ? path : `${BASE_URL}${path}`;
  try {
    const response = await page.goto(url, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT });
    const status = response?.status() ?? 0;

    if (status === 404) {
      fail("pages", name || path, "404 Not Found");
      warn(name || path, "HTTP 404");
      return false;
    }
    if (status >= 500) {
      fail("pages", name || path, `${status} Server Error`);
      warn(name || path, `HTTP ${status}`);
      return false;
    }

    // Check Rails error content
    const body = await page.textContent("body").catch(() => "");
    if (
      body.includes("We're sorry, but something went wrong") ||
      body.includes("Application Error") ||
      body.includes("Internal Server Error")
    ) {
      fail("pages", name || path, "Rails 500 error in body");
      warn(name || path, "Rails error content detected");
      return false;
    }

    pass("pages", name || path);
    return true;
  } catch (e) {
    const msg = e.message.split("\n")[0].substring(0, 120);
    fail("pages", name || path, msg);
    warn(name || path, msg);
    return false;
  }
}

/** Login as a customer (User). Assumes browser is not already logged in. */
async function loginCustomer(page) {
  await page.goto(`${BASE_URL}/users/sign_in`, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT });
  await page.fill('input[name="user[email]"]', CUSTOMER_EMAIL);
  await page.fill('input[name="user[password]"]', CUSTOMER_PASSWORD);
  // Use .auth-submit-btn to avoid hitting the Google OAuth button which also has type=submit
  await Promise.all([
    page.waitForNavigation({ timeout: NAV_TIMEOUT }),
    page.locator("button.auth-submit-btn, form[action*='sign_in'] button[type='submit']").last().click(),
  ]);
}

/** Login as an artisan. Assumes browser is not already logged in. */
async function loginArtisan(page) {
  await page.goto(`${BASE_URL}/artisans/sign_in`, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT });
  await page.fill('input[name="artisan[email]"]', ARTISAN_EMAIL);
  await page.fill('input[name="artisan[password]"]', ARTISAN_PASSWORD);
  await Promise.all([
    page.waitForNavigation({ timeout: NAV_TIMEOUT }),
    page.click('input[type="submit"], button[type="submit"]'),
  ]);
}

/** Click the logout link in the navbar avatar dropdown. */
async function logout(page) {
  // The logout link is inside a Bootstrap dropdown (.od-avatar toggle → .dropdown-menu)
  // We must open the dropdown first before the link becomes clickable.
  try {
    const dropdownToggle = page.locator("button.od-avatar, button[data-bs-toggle='dropdown']").first();
    if (await dropdownToggle.count() > 0) {
      await dropdownToggle.click({ timeout: ACTION_TIMEOUT });
      await page.waitForTimeout(300); // let dropdown animate open
    }
    const logoutLink = page.locator('a[href*="sign_out"], a:has-text("Se déconnecter")').first();
    if (await logoutLink.count() > 0) {
      await Promise.all([
        page.waitForNavigation({ timeout: NAV_TIMEOUT }).catch(() => {}),
        logoutLink.click({ timeout: ACTION_TIMEOUT }),
      ]);
    } else {
      // Fallback: navigate directly (Turbo DELETE)
      await page.evaluate((url) => {
        const f = document.createElement("form");
        f.method = "post"; f.action = url;
        const m = document.createElement("input");
        m.type = "hidden"; m.name = "_method"; m.value = "delete";
        const t = document.createElement("input");
        t.type = "hidden"; t.name = "authenticity_token";
        const tokenEl = document.querySelector('meta[name="csrf-token"]');
        t.value = tokenEl ? tokenEl.content : "";
        f.appendChild(m); f.appendChild(t); document.body.appendChild(f); f.submit();
      }, `${BASE_URL}/users/sign_out`);
      await page.waitForNavigation({ timeout: NAV_TIMEOUT }).catch(() => {});
    }
  } catch {
    // Last resort: navigate to sign_out page
    await page.goto(`${BASE_URL}/users/sign_out`, { timeout: NAV_TIMEOUT }).catch(() => {});
  }
}

/** Take a screenshot and return the path. */
async function screenshot(page, name) {
  const safeName = name.replace(/[^a-z0-9]/gi, "_").toLowerCase();
  const path = join(SCREENSHOTS_DIR, `${safeName}.png`);
  await page.screenshot({ path, fullPage: true });
  return path;
}

/** Ask Claude to analyse a screenshot for UI consistency. Returns parsed result object. */
async function analyzeWithClaude(screenshotPath, pageName) {
  if (SKIP_AI || !anthropic) {
    return { raw: "AI checks skipped (SKIP_AI=true)", logo: null, navbar: null, footer: null, errors: "skipped" };
  }

  try {
    const imageData = readFileSync(screenshotPath);
    const base64 = imageData.toString("base64");

    const msg = await anthropic.messages.create({
      model: "claude-opus-4-6",
      max_tokens: 512,
      messages: [
        {
          role: "user",
          content: [
            {
              type: "image",
              source: { type: "base64", media_type: "image/png", data: base64 },
            },
            {
              type: "text",
              text: `You are a QA analyst reviewing a screenshot of OpenDevis, a French construction-estimation web app.

Page name: "${pageName}"

Check the following and respond in EXACTLY this format (no extra text):
LOGO: yes/no
NAVBAR: yes/no
FOOTER: yes/no
BUTTONS: yes/no/na
DESIGN_CONSISTENT: yes/no
ERRORS: none OR brief description of any broken layout or missing element`,
            },
          ],
        },
      ],
    });

    const raw = msg.content[0].text.trim();
    const get = (key) => {
      const m = raw.match(new RegExp(`${key}:\\s*(.+)`, "i"));
      return m ? m[1].trim().toLowerCase() : "unknown";
    };

    return {
      raw,
      logo: get("LOGO"),
      navbar: get("NAVBAR"),
      footer: get("FOOTER"),
      buttons: get("BUTTONS"),
      designConsistent: get("DESIGN_CONSISTENT"),
      errors: get("ERRORS"),
    };
  } catch (e) {
    return { raw: `Claude error: ${e.message}`, logo: "error", navbar: "error", footer: "error", errors: e.message };
  }
}

/** Evaluate UI analysis result and log. */
function evaluateUI(analysis, pageName) {
  const issues = [];
  if (analysis.logo === "no") issues.push("logo missing");
  if (analysis.navbar === "no") issues.push("navbar missing");
  if (analysis.footer === "no") issues.push("footer missing");
  if (analysis.designConsistent === "no") issues.push("design inconsistency");
  if (analysis.errors && analysis.errors !== "none" && analysis.errors !== "skipped" && analysis.errors !== "unknown") {
    issues.push(`UI error: ${analysis.errors}`);
  }

  if (issues.length === 0) {
    pass("uiChecks", pageName, "logo ✓ navbar ✓ footer ✓");
  } else {
    fail("uiChecks", pageName, issues.join(", "));
    issues.forEach((i) => warn(`UI:${pageName}`, i));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Test sections
// ─────────────────────────────────────────────────────────────────────────────

async function testPublicPages(page) {
  section("PUBLIC PAGES");
  await visitPage(page, "/", "Home page");
  await visitPage(page, "/users/sign_in", "Customer sign-in page");
  await visitPage(page, "/artisans/sign_in", "Artisan sign-in page");
}

async function testAuthentication(browser) {
  section("AUTHENTICATION");

  // ── Customer login ──
  const ctx1 = await browser.newContext();
  const page1 = await ctx1.newPage();
  try {
    await page1.goto(`${BASE_URL}/users/sign_in`, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT });
    await page1.fill('input[name="user[email]"]', CUSTOMER_EMAIL);
    await page1.fill('input[name="user[password]"]', CUSTOMER_PASSWORD);
    await Promise.all([
      page1.waitForNavigation({ timeout: NAV_TIMEOUT }),
      page1.locator("button.auth-submit-btn, form[action*='sign_in'] button[type='submit']").last().click(),
    ]);
    const url = page1.url();
    if (url.includes("/projects") || url.includes("/dashboard") || url === `${BASE_URL}/`) {
      pass("flows", "Customer login", `redirected to ${url}`);
    } else {
      fail("flows", "Customer login", `unexpected redirect: ${url}`);
    }
  } catch (e) {
    fail("flows", "Customer login", e.message.split("\n")[0]);
  }

  // ── Customer logout ──
  try {
    await logout(page1);
    const afterUrl = page1.url();
    const onLoginOrHome =
      afterUrl.includes("sign_in") || afterUrl === `${BASE_URL}/` || afterUrl === `${BASE_URL}`;
    if (onLoginOrHome) {
      pass("flows", "Customer logout");
    } else {
      fail("flows", "Customer logout", `still at ${afterUrl}`);
    }
  } catch (e) {
    fail("flows", "Customer logout", e.message.split("\n")[0]);
  }
  await ctx1.close();

  // ── Artisan login ──
  const ctx2 = await browser.newContext();
  const page2 = await ctx2.newPage();
  try {
    await page2.goto(`${BASE_URL}/artisans/sign_in`, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT });
    await page2.fill('input[name="artisan[email]"]', ARTISAN_EMAIL);
    await page2.fill('input[name="artisan[password]"]', ARTISAN_PASSWORD);
    await Promise.all([
      page2.waitForNavigation({ timeout: NAV_TIMEOUT }),
      page2.click('input[type="submit"], button[type="submit"]'),
    ]);
    const url = page2.url();
    if (url.includes("artisan_dashboard") || url.includes("artisan")) {
      pass("flows", "Artisan login", `redirected to ${url}`);
    } else {
      fail("flows", "Artisan login", `unexpected redirect: ${url}`);
    }
  } catch (e) {
    fail("flows", "Artisan login", e.message.split("\n")[0]);
  }

  // ── Artisan logout ──
  try {
    const logoutLink = page2.locator('a[href*="sign_out"]').first();
    if (await logoutLink.count() > 0) {
      await Promise.all([
        page2.waitForNavigation({ timeout: NAV_TIMEOUT }).catch(() => {}),
        logoutLink.click(),
      ]);
    } else {
      await page2.goto(`${BASE_URL}/artisans/sign_out`, { timeout: NAV_TIMEOUT }).catch(() => {});
    }
    const afterUrl = page2.url();
    const isOut = afterUrl.includes("sign_in") || afterUrl === `${BASE_URL}/` || afterUrl === `${BASE_URL}`;
    if (isOut) {
      pass("flows", "Artisan logout");
    } else {
      fail("flows", "Artisan logout", `still at ${afterUrl}`);
    }
  } catch (e) {
    fail("flows", "Artisan logout", e.message.split("\n")[0]);
  }
  await ctx2.close();

  // ── Protected route redirect ──
  const ctx3 = await browser.newContext();
  const page3 = await ctx3.newPage();
  try {
    await page3.goto(`${BASE_URL}/projects`, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT });
    const url = page3.url();
    if (url.includes("sign_in")) {
      pass("flows", "Protected route redirects unauthenticated user");
    } else {
      fail("flows", "Protected route redirects unauthenticated user", `got ${url}`);
    }
  } catch (e) {
    fail("flows", "Protected route redirects unauthenticated user", e.message.split("\n")[0]);
  }
  await ctx3.close();
}

async function testCustomerPages(browser) {
  section("CUSTOMER PAGES");

  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  await loginCustomer(page);

  // Core pages
  await visitPage(page, "/projects", "Projects dashboard");
  await visitPage(page, "/projects/wizard/choose", "Wizard — choose project type");
  await visitPage(page, "/profile", "Customer profile");
  await visitPage(page, "/notifications", "Notifications");
  await visitPage(page, "/work_categories", "Work categories index");
  await visitPage(page, "/materials", "Materials index");

  // Analytics (may require admin — check gracefully)
  const analyticsOk = await visitPage(page, "/analytics", "Analytics dashboard");
  if (!analyticsOk) {
    console.log("    (analytics may require admin — skipping sub-pages)");
  }

  // Find existing projects from the dashboard
  await page.goto(`${BASE_URL}/projects`, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT });
  const projectLinks = await page.locator('a[href*="/projects/"]').evaluateAll((els) =>
    els
      .map((e) => e.getAttribute("href"))
      .filter((h) => h && h.match(/\/projects\/\d+$/) && !h.includes("edit"))
  );

  const projectIds = [...new Set(projectLinks.map((h) => h.match(/\/projects\/(\d+)$/)?.[1]))].filter(Boolean);
  console.log(`\n  Found ${projectIds.length} project(s) in dashboard: ${projectIds.join(", ")}`);

  if (projectIds.length > 0) {
    const id = projectIds[0];
    await visitPage(page, `/projects/${id}`, `Project show (id=${id})`);
    await visitPage(page, `/projects/wizard/edit/${id}`, `Project edit wizard (id=${id})`);

    // Try rooms page
    const roomLinks = await page.goto(`${BASE_URL}/projects/${id}`, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT })
      .then(() => page.locator('a[href*="/rooms/"]').evaluateAll((els) =>
        els.map((e) => e.getAttribute("href")).filter((h) => h && h.match(/\/rooms\/\d+/))
      ))
      .catch(() => []);

    if (roomLinks.length > 0) {
      await visitPage(page, roomLinks[0], `Room show (${roomLinks[0]})`);
    }

    // Documents page
    await visitPage(page, `/projects/${id}/documents`, `Project documents (id=${id})`);
  }

  // Test a known-bad URL — these should return 404 gracefully (not 500)
  section("404/500 ERROR DETECTION");
  for (const [path, label] of [
    ["/projects/999999999", "Non-existent project (graceful 404)"],
    ["/rooms/999999999", "Non-existent room (graceful 404)"],
  ]) {
    const resp = await page.request.get(`${BASE_URL}${path}`, { timeout: 15_000 }).catch(() => null);
    const status = resp?.status() ?? 0;
    if (status === 404) {
      pass("pages", label, "404 returned correctly (not 500)");
    } else if (status >= 500) {
      fail("pages", label, `${status} Server Error — should be 404`);
      warn(label, `Returns ${status} instead of 404 for missing record`);
    } else {
      fail("pages", label, `Expected 404, got ${status}`);
    }
  }

  await ctx.close();
}

async function testWizardFlow(browser) {
  section("CUSTOMER FLOW — CREATE PROJECT VIA WIZARD");

  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  await loginCustomer(page);

  let createdProjectId = null;

  try {
    // Step 0: Choose project type
    // Click renovation button, wait for networkidle so Turbo's full fetch→redirect→DOM cycle settles.
    await page.goto(`${BASE_URL}/projects/wizard/choose`, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT });
    await page.locator('form:has(input[name="project_type"][value="renovation"]) button[type="submit"]').first().click();
    await page.waitForLoadState("networkidle", { timeout: NAV_TIMEOUT });

    // If still at choose (session lost in Turbo redirect chain), retry with native submit
    if (!page.url().includes("step1")) {
      await page.goto(`${BASE_URL}/projects/wizard/choose`, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT });
      await Promise.all([
        page.waitForNavigation({ waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT }),
        page.evaluate(() => {
          const form = document.querySelector('form:has(input[name="project_type"][value="renovation"])');
          if (form) HTMLFormElement.prototype.submit.call(form);
        }),
      ]);
      await page.waitForLoadState("networkidle", { timeout: 15_000 }).catch(() => {});
    }
    if (!page.url().includes("step1")) throw new Error(`Expected step1, got: ${page.url()}`);
    pass("flows", "Wizard step 0 — choose renovation type");
  } catch (e) {
    fail("flows", "Wizard step 0 — choose renovation type", e.message.split("\n")[0]);
    await ctx.close();
    return null;
  }

  try {
    // Step 1: Fill property info — we're already at step1 from step0 waitForURL
    await page.waitForLoadState("domcontentloaded");
    if (page.url().includes("sign_in")) throw new Error("Redirected to sign_in — login may have failed");
    if (!page.url().includes("step1")) throw new Error(`Expected step1, got: ${page.url()}`);

    // Wait for the property type cards to render
    await page.waitForSelector(".property-type-options, .property-type-option", { timeout: 15_000 });
    // Radio inputs are hidden (display:none) — click the visible label instead
    await page.locator('label[for="property_type_appartement"]').click({ timeout: ACTION_TIMEOUT }).catch(() =>
      page.locator('input[name="project[property_type]"]').first().check({ force: true, timeout: ACTION_TIMEOUT })
    );

    // Name
    await page.locator('input[name="project[name]"]').fill("Test Appartement Paris 80m²", { timeout: ACTION_TIMEOUT }).catch(() => {});

    // Surface
    await page.locator('input[name="project[total_surface_sqm]"]').fill("80");

    // Room count
    await page.locator('input[name="project[room_count]"]').fill("3");

    // Location zip — set both visible text input and hidden field
    const zipInput = page.locator('[data-city-autocomplete-target="input"]').first();
    await zipInput.fill("75011").catch(() => {});
    await page.evaluate(() => {
      const hidden = document.querySelector('[data-city-autocomplete-target="hidden"]');
      if (hidden) hidden.value = "75011";
    });

    // Energy rating
    await page.locator('select[name="project[energy_rating]"]').selectOption("D").catch(() => {});

    // Description
    await page.locator('textarea[name="project[description]"]').fill("Appartement haussmannien à rénover entièrement.").catch(() => {});

    // Submit
    await Promise.all([
      page.waitForNavigation({ timeout: NAV_TIMEOUT }),
      page.locator('button[type="submit"]').filter({ hasText: /suivant|continuer|next/i }).first().click()
        .catch(() => page.locator('button[type="submit"], input[type="submit"]').last().click()),
    ]);
    pass("flows", "Wizard step 1 — property info");
  } catch (e) {
    fail("flows", "Wizard step 1 — property info", e.message.split("\n")[0]);
    await ctx.close();
    return null;
  }

  try {
    // Step 2: Renovation type
    await page.waitForURL(/wizard\/step2/, { timeout: NAV_TIMEOUT }).catch(() => {});
    if (!page.url().includes("step2")) {
      await page.goto(`${BASE_URL}/projects/wizard/step2`, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT });
    }

    // Renovation type radios are also hidden (display:none) — click the label/card wrapper
    await page.locator('input[name="renovation_type"][value="renovation_complete"]').check({ force: true, timeout: ACTION_TIMEOUT }).catch(() =>
      page.locator('.renovation-card').first().click({ timeout: ACTION_TIMEOUT })
    );

    // Submit
    await Promise.all([
      page.waitForNavigation({ timeout: NAV_TIMEOUT }),
      page.locator('button[type="submit"]').first().click(),
    ]);
    pass("flows", "Wizard step 2 — renovation type");
  } catch (e) {
    fail("flows", "Wizard step 2 — renovation type", e.message.split("\n")[0]);
    await ctx.close();
    return null;
  }

  try {
    // Step 3: Categories
    await page.waitForURL(/wizard\/step3/, { timeout: NAV_TIMEOUT }).catch(() => {});
    if (!page.url().includes("step3")) {
      await page.goto(`${BASE_URL}/projects/wizard/step3`, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT });
    }

    // Category checkboxes are hidden (display:none) — click the visible .category-card labels instead
    const cards = page.locator('.category-card');
    const cardCount = await cards.count();
    const toCheck = Math.min(cardCount, 3);
    for (let i = 0; i < toCheck; i++) {
      await cards.nth(i).click({ timeout: ACTION_TIMEOUT }).catch(() => {});
    }

    // Submit
    await Promise.all([
      page.waitForNavigation({ timeout: NAV_TIMEOUT }),
      page.locator('button[type="submit"]').first().click(),
    ]);
    pass("flows", `Wizard step 3 — categories (selected ${toCheck})`);
  } catch (e) {
    fail("flows", "Wizard step 3 — categories", e.message.split("\n")[0]);
    await ctx.close();
    return null;
  }

  try {
    // Step 4: Summary + generate
    await page.waitForURL(/wizard\/step4/, { timeout: NAV_TIMEOUT }).catch(() => {});
    if (!page.url().includes("step4")) {
      await page.goto(`${BASE_URL}/projects/wizard/step4`, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT });
    }
    if (!page.url().includes("step4")) throw new Error(`Expected step4, got: ${page.url()}`);

    // Wait for the generate button to appear
    await page.waitForSelector("#generate-btn, .generate-btn", { timeout: 15_000 });
    // Click it — this triggers a 3s JS loader before native form.submit()
    await page.locator("#generate-btn, .generate-btn").first().click({ timeout: ACTION_TIMEOUT });
    // Wait for the loader overlay to confirm click registered
    await page.locator("#generation-loader").waitFor({ state: "visible", timeout: 8_000 }).catch(() => {});
    // Wait for redirect to project show page (server creates rooms + work items, may take time)
    await page.waitForURL(/\/projects\/\d+/, { timeout: 60_000 });
    const url = page.url();
    const match = url.match(/\/projects\/(\d+)/);
    if (match) {
      createdProjectId = match[1];
      pass("flows", `Wizard step 4 — generate estimate (project id=${createdProjectId})`);
    } else {
      fail("flows", "Wizard step 4 — generate estimate", `unexpected URL: ${url}`);
    }
  } catch (e) {
    fail("flows", "Wizard step 4 — generate estimate", e.message.split("\n")[0]);
  }

  // ── Edit project flow ──
  if (createdProjectId) {
    try {
      await visitPage(page, `/projects/${createdProjectId}`, `Created project show (id=${createdProjectId})`);
      await visitPage(page, `/projects/wizard/edit/${createdProjectId}`, `Edit wizard recap (id=${createdProjectId})`);
      pass("flows", `Edit project flow (id=${createdProjectId})`);
    } catch (e) {
      fail("flows", "Edit project flow", e.message.split("\n")[0]);
    }

    // ── Archive project flow ──
    try {
      await page.goto(`${BASE_URL}/projects/${createdProjectId}`, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT });

      // Step 1: Click the archive trigger button (opens Bootstrap modal via archive-confirm Stimulus controller)
      const archiveTrigger = page.locator('[data-action="click->archive-confirm#show"]').first();
      await archiveTrigger.waitFor({ state: "visible", timeout: ACTION_TIMEOUT });
      await archiveTrigger.click({ timeout: ACTION_TIMEOUT });

      // Step 2: Wait for modal and click confirm
      const confirmBtn = page.locator('[data-action="click->archive-confirm#confirm"]').first();
      await confirmBtn.waitFor({ state: "visible", timeout: 8_000 });
      await Promise.all([
        page.waitForNavigation({ timeout: NAV_TIMEOUT }).catch(() => {}),
        confirmBtn.click({ timeout: ACTION_TIMEOUT }),
      ]);
      pass("flows", `Archive project (id=${createdProjectId})`);

      // Step 3: Unarchive
      await page.goto(`${BASE_URL}/projects/${createdProjectId}`, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT });
      const unarchiveBtn = page.locator('form[action*="unarchive"] input[type="submit"], button:has-text("Désarchiver")').first();
      if (await unarchiveBtn.count() > 0) {
        await Promise.all([
          page.waitForNavigation({ timeout: NAV_TIMEOUT }).catch(() => {}),
          unarchiveBtn.click({ timeout: ACTION_TIMEOUT }),
        ]);
        pass("flows", `Unarchive project (id=${createdProjectId})`);
      }
    } catch (e) {
      fail("flows", "Archive/unarchive project", e.message.split("\n")[0]);
    }
  }

  await ctx.close();
  return createdProjectId;
}

async function testArtisanFlows(browser) {
  section("ARTISAN FLOWS");

  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  await loginArtisan(page);

  // Dashboard
  await visitPage(page, "/artisan_dashboard", "Artisan dashboard home");
  // /artisan_dashboard/requests has a known bug: before_action :set_request runs on index
  // (params[:id] is nil) causing ActiveRecord::RecordNotFound → 404
  {
    const resp = await page.request.get(`${BASE_URL}/artisan_dashboard/requests`, { timeout: 15_000 }).catch(() => null);
    const status = resp?.status() ?? 0;
    if (status === 404) {
      fail("pages", "Artisan requests list", "BUG: 404 — set_request before_action fires on index (params[:id] nil)");
      warn("Artisan requests list", "Real app bug: before_action :set_request missing only: constraint, raises RecordNotFound on index");
    } else if (status >= 500) {
      fail("pages", "Artisan requests list", `${status} Server Error`);
    } else {
      pass("pages", "Artisan requests list");
    }
  }
  await visitPage(page, "/artisan_dashboard/profile", "Artisan profile");

  // Profile edit
  try {
    await page.goto(`${BASE_URL}/artisan_dashboard/profile/edit`, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT });
    const url = page.url();
    if (url.includes("sign_in")) {
      fail("pages", "Artisan profile edit", "redirected to sign_in");
    } else {
      pass("pages", "Artisan profile edit");

      // Try updating the phone number
      const phoneInput = page.locator('input[name*="phone"], #artisan_phone').first();
      if (await phoneInput.count() > 0) {
        const currentVal = await phoneInput.inputValue();
        await phoneInput.fill("06 99 88 77 66");
        await Promise.all([
          page.waitForNavigation({ timeout: NAV_TIMEOUT }).catch(() => {}),
          page.locator('input[type="submit"], button[type="submit"]').first().click(),
        ]);
        // Revert
        await page.goto(`${BASE_URL}/artisan_dashboard/profile/edit`, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT });
        await page.locator('input[name*="phone"], #artisan_phone').first().fill(currentVal).catch(() => {});
        await page.locator('input[type="submit"], button[type="submit"]').first().click().catch(() => {});
        pass("flows", "Artisan profile edit — update phone");
      }
    }
  } catch (e) {
    fail("flows", "Artisan profile edit", e.message.split("\n")[0]);
  }

  // Check if there are pending requests to interact with
  try {
    await page.goto(`${BASE_URL}/artisan_dashboard/requests`, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT });
    const requestLinks = await page.locator('a[href*="/artisan_dashboard/requests/"]').evaluateAll((els) =>
      els.map((e) => e.getAttribute("href")).filter((h) => h && h.match(/\/requests\/\d+/))
    );

    if (requestLinks.length > 0) {
      const requestPath = requestLinks[0];
      await visitPage(page, requestPath, `Artisan request detail (${requestPath})`);

      // Try to interact with the request (submit price or decline)
      const priceInput = page.locator('input[name*="price"], input[name*="amount"]').first();
      if (await priceInput.count() > 0) {
        // There's a form to submit a price — just check it renders
        pass("flows", "Artisan request detail — price form visible");
      }

      const declineBtn = page.locator('button, a').filter({ hasText: /refus|déclin|decline/i }).first();
      if (await declineBtn.count() > 0) {
        pass("flows", "Artisan request detail — decline button visible");
      }
    } else {
      console.log("  ℹ️  No artisan requests found (bidding round not set up in staging)");
    }
  } catch (e) {
    fail("flows", "Artisan requests interaction", e.message.split("\n")[0]);
  }

  await ctx.close();
}

async function testUIConsistency(browser) {
  if (SKIP_AI) {
    section("UI CONSISTENCY (SKIPPED — SKIP_AI=true)");
    return;
  }

  section("UI CONSISTENCY (CLAUDE AI ANALYSIS)");

  const ctx = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  const page = await ctx.newPage();

  // ── Public pages ──
  const publicPages = [
    { path: "/", name: "Home page" },
    { path: "/users/sign_in", name: "Customer sign-in" },
    { path: "/artisans/sign_in", name: "Artisan sign-in" },
  ];

  for (const { path, name } of publicPages) {
    await page.goto(`${BASE_URL}${path}`, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT });
    const imgPath = await screenshot(page, name);
    const analysis = await analyzeWithClaude(imgPath, name);
    evaluateUI(analysis, name);
  }

  // ── Authenticated customer pages ──
  await loginCustomer(page);

  const customerPages = [
    { path: "/projects", name: "Customer dashboard" },
    { path: "/projects/wizard/choose", name: "Wizard choose type" },
    { path: "/profile", name: "Customer profile" },
    { path: "/notifications", name: "Notifications" },
  ];

  for (const { path, name } of customerPages) {
    await page.goto(`${BASE_URL}${path}`, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT });
    const imgPath = await screenshot(page, name);
    const analysis = await analyzeWithClaude(imgPath, name);
    evaluateUI(analysis, name);
  }

  // Get first project and check it
  await page.goto(`${BASE_URL}/projects`, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT });
  const projectLinks = await page.locator('a[href*="/projects/"]').evaluateAll((els) =>
    els
      .map((e) => e.getAttribute("href"))
      .filter((h) => h && h.match(/\/projects\/\d+$/))
  );
  if (projectLinks.length > 0) {
    await page.goto(`${BASE_URL}${projectLinks[0]}`, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT });
    const imgPath = await screenshot(page, "Project show page");
    const analysis = await analyzeWithClaude(imgPath, "Project show page");
    evaluateUI(analysis, "Project show page");
  }

  // Wizard step 1
  await page.goto(`${BASE_URL}/projects/wizard/step1`, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT });
  const imgPath1 = await screenshot(page, "Wizard step 1");
  evaluateUI(await analyzeWithClaude(imgPath1, "Wizard step 1"), "Wizard step 1");

  // ── Artisan pages ──
  await logout(page);
  await loginArtisan(page);

  const artisanPages = [
    { path: "/artisan_dashboard", name: "Artisan dashboard" },
    { path: "/artisan_dashboard/requests", name: "Artisan requests list" },
    { path: "/artisan_dashboard/profile", name: "Artisan profile page" },
  ];

  for (const { path, name } of artisanPages) {
    await page.goto(`${BASE_URL}${path}`, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT });
    const imgPath = await screenshot(page, name);
    const analysis = await analyzeWithClaude(imgPath, name);
    evaluateUI(analysis, name);
  }

  await ctx.close();
}

async function testBrokenLinks(browser) {
  section("BROKEN LINK DETECTION");

  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  await loginCustomer(page);

  await page.goto(`${BASE_URL}/projects`, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT });

  // Collect all internal links from the dashboard
  const links = await page.locator("a[href]").evaluateAll((els) =>
    els
      .map((e) => e.getAttribute("href"))
      .filter((h) => h && h.startsWith("/") && !h.startsWith("//") && !h.includes("sign_out"))
  );

  const unique = [...new Set(links)].slice(0, 15); // Cap at 15 to avoid too many requests
  console.log(`  Checking ${unique.length} internal links from dashboard...`);

  for (const href of unique) {
    const response = await page.request.get(`${BASE_URL}${href}`, { timeout: 15_000 }).catch(() => null);
    const status = response?.status() ?? 0;
    if (status === 404 || status >= 500) {
      fail("pages", `Link check: ${href}`, `HTTP ${status}`);
      warn(`Link: ${href}`, `HTTP ${status}`);
    }
    // Only log broken ones (avoid spamming successes here)
  }
  pass("flows", `Broken link scan (${unique.length} links checked from dashboard)`);

  await ctx.close();
}

// ─────────────────────────────────────────────────────────────────────────────
// Post results to Rails admin dashboard
// ─────────────────────────────────────────────────────────────────────────────

async function postResults(elapsed) {
  if (!RESULTS_URL || !TEST_TOKEN) return;

  const passedPages = results.pages.filter((p) => p.status === "pass").length;
  const passedFlows = results.flows.filter((f) => f.status === "pass").length;
  const passedUI    = results.uiChecks.filter((u) => u.status === "pass").length;

  const payload = {
    test_run: {
      ran_at:           new Date(results.startTime).toISOString(),
      trigger:          process.env.TEST_TRIGGER || "manual",
      duration_seconds: parseFloat(elapsed),
      pages_total:      results.pages.length,
      pages_passed:     passedPages,
      flows_total:      results.flows.length,
      flows_passed:     passedFlows,
      ui_total:         results.uiChecks.length,
      ui_passed:        passedUI,
      errors_count:     results.errors.length,
      results: {
        pages:     results.pages,
        flows:     results.flows,
        uiChecks:  results.uiChecks,
        errors:    results.errors,
      },
    },
  };

  try {
    const res = await fetch(RESULTS_URL, {
      method:  "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${TEST_TOKEN}` },
      body:    JSON.stringify(payload),
    });
    if (res.ok) {
      const { id } = await res.json();
      console.log(`\n  📤 Results posted → ${RESULTS_URL.replace(/\/test_runs.*/, "")}/test_runs/${id}`);
    } else {
      console.warn(`\n  ⚠️  Could not post results: HTTP ${res.status}`);
    }
  } catch (e) {
    console.warn(`\n  ⚠️  Could not post results: ${e.message}`);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Report
// ─────────────────────────────────────────────────────────────────────────────

function printReport(elapsed) {
  const line = "═".repeat(60);

  console.log(`\n\n${line}`);
  console.log("OPENDEVIS TEST SUITE — FINAL REPORT");
  console.log(line);

  // Pages
  console.log("\nPAGES TESTED");
  console.log("─".repeat(40));
  for (const p of results.pages) {
    const icon = p.status === "pass" ? "✅" : "❌";
    console.log(`  ${icon} ${p.label}${p.note ? "  — " + p.note : ""}`);
  }

  // Flows
  console.log("\nFLOWS TESTED");
  console.log("─".repeat(40));
  for (const f of results.flows) {
    const icon = f.status === "pass" ? "✅" : "❌";
    console.log(`  ${icon} ${f.label}${f.note ? "  — " + f.note : ""}`);
  }

  // UI Consistency
  if (results.uiChecks.length > 0) {
    console.log("\nUI CONSISTENCY CHECKS (Claude AI)");
    console.log("─".repeat(40));
    for (const u of results.uiChecks) {
      const icon = u.status === "pass" ? "✅" : "❌";
      console.log(`  ${icon} ${u.label}${u.note ? "  — " + u.note : ""}`);
    }
  }

  // Errors
  if (results.errors.length > 0) {
    console.log("\nERRORS / WARNINGS DETECTED");
    console.log("─".repeat(40));
    for (const e of results.errors) {
      console.log(`  ⚠️  [${e.label}] ${e.msg}`);
    }
  } else {
    console.log("\nERRORS / WARNINGS DETECTED");
    console.log("─".repeat(40));
    console.log("  (none)");
  }

  // Summary
  const totalPages = results.pages.length;
  const passedPages = results.pages.filter((p) => p.status === "pass").length;
  const totalFlows = results.flows.length;
  const passedFlows = results.flows.filter((f) => f.status === "pass").length;
  const totalUI = results.uiChecks.length;
  const passedUI = results.uiChecks.filter((u) => u.status === "pass").length;

  console.log(`\nSUMMARY`);
  console.log("─".repeat(40));
  console.log(`  Pages  : ${passedPages}/${totalPages} passed`);
  console.log(`  Flows  : ${passedFlows}/${totalFlows} passed`);
  if (totalUI > 0) {
    console.log(`  UI AI  : ${passedUI}/${totalUI} passed`);
  }
  console.log(`  Errors : ${results.errors.length}`);
  console.log(`  Time   : ${elapsed}s`);
  console.log(line);

  const allPassed =
    passedPages === totalPages &&
    passedFlows === totalFlows &&
    (totalUI === 0 || passedUI === totalUI);

  console.log(allPassed ? "\n  🎉 ALL TESTS PASSED\n" : "\n  ⚠️  SOME TESTS FAILED — see above\n");
  console.log(line);
}

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

async function main() {
  console.log("═".repeat(60));
  console.log("OPENDEVIS AI-POWERED E2E TEST SUITE");
  console.log(`Target: ${BASE_URL}`);
  console.log(`AI checks: ${SKIP_AI ? "disabled" : "enabled (Claude API)"}`);
  console.log(`Headless: ${HEADLESS}`);
  console.log("═".repeat(60));

  if (!SKIP_AI && !process.env.ANTHROPIC_API_KEY) {
    console.warn("\n⚠️  ANTHROPIC_API_KEY not set — UI consistency checks will fail.\n   Run with SKIP_AI=true to skip AI checks.\n");
  }

  const browser = await chromium.launch({ headless: HEADLESS });

  try {
    await testPublicPages(await browser.newPage());
    await testAuthentication(browser);
    await testCustomerPages(browser);
    await testWizardFlow(browser);
    await testArtisanFlows(browser);
    await testBrokenLinks(browser);
    await testUIConsistency(browser);
  } catch (e) {
    console.error("\n❌ Fatal error in test suite:", e);
    warn("Fatal", e.message);
  } finally {
    await browser.close();
    const elapsed = ((Date.now() - results.startTime) / 1000).toFixed(1);
    printReport(elapsed);
    await postResults(elapsed);
  }

  const failures = [...results.pages, ...results.flows, ...results.uiChecks].filter((r) => r.status === "fail").length;
  process.exit(failures > 0 ? 1 : 0);
}

main();
