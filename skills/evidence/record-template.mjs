// Evidence recorder for one task: one screen recording of the whole flow, with the time where each
// acceptance criterion's result shows, against the real running app.
// Copy to docs/evidence/<worksheet>/record.mjs and edit the steps.
//
// Usage: node docs/evidence/<worksheet>/record.mjs <base-url>
//   e.g. node docs/evidence/2026-10-26-discount-codes/record.mjs http://localhost:3000
// Start the app first (bin/with-secrets <start command>). Needs Playwright installed in the project.
// The base URL comes in as an argument, not from the environment, so this file never reads env vars.
//
// The recording is the proof. It is never committed (evidence init git-ignores it): `evidence upload`
// puts it in the project's store, or a person attaches it to the PR. At the end, the script prints
// one "AC<n> @ m:ss" line per criterion for the Evidence column of EVIDENCE.md.

import { chromium } from 'playwright';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const baseUrl = process.argv[2];
if (!baseUrl) {
  console.error('usage: node record.mjs <base-url>');
  process.exit(2);
}
const out = path.dirname(fileURLToPath(import.meta.url));
const recording = 'walkthrough.webm';

// Paced for a person to follow, not rushed: slowMo waits between actions, type() types at
// reading speed, pause() gives a beat before an important action, and mark() holds each result.
const browser = await chromium.launch({ slowMo: 300 });
const context = await browser.newContext({
  viewport: { width: 1440, height: 900 },
  recordVideo: { dir: out, size: { width: 1440, height: 900 } },
});
const page = await context.newPage();
const started = Date.now(); // the video starts with the page
const errors = [];
page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`));
page.on('console', (m) => { if (m.type() === 'error') errors.push(`console: ${m.text()}`); });

// mark: call it when the criterion's result is visible. It notes the time in the recording and
// holds the screen still, so a person can see the result and `evidence frames` can extract it.
const marks = [];
const mark = async (label) => {
  const s = (Date.now() - started) / 1000;
  marks.push(`${label} @ ${Math.floor(s / 60)}:${(s % 60).toFixed(1).padStart(4, '0')}`);
  await page.waitForTimeout(2500);
};
const pause = (ms = 1000) => page.waitForTimeout(ms);
const type = (locator, text) => locator.pressSequentially(text, { delay: 80 }); // not fill(): it is instant

// ---- Steps: one block per acceptance criterion. Show the observable result, then mark it. ----

// AC1: <criterion text>
await page.goto(`${baseUrl}/`);
await pause(1500); // let the viewer see the starting screen
// await type(page.getByLabel('Discount code'), 'SAVE10');
// await pause();
// await page.getByRole('button', { name: 'Apply code' }).click();
// await page.getByText('Discount: -$1.00').waitFor();
await mark('AC1');

// AC2: <criterion text>
// ...
// await mark('AC2');

// Mobile width of the main changed screen.
await page.setViewportSize({ width: 390, height: 844 });
await mark('mobile');

// ---- End of steps ----

const video = page.video();
await context.close();
if (video) {
  await video.saveAs(path.join(out, recording));
  await video.delete();
}
await browser.close();

if (errors.length) {
  console.error(`Errors during the walkthrough:\n${errors.join('\n')}`);
  process.exit(1);
}
console.log(`Recording saved: ${path.join(out, recording)}`);
console.log('Evidence column, one per criterion:');
for (const m of marks) console.log(`  ${recording} ${m.replace(/^\S+ /, '')}   (${m.split(' ')[0]})`);
