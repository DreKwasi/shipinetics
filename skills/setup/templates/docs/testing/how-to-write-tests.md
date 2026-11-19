# How to write tests here
> Summary: How the tests in this repo are organized and run, and which test to write for which change. It also lists the patterns that make tests lie. Read it before you write or change a test.
> Owns: {{test folders, e.g. src/**/*.test.ts, e2e/**}}
> Entry points: {{UNIT_TEST_CMD}}, {{E2E_CMD}}, bin/verify
> Depends on: docs/testing/test-index.md (what exists), .shipinetics/protected-paths (files that agents cannot change)
> Gotchas: {{e.g. "e2e needs the dev server and seeded DB; run the seed first"}}
> Owner persona: test-integrity | Last verified: {{YYYY-MM-DD}} at {{short commit}}

<!-- Write this file in ASD-STE100 (Simplified Technical English): short sentences, active voice, one word for one thing. Where it describes structure or flow, add a Mermaid diagram and a link to its Whiteboard. Write the diagram's labels by the same rules. Rules: shipinetics:explain. -->

## Which test to write

| Change | Write |
|---|---|
| New user-facing behaviour | An e2e test for each acceptance criterion's main example, written from the criteria after the code. Unit tests for the other cases that the criteria state |
| Bug fix | A criterion that states the correct behaviour (the one the bug broke, or a new one in the worksheet). Then a regression case in the test of the behaviour it broke. It passes on the fix and fails on the code before the fix (test-writer runs it against the base commit). Not a new file named after the fix |
| Pure logic (parsing, calculation, state machines) | Tests of its behaviours through its public interface, with edge cases and invalid input as rows in a table |
| Glue (routes, controllers, wiring) or trivial code | No unit tests. A behaviour test at the entry point covers it |
| A rule for every input (round trip, invariant, idempotency) | A property test with {{property-testing library, e.g. fast-check, Hypothesis, or "none yet"}}. Fix the seed so that a failure repeats |
| Refactor | No new tests. The existing tests must pass with no change. If a test had to change, the change was not a pure refactor |
| Rewrite or migration that must not change behaviour | A differential test: the old and the new code on the same inputs, with a list of the approved differences |
| Existing feature with no tests | `/shipinetics:test-backfill`: criteria from what users see, approved by a human, then the tests |
| Changed behaviour | Change the test of that behaviour in the same task (test-writer `change` mode). Never add a second test beside the old one |
| Removed behaviour or deleted code | Delete its tests, or the cases that cover it, in the same change. Remove its lines from the test index |
| UI appearance | A screenshot test (shipinetics:visual-regression) |
| Performance-sensitive path | A benchmark (shipinetics:perf) |

## Layout and commands

- Unit tests: {{where they live, naming}}. Run one file: `{{single file cmd}}`.
- Fastest targeted run: `{{e.g. pytest --reuse-db -n0 path::test, or vitest run path -t name}}`. Fixed cost of one run: {{e.g. 2s}}. Test-writer uses it for every proof run, so keep the fixed cost low (reuse the test database, skip slow setup the test doesn't need).
- Tests related to a change: `{{e.g. vitest related <files>, jest --findRelatedTests <files>, pytest --testmon}}`. `bin/verify --quick` runs it. When a change touches test config, fixtures, a lockfile or a shared test helper, it runs all unit tests.
- Copies can run at the same time: {{yes, or no and why, e.g. one shared test database}}. Test-writer runs its mutants in parallel only on yes.
- E2E: {{e2e folder}}. Run one: `{{single e2e cmd}}`. Smoke tests are tagged `@smoke` and run in `bin/verify`.
- Acceptance tests from specs live in `e2e/acceptance/` and are protected once written.
- Test data: {{fixtures, factories, seed}}.

## Rules

- **Every test proves an acceptance criterion, and names it.** Put the reference at the start of the test's name, or of its group's name: `refund-rounding AC2` (the spec's slug, or the worksheet's name for a task with no spec, and the criterion's ID). Where test names can't hold free text, put it in a comment on the test. In a file of one spec's tests (`e2e/acceptance/<slug>.spec.ts`), the ID alone is enough. Each case checks what its criterion states. A behaviour that no criterion states gets no test: propose the criterion instead.
- **Test behaviours, not functions.** One test per behaviour a user or caller can observe, through the public entry point, at one layer. Never one test per function, and never on private functions or call counts.
- **One home per behaviour.** Tests live in the module's test file, grouped by behaviour. Extend the existing test before adding one.
- **One test per behaviour, with every assertion it needs.** Several assertions about one behaviour belong in one test. Never split one behaviour into a test for each assertion, and never cover two behaviours in one test. Name the test after its behaviour.
- **Changed or removed behaviour changes its tests in the same task.** When you delete code, delete its tests in the same change. When a behaviour changes, change its test. The suite grows only with new behaviour.
- **Every test must be able to fail.** Before you commit a new test, break the code that it covers and see the test fail. Do this in a scratch worktree of the project, never in the working tree.
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

Update `docs/testing/test-index.md`: one line per behaviour, under its module, naming its criterion and the test that proves it.
