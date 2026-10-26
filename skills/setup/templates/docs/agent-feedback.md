# Agent feedback
> Summary: End-of-session notes from agents about what slowed them down, what was missing or confusing, and what they'd change. Appended every session, ingested periodically to improve docs, skills, tools and linters.
> Owns: nothing in code. Feeds AGENTS.md, docs/, bin/ and lint rules
> Entry points: newest entries at the bottom; ingest markers show what's been processed
> Depends on: docs/worksheets/ (each entry names its worksheet)
> Gotchas: be specific. "Docs were unclear" is useless; "docs/systems/auth.md doesn't say tokens expire after 15 min" is useful
> Owner persona: maintainability | Last verified: {{YYYY-MM-DD}} at {{short commit}}

Entry format (append at the bottom, newest last):

```
## YYYY-MM-DD <worksheet-name> (<agent/model>)
- Slowed me down: <specific thing, with file paths>
- Missing: <doc, tool, test, permission that would have helped>
- Wrong or conflicting: <instructions that were wrong or contradicted each other>
- I'd change: <concrete suggestion: which file, what edit>
- Time sinks: <where most of the session went>
```

<!-- ingested through: never -->
