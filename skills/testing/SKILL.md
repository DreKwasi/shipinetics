---
name: testing
description: How tests get written here. The implementing agent never writes its own tests; the independent shipinetics:test-writer subagent does, from the spec, in a fresh context, with rules against bloat. Every test proves an acceptance criterion and names it. Use whenever a task needs tests, after implementing a feature or fix, when a test fails and you're tempted to change it, or when tests feel bloated.
---

# Testing: independent and lean

> Paths below are Shipinetics's defaults. A project can map them elsewhere in `.shipinetics/config`: run `shipinetics-config` to see this project's actual paths and commands, and use those.
>
> Text for people (docs, worksheets, reports, PR descriptions, commit messages, review comments, replies, and each label on a board, diagram or table): write it in ASD-STE100, by the plain-language guide (`${CLAUDE_PLUGIN_ROOT}/skills/explain/plain-language.md`). Where the text describes structure or flow (a call path, a data flow, states or steps), show it on a Whiteboard. In a committed file, also put a Mermaid diagram and a link to the Whiteboard, because GitHub and other people cannot open your Whiteboard. Without Whiteboard, use Mermaid only. shipinetics:explain has the rules.

**The agent that writes the code doesn't write the tests.** Tests written by the author share the author's blind spots: the same misreading of the spec shows up in both the code and the test, and the test passes. So tests come from `shipinetics:test-writer`, a subagent with its own fresh context that works from the spec and the public interface. A hook enforces it: in a set-up project, only test-writer can create or edit files matching `.shipinetics/test-paths`, and test-writer can't edit source.

The project's own commands, layout and fixtures are in `docs/testing/how-to-write-tests.md`.

## The flow

1. **Spec first.** Acceptance criteria with IDs (`AC1`, `AC2` ...) in `docs/specs/<slug>.md` (shipinetics:spec) or, for small tasks, in the worksheet. No criteria, no tests: tests without a spec just freeze whatever the code does. For a bug fix, a criterion states the correct behaviour before test-writer starts: the criterion that the bug broke, or a new one in the worksheet ("AC1: Given <the repro>, when <action>, then <the correct result>").
2. **Implement, then commit.** Run the existing targeted tests as you go (one file, one name), not the whole suite. Old tests of behaviour that you changed or removed can fail now. Leave them: test-writer changes or deletes them in step 3.
3. **Then the tests, in one request.** Spawn `shipinetics:test-writer` once, with every mode the task needs: `acceptance` (the criteria, at the entry point; for M and up), `unit` (domain logic), `regression` (a bug you fixed) and `change` (tests of changed or removed behaviour). Give it the spec and the commit range. Don't edit source while it runs. The new tests must pass on your code. Regression tests must also fail on the code before your fix: test-writer checks that against the base commit. New acceptance tests become protected.
   For tasks M and up, the plan is reviewed before any test is written:
   1. Spawn test-writer with "Plan first". It returns its test plan and writes no files.
   2. Spawn `shipinetics:test-plan-reviewer` with the spec, the plan and the target. Give it nothing else. It returns KEEP, CUT, MERGE, MOVE or REWRITE for each row, the acceptance criteria that have no row, and the proposed criteria.
   3. Decide on the proposed criteria (step 4). Then send the verdict, with the IDs of any criteria that you added, to the same test-writer (SendMessage, so it keeps its context). It writes and proves the tests of the approved plan.

   Skip the plan review for S tasks and for a request with only `regression` mode: the plan has one row.
4. **Proposed criteria are a decision, not a test.** Test-writer tests only what a criterion states. A behaviour that seems to need a test, but that no criterion states, comes back under "Proposed criteria". Interactive: show them to the user and add the ones that they accept to the spec, with the next free IDs. Autonomous: add one yourself only if it is a technical detail (invalid input gets an error, not a crash), and record it under Open questions so a human can overrule it. A product decision goes to Open questions with no test. Then send the new IDs to the same test-writer.
5. **Bugs it reports are yours to fix.** Test-writer reports a "suspected bug" when the code disagrees with the spec. Fix the code. If you believe the test is wrong, don't argue with the test, argue with the spec: send test-writer your reasoning and the spec line, and it decides. If the spec itself is ambiguous, ask the human (interactive) or mark it under "Test change requests" in the worksheet (autonomous).
6. **`shipinetics-verify`** passes before you're done. Test-writer runs only targeted tests, so the complete verify is what runs the suite on the final code.

Run test-writer in the foreground and wait for its report before you run verify or report to the user. If the report has "Slow test runs", tell the user the numbers and the suggested fix (shipinetics:workflow, step 5). Don't change the project's test setup without their yes. Its suspected bugs are input to your next step.

Test-writer runs on Opus at medium effort (its frontmatter). Don't pass a model or an effort when you spawn it. Its independence comes from its fresh context and the spec, not from a different model. Test-plan-reviewer runs on Sonnet at high effort (its frontmatter). Don't pass a model or an effort. It judges a short table against the spec, so it doesn't need Opus.

## What to give test-writer

```
Modes: acceptance, unit
Spec: docs/specs/refund-rounding.md (AC1 to AC4; tests name them as "refund-rounding AC2")
Change: main..HEAD
Interface: src/refunds/calc.ts (exports computeRefund, RefundInput)
Notes: amounts are integer minor units; JPY and KRW have zero decimals
```

Don't give it your implementation reasoning, your worry list or your expected outputs. Its independence is the point.

## What lean means

