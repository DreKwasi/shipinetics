---
name: spec
description: Turn an issue, task or idea into a spec with runnable acceptance criteria, then have the independent test-writer produce failing acceptance tests before any implementation. Use at the start of any task size M or larger, when the user runs /shipyard:spec, or when a queue task lacks clear acceptance criteria.
argument-hint: "<issue URL, task ID or description>"
---

# Spec: intent to acceptance criteria

Input: `$ARGUMENTS`. Fetch it if it's an issue URL (`gh issue view`) or a task ID (`TODOS.md`).

The human's job is intent and acceptance criteria. Your job is to make those criteria concrete enough that a test can check them, and to get those tests written, by an independent agent, before anyone writes the code.

## Steps

1. **Understand.** Read the request, the relevant system docs (`head -n 7 docs/systems/*.md`) and the code involved. List anything ambiguous.
2. **Resolve ambiguity.** Interactive: ask the user, a few questions at a time, with your recommended answer for each. Autonomous: if the gap is a product decision, mark the task blocked with the question and stop. If it's a technical detail, decide, and record the decision under Open questions so a human can overrule it.
3. **Write the spec** to `docs/specs/<slug>.md` using the format below.
4. **Have the acceptance tests written independently.** Spawn the `shipyard:test-writer` subagent in `acceptance` mode with the spec path. You don't write them yourself: the hook won't let you, and tests written by the implementer share its blind spots. Test-writer writes `e2e/acceptance/<slug>.spec.ts` (or the stack's equivalent), one test per criterion named after it, and confirms they fail now for the right reason. Read its report: a criterion it couldn't test usually means the criterion isn't observable yet. Fix the spec and ask again.
5. **They're protected now.** Files in `e2e/acceptance/` are in `.shipyard/protected-paths` by default. If the tests live elsewhere, add their paths. From here on, no agent can modify them without a human unlocking it.
6. **Review.** Get a plan review of the spec (shipyard:review plan). Interactive: show the user the criteria and get a yes before implementation.
7. **Write the goal line.** Add a `## Goal` section to the spec with a ready-to-paste `/goal` condition built from the acceptance criteria (format below). Interactive: show it to the user and suggest they paste it to run the implementation to completion. Claude can't set a goal itself.
8. Link the spec and tests from the worksheet and the queue task.

## The goal line

`/goal` makes Claude keep working until a separate evaluator model judges the condition met. The evaluator only sees the conversation, not the files, so every part of the condition must be something Claude's own output can show. It complements the Stop hook: the hook proves `bin/verify` passes, the goal proves this task's deliverables exist.

Build it from the acceptance criteria:

- **One measurable end state per criterion**, each with a stated check: "the AC1 to AC4 tests in `e2e/acceptance/refunds.spec.ts` pass, shown by running them".
- **The standing checks:** `bin/verify` exits 0 with its output shown; the implementation review verdict is approve, or every finding has a recorded response in the worksheet.
- **Constraints:** no file in `e2e/acceptance/` or any protected path is modified; tests are only changed by shipyard:test-writer.
- **Deliverables:** the worksheet is updated and the work is committed with the `Worksheet:` trailer.
- **A turn bound:** "If this isn't met after 15 turns, stop and report the blocker." It's judged by the model, so the hard limits stay with the launcher or you.

Example:

```
/goal The refund-rounding spec is implemented: the AC1 to AC4 tests in e2e/acceptance/refunds.spec.ts pass (run them and show the output), bin/verify exits 0 (show the output), the shipyard:reviewer implementation review is approve or every finding has a response in the worksheet, no file under e2e/acceptance/ was modified, and the work is committed with the Worksheet trailer. If this isn't met after 15 turns, stop and report the blocker.
```

Keep it under 4,000 characters.

## Spec format

```markdown
# <Feature name>
> Summary: <one or two sentences on what changes for the user>
> Task: <T-ID or issue link> | Worksheet: <name> | Status: draft, approved, done

## Problem
<What's wrong or missing today, for whom. Evidence if any.>

## Acceptance criteria
Each one is observable from outside the code and maps to one test.

- AC1: Given <state>, when <action>, then <observable result>. Test: `e2e/acceptance/<slug>.spec.ts` "AC1 ..."
- AC2: ...

## Out of scope
<What this deliberately doesn't do. Stops scope creep and tells the reviewer what not to ask for.>

## Approach
<A few lines: which systems change and how. Enough for a plan review, not a design doc.>

## Risks and edge cases
<Data migration, permissions, concurrency, empty and error states, performance.>

## Open questions
<Decisions made without the human, so they can overrule them.>

## Claims
<Every factual claim the approach relies on that isn't obvious from the code: external API behavior, limits, versions. One row each.>
| # | Claim | Evidence (file:line or URL) | Checked | Verdict |

## Goal
<The ready-to-paste /goal line. See below.>
```

## What makes a good criterion

- **Observable:** "the invoice shows the total including tax", not "tax is calculated correctly".
- **Specific:** real values. "Given a cart with two items at $10 and 8% tax, the total shows $21.60."
- **Includes the unhappy path:** at least one criterion for invalid input, an empty state or a failure.
- **No implementation detail:** criteria survive a rewrite of the code.
