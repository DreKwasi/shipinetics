# Shipinetics

A portable agentic coding setup for Claude Code. Install it once and every project gets the same workflow, review process and guardrails:

- A Stop hook that won't let the agent finish while checks fail. Checks run in tiers, each at the moment its result is needed: quick ones at mid-task stops, every fast check before work counts as done, the full suite in CI. Nothing is skipped, and a pass is reused until the code changes.
- Tests written by an independent agent, never by the one that wrote the code.
- A verification map of the real app (launch, health check, every feature and every way a user reaches it), so any agent can prove a change works the way a user would. A reviewer re-drives the change itself instead of trusting the author's screenshots.
- Every PR carries fresh evidence from the running app (screenshots, recordings, transcripts) and an independent merge-risk grade.
- UI changes checked against the project's own design system (DESIGN.md), which setup writes from the tokens the code already uses.
- Secrets that stay in the vault and out of the agent's context.
- Read-only reviewers on different models, including security (Cloudflare's security-audit skill) and frontend (impeccable), all at high effort.
- Security scanning of agent tooling (NVIDIA SkillSpector) and of your app (Strix), with you approving every app test.
- Whiteboards and HTML explainers so you can understand what the agents did, with claims checked against sources.
- Worksheets that let another agent pick up a half-done task, with metrics to measure the setup on accepted work.
- A night shift launcher with hard limits.

It has two layers:

- **The plugin** (this repo) carries the generic parts: skills, subagents, hooks and scripts. Update it in one place and every project gets the change.
- **The project** gets the specific parts, written into the repo by `/shipinetics:setup` and committed: `AGENTS.md`, `bin/verify`, `bin/with-secrets`, the `.shipinetics/` lists, system docs, conventions, test docs and the task queue. They live in the repo so CI, teammates and other agents (Codex, Cursor) can use them without the plugin.

[GETTING-STARTED.md](GETTING-STARTED.md) walks through the rollout step by step.

## Install

Locally, while it's not on GitHub yet:

```bash
claude plugin marketplace add ~/Projects/shipinetics
```

```bash
claude plugin install shipinetics@shipinetics
```

Once it's in a GitHub repo, use `claude plugin marketplace add <owner>/<repo>` on any machine, then the same install command. To try it for one session without installing, run `claude --plugin-dir ~/Projects/shipinetics`.

### Companions (install separately)

shipinetics uses these when they're installed and falls back when they aren't. `/shipinetics:setup` checks for them. Scan each with SkillSpector before installing it.

| Companion | Used by | Install |
|---|---|---|
| Cloudflare `security-audit` skill | `shipinetics:security-reviewer` | `npx skills add cloudflare/security-audit-skill` |
| Impeccable plugin | `shipinetics:ui-reviewer`, `design-check`, the design-system setup step, HTML explainers | `/plugin marketplace add pbakaus/impeccable`, then install it from `/plugin`. Avoid `npx skills add pbakaus/impeccable` for Claude Code: it installs the repo's `.agents/skills/` copy, written for Codex |
| Matt Pocock's skills (optional) | `grilling` and `domain-modeling` before specs and L splits, `codebase-design`, `diagnosing-bugs`, `prototype`, `research` | `claude plugin install mattpocock-skills@claude-plugins-official`. Some of the others in that pack clash with shipinetics's rules: `shipinetics:workflow` lists which to leave alone |
| `merge-risk` skill (Warp) | Merge-risk grades on every PR | `npx skills add warpdotdev/common-skills --skill merge-risk` |
| NVIDIA SkillSpector | `scan-skills`, the install gate | `uv tool install git+https://github.com/NVIDIA/skillspector.git` |
| Strix | App security testing (shipinetics:security-scans) | See its README. Needs Docker and a provider key in your vault |
| dev.fast Whiteboard plugin | Whiteboards of changes for human review | from the dev.fast marketplace |
| Codex, Gemini or Cursor CLI | `agent_review` cross-family reviews | each tool's installer |

They aren't declared as hard plugin dependencies on purpose. A missing hard dependency stops the whole plugin from loading, and some of them (Whiteboard, Docker) won't exist in CI or on every machine.

### Other skill packs

Shipinetics borrows the strongest ideas from Matt Pocock's skills and from pstack (Lauren Tan's skill stack for Cursor) instead of running them side by side. The verification map and the independent re-check come from pstack's verification skills, and the review filters, blast-radius ladder, test rules and feedback criteria come from both. Running those packs' routers, `tdd`, `implement` or autopilot playbooks next to shipinetics bypasses its rules (test-writer owns tests, a different model reviews, nothing merges by itself). `shipinetics:workflow` lists what fits and what to leave out.

