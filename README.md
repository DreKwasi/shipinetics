# Shipinetics

Shipinetics is a plugin for Claude Code. It gives every project the same workflow, reviews and guardrails. You install it one time. Then each project gets these parts:

- **A Stop hook.** The agent cannot stop while the project's checks fail. Checks run in tiers: quick checks while the agent works, all fast checks before the work is done, and the full suite in CI. No check is skipped. A pass stays valid until the code changes.
- **Independent tests.** A separate agent writes the tests, never the agent that wrote the code. It writes one test for each behaviour that a user or caller can see, never one test for each function.
- **A verification map.** It tells any agent how to start the real app, check it, and use each feature the way a user does. A reviewer uses the feature again by itself. It does not trust the author's screenshots.
- **Evidence on every PR.** Each PR shows the change in the running app: screenshots, a recording, or terminal output. An independent reviewer gives each PR a merge-risk grade.
- **Design checks.** UI changes are compared with the project's design system (`DESIGN.md`). Setup writes `DESIGN.md` from the tokens that the code already uses.
- **Secrets stay hidden.** Secrets stay in the vault. The agent never sees their values.
- **Reviewers on other models.** The reviewers are read-only. They include a security reviewer (Cloudflare's security-audit skill) and a UI reviewer (Impeccable).
- **Security scans.** SkillSpector scans agent tools before you install them. Strix tests your own app, but only after you approve each run. A full security audit runs on the schedule that you choose.
- **Explanations.** Whiteboards and HTML pages show you what the agents did. All text for people uses ASD-STE100 (Simplified Technical English).
- **Worksheets.** Each task has a worksheet. Another agent can continue a task from its worksheet.
- **A night shift.** A launcher runs tasks without a person, inside hard limits.

## Two layers

- **The plugin** (this repo) has the general parts: skills, agents, hooks and tools. When you update the plugin, every project gets the change.
- **The project** has its own parts. `/shipinetics:setup` writes them into the repo, and you commit them. Examples: `AGENTS.md`, `bin/verify`, `bin/with-secrets`, the lists in `.shipinetics/`, the system docs and the task queue. CI, other people and other agents (Codex, Cursor) can use these files without the plugin.

[GETTING-STARTED.md](GETTING-STARTED.md) gives the steps to start, one by one.

## Install

```bash
claude plugin marketplace add DreKwasi/shipinetics
```

```bash
claude plugin install shipinetics@shipinetics
```

To try the plugin for one session without an install, run `claude --plugin-dir <path to a clone of this repo>`.

## Update

Each release has a version. [CHANGELOG.md](CHANGELOG.md) shows what changed.

1. Update the plugin:

   ```bash
   claude plugin marketplace update shipinetics
   claude plugin update shipinetics@shipinetics
   ```

2. Restart Claude Code.
3. Read the changelog entry. If it has a **breaking** change, do the steps it gives in each project.

The plugin update changes the skills, agents, hooks and tools. It does not change the files that setup copied into your projects. To compare a project with the newest templates, run `/shipinetics:setup audit` in the project. Setup merges changes into your files. It never overwrites them.

## Companions

Shipinetics uses these tools when they are installed. When a tool is missing, Shipinetics uses a simpler method. `/shipinetics:setup` checks for each tool. Scan each tool with SkillSpector before you install it.

| Companion | What uses it | Install |
|---|---|---|
| Cloudflare `security-audit` skill | The security reviewer, and the full security audit (on the schedule in `security_audit_every`) | `npx skills add cloudflare/security-audit-skill -g -a claude-code` |
| Impeccable plugin | The UI reviewer, `design-check`, the design-system setup step, HTML pages | `/plugin marketplace add pbakaus/impeccable`, then install it from `/plugin`. Do not use `npx skills add pbakaus/impeccable`: that copy is for Codex |
| Matt Pocock's skills (optional) | `grilling` and `domain-modeling` before specs and before decisions that are hard to reverse. `/wait-what` when a message is not clear. `codebase-design`, `diagnosing-bugs`, `prototype`, `research` | `npx skills add mattpocock/skills --skill <name> -g -a claude-code`, one time for each skill. Some skills in this pack conflict with Shipinetics. `shipinetics:workflow` lists them |
| `merge-risk` skill (Warp) | The merge-risk grade on each PR | `npx skills add warpdotdev/common-skills --skill merge-risk -g -a claude-code` |
| NVIDIA SkillSpector | `scan-skills` and the install gate | `uv tool install git+https://github.com/NVIDIA/skillspector.git` |
| Strix | Security tests of your app (shipinetics:security-scans) | See its README. It needs Docker and a provider key in your vault |
| dev.fast Whiteboard plugin | Whiteboards of changes, for your review | From the dev.fast marketplace |
| Codex, Gemini or Cursor CLI | `agent_review`: a review from a different model family | The installer of each tool |

These tools are not hard dependencies of the plugin. If a hard dependency is missing, the whole plugin does not load. Also, some tools (Whiteboard, Docker) are not on every machine or in CI.

### Keep the companions up to date

Companions change upstream, and Shipinetics depends on some of their details. The weekly sweep checks for updates. Only you apply them.

1. **Check.** The sweep runs `skills-outdated`. This tool compares each installed skill with its repo. It changes nothing. For plugins, the sweep compares `claude plugin list` with each marketplace.
   Do not use `npx skills check` to look for updates. It can update and remove skills while it checks. The install gate asks you before an agent runs it.
2. **Scan.** Scan the new version with SkillSpector (shipinetics:security-scans).
3. **Update.** For skills: `npx skills update -g <names>`. For plugins: `claude plugin marketplace update <marketplace>`, then `claude plugin update <plugin>@<marketplace>`. For CLIs: use their own installers. The install gate asks you before an agent runs these commands.
4. **Check again.** The sweep reads each updated companion and compares it with the table below. If a detail that Shipinetics needs changed, the sweep adds a task to the queue.

`skills-outdated` reads the lock file of the `skills` CLI (`~/.agents/.skill-lock.json`). It only sees skills that the CLI installed. Install skills with the CLI and `-g`.

### What Shipinetics needs from each companion

| Companion | Shipinetics needs |
|---|---|
| `security-audit` | A guidance mode for one change. A full six-phase mode that writes its report outside the repo (default `~/security-audit-skill/<repo>/run-<N>`). Its severity names |
| Impeccable | The `critique`, `audit`, `document` and `detect` commands. A `DESIGN.md` with token frontmatter |
| `grilling` | A recommended answer for each question. The agent finds facts itself, and does not ask you for them |
| `domain-modeling` | The glossary in `GLOSSARY.md` (`GLOSSARY-MAP.md` when there are several). Decision records (ADRs) in `docs/adr/` |
| `wait-what` | A new explanation in ASD-STE100, with the terms from `GLOSSARY.md` |
| `diagnosing-bugs` | Its phases 1 to 6. The regression test is in phase 5 |
| `merge-risk` | A grade of low, medium or high, with the files that caused the grade |

### Other skill packs

Shipinetics takes the best ideas from Matt Pocock's skills and from pstack (Lauren Tan's skills for Cursor). It does not run them next to its own skills. The verification map and the independent check come from pstack. The review filters, test rules and feedback rules come from both packs. Do not run their routers, `tdd`, `implement` or autopilot playbooks with Shipinetics. They skip its rules: test-writer writes all tests, a different model reviews, and nothing merges by itself. `shipinetics:workflow` lists what to use and what not to use.

