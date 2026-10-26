// Evidence recorder for one task: screenshots per acceptance criterion plus one screen recording,
// against the real running app. Copy to docs/evidence/<worksheet>/record.mjs and edit the steps.
//
// Usage: node docs/evidence/<worksheet>/record.mjs <base-url>
//   e.g. node docs/evidence/2026-10-26-discount-codes/record.mjs http://localhost:3000
// Start the app first (bin/with-secrets <start command>). Needs Playwright installed in the project.
// The base URL comes in as an argument, not from the environment, so this file never reads env vars.

import { chromium } from 'playwright';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const baseUrl = process.argv[2];
if (!baseUrl) {
  console.error('usage: node record.mjs <base-url>');
  process.exit(2);
}
const out = path.dirname(fileURLToPath(import.meta.url));
const shot = (page, name) => page.screenshot({ path: path.join(out, `${name}.png`), fullPage: true });

const browser = await chromium.launch();
const context = await browser.newContext({
  viewport: { width: 1440, height: 900 },
  recordVideo: { dir: out, size: { width: 1440, height: 900 } },
});
const page = await context.newPage();
const errors = [];
page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`));
page.on('console', (m) => { if (m.type() === 'error') errors.push(`console: ${m.text()}`); });

// ---- Steps: one block per acceptance criterion. Show the observable result, then screenshot it. ----

// AC1: <criterion text>
await page.goto(`${baseUrl}/`);
// await page.getByRole('button', { name: 'Apply code' }).click();
// await page.getByText('Discount: -$1.00').waitFor();
await shot(page, 'AC1-<short-name>');

// AC2: <criterion text>
// ...
// await shot(page, 'AC2-<short-name>');

// Mobile check of the main changed screen.
await page.setViewportSize({ width: 390, height: 844 });
await shot(page, 'mobile-<short-name>');

// ---- End of steps ----

const video = page.video();
await context.close();
if (video) {
  await video.saveAs(path.join(out, 'walkthrough.webm'));
  await video.delete();
}
await browser.close();

if (errors.length) {
  console.error(`Errors during the walkthrough:\n${errors.join('\n')}`);
  process.exit(1);
}
console.log(`Evidence saved in ${out}`);
