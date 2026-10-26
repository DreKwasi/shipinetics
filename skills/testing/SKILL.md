---
name: testing
description: How tests get written here. The implementing agent never writes its own tests; the independent shipinetics:test-writer subagent does, from the spec, in a fresh context, with rules against bloat. Use whenever a task needs tests, before implementing a feature or fix, when a test fails and you're tempted to change it, or when tests feel bloated.
---

# Testing: independent and lean

> Paths below are Shipinetics's defaults. A project can map them elsewhere in `.shipinetics/config`: run `shipinetics-config` to see this project's actual paths and commands, and use those.

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

Choose a different model for test-writer than the one implementing when you can (Opus implementing, Sonnet writing tests, or the reverse). Pass the model when you spawn it.

## What to give test-writer

```
Mode: unit
Spec: docs/specs/refund-rounding.md (AC1 to AC4)
Interface: src/refunds/calc.ts (exports computeRefund, RefundInput)
Notes: amounts are integer minor units; JPY and KRW have zero decimals
```

Don't give it your implementation reasoning, your worry list or your expected outputs. Its independence is the point.

## What lean means

Test-writer follows these, and reviewers check them (the test-integrity persona):

- One test per behavior, equivalence class or boundary. Same-shaped cases go in one table-driven test.
- Every test traces to a line of the spec.
- No tests of the framework, libraries, getters and setters, private functions, or what the type checker guarantees.
- Assert outputs and observable effects, never call counts on internal collaborators.
- Mock only at system boundaries: network, clock, randomness, filesystem, external services.
- Expected values come from the spec or hand calculation, never from running the code and pasting the output.
- Each test must catch a mutation (a deliberate break in the code) that no other test catches, or encode a named requirement. Redundant tests get deleted.

A suite is good when it fails if the product breaks and passes when it doesn't. More tests isn't better. Coverage numbers don't measure what matters. The periodic audit (shipinetics:test-audit) checks the suite stays that way.

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

## Escape hatch

If a session genuinely needs the implementer to touch tests (a mass rename, a framework migration), the user starts Claude Code with `SHIPINETICS_ALLOW_AUTHOR_TESTS=1`. Say why in the worksheet.