## Projects with their own setup, and multi-repo workspaces

Shipinetics has default paths and commands. A project can change them in `.shipinetics/config` (the template is `skills/setup/templates/config`). For example, you can set the worksheet folder, the feedback log, the system docs, the verify command and the secrets runner. Then the skills, hooks and tools use the project's own files.

Two commands help:

- `shipinetics-config` shows all settings, and which ones the project set.
- `shipinetics-config match <list> <path>` shows which line in a list covers a path. It uses the same rules as the guards.

Set `launch = user` when you start the dev servers yourself. Then agents only run the doctor check. They do not seed or reset data. They write only as the test account, and they remove what they create. If the sandbox blocks localhost, they use the harness's preview browser. See shipinetics:verification-map.

**Workspace mode** is for a folder that holds several package repos and is not a repo itself. Set `packages` in the config to turn it on.

- The Stop hook runs `package_verify_cmd` for each package that the agent edited in the session. It uses `package_verify_quick_cmd` while the agent works. Your own unrelated changes never block the agent.
- The PR gate and `evidence` work in the package repo that the PR comes from.
- The root's own files (`.shipinetics/`, the queue, worksheets, docs) must also be in a git repo. Make the root a repo that ignores the package folders, or set `harness_repo` to a separate repo. `shipinetics-config` warns you when neither is true.
- `night-shift` then makes a worktree of the harness repo, with a worktree of each package inside it. All of them are on the branch `night/<date>`.

