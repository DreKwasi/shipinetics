---
name: system-docs
description: Rules for the self-healing system docs in docs/systems/, including the 7-line greppable header, when to create or update a doc, and how to find the right one. Use when you need to understand a system, after changing how a system works, or when you find a doc that's wrong or missing.
---

# Self-healing system docs

> Paths below are Shipinetics's defaults. A project can map them elsewhere in `.shipinetics/config`: run `shipinetics-config` to see this project's actual paths and commands, and use those.

Docs rot because nobody owns updating them. Here, every agent does: whoever changes a system updates its doc in the same change, and whoever finds a wrong doc fixes it.

## Finding the right doc

```bash
head -n 7 docs/systems/*.md          # map of every system
rg -l "billing" docs/systems/        # which docs mention something
rg "^> Owns:.*src/billing" docs/     # which doc owns a path
```

Read the header first. Open the full doc only for systems you'll touch.

## The 7-line header

Every doc in `docs/systems/` starts with exactly these 7 lines (template: `docs/systems/_template.md`):

```
# <System name>
> Summary: <2 or 3 specific sentences>
> Owns: <paths and globs>
> Entry points: <file:function where you start reading>
> Depends on: <systems and external services>
> Gotchas: <what bites people, one line>
> Owner persona: <persona> | Last verified: <YYYY-MM-DD> at <short commit>
```

**A good summary** is specific enough to tell this system apart from every other: "Turns Stripe webhooks into ledger entries. Idempotent by event ID. The only code allowed to write to the ledger table." **A bad summary** could describe anything: "Handles billing functionality."

## When to update

- You changed behavior, data flow, entry points or dependencies of a system: update its doc in the same commit.
- You read a doc and it was wrong: fix it now, note it in your worksheet, and bump `Last verified`.
- You confirmed a doc against the code and it was right: bump `Last verified`.
- You learned a gotcha the hard way: add it to the header's Gotchas line and the Gotchas section.

## When to create

- A folder, service or package with its own responsibility has no doc. Write one from the template, filled from reading the code. A short accurate doc beats a long speculative one.
- Add it to the routing table in `AGENTS.md` if agents would need to find it from there.

## When to split or merge

- A doc over about 300 lines, or a header Summary that needs "and" three times: split by responsibility.
- Two docs that keep needing the same update: merge.

## Facts from outside the codebase

Docs that state external facts (an API's rate limit, a library's behavior in a version, a provider's quota) go stale without anyone touching the code. For each such fact:

- Cite an official primary source inline, with the date you checked it: `(source: <URL>, checked 2026-10-26)`.
- When you change a doc's factual content, get a docs review: `shipinetics:reviewer` with stage `docs`, or `agent_review --stage docs --file <doc>`. It returns a claims table with a verdict for every claim (verified, incorrect, unresolved).
- Fix incorrect claims. Keep unresolved claims visibly marked in the doc (`UNVERIFIED: <what's missing>`) until someone resolves them.

## Where decisions and terms go

One home for each, so they don't drift apart:

| What | Where |
|---|---|
| A domain term and what it means | `GLOSSARY.md`, the glossary: term, one-line definition, words to avoid. No implementation details. A repo with several domains keeps one per domain and lists them in `GLOSSARY-MAP.md` |
| A decision that's hard to reverse, surprising without context, and a real trade-off, across the project | `docs/adr/NNNN-<slug>.md`, 1 to 3 sentences. Link it from the system docs it affects |
| Why one system is built the way it is | That system doc's Key decisions, one line each |
| A choice made during one task | The worksheet's Decisions. Promote it to the system doc or an ADR only if it will matter after the task |

The `domain-modeling` skill writes `GLOSSARY.md` and ADRs in these formats, and `/wait-what` reads the glossary when it re-pitches a message. Use them in code and docs: a name the glossary says to avoid is a review finding.

## Persona ownership

The `Owner persona` field says which review persona (shipinetics:review) checks this doc when its area changes. When that persona reviews a change, it reports docs that went stale. The author fixes them before the task is done.

## Language

Write system docs, ADRs and the glossary in ASD-STE100 (shipinetics:explain): short sentences, active voice, one word for one thing. A doc that's hard to read gets skipped, and then it stops being true.

## Don'ts

- Don't paste code into docs. Link to `file:line`. Code in docs goes stale silently.
- Don't document what the code says clearly. Document why, how the pieces connect, and what bites.
- Don't write docs about plans. Plans go in specs and worksheets. Docs describe what exists.
