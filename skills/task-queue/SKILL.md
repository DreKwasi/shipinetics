---
name: task-queue
description: Rules for reading, claiming, updating and adding to the project's task queue (TODOS.md by default, or Linear through its CLI). Use when picking the next task, when finishing or blocking one, when you discover work outside your current task, or during night shift.
---

# The task queue

> Paths below are Shipyard's defaults. A project can map them elsewhere in `.shipyard/config`: run `shipyard-config` to see this project's actual paths and commands, and use those.

The queue is where work waits. `TODOS.md` by default. If `AGENTS.md` says the source of truth is somewhere else (Linear, GitHub issues), use that system's CLI with the same rules and states.

## States

| Section | Meaning |
|---|---|
| **Ready** | Has acceptance criteria and is small enough (S or M). Any agent can take it. Top is highest priority |
| **In progress** | Claimed. Has a worksheet name |
| **Blocked** | Can't continue without something (usually a human decision). States exactly what's needed |
| **Done** | Finished, with the worksheet name for traceability. Trim this section when it gets long: git has the history |

## Picking a task

1. Take the top item in Ready. Skip any that's L size (split it first, see below) or that touches files another In progress task is changing.
2. Claim it: move it to In progress, add `Worksheet: <name>`, and commit just that change (`git commit -m "Claim T-012" -m "Worksheet: <name>"`). In night shift this matters: the commit is what stops two runs taking the same task.
3. If it lacks runnable acceptance criteria, write them (shipyard:spec) before starting. If you can't without a product decision, move it to Blocked with the question.

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
```

Use the next free ID (`grep -o 'T-[0-9]*' TODOS.md | sort -t- -k2 -n | tail -1`). New tasks go at the bottom of Ready unless they're urgent: a broken build or a security problem goes at the top with P0.

## Splitting L tasks

An L task gets broken into S and M tasks that each leave the product working, each with its own acceptance criteria. Replace the L item with the pieces, in order, and link them to each other in Context.

## Linear or another tracker

If the project uses Linear: map Ready to the team's "Todo" (or a "Ready for agent" label), In progress to "In Progress", Blocked to "Blocked" or a label, Done to "Done". Claim by assigning and moving the issue. Put the worksheet name in a comment. Build a small `bin/tasks` wrapper (shipyard:build-tool) so agents run `bin/tasks next`, `bin/tasks claim <id>` and `bin/tasks done <id>` without knowing the API.