## Projects with their own setup, and multi-repo workspaces

Shipinetics's paths and commands are defaults. A project can map them to what it already has in `.shipinetics/config` (template: `skills/setup/templates/config`): worksheet folder, feedback log, system docs, conventions, test docs, verify command, worksheet scripts, tag prefix and secrets runner. Skills, hooks and tools then use the project's own files. `shipinetics-config` prints the effective settings, and `shipinetics-config match <list> <path>` shows which glob in a list (protected-paths, test-paths and the rest) covers a path, exactly as the guards match it. Set `launch = user` when the user runs the dev servers: agents then only run the doctor, never seed or reset, write only as a test account and clean up after themselves, and use the harness's preview browser if the sandbox blocks localhost (see shipinetics:verification-map).

Workspace mode (`packages = ...`) is for a root that holds several package repos and isn't a repo itself. The Stop hook runs `package_verify_cmd` (or `package_verify_quick_cmd` mid-task) for each package the agent edited in that session, so the user's unrelated work in progress never blocks it. The PR gate and `evidence` work from whichever package repo the PR comes from. The root's own files (`.shipinetics/`, the queue, worksheets, docs) belong in a git repo too: the root itself, ignoring the package folders, or a separate repo named by `harness_repo`. `shipinetics-config` warns when they aren't. With that in place, `night-shift` gives the shift a worktree of the harness repo with a worktree of each package inside it, all on `night/<date>`.

`/shipinetics:setup` audits first, asks all its questions in one message (including anything it could only infer from comments or old docs), then installs every phase in one run with a commit per phase.

## How the points map to the plugin

