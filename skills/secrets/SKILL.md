---
name: secrets
description: How secrets work in shipyard projects. They live in a vault (such as Google Secret Manager), reach the app as environment variables, are read only by the config module, and are never seen by agents. Use when code needs a secret or config value, when running something that needs secrets, when adding a new secret, or when a hook blocks an environment read.
---

# Secrets: vault in, config module out, never in the agent's context

## The model

1. **Secrets live in a vault**, such as Google Secret Manager. Never in files: no `.env`, no committed config, no fixtures, no docs.
2. **They reach processes as environment variables.** In production, the platform injects them (Cloud Run secret environment variables, for example). Locally and for agents, `bin/with-secrets <command>` fetches them from the vault and runs the command with them set.
3. **Only the config module reads the environment.** One place (listed in `.shipyard/env-allowed-paths`, usually `src/config/`) reads, validates and types every variable, fails fast at startup if one is missing, and exports values to the rest of the code. Everything else imports from it.
4. **Agents never see secret values.** You work with names, never values.

## What the hooks enforce

- **`guard-secrets` (Bash and Read, in every project):** blocks dumping the environment (`env`, `printenv`, `export -p`), inline scripts that read it (`node -e "process.env..."`), echoing secret-looking variables, reading the vault directly (`gcloud secrets versions access`, `vault kv get`, `op read`, ...) and reading credential files (gcloud ADC, `~/.aws/credentials`, SSH keys).
- **`guard-edits` (set-up projects):** blocks new `process.env`, `os.environ` and similar reads in any file outside `.shipyard/env-allowed-paths`.

If a hook blocks you, don't look for another route to the value. You almost never need it. Do one of these instead:

| You want to | Do this |
|---|---|
| Use a secret in code | Import it from the config module. If it isn't there, add it there (name, type, validation) |
| Run the app or tests that need secrets | `bin/with-secrets npm run dev` (or whatever the command is) |
| Check a variable is set | `[ -n "${NAME+x}" ] && echo set` |
| Know which secrets exist | Read `.shipyard/secrets.list` (names and vault paths only, no values) or the config module |
| Debug "secret missing" | Check the name in the config module matches the vault and `.shipyard/secrets.list`. Ask the human to check the vault |

## Adding a new secret

You can't create it in the vault, and you shouldn't. Instead:

1. Add the variable to the config module with its type and validation.
2. Add a line to `.shipyard/secrets.list`: `ENV_NAME=secret-name` (or a full `projects/<project>/secrets/<name>` path).
3. Write it in the worksheet under Blockers or Follow-ups: "Needs secret `ENV_NAME` created in Secret Manager as `secret-name`, used for <purpose>." The human creates it.
4. Make the code fail with a clear message at startup when it's missing, not deep inside a request.

## Never

- Print, log, echo or write a secret value anywhere, including test output and error messages.
- Put a real secret in a test. Tests use obviously fake values (`test-key-not-real`).
- Pass a secret on a command line you show in output or a worksheet.
- Commit a `.env` file or a file with credentials, even "temporarily".

## For the user: the strongest layer

The hooks match command text, so they're a backstop. The strongest protection is that secrets are never in the agent's environment at all:

- Don't start Claude Code from a shell that has production secrets exported. Use `bin/with-secrets` inside commands instead.
- Set `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` (the project's `.claude/settings.json` from `/shipyard:setup` does this). Claude Code then strips anything that looks like a credential from every command, hook and MCP server it starts. `bin/with-secrets` still works, because it fetches the values itself after it starts.
