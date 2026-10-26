---
name: build-tool
description: Build a script in bin/ (or tools/) that makes a repeated agent task one reliable command, following the conventions for agent-friendly scripts. Use when you've run the same multi-step command sequence twice, when a command needs fragile flags, when output needs parsing every time, or when the user asks for a tool.
argument-hint: "<what the tool should do>"
---

# Build yourself a tool

> Paths below are Shipyard's defaults. A project can map them elsewhere in `.shipyard/config`: run `shipyard-config` to see this project's actual paths and commands, and use those.

Every time you work out a fiddly sequence of commands, the next agent has to work it out again. A script ends that. Over time, `bin/` becomes the project's own toolbox, and agents get faster and make fewer mistakes.

Tool to build: `$ARGUMENTS`

## When to build one

- You've run the same sequence of commands twice in a session, or seen it in two worksheets.
- A command needs flags or ordering that are easy to get wrong.
- You keep parsing the same output by eye.
- You're about to tell another agent "run X, then Y, then check Z".

## Where it goes

- Project-specific: `bin/<name>` (or `tools/` if the project already uses that).
- Useful in every project (like `agent_review`): build it in the project first, then note it in `docs/agent-feedback.md` as a candidate for the plugin's `bin/`.
- Add a line to `docs/tools.md` in the same commit. A tool nobody can find doesn't exist.

## How to write it

Bash for gluing commands together, Python (standard library only, or `uv` with inline script metadata) once there's real logic or data handling.

**Required:**

- First lines: shebang, then a comment block with what it does and usage examples. Keep that block in sync with the code.
- `--help` prints the usage and exits 0.
- Bash: `set -euo pipefail`. Python: `if __name__ == "__main__":` and `argparse`.
- Runs from any directory: `cd "$(dirname "$0")/.."` or resolve paths from the repo root.
- Non-interactive. Never prompt. Take everything as arguments or environment variables.
- Exit codes mean something: 0 success, 1 failure, 2 bad usage.
- Errors go to stderr and say how to fix them: `"no worksheet found. Start one with: worksheet new <slug>"`.
- Quiet on success, loud on failure. An agent reading 500 lines of output to find one error is wasting your budget.
- Idempotent where possible: running it twice does no harm.

**Strongly preferred:**

- `--json` for anything another tool or agent will parse.
- `--dry-run` for anything that changes state.
- No secrets in the script. Read them from the environment, and fail with a clear message when they're missing.

## Test it

Run it for real: the happy path, `--help`, a bad argument, and a failure case. If it's important, add a smoke test (a bats file or a pytest) so it doesn't rot.

## Then use it

Replace the manual steps everywhere they're written down: `AGENTS.md`, skills, system docs. Mention it in the worksheet.
