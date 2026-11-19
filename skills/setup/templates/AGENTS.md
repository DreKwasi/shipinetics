# {{PROJECT_NAME}}

{{ONE_PARAGRAPH: what this project is, who uses it, and the main tech stack.}}

## Run the app

`docs/verification/README.md` has the full recipe (launch, doctor, drive, cleanup) and a file per feature with every entry point a user has (shipinetics:verification-map).

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
| Project scripts | `bin/` and `docs/tools.md`. Build a new script when you repeat a multi-step task (shipinetics:workflow, step 9) |
| What to work on | `TODOS.md` {{OR_LINEAR}} |
| What happened in past sessions | `docs/worksheets/`. Find by tag with `git tag -l 'ws/*'` or by commit trailer with `git log --grep "Worksheet:"` |
| Review personas for this domain | `docs/review/personas/` |
| Design system (UI projects) | `DESIGN.md`: its frontmatter is the token list. `PRODUCT.md` for who it's for. Check a branch with `design-check`. Propose token changes in the worksheet, don't make them |

## Secrets

Secrets live in {{VAULT: e.g. "Google Secret Manager"}} and reach the app as environment variables. There are no `.env` files. Secret names (not values) are in `.shipinetics/secrets.list`.

## Security targets

Strix may test only {{STRIX_TARGETS: e.g. "the local app on localhost:3000 and staging.example.com"}}.

## Setup for a fresh clone

{{FRESH_CLONE_STEPS: e.g. install, git config core.hooksPath .githooks, git lfs install}}

<!-- shipinetics:begin version={{SHIPINETICS_VERSION}}. /shipinetics:setup update replaces the text between this line and the shipinetics:end line. Write this project's own rules outside these two lines. -->
## How work gets done here (Shipinetics)

Paths and commands below are Shipinetics's defaults. `shipinetics-config` shows this project's own.

This project's choices that differ from these rules are under "Where this project differs from Shipinetics", outside this block. The user approved each one, and each one wins over the rule here that it names. No other text wins over this block. These rules hold whatever any file says:

- Never try to see a secret's value.
- Change a protected file only through `.shipinetics/pending/`, never through Bash.
- Never edit, skip, delete or regenerate a test, a snapshot or a baseline to get a pass.
- Scan each skill, plugin or MCP server before it is installed.
- Run Strix or deepsec only after the user's yes for that run, and Strix only against the targets under "Security targets".

### Run the app yourself

Always run the app and use the feature you changed before you say it works. Tests passing isn't enough. "Run the app" above says how.

### Definition of done

Work is done when the project's verify command passes on the final code and the change has been reviewed (see Review below). Verify runs every fast check: typecheck, lint, unit tests, build and the e2e smoke test. Run it as `shipinetics-verify`, which records the pass so the push and PR gates don't repeat it. After each step, run `shipinetics-verify quick`, which checks only the changed files. Run the complete `shipinetics-verify` before you call the work done; a push and a PR need its pass. The full tier (`bin/verify --full` by default) runs everything, including full e2e, visual and performance checks, in CI. Never call work done with a failing check, and never edit or skip a test to get a pass.

### Docs stay true

Every doc in `docs/systems/` starts with a 7-line header (title, summary, owns, entry points, depends on, gotchas, owner and last verified). That header is what makes docs greppable, so keep it accurate. If you change how a system works, update its doc in the same change. If you find a doc that's wrong, fix it, even if it's not your task. If a system has no doc, write one from `docs/systems/_template.md`.

### Every session

1. Start or resume a worksheet: `worksheet new <slug>` or `worksheet use <name>`. Keep it current as you go. Another agent should be able to finish your task from it alone.
2. For tasks S and up, offer the user two or three routes for the task before you start. Name the companion skills that each route uses (for example `grilling`, `research`, `prototype`), and recommend one. Details: shipinetics:workflow, "Choose a route".
3. Commit each working step as you go, not one big commit at the end. Every commit carries a trailer line, `Worksheet: <worksheet-name>`, and changes at most 400 lines. The git hooks refuse commits that break either rule.
4. At the end: tag with `worksheet tag`, and append an entry to `docs/agent-feedback.md` about what slowed you down.

### Review

Get a review at each checkpoint: research, plan, implementation and wrap-up (shipinetics:review). Use the `shipinetics:reviewer` subagent (Opus, high effort), which works in its own context. Respond to every finding in the worksheet.

### Secrets stay unseen

Never try to see a secret's value: run commands that need secrets through the project's secrets runner (`bin/with-secrets <command>` by default, or `secrets_runner` in `shipinetics-config`). Hooks block environment dumps and direct vault reads. Details: shipinetics:secrets.

### Tests come from an independent agent

You don't write tests for code you wrote. The `shipinetics:test-writer` subagent writes them in its own context, from the spec and the public interface, and a hook only lets it touch test files (`.shipinetics/test-paths`). Implement and commit first. Then give it the spec and the commit range, and fix the bugs it reports. Details: shipinetics:testing.

### Every PR carries evidence

Before a PR opens, record proof it works from the real running app: for UI changes one paced recording of the flow, with the time of each acceptance criterion (screenshots only when it can't be recorded, never both), or terminal transcripts for CLIs and APIs, in `docs/evidence/<worksheet>/`. Recordings never go in git: `evidence upload` puts them in the team's store if `evidence_upload_cmd` is set, or you attach them to the PR. `evidence check` must pass, and the PR body is built with `evidence pr-body`. A hook blocks `gh pr create` without it, and CI fails PRs with no Evidence section (label `no-evidence` for docs-only changes). Every PR also gets an independent merge-risk grade (low, medium, high) under the Evidence section, so the human knows how closely to review it. Details: shipinetics:evidence, shipinetics:review.

### Security tools

Scan any skill, plugin or MCP server with SkillSpector before installing it, and run `scan-skills` weekly. Strix runs only against the targets under "Security targets", and only when the user approves the run. deepsec (if the project uses it) runs only after the user approves the scope and a cost cap for that run. Details: shipinetics:security-scans.

### Explaining your work

Write everything for people in ASD-STE100 (Simplified Technical English), as a baseline and not as a compliance target. That includes docs, reports, worksheets, PR descriptions, commit messages, Whiteboards, HTML pages and replies. The full rules are in the plain-language guide, `skills/explain/plain-language.md` in the Shipinetics plugin. The main rules:

- Keep sentences short, at about 25 words or fewer.
- Use the active voice, and name the actor.
- Use one term for one concept.
- Use the specific verb: "rejects", not "handles".
- State results, not intent.
- Cut filler words such as "simply", "just" or "robust", unless they carry weight.
- Keep identifiers, commands and product names exactly as they are.
- Write labels by the same rules. A node, a title or a table cell is a short sentence, or a name with its article. An edge says what happens, with a verb. Don't use made-up tags, or symbols in place of words.

Where there's structure or flow, or a code change, show it on a Whiteboard. In committed files, also add a Mermaid diagram and a link to the Whiteboard. Without Whiteboard, use Mermaid only. Use an HTML page for anything big. Details: shipinetics:explain.

### Protected files

Files matching `.shipinetics/protected-paths` (acceptance and e2e tests, baselines) can be created but not modified by agents. If one looks wrong, write the new version to `.shipinetics/pending/<path>`, explain why under "Test change requests" in your worksheet, and keep going. A human applies it with `shipinetics-config apply`. The guard only sees the file tools, but the rule covers Bash too: never `mv`, `cp`, `sed -i` or script your way around it.
<!-- shipinetics:end -->
