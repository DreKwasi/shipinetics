# {{System name}}
> Summary: {{Two or three sentences: what this system does, for whom, and the one thing that makes it different from what you'd guess.}}
> Owns: {{paths and globs, e.g. src/billing/**, db/migrations/*billing*}}
> Entry points: {{the files or functions you start reading from, e.g. src/billing/index.ts:createInvoice}}
> Depends on: {{other systems and external services}}
> Gotchas: {{the things that bite people, in one line, e.g. "amounts are integer cents; webhooks can arrive twice"}}
> Owner persona: {{persona name}} | Last verified: {{YYYY-MM-DD}} at {{short commit}}

<!-- Write this file in ASD-STE100 (Simplified Technical English): short sentences, active voice, one word for one thing. Where it describes structure or flow, add a Mermaid diagram and a link to its Whiteboard. Rules: shipinetics:explain. -->

<!-- The 7 lines above are the greppable summary. `head -n 7 docs/systems/*.md` should give
     a useful map of the whole codebase. Keep them accurate and specific. Update "Last verified"
     whenever you confirm this doc against the code. -->

## How it works

{{Data flow from entry point to result. A short list or a small diagram. Link to code with file:line.}}

## States

<!-- Only if records, sessions or screens in this system move through states. Delete this section if not. Rules: shipinetics:system-docs, "States". -->

{{Where the state lives (field or fields, file:line). The states, one line each, terminal ones marked. The invariants, each with what enforces it.}}

| From | Event | To | Guard (file:line) | Safe to repeat? |
|---|---|---|---|---|

{{A Mermaid stateDiagram-v2 of the table.}}

## Key decisions

{{Why it's built this way, and what was rejected. One line each. Link the worksheet where it was decided, or the ADR in docs/adr/ if it's a project-wide decision.}}

## How to test it

{{Which tests cover it (see docs/testing/test-index.md), how to run just those, and how to exercise it by hand in the running app.}}

## Gotchas in detail

{{Each gotcha from the header, explained, with the commit or worksheet where someone got bitten.}}
