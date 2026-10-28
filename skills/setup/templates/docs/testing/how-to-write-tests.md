# How to write tests here
> Summary: How the tests in this repo are organized and run, and which test to write for which change. It also lists the patterns that make tests lie. Read it before you write or change a test.
> Owns: {{test folders, e.g. src/**/*.test.ts, e2e/**}}
> Entry points: {{UNIT_TEST_CMD}}, {{E2E_CMD}}, bin/verify
> Depends on: docs/testing/test-index.md (what exists), .shipinetics/protected-paths (files that agents cannot change)
> Gotchas: {{e.g. "e2e needs the dev server and seeded DB; run the seed first"}}
> Owner persona: test-integrity | Last verified: {{YYYY-MM-DD}} at {{short commit}}

<!-- Write this file in ASD-STE100 (Simplified Technical English): short sentences, active voice, one word for one thing. Where it describes structure or flow, add a Mermaid diagram and a link to its Whiteboard. Rules: shipinetics:explain. -->

## Which test to write

| Change | Write |
|---|---|
| New user-facing behaviour | An e2e test for the main path, written from the acceptance criteria before the code. Unit tests for the domain logic's behaviours |
| Bug fix | A regression case in the test of the behaviour it broke, failing without the fix. Watch it fail first. Not a new file named after the fix |
| Pure logic (parsing, calculation, state machines) | Tests of its behaviours through its public interface, with edge cases and invalid input as rows in a table |
| Glue (routes, controllers, wiring) or trivial code | No unit tests. A behaviour test at the entry point covers it |
| Refactor | No new tests. The existing tests must pass with no change. If a test had to change, the change was not a pure refactor |
| Changed behaviour | Change the test of that behaviour, before the code (test-writer `change` mode). Never add a second test beside the old one |
| Removed behaviour or deleted code | Delete its tests, or the cases that cover it, in the same change. Remove its lines from the test index |
| UI appearance | A screenshot test (shipinetics:visual-regression) |
| Performance-sensitive path | A benchmark (shipinetics:perf) |

## Layout and commands

- Unit tests: {{where they live, naming}}. Run one file: `{{single file cmd}}`.
- E2E: {{e2e folder}}. Run one: `{{single e2e cmd}}`. Smoke tests are tagged `@smoke` and run in `bin/verify`.
- Acceptance tests from specs live in `e2e/acceptance/` and are protected once written.
- Test data: {{fixtures, factories, seed}}.

## Rules

- **Test behaviours, not functions.** One test per behaviour a user or caller can observe, through the public entry point, at one layer. Never one test per function, and never on private functions or call counts.
- **One home per behaviour.** Tests live in the module's test file, grouped by behaviour. Extend the existing test before adding one.
- **One test per behaviour, with every assertion it needs.** Several assertions about one behaviour belong in one test. Never split one behaviour into a test for each assertion, and never cover two behaviours in one test. Name the test after its behaviour.
- **Changed or removed behaviour changes its tests first.** When you delete code, delete its tests in the same change. When a behaviour changes, change its test. The suite grows only with new behaviour.
- **Every test must be able to fail.** Before you commit a new test, break the code that it covers and see the test fail. Do this in a scratch copy of the project, never in the working tree.
- **E2E selectors** use roles and accessible names (`getByRole('button', { name: 'Save' })`), then `data-testid`. Never CSS classes or DOM structure.
- **No fixed sleeps.** Wait for a condition (`expect(...).toBeVisible()`), not for time.
- **Deterministic.** Control time, randomness and network. A flaky test is a bug: fix the cause or quarantine it with a task in `TODOS.md`, never add retries to hide it.
- **Fail on console errors** in e2e tests.

## Patterns that make tests lie (never do these)

- Asserting only that something is truthy, defined, or does not throw.
- Mocking the thing that you test, or mocks that return exactly what the assertion expects.
- Updating expected values or snapshots to match new output without a spec change saying the behaviour changed.
- `try/catch` around assertions, `.skip`, `.only`, `xfail` left in commits.
- Asserting on a loading state, then never on the loaded result.
- Tests that pass when the feature is deleted.

## After writing tests

Update `docs/testing/test-index.md`: one line per behaviour, under its module, naming the test that proves it.
