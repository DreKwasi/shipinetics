# {{TITLE}}
> Summary: <fill in when done: what was achieved, in one or two sentences>
> Status: in progress | Task: <T-ID or issue> | Spec: <docs/specs/... or none>
> Started: {{DATE}} | Branch: {{BRANCH}} | Base: {{BASE}}
> Agent: <harness and model, e.g. Claude Code / Opus>
> Tag: ws/{{NAME}} (applied at wrap-up) | Commits: git log --grep "Worksheet: {{NAME}}"
> Next step: <the exact next action, always current, so anyone can pick this up>

## Goal and acceptance criteria

<What done means. Copy from the spec or task, or write them if it's a small task.>

- [ ] AC1:
- [ ] AC2:

## Research

<How the code works today, what has to change, what surprised you. Fill in for size M and up.>

### Claims

<Every factual claim the plan relies on. Evidence is file:line for the codebase, or an official
primary source URL for anything external. Verdict: verified, incorrect (with the correction) or
unresolved (with the missing evidence). An unresolved claim the plan depends on is a blocker.>

| # | Claim | Evidence | Checked | Verdict |
|---|---|---|---|---|

## Plan

- [ ] 1.
- [ ] 2.

## Log

<Newest at the bottom. One entry per meaningful step: what you did, what happened, evidence.
Write it so another agent could take over from the last entry.>

- HH:MM Started. bin/verify on base: <pass | fail: what>.

## Decisions

<Each choice that someone might question later, with the reason. One line each.>

## Verified

<What you actually checked and how: commands run, screens clicked through, screenshots taken.
Evidence: docs/evidence/{{NAME}}/EVIDENCE.md (shipinetics:evidence). Also what you didn't verify, and why.>

## Reviews

| Stage | Reviewer | Verdict | Findings and responses |
|---|---|---|---|

## Test change requests

<Protected tests or baselines you believe are wrong, with your reasoning, and the proposed version's path under .shipinetics/pending/ if you wrote one. A human decides and applies it with shipinetics-config apply.>

## Design-system change requests

<Changes to DESIGN.md or the design tokens you think the project needs: a value that should become
a token, a missing component state, near-duplicate tokens, a gap the UI reviewer found. One row
each, with the evidence. Until a human approves, the change uses existing tokens. A human decides.>

| # | Proposed change | Why (evidence) | Status |
|---|---|---|---|

## Blockers

<Anything stopping progress, what you tried, and what's needed to unblock it.>

## Metrics

<Fill in at wrap-up. Leave a cell blank rather than guess. The night shift launcher records cost,
turns and duration in .shipinetics/.cache/night/<date>/metrics.csv. In an interactive session the human
can read cost from /usage.>

| Metric | Value |
|---|---|
| Model and effort | |
| Plugin version | |
| Cost (USD) | |
| Turns | |
| Wall time | |
| Merge risk (low, medium, high) | |
| Review rounds | |
| Findings: fixed / disagreed / deferred | |
| Suspected bugs found by test-writer | |
| Corrections needed after human review | |
| Human review minutes | |
| Accepted (yes, partly, no) | |

## Follow-ups

<Work discovered but not done. Each one also goes in the task queue with its ID here.>
