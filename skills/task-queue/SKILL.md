---
name: task-queue
description: Rules for reading, claiming, updating and adding to the project's task queue (TODOS.md by default, or Linear through its CLI). Use when picking the next task, when finishing or blocking one, or when you discover work outside your current task.
---

# The task queue

> Paths below are Shipinetics's defaults. A project can map them elsewhere in `.shipinetics/config`: run `shipinetics-config` to see this project's actual paths and commands, and use those.
>
> Text for people (docs, worksheets, reports, PR descriptions, commit messages, review comments, replies, and each label on a board, diagram or table): write it in ASD-STE100, by the plain-language guide (`${CLAUDE_PLUGIN_ROOT}/skills/explain/plain-language.md`). Where the text describes structure or flow (a call path, a data flow, states or steps), show it on a Whiteboard. In a committed file, also put a Mermaid diagram and a link to the Whiteboard, because GitHub and other people cannot open your Whiteboard. Without Whiteboard, use Mermaid only. shipinetics:explain has the rules.

The queue is where work waits. `TODOS.md` by default. If `AGENTS.md` says the source of truth is somewhere else (Linear, GitHub issues), use that system's CLI with the same rules and states.

## States

| Section | Meaning |
|---|---|
| **Ready** | Has acceptance criteria, is small enough (S or M), and has no open product questions: for M tasks, its design was grilled with a human or the spec already answers the questions. Nothing it's `Blocked-by` is unfinished. Any agent can take it. Top is highest priority |
| **In progress** | Claimed. Has a worksheet name |
| **Blocked** | Can't continue without something (usually a human decision). States exactly what's needed |
| **Done** | Finished, with the worksheet name for traceability. Trim this section when it gets long: git has the history |

## Picking a task

1. Take the top item in Ready. Skip any that's L size (split it first, see below), whose `Blocked-by` tasks aren't Done, or that touches files another In progress task is changing.
2. Claim it: move it to In progress, add `Worksheet: <name>`, and commit just that change (`git commit -m "Claim T-012" -m "Worksheet: <name>"`). The commit is what stops two agents taking the same task on one machine. When other people or machines share the queue, make the claim on the default branch: pull, commit the claim, and push it before you start (in a worktree, `git push origin HEAD:<default branch>` from a branch that has only the claim commit on top of the default branch). If the push is refused as "non-fast-forward" or "fetch first", someone else changed the queue: pull, check that the task is still free, and claim again. If it is refused for another reason (a protected branch, a required review), don't try again: the team needs another place for claims, such as its issue tracker. Ask the user, and until then claim the task in your own branch only.
3. If it lacks runnable acceptance criteria, write them (shipinetics:spec) before starting. If you can't without a product decision, move it to Blocked with the question.

## Finishing

- **Done:** move it to Done with the worksheet name, in the same commit as the work or the wrap-up commit.
- **Blocked:** move it to Blocked. Write what's needed in one line a human can answer quickly: "Should refunds over $500 need manager approval? (yes/no)". Put the details in the worksheet.
- **Partly done:** leave it In progress with the worksheet's Next step current, or split the remaining work into a new Ready task.

## Adding tasks

When you find work outside your current task (a bug, a missing test, a refactor that would help), don't do it now unless it blocks you. Add it:

```
- [ ] T-NNN <title> | size: S | priority: P2
  Acceptance: <runnable criteria>
  Context: found while working on <worksheet>; <file:line>
  Blocked-by: T-NNN (only if it can't start before another task is Done)
  Touches: <the paths or areas it will change> (optional. It lets agents check the rule in "Picking a task")
  Interface: <a function, type or endpoint that other tasks rely on> (optional, for split tasks)
```

Use the next free ID (`grep -o 'T-[0-9]*' TODOS.md | sort -t- -k2 -n | tail -1`). When the queue is shared, take the ID on the default branch the same way as a claim (pull, commit, push), so two people never take the same ID. New tasks go at the bottom of Ready unless they're urgent: a broken build or a security problem goes at the top with P0.

## Splitting L tasks

An L task gets broken into S and M tasks that each leave the product working, each with its own acceptance criteria. This is where the hard questions get answered, so agents only ever pick up work a human already shaped.

1. **Grill first** (interactive): run `grilling` with `domain-modeling` on the whole L task, as in shipinetics:spec step 2. Record terms in `GLOSSARY.md` and hard-to-reverse decisions in `docs/adr/`.
2. **Cut vertical slices.** Each task cuts through every layer it needs (data, logic, API, UI) and delivers one thing a user or caller can see working, a tracer bullet, not a layer ("all the models", "all the endpoints"). Each one is small enough for one agent to finish in one fresh context. If the code needs reshaping first, that's its own task at the front, a prefactor that changes no behavior.
   - **A wide mechanical change** (a rename or a type change used across the whole code) can't be a vertical slice, because one edit breaks every caller. Split it as expand, migrate, contract: first add the new form next to the old one, then move the callers in batches (one task each, by package or folder), then delete the old form in a last task that waits for every batch. The build stays green between tasks.
3. **Mark dependencies** with `Blocked-by:`. Keep them few: slices that can run in any order are better. The tasks that can start now are the ones whose `Blocked-by` tasks are all Done.
4. **Check the split with the human** (interactive): are the slices the right size, in the right order, and is anything missing? Autonomous: you can split, but put the split in Blocked for a human to confirm before any piece goes to Ready.
5. Replace the L item with the pieces, in order, and link them to each other in Context. Keep the L task's end-to-end criteria as the last piece, with `Blocked-by:` on all the others: it drives the whole flow through the verification map once every slice is Done. Otherwise nothing checks that the slices work together.

## Linear or another tracker

If the project uses Linear: map Ready to the team's "Todo" (or a "Ready for agent" label), In progress to "In Progress", Blocked to "Blocked" or a label, Done to "Done". Claim by assigning and moving the issue. Put the worksheet name in a comment. Build a small `bin/tasks` wrapper (shipinetics:workflow, step 9) so agents run `bin/tasks next`, `bin/tasks claim <id>` and `bin/tasks done <id>` without knowing the API.
