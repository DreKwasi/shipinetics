---
name: verification-map
description: Build and maintain the project's verification map in docs/verification/, the recipe for launching the real app, checking the instance is usable, driving each feature through every entry point a user has, capturing proof and cleaning up. Use during setup, when a task touches a feature the map doesn't cover, when driving the app for verification, evidence or an independent re-check, and weekly from the sweep to catch drift.
argument-hint: "[create|maintain|light <feature ids>]"
---

# The verification map

> Paths below are Shipinetics's defaults. A project can map them elsewhere in `.shipinetics/config`: run `shipinetics-config` to see this project's actual paths and commands, and use those.

"The build passed" says little about whether a feature works. Proof means using the real app the way a user does, through every way a user can reach the feature, and showing the result and the state it leaves behind. The map makes that repeatable: any agent, on any model, can launch the app, drive a feature and capture proof without rediscovering how. It lives in `docs/verification/` and is committed, so Codex, Cursor and CI agents can read it too. The approach comes from pstack's verification skills.

Argument: `$ARGUMENTS`. `create` builds the map. `maintain` checks the whole map against the code and drives every feature. `light <ids>` maintains only the features named. No argument: `create` if `docs/verification/README.md` doesn't exist, else `maintain`.

## What the map holds

`docs/verification/README.md`, with these sections:

| Section | What it says |
|---|---|
| **Launch** | Commands to go from an empty data directory to a *usable* app: install, migrations, seed data, start (through the project's secrets runner if it needs secrets), and the readiness check. Readiness means a real request succeeds, not that a port is open: a health check can pass while init scripts still run |
| **Doctor** | One read-only check that this instance is worth driving: the process is up, it's running this checkout's code (build version or commit), the port belongs to it, and the test login works. Run it before driving and after any surprise |
| **Isolation** | Whether two instances can run side by side (ports, data directories, queues), and how. Reviewers re-check the app while the author's instance may still be running |
| **Drive** | The harness: Playwright for web, a PTY or plain commands for CLIs, HTTP for APIs, the simulator for mobile. Use stable handles: roles, labels, `data-testid`, not CSS paths |
| **Evidence** | What proof looks like here (see the standards below), and where it goes: `docs/evidence/<worksheet>/` for a task, `$TMPDIR` for a reviewer's re-check |
| **Cleanup** | Stop only what you started, by the PID you recorded, never by process name. Never delete evidence. Leave the data directory as you found it, or say where you left it |
| **Feature index** | A table: feature ID, name, entry points, file, last verified (date and commit) |

`docs/verification/features/<id>.md`, one per feature, with exactly these sections:

- **Sub-features:** the behaviors this feature covers.
- **How a user gets to it:** every entry point, from the user's side: the nav link, the deep link, the keyboard shortcut, the CLI flag, the API route, the scheduled job.
- **Driving it:** exact steps per entry point, with the selectors or commands.
- **Proof:** what the result looks like, and how to read back the state it changes from a second, read-only view (a query, a GET, a different screen).
- **Gotchas:** what makes it flaky or misleading, and how to tell.

Start with 3 to 5 features: the ones users depend on most and the ones the current work touches. The map grows as tasks touch features it doesn't have.

## Evidence standards

These apply wherever the map is used, including shipinetics:evidence:

- **The real user path.** No test-only endpoints, fixture servers or injected state, unless that is the product. Mock only at production boundaries (payment provider, email), and say so.
- **Action and resulting state.** A screenshot of the button is not proof. Show what it did: the new row, the changed total, the file written.
- **Read changes back.** For anything that writes, confirm it from a second view that only reads.
- **Every entry point the map lists.** Proof through one convenient entry point is incomplete when the map lists others. Never report a skipped entry point as verified through a different one. Name what you didn't drive.
- **Label it.** Each artifact names the feature ID and the entry point.
- **Bugs:** reproduce the symptom through the real UI twice before the fix, and never force or inject the symptom while inspecting state.
- **Dry runs:** check what a dry-run mode really skips before trusting it.

## User-run servers (`launch = user`)

Some projects can't have agents start the app: the servers need the user's own credentials or devices, the dev stack is heavy, or the agent's sandbox can't run it. Setting `launch = user` in `.shipinetics/config` says the user starts and stops the servers. The map still describes how to launch, for humans. Agents work like this:

- **Doctor, never launch.** Run the doctor before driving. If the app isn't up, isn't running this checkout's code, or the test login fails, stop and ask the user to start or restart it, with the exact command from Launch. Don't start, restart or kill any server yourself.
- **No seeding, migrations or resets.** Work with the data that's there. If a feature needs data that isn't there, create it through the app, as the test account.
- **Writes only as the test account.** The map's Launch section names a test account (its credentials come through the project's secrets runner, never pasted). Every write happens as that account. Never change other users' data or shared settings.
- **Clean up what you wrote.** Record each thing you create (IDs, names) as you go, and delete it through the app or its API when you're done, then read it back to confirm it's gone. Say in the report what you couldn't remove. Evidence still survives cleanup.
- **One instance.** Reviewers re-check on the same running instance, after the doctor passes. The Isolation section says what can and can't run side by side.
- **Browser fallback.** If the agent's sandbox blocks connections to localhost (connection refused or not permitted when the user can open the page), drive the app with the harness's preview browser, for example Claude Code's preview tools, pointed at the URL the user's server serves. Screenshots and recordings from it count as evidence. Note in EVIDENCE.md which browser recorded it.

