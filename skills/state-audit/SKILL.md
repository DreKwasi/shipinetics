---
name: state-audit
description: Audit of the app's state machines, explicit and implicit. It documents each one's states, invariants and transition table in its system doc, finds the invalid states and transitions that the code can really reach (also through retries and concurrency), with evidence, and queues the confirmed bugs by impact so that each is fixed with a regression test. Use when the user runs /shipinetics:state-audit, when a bug ships that came from a record in an impossible state, a double charge, a stuck job or a race, or when the sweep says a system's States table is missing or stale.
argument-hint: "[system, path or 'all']"
---

# State audit

> Paths below are Shipinetics's defaults. A project can map them elsewhere in `.shipinetics/config`: run `shipinetics-config` to see this project's actual paths and commands, and use those.
>
> Text for people (docs, worksheets, reports, PR descriptions, commit messages, review comments, replies, and each label on a board, diagram or table): write it in ASD-STE100, by the plain-language guide (`${CLAUDE_PLUGIN_ROOT}/skills/explain/plain-language.md`). Where the text describes structure or flow (a call path, a data flow, states or steps), show it on a Whiteboard. In a committed file, also put a Mermaid diagram and a link to the Whiteboard, because GitHub and other people cannot open your Whiteboard. Without Whiteboard, use Mermaid only. shipinetics:explain has the rules.

Per-task review sees the transitions that one diff touches. Nobody sees the whole machine: the states that five tasks added between them, the combination of flags that no code path was meant to produce, the webhook that arrives twice. This audit reads one system at a time, writes its machine down, and then tries to break it.

Focus: `$ARGUMENTS`. If empty, pick as below. The audit itself changes only docs and the queue. Fixes are separate tasks.

## Pick what to audit

One to three systems in a run. A whole app in one run gives a shallow table for each system and no confirmed bug.

1. A system where a state bug recently shipped (a stuck record, a double side effect, a race).
2. Systems that handle money, permissions, or data that can't be rebuilt.
3. Systems with handlers that are retried: webhooks, queue jobs, imports, payments, anything behind an at-least-once delivery.
4. Systems with states and no "States" section in `docs/systems/`, then the ones whose `Last verified` is oldest.

## 1. Find the machines

Explicit ones are easy: `rg -i 'status|state|phase|stage|step'` on the schema, the types and the enums, plus reducers and workflow or state-machine libraries.

Implicit ones need reading. Look for:

- Booleans and nullable timestamps on one record that depend on each other (`is_active`, `deleted_at`, `verified_at`, `locked`).
- State that is derived, not stored: "expired" means `expires_at < now`, "complete" means every child row is done.
- State split over two stores: a row in the database and an object at a provider, a cache and its source, a server record and a client store.
- Flows where order matters and nothing records it: a wizard, an onboarding, a multi-call API protocol, a migration that runs in phases.

List each machine with the field or fields that hold it. Ask the user, if they are there, which ones matter most.

## 2. Write each machine down

In the system's doc, in the "States" section (format in shipinetics:system-docs): where the state lives, the states, the invariants with what enforces each one, the transition table with a guard for each row, and a `stateDiagram-v2`.

Build the table from the code, not from names or from what seems sensible:

- Find **every** write to the state: `rg` for the field, the setter, the ORM update, raw SQL, migrations, admin tools, scripts, seeds, and jobs. Each write is one or more rows. A write with no check of the current state is a row from "any".
- For each row, record the guard as `file:line`, or "none".
- For each invariant, find what enforces it. "Every caller is careful" counts as "nothing".

Spawn `shipinetics:reviewer` with stage `docs` on the section. Its claims table checks each row against the code. Fix what it finds before you go on: a wrong table gives wrong bugs.

## 3. Find the invalid states that the code can reach

With the table in front of you, go through these for each machine. Each one that holds is a **candidate**.

