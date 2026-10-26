---
name: night-shift
description: Orchestration rules for unattended autonomous work. Each run takes exactly one task from the queue through the full workflow with no human available, inside the guardrails the night-shift launcher sets. Use when running under the night-shift launcher, or when the user asks you to work autonomously through the queue.
---

# Night shift

You're working with nobody watching. The `night-shift` launcher runs you once per task, each time with a fresh context, a spend cap and a turn cap, in a worktree on branch `night/<date>`, with Bash sandboxed and pushes denied. Your job in this run: **finish exactly one task properly, or leave it in a state the next agent or a human can act on, then stop.**

The user would rather come back to two tasks done right and one clearly blocked than five done badly.

## Guardrails (the launcher enforces these, you respect them anyway)

- **Never** push, merge, deploy, publish, change CI config, delete data, rewrite git history, or switch away from the night branch.
- **Never** try to see a secret. Run anything that needs secrets through `bin/with-secrets`. If a task needs a new secret, it's blocked until a human creates it in the vault (shipyard:secrets).
- **Never** write tests yourself. Spawn `shipyard:test-writer` (shipyard:testing). The hook enforces it.
- **Never** modify protected files (`.shipyard/protected-paths`). Test change requests go in the worksheet.
- **Never** upgrade a dependency's major version, add a new dependency, or change the database schema unless the task explicitly asks for it.
- **Never** weaken a check to get green. If `bin/verify` can't pass, the task is blocked, not done.
- **Stay in scope.** Work you notice outside the task goes in the queue, not in this run.
- If the sandbox blocks something the task really needs (a network host, a path), don't look for a way around it. Mark the task blocked and say what's needed.

## One run

### 1. Preflight

- Confirm you're on a `night/` branch: `git branch --show-current`. If not, reply `SHIFT_STOP: not on a night branch` and stop.
- `git status` is clean, or the only changes are a previous run's unfinished task (check In progress in the queue and its worksheet).
- Run `bin/verify`. If it fails on a clean tree and the failure isn't from an in-progress task, fixing it **is** your task this run: create a P0 queue item for it and work it. If you can't fix it, reply `SHIFT_STOP: verify fails on the base` with the details, because every later run would hit the same wall.

### 2. Pick

- Is there a task In progress with a worksheet whose last log entry is from tonight? Then a previous run died or hit its cap. Resume it (shipyard:worksheet, "Resuming") unless its worksheet says it's blocked.
- Otherwise, take the top Ready task (shipyard:task-queue) and claim it with a commit.
- No Ready tasks: reply `QUEUE_EMPTY` and stop.

### 3. Work it

Follow the full loop in shipyard:workflow. In particular:

- Spec with runnable criteria, and acceptance tests that fail first, for anything above XS.
- No human to answer questions. If a product decision is needed, mark the task Blocked with a one-line question, commit, and stop. Don't guess on product decisions. Do decide technical details, and record them under Decisions.
- Run the app and check the feature works, then record the evidence (shipyard:evidence) and run `evidence check`. A task without complete evidence isn't done.
- Plan review and implementation review with a different model (shipyard:review), including the security and UI reviewers when the change calls for them. Address every finding. For night shift, also get a wrap-up review.
- Author a Whiteboard of the task's change for the human, if Whiteboard is available (shipyard:review, "Whiteboard for the human"). Link it in the worksheet.
- Get the task's merge-risk grade from `shipyard:reviewer` (stage `merge-risk`) and record it in the worksheet's Metrics.
- Keep the worksheet current after every step. You may hit your turn or budget cap at any moment, and the next run resumes from the worksheet alone.

### 4. Budget sense

You have a spend cap and a turn cap you can't see. Work as if each step might be your last:

- Commit working increments as you go, not one big commit at the end.
- If you've spent a long time on one problem (same failure three times, or about a third of a typical task's effort with no progress), stop digging. Write what you tried, mark the task Blocked with what you'd try next, commit, and stop.

### 5. Finish

- `bin/verify` passes.
- Commits have the `Worksheet:` trailer. Worksheet summary filled in, status done, `worksheet tag`.
- Queue updated: task in Done, follow-ups added to Ready.
- Feedback entry appended (shipyard:feedback).
- Final reply: one line the launcher can read: `DONE T-012 2026-10-25-refund-rounding` or `BLOCKED T-012 2026-10-25-refund-rounding: <the question>`. Each run is a `/goal` whose evaluator checks for exactly this, plus the evidence in the conversation (verify output, commit, tag), so show that evidence as you go.

## Stop signals

Reply with one of these as your final message when it applies. The launcher acts on them.

- `QUEUE_EMPTY`: no Ready tasks.
- `SHIFT_STOP: <reason>`: something needs a human before any more work makes sense (base is broken, environment is wrong, repeated sandbox blocks).

## Running without the launcher

If the user asks you to work through the queue in an interactive session, follow the same rules, one task at a time, and check in with the user between tasks unless they've said not to. You won't have the launcher's spend cap, so tell the user how many tasks you plan to take before you start.
