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

Impeccable, as the Claude Code plugin (not `npx skills add`, which installs its Codex build). In Claude Code:

```
/plugin marketplace add pbakaus/impeccable
```

Then open `/plugin` and install Impeccable from the list.

Optionally, Matt Pocock's skills, for grilling a plan before the spec and naming domain terms. `shipyard:workflow` says which ones fit and which to leave alone:

```bash
npx skills add mattpocock/skills
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
2. Run `/shipyard:setup`. It audits the project against every point and writes the status to `docs/shipyard-setup.md`.
3. Answer its questions. They come in one message: facts it couldn't confirm from live config, secret names, git LFS, the `no-evidence` label, and which optional phases you want.
4. It then installs every phase in the same run. It proves each phase works and commits it before starting the next:

| Phase | Adds | Setup proves it by |
|---|---|---|
| 1 | `bin/verify` with its quick, complete and full tiers, `AGENTS.md`, `.shipyard/` lists, `bin/with-secrets`, `.claude/settings.json`, one smoke test, the verification map in `docs/verification/` | Running each verify tier with `shipyard-verify`, the smoke test, and the map's end-to-end self-proof |
| 2 | System docs with 7-line headers, conventions, and for UI projects the design system: `DESIGN.md` written from the tokens the code already uses | `head -n 7 docs/systems/*.md` reads like a map of the codebase, and `design-check --all` runs |
| 3 | Worksheet template, feedback log, `TODOS.md` | `worksheet new` then `worksheet list` |
| 4 | Commit hooks: lint autofix with LLM fallback, a 400-line size limit, the `Worksheet:` trailer, and a pre-push hook that runs the complete verify | Committing a fixable lint error, a commit without a trailer and an oversized commit, and running the pre-push hook |
| 5 | CI running `bin/verify --full` | Validating the workflow YAML |
| 6 | One visual test, one benchmark (optional) | Both run in `bin/verify --full` |
| 7 | Night shift readiness (optional) | `night-shift --dry-run` |
| 8 | Security tools: SkillSpector and Strix (optional) | `scan-skills` shows no DO_NOT_INSTALL |

5. Read its report. It ends with a "For you" list: what only you can do, such as installing a CLI, logging in or creating a GitHub label. Anything about secrets or evidence is at the top, with what it leaves unprotected until you do it: those guardrails are only partly in force until then. If the run stopped early, run `/shipyard:setup` again. It picks up at the first phase that isn't done.
6. **Check the gates yourself:**
   - Run `shipyard-verify quick`, then `shipyard-verify`. The quick tier should take seconds, the complete one a few minutes at most. `shipyard-verify status` then shows both passed on the current code.
   - Ask the agent to make a small change that breaks a test and then finish. The Stop hook should send it back with the failure.
   - Ask the agent to write a test directly. The hook should refuse and point it at `shipyard:test-writer`.
   - Ask it to run `env`. The secrets guard should refuse.

To redo or repair one phase later, run `/shipyard:setup <phase>`, for example `/shipyard:setup 4`.

## 4. Daily: a normal task

Tell the agent what you want, the way you do now. It follows `shipyard:workflow`:

1. Starts a worksheet.
2. For medium tasks and up, grills you on the design first: one question at a time, each with its recommended answer, looking in the code instead of asking where it can. Then it writes a spec with acceptance criteria, and new domain terms go in `CONTEXT.md`. You approve the criteria.
3. Has `shipyard:test-writer` write the acceptance tests, then unit tests, in its own context.
4. Implements. While it works, each stop runs only the quick checks for what it changed. It drives the feature in the real app from the verification map, every entry point, then runs `shipyard-verify`. When it marks the worksheet done, the next stop runs the complete checks, and a push or PR needs them to have passed on the final code.
5. Gets reviews: `shipyard:reviewer` on a different model, plus the security or UI reviewer when the change calls for them, plus `agent_review` for a different model family. UI changes are checked against `DESIGN.md`. If the design needs a new token, the agent asks you in the worksheet instead of adding it. For medium tasks and up, the wrap-up reviewer drives the change in the app itself.
6. Records evidence from the running app once the code is final: screenshots per acceptance criterion showing the result and the state it left, a recording for UI changes, transcripts for CLIs and APIs. Evidence recorded before a later code change no longer passes.
7. For medium tasks and up, authors a Whiteboard of the change for you.
8. Commits each working step as it goes, each with a `Worksheet:` trailer and under 400 changed lines (the git hooks refuse anything else). Then tags the worksheet, fills in its metrics and leaves feedback.
9. For a PR: builds the body with the Evidence section and an independent merge-risk grade. The PR can't open without the evidence.

What you do: answer the grilling questions, approve the acceptance criteria, decide any design-system change requests, then let the merge-risk grade set how closely you review. Low: check the evidence, skim, merge. Medium: read the Whiteboard and the flagged files. High: full review. Fill in the three human fields in the worksheet's Metrics (corrections, review minutes, accepted).

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
| `/shipyard:sweep` | Looks across the week's commits for duplication, drift and half-finished work. Also checks the verification map against the app, design-system drift, the secrets and evidence guardrails, and `shipyard-verify times` |
| `/improve-codebase-architecture` | Optional (Matt Pocock's skills). When the sweep keeps finding the same hot spots: proposes deeper modules, and you pick what goes in the queue |
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
| Stop hook makes every turn slow | Mid-task stops are running the complete tier. Set `verify_quick_cmd = bin/verify --quick` in `.shipyard/config` and scope `--quick` to the changed files. `shipyard-verify times` shows which tier and step is slow. Keep slow suites behind `--full` |
| A stop runs the complete checks mid-task | A path in `.shipyard/complete-paths` changed (build config, a manifest, a lockfile), or the worksheet already says `Status: done`. Working as intended |
| `gh pr create` is refused | Working as intended: the complete verify hasn't passed on this exact code (run `shipyard-verify`), the branch has no complete evidence, or the body has no Evidence section. Run `evidence check --branch` to see what's missing |
| `evidence check` says code changed since the evidence was recorded | A code fix landed after the screenshots. Re-record the criteria it affects and update the Commit line in `EVIDENCE.md`. Docs and test changes don't trigger this |
| `design-check` says there's no design system to check against | `DESIGN.md` is missing or has no token frontmatter. Run `/shipyard:setup 2` (or `/impeccable document`) to write it from the code |
| Agent says it can't write a test | Working as intended. It should spawn `shipyard:test-writer`. For a one-off mass change, start Claude Code with `SHIPYARD_ALLOW_AUTHOR_TESTS=1` |
| Guard blocks a harmless command | Tell me the command so the pattern can be fixed. For now, run it yourself or use `SHIPYARD_ALLOW_ENV_READ=1` for that session |
| `bin/with-secrets` fails | gcloud isn't logged in, or the secret name in `.shipyard/secrets.list` doesn't match Secret Manager |
| `agent_review` warns about falling back to Claude | No Codex, Gemini or Cursor CLI is installed and logged in |
| Night shift stops at once with a sandbox error | Claude Code's sandbox isn't available on this machine. Run `/sandbox` in Claude Code to check |
| Every Bash call in a headless run fails with `EPERM ... srt-mux-*.sock` | You started `night-shift` or `claude -p` from inside another Claude Code session. A sandbox can't start inside another sandbox, and this machine's managed settings require one. Start it from a normal terminal instead |