`/shipinetics:setup` audits the project first. Then it asks all its questions in one message. Then it installs every phase in one run, with a commit for each phase.

## Where each part lives

| # | Part | In the plugin | In the project |
|---|---|---|---|
| 0 | Router | setup writes it | `AGENTS.md`, `CLAUDE.md` (it imports `@AGENTS.md`) |
| 1 | Workflow | `shipinetics:workflow` | Your `AGENT_WORKFLOW.md`, if you have one, replaces it |
| 2 | System docs that stay true | `shipinetics:system-docs` | `docs/systems/*.md`, each with a 7-line header |
| 3 | Run the app | `shipinetics:verification-map`, workflow step 6 | `docs/verification/`, and "Run the app yourself" in `AGENTS.md` |
| 4 | Tests | `shipinetics:testing`, `shipinetics:test-writer`, `shipinetics:spec` | `docs/testing/`, `e2e/`, `.shipinetics/test-paths` |
| 5 | Linters that fix | `shipinetics:lint-rule` | `bin/lint-fix`, `bin/llm-fix`, `.githooks/pre-commit` (it also limits commits to 400 changed lines), `.githooks/commit-msg` (it requires the `Worksheet:` trailer) |
| 6 | Reviews by other agents | `shipinetics:review`, four reviewer agents, `agent_review`, 7 personas | `docs/review/personas/` for the project's own personas |
| 7 | Worksheets and tags | `shipinetics:worksheet`, `worksheet` | `docs/worksheets/`, `ws/*` tags, `Worksheet:` trailers |
| 8 | Session feedback | `shipinetics:feedback`, a Stop hook reminder | `docs/agent-feedback.md` |
| 9 | Tools that agents build | `shipinetics:build-tool` | `bin/`, `docs/tools.md` |
| 10 | Commit sweeps | `shipinetics:sweep` | `docs/sweeps/`, `sweep/*` tags |
| 11 | Conventions | `shipinetics:lint-rule` moves them into linters | `docs/conventions.md` |
| 12 | Night shift | `shipinetics:night-shift`, the `night-shift` launcher | `TODOS.md`, `.claude/settings.json` |
| 13 | Task queue | `shipinetics:task-queue` | `TODOS.md`, or Linear through `bin/tasks` |
| 14 | Test audit | `shipinetics:test-audit` | `docs/test-audits/` |
| 15 | Visual regression | `shipinetics:visual-regression`, `shipinetics:ui-reviewer` | Screenshot tests, with baselines in LFS or PR artifacts |
| 16 | Benchmarks | `shipinetics:perf`, `bench-compare` | `perf/baselines/`, `bin/bench` |
| 17 | Profiling | `shipinetics:perf` (experiment steps) | `docs/perf/experiments.md` |
| 18 | End of shift | `shipinetics:end-of-shift` | `bin/verify --full`, `docs/shifts/*.md` and `*.html` |
| S | Secrets | `shipinetics:secrets`, the secrets guard | `.shipinetics/secrets.list`, `bin/with-secrets`, the config module |
| V | Evidence on every PR | `shipinetics:evidence`, `evidence`, the PR gate, a CI job | `docs/evidence/<worksheet>/`, `.shipinetics/ui-paths` |
| D | Design system | `design-check`, `shipinetics:ui-reviewer`, setup's design-system step | `DESIGN.md` with token frontmatter, `PRODUCT.md`, design-system change requests in worksheets |
| M | Merge risk | `shipinetics:review` | `## Merge risk` in each PR body |
| X | Security tools | `shipinetics:security-scans`, `scan-skills`, the install gate | `docs/security/` |
| E | Explanations | `shipinetics:explain`, Whiteboard | `.shipinetics/explainers/` (not committed) |

