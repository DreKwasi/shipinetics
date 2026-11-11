---
name: workflow
description: The standard task loop for any coding task in a shipinetics-set-up repo, from orienting and choosing a route (with the companion skills each route uses) through spec, implementation, tests, running the app, verification, review and wrap-up. Use at the start of any feature, bug fix or refactor, including bug reports, error reports and Sentry issues (the fix comes first, then a regression test from test-writer), and whenever you're unsure what step comes next.
---

# The task loop

> Paths below are Shipinetics's defaults. A project can map them elsewhere in `.shipinetics/config`: run `shipinetics-config` to see this project's actual paths and commands, and use those.
>
> Text for people (docs, worksheets, reports, PR bodies, replies): write it in ASD-STE100. Where the text describes structure or flow (a call path, a data flow, states or steps), show it on a Whiteboard. In a committed file, also put a Mermaid diagram and a link to the Whiteboard, because GitHub and other people cannot open your Whiteboard. Without Whiteboard, use Mermaid only. shipinetics:explain has the rules.

This is how every task runs, interactive or autonomous. Skip steps only where the size table says you can. If the project has its own `AGENT_WORKFLOW.md`, it overrides anything here that conflicts.

## Sizes

| Size | Looks like | Skip |
|---|---|---|
| **XS** | Typo, copy change, config value, one-line fix with an obvious test | Spec, research and plan reviews. Still verify and run the app |
| **S** | One area, under an hour, clear acceptance | Research review. Plan can be a few lines in the worksheet |
| **M** | Several files or systems, a few hours | Nothing |
| **L** | Days, or unclear scope | Don't start. Split it into M or smaller tasks in the queue first |

## 1. Orient

- Read the task. If it came from `TODOS.md`, claim it (shipinetics:task-queue).
- Start or resume a worksheet: `worksheet new <slug> "<title>"` or `worksheet use <name>`. If you're resuming, read the whole worksheet and `git log --grep "Worksheet: <name>"` before touching anything.
- Find the relevant systems: `head -n 7 docs/systems/*.md`, then read the full doc for each system you'll touch.
- For tasks S and up, offer the user routes for the task, with the companion skills that each route uses, and recommend one ("Choose a route" below).
- Run `shipinetics-verify` once before changing anything. If it already fails, note that in the worksheet. You're not responsible for pre-existing failures, but you need to know about them.

## 2. Research (M and up)

Read the code paths you'll change, end to end. Write what you learned in the worksheet's Research section: how it works now, what you'll need to change, what surprised you.

Record every factual claim the plan will rely on in the worksheet's claims table, with its evidence: `file:line` for the codebase, an official primary source URL and the date you checked it for anything external (API behavior, limits, versions). Don't write a claim you haven't checked. If you can't find evidence, mark it unresolved and say what's missing. Comments, TODOs, feedback logs and old worksheets are history, not evidence of how things work now: confirm against live config and code, and if you can't, ask the user (interactive) or mark it unresolved (autonomous). An unresolved claim that the plan depends on is a blocker, not an assumption.

If the system doc was wrong or thin, fix it now. For unfamiliar or risky systems, get a research review (shipinetics:review research), which checks the claims table row by row.

## 3. Spec and plan

- For M and up, write a spec with runnable acceptance criteria (shipinetics:spec). For S and XS, write the criteria in the worksheet, with IDs (`AC1`, `AC2` ...). Tests are only written for what a criterion states, so put each case that must not break in a criterion.
- Plan the steps as a checklist in the worksheet. Each step should leave the code working.
- M and up: get a plan review (shipinetics:review plan) before writing code. Fixing a plan is cheap. Fixing an implementation isn't.
- M and up, interactive: the spec ends with a ready-to-paste `/goal` line (shipinetics:spec). Offer it to the user so the implementation runs until its deliverables are shown, not until you feel done.
- If the plan is ambiguous on something only the user can decide, ask now (interactive) or mark the task blocked with the question (autonomous). Don't guess on product decisions.

## 4. Implement

