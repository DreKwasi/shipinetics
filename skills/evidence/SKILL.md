---
name: evidence
description: Capture proof that a change works (screenshots per acceptance criterion, a screen recording for UI changes, terminal transcripts for CLIs and APIs) from the real running app, and attach it to every PR. Use after implementing and verifying a task, before opening or updating a PR, when reviewing a PR, and when a hook blocks `gh pr create` for missing evidence.
argument-hint: "[worksheet]"
---

# Evidence: show it working

> Paths below are Shipyard's defaults. A project can map them elsewhere in `.shipyard/config`: run `shipyard-config` to see this project's actual paths and commands, and use those.

A PR without proof that it works isn't worth a reviewer's time. Passing tests are necessary, not sufficient: tests can be wrong, and they never show what the user sees. So every PR carries evidence recorded from the real, running app at the PR's code: screenshots for each acceptance criterion, a screen recording for anything visual, and terminal transcripts for CLIs, APIs and jobs.

Worksheet: `$ARGUMENTS` (default: the current one).

## What's enforced

- **`gh pr create` and `gh pr ready` are blocked** by a hook until `evidence check --branch` passes and the PR body contains the `## Evidence` section.
- **CI fails any PR** (agent or human) whose description has no `## Evidence` section with a screenshot, recording or transcript, unless it carries the `no-evidence` label (for docs-only or config-only changes).
- **Reviewers look at it:** the wrap-up reviewer checks evidence against the acceptance criteria, the UI reviewer starts from the screenshots, and the Whiteboard shows them to the human.

## What counts

| Change | Required evidence |
|---|---|
| UI (any path in `.shipyard/ui-paths`) | A screenshot per acceptance criterion showing the observable result, a mobile-width screenshot of the main changed screen, and one screen recording of the whole flow |
| CLI | A terminal transcript per criterion: the real command and its real output, via `evidence run` |
| API | A transcript of real requests against the running service (curl or httpie through `evidence run`), showing status and body |
| Background job, data change | A transcript of triggering it and of the resulting state (a query, a log line, a file) |
| Bug fix | The same, showing the bug's reproduction steps now producing the right result. If you can, also the "before" from the base commit |
| Docs, config, tests only | None. Humans add the `no-evidence` label; the hook passes docs-only branches by itself |

Evidence is real or it's nothing:

- Recorded from the app started the normal way (`bin/with-secrets <start command>`), at the code you're submitting. Not mocks, not Storybook, not a test's fixture server, unless that is the product.
- Shows the result the criterion talks about, not just that a page loaded.
- Contains no secrets, tokens or personal data. Use seeded test accounts. Check every screenshot before you commit it.
- Recordings stay short: under a minute, one flow. Several short recordings beat one long one.

## How to capture it

1. **Start the file:** `evidence init`. It creates `docs/evidence/<worksheet>/EVIDENCE.md` with a row for every acceptance criterion in the worksheet.
2. **Run the app** and check it works before recording.
3. **Record:**
   - **Web:** copy `${CLAUDE_SKILL_DIR}/record-template.mjs` to `docs/evidence/<worksheet>/record.mjs`, write one block per criterion (act, wait for the visible result, screenshot `AC<n>-<name>.png`), and run it with the base URL: `node docs/evidence/<worksheet>/record.mjs http://localhost:3000`. It saves the screenshots and `walkthrough.webm`, and fails if the page logged errors.
   - **CLI, API, jobs:** `evidence run -- <command>` runs the command and appends it, its output and its exit code to `terminal.log`. Run one command per criterion.
   - **iOS simulator:** `xcrun simctl io booted screenshot <file>.png` and `xcrun simctl io booted recordVideo <file>.mov` (stop it with Ctrl-C), or the simulator tool's screenshot action.
4. **Look at every screenshot** with the Read tool before you list it. Confirm it shows what the row claims. If it doesn't, the feature or the recording is wrong: fix it, don't describe around it.
5. **Fill in EVIDENCE.md:** for each criterion, the file name and one line on what it shows. Update the commit line to the commit you recorded at.
6. **Check:** `evidence check`. It confirms every criterion has a file, every named file exists, UI changes have a recording, and the evidence is fresh: no code changed since the commit on the Commit line. Changes to docs, Markdown, tests, worksheets and the evidence itself don't count. So record evidence once the code is final, after review fixes, and a later docs or test commit doesn't make you record it again. If a fix touches code, re-record the criteria it affects and update the Commit line.
7. Commit the evidence with the work (trailer `Worksheet: <name>`). With git LFS set up (`/shipyard:setup` asks), recordings don't bloat the repo. Without it, keep recordings small, or keep them out of git and attach them to the PR by hand.

## Opening the PR

```bash
evidence pr-body > "$TMPDIR/pr-body.md"
```

Put your summary above the generated `## Evidence` section in that file (what changed, why, how it was verified, anything not verified). Add a `## Merge risk` section after it with the independent grade (shipyard:review, "Merge risk"). Then:

```bash
gh pr create --title "<title>" --body-file "$TMPDIR/pr-body.md"
```

Push the branch first so the image links resolve. If evidence changes after review, regenerate the section and update the PR body (`gh pr edit --body-file`).

## Reviewing a PR

Open the evidence before reading the diff. For each criterion: does the screenshot or transcript actually show the result? Is it from this branch's code? `evidence check` fails if code changed after the commit on the Commit line. Anything missing, stale or unconvincing is a finding, severity major.
