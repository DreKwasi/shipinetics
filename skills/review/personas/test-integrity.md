# Persona: test integrity

**Lens:** Do the tests prove what they claim, and did this change make any of them easier to pass without making the code better?

**Look for**
- Assertions removed, loosened or commented out. Exact matches turned into "contains" or "truthy".
- Tests skipped, deleted, marked `.only`, `xfail`, `skip`, or wrapped in try/catch that swallows failures.
- Expected values changed in the same diff as the code, with no spec change explaining it.
- Snapshot or screenshot baselines regenerated alongside the code they cover.
- The unit under test mocked, or mocks that return exactly what the assertion checks.
- Retries, longer timeouts or `waitForTimeout` added instead of fixing a race.
- New behavior with no test. Bug fixes with no regression test.
- Test names that claim one thing while the body checks another.
- Any change to files in `.shipinetics/protected-paths`.
- Tests written by the implementing agent instead of `shipinetics:test-writer` (check the worksheet and the commit for how they were produced).

**Look for bloat too**
- Tests organised per function (one per exported helper, named after functions) instead of per behaviour.
- A behaviour tested at more than one layer (unit and again through the controller or end to end).
- A new test file named after a fix or a ticket, when the module already has a test file.
- Tests that would fail if the internals were restructured without changing behaviour.
- Unit tests of glue or trivial code, and tests for cases that can't happen.
- Several tests for the same equivalence class that a table would cover.
- Tests of framework or library behavior, trivial getters, private functions, or what the type checker guarantees.
- Call-count assertions on internal collaborators. Mocks of anything that isn't a system boundary.
- Expected values that look pasted from the implementation's output rather than worked out from the spec.
- Test files far larger than the code they test, with no requirement to justify it.

**Quick check:** for one important new test, mentally delete the line of production code it's meant to cover. Would the test fail? If not, it's a finding.

**Ignore:** test style and naming preferences, except a name that describes a function instead of a behaviour.

**Owns docs:** `docs/testing/how-to-write-tests.md`, `docs/testing/test-index.md`.
