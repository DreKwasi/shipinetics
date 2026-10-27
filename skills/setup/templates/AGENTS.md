# {{PROJECT_NAME}}

{{ONE_PARAGRAPH: what this project is, who uses it, and the main tech stack.}}

## Definition of done

Work is done when **`bin/verify` passes** on the final code and the change has been reviewed (see Review below). `bin/verify` runs every fast check: typecheck, lint, unit tests, build and the e2e smoke test. Run it as `shipinetics-verify`, which records the pass so hooks don't repeat it. Mid-task stops run only `bin/verify --quick`, scoped to the changed files. The complete run happens at the stop after the worksheet is marked done, before a push and before a PR. `bin/verify --full` runs everything, including full e2e, visual and performance checks, in CI and at end of shift. Never call work done with a failing check, and never edit or skip a test to get a pass.

## Run the app yourself

Always run the app and use the feature you changed before you say it works. Tests passing isn't enough. `docs/verification/README.md` has the full recipe (launch, doctor, drive, cleanup) and a file per feature with every entry point a user has (shipinetics:verification-map).

- Install: `{{INSTALL_CMD}}`
- Start: `bin/with-secrets {{START_CMD}}` (serves on {{URL}})
- Seed data: `{{SEED_CMD}}`
- Test login: {{TEST_LOGIN: e.g. "the seed script creates test@example.com; its password is in Secret Manager as test-user-password and bin/with-secrets injects it". Never real credentials.}}
- Logs: {{WHERE_LOGS_GO}}
- Drive it: use Playwright (`{{E2E_CMD}}`) or the Playwright MCP to click through, and check the browser console and server logs for errors.

## Where to find things

| You need | Go to |
|---|---|
| What a domain term means | `GLOSSARY.md` (the glossary: one meaning per term, and words to avoid). Decisions that are hard to reverse: `docs/adr/` |
| How a system works | `docs/systems/`. Run `head -n 7 docs/systems/*.md` to see every system's summary, then open the one you need |
| How we work (the task loop) | {{WORKFLOW_POINTER: "@AGENT_WORKFLOW.md" or "the shipinetics:workflow skill"}} |
| Code conventions | `docs/conventions.md` |
| How to write tests, and what each test covers | `docs/testing/how-to-write-tests.md`, `docs/testing/test-index.md` |
| Project scripts | `bin/` and `docs/tools.md`. Build a new script when you repeat a multi-step task (shipinetics:build-tool) |
| What to work on | `TODOS.md` {{OR_LINEAR}} |
| What happened in past sessions | `docs/worksheets/`. Find by tag with `git tag -l 'ws/*'` or by commit trailer with `git log --grep "Worksheet:"` |
| Review personas for this domain | `docs/review/personas/` |
| Design system (UI projects) | `DESIGN.md`: its frontmatter is the token list. `PRODUCT.md` for who it's for. Check a branch with `design-check`. Propose token changes in the worksheet, don't make them |

## Docs stay true

Every doc in `docs/systems/` starts with a 7-line header (title, summary, owns, entry points, depends on, gotchas, owner and last verified). That header is what makes docs greppable, so keep it accurate. If you change how a system works, update its doc in the same change. If you find a doc that's wrong, fix it, even if it's not your task. If a system has no doc, write one from `docs/systems/_template.md`.

## Every session

1. Start or resume a worksheet: `worksheet new <slug>` or `worksheet use <name>`. Keep it current as you go. Another agent should be able to finish your task from it alone.
2. Commit each working step as you go, not one big commit at the end. Every commit carries a trailer line, `Worksheet: <worksheet-name>`, and changes at most 400 lines. The git hooks refuse commits that break either rule.
3. At the end: tag with `worksheet tag`, and append an entry to `docs/agent-feedback.md` about what slowed you down.

## Review

Get a review from a different model at each checkpoint: research, plan, implementation and wrap-up (shipinetics:review). Use the `shipinetics:reviewer` subagent on a different Claude model, and `agent_review` for a different model family. Respond to every finding in the worksheet.

## Secrets

Secrets live in Google Secret Manager and reach the app as environment variables. There are no `.env` files. Only the config module (`{{CONFIG_MODULE_PATH}}`) reads the environment. Everything else imports from it. Never try to see a secret's value: run commands that need secrets as `bin/with-secrets <command>`. Secret names (not values) are in `.shipinetics/secrets.list`. Hooks block environment dumps, direct vault reads and new environment reads outside the config module. Details: shipinetics:secrets.

## Tests come from an independent agent

You don't write tests for code you wrote. The `shipinetics:test-writer` subagent writes them in its own context, from the spec and the public interface, and a hook only lets it touch test files (`.shipinetics/test-paths`). Give it the spec and the interface, then fix the bugs it reports. Details: shipinetics:testing.

## Every PR carries evidence

Before a PR opens, record proof it works from the real running app: a screenshot per acceptance criterion and a screen recording for UI changes, or terminal transcripts for CLIs and APIs, in `docs/evidence/<worksheet>/`. `evidence check` must pass, and the PR body is built with `evidence pr-body`. A hook blocks `gh pr create` without it, and CI fails PRs with no Evidence section (label `no-evidence` for docs-only changes). Every PR also gets an independent merge-risk grade (low, medium, high) under the Evidence section, so the human knows how closely to review it. Details: shipinetics:evidence, shipinetics:review.

## Security tools

Scan any skill, plugin or MCP server with SkillSpector before installing it, and run `scan-skills` weekly. Strix security testing runs only against {{STRIX_TARGETS: e.g. "the local app on localhost:3000 and staging.example.com"}}, and only when the user approves the run. Details: shipinetics:security-scans.

## Explaining your work

Write everything for people in ASD-STE100 (Simplified Technical English): docs, reports, worksheets, PR bodies, Whiteboards, HTML pages and replies. Short sentences, active voice, one word for one thing. Use a diagram when there's structure or flow, a Whiteboard for code changes, and an HTML page for anything big. Details: shipinetics:explain.

## Protected files

Files matching `.shipinetics/protected-paths` (acceptance and e2e tests, baselines) can be created but not modified by agents. If one looks wrong, write the new version to `.shipinetics/pending/<path>`, explain why under "Test change requests" in your worksheet, and keep going. A human applies it with `shipinetics-config apply`. The guard only sees the file tools, but the rule covers Bash too: never `mv`, `cp`, `sed -i` or script your way around it.

## Setup for a fresh clone

{{FRESH_CLONE_STEPS: e.g. install, git config core.hooksPath .githooks, git lfs install}}
