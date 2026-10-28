# Project tools
> Summary: Index of scripts in bin/ (and tools/ if present) that agents and humans use to work on this repo, with one line each on what they do. Check here before writing a one-off command sequence.
> Owns: bin/*, tools/*
> Entry points: run any tool with --help
> Depends on: plugin tools on PATH: worksheet, shipinetics-verify, shipinetics-companions
> Gotchas: a tool that isn't listed here won't be found. Add the line when you add the tool
> Owner persona: maintainability | Last verified: {{YYYY-MM-DD}} at {{short commit}}

<!-- Write this file in ASD-STE100 (Simplified Technical English): short sentences, active voice, one word for one thing. Where it describes structure or flow, add a Mermaid diagram and a link to its Whiteboard. Rules: shipinetics:explain. -->

| Tool | What it does | Example |
|---|---|---|
| `bin/verify` | Definition of done. Fast checks, or everything with `--full` | `bin/verify --full` |
| `bin/lint-fix` | Fix lint problems with linter autofix, then an LLM for the rest | `bin/lint-fix src/foo.ts` |
| `bin/llm-fix` | Have a cheaper model fix lint problems in one file | used by lint-fix |
| `worksheet` (plugin) | Create, resume, list and tag worksheets | `worksheet new fix-login` |