Write these rules into the README's Launch, Doctor, Isolation and Cleanup sections when the project uses `launch = user`, with this project's test account, URL and restart command.

## Create

1. **Interview the repo, not the user.** Check `shipinetics-config get launch` first: with `user`, write the map for user-run servers (above). Find how the app starts, seeds, logs in and logs, from `AGENTS.md`, `package.json` or the stack's equivalent, the e2e config, CI and the dev scripts. Ask the user only for what you can't find. If the checkout doesn't build or start, fix that first or report it.
2. **Write the README sections** above with the real commands. Prefer existing harnesses (the e2e setup, a seed script) over new ones. If a step needs a helper script, make it a `bin/` script (shipinetics:build-tool), not a paragraph of commands.
3. **Write the first feature files.** For each one, actually drive every entry point while you write it, and put the selectors you used in the file.
4. **Prove it end to end** before handing off: launch from empty data (with `launch = user`, ask the user to start it), run the doctor, drive one feature through every entry point, capture its proof, clean up, then confirm the evidence survived cleanup and nothing you started is still running. If you proved it in a stand-in environment, list which launch steps are still unproven.
5. **Point to it.** In `AGENTS.md`, make "Run the app yourself" point at `docs/verification/README.md`. If the harness supports project skills, add a short `.claude/skills/drive-app/SKILL.md` whose description says it launches and drives this app, and whose body points at the README. Claude Code's built-in `run` skill looks for a project skill like that.
6. Commit it with the setup or task it belongs to.

## Maintain

Edit only `docs/verification/` and its helper scripts, never product code.

1. **Index check:** every feature file is in the index and every index row has a file.
2. **Source pass:** for each feature, read the code behind its entry points and list likely drift with citations: a renamed route, a changed selector, a new entry point, a removed flag. For a big map, give each feature file to its own read-only subagent and merge the results.
3. **Missing features:** look at what changed since the oldest "last verified" commit (`git log --stat`). A user-visible feature with no file gets one, with the source path that shows it exists.
4. **Live pass:** required even when the source pass looks clean. Run the doctor, then drive every feature (or, for `light`, the named ones) through every entry point. Run the doctor again after any surprise. Evidence survives every cleanup, and nothing a drive started outlives it. A feature you can't reach counts as unreachable only with a named prerequisite ("needs a Stripe test key").
5. **Sort each problem:** map drift is fixed in the map, a harness gap is fixed in the harness, a product bug goes in the queue as a task with its proof. Never hide a product bug by changing the map's journey.
6. **Outcome:** exactly one of **clean** (nothing changed), **changed** (map or harness updated: say what) or **blocked** (say what's needed). Update "last verified" for each feature you drove.

## Where it's used

| When | What |
|---|---|
| Setup | `create`, from Phase 1's run-the-app step |
| Workflow step 6 | Drive the touched features from their files, every entry point |
| A task touches a feature the map lacks | Add its file in the same task |
| Evidence | The standards above, and the feature ID and entry point in each EVIDENCE.md row |
| Independent re-check | The wrap-up reviewer re-drives the main touched feature at the final code (shipinetics:review) |
| Weekly sweep | `maintain` |
