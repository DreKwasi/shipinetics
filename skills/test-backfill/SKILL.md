---
name: test-backfill
description: Add tests to an existing app that has few, in small batches, riskiest features first. For each batch it drafts acceptance criteria from what users see, gets them approved in one round, and has shipinetics:test-writer write the tests in parallel, one feature for each writer. A ledger in docs/testing/backfill.md records the progress, so each run continues where the last one stopped. Use after setup, when the user runs /shipinetics:test-backfill, or when the user asks to add tests to existing code.
argument-hint: "[next|<feature ids>|status]"
---

# Test backfill

> Paths below are Shipinetics's defaults. A project can map them elsewhere in `.shipinetics/config`: run `shipinetics-config` to see this project's actual paths and commands, and use those.
>
> Text for people (docs, worksheets, reports, PR descriptions, commit messages, review comments, replies, and each label on a board, diagram or table): write it in ASD-STE100, by the plain-language guide (`${CLAUDE_PLUGIN_ROOT}/skills/explain/plain-language.md`). Where the text describes structure or flow (a call path, a data flow, states or steps), show it on a Whiteboard. In a committed file, also put a Mermaid diagram and a link to the Whiteboard, because GitHub and other people cannot open your Whiteboard. Without Whiteboard, use Mermaid only. shipinetics:explain has the rules.

An app with few tests needs many tests, and test-writer writes a test only for an acceptance criterion. Criteria for a whole app, written all at once, take days and nobody reviews them well. So this skill does the work in batches of 3 to 5 features. Each batch has one approval round for the human and gives committed tests at its end. The riskiest features come first, so the first batch gives the most protection.

Argument: `$ARGUMENTS`. `next` (the default) continues the ledger: first the features in `criteria drafted` (from step 3, in an interactive session), then the features in `approved` (from step 4), then a new batch from `todo`. Feature IDs take those features, each from the step that its status shows. `status` shows the ledger and stops.

## Before the first batch

Check these and stop with what's missing if one fails:

- `docs/testing/how-to-write-tests.md` gives the fastest targeted command, its fixed cost, and if copies can run at the same time (setup, Phase 1 "Testing guide").
- `docs/verification/` exists (shipinetics:verification-map), so that features can be driven. Setup puts only 3 to 5 features in it, so the map is not the full list of features (see "The ledger").
- `shipinetics-verify` passes, or its known failures are quarantined (shipinetics:testing, "A suite that already fails"). Tests written on a red suite prove nothing.

## The ledger

`docs/testing/backfill.md` records each feature and its status. Create it on the first run:

```
# Test backfill
> Summary: Which features of the app have tests from approved criteria, which come next, and why.
| Feature | Risk | Why this risk | Status | Spec | Tests | Updated |
```

Status is one of: `todo`, `criteria drafted`, `approved`, `tested`, `skipped` (with the reason).

**List every feature on the first run,** not only the features in the verification map. Find each thing that a user or a caller can do: the routes and screens, the API endpoints, the CLI commands, the jobs and the webhooks. Group them into features as a user would name them ("checkout", "invite a teammate"), with the map's feature IDs where the map has the feature. Read only the routing, the navigation and the command lists for this, not the code behind them. A feature with no map file gets one (verification-map `light`) when its batch starts, not before.

**Rank by risk.** For each feature, look at:

1. **What a bug costs:** money, auth and permissions, writes or deletes of user data, anything a domain persona names. These are high.
2. **Bugs that shipped:** fix commits that touched the feature's files in the last 6 months (`git log --since=6.months -i --grep=fix --name-only`).
3. **Change rate:** commits to its files in the last 3 months. Code that changes often breaks often.
4. **Tests that exist:** the feature's rows in `docs/testing/test-index.md`. Good coverage moves a feature down.

Write the reason in a few words ("payments, 4 fixes since May, no e2e test"). Sort by risk, highest first. Show the user the ranked list on the first run, and change the order if they ask.

## A batch, step by step

