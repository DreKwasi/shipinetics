# Agent feedback
> Summary: Notes from agents at the end of each session: what slowed them down, what was missing or not clear, and what they would change. The feedback ingest uses them to improve docs, skills, tools and linters.
> Owns: nothing in code. Feeds AGENTS.md, docs/, bin/ and lint rules
> Entry points: the newest entries are at the bottom. Ingest markers show which entries were processed
> Depends on: docs/worksheets/ (each entry names its worksheet)
> Gotchas: be specific, and write in ASD-STE100 (short sentences, active voice). "Docs were unclear" is useless. "docs/systems/auth.md does not say that tokens expire after 15 min" is useful
> Owner persona: maintainability | Last verified: {{YYYY-MM-DD}} at {{short commit}}

<!-- Write this file in ASD-STE100 (Simplified Technical English): short sentences, active voice, one word for one thing. Where it describes structure or flow, add a Mermaid diagram and a link to its Whiteboard. Write the diagram's labels by the same rules. Rules: shipinetics:explain. -->

Entry format (append at the bottom, newest last):

```
## YYYY-MM-DD <worksheet-name> (<agent/model>)
- Slowed me down: <specific thing, with file paths>
- Missing: <doc, tool, test, permission that would have helped>
- Wrong or conflicting: <instructions that were wrong or contradicted each other>
- I would change: <concrete suggestion: which file, what edit>
- Time sinks: <where most of the session went>
```

<!-- ingested through: never -->
