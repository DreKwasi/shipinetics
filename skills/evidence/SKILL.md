---
name: evidence
description: Capture proof that a change works (one paced recording of the flow for UI changes, with the time of each acceptance criterion; screenshots only when it can't be recorded, never both; terminal transcripts for CLIs and APIs) from the real running app, and attach it to a PR. Optional: the user decides for each task. Recordings are uploaded and linked, never committed. Use when the user says yes to evidence for a task (the workflow asks when the change works), when the user asks to record or check evidence, and when reviewing a PR that has evidence.
argument-hint: "[worksheet]"
---

# Evidence: show it working

> Paths below are Shipinetics's defaults. A project can map them elsewhere in `.shipinetics/config`: run `shipinetics-config` to see this project's actual paths and commands, and use those.
>
> Text for people (docs, worksheets, reports, PR descriptions, commit messages, review comments, replies, and each label on a board, diagram or table): write it in ASD-STE100, by the plain-language guide (`${CLAUDE_PLUGIN_ROOT}/skills/explain/plain-language.md`). Where the text describes structure or flow (a call path, a data flow, states or steps), show it on a Whiteboard. In a committed file, also put a Mermaid diagram and a link to the Whiteboard, because GitHub and other people cannot open your Whiteboard. Without Whiteboard, use Mermaid only. shipinetics:explain has the rules.

Evidence shows a change working in the real, running app at the PR's code: one recording of the flow for anything visual, and terminal transcripts for CLIs, APIs and jobs. Tests can be wrong, and they never show what the user sees, so evidence helps a reviewer.

**The user decides whether a task gets evidence.** When the change works (shipinetics:workflow, step 6), ask the user one question: "Record evidence for this change?" Add your advice in one line: yes for a change that users see, no for a refactor, a config change or an internal change. Then:

- **Yes:** record it by this skill, and write "Evidence: the user said yes" in the worksheet's Verified section.
- **No:** don't record it. Write "Evidence: the user said no" in Verified, and say in the PR how you verified the change: the commands you ran, what you checked in the app, and what you didn't check.
- Ask once for each task. If the user already answered, for example in the task's request, don't ask again.
- In an autonomous session, don't ask and don't record evidence.

**Nothing requires evidence.** No hook or CI job checks for it, and a PR opens without it. Never record it unless the user said yes.

**Rules for media:**
- **A recording first.** One recording of the whole flow. Each criterion's row names the time where its result shows: `walkthrough.webm @ 0:07`. People jump to that time. Agents can't watch a video, so `evidence frames` extracts the frame at each time, and agents look at those frames.
- **Screenshots only when the change can't be recorded,** with the reason on a `> No recording: <reason>` line in EVIDENCE.md. Never both.
- **Paced, not rushed.** A person must be able to follow it. Pause on the starting screen, type at reading speed, wait a beat before each important action, and hold each result for about two seconds. The record template does this (`slowMo`, `type()`, `pause()`, `mark()`). Without the template, pace it by hand the same way.
- **Media never goes into git.** Everyone who pulls the repo would pull every recording. `evidence init` writes a `.gitignore` in the evidence folder that ignores media. Only EVIDENCE.md and `terminal.log` are committed.
- **The store is opt-in.** If `.shipinetics/config` sets `evidence_upload_cmd`, `evidence upload` puts the recording in the team's store (SharePoint or OneDrive, S3, Google Drive, through rclone or the team's own command) and replaces the file name in EVIDENCE.md with its link. The time stays. Without a store, the recording stays on disk, and the human drags it into the PR description, so GitHub hosts it.

Worksheet: `$ARGUMENTS` (default: the current one).

## Who uses it

- **Reviewers look at it:** the wrap-up reviewer checks evidence against the acceptance criteria, the UI reviewer starts from the frames of the recording, and the Whiteboard shows the recording and its key frames to the human.

## What counts

| Change | Evidence to record |
|---|---|
| UI (any path in `.shipinetics/ui-paths`) | One paced recording of the whole flow, with the time where each acceptance criterion's result shows, and a mobile-width part for the main changed screen. If it can't be recorded: a screenshot per criterion and a mobile-width one, with the reason. Never both |
| CLI | A terminal transcript per criterion: the real command and its real output, via `evidence run` |
| API | A transcript of real requests against the running service (curl or httpie through `evidence run`), showing status and body |
| Background job, data change | A transcript of triggering it and of the resulting state (a query, a log line, a file) |
| Bug fix | The same, showing the bug's reproduction steps now producing the right result. If you can, also the "before" from the base commit |

Evidence is real or it's nothing. The verification map's evidence standards apply (shipinetics:verification-map): the real user path, the action *and* the resulting state, changes read back from a second view, every entry point the feature lists, each artifact labeled with its feature ID and entry point. In short:

