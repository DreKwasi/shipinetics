---
name: test-audit
description: Periodic false-confidence audit that finds tests which don't test what they claim, proves it by breaking the code they cover, and fixes them. Use on a schedule (weekly, or at end of shift on a sample), when the user runs /shipyard:test-audit, or when a bug ships that tests should have caught.
argument-hint: "[path or system to focus on]"
---

# False-confidence test audit

> Paths below are Shipyard's defaults. A project can map them elsewhere in `.shipyard/config`: run `shipyard-config` to see this project's actual paths and commands, and use those.

A passing suite only means something if the tests would fail when the product breaks. This audit checks that, test by test, and fixes the ones that wouldn't.

Focus: `$ARGUMENTS` (if empty, use the selection below).

## Pick what to audit

You won't audit everything in one go. Prioritize, and record the date in the `Audited` column of `docs/testing/test-index.md` so the next audit picks up where this one stopped.

1. Tests for code where a bug recently shipped.
2. Tests added or changed in the last two weeks (`git log --since=2.weeks --name-only -- '*test*' '*spec*'`).
3. Tests for critical paths: auth, payments, data writes, anything in a domain persona's docs.
4. Tests never audited, oldest first.

Aim for 10 to 20 test files per run.

## For each test, check

**Read it** and look for the smells:

- Asserts nothing meaningful: only truthy, defined, no-throw, or status 200 with no body check.
- Mocks the unit under test, or the mock returns exactly what the assertion expects.
- Name promises one behavior, body checks another or less.
- Assertion on an intermediate state (loading spinner) but not the result.
- Swallowed failures: try/catch around assertions, `.catch(() => {})`, conditional assertions that can be skipped.
- Snapshot of a huge blob nobody reads.
- Depends on order, time, randomness or shared state, so it passes by luck.
- Skipped, `.only`, `xfail`, or commented out.
- E2E test that performs actions and never asserts the outcome.

**Then prove it** with a mutation check. This is the part that matters:

1. Find the production line or branch the test claims to cover.
2. Break it on purpose in a scratch change: flip the condition, return early, delete the call, change the constant.
3. Run just that test. It should fail.
4. Restore the code (`git checkout -- <file>`). Confirm the tree is clean.

If the stack has a mutation testing tool (Stryker, mutmut, cargo-mutants, go-mutesting), run it on the selected files instead of doing this by hand. It's faster and more thorough.

## Fix what you find

- **Test survives the mutation:** strengthen the assertion until it fails on the mutation, then passes on the real code.
- **Smell, but the mutation was caught:** fix it if it's cheap, otherwise note it.
- **Test is protected:** don't edit it. Write it up under "Test change requests" in the worksheet with the mutation that survived.
- **Test is worthless and can't be saved:** replace it with one that tests the behavior properly. Never delete without a replacement unless the behavior itself is gone.

Test fixes go through `shipyard:test-writer`: the hook only lets it edit tests. Give it the test, the smell and the mutation that survived, and it strengthens or replaces the test.

Run `bin/verify` after the fixes.

## Prune the bloat

A suite that's too big is slow, noisy, and hides the tests that matter. For each audited file:

1. **Find redundancy.** With a mutation tool, look at which mutants each test kills. Without one, group tests by the behavior they exercise. Any test that kills nothing another test doesn't already kill, and doesn't encode a named requirement, is redundant.
2. **Find tests that test the wrong thing:** framework or library behavior, getters and setters, private functions, call counts on internal collaborators, what the type checker already guarantees.
3. **Merge same-shaped cases** into one table-driven test.
4. Have `shipyard:test-writer` make the cuts and merges, then re-run the mutation check to confirm the suite still catches everything it caught before.
5. Record in the report: tests before, tests after, mutations caught before and after. Fewer tests catching the same mutations is a win.

## Report

Write `docs/test-audits/YYYY-MM-DD.md`:

```
# Test audit YYYY-MM-DD
> Summary: <N files audited, M weak tests found, K fixed>
| Test | Smell | Mutation tried | Survived? | Action |

Bloat: <tests before> to <tests after>. Mutations caught: <before> to <after>.
```

Update `docs/testing/test-index.md` audit dates. If the same smell shows up three or more times, add it to the "Patterns that make tests lie" list in `docs/testing/how-to-write-tests.md`, and consider a lint rule for it (shipyard:lint-rule).
