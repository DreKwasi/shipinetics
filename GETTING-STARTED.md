# Getting started with shipyard

How to roll shipyard out: once per machine, once per project, then the daily, nightly and weekly rhythm. Read the README first for what each piece does.

## 1. Publish the plugin (once)

Put this folder in a private GitHub repo so every machine installs the same version.

```bash
cd ~/Projects/shipyard && git init -b main && git add -A && git commit -m "shipyard v0.1.0"
```

```bash
gh repo create shipyard --private --source ~/Projects/shipyard --push
```

When you change the plugin later, bump `version` in `.claude-plugin/plugin.json`, commit and push. Machines pick it up with `claude plugin update shipyard`.

## 2. Install on each machine (once per machine)

```bash
claude plugin marketplace add <your-github-user>/shipyard
```

```bash
claude plugin install shipyard@shipyard
```

Then the companions. Each is optional, and shipyard tells you when one is missing:

```bash
npx skills add cloudflare/security-audit-skill
```

```bash
npx skills add pbakaus/impeccable
```

```bash
npx skills add warpdotdev/common-skills --skill merge-risk
```

```bash
uv tool install git+https://github.com/NVIDIA/skillspector.git
```

Install SkillSpector first, then scan each skill before you install it, for example `skillspector scan https://github.com/warpdotdev/common-skills --no-llm`. Once shipyard is installed, its install gate asks you before any agent installs a skill, plugin or MCP server.

- App security testing: install Strix (see its README; it needs Docker) and keep its provider key in Secret Manager.

- Whiteboard: install the dev.fast Whiteboard plugin and desktop app.
- Cross-family review: install at least one of the Codex, Gemini or Cursor CLIs, and log in to it. Check with `agent_review --list` inside a project.
- Secrets: `gcloud auth login` and `gcloud auth application-default login`, so `bin/with-secrets` can read Secret Manager.

## 3. Set up a project (once per project)

Start with one pilot project, not all of them. Pick one with an existing test suite and a few small tasks waiting.

1. Open the project in Claude Code on a clean branch.
2. Run `/shipyard:setup`. It audits the project against every point, writes the status to `docs/shipyard-setup.md`, then does Phase 1:
   - `bin/verify` with the project's real commands
   - `AGENTS.md` and a one-line `CLAUDE.md`
   - the `.shipyard/` lists (protected paths, test paths, env-allowed paths, secret names)
   - `bin/with-secrets` and `.claude/settings.json` (env scrub and deny list)
   - one smoke test, written by `shipyard:test-writer`
3. **Check Phase 1 yourself before going on:**
   - Run `bin/verify`. It should pass and take a few minutes at most.
   - Ask the agent to make a small change that breaks a test and then finish. The Stop hook should send it back with the failure.
   - Ask the agent to write a test directly. The hook should refuse and point it at `shipyard:test-writer`.
   - Ask it to run `env`. The secrets guard should refuse.
4. Run the remaining phases one at a time, when you're ready:

| Command | Adds | Check |
|---|---|---|
| `/shipyard:setup 2` | System docs with 7-line headers, conventions | `head -n 7 docs/systems/*.md` reads like a map of the codebase |
| `/shipyard:setup 3` | Worksheet template, feedback log, `TODOS.md` | `worksheet new test` then `worksheet list` |
| `/shipyard:setup 4` | Pre-commit lint with autofix and LLM fallback | Commit a fixable lint error. It comes out fixed |
| `/shipyard:setup 5` | CI running `bin/verify --full` | The next PR shows the check |
| `/shipyard:setup 6` | One visual test, one benchmark | Both run in `bin/verify --full` |
| `/shipyard:setup 7` | Night shift readiness | `night-shift --dry-run` |
| `/shipyard:setup 8` | Security tools: SkillSpector and Strix | `scan-skills` shows no DO_NOT_INSTALL |

## 4. Daily: a normal task

Tell the agent what you want, the way you do now. It follows `shipyard:workflow`:

1. Starts a worksheet.
2. Writes a spec with acceptance criteria (medium tasks and up). You approve the criteria.
3. Has `shipyard:test-writer` write the acceptance tests, then unit tests, in its own context.
4. Implements, runs the app, runs `bin/verify`.
5. Gets reviews: `shipyard:reviewer` on a different model, plus the security or UI reviewer when the change calls for them, plus `agent_review` for a different model family.
6. Records evidence from the running app: screenshots per acceptance criterion, a recording for UI changes, transcripts for CLIs and APIs.
7. For medium tasks and up, authors a Whiteboard of the change for you.
8. Commits with a `Worksheet:` trailer, tags the worksheet, fills in its metrics, leaves feedback.
9. For a PR: builds the body with the Evidence section and an independent merge-risk grade. The PR can't open without the evidence.

