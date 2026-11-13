---
name: secrets
description: How secrets work in shipinetics projects. They live in a vault (such as Google Secret Manager or Infisical), reach the app as environment variables, and are never seen by agents. Use when code needs a secret or config value, when running something that needs secrets, when adding a new secret, or when a hook blocks an environment read.
---

# Secrets: in the vault, never in the agent's context

> Paths below are Shipinetics's defaults. A project can map them elsewhere in `.shipinetics/config`: run `shipinetics-config` to see this project's actual paths and commands, and use those.
>
> Text for people (docs, worksheets, reports, PR descriptions, commit messages, review comments, replies, and each label on a board, diagram or table): write it in ASD-STE100, by the plain-language guide (`${CLAUDE_PLUGIN_ROOT}/skills/explain/plain-language.md`). Where the text describes structure or flow (a call path, a data flow, states or steps), show it on a Whiteboard. In a committed file, also put a Mermaid diagram and a link to the Whiteboard, because GitHub and other people cannot open your Whiteboard. Without Whiteboard, use Mermaid only. shipinetics:explain has the rules.

## The model

1. **Secrets live in a vault**, such as Google Secret Manager. Never in files: no `.env`, no committed config, no fixtures, no docs.
2. **They reach processes as environment variables.** In production, the platform injects them (Cloud Run secret environment variables, for example). Locally and for agents, the project's secrets runner fetches them from the vault and runs the command with them set. That's `secrets_runner` in `.shipinetics/config`: `bin/with-secrets <command>` by default, or for example `infisical run --env=dev -- <command>` in an Infisical project.
3. **Agents never see secret values.** You work with names, never values.

## What the hooks enforce

- **`guard-secrets` (Bash and Read, in every project):** blocks dumping the environment (`env`, `printenv`, `export -p`), inline scripts that read it (`node -e "process.env..."`), echoing secret-looking variables, reading the vault directly (`gcloud secrets versions access`, `vault kv get`, `op read`, ...) and reading or naming a secret file. The user chooses the secret files: a `secret-paths` list in `.shipinetics/` or `~/.config/shipinetics/`, else a built-in list (gcloud ADC, `~/.aws/credentials`, SSH keys and the like).

If a hook blocks you, don't look for another route to the value. You almost never need it. Do one of these instead:

| You want to | Do this |
|---|---|
| Use a secret in code | Read it the way the project reads its other configuration. Fail with a clear message at startup when it's missing |
| Run the app or tests that need secrets | `bin/with-secrets npm run dev` (or whatever the command is) |
| Check a variable is set | `[ -n "${NAME+x}" ] && echo set` |
| Know which secrets exist | Read `.shipinetics/secrets.list` (names and vault paths only, no values) |
| Debug "secret missing" | Check that the name in the code matches the vault and `.shipinetics/secrets.list`. Ask the human to check the vault |

## Adding a new secret

You can't create it in the vault, and you shouldn't. Instead:

1. Read the variable in code the way the project reads its other configuration.
2. Add a line to `.shipinetics/secrets.list`: `ENV_NAME=secret-name` (or a full `projects/<project>/secrets/<name>` path).
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
- Set `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` (the project's `.claude/settings.json` from `/shipinetics:setup` does this). Claude Code then strips anything that looks like a credential from every command, hook and MCP server it starts. `bin/with-secrets` still works, because it fetches the values itself after it starts.
