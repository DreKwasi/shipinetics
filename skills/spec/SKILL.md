---
name: spec
description: Turn an issue, task or idea into a spec with runnable acceptance criteria, so that the independent test-writer can test the implementation against them. Use at the start of any task size M or larger, when the user runs /shipinetics:spec, or when a queue task lacks clear acceptance criteria.
argument-hint: "<issue URL, task ID or description>"
---

# Spec: intent to acceptance criteria

> Paths below are Shipinetics's defaults. A project can map them elsewhere in `.shipinetics/config`: run `shipinetics-config` to see this project's actual paths and commands, and use those.
>
> Text for people (docs, worksheets, reports, PR bodies, replies): write it in ASD-STE100. Where the text describes structure or flow (a call path, a data flow, states or steps), show it on a Whiteboard. In a committed file, also put a Mermaid diagram and a link to the Whiteboard, because GitHub and other people cannot open your Whiteboard. Without Whiteboard, use Mermaid only. shipinetics:explain has the rules.

Input: `$ARGUMENTS`. Fetch it if it's an issue URL (`gh issue view`) or a task ID (`TODOS.md`).

The human's job is intent and acceptance criteria. Your job is to make those criteria concrete enough that a test can check them. After the implementation, an independent agent writes those tests (shipinetics:testing).

## Steps

1. **Understand.** Read the request, the relevant system docs (`head -n 7 docs/systems/*.md`) and the code involved. List anything ambiguous.
2. **Resolve ambiguity.**
   - **Interactive, size M and up: grill.** If the `grilling` and `domain-modeling` skills are installed, run them together on the request: walk the design tree as `grilling` directs, with your recommended answer for each question, and look in the code instead of asking whenever the code can answer. Sharpen fuzzy terms as they come up. Stop when every branch that changes the acceptance criteria or the approach is decided, and say which branches you left open on purpose. Then write the results straight into the spec without asking again: decisions go in Approach and Out of scope, open technical choices in Open questions, new or sharpened terms in `GLOSSARY.md` (term, one-line definition, words to avoid), and decisions that are hard to reverse, surprising and a real trade-off in `docs/adr/` (1 to 3 sentences each). Without those skills, do the same by hand.
   - **Interactive, S and XS:** ask the user, a few questions at a time, with your recommended answer for each.
   - **Autonomous:** never grill: nobody can answer. If the gap is a product decision, mark the task blocked with the question and stop. If it's a technical detail, decide, and record the decision under Open questions so a human can overrule it.
   - If a question needs a runnable answer (does this interaction feel right, does this state model hold), build a throwaway prototype (the `prototype` skill, interactive only), record what it showed under Approach, and delete it.
3. **Write the spec** to `docs/specs/<slug>.md` using the format below.
4. **Check that each criterion is testable.** Each one names an observable result at an entry point (a screen, a response, a command's output). If a test can't see it, rewrite it. Test-writer writes the acceptance tests after the implementation (shipinetics:workflow, step 5), and they become protected then.
5. **Review.** Get a plan review of the spec (shipinetics:review plan). Interactive: show the user the criteria and get a yes before implementation.
6. **Write the goal line.** Add a `## Goal` section to the spec with a ready-to-paste `/goal` condition built from the acceptance criteria (format below). Interactive: show it to the user and suggest they paste it to run the implementation to completion. Claude can't set a goal itself.
7. Link the spec from the worksheet and the queue task. Link the tests after test-writer writes them (shipinetics:workflow, step 5).

## The goal line

`/goal` makes Claude keep working until a separate evaluator model judges the condition met. The evaluator only sees the conversation, not the files, so every part of the condition must be something Claude's own output can show. It complements `shipinetics-verify`: verify proves the checks pass, the goal proves this task's deliverables exist.

Build it from the acceptance criteria:

- **One measurable end state per criterion**, each with a stated check: "shipinetics:test-writer wrote the AC1 to AC4 tests in `e2e/acceptance/refunds.spec.ts` after the implementation, and they pass, shown by running them".
- **The standing checks:** `shipinetics-verify` exits 0 with its output shown (the complete tier); the implementation review verdict is approve, or every finding has a recorded response in the worksheet.
- **Constraints:** no existing file in `e2e/acceptance/` or any protected path is modified; tests are only changed by shipinetics:test-writer.
- **Deliverables:** the worksheet is updated and the work is committed with the `Worksheet:` trailer.
- **A turn bound:** "If this isn't met after 15 turns, stop and report the blocker." It's judged by the model, so the hard limits stay with the launcher or you.

Example:

```
/goal The refund-rounding spec is implemented, then shipinetics:test-writer wrote the tests: the AC1 to AC4 tests in e2e/acceptance/refunds.spec.ts pass (run them and show the output), shipinetics-verify exits 0 (show the output), the shipinetics:reviewer implementation review is approve or every finding has a response in the worksheet, no existing file under e2e/acceptance/ was modified, and the work is committed with the Worksheet trailer. If this isn't met after 15 turns, stop and report the blocker.
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