What you do: approve the acceptance criteria, then let the merge-risk grade set how closely you review. Low: check the evidence, skim, merge. Medium: read the Whiteboard and the flagged files. High: full review. Fill in the three human fields in the worksheet's Metrics (corrections, review minutes, accepted).

For longer tasks, paste the `/goal` line from the spec. Claude then keeps working until a separate evaluator sees the deliverables shown: tests passing, verify green, review done, work committed.

Useful direct commands:

| Command | When |
|---|---|
| `/shipyard:spec <issue or idea>` | Turn an idea into acceptance criteria and failing tests first |
| `/shipyard:review impl` | Force a review now |
| `/shipyard:explain <topic> html` | Get an interactive page explaining something |
| `/shipyard:explain <topic> video` | Get a narrated explainer video (asks first) |
| `/shipyard:evidence` | Record or check the evidence for the current task |
| `/shipyard:security-scans app` | Security-test your own app with Strix (asks you to approve the targets first) |

## 5. Nightly: the night shift

1. Put small, clear tasks in the Ready section of `TODOS.md`, each with acceptance criteria.
2. Start it from a terminal in the project:

```bash
caffeinate -i night-shift --hours 6 --budget 30 --task-budget 6
```

3. In the morning, open `docs/shifts/<date>.html` (or the `.md`) in the night worktree. Start with "Needs you": blocked questions, failing checks, test change requests.
4. Read the Whiteboards for the tasks you care about, then review branch `night/<date>` and merge what you want.

Start with a small budget and two or three tasks for the first few nights. Raise the limits once the reports look trustworthy.

## 6. Weekly: keep it sharp

| Command | What it does |
|---|---|
| `/shipyard:feedback ingest` | Groups the agents' feedback and proposes fixes to docs, tools and lint rules. You approve them |
| `/shipyard:sweep` | Looks across the week's commits for duplication, drift and half-finished work |
| `/shipyard:test-audit` | Finds tests that don't test what they claim, and prunes bloat |
| `scan-skills` | Scans every installed skill, agent and plugin with SkillSpector. Deal with anything DO_NOT_INSTALL |
| Full security audit | Ask for it before a release: "run a full security audit with shipyard:security-reviewer", plus a Strix run against staging if you approve it |

## Effort

Everything runs at high effort by default: the main session (project settings), all four agents, night shift runs and the review CLIs. To turn it down for a session, start Claude Code with `CLAUDE_CODE_EFFORT_LEVEL=medium`, which overrides everything, agents included. The README lists the per-scope settings.

## 7. Roll out to more projects

Once the pilot has run a couple of weeks of tasks and a few night shifts without surprises, run `/shipyard:setup` in the next project. Each project keeps its own `AGENTS.md`, docs and lists. The plugin stays shared, so an improvement from one project's feedback reaches every project on the next `claude plugin update shipyard`.

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| Stop hook never fires | The project has no `.shipyard/` folder or `bin/verify` isn't executable. Check `/plugin` for errors |
| Stop hook makes every turn slow | `bin/verify` fast mode is too slow. Move slow suites behind `--full` |
| `gh pr create` is refused | Working as intended: the branch has no complete evidence, or the body has no Evidence section. Run `evidence check --branch` to see what's missing |
| Agent says it can't write a test | Working as intended. It should spawn `shipyard:test-writer`. For a one-off mass change, start Claude Code with `SHIPYARD_ALLOW_AUTHOR_TESTS=1` |
| Guard blocks a harmless command | Tell me the command so the pattern can be fixed. For now, run it yourself or use `SHIPYARD_ALLOW_ENV_READ=1` for that session |
| `bin/with-secrets` fails | gcloud isn't logged in, or the secret name in `.shipyard/secrets.list` doesn't match Secret Manager |
| `agent_review` warns about falling back to Claude | No Codex, Gemini or Cursor CLI is installed and logged in |
| Night shift stops at once with a sandbox error | Claude Code's sandbox isn't available on this machine. Run `/sandbox` in Claude Code to check |
| Every Bash call in a headless run fails with `EPERM ... srt-mux-*.sock` | You started `night-shift` or `claude -p` from inside another Claude Code session. A sandbox can't start inside another sandbox, and this machine's managed settings require one. Start it from a normal terminal instead |