| Question | What to look for |
|---|---|
| Is every pair of (state, event) handled? | An event that arrives in a state with no row: is it rejected, ignored, or does it write anyway? |
| Does each write check the state it starts from? | Rows from "any". Check-then-write with no lock, no transaction and no conditional update. |
| What does a second delivery do? | Call each retried handler twice in your head: the same webhook, the same job, a double click. Which side effects repeat? |
| What does a retry after a partial failure do? | Stop the handler after each external call or write in turn. Which state is the record in, and does the retry start from there? |
| What do two actors at once do? | Two requests on one record. A request and a background job. Cancel against complete. Expiry against use. Write down the interleaving. |
| Do related fields change together? | Fields from one invariant written in separate statements, or in separate stores, with no transaction and no reconcile job. |
| Can a terminal state be left? Can every other state be left? | Writes that match a terminal state. States with no outgoing row when the worker or the user goes away. |
| Does every entry point enforce the invariant? | The API when the UI is what checks. Admin tools, imports, migrations and scripts that write the field directly. |
| Does old code and old data know the new states? | Branches and queries written before a state was added. Rows and queued jobs that hold a value the code no longer writes. |

## 4. Confirm each candidate

A candidate is not a bug yet. Each one ends in one of three grades:

- **Reproduced.** Something puts a real record in the invalid state. Use what the project already has: a script in a scratch copy under `$TMPDIR` that calls the entry point twice or with the calls interleaved, a query on a development database that counts rows which break the invariant, or the running app (`docs/verification/README.md`). Never production data, and never the working tree. For a race, don't wait for luck: force the order with the seam that the code already has (a transaction held open, a lock, a fake clock, a job run by hand between two steps).
- **Reachable by trace.** You couldn't run it, but the path is complete: entry point, each step as `file:line`, the order of events, and the reason that no guard stops it (you looked for the constraint, the lock, the unique index and the isolation level, and say where).
- **Closed.** A guard stops it. Record the guard in the table's Guard column and drop the candidate.

Anything else ("this might race") is not in the report.

A count of existing rows that break an invariant is the strongest evidence there is. If the project has a read path for it that is safe and that the user allows, ask them to run the query and give you the number. Don't read production yourself.

## 5. Prioritise and queue

Order the confirmed bugs by impact: data lost or corrupted, money moved twice, a permission check skipped. Then stuck records that need a manual fix. Then wrong screens. Within one level, reproduced before reachable by trace, and paths that any user can hit before paths that need two rare events.

Group bugs that one fix closes (one missing conditional update behind three symptoms, one handler with no idempotency key). Each group is one queue task (shipinetics:task-queue) with: the invariant that breaks, the evidence and its grade, the proposed guard, and the records already in the invalid state, if any, because the fix needs a repair step for them. Mark each bug's row in the transition table with "BUG: T-NNN".

Stop here unless the user asked you to fix them too.

## 6. Fix, one task for each group

Each fix is a normal task (shipinetics:workflow), with nothing skipped:

1. **The invariant becomes an acceptance criterion** in the task's spec or worksheet: "AC1: Given an order that is `refunded`, when a capture webhook arrives, then the order stays `refunded` and no capture is recorded." Test-writer tests only what a criterion states, so without this there is no regression test.
2. **Fix it at the lowest place that every writer passes through:** a database constraint, a conditional update, a transaction, an idempotency key. A check in one caller leaves the other entry points open.
3. **`shipinetics:test-writer` in `regression` mode** writes the test from the criterion and the repro. It must fail on the code before the fix. A test of a race forces the order of events, and never sleeps or repeats until it fails.
4. **Repair the records** that are already invalid, if there are any, as its own step with its own evidence.
5. **Update the States table in the same commit:** the new guard in the row, the "BUG" mark removed, the invariant's "enforced by" filled in. Bump `Last verified`.
6. Review with the `state-integrity` persona.

## Report

Write `docs/state-audits/YYYY-MM-DD.md`. It is the one place that lists every machine, with a link to each table:

```
# State audit YYYY-MM-DD
> Summary: <N systems, M machines documented, K bugs confirmed (R reproduced, T by trace), tasks queued>

## Machines
| System | Machine | State lives in | States | Table |
|---|---|---|---|---|
| orders | order lifecycle | orders.status | 6 | docs/systems/orders.md#states |

## Confirmed bugs, by impact
| # | Machine | Invalid state or transition | How it is reached | Grade | Evidence | Task |

## Closed candidates
| Machine | Candidate | Guard that stops it |

## Not audited
<Systems and machines left for the next run, and why.>
```

Bump `Last verified` in each system doc that you checked.
