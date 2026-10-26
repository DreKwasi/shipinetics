---
name: feedback
description: Write end-of-session feedback about what slowed the agent down, and periodically ingest that feedback to improve docs, skills, tools and lint rules. Use at the end of every session that changed code, and when the user runs /shipyard:feedback ingest.
argument-hint: "[ingest]"
---

# Agent feedback

Mode: `$ARGUMENTS` (empty means write an entry, `ingest` means process the backlog).

Agents hit the same friction over and over: a missing doc, a confusing instruction, a slow command, a tool that should exist. Feedback captures it while it's fresh. Ingesting turns it into fixes so the next session doesn't hit it.

## Writing an entry (end of every session)

Append to `docs/agent-feedback.md`, at the bottom, in the format the file shows. Commit it with the work.

Be specific and actionable. Name files, commands and minutes lost.

- Bad: "The docs could be clearer."
- Good: "docs/systems/auth.md doesn't mention that session tokens are refreshed by middleware in src/server/session.ts. I spent about 20 minutes assuming the client refreshed them."
- Bad: "Tests are slow."
- Good: "bin/verify takes 6 minutes because the e2e smoke set includes the full checkout flow. Moving checkout out of @smoke would cut it to about 90 seconds."

Include instruction problems too: rules that contradicted each other, rules that didn't fit the situation, steps you skipped and why. If nothing slowed you down, write one line saying so. That's useful signal too.

## Ingesting (interactive, with the user)

Run this with the user every week or two, or when the backlog gets long.

1. Read `docs/agent-feedback.md` from the last `<!-- ingested through: ... -->` marker to the end.
2. **Cluster** entries by root cause, not by wording. Five entries about "couldn't find X" might all be one missing routing line in `AGENTS.md`.
3. **Rank** clusters by how often they occur and how much time they cost.
4. **Propose a fix for each cluster**, pointing at the exact file and change. Prefer fixes in this order, because each is more reliable than the next:
   1. A lint rule or hook (it enforces itself)
   2. A script in `bin/` (it does the work)
   3. A test (it catches the problem)
   4. A doc or skill change (it explains)
   5. An `AGENTS.md` routing line (it points)
5. Show the user the ranked list. Apply the ones they approve. Changes to the plugin itself (skills, reviewer, hooks) go in the plugin repo, not the project: note them as a list the user can take there.
6. **Look at the numbers.** Read the Metrics blocks of worksheets since the last ingest, and `docs/metrics/runs.csv` if night shifts ran. Summarize per accepted task: cost, turns, review rounds, corrections after human review, human review minutes, and the share of tasks accepted. Show the user any trend, and which feedback cluster it might explain. Also compare merge-risk grades with what actually happened: if low-risk tasks keep needing corrections, the grading (or the evidence behind it) can't be trusted yet, and that's worth fixing before anyone reviews less.
7. **Change one thing at a time.** When a fix changes the setup itself (effort level, a skill, a reviewer, a model), say so in the commit and note the date. Compare the next batch of accepted tasks against the previous one on the same metrics before changing anything else. Two changes at once make the numbers unreadable.
8. Move the marker to today's date: `<!-- ingested through: YYYY-MM-DD -->`. Leave old entries in place above it.
9. Commit with a message summarizing what changed and which feedback it addresses.
