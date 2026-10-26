---
name: workflow
description: The standard task loop for any coding task in a shipyard-set-up repo, from orienting through spec, tests, implementation, running the app, verification, review and wrap-up. Use at the start of any feature, bug fix or refactor, and whenever you're unsure what step comes next.
---

# The task loop

> Paths below are Shipyard's defaults. A project can map them elsewhere in `.shipyard/config`: run `shipyard-config` to see this project's actual paths and commands, and use those.

This is how every task runs, interactive or autonomous. Skip steps only where the size table says you can. If the project has its own `AGENT_WORKFLOW.md`, it overrides anything here that conflicts.

## Sizes

| Size | Looks like | Skip |
|---|---|---|
| **XS** | Typo, copy change, config value, one-line fix with an obvious test | Spec, research and plan reviews. Still verify and run the app |
| **S** | One area, under an hour, clear acceptance | Research review. Plan can be a few lines in the worksheet |
| **M** | Several files or systems, a few hours | Nothing |
| **L** | Days, or unclear scope | Don't start. Split it into M or smaller tasks in the queue first |

## 1. Orient

- Read the task. If it came from `TODOS.md`, claim it (shipyard:task-queue).
- Start or resume a worksheet: `worksheet new <slug> "<title>"` or `worksheet use <name>`. If you're resuming, read the whole worksheet and `git log --grep "Worksheet: <name>"` before touching anything.
- Find the relevant systems: `head -n 7 docs/systems/*.md`, then read the full doc for each system you'll touch.
- Run `bin/verify` once before changing anything. If it already fails, note that in the worksheet. You're not responsible for pre-existing failures, but you need to know about them.

## 2. Research (M and up)

Read the code paths you'll change, end to end. Write what you learned in the worksheet's Research section: how it works now, what you'll need to change, what surprised you.

Record every factual claim the plan will rely on in the worksheet's claims table, with its evidence: `file:line` for the codebase, an official primary source URL and the date you checked it for anything external (API behavior, limits, versions). Don't write a claim you haven't checked. If you can't find evidence, mark it unresolved and say what's missing. Comments, TODOs, feedback logs and old worksheets are history, not evidence of how things work now: confirm against live config and code, and if you can't, ask the user (interactive) or mark it unresolved (autonomous). An unresolved claim that the plan depends on is a blocker, not an assumption.

If the system doc was wrong or thin, fix it now. For unfamiliar or risky systems, get a research review (shipyard:review research), which checks the claims table row by row.

## 3. Spec and plan

- For M and up, write a spec with runnable acceptance criteria (shipyard:spec). For S, write the criteria in the worksheet.
- Plan the steps as a checklist in the worksheet. Each step should leave the code working.
- M and up: get a plan review (shipyard:review plan) before writing code. Fixing a plan is cheap. Fixing an implementation isn't.
- M and up, interactive: the spec ends with a ready-to-paste `/goal` line (shipyard:spec). Offer it to the user so the implementation runs until its deliverables are shown, not until you feel done.
- If the plan is ambiguous on something only the user can decide, ask now (interactive) or mark the task blocked with the question (autonomous). Don't guess on product decisions.

## 4. Tests first, by someone else

You don't write tests for your own code (shipyard:testing). Spawn `shipyard:test-writer`:

- `acceptance` mode with the spec, before any implementation. It writes the acceptance tests and confirms they fail for the right reason.
- `unit` mode once the public interface exists (signatures and types, stubs are fine).
- `regression` mode for a bug, before you fix it.

Read its report. "Suspected bugs" are yours to fix. "Gaps" usually mean the spec needs work.

## 5. Implement

- Small steps. After each one, run the targeted tests for what you touched, not the whole suite.
- Read config and secrets through the project's config module only. Never read environment variables directly in code, and never try to see a secret's value. To run something that needs secrets, use `bin/with-secrets <command>` (shipyard:secrets).
- Follow `docs/conventions.md`. Look for an existing helper before writing a new one.
- Update the worksheet log as you go: what you did, what happened, what you decided and why. Write it so another agent could take over mid-step.
- If you're going in circles (same error three times, or 20 minutes with no progress), stop. Write down what you've tried in the worksheet, then step back: reread the error, check your assumptions, search the codebase for how similar things are done. If you're autonomous and still stuck, mark the task blocked and move on.

## 6. Run the app yourself

Tests aren't enough. Start the app (commands in `AGENTS.md`), go through the feature the way a user would, and check:

- The feature works on the main path and at least one edge case (empty, error, long input).
- No errors in the browser console or server logs.
- Nothing nearby broke. Click through the screens next to the one you changed.

For web apps, drive it with Playwright or the Playwright MCP and take a screenshot of the result. Look at the screenshot. For CLIs and APIs, run the real commands and read the output. Write what you checked, and what you saw, in the worksheet.

Once it works, **record the evidence** (shipyard:evidence): a screenshot per acceptance criterion and a screen recording for UI changes, or terminal transcripts for CLIs and APIs, saved in `docs/evidence/<worksheet>/` and checked with `evidence check`. Every PR needs it, and the hook won't let a PR open without it.

## 7. Verify

Run `bin/verify`. It must pass. The Stop hook will run it anyway and send you back if it fails, so run it yourself first. Never edit, skip or delete a test to get a pass. If a test seems wrong, take it to test-writer with the spec (or, for protected tests, write it up under "Test change requests" in the worksheet).

## 8. Review

Implementation review is required for every task above XS (shipyard:review impl). That includes the security reviewer when the change touches anything security-relevant and the UI reviewer when it touches UI. Respond to every finding in the worksheet: fixed, disagree with a reason, or deferred to the queue.

For tasks M and up, also author a Whiteboard of the change for the human (shipyard:review, "Whiteboard for the human"), if Whiteboard is installed.

## 9. Keep the docs true

- Update the system docs you changed, especially their 7-line headers (shipyard:system-docs).
- Add new tests to `docs/testing/test-index.md`.
- If you made a mistake a linter could have caught, or a reviewer flagged the same issue twice, add a lint rule (shipyard:lint-rule) or at least a convention.
- If you repeated a multi-step command sequence, turn it into a script (shipyard:build-tool).

## 10. Wrap up

1. Wrap-up review for S and up (shipyard:review wrapup).
2. Commit, evidence included. Message says why, not just what. Add the trailer line `Worksheet: <name>`. Small, coherent commits beat one giant one.
3. If you're opening a PR: `evidence pr-body > "$TMPDIR/pr-body.md"`, add your summary above the Evidence section, get the merge-risk grade from an independent reviewer and add it below (shipyard:review), then `gh pr create --body-file "$TMPDIR/pr-body.md"` (shipyard:evidence).
4. Mark the worksheet done with a summary and exact next steps, if any. Fill in its Metrics block (shipyard:worksheet). `worksheet tag`.
5. Update the task queue: done, or follow-ups added.
6. Append feedback to `docs/agent-feedback.md` (shipyard:feedback).
7. Tell the user what changed, what you verified and how, and anything not done or not verified. No hedging on what's verified, no claiming what isn't. Pick the format that makes it fastest to understand (shipyard:explain): plain controlled English for short reports, a diagram when there's structure or flow, a Whiteboard or an HTML page for anything bigger.

## Optional skills that fit this loop

If installed, use them at the matching step: `grilling` to stress-test a plan in step 3, `tdd` in step 4, `diagnosing-bugs` when a bug resists, `codebase-design` when a change needs a new module boundary, `domain-modeling` when terms are fuzzy.
