import { test, expect } from '@playwright/test';

// Smoke test: the app starts, the main screen renders, and nothing errors in the console.
// Tagged @smoke so bin/verify runs it on every agent stop. Keep it fast and boring.

test('app loads its main screen without errors @smoke', async ({ page }) => {
  const errors: string[] = [];
  page.on('pageerror', (err) => errors.push(`pageerror: ${err.message}`));
  page.on('console', (msg) => {
    if (msg.type() === 'error') errors.push(`console: ${msg.text()}`);
  });

  await page.goto('/');

  // Replace with the element that proves the real app rendered, not just a shell.
  await expect(page.getByRole('{{ROLE}}', { name: '{{ACCESSIBLE_NAME}}' })).toBeVisible();

  expect(errors, errors.join('\n')).toEqual([]);
});