## What code enforces

Skills are instructions. The parts below are hooks and scripts. They work even when an agent does not follow its instructions.

You can switch off each hook. Put `hooks_off` in the project's `.shipinetics/config`, or in `~/.config/shipinetics/config` for all projects. The names are `stop`, `edits`, `secrets`, `pr` and `installs`. Example: `hooks_off = secrets installs`. If a project sets `hooks_off`, the project setting is used, not yours. `SHIPINETICS_HOOKS_OFF` does the same for one session. Agents cannot edit `~/.config/shipinetics/`.

**Stop hook** (`scripts/stop-verify.sh`, only in set-up projects)
- It runs each time the agent tries to stop with changes. Changes are uncommitted changes, or commits made in this session. An agent that commits each step is checked too.
- The time decides the tier. See "When checks run" below.
- If a check fails, the agent gets the last 60 lines of the output, and it must continue.
- If the agent stops again with no change, the hook lets it stop. Then it tells you that the checks still fail. This prevents a loop.
- When only the quick tier ran, it tells you.
- One time in each session, it reminds the agent to update the worksheet and the feedback log.
- On a bug fix with code changes but no test changes, it reminds the agent to get a failing test from test-writer first. A worksheet is a bug fix when its header says `Type: bug`, or its title has the word bug, fix, crash, regression or Sentry.

**Pre-push hook** (`.githooks/pre-push`, setup installs it). The complete checks must pass before code leaves the machine. It uses a recorded pass, so it costs no time after the agent ran the checks.

**Edit guard** (`scripts/guard-edits.sh`, only in set-up projects). It has three rules. Each rule uses a list in `.shipinetics/`:

- `protected-paths`: an agent can create these files (acceptance tests, baselines) but cannot change them. To change one, the agent writes the new version to `.shipinetics/pending/<path>`. You read the change and apply it with `shipinetics-config apply`. `shipinetics-config pending` lists the changes that wait for you. `apply` needs a terminal, so an agent's Bash tool cannot run it by accident. Like the guards, it slows an agent down. It is not a lock. The same method works for `.claude/settings.json`, which Claude Code does not let agents edit.
- `test-paths`: only `shipinetics:test-writer` can create or edit test files. Test-writer cannot edit source files.
- `env-allowed-paths`: new reads of the environment (`process.env`, `os.environ` and similar) are allowed only in the config module. Docs, text files and reads of safe variables (see the secrets guard) do not count.

**Known failures** (`bin/known-failing`). Some suites already fail. For them, `bin/verify` can run `known-failing check <junit.xml>`. Then only new failures fail the check. The list of known failures is `.shipinetics/known-failing`, and it is protected. See shipinetics:testing.

**Secrets guard** (`scripts/guard-secrets.sh`, in every project). It blocks commands that could show a secret to the agent:
- commands that show the environment;
- inline scripts that read the environment;
- commands that print a variable with a secret-like name;
- direct reads from a vault;
- reading or naming a secret file, with Bash or the Read tool.

You choose the secret files. Write a `secret-paths` list in `.shipinetics/`, or in `~/.config/shipinetics/` for all projects. Put one pattern on each line. The template is `skills/setup/templates/secret-paths`. The first list that the guard finds is the whole list. If there is no list, a built-in list covers cloud and tool credentials: gcloud, AWS, Azure, SSH keys, `.netrc`, `.npmrc` and others.