- Small steps. After each one, run the targeted tests for what you touched, not the whole suite. Old tests of behaviour that you changed or removed can fail. Leave them for test-writer (step 5).
- Commit each step once it works, with the `Worksheet:` trailer. A reviewer reads a few hundred lines closely and skims anything bigger, so the pre-commit hook refuses commits over the size limit (400 changed lines by default). If a step comes out bigger, split it into commits that each leave the code working.
- Never try to see a secret's value. To run something that needs secrets, use `bin/with-secrets <command>` (shipinetics:secrets).
- Follow `docs/conventions.md`. Look for an existing helper before writing a new one.
- Update the worksheet log as you go: what you did, what happened, what you decided and why. Write it so another agent could take over mid-step.
- If you're going in circles (same error three times, or 20 minutes with no progress), stop. Write down what you've tried in the worksheet, then step back: reread the error, check your assumptions, search the codebase for how similar things are done. If you're autonomous and still stuck, mark the task blocked and move on.

## 5. Tests, by someone else

You don't write tests for your own code (shipinetics:testing). When the implementation is committed, spawn `shipinetics:test-writer` once, with every mode the task needs:

- `acceptance` for M and up: the acceptance criteria, at the entry point.
- `unit` for domain logic: the other cases that the criteria state, through the public interface.
- `regression` for a bug that you fixed. The test passes on the fix and fails on the code before it. First make sure that a criterion states the correct behaviour: the criterion that the bug broke, or a new one in the worksheet ("AC1: Given <your smallest repro>, when <action>, then <the correct result>").
- `change` when the task changed or removed behaviour that has tests. It changes or deletes those tests, so the suite doesn't pile up tests for code that no longer exists.