| # | Point | Plugin | In the project |
|---|---|---|---|
| 0 | Router | setup writes it | `AGENTS.md`, `CLAUDE.md` (imports `@AGENTS.md`) |
| 1 | Workflow | `shipinetics:workflow` | your `AGENT_WORKFLOW.md` overrides it if present |
| 2 | Self-healing docs | `shipinetics:system-docs` (with claims checked against sources) | `docs/systems/*.md` with 7-line headers |
| 3 | Run the app | `shipinetics:verification-map`, `shipinetics:workflow` step 6 | `docs/verification/` (launch, doctor, drive, cleanup, a file per feature), "Run the app yourself" in `AGENTS.md` |
| 4 | Tests | `shipinetics:testing`, `shipinetics:test-writer`, `shipinetics:spec` | `docs/testing/`, `e2e/`, `.shipinetics/test-paths` |
| 5 | Linters that fix | `shipinetics:lint-rule` | `bin/lint-fix`, `bin/llm-fix`, `.githooks/pre-commit` (also caps commits at 400 changed lines), `.githooks/commit-msg` (requires the `Worksheet:` trailer) |
| 6 | Cross-agent review | `shipinetics:review`, four reviewer agents, `agent_review`, 7 personas | `docs/review/personas/` for domain personas |
| 7 | Worksheets and tags | `shipinetics:worksheet`, `worksheet` | `docs/worksheets/`, `ws/*` tags, `Worksheet:` commit trailers |
| 8 | Session feedback | `shipinetics:feedback`, Stop hook reminder | `docs/agent-feedback.md` |
| 9 | Agent-built tools | `shipinetics:build-tool` | `bin/`, `docs/tools.md` |
| 10 | Commit sweeps | `shipinetics:sweep` | `docs/sweeps/`, `sweep/*` tags |
| 11 | Conventions | `shipinetics:lint-rule` moves them into linters | `docs/conventions.md` |
| 12 | Night shift | `shipinetics:night-shift`, `night-shift` launcher | `TODOS.md`, `.claude/settings.json` |
| 13 | Task queue | `shipinetics:task-queue` | `TODOS.md`, or Linear through `bin/tasks` |
| 14 | False-confidence audit | `shipinetics:test-audit` (mutation checks, bloat pruning) | `docs/test-audits/` |
| 15 | Visual regression | `shipinetics:visual-regression`, `shipinetics:ui-reviewer` | screenshot tests, LFS or PR artifacts |
| 16 | Perf benchmarks | `shipinetics:perf` | `perf/baselines/`, `bin/bench` |
| 17 | Profiling | `shipinetics:perf` (experiment protocol) | `docs/perf/experiments.md` |
| 18 | End of shift | `shipinetics:end-of-shift` | `bin/verify --full`, `docs/shifts/*.md` and `*.html` |
| S | Secrets | `shipinetics:secrets`, `guard-secrets` hook | `.shipinetics/secrets.list`, `bin/with-secrets`, config module |
| V | Evidence on every PR | `shipinetics:evidence`, `evidence`, PR gate hook, CI job | `docs/evidence/<worksheet>/`, `.shipinetics/ui-paths` |
| D | Design system | `design-check`, `shipinetics:ui-reviewer`, setup's design-system step (Impeccable's `document`) | `DESIGN.md` with token frontmatter, `PRODUCT.md`, design-system change requests in worksheets |
| M | Merge risk | `shipinetics:review` (merge-risk stage) | `## Merge risk` in every PR body |
| X | Security tools | `shipinetics:security-scans`, `scan-skills`, install gate hook | `docs/security/` |
| E | Understanding outputs | `shipinetics:explain`, Whiteboard | `.shipinetics/explainers/` (gitignored) |

## What's enforced by code

Skills are instructions. These parts are hooks and scripts, so they hold even when an agent doesn't follow instructions:

**Stop hook** (`scripts/stop-verify.sh`, set-up projects only). Every time the agent tries to finish with changes, it runs the project's checks. Changes means uncommitted changes or commits made since the session started, so an agent that commits each step and stops on a clean tree is still checked. Which tier runs depends on the moment (see "When checks run" below). If a check fails, the agent gets the last 60 lines of output and has to keep going. If it stops again without changing anything, the hook lets it stop and shows you a message instead of looping. When only the quick tier has run, it tells you so. It also reminds the agent once per session about the worksheet and feedback log, and, when the worksheet is a bug fix (`Type: bug`, or bug, fix, crash, regression or Sentry in its title) and the session changed code but no tests, to get a failing regression test from test-writer first.

**Pre-push hook** (`.githooks/pre-push`, installed by setup). The complete verify must pass before code leaves the machine. It reuses a recorded pass, so it costs nothing after the agent verified.

**Edit guard** (`scripts/guard-edits.sh`, set-up projects only). Three rules, each driven by a list in `.shipinetics/`:

