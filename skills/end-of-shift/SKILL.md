---
name: end-of-shift
description: Full validation at the end of an autonomous shift or a long session, running every check, review and sweep, cleaning up loose ends, and writing an honest shift report so the repo is as clean as possible when the human returns. Use at the end of a night shift, when the user runs /shipyard:end-of-shift, or before handing a branch over for human review.
---

# End-of-shift validation

> Paths below are Shipyard's defaults. A project can map them elsewhere in `.shipyard/config`: run `shipyard-config` to see this project's actual paths and commands, and use those.

The human is about to come back. Leave the repo in a state where they can see, in two minutes, what happened, what's solid and what needs them.

**Honesty rule:** the report says exactly what passed and what didn't. A red check reported as red is fine. A red check hidden or explained away is a broken shift.

**Commits:** end-of-shift work belongs to no single task, so commit it with `SHIPYARD_ALLOW_NO_WORKSHEET=1 git commit ...`. The fix, the metrics and the report each go in their own commit.

## 1. Full checks

Run each and record the result (pass, fail with summary, or not run with reason):

1. `bin/verify --full`: typecheck, lint, all unit and e2e tests, visual regression, benchmarks.
2. If visual tests failed: review the diffs (shipyard:visual-regression) and say which are intended.
3. If benchmarks regressed: re-run to rule out noise, and name the commit if it's real (shipyard:perf).

If something fails and the fix is small and obvious, fix it, with `bin/verify` passing afterwards, in its own commit. Otherwise leave it failing and report it. Don't start new feature work.

## 2. Reviews and sweeps

1. **Wrap-up review of the whole shift:** `agent_review --stage wrapup --base <shift start commit>` plus the `shipyard:reviewer` subagent on a different model. The base is where the night branch started: `git merge-base HEAD main`.
2. **Sweep** today's commits (shipyard:sweep), so cross-task problems surface tonight, not next week.
3. **Light test audit:** run shipyard:test-audit on the tests added or changed during the shift only.
4. **Agent tooling:** if the shift added or changed any skill, agent, hook or MCP config, run `scan-skills` on those paths and report the results.
5. **Verification map:** shipyard:verification-map `light` for the features the shift's tasks touched. Report its outcome (clean, changed or blocked). Product bugs it finds go in the queue.

Fix what's small. Queue the rest.

## 3. Loose ends

- Every worksheet from the shift is either done (summary filled, tagged) or has an exact Next step and is listed as unfinished.
- **Evidence:** `evidence check --branch` passes for the shift branch. Write `docs/shifts/YYYY-MM-DD-pr-body.md` with `evidence pr-body`, so the human can open the PR with it in the morning.
- Every task touched is in the right queue section. Blocked tasks have a one-line question a human can answer fast.
- System docs touched during the shift: headers still accurate.
- No stray files: debug output, temp scripts, screenshots outside where they belong. `git status` is clean.
- Feedback entries exist for the shift's sessions.
- **Metrics:** the launcher's per-run metrics are in `.shipyard/.cache/night-metrics.csv`. Append its rows (without the header, if the file already exists) to `docs/metrics/runs.csv` and commit it. Copy each task's cost, turns and duration into the Metrics block of its worksheet.

## 4. Shift report

Write the report in plain controlled English (shipyard:explain): short sentences, active voice, no hedging. Write `docs/shifts/YYYY-MM-DD.md` and commit it:

```markdown
# Shift YYYY-MM-DD
> Summary: <N tasks done, M blocked, checks: all green | X failing>
> Branch: night/YYYY-MM-DD | Base: <sha> | Head: <sha> | Spend: $<amount> | Duration: <h>
> Stopped because: <time limit | budget | queue empty | agent stop: reason>
> Per task: <cost and turns for each task, from the metrics CSV>

## Needs you (start here)
<Ordered by urgency. Blocked questions, failing checks, test change requests, risky changes that deserve a close look.>

## Done
| Task | Worksheet | Summary | Review verdict | Merge risk |

## Checks
| Check | Result |
|---|---|
| bin/verify --full | |
| Visual | |
| Benchmarks | |
| Wrap-up review | |
| Sweep | |
| Test audit | |

## Not verified
<What you couldn't check and why.>

## Suggested review order
<Highest merge risk first. Which commits or files to read first, and why. Low-risk tasks can be grouped at the end.>
```

Then make it easy to take in:

- **HTML version:** `docs/shifts/YYYY-MM-DD.html`, a single self-contained page built from the same facts: the "Needs you" list first, a timeline of the shift, each task with its diagram, review verdicts and evidence (embed the screenshots, link the recordings), checks as a status grid, and links to every Whiteboard and worksheet (shipyard:explain, "HTML pages"). Commit it with the Markdown report.
- **Whiteboards:** every task done in the shift should already have one. If any is missing, author it now. If Whiteboard is available and the shift had several related tasks, also author one Whiteboard for the whole shift branch against its base.

## 5. Stop

Final message: the report's Summary line and the paths to the Markdown and HTML reports. Never push. The human reviews the branch and decides what to merge.