**Every test proves an acceptance criterion.** A test, and each case in it, checks what a criterion says, and names it: `refund-rounding AC2` at the start of the test's name (or of its group's name, or in a comment where names can't hold it). In a file that holds the tests of one spec, such as `e2e/acceptance/<slug>.spec.ts`, the ID alone is enough. A behaviour that no criterion states gets no test: test-writer proposes the criterion instead. So `rg 'refund-rounding AC2'` finds every test of a criterion, a changed criterion shows which tests to change, and a test with no criterion is easy to see. The criterion's sentence must state what the test checks: an ID put on an unrelated test is a false link, and the reviewers cut it.

**Test behaviours, not functions.** A test checks something a user or caller can observe, through the public entry point, in a sentence they would recognise ("ties go to whoever reached the total first"), never what one function returns. Each behaviour gets one test, at one layer, in one home: the module's test file, grouped by behaviour. A fix adds a case to the test of the behaviour it protects, not a new file named after the fix. This is Google's rule ("Software Engineering at Google", ch. 12: a test per behaviour, not per method), and the rest follows from it:

- Sort the code first. Domain logic gets tests of its behaviours. Glue code is covered by one test at its entry point. Trivial code gets none. Logic tangled with I/O is a refactor candidate, not something to mock around.
- Every test names its criterion and the plausible bug it catches, and is shown to catch it. No criterion or no nameable bug, no test.
- Cases come from the criterion: the values it names, its limit and just over it. An edge that no criterion states is a proposed criterion, not a case.
- Mock only at system boundaries. Assert outputs and effects, never call counts on internal collaborators.
- Expected values come from the spec, worked out by hand.
- Tests that catch nothing unique are deleted.
- **One test per behaviour, with every check that behaviour needs.** A test has one reason to fail: its behaviour is broken. So it can assert several things about that behaviour (the returned value, the stored state, the message), and its name says the behaviour. Don't split one behaviour into a test for each assertion: that repeats the setup and multiplies the count without catching more bugs. Don't put two behaviours in one test either: the first failure hides the second, and the name can't say what broke.
- When behaviour changes or is removed, its tests change or go in the same task (test-writer `change` mode). A deleted feature leaves no tests behind, and a changed one never gets a second test beside the old one. The suite grows only with new behaviour.

The detail is in the test-writer agent, and the test-integrity persona reviews it. A suite is good when it fails if the product breaks and passes when it doesn't. More tests isn't better, and coverage numbers don't measure what matters. The periodic audit (shipinetics:test-audit) reshapes suites that drifted.

## E2E specifics

- One test per acceptance criterion, named with its ID and its behaviour (`"AC2: a declined card shows the reason"`).
- Arrange through the fastest honest route (API or seed), act and assert through the UI.
- Locate by role and accessible name, then test IDs. Never CSS classes or DOM shape.
- Wait on conditions, never on time.
- Fail on console errors and uncaught page errors.
- The one or two most important journeys are tagged `@smoke` so `bin/verify` (the complete tier) runs them before any task counts as done.

## When a test fails

- **The code is wrong** (usual case): fix the code.
- **The spec changed:** update the spec first (with the human's agreement), then have test-writer update the tests. For a protected acceptance test, test-writer writes the new version to `.shipinetics/pending/<test path>`, and a human applies it with `shipinetics-config apply`.
- **Flaky:** find the race or shared state. No retries, no sleeps. If it can't be fixed now, a queue task names the test and what you found.

## Catching flaky tests

A flaky test passes and fails on the same code. It hides real bugs and teaches people to re-run until green. Three checks catch it, and none of them turns a failure into a pass:

1. **When it's written.** Test-writer runs each new or changed test 5 more times at HEAD. One failure, and the test isn't done.
2. **When verify fails.** `bin/verify` gates the suite with `known-failing check --rerun '<cmd>'`. The failures run once more. A test that passes then is named **flaky** in the output and logged in `.shipinetics/.cache/flaky.tsv`, but the check still fails. So you know if you broke something or hit a race. Fix the race, or, if it isn't yours and can't be fixed now, add a queue task that names the test, and ask the human what to do. Never re-run verify until it passes.
3. **Every week.** The sweep runs `known-failing hunt -n 5 -- <cmd with {junit}>` on the main branch: the suite 5 times on the same code. Each test that passed and failed gets a queue task. `known-failing flaky` adds the ones that verify found during the week.

The re-run and the hunt need a JUnit report (see below). `{junit}` in the command is the path to write it to.

Never make a test pass by loosening, deleting, skipping or re-snapshotting it. The hooks block the direct route and the reviewers check for the indirect ones.

## A suite that already fails

When a project starts with failing tests nobody can fix yet, the gate would block every task. Quarantine them instead of skipping them, so only new failures fail:

1. Have the test runner write a JUnit XML report (`vitest --reporter=junit`, `jest-junit`, `pytest --junitxml`, `go-junit-report`, `cargo nextest`, Playwright's junit reporter).
2. A human records today's failures: `known-failing init <report.xml>` writes `.shipinetics/known-failing`, one test ID per line. The list is protected. Agents propose changes through `.shipinetics/pending/` like any protected file.
3. In `bin/verify`, run the suite without letting its exit code decide, then gate on the report: `known-failing check <report.xml>`. It fails on any failure that isn't listed, and fails on an empty or missing report, so a crashed runner can't pass.
4. Shrinking the list is real work: each entry is a queue task. When `check` says a listed test passes now, propose removing it. Never add a new failure to the list to get a pass. That's a human's decision, and the reviewers flag any change to the list.

In CI, where the plugin isn't installed, copy `known-failing` from the plugin's `bin/` into the project's `bin/`. It runs on its own.

## Escape hatch

If a session genuinely needs the implementer to touch tests (a mass rename, a framework migration), the user starts Claude Code with `SHIPINETICS_ALLOW_AUTHOR_TESTS=1`. Say why in the worksheet.
