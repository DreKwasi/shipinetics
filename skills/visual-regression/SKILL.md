---
name: visual-regression
description: Set up and run screenshot-based visual regression tests, combining pixel comparison with agent visual review, and handle baselines with git LFS or PR artifacts. Use when changing UI, when a screenshot test fails, when adding visual tests to a project, or when the user asks about visual regressions.
---

# Visual regression

> Paths below are Shipinetics's defaults. A project can map them elsewhere in `.shipinetics/config`: run `shipinetics-config` to see this project's actual paths and commands, and use those.
>
> Text for people (docs, worksheets, reports, PR descriptions, commit messages, review comments, replies, and each label on a board, diagram or table): write it in ASD-STE100, by the plain-language guide (`${CLAUDE_PLUGIN_ROOT}/skills/explain/plain-language.md`). Where the text describes structure or flow (a call path, a data flow, states or steps), show it on a Whiteboard. In a committed file, also put a Mermaid diagram and a link to the Whiteboard, because GitHub and other people cannot open your Whiteboard. Without Whiteboard, use Mermaid only. shipinetics:explain has the rules.

Two layers, because each misses what the other catches:

- **Pixel comparison** (Playwright `toHaveScreenshot`) catches every unintended change, including ones a human would miss.
- **Agent visual review** looks at the actual images and judges whether a change is intended and whether the result looks right. Pixel diffs can't tell a bug from a redesign.

## Setting it up (once per project)

1. **Pick the screens.** Start with 3 to 8: the main screen, the most-used flows, anything with complex layout. Add more as UI bugs ship.
2. **Make them deterministic**, or the tests will flake:
   - Fixed viewport and device scale factor in the Playwright project.
   - Seeded test data. Mock time (`page.clock.setFixedTime`) and anything random.
   - `animations: 'disabled'` and `caret: 'hide'` in `toHaveScreenshot` options.
   - Mask dynamic regions (avatars, timestamps, ads) with the `mask` option.
   - Wait for fonts and images: `await page.evaluate(() => document.fonts.ready)`.
3. **Generate baselines where CI runs.** Font rendering differs between macOS and Linux, so baselines made on a Mac fail in Linux CI. Generate them in the Playwright Docker image (`mcr.microsoft.com/playwright:<version>`) or in CI itself, and use the same image locally.
4. **Store baselines.** Ask the user which they prefer:
   - **git LFS** (recommended once there are more than a handful): `git lfs install`, then `git lfs track "e2e/**/*-snapshots/**"`, and commit `.gitattributes`. Add `lfs: true` to the CI checkout step.
   - **PR artifacts:** CI uploads screenshots and diffs as artifacts or posts them to the PR, with baselines kept in plain git.
5. **Protect baselines.** `*-snapshots/*` is in `.shipinetics/protected-paths` by default, so agents can't quietly regenerate them.
6. Add the visual run to `bin/verify --full`.

## Writing a visual test

```ts
test('invoice page @visual', async ({ page }) => {
  await page.clock.setFixedTime(new Date('2026-01-15T10:00:00Z'));
  await page.goto('/invoices/seed-invoice-1');
  await page.evaluate(() => document.fonts.ready);
  await expect(page).toHaveScreenshot('invoice.png', {
    fullPage: true,
    mask: [page.getByTestId('generated-at')],
  });
});
```

## When a screenshot test fails

1. Open the three images Playwright writes to `test-results/` (expected, actual, diff). Read each PNG with the Read tool and look at them.
2. Decide: **intended** (the task changed this UI on purpose) or **regression** (it shouldn't have changed).
3. **Regression:** fix the code. Never update the baseline to make a regression pass.
4. **Intended:** look at the actual image as a designer would. Is anything clipped, overlapping, misaligned, unreadable, or off-brand (against DESIGN.md and the existing components)? Check dark mode and a narrow viewport if the change could affect them.
5. Baselines are protected, so updating them is a human decision. Write in the worksheet under "Test change requests": which screenshot, why it changed, and your visual review of the new version. Put the new screenshot at `.shipinetics/pending/<baseline path>`. A human reviews it with `shipinetics-config apply`, or approves it in the PR.

## Agent visual review without a failing test

After any UI change, even with no screenshot test, take screenshots of the changed screens (Playwright or the browser tool) and look at them before calling the work done. Check layout at desktop and mobile widths, empty and error states, and long text. Note what you checked in the worksheet.
