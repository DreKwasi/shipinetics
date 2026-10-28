---
name: testing
description: How tests get written here. The implementing agent never writes its own tests; the independent shipinetics:test-writer subagent does, from the spec, in a fresh context, with rules against bloat. Use whenever a task needs tests, before implementing a feature or fix, when a test fails and you're tempted to change it, or when tests feel bloated.
---

# Testing: independent and lean

> Paths below are Shipinetics's defaults. A project can map them elsewhere in `.shipinetics/config`: run `shipinetics-config` to see this project's actual paths and commands, and use those.
>
> Text for people (docs, worksheets, reports, PR bodies, replies): write it in ASD-STE100. Where the text describes structure or flow (a call path, a data flow, states or steps), show it on a Whiteboard. In a committed file, also put a Mermaid diagram and a link to the Whiteboard, because GitHub and other people cannot open your Whiteboard. Without Whiteboard, use Mermaid only. shipinetics:explain has the rules.

**The agent that writes the code doesn't write the tests.** Tests written by the author share the author's blind spots: the same misreading of the spec shows up in both the code and the test, and the test passes. So tests come from `shipinetics:test-writer`, a subagent with its own fresh context that works from the spec and the public interface. A hook enforces it: in a set-up project, only test-writer can create or edit files matching `.shipinetics/test-paths`, and test-writer can't edit source.

The project's own commands, layout and fixtures are in `docs/testing/how-to-write-tests.md`.

## The flow

1. **Spec first.** Acceptance criteria in `docs/specs/<slug>.md` (shipinetics:spec) or, for small tasks, in the worksheet. No criteria, no tests: tests without a spec just freeze whatever the code does.
2. **Acceptance tests before code.** Spawn `shipinetics:test-writer` in `acceptance` mode with the spec. It writes `e2e/acceptance/<slug>.spec.ts` (or the stack's equivalent), confirms they fail for the right reason, and they become protected.
3. **Define the interface.** Write the public signatures, types and module boundaries (stubs are fine). This is what test-writer tests against.
4. **Unit tests from the interface.** Spawn `shipinetics:test-writer` in `unit` mode with the spec and the interface files. Do this before or alongside implementation, not after you've finished and convinced yourself it works.
5. **Implement** until the tests pass. Run targeted tests as you go (one file, one name), not the whole suite.
6. **Bugs it reports are yours to fix.** Test-writer reports a "suspected bug" when the code disagrees with the spec. Fix the code. If you believe the test is wrong, don't argue with the test, argue with the spec: send test-writer your reasoning and the spec line, and it decides. If the spec itself is ambiguous, ask the human (interactive) or mark it under "Test change requests" in the worksheet (autonomous).
7. **Regression tests for bugs:** spawn test-writer in `regression` mode with the bug report. It writes a test that fails now. Then you fix the bug.
8. **`bin/verify`** passes before you're done.

Run test-writer in the foreground and wait for its report before you implement against its tests or report to the user. Its suspected bugs are input to your next step.

Test-writer runs on Opus at medium effort (its frontmatter). Don't pass a model or an effort when you spawn it. Its independence comes from its fresh context and the spec, not from a different model.

## What to give test-writer

```
Mode: unit
Spec: docs/specs/refund-rounding.md (AC1 to AC4)
Interface: src/refunds/calc.ts (exports computeRefund, RefundInput)
Notes: amounts are integer minor units; JPY and KRW have zero decimals
```

Don't give it your implementation reasoning, your worry list or your expected outputs. Its independence is the point.

## What lean means

**Test behaviours, not functions.** A test checks something a user or caller can observe, through the public entry point, in a sentence they would recognise ("ties go to whoever reached the total first"), never what one function returns. Each behaviour gets one test, at one layer, in one home: the module's test file, grouped by behaviour. A fix adds a case to the test of the behaviour it protects, not a new file named after the fix. This is Google's rule ("Software Engineering at Google", ch. 12: a test per behaviour, not per method), and the rest follows from it:

- Sort the code first. Domain logic gets tests of its behaviours. Glue code is covered by one test at its entry point. Trivial code gets none. Logic tangled with I/O is a refactor candidate, not something to mock around.
- Every test names the plausible bug it catches, and is shown to catch it. No nameable bug, no test.
- Mock only at system boundaries. Assert outputs and effects, never call counts on internal collaborators.
- Expected values come from the spec, worked out by hand.
- Tests that catch nothing unique are deleted.
- **One test per behaviour, with every check that behaviour needs.** A test has one reason to fail: its behaviour is broken. So it can assert several things about that behaviour (the returned value, the stored state, the message), and its name says the behaviour. Don't split one behaviour into a test for each assertion: that repeats the setup and multiplies the count without catching more bugs. Don't put two behaviours in one test either: the first failure hides the second, and the name can't say what broke.
- When behaviour changes or is removed, its tests change or go first (test-writer `change` mode). A deleted feature leaves no tests behind, and a changed one never gets a second test beside the old one. The suite grows only with new behaviour.

The detail is in the test-writer agent, and the test-integrity persona reviews it. A suite is good when it fails if the product breaks and passes when it doesn't. More tests isn't better, and coverage numbers don't measure what matters. The periodic audit (shipinetics:test-audit) reshapes suites that drifted.

## E2E specifics

- One test per acceptance criterion or user journey, named after the behavior.
- Arrange through the fastest honest route (API or seed), act and assert through the UI.
- Locate by role and accessible name, then test IDs. Never CSS classes or DOM shape.
- Wait on conditions, never on time.
- Fail on console errors and uncaught page errors.
- The one or two most important journeys are tagged `@smoke` so `bin/verify` (the complete tier) runs them before any task counts as done.

## When a test fails

- **The code is wrong** (usual case): fix the code.
- **The spec changed:** update the spec first (with the human's agreement), then have test-writer update the tests. For a protected acceptance test, test-writer writes the new version to `.shipinetics/pending/<test path>`, and a human applies it with `shipinetics-config apply`.
- **Flaky:** find the race or shared state. No retries, no sleeps. If it can't be fixed now, a queue task names the test and what you found.

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