For M and up, ask it for the plan first, and have `shipinetics:test-plan-reviewer` review the plan before test-writer writes the tests (shipinetics:testing, step 3). Give it the spec and the commit range (`<base>..HEAD`; in workspace mode, the package repo's range). Don't edit source while it runs. Test-writer runs only targeted tests. Run `shipinetics-verify quick` after its report. The complete verify (step 7) runs the suite. Read its net change: the number of tests grows only with new behaviour.

Read its report. "Suspected bugs" are yours to fix: fix them, commit, and send test-writer the new commit if a test needs a second look. "Proposed criteria" are behaviours that it did not test, because no criterion states them: decide on them as shipinetics:testing (step 4) says. "Gaps" usually mean the spec needs work.

If the report has "Slow test runs", the project's tests cost more time than they need to. Tell the user now, in two or three lines: the command, the time of one run of one test, how much of the task's time that cost, the likely cause and the suggested fix. Don't change the project's test setup unless the user says yes: it is their code, and a fix such as reusing the test database must not weaken CI. Write it in the worksheet. In an autonomous session, add a queue task with the numbers instead. Tell the user only once per project. If they keep the setup, write the measured cost and their choice on the fixed-cost line of `docs/testing/how-to-write-tests.md` ("Fixed cost of one run: 36 s, kept by the user on <date>"). When that line records their choice, don't tell them again.

## 6. Run the app yourself

Tests aren't enough. Start the app and run the doctor check from `docs/verification/README.md` (shipinetics:verification-map), then go through the feature the way a user would, using its file in `docs/verification/features/`. Drive every entry point the file lists, not just the most convenient one. If the feature has no file, or the file is out of date, fix that in this task. If `shipinetics-config get launch` says `user`, the user runs the servers: follow the user-run rules in shipinetics:verification-map instead of launching anything. Check:

- The feature works on the main path and at least one edge case (empty, error, long input).
- What changed is really stored: read it back from a second, read-only view (a query, a GET, another screen).
- No errors in the browser console or server logs.
- Nothing nearby broke. Click through the screens next to the one you changed.

For web apps, drive it with Playwright or the Playwright MCP and take a screenshot of the result. Look at the screenshot. For CLIs and APIs, run the real commands and read the output. Write what you checked, and what you saw, in the worksheet.

Once it works, commit, then **record the evidence** (shipinetics:evidence) and set its Commit line to that commit: for UI changes one paced recording of the flow with the time of each acceptance criterion (screenshots only when it can't be recorded), or terminal transcripts for CLIs and APIs, in `docs/evidence/<worksheet>/` and checked with `evidence check`. Recordings never go in git: `evidence upload` puts them in the project's store, or the human attaches them to the PR. Recording now lets reviewers start from it. If a review fix later changes code, `evidence check` names the files, and you re-record the criteria they affect at wrap-up. Every PR needs it, and the hook won't let a PR open without it.

## 7. Verify

You run verify yourself. No hook runs it when you stop.

- After a step that changes behaviour, run `shipinetics-verify quick`. It checks only the changed files. Until test-writer finishes step 5, old tests of behaviour that you changed or removed can fail there. That is expected. Any other failure is yours.
- If verify names a test **flaky** (it failed, then passed on a re-run), it still failed. If your change touches what the test covers, the race is probably yours: fix it. If not, add a queue task with the test and the output, and tell the user. Don't run verify again and again to get a pass (shipinetics:testing, "Catching flaky tests").
- Before you mark the task done, run `shipinetics-verify`. It runs the complete verify (`bin/verify`) and must pass. It records the pass for exactly this code, so the pre-push hook and the PR gate reuse it and do not run it again. Committing the code, or editing only the worksheet, evidence or feedback log, keeps the pass. Any other change needs a new run.
- Don't run verify while a subagent is still editing or running tests. Wait for it to finish.
- Don't answer a question with a verify run. Run it only when the code changed.

"Done" always means the complete verify passed on the final code. A PR can't open without it. Never edit, skip or delete a test to get a pass. Removing the tests of behaviour that the task removes is different: test-writer does it in `change` mode and names each one. If a test seems wrong, take it to test-writer with the spec (or, for protected tests, write it up under "Test change requests" in the worksheet).

## 8. Review

Implementation review is required for every task above XS (shipinetics:review impl). That includes the security reviewer when the change touches anything security-relevant and the UI reviewer when it touches UI. Respond to every finding in the worksheet: fixed, disagree with a reason, or deferred to the queue.

For UI changes, run `design-check` yourself before review and fix what it finds. A value outside DESIGN.md either becomes the documented token, or, if the design really needs something new, goes in the worksheet's "Design-system change requests" for a human to approve. Don't add tokens or edit DESIGN.md to make a finding go away.

For tasks M and up, also author a Whiteboard of the change for the human (shipinetics:review, "Whiteboard for the human"), if Whiteboard is installed.

## 9. Keep the docs true

- Update the system docs you changed, especially their 7-line headers (shipinetics:system-docs).
- Add new tests to `docs/testing/test-index.md`.
- If you made a mistake a linter could have caught, or a reviewer flagged the same issue twice, add a lint rule (shipinetics:lint-rule) or at least a convention.
- If you repeated a multi-step command sequence, turn it into a script in `bin/`. Give it a usage comment and `--help`. Make it non-interactive, quiet on success, and clear on failure: say how to fix the error. Use exit code 0 for success, 1 for failure and 2 for bad usage. Add a line to `docs/tools.md` in the same commit, so the next agent finds it.

## 10. Wrap up

1. If review fixes changed code since the evidence was recorded, re-record the affected criteria now (`evidence check` says which). Then the wrap-up review for S and up (shipinetics:review wrapup).
2. Commit what's left: evidence, docs, the worksheet. Message says why, not just what. Add the trailer line `Worksheet: <name>`.
3. If you're opening a PR: `evidence pr-body > "$TMPDIR/pr-body.md"`, add your summary above the Evidence section, get the merge-risk grade from an independent reviewer and add it below (shipinetics:review), then `gh pr create --body-file "$TMPDIR/pr-body.md"` (shipinetics:evidence).
4. Mark the worksheet done with a summary and exact next steps, if any. Fill in its Metrics block (shipinetics:worksheet). `worksheet tag`.
5. Update the task queue: done, or follow-ups added.
6. Append feedback to `docs/agent-feedback.md` (shipinetics:feedback).
7. Tell the user, in ASD-STE100 (shipinetics:explain), what changed, what you verified and how, and anything not done or not verified. If test-writer reported slow test runs, say it again in one line with the time it cost this task. No hedging on what's verified, no claiming what isn't. Pick the format that makes it fastest to understand (shipinetics:explain): plain controlled English for short reports, a diagram when there's structure or flow, a Whiteboard or an HTML page for anything bigger.

## Choose a route

A route is the order of steps for a task, and the companion skills that each step uses. For tasks S and up, offer the user two or three routes before you start research. Put the route that you recommend first, and give the reason in one sentence. Then wait for the user's choice. For an XS task, or in an autonomous session, take the route that you recommend and write it in the worksheet.

Offer only routes that are really different. If one route is clearly correct, offer it with one other route, and say why the other route is weaker.

Example: the user asks for an authentication feature.

> **Route A (recommended):** `grilling` with `domain-modeling` to settle the decisions (sessions or tokens, which provider, what happens to current users), then a spec. Reason: these decisions are hard to reverse.
> **Route B:** `research` first (the provider's docs, rate limits, token lifetimes), then `grilling`, then a spec. Use it when the provider is new to the project.
> **Route C:** a `prototype` of the login flow, then a spec. Use it when you cannot decide without seeing the flow.

Use the companion skills at these steps. Where a companion's rules and Shipinetics's rules are different, Shipinetics's rules apply:

| Companion | Use it when | Step | Rules here |
|---|---|---|---|
| `grilling` with `domain-modeling` | M and up, before the spec. When you split an L task. Before each decision that is hard to reverse (a rename, a removal, a breaking change, a new public interface), whatever the task's size | 3, interactive | Terms go in `GLOSSARY.md`. Decisions that are hard to reverse go in `docs/adr/` |
| `research` | The task depends on external facts: an API, a limit, a version | 2 | Its findings go in the claims table, with the URL and the date |
| `prototype` | A question needs a runnable answer: a state model, a screen | 3, interactive | Write the answer in the spec or in the worksheet's Decisions. Delete the prototype before the PR |
| `codebase-design` | A change needs a new module or seam | 3 | Reviewers use the same words (depth, seam, adapter). Its advice to delete old tests goes to test-writer |
| `diagnosing-bugs` | A bug, an error report or a slow path | bug fixes | Phases 1-4 and 6 as written. Put its loop scripts in `$TMPDIR` or `bin/`, not in test paths. Fix the bug first. Write the correct behaviour as a criterion in the worksheet (or name the spec criterion that the bug broke). Then test-writer writes the regression test (phase 5) in `regression` mode, from that criterion, your smallest repro and the fix commit |
| `wait-what` | The user types `/wait-what` | any | Explain again: a little context first, ASD-STE100 (shipinetics:explain), and the terms in `GLOSSARY.md` |
| Impeccable | UI work | 3, 4, 8 | `shape` for the brief, `polish` before review, `detect` and `audit` in review (shipinetics:review) |
| tasteskill (optional) | UI work that builds or redesigns a page or an app screen: a landing page, a company site, a dashboard. Offer it as a route, with its cost: 30 to 45 minutes and a few hundred thousand tokens for a page | 4, 6 | `DESIGN.md` wins over its kit: give it the project's tokens and fonts, and put a value that the page really needs in "Design-system change requests". Without `DESIGN.md`, run `/impeccable document` after the build. Commit only the kit files that the page loads, as one vendored commit before the page's commits (`SHIPINETICS_ALLOW_BIG_COMMIT=1`, and say why in the message). Point its screenshots and browser profile at `$TMPDIR`, never into git. The prices, hours and addresses that its report says it assumed go in the worksheet's open questions. Its checkers are part of step 6. They do not replace `design-check`, the UI reviewer or the evidence |
| `security-audit` | The change touches security | 8 | Through `shipinetics:security-reviewer` |
| `merge-risk` | A PR opens | 10 | Through shipinetics:review |

If a route needs a companion that is not installed (`shipinetics-companions missing`), say so in the route. Give the companion's install command and its SkillSpector result, and also offer a route without it. Never install a companion without the user's yes.

You can use other skills too. Only test-writer writes tests (the edit guard makes sure of this), so give the test step of any skill to test-writer.
