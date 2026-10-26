---
name: worksheet
description: Keep a session worksheet that records what the agent is doing so another agent can finish the job, commit it with the work, and tag it for later lookup. Use at the start of every task, when resuming someone else's work, and at wrap-up.
---

# Worksheets

> Paths below are Shipyard's defaults. A project can map them elsewhere in `.shipyard/config`: run `shipyard-config` to see this project's actual paths and commands, and use those.

A worksheet is the trace of one task: goal, plan, what happened, what was decided, what's verified, what's next. It's committed with the work and tagged, so months later you can find out why the code is the way it is. If an agent dies halfway through, another agent picks up the worksheet and finishes.

## Commands

`worksheet` is on your PATH (from the plugin):

```bash
worksheet new <slug> "<Title>"   # creates docs/worksheets/YYYY-MM-DD-<slug>.md and makes it current
worksheet use <name>             # resume an existing one
worksheet current                # path of the current one
worksheet list                   # all worksheets with their summaries
worksheet tag                    # tag HEAD as ws/<name> at wrap-up
```

The template is `docs/worksheets/_template.md` if the project has one, otherwise the plugin's.

## The handoff test

At every point, the worksheet should pass this test: **could a different agent, with no other context, read it plus the commits and finish the task?** That means:

- The `Next step` line in the header is always current and specific: "Run the failing test in e2e/acceptance/refunds.spec.ts AC2 and fix the missing currency conversion in src/refunds/calc.ts", not "keep going".
- The log says what you tried that didn't work, so nobody tries it again.
- Decisions have reasons.

## When to write

- **Start:** goal, criteria, plan, and the result of `bin/verify` on the base.
- **After each meaningful step:** a log line. Meaningful means you learned something, changed direction, finished a plan item, or hit a problem. Don't log every command.
- **When you decide something:** a line in Decisions.
- **When you verify something:** what and how, in Verified.
- **After each review:** the verdict and your response to every finding.
- **During research:** every factual claim the plan relies on goes in the Claims table with its evidence and verdict. See shipyard:workflow, step 2.
- **Wrap-up:** fill in Summary, set Status to done (or handed off), make sure Next step says either "none" or exactly what's left, and fill in Metrics.

## Metrics: measure on accepted work

The Metrics block is how the user finds out whether a change to the setup (a new skill, a different effort level, another reviewer) actually helps. A cheap run that needed an hour of human fixes isn't cheap. So the numbers that matter are per accepted task, including review rounds and human corrections.

- Fill in what you know: model and effort (from the session), plugin version (from `.claude-plugin/plugin.json` in the plugin, or "unknown"), review rounds, finding dispositions, test-writer's suspected bugs.
- Cost, turns and wall time: in a night shift, copy them from the run's row in the metrics CSV. Interactive: leave them blank, the user can fill them in from `/usage`.
- Leave "Corrections needed after human review", "Human review minutes" and "Accepted" for the human. Never fill those in yourself.

## Linking to git

- Every commit made under a worksheet gets a trailer as the last line of its message:

  ```
  Fix refund rounding for JPY

  Refunds in zero-decimal currencies were divided by 100 twice.

  Worksheet: 2026-10-25-refund-rounding
  ```

- At wrap-up, commit the finished worksheet, then `worksheet tag`. The tag `ws/<name>` points at the final commit and its message holds the worksheet header.
- Later: `git show ws/<name>` for the summary, `git log --grep "Worksheet: <name>"` for every commit, `git tag -l 'ws/*'` for all of them. Tags are local until pushed. Push them with the branch (`git push --follow-tags` or `git push origin ws/<name>`) when the user pushes.

## Resuming someone else's worksheet

1. `worksheet use <name>`, then read the whole thing.
2. `git log --grep "Worksheet: <name>"` and look at the diffs.
3. Check the branch and working tree match what the worksheet says. If they don't, the log is wrong or work was lost: write that down first.
4. Run `bin/verify` to see the real state.
5. Add a log line: "Resumed by <agent> at <time>. State: <what you found>." Then continue from Next step.
