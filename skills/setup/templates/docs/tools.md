# Project tools
> Summary: The scripts in bin/ (and tools/, if it exists), with one line on what each one does. Agents and people use them to work on this repo. Look here before you write a sequence of commands.
> Owns: bin/*, tools/*
> Entry points: run any tool with --help
> Depends on: plugin tools on PATH: worksheet, shipinetics-verify, shipinetics-companions
> Gotchas: agents do not find a tool that is not in this list. Add its line when you add the tool
> Owner persona: maintainability | Last verified: {{YYYY-MM-DD}} at {{short commit}}

<!-- Write this file in ASD-STE100 (Simplified Technical English): short sentences, active voice, one word for one thing. Where it describes structure or flow, add a Mermaid diagram and a link to its Whiteboard. Rules: shipinetics:explain. -->

| Tool | What it does | Example |
|---|---|---|
| `bin/verify` | Definition of done. Fast checks, or everything with `--full` | `bin/verify --full` |
| `bin/lint-fix` | Fix lint problems with linter autofix, then an LLM for the rest | `bin/lint-fix src/foo.ts` |
| `bin/llm-fix` | Have a cheaper model fix lint problems in one file | used by lint-fix |
| `worksheet` (plugin) | Create, resume, list and tag worksheets | `worksheet new fix-login` |