- Recorded from the app started the normal way (`bin/with-secrets <start command>`), at the code you're submitting. Not mocks, not Storybook, not a test's fixture server, unless that is the product.
- Shows the result the criterion talks about, not just that a page loaded, and the state it left behind.
- For a bug, the symptom reproduced twice through the real UI before the fix, and gone after it. Never force or inject the symptom.
- Contains no secrets, tokens or personal data. Use seeded test accounts. Check the frames of every recording before you upload it.
- Recordings stay short: under a minute, one flow. Several short recordings beat one long one.

## How to capture it

1. **Commit the code first,** so the evidence can name the commit it shows. Then **start the file:** `evidence init`. It creates `docs/evidence/<worksheet>/EVIDENCE.md` with a row for every acceptance criterion in the worksheet.
2. **Run the app** and check it works before recording. If `shipinetics-config get launch` says `user`, the user runs the servers: follow the user-run rules in shipinetics:verification-map instead of launching anything. If the sandbox blocks localhost, record with the harness's preview browser and say so in EVIDENCE.md.
3. **Record:**
   - **Web:** copy `${CLAUDE_SKILL_DIR}/record-template.mjs` to `docs/evidence/<worksheet>/record.mjs`, write one block per criterion (act at a person's pace, wait for the visible result, `mark('AC<n>')`), and run it with the base URL: `node docs/evidence/<worksheet>/record.mjs http://localhost:3000`. It saves `walkthrough.webm` in the evidence folder (git ignores it), prints the time of each mark for the Evidence column, and fails if the page logged errors.
   - **CLI, API, jobs:** `evidence run -- <command>` runs the command and appends it, its output and its exit code to `terminal.log`. Run one command per criterion.
   - **iOS simulator:** `xcrun simctl io booted recordVideo <file>.mov` (stop it with Ctrl-C). Drive the app at a person's pace, and note the time where each criterion's result shows. Screenshots (`xcrun simctl io booted screenshot <file>.png`) only if it can't be recorded.
4. **Fill in EVIDENCE.md:** for each criterion, the recording and its time (`walkthrough.webm @ 0:07`), or `terminal.log`, and one line on what it shows. Update the Commit line to the commit you recorded at.
5. **Look at every frame:** `evidence frames` extracts the frame at each time to `$TMPDIR` and prints the paths (it needs `ffmpeg`). Look at each one with the Read tool. Confirm it shows what the row claims. If it doesn't, the feature, the recording or the time is wrong: fix it, don't describe around it. Fallback screenshots you look at directly.
6. **Upload:** `evidence upload`, if the project set `evidence_upload_cmd`. It replaces each file name with its link and keeps the local copy for `evidence frames`. Without a store it lists the files for the human to attach to the PR.
7. **Check:** `evidence check`. It confirms that every criterion has a recording with its time or a terminal log, every named file exists, no recording or screenshot is in git, with a store the recordings are uploaded, there is one recording and no screenshots beside it, screenshots have a reason, UI changes have a recording, and the evidence is fresh: no code changed since the commit on the Commit line. Changes to docs, Markdown, tests, worksheets and the evidence itself don't count. Record it when the feature works (workflow step 6), so reviewers can start from it. A later docs or test commit doesn't make you record it again. If a review fix touches code, re-record the criteria it affects at wrap-up and update the Commit line. Only this branch's own changes count, so merging main doesn't make evidence stale.
8. Commit EVIDENCE.md, `terminal.log` and the folder's `.gitignore` with the work (trailer `Worksheet: <name>`). Never commit the recording or screenshots.

## Opening the PR with evidence

```bash
evidence pr-body > "$TMPDIR/pr-body.md"
```

Put your summary above the generated `## Evidence` section in that file: what changed and why, how you verified it, and what you did not verify. Write it by the plain-language guide (`${CLAUDE_PLUGIN_ROOT}/skills/explain/plain-language.md`). The PR title follows the same guide, and says what changed. In particular:

- Name each actor.
- Use the specific verb.
- State results, not intent.
- Keep identifiers exactly as they are.
- Cut the words that add nothing, unless they carry weight.

Add a `## Merge risk` section after it with the independent grade (shipinetics:review, "Merge risk"). Then:

```bash
gh pr create --title "<title>" --body-file "$TMPDIR/pr-body.md"
```

Push the branch first so the `terminal.log` link resolves. If a recording isn't uploaded, the section says so: drag the file into the PR description. If evidence changes after review, regenerate the section and update the PR body (`gh pr edit --body-file`).

## Reviewing a PR

Open the evidence before reading the diff. For each criterion: run `evidence frames` and look at the frame at its time (or the transcript, or the fallback screenshot). Does it actually show the result? If the recording isn't on your machine, download it from its link into the evidence folder first. Is it from this branch's code? `evidence check` fails if code changed after the commit on the Commit line. Anything missing, stale or unconvincing is a finding, severity major.