The guard ignores text that only mentions the environment:
- the body of a heredoc that goes into a file;
- the pattern given to grep, rg and similar commands;
- reads of variables that never hold secrets: `HOME`, `PATH`, `TMPDIR`, `NODE_ENV`, `CI` and others, plus the names in `env_safe_names`.

The block message names the project's secrets runner (`secrets_runner`).

**PR gate** (`scripts/guard-pr.sh`, only in set-up projects). It blocks `gh pr create` and `gh pr ready` until three things are true:
1. `evidence check --branch` passes;
2. the complete checks passed on exactly this code;
3. the PR body has a `## Evidence` section.

`evidence check` also fails when the code changed after the evidence was recorded. Changes to docs, tests and records do not count. A branch that changes only docs passes.

**Install gate** (`scripts/guard-installs.sh`, in every project). Before an agent installs or updates a skill, plugin, marketplace or MCP server, the gate asks you. It also tells you to scan the source with SkillSpector first.

**CI** (the project's `verify.yml`). It runs `bin/verify --full`. It fails a PR that has no Evidence section with a screenshot, recording or terminal output. A PR with the `no-evidence` label passes.

**`bin/with-secrets`**. It gets the secrets in `.shipinetics/secrets.list` from Google Secret Manager. Then it runs a command with the secrets set. The agent never sees a value.

**Environment scrub** (`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1`, in the project settings and in night shift runs). It removes credentials from every command, hook and MCP server that Claude Code starts. This is the strongest secrets layer. The guard is a second layer.

**Night shift launcher** (`bin/night-shift`)
- It uses a separate worktree and branch.
- Each task has limits on cost and turns. The shift has limits on time and budget.
- It runs in the OS sandbox, with no way out. Pushes and vault reads are blocked. The environment scrub is on.
- Each task runs as a `/goal` with a fixed completion condition.
- It writes each run to a metrics file (CSV).

## When checks run

Each check runs at the first time its result is useful, and before anything depends on it. No check is dropped to save time.

| When | What runs | What it blocks |
|---|---|---|
| A commit | Lint, with fixes, on the staged files (the pre-commit hook) | The commit |
| A stop while the agent works | `bin/verify --quick` (`verify_quick_cmd`): lint of the changed files, an incremental type check, the tests related to the changes. If a path in `.shipinetics/complete-paths` changed (build config, manifests, lock files), the complete tier runs instead | The stop |
| The "done" stop (the worksheet says `Status: done`) | `bin/verify`: all fast checks, with the build and the e2e smoke test | The report that the work is done |
| A push or a PR | A recorded complete pass for exactly this code | The push or the PR |
| CI | `bin/verify --full`, without local caches | The merge |
| End of shift, and weekly | `--full`, visual and performance checks, the sweep, a check of the verification map and the design system | The report |

A pass is recorded against a hash of the code's contents, not against the commit. So a commit of checked code does not run the checks again. Changes to worksheets, evidence and the feedback log do not run them again either.

- `shipinetics-verify` runs a tier and records the pass.
- `shipinetics-verify status` shows which tiers passed on the current code.
- `shipinetics-verify times` shows where the check time goes.

A project without `verify_quick_cmd` runs the complete tier at every stop.

## Reviews, evidence and explanations

- **Agent reviews** happen at each checkpoint:
  - `shipinetics:reviewer` on a different Claude model;
  - `agent_review` for a different model family;
  - `shipinetics:security-reviewer` for changes that touch security;
  - `shipinetics:ui-reviewer` for changes that people see.

  The UI reviewer first compares the change with `DESIGN.md` (`design-check`, then a check by hand). Then it runs Impeccable's critique and audit on real screenshots. The findings of all reviewers are merged and filtered before the author acts on them.
- **Independent check.** For medium tasks and larger, UI changes and all night shift tasks, the final reviewer uses the change in the app itself. It uses every entry point from the verification map, on the final code. Its result is PASS, ISSUES or BLOCKED.
- **Design system.** Agents never change tokens to remove a finding. They write the change in the worksheet, under "Design-system change requests". You decide. Setup can protect the design files.
- **Claims tables.** Reviews of research and docs check each fact against evidence that the reviewer opened: `file:line`, or a source URL with the date. Each fact gets a result: verified, incorrect or unresolved.
- **Evidence.** Each PR shows the change in the real app: a screenshot for each acceptance criterion, a recording for UI changes, and terminal output for CLIs and APIs. Agents record it with `evidence` and the Playwright template in `shipinetics:evidence`.
- **Merge risk.** An independent reviewer grades each PR as low, medium or high. It uses Warp's `merge-risk` skill. The grade tells you how carefully to review. Nothing merges by itself.
- **Your review.** For medium tasks and larger, and all night shift tasks, the agent makes a Whiteboard. The merge-risk grade, the review results and the evidence screenshots are at the top. Without Whiteboard, the agent makes an HTML page.
- **Explanations.** `shipinetics:explain` sets the formats: ASD-STE100 text, diagrams, Whiteboards, HTML pages, and videos with narration when you ask for one.

## Effort

All parts run at high effort by default:

- All four agents (`reviewer`, `test-writer`, `security-reviewer`, `ui-reviewer`) set `effort: high`.
- The project settings template sets `"effortLevel": "high"` for the main session.
- `night-shift` uses `--effort high`. `agent_review` asks the Claude and Codex reviewers for high effort.

To change the effort:

| For | Do this |
|---|---|
| All parts, agents too | Start Claude Code with `CLAUDE_CODE_EFFORT_LEVEL=medium` (or another level). It overrides all other settings |
| The main session | Use `/effort` in the session, or set `effortLevel` in the project's `.claude/settings.json` |
| One agent | Edit its `effort:` line in `agents/<name>.md`, or ask Claude to use a different effort for one task |
| Night shift | `night-shift --effort medium` |
| Review and lint-fix CLIs | `SHIPINETICS_CLAUDE_REVIEW_EFFORT`, `SHIPINETICS_CODEX_EFFORT`, `SHIPINETICS_FIX_EFFORT` (empty means the tool's default) |

## Measure the setup

Each worksheet has a Metrics block. It records the model, the effort, the plugin version, cost, turns, time and merge risk. It also records the review rounds, what happened to each finding, and the bugs that test-writer suspected. Three fields are for you: the corrections you needed, your review time, and whether you accepted the work. Night shift runs write cost, turns and time to a CSV file. `/shipinetics:feedback ingest` summarises them for each accepted task. Change one thing at a time, then compare the next group of accepted tasks.

## Environment variables

| Variable | Effect |
|---|---|
| `SHIPINETICS_SKIP_VERIFY=1` | Turns off the Stop hook, and the PR gate's check of verify, for a session |
| `SHIPINETICS_UNLOCK=1` | Lets agents edit protected paths for a session |
| `SHIPINETICS_ALLOW_AUTHOR_TESTS=1` | Lets any agent edit tests for a session (for example, a rename of many files) |
| `SHIPINETICS_ALLOW_ENV_READ=1` | Turns off both environment guards for a session |
| `SHIPINETICS_ALLOW_NO_EVIDENCE=1` | Turns off the PR gate for a session |
| `SHIPINETICS_ALLOW_INSTALLS=1` | Turns off the install gate for a session |
| `SHIPINETICS_HOOKS_OFF="secrets installs"` | Switches off the named hooks for a session (stop, edits, secrets, pr, installs) |
| `SHIPINETICS_ALLOW_NO_WORKSHEET=1` | Lets one commit through without a `Worksheet:` trailer (work that is not part of a task) |
| `SHIPINETICS_ALLOW_BIG_COMMIT=1` | Lets one commit through above the size limit (for example, a vendored library). Say why in the commit message |
| `CLAUDE_CODE_EFFORT_LEVEL` | One effort level for the session and all agents |
| `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` | Claude Code's own credential scrub. Setup puts it in the project settings |
| `SHIPINETICS_AUTHOR` | The model family that wrote the code, for `agent_review` (default `claude`) |
| `SHIPINETICS_REVIEW_ORDER` | The order in which `agent_review --cli auto` tries CLIs (default `codex gemini cursor claude`) |
| `SHIPINETICS_CODEX_MODEL`, `SHIPINETICS_GEMINI_MODEL`, `SHIPINETICS_CURSOR_MODEL`, `SHIPINETICS_CLAUDE_REVIEW_MODEL` | The model for each review CLI |
| `SHIPINETICS_CURSOR_FAMILY` | The family of your Cursor model. Then `auto` does not choose Claude through Cursor to review Claude |
| `SHIPINETICS_CLAUDE_REVIEW_EFFORT`, `SHIPINETICS_CODEX_EFFORT`, `SHIPINETICS_FIX_EFFORT` | The effort for the review and lint-fix CLIs (default `high`) |
| `SHIPINETICS_FIX_CLI`, `SHIPINETICS_FIX_MODEL` | The CLI and model for `bin/llm-fix` (default `claude`, `sonnet`) |
| `SHIPINETICS_LLM_FIX=0` | Skips the LLM step in `bin/lint-fix` |
| `SHIPINETICS_BENCH_MACHINE` | The machine name for `bench-compare` baselines (default `<host>-<arch>`). Set it in CI, so all runners use one baseline |
| `GOOGLE_CLOUD_PROJECT` | The default project for `bin/with-secrets` (else gcloud's project) |

## Known limits

- The guards only see Claude's file tools and the text of commands. Changes to guarded files go through a person or a named command (`shipinetics-config apply`, `bench-compare --init`, `known-failing init`). The setup skill lists them. An agent can still write a file or print a variable through a script that it writes and runs. The environment scrub, the reviewers and the night shift sandbox are the layers behind the guards.
- The reviewers have Bash, so they can run `git diff` and tests. They are read-only because their instructions say so, not because code enforces it. Claude Code ignores hooks on plugin agents.
- The install gate asks you. In a run without a person, nobody can answer, so installs are refused.
- `agent_review` runs Codex, Gemini and Cursor in their documented non-interactive modes. These modes can change. Check them with `--help` the first time.
- SkillSpector and Strix were not installed when these parts were built. `scan-skills` was tested with a copy of SkillSpector's documented JSON format. After you install SkillSpector, run `scan-skills` one time and check the summary.
- `evidence pr-body` links to files on the pushed branch. Push before you open the PR. Without git LFS, keep recordings small.
- `bin/with-secrets` reads Google Secret Manager through gcloud. When `.shipinetics/config` has `vault = infisical`, it runs `infisical run`. A project with its own runner sets `secrets_runner`.
- The Stop hook cannot tell a pause from a finished task. The worksheet's `Status: done` tells it to run the complete tier. If an agent never sets it, the complete tier still runs before a push and a PR, but not at the agent's last stop. Keep `--quick` to seconds and the complete tier to a few minutes. Never let a check print environment values.
- `design-check` finds fonts, colours, radii and font sizes that are not in `DESIGN.md`. The UI reviewer checks the rest: spacing, unknown `var()` names, new tokens and copied components. Without token frontmatter in `DESIGN.md`, there is nothing to check against.

## Layout

```
.claude-plugin/   plugin.json, marketplace.json
agents/           reviewer, test-writer, security-reviewer, ui-reviewer   (all at effort: high)
bin/              agent_review, bench-compare, design-check, evidence, known-failing, night-shift,
                  scan-skills, shipinetics-config, shipinetics-verify, skills-outdated, worksheet
                  (on the agent's PATH)
hooks/            hooks.json
scripts/          lib.sh (shared helpers), stop-verify.sh, guard-edits.sh, guard-secrets.sh,
                  guard-pr.sh, guard-installs.sh
skills/           setup (with templates/), workflow, spec, system-docs, testing, lint-rule,
                  review (with personas/), evidence, security-scans, secrets, explain, worksheet,
                  feedback, task-queue, build-tool, sweep, night-shift, test-audit,
                  visual-regression, perf, end-of-shift, verification-map
CHANGELOG.md      what changed in each release, and the versioning rules
tests/            the tests for the hooks and tools. Run tests/run.sh. CI runs it on Linux and on
                  macOS's bash 3.2
```
