# {{PROJECT_NAME}}

{{ONE_PARAGRAPH: what this project is, who uses it, and the main tech stack.}}

## Definition of done

Work is done when **`bin/verify` passes** and the change has been reviewed (see Review below). `bin/verify` runs typecheck, lint, unit tests and the e2e smoke test. `bin/verify --full` runs everything, including full e2e, visual and performance checks. Never call work done with a failing check, and never edit or skip a test to get a pass.

## Run the app yourself

Always run the app and use the feature you changed before you say it works. Tests passing isn't enough.

- Install: `{{INSTALL_CMD}}`
- Start: `bin/with-secrets {{START_CMD}}` (serves on {{URL}})
- Seed data: `{{SEED_CMD}}`
- Test login: {{TEST_LOGIN: e.g. "the seed script creates test@example.com; its password is in Secret Manager as test-user-password and bin/with-secrets injects it". Never real credentials.}}
- Logs: {{WHERE_LOGS_GO}}
- Drive it: use Playwright (`{{E2E_CMD}}`) or the Playwright MCP to click through, and check the browser console and server logs for errors.

## Where to find things

| You need | Go to |
|---|---|
| How a system works | `docs/systems/`. Run `head -n 7 docs/systems/*.md` to see every system's summary, then open the one you need |
| How we work (the task loop) | {{WORKFLOW_POINTER: "@AGENT_WORKFLOW.md" or "the shipyard:workflow skill"}} |
| Code conventions | `docs/conventions.md` |
| How to write tests, and what each test covers | `docs/testing/how-to-write-tests.md`, `docs/testing/test-index.md` |
| Project scripts | `bin/` and `docs/tools.md`. Build a new script when you repeat a multi-step task (shipyard:build-tool) |
| What to work on | `TODOS.md` {{OR_LINEAR}} |
| What happened in past sessions | `docs/worksheets/`. Find by tag with `git tag -l 'ws/*'` or by commit trailer with `git log --grep "Worksheet:"` |
| Review personas for this domain | `docs/review/personas/` |

## Docs stay true

Every doc in `docs/systems/` starts with a 7-line header (title, summary, owns, entry points, depends on, gotchas, owner and last verified). That header is what makes docs greppable, so keep it accurate. If you change how a system works, update its doc in the same change. If you find a doc that's wrong, fix it, even if it's not your task. If a system has no doc, write one from `docs/systems/_template.md`.

## Every session

1. Start or resume a worksheet: `worksheet new <slug>` or `worksheet use <name>`. Keep it current as you go. Another agent should be able to finish your task from it alone.
2. Commits carry a trailer line: `Worksheet: <worksheet-name>`.
3. At the end: tag with `worksheet tag`, and append an entry to `docs/agent-feedback.md` about what slowed you down.

## Review

Get a review from a different model at each checkpoint: research, plan, implementation and wrap-up (shipyard:review). Use the `shipyard:reviewer` subagent on a different Claude model, and `agent_review` for a different model family. Respond to every finding in the worksheet.

## Secrets

Secrets live in Google Secret Manager and reach the app as environment variables. There are no `.env` files. Only the config module (`{{CONFIG_MODULE_PATH}}`) reads the environment. Everything else imports from it. Never try to see a secret's value: run commands that need secrets as `bin/with-secrets <command>`. Secret names (not values) are in `.shipyard/secrets.list`. Hooks block environment dumps, direct vault reads and new environment reads outside the config module. Details: shipyard:secrets.

## Tests come from an independent agent

You don't write tests for code you wrote. The `shipyard:test-writer` subagent writes them in its own context, from the spec and the public interface, and a hook only lets it touch test files (`.shipyard/test-paths`). Give it the spec and the interface, then fix the bugs it reports. Details: shipyard:testing.

## Every PR carries evidence

Before a PR opens, record proof it works from the real running app: a screenshot per acceptance criterion and a screen recording for UI changes, or terminal transcripts for CLIs and APIs, in `docs/evidence/<worksheet>/`. `evidence check` must pass, and the PR body is built with `evidence pr-body`. A hook blocks `gh pr create` without it, and CI fails PRs with no Evidence section (label `no-evidence` for docs-only changes). Every PR also gets an independent merge-risk grade (low, medium, high) under the Evidence section, so the human knows how closely to review it. Details: shipyard:evidence, shipyard:review.

## Security tools

Scan any skill, plugin or MCP server with SkillSpector before installing it, and run `scan-skills` weekly. Strix security testing runs only against {{STRIX_TARGETS: e.g. "the local app on localhost:3000 and staging.example.com"}}, and only when the user approves the run. Details: shipyard:security-scans.

## Explaining your work

Write reports and summaries in plain controlled English (about 80% of ASD-STE100: short sentences, active voice, one word per concept). Use a diagram when there's structure or flow, a Whiteboard for code changes, and an HTML page for anything big. Details: shipyard:explain.

## Protected files

Files matching `.shipyard/protected-paths` (acceptance and e2e tests, baselines) can be created but not modified by agents. If one looks wrong, write it up under "Test change requests" in your worksheet and keep going.

## Setup for a fresh clone

{{FRESH_CLONE_STEPS: e.g. install, git config core.hooksPath .githooks, git lfs install}}