- `protected-paths`: acceptance tests and baselines can be created, then not modified. To change one, an agent writes the new version to `.shipinetics/pending/<path>`, and you review and apply it with `shipinetics-config apply` (it needs a terminal, so an agent's Bash tool can't run it by accident; like the guards, it's a speed bump, not a lock). `shipinetics-config pending` lists what's waiting. The same route covers `.claude/settings.json`, which Claude Code doesn't let agents edit.
- `test-paths`: only `shipinetics:test-writer` can create or edit test files, and it can't edit source.
- `env-allowed-paths`: new `process.env`, `os.environ` and similar reads are only allowed in the config module. Docs and text files (`.md`, `.txt`, `docs/`) and reads of the safe variables above don't count.

**Known failures** (`bin/known-failing`). A suite that already fails can be gated on new failures only: `bin/verify` runs `known-failing check <junit.xml>` against the protected `.shipinetics/known-failing` list (shipinetics:testing).

**Secrets guard** (`scripts/guard-secrets.sh`, every project). Blocks commands that would put a secret in the agent's context: environment dumps, inline scripts that read the environment, echoing secret-looking variables, direct vault reads, and reading credential files with Bash or the Read tool. It ignores what only mentions the environment: heredoc bodies written to a file, the pattern given to grep, rg and similar, and reads of variables that never hold secrets (`HOME`, `PATH`, `TMPDIR`, `NODE_ENV`, `CI` and the like, plus `env_safe_names` in the project config). Deny messages name the project's `secrets_runner`.

**PR gate** (`scripts/guard-pr.sh`, set-up projects only). `gh pr create` and `gh pr ready` are blocked until `evidence check --branch` passes, the complete verify has passed on exactly this code, and the PR body has the `## Evidence` section. `evidence check` also fails when code changed after the evidence was recorded (docs, tests and records don't count). Docs-only branches pass.

**Install gate** (`scripts/guard-installs.sh`, every project). Installing a skill, plugin, marketplace or MCP server asks you first, with a reminder to scan it with SkillSpector.

**CI** (the project's `verify.yml`). Runs `bin/verify --full`, and fails any PR whose description has no Evidence section with a screenshot, recording or transcript, unless it has the `no-evidence` label.

**`bin/with-secrets`** fetches the secrets named in `.shipinetics/secrets.list` from Google Secret Manager and runs a command with them set. The agent never sees a value.

**Env scrub** (`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` in project settings and night shift runs) strips credentials from every command, hook and MCP server Claude Code starts. It's the strongest secrets layer. The guard is a backstop.

**Night shift launcher** (`bin/night-shift`). Separate worktree and branch, per-task cost and turn caps, overall time and budget limits, OS sandbox with no escape, pushes and vault reads denied, env scrub on. Each task runs as a `/goal` with a fixed completion condition, and each run is logged to a metrics CSV.

## When checks run

Each check runs at the earliest moment its result is useful and the latest moment before something depends on it. None is dropped to save time.

| Moment | What runs | Blocks |
|---|---|---|
| Commit | Lint and fix on staged files (pre-commit hook) | The commit |
| Mid-task stop | `bin/verify --quick` (`verify_quick_cmd`): lint the changed files, incremental typecheck, tests related to the changes. The complete tier instead when a path in `.shipinetics/complete-paths` changed (build config, manifests, lockfiles) | The stop |
| "Done" stop (worksheet `Status: done`) | `bin/verify`, every fast check, including the build and e2e smoke | Reporting the work as done |
| Push, PR | A recorded complete pass for exactly this code | The push, the PR |
| CI | `bin/verify --full`, without local caches | The merge |
| End of shift, weekly | `--full`, visual and perf, sweep, verification-map drift, design-system drift | Report |

A pass is recorded against a hash of the code's contents, not the commit, so committing verified code or editing only worksheets, evidence and the feedback log doesn't run anything again. Run `shipinetics-verify` to run a tier and record it, `shipinetics-verify status` to see what has passed on the current code, and `shipinetics-verify times` for where verify time goes. A project without `verify_quick_cmd` runs the complete tier at every stop, as before.

## Reviews, evidence and explanations

- **Agent reviews** at each checkpoint: `shipinetics:reviewer` on a different Claude model, `agent_review` for a different model family, `shipinetics:security-reviewer` for anything security-relevant, and `shipinetics:ui-reviewer` for anything visual. The UI reviewer checks conformance to DESIGN.md first (`design-check` plus a manual pass for what the detector can't see), then runs Impeccable's critique and audit on real screenshots. Findings from several reviewers are merged and filtered before the author acts on them.
- **Independent re-check:** for medium tasks and up, UI changes and every night shift task, the wrap-up reviewer drives the change itself from the verification map, through every entry point, at the final code, and reports PASS, ISSUES or BLOCKED.
- **Design system:** agents never change tokens to make a finding go away. They propose the change in the worksheet's "Design-system change requests", and you decide. Setup can protect the design files so that's enforced.
- **Claims tables:** research and docs reviews check every factual claim against evidence the reviewer opened (`file:line`, or a primary source URL with the date checked), with a verdict of verified, incorrect or unresolved.
- **Evidence:** every PR shows the change working in the real app. Screenshots per acceptance criterion, a recording for UI changes, terminal transcripts for CLIs and APIs, recorded with `evidence` and the Playwright template in `shipinetics:evidence`.
- **Merge risk:** an independent reviewer grades every PR (alignment, impact, verification, rollback cost, error detection) as low, medium or high, using Warp's `merge-risk` skill. The grade tells you how closely to review. It never merges anything by itself.
- **Human review:** for medium tasks and up and every night shift task, the agent authors a Whiteboard with the merge-risk grade, review verdicts and evidence screenshots at the top. Without Whiteboard, it writes an HTML explainer instead.
- **Explaining:** `shipinetics:explain` sets the format ladder: about 80% ASD-STE100 prose, diagrams, Whiteboards, self-contained HTML pages, and narrated explainer videos when you ask for one.

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
| Review and lint-fix CLIs | `SHIPINETICS_CLAUDE_REVIEW_EFFORT`, `SHIPINETICS_CODEX_EFFORT`, `SHIPINETICS_FIX_EFFORT` (empty means the tool's default) |

## Measuring the setup

Each worksheet has a Metrics block: model and effort, plugin version, cost, turns, wall time, merge risk, review rounds, finding dispositions, test-writer's suspected bugs, and three fields only you fill in (corrections needed after your review, your review minutes, accepted or not). Night shift runs log cost, turns and duration to a CSV automatically. `/shipinetics:feedback ingest` summarizes them per accepted task. Change one thing at a time and compare the next batch of accepted tasks.

## Environment variables

| Variable | Effect |
|---|---|
| `SHIPINETICS_SKIP_VERIFY=1` | Turn off the Stop hook, and the PR gate's verify check, for a session |
| `SHIPINETICS_UNLOCK=1` | Allow edits to protected paths for a session |
| `SHIPINETICS_ALLOW_AUTHOR_TESTS=1` | Let any agent edit tests for a session (mass renames, framework migrations) |
| `SHIPINETICS_ALLOW_ENV_READ=1` | Turn off both env guards for a session |
| `SHIPINETICS_ALLOW_NO_EVIDENCE=1` | Turn off the PR gate for a session |
| `SHIPINETICS_ALLOW_INSTALLS=1` | Turn off the install gate for a session |
| `SHIPINETICS_ALLOW_NO_WORKSHEET=1` | Let one commit through without a `Worksheet:` trailer (work that belongs to no task) |
| `SHIPINETICS_ALLOW_BIG_COMMIT=1` | Let one commit through over the size limit (a codemod, a vendored library). Say why in the message |
| `CLAUDE_CODE_EFFORT_LEVEL` | One effort level for the session and every agent |
| `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` | Claude Code's own credential scrub. Setup puts it in the project settings |
| `SHIPINETICS_AUTHOR` | Model family that wrote the code, for `agent_review` (default `claude`) |
| `SHIPINETICS_REVIEW_ORDER` | CLI preference for `agent_review --cli auto` (default `codex gemini cursor claude`) |
| `SHIPINETICS_CODEX_MODEL`, `SHIPINETICS_GEMINI_MODEL`, `SHIPINETICS_CURSOR_MODEL`, `SHIPINETICS_CLAUDE_REVIEW_MODEL` | Model per review CLI |
| `SHIPINETICS_CURSOR_FAMILY` | Family of the Cursor model you picked, so auto doesn't pick Claude-through-Cursor to review Claude |
| `SHIPINETICS_CLAUDE_REVIEW_EFFORT`, `SHIPINETICS_CODEX_EFFORT`, `SHIPINETICS_FIX_EFFORT` | Effort for review and lint-fix CLIs (default `high`) |
| `SHIPINETICS_FIX_CLI`, `SHIPINETICS_FIX_MODEL` | CLI and model for `bin/llm-fix` (default `claude`, `sonnet`) |
| `SHIPINETICS_LLM_FIX=0` | Skip the LLM pass in `bin/lint-fix` |
| `SHIPINETICS_BENCH_MACHINE` | Machine name for `bench-compare` baselines (default `<host>-<arch>`). Set it in CI so runners share one baseline |
| `GOOGLE_CLOUD_PROJECT` | Default project for `bin/with-secrets` (else gcloud's configured project) |

## Known limits

- The guards match what Claude's tools are asked to do. Maintenance on guarded files goes through a human or a named command (`shipinetics-config apply`, `bench-compare --init`, `known-failing init`), as the setup skill lists. An agent could still write a test file or print a variable through a script it writes and then runs. The env scrub, the reviewers and the night shift sandbox are the layers behind them.
- The reviewers have Bash so they can run `git diff` and tests, which makes them read-only by instruction, not enforcement. Claude Code ignores hooks on plugin subagents.
- The install gate asks you, so in a headless run (where nobody can answer) installs are refused.
- `agent_review`'s runners for Codex, Gemini and Cursor use each CLI's non-interactive mode as documented when this was written. Check them against `--help` the first time you use one.
- SkillSpector and Strix weren't installed where this was built, so `scan-skills` was tested against a stand-in with SkillSpector's documented JSON format. Run `scan-skills` once after installing the real tool and check the summary.
- `evidence pr-body` links to files on the pushed branch, so push before opening the PR. Without git LFS, keep recordings small.
- `bin/with-secrets` reads Google Secret Manager via gcloud, or runs `infisical run` when `.shipinetics/config` sets `vault = infisical`. Projects with their own runner set `secrets_runner` instead.
- The Stop hook can't tell a pause from a finished task by itself. The worksheet's `Status: done` is the signal for the complete tier. If an agent never sets it, the complete tier still runs at push and PR, but not at its last stop. Keep `--quick` to seconds and the complete tier to a few minutes, and never let either print environment values.
- `design-check` sees fonts, colors, radii and font sizes outside DESIGN.md's frontmatter. Spacing, unknown `var()` names, new token definitions and duplicated components are left to the UI reviewer. Without token frontmatter in DESIGN.md there's nothing to check against.

## Layout

```
.claude-plugin/   plugin.json, marketplace.json
agents/           reviewer, test-writer, security-reviewer, ui-reviewer   (all at effort: high)
bin/              agent_review, bench-compare, design-check, evidence, known-failing, night-shift, scan-skills, shipinetics-config,
                  shipinetics-verify, worksheet   (on the agent's PATH)
hooks/            hooks.json
scripts/          lib.sh (shared config helpers), stop-verify.sh, guard-edits.sh, guard-secrets.sh, guard-pr.sh, guard-installs.sh
skills/           setup (with templates/), workflow, spec, system-docs, testing, lint-rule,
                  review (with personas/), evidence, security-scans, secrets, explain, worksheet,
                  feedback, task-queue, build-tool, sweep, night-shift, test-audit,
                  visual-regression, perf, end-of-shift, verification-map
tests/            shipinetics's own tests for the hooks and tools. Run tests/run.sh (CI runs it on
                  Linux and on macOS's bash 3.2)
```