1. **Pick the batch.** The next 3 features with status `todo` (up to 5 if each is small). Start a worksheet: `worksheet new test-backfill-<first feature id>`.
2. **Draft the criteria.** For each feature, write `docs/specs/<feature id>.md` with shipinetics:spec's format, and put this line under the title: "Source: test backfill. These criteria state what the app does today." Get the criteria from what a user or caller sees, never from function bodies:
   - Drive the feature through its entry points with the verification map (you do this, not a subagent), and read its feature file, the UI text, the API schema, the docs and the names of its existing tests.
   - Write 3 to 7 criteria for each feature, with IDs: the main example of each sub-feature, the limits that matter (amounts, permissions, sizes), and the errors that users get. Each one is "Given ..., when ..., then ..." with real values.
   - Leave out what nobody depends on. Fewer criteria with real examples are better than many vague ones.
   - **What looks wrong is not a criterion.** If the app does something that seems to be a bug, put it in the worksheet under "Suspected bugs" and in the approval message. Don't write a criterion that freezes it.

   For more than 2 features, give each feature to its own read-only subagent (Explore) that reads the UI text, the schemas and the docs and returns a draft. Then drive each feature yourself, correct the drafts from what you saw, and write the files.
3. **One approval round.** Show all the criteria of the batch in one message: a table for each feature (ID, criterion, example), then the suspected bugs. The user approves, edits or removes criteria, and says for each suspected bug if it is a bug (it becomes a queue task) or the wanted behaviour (it becomes a criterion). Write the answers into the specs, add the line "Approved by <the user's name> on <date>, in the session of worksheet <name>." under the source line of each spec, and set the status to `approved`.
   Criteria are product decisions. In an autonomous session, stop after step 2: set the status to `criteria drafted`, add one task to the **Blocked** section of the queue ("Approve the test-backfill criteria for <features>: run /shipinetics:test-backfill next"), and end the run. Never test criteria that a human didn't approve: step 4 starts only for a spec with an "Approved by" line.
4. **Write the tests.** Spawn one `shipinetics:test-writer` for each feature, with mode `backfill`, the spec, `HEAD` as the commit, and the feature's entry points as the target. Tell each writer to return its test-index rows in its report and not to edit `docs/testing/test-index.md`: parallel writers in one working tree would overwrite each other's edits. You add the rows in step 6. Run them in parallel when each one writes to its own test files and `how-to-write-tests.md` says that copies can run at the same time. Otherwise run them one after another. For a feature with more than 5 criteria, ask for "Plan first" and run `shipinetics:test-plan-reviewer` on each plan (all features in parallel) before the tests are written.
5. **Suspected bugs from test-writer.** A test that fails on an approved criterion means that the app disagrees with what the human approved. Don't change the criterion to match the app. Test-writer leaves that test out of the tree and puts it in its report. Add a queue task for each one, with the criterion and the test. The fix goes through the normal workflow, and its regression test comes from test-writer then.
6. **Commit and record.** For each feature: add its test-index rows from the writer's report, run `shipinetics-verify quick`, then commit its tests, its spec and its test-index rows (under 400 lines, with the worksheet trailer). Set the ledger status to `tested`, with the test files. After the last feature, run the complete `shipinetics-verify`.
7. **Report.** For each feature: criteria approved, tests added and extended, the mutants that the tests caught, suspected bugs, and the time it took. Then propose the next batch from the ledger.

## Keep it fast

- **One feature, one context.** Each test-writer sees only its own feature's spec and entry points. Don't send a writer the whole app.
- **Acceptance tests first.** One test for each criterion's main example, at the entry point, catches the most for each test. Unit tests are only for domain logic with many cases that a criterion names (amounts, rounding, states).
- **Existing tests count.** When a test already proves a criterion, test-writer adds the criterion reference to it and writes nothing new.
- **Slow runs are the user's choice.** If test-writer reports "Slow test runs", give the user the numbers once (shipinetics:workflow). A slow fixed cost multiplies over every proof run of every feature.
- **Stop when the risk is low.** When the features left are all low risk, tell the user and stop the backfill. Their tests come when a task touches them, through the normal workflow.

## Prompt for a long backfill

To run batches one after another without a person between them, criteria approval must come first. A human approves the criteria of several batches in one sitting, and then this prompt writes their tests:

```
Run /shipinetics:test-backfill on each feature in docs/testing/backfill.md with status "approved"
whose spec has an "Approved by" line, one batch of 3 at a time. Don't draft or approve criteria. After each batch: shipinetics-verify must pass,
commit, update the ledger. Stop when no feature is "approved", when verify fails and you can't
find the cause in 3 tries, or when a suspected bug blocks a feature. Report what you did and what's left.
```
