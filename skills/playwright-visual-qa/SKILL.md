---
name: playwright-visual-qa
description: "Run Playwright tests, capture screenshots, and perform AI-powered visual analysis against branding standards"
---

# Skill: Playwright Visual QA

This skill teaches Claude how to run Playwright tests, capture screenshots,
and perform AI-powered visual analysis against the project's branding standards.

## Running Playwright Tests

```bash
# From the worktree directory
source .env.local
pnpm test:e2e

# Run a specific test file
pnpm test:e2e e2e/invitations.spec.ts

# Run with UI (headed mode, useful for debugging)
pnpm test:e2e --headed

# Run with Playwright's built-in reporter
pnpm test:e2e --reporter=html
```

## Capturing Screenshots via CLI

```bash
# Full page screenshot
npx playwright screenshot \
  --browser chromium \
  http://localhost:3000/dashboard \
  .claude/task/screenshots/dashboard-desktop.png

# Mobile viewport
npx playwright screenshot \
  --browser chromium \
  --viewport-size 390,844 \
  http://localhost:3000/dashboard \
  .claude/task/screenshots/dashboard-mobile.png

# Specific element screenshot (via script)
npx playwright eval "
  const { chromium } = require('playwright');
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto('http://localhost:3000/dashboard');
  await page.locator('[data-testid=\"invitations-panel\"]').screenshot({
    path: '.claude/task/screenshots/invitations-panel.png'
  });
  await browser.close();
"
```

## Visual QA Analysis Pattern

After capturing screenshots, analyze each one against `config/branding.md`.

The analysis should check each item in the branding doc's Visual QA Checklist:

```
For each screenshot:
  1. Load the screenshot
  2. Load config/branding.md
  3. For each checklist item in branding.md:
     - Examine the screenshot for compliance
     - Report: ✓ PASS, ✗ FAIL (with specifics), or ⚠ WARNING
  4. Write findings to .claude/task/visual-qa.md
```

## What to Look For

### Colors
- Are only palette colors from `branding.md` used?
- No random grays or blues that aren't in the brand?
- Correct usage of semantic colors (error = red from palette, not any red)?

### Typography
- Is the correct font family rendering? (Check DevTools font in screenshot context)
- Are heading weights correct? (H1=700, H2=600, etc. per branding doc)
- Is body text at the correct base size?
- Are there any unstyled text elements?

### Spacing
- Do elements have breathing room? (not cramped)
- Is padding/margin consistent with the spacing scale?
- Are similar elements spaced similarly?

### Components
- Do buttons match the defined button styles?
- Do form inputs look styled (not browser defaults)?
- Do cards/panels have correct borders, radius, and padding?

### Layout
- Is the content properly contained within the max-width?
- Is the sidebar/nav present and correctly sized?
- Are elements aligned to an invisible grid? (nothing floating off-center)

### States
- If the page has empty state — is it properly designed?
- If there's a loading state — are skeletons/spinners present?
- Are interactive elements visually distinct?

## Writing E2E Tests

New E2E tests go in `e2e/` directory. Follow the existing patterns:

```typescript
// e2e/invitations.spec.ts
import { test, expect } from '@playwright/test'

test.describe('Workspace Invitations', () => {
  test.beforeEach(async ({ page }) => {
    // Use seed data credentials
    await page.goto('/login')
    await page.fill('[name="email"]', 'alice@example.com')
    await page.fill('[name="password"]', 'test-password')
    await page.click('[type="submit"]')
    await page.waitForURL('/dashboard')
  })

  test('shows invite member button for org owners', async ({ page }) => {
    await page.goto('/settings/members')
    await expect(page.getByTestId('invite-member-btn')).toBeVisible()
  })

  test('opens invite modal on button click', async ({ page }) => {
    await page.goto('/settings/members')
    await page.getByTestId('invite-member-btn').click()
    await expect(page.getByRole('dialog')).toBeVisible()
    await expect(page.getByText('Invite Member')).toBeVisible()
  })

  test('sends invitation and shows success state', async ({ page }) => {
    await page.goto('/settings/members')
    await page.getByTestId('invite-member-btn').click()
    await page.fill('[name="email"]', 'newuser@example.com')
    await page.click('[type="submit"]')
    await expect(page.getByText('Invitation sent')).toBeVisible()
  })
})
```

## Playwright Config Reference

The `playwright.config.ts` should be configured to:
- Use `baseURL` from `PLAYWRIGHT_BASE_URL` env var (falls back to `http://localhost:3000`)
- Run against the feature's dev server
- Store screenshots in `.claude/task/screenshots/` on failure

```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  use: {
    baseURL: process.env.PLAYWRIGHT_BASE_URL || 'http://localhost:3000',
    screenshot: 'only-on-failure',
  },
  outputDir: '.claude/task/screenshots',
})
```

## Troubleshooting

### "Target page, context or browser has been closed"
The dev server isn't running. Start it first:
```bash
pnpm dev &
npx wait-on http://localhost:3000
```

### Screenshots are blank/all white
The page probably requires authentication. Check that test's `beforeEach` sets up auth.

### Visual QA keeps flagging the same color
Update `config/branding.md` if the flagged color is intentional — the branding doc
is the source of truth. If it's a real issue, file it in `failures.md`.

### Tests pass locally but fail in CI
Check that `DATABASE_URL` in CI points to the correct schema.
The CI workflow should call `./scripts/db-setup.sh create [branch]` before running tests.
