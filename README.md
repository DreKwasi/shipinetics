# shipyard

A portable agentic coding setup for Claude Code. Install it once and every project gets the same workflow, review process and guardrails:

- A Stop hook that won't let the agent finish while checks fail.
- Tests written by an independent agent, never by the one that wrote the code.
- Every PR carries evidence from the running app (screenshots, recordings, transcripts) and an independent merge-risk grade.
- Secrets that stay in the vault and out of the agent's context.
- Read-only reviewers on different models, including security (Cloudflare's security-audit skill) and frontend (impeccable), all at high effort.
- Security scanning of agent tooling (NVIDIA SkillSpector) and of your app (Strix), with you approving every app test.
- Whiteboards and HTML explainers so you can understand what the agents did, with claims checked against sources.
- Worksheets that let another agent pick up a half-done task, with metrics to measure the setup on accepted work.
- A night shift launcher with hard limits.

It has two layers:

- **The plugin** (this repo) carries the generic parts: skills, subagents, hooks and scripts. Update it in one place and every project gets the change.
- **The project** gets the specific parts, written into the repo by `/shipyard:setup` and committed: `AGENTS.md`, `bin/verify`, `bin/with-secrets`, the `.shipyard/` lists, system docs, conventions, test docs and the task queue. They live in the repo so CI, teammates and other agents (Codex, Cursor) can use them without the plugin.

[GETTING-STARTED.md](GETTING-STARTED.md) walks through the rollout step by step.

## Install

Locally, while it's not on GitHub yet:

```bash
claude plugin marketplace add ~/Projects/shipyard
```

```bash
claude plugin install shipyard@shipyard
```

Once it's in a GitHub repo, use `claude plugin marketplace add <owner>/<repo>` on any machine, then the same install command. To try it for one session without installing, run `claude --plugin-dir ~/Projects/shipyard`.

### Companions (install separately)

shipyard uses these when they're installed and falls back when they aren't. `/shipyard:setup` checks for them. Scan each with SkillSpector before installing it.

| Companion | Used by | Install |
|---|---|---|
| Cloudflare `security-audit` skill | `shipyard:security-reviewer` | `npx skills add cloudflare/security-audit-skill` |
| `impeccable` skill or plugin | `shipyard:ui-reviewer`, HTML explainers | `npx skills add pbakaus/impeccable`, or the impeccable plugin |
| `merge-risk` skill (Warp) | Merge-risk grades on every PR | `npx skills add warpdotdev/common-skills --skill merge-risk` |
| NVIDIA SkillSpector | `scan-skills`, the install gate | `uv tool install git+https://github.com/NVIDIA/skillspector.git` |
| Strix | App security testing (shipyard:security-scans) | See its README. Needs Docker and a provider key in your vault |
| dev.fast Whiteboard plugin | Whiteboards of changes for human review | from the dev.fast marketplace |
| Codex, Gemini or Cursor CLI | `agent_review` cross-family reviews | each tool's installer |

They aren't declared as hard plugin dependencies on purpose. A missing hard dependency stops the whole plugin from loading, and some of them (Whiteboard, Docker) won't exist in CI or on every machine.

## Projects with their own setup, and multi-repo workspaces

Shipyard's paths and commands are defaults. A project can map them to what it already has in `.shipyard/config` (template: `skills/setup/templates/config`): worksheet folder, feedback log, system docs, conventions, test docs, verify command, worksheet scripts, tag prefix and secrets runner. Skills, hooks and tools then use the project's own files. `shipyard-config` prints the effective settings.

Workspace mode (`packages = ...`) is for a root that holds several package repos and isn't a repo itself. The Stop hook runs `package_verify_cmd` for each package the agent edited in that session, so the user's unrelated work in progress never blocks it. The PR gate and `evidence` work from whichever package repo the PR comes from. `night-shift` doesn't support workspace mode yet.

`/shipyard:setup` audits first and asks before acting on anything it could only infer from comments or old docs.

## How the points map to the plugin

| # | Point | Plugin | In the project |
|---|---|---|---|
| 0 | Router | setup writes it | `AGENTS.md`, `CLAUDE.md` (imports `@AGENTS.md`) |
| 1 | Workflow | `shipyard:workflow` | your `AGENT_WORKFLOW.md` overrides it if present |
| 2 | Self-healing docs | `shipyard:system-docs` (with claims checked against sources) | `docs/systems/*.md` with 7-line headers |
| 3 | Run the app | `shipyard:workflow` step 6 | "Run the app yourself" in `AGENTS.md` |
| 4 | Tests | `shipyard:testing`, `shipyard:test-writer`, `shipyard:spec` | `docs/testing/`, `e2e/`, `.shipyard/test-paths` |
| 5 | Linters that fix | `shipyard:lint-rule` | `bin/lint-fix`, `bin/llm-fix`, `.githooks/pre-commit` |
| 6 | Cross-agent review | `shipyard:review`, four reviewer agents, `agent_review`, 7 personas | `docs/review/personas/` for domain personas |
| 7 | Worksheets and tags | `shipyard:worksheet`, `worksheet` | `docs/worksheets/`, `ws/*` tags, `Worksheet:` commit trailers |
| 8 | Session feedback | `shipyard:feedback`, Stop hook reminder | `docs/agent-feedback.md` |
| 9 | Agent-built tools | `shipyard:build-tool` | `bin/`, `docs/tools.md` |
| 10 | Commit sweeps | `shipyard:sweep` | `docs/sweeps/`, `sweep/*` tags |
| 11 | Conventions | `shipyard:lint-rule` moves them into linters | `docs/conventions.md` |
| 12 | Night shift | `shipyard:night-shift`, `night-shift` launcher | `TODOS.md`, `.claude/settings.json` |
| 13 | Task queue | `shipyard:task-queue` | `TODOS.md`, or Linear through `bin/tasks` |
| 14 | False-confidence audit | `shipyard:test-audit` (mutation checks, bloat pruning) | `docs/test-audits/` |
| 15 | Visual regression | `shipyard:visual-regression`, `shipyard:ui-reviewer` | screenshot tests, LFS or PR artifacts |
| 16 | Perf benchmarks | `shipyard:perf` | `perf/baselines/`, `bin/bench` |
| 17 | Profiling | `shipyard:perf` (experiment protocol) | `docs/perf/experiments.md` |
| 18 | End of shift | `shipyard:end-of-shift` | `bin/verify --full`, `docs/shifts/*.md` and `*.html` |
| S | Secrets | `shipyard:secrets`, `guard-secrets` hook | `.shipyard/secrets.list`, `bin/with-secrets`, config module |
| V | Evidence on every PR | `shipyard:evidence`, `evidence`, PR gate hook, CI job | `docs/evidence/<worksheet>/`, `.shipyard/ui-paths` |
| M | Merge risk | `shipyard:review` (merge-risk stage) | `## Merge risk` in every PR body |
| X | Security tools | `shipyard:security-scans`, `scan-skills`, install gate hook | `docs/security/` |
| E | Understanding outputs | `shipyard:explain`, Whiteboard | `.shipyard/explainers/` (gitignored) |

## What's enforced by code

Skills are instructions. These parts are hooks and scripts, so they hold even when an agent doesn't follow instructions:

**Stop hook** (`scripts/stop-verify.sh`, set-up projects only). Every time the agent tries to finish with uncommitted changes, it runs `bin/verify`. If verify fails, the agent gets the last 60 lines of output and has to keep going. If it stops again without changing anything, the hook lets it stop and shows you a message instead of looping. It also reminds the agent once per session about the worksheet and feedback log.

**Edit guard** (`scripts/guard-edits.sh`, set-up projects only). Three rules, each driven by a list in `.shipyard/`:

- `protected-paths`: acceptance tests and baselines can be created, then not modified.
- `test-paths`: only `shipyard:test-writer` can create or edit test files, and it can't edit source.
- `env-allowed-paths`: new `process.env`, `os.environ` and similar reads are only allowed in the config module.

**Secrets guard** (`scripts/guard-secrets.sh`, every project). Blocks commands that would put a secret in the agent's context: environment dumps, inline scripts that read the environment, echoing secret-looking variables, direct vault reads, and reading credential files with Bash or the Read tool.

**PR gate** (`scripts/guard-pr.sh`, set-up projects only). `gh pr create` and `gh pr ready` are blocked until `evidence check --branch` passes and the PR body has the `## Evidence` section. Docs-only branches pass.

**Install gate** (`scripts/guard-installs.sh`, every project). Installing a skill, plugin, marketplace or MCP server asks you first, with a reminder to scan it with SkillSpector.

**CI** (the project's `verify.yml`). Runs `bin/verify --full`, and fails any PR whose description has no Evidence section with a screenshot, recording or transcript, unless it has the `no-evidence` label.

**`bin/with-secrets`** fetches the secrets named in `.shipyard/secrets.list` from Google Secret Manager and runs a command with them set. The agent never sees a value.

**Env scrub** (`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` in project settings and night shift runs) strips credentials from every command, hook and MCP server Claude Code starts. It's the strongest secrets layer. The guard is a backstop.

**Night shift launcher** (`bin/night-shift`). Separate worktree and branch, per-task cost and turn caps, overall time and budget limits, OS sandbox with no escape, pushes and vault reads denied, env scrub on. Each task runs as a `/goal` with a fixed completion condition, and each run is logged to a metrics CSV.

## Reviews, evidence and explanations

- **Agent reviews** at each checkpoint: `shipyard:reviewer` on a different Claude model, `agent_review` for a different model family, `shipyard:security-reviewer` for anything security-relevant, and `shipyard:ui-reviewer` (impeccable's critique and audit on real screenshots) for anything visual.
- **Claims tables:** research and docs reviews check every factual claim against evidence the reviewer opened (`file:line`, or a primary source URL with the date checked), with a verdict of verified, incorrect or unresolved.
- **Evidence:** every PR shows the change working in the real app. Screenshots per acceptance criterion, a recording for UI changes, terminal transcripts for CLIs and APIs, recorded with `evidence` and the Playwright template in `shipyard:evidence`.
- **Merge risk:** an independent reviewer grades every PR (alignment, impact, verification, rollback cost, error detection) as low, medium or high, using Warp's `merge-risk` skill. The grade tells you how closely to review. It never merges anything by itself.
- **Human review:** for medium tasks and up and every night shift task, the agent authors a Whiteboard with the merge-risk grade, review verdicts and evidence screenshots at the top. Without Whiteboard, it writes an HTML explainer instead.
- **Explaining:** `shipyard:explain` sets the format ladder: about 80% ASD-STE100 prose, diagrams, Whiteboards, self-contained HTML pages, and narrated explainer videos when you ask for one.

## Effort

Everything runs at high effort by default:

- All four agents (`reviewer`, `test-writer`, `security-reviewer`, `ui-reviewer`) set `effort: high`.
- The project settings template sets `"effortLevel": "high"` for the main session.
- `night-shift` passes `--effort high`, and `agent_review` asks Claude and Codex reviewers for high effort.

To change it:

| Scope | How |
|---|---|
| Everything at once, agents included | Start Claude Code with `CLAUDE_CODE_EFFORT_LEVEL=medium` (or any level). It overrides every other setting |
| The main session | `/effort` in the session, or `effortLevel` in the project's `.claude/settings.json` |
| One agent | Edit its `effort:` line in `agents/<name>.md` here, or ask Claude to run it at a given effort for one task |
| Night shift | `night-shift --effort medium` |
| Review and lint-fix CLIs | `SHIPYARD_CLAUDE_REVIEW_EFFORT`, `SHIPYARD_CODEX_EFFORT`, `SHIPYARD_FIX_EFFORT` (empty means the tool's default) |

## Measuring the setup

Each worksheet has a Metrics block: model and effort, plugin version, cost, turns, wall time, merge risk, review rounds, finding dispositions, test-writer's suspected bugs, and three fields only you fill in (corrections needed after your review, your review minutes, accepted or not). Night shift runs log cost, turns and duration to a CSV automatically. `/shipyard:feedback ingest` summarizes them per accepted task. Change one thing at a time and compare the next batch of accepted tasks.

## Environment variables

| Variable | Effect |
|---|---|
| `SHIPYARD_SKIP_VERIFY=1` | Turn off the Stop hook for a session |
| `SHIPYARD_UNLOCK=1` | Allow edits to protected paths for a session |
| `SHIPYARD_ALLOW_AUTHOR_TESTS=1` | Let any agent edit tests for a session (mass renames, framework migrations) |
| `SHIPYARD_ALLOW_ENV_READ=1` | Turn off both env guards for a session |
| `SHIPYARD_ALLOW_NO_EVIDENCE=1` | Turn off the PR gate for a session |
| `SHIPYARD_ALLOW_INSTALLS=1` | Turn off the install gate for a session |
| `CLAUDE_CODE_EFFORT_LEVEL` | One effort level for the session and every agent |
| `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` | Claude Code's own credential scrub. Setup puts it in the project settings |
| `SHIPYARD_AUTHOR` | Model family that wrote the code, for `agent_review` (default `claude`) |
| `SHIPYARD_REVIEW_ORDER` | CLI preference for `agent_review --cli auto` (default `codex gemini cursor claude`) |
| `SHIPYARD_CODEX_MODEL`, `SHIPYARD_GEMINI_MODEL`, `SHIPYARD_CURSOR_MODEL`, `SHIPYARD_CLAUDE_REVIEW_MODEL` | Model per review CLI |
| `SHIPYARD_CURSOR_FAMILY` | Family of the Cursor model you picked, so auto doesn't pick Claude-through-Cursor to review Claude |
| `SHIPYARD_CLAUDE_REVIEW_EFFORT`, `SHIPYARD_CODEX_EFFORT`, `SHIPYARD_FIX_EFFORT` | Effort for review and lint-fix CLIs (default `high`) |
| `SHIPYARD_FIX_CLI`, `SHIPYARD_FIX_MODEL` | CLI and model for `bin/llm-fix` (default `claude`, `sonnet`) |
| `SHIPYARD_LLM_FIX=0` | Skip the LLM pass in `bin/lint-fix` |
| `GOOGLE_CLOUD_PROJECT` | Default project for `bin/with-secrets` (else gcloud's configured project) |

## Known limits

- The guards match what Claude's tools are asked to do. An agent could still write a test file or print a variable through a script it writes and then runs. The env scrub, the reviewers and the night shift sandbox are the layers behind them.
- The reviewers have Bash so they can run `git diff` and tests, which makes them read-only by instruction, not enforcement. Claude Code ignores hooks on plugin subagents.
- The install gate asks you, so in a headless run (where nobody can answer) installs are refused.
- `agent_review`'s runners for Codex, Gemini and Cursor use each CLI's non-interactive mode as documented when this was written. Check them against `--help` the first time you use one.
- SkillSpector and Strix weren't installed where this was built, so `scan-skills` was tested against a stand-in with SkillSpector's documented JSON format. Run `scan-skills` once after installing the real tool and check the summary.
- `evidence pr-body` links to files on the pushed branch, so push before opening the PR. Without git LFS, keep recordings small.
- `bin/with-secrets` reads Google Secret Manager via gcloud, or runs `infisical run` when `.shipyard/config` sets `vault = infisical`. Projects with their own runner set `secrets_runner` instead.
- `bin/verify` runs on every agent stop where something changed, so keep fast mode to a few minutes, and never let it print environment values.

## Layout

```
.claude-plugin/   plugin.json, marketplace.json
agents/           reviewer, test-writer, security-reviewer, ui-reviewer   (all at effort: high)
bin/              agent_review, evidence, night-shift, scan-skills, shipyard-config, worksheet   (on the agent's PATH)
hooks/            hooks.json
scripts/          lib.sh (shared config helpers), stop-verify.sh, guard-edits.sh, guard-secrets.sh, guard-pr.sh, guard-installs.sh
skills/           setup (with templates/), workflow, spec, system-docs, testing, lint-rule,
                  review (with personas/), evidence, security-scans, secrets, explain, worksheet,
                  feedback, task-queue, build-tool, sweep, night-shift, test-audit,
                  visual-regression, perf, end-of-shift
```
