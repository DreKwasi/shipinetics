---
name: setup
description: Audit a project against the shipinetics setup (17 points plus secrets, independent tests, specialist reviewers and explainers) and scaffold what's missing, one phase at a time. It fits around an existing CLAUDE.md or AGENTS.md, and `update` brings a set-up project to the plugin's current version. Use when the user runs /shipinetics:setup, asks to set up the agentic workflow in a repo, asks what's missing from their setup, or updated the plugin.
argument-hint: "[audit|update|1|2|3|4|5|6|7]"
disable-model-invocation: true
---

# Shipinetics setup

> Text for people (docs, worksheets, reports, PR descriptions, commit messages, review comments, replies, and each label on a board, diagram or table): write it in ASD-STE100, by the plain-language guide (`${CLAUDE_PLUGIN_ROOT}/skills/explain/plain-language.md`). Where the text describes structure or flow (a call path, a data flow, states or steps), show it on a Whiteboard. In a committed file, also put a Mermaid diagram and a link to the Whiteboard, because GitHub and other people cannot open your Whiteboard. Without Whiteboard, use Mermaid only. shipinetics:explain has the rules.

You're installing a working agentic setup into this project. The plugin carries the generic parts (skills, reviewer, hooks, scripts). This skill puts the project-specific parts into the repo so they're committed, visible to every agent and to CI, and work without the plugin.

Argument: `$ARGUMENTS`. No argument means: run the audit, ask every question in one message, then run the phases in the way the user chose ("How to run setup" below). If `docs/shipinetics-setup.md` shows phases already done, start at the first one that isn't. A number runs just that phase, to redo or repair it. `audit` means audit only. `update` brings a project that is already set up to the plugin's current version ("Update a set-up project" below).

## How to run setup

With no argument, offer these four ways in the ask-once message, with the first one recommended. Write the choice in `docs/shipinetics-setup.md`, so that a resumed run keeps it:

| Way | What happens | Good for |
|---|---|---|
| **All phases in one run** (recommended) | Every phase in order, without a stop between them. Setup stops early only when a proof fails | Most projects. It is the fastest way to a working setup |
| **One phase at a time** | After each phase's proof and commit, setup shows what the phase added and asks before the next one | A team that wants to read each phase, or a project where a mistake costs much |
| **Phase 1 only** | The core loop: verify, the router and the block, the lists, secrets, the testing guide, the smoke test and the verification map. Then setup runs Finish and stops. `/shipinetics:setup` later continues at Phase 2 | A first try, or a busy week |
| **Audit only** | The audit table and the questions, and no change. The same as `/shipinetics:setup audit` | Seeing what is missing before deciding |

With "one phase at a time" or "Phase 1 only", ask the other questions only when the phase that needs them starts.

## Show the findings and the questions

The audit's findings and the ask-once questions are long. A person understands them faster on a Whiteboard than in one long chat message. So, before you show them, check for Whiteboard:

1. **Call the Whiteboard `session_capabilities` tool.**
   - **It answers:** show the findings and the questions on a Whiteboard (below).
   - **The Whiteboard plugin is installed, but the tool doesn't answer** (the MCP server fails to connect, or the tool isn't there): the dev.fast Whiteboard app is probably missing. Ask the user one question before anything else: "Setup shows its findings and questions on a Whiteboard. The Whiteboard plugin is installed, but the dev.fast Whiteboard app does not answer. Do you want to install the app and restart this session, or continue with the questions as text?" Recommend the install. If they install it, run setup again after the restart. If they choose text, continue with text, and put the app install on the For you list.
   - **The Whiteboard plugin isn't installed:** use text. Row R of the audit already lists the missing companion.
2. **Write every word in ASD-STE100.** shipinetics:explain ("Prose" and "Labels") has the rules. They apply to each title, card, table cell and option. Two rules matter most here:
   - **No private codes.** Write "Recommended:", not "(rec)". Write "Not confirmed:", not "?". The project's own names (a ticket prefix such as `PROJ`, a table name, a port number) stay as they are.
   - **One question for each card,** as a sentence that ends with "?".

### On a Whiteboard

Call `session_get_instructions` with topic `scratchpad`, and follow it. Make one board with three parts, in this order:

1. **What setup found.** The audit table: each row with its status (present, partial, missing). Then the main findings, one card each, most important first: each conflict between the project's rules and Shipinetics, each secret risk, each tool that isn't on the agent's PATH. Where the finding has structure (the repos and the root folder, the ports of each service, the flow of a commit through the hooks), draw it.
2. **Questions for you.** One card for each question, with its number. Each card has these parts:
   - The question.
   - The options, each as a short sentence.
   - "Recommended:" before the option that you recommend, and one sentence that says why.
   - "Not confirmed:" before each fact that you inferred, with where you inferred it from.
3. **What happens next.** The phases that run with the recommended answers, in order, and what each one adds.

Read each card alone when you read the board back. Rewrite each card that makes no sense without the others.

Then send a short chat message: the link to the board, the number of questions, and how to answer ("Answer by number, or say: use the recommended answers"). The answers come in chat. Write the questions and the findings in `docs/shipinetics-setup.md` too, because other people and later sessions can't open your Whiteboard.

### As text

Use one message, in this order: the findings, then the numbered questions, then what happens next. Each question has the same parts as a card: the question, the options, "Recommended:" with the reason, and "Not confirmed:" for each inferred fact.

## Rules

- **Audit before you build.** Never overwrite an existing file. If a file exists, merge into it and show the user the diff. If an existing setup does something differently (a different test runner, a `tools/` folder instead of `bin/`), adapt to it, don't replace it.
- **Detect, don't ask, where you can.** Read `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Makefile`, CI config, lockfiles and existing scripts to find the real commands. Ask only for what you can't find out.
- **Confirm, don't infer.** Live config and scripts are evidence. Comments, TODOs, feedback logs, worksheets and old docs are history: they say what was true once. Before you act on a fact about infrastructure (the secrets vault, deploy target, CI, package manager, which package or runtime is active), find it in live config. If the only evidence is historical, or two sources disagree, ask the user. Say what you inferred and from where, so they can correct it in one answer. A wrong guess here gets written into config and every agent repeats it.
- **Each phase ends with proof.** Run the thing you set up and show it working before you move on. If it doesn't work, fix it or stop and say what's blocking.
- **Ask once, then run straight through** (with "All phases in one run"). After the audit, put every question the phases need in one place, on a Whiteboard or in one message ("Show the findings and the questions" above), with the way to run setup first: the Unconfirmed list, secret names you couldn't find, where recordings go (an opt-in `evidence_upload_cmd` for the team's store, or attach them to the PR by hand), which optional phases to run (6 visual and perf, 7 security tools), for UI projects whether to write PRODUCT.md with `/impeccable init` and whether token changes should need a human (protected design files), which task list is the source of truth if one exists outside `TODOS.md`, whether agents start the app or the user runs the servers (`launch`), the smoke test's criterion (which screen it opens and what it must show: test-writer tests only criteria that a human approved), each disagreement between the project's instruction files and the Shipinetics block ("Projects that already have CLAUDE.md or AGENTS.md", step 3), and for Phase 7 which instance Strix may test and whether to run deepsec on the whole repo, with which cost cap. Then work through the phases without stopping. Stop early only when a phase's proof fails and you can't fix it, or when something comes up that the answers don't cover.
- **What only the user can do goes on a list, not a pause.** Installing a CLI, logging in, creating a GitHub label they didn't approve: add it to a "For you" list in `docs/shipinetics-setup.md` and carry on.
- **Commit as you go.** At least one commit per phase, more where a phase is big (in Phase 2, a commit per few system docs), each under 400 changed lines. Log each phase's result and proof in `docs/shipinetics-setup.md` as you finish it, so a stopped run can resume. From Phase 4 on the commit hooks are live. Setup belongs to no worksheet, so commit with `SHIPINETICS_ALLOW_NO_WORKSHEET=1`.
- Templates are in `${CLAUDE_SKILL_DIR}/templates/`. Copy them, then replace every `{{PLACEHOLDER}}` with real values. Delete sections that don't apply. No placeholder survives into the repo. (GitHub Actions `${{ ... }}` expressions in the CI template aren't placeholders. Leave them.)
- Use a branch: `shipinetics-setup` unless the user is already on one for this.
- **Protected files go through pending.** The edit guard stops agents changing any existing file that `.shipinetics/protected-paths` covers, `.shipinetics/` itself included, and Claude Code stops agents editing `.claude/settings.json`. So write `protected-paths` in Finish, after the phases that edit `.shipinetics/`. For a protected file (on a resumed run, or `.claude/settings.json` at any time), write the full new version to `.shipinetics/pending/<path>` (same path under that folder) and a human reviews and applies it with `shipinetics-config apply`. On the For you list, give the user the output of `shipinetics-config pending`. It says why a person must apply each change, and it gives the exact command, with the project folder and the full path to the tool. Never write only `shipinetics-config apply`: the user's terminal doesn't have the plugin's tools on its PATH, unless the user installed the shims. If `shipinetics-shims status` fails, also put the one-time command from the `pending` output on the For you list: it installs the short commands. Never ask the user to restart with `SHIPINETICS_UNLOCK=1` to get setup through.

## What the guards cover

The edit guard sees only Claude's file tools (Edit, Write, NotebookEdit). It doesn't see Bash, so `mv`, `cp`, `sed -i`, `git mv` or a script can change a protected file, a test file or a policy list without being stopped. That's a gap in the enforcement, not permission: the rule still holds, and reviewers check diffs for it. So a maintenance move on a guarded file goes through a human or a named command, never a Bash workaround:

| Move | Route |
|---|---|
| Change a protected file (acceptance test, baseline, policy list, `.claude/settings.json`) | The new version in `.shipinetics/pending/<path>`, then a human runs `shipinetics-config apply` |
| Rename, move or rewrite tests in bulk (framework migration) | `shipinetics:test-writer`, or a human starts the session with `SHIPINETICS_ALLOW_AUTHOR_TESTS=1` |
| Reset a benchmark baseline | `bench-compare --init` (a pending proposal once a baseline exists) |
| Quarantine failing tests | `known-failing init` (a pending proposal once the list exists) |
| Check which rule covers a path | `shipinetics-config match <list> <path>` |

Tell the user this in the Finish summary in one or two sentences, so they don't read the guards as a sandbox.

## Projects that already have a harness

Many projects already have their own versions of these pieces under other names: a router, worksheet scripts, a validate script, review and testing docs. Shipinetics fits over them instead of replacing them.

- **Map, don't duplicate.** For each point the audit marks in place, set the matching key in `.shipinetics/config` (from `templates/config`) to the existing file or command: `worksheets_dir`, `feedback_file`, `systems_dir`, `conventions_file`, `test_index_file`, `testing_guide_file`, `verify_cmd`, `worksheet_new_cmd`, `worksheet_tag_cmd`, `tag_prefix`, `secrets_runner`. Shipinetics's skills, hooks and tools then use the project's own files. Show the user the mapping, and check it with `shipinetics-config`.
- **Only add what's missing.** Skip any template that duplicates something the project already has (`bin/verify`, the docs templates, `TODOS.md`). Add the `.shipinetics/` lists, and the Shipinetics block as "Projects that already have CLAUDE.md or AGENTS.md" describes.
- **The instruction files** (`CLAUDE.md`, `AGENTS.md` and the files they import) follow "Projects that already have CLAUDE.md or AGENTS.md" below.
- **Secrets:** match how the project already runs things with secrets. For Infisical, set `secrets_runner = infisical run --env=<env> --` (and `vault = infisical` if the project copies `bin/with-secrets`).

## Projects that already have CLAUDE.md or AGENTS.md

Most projects already have instructions for agents. Shipinetics adds its rules next to them. It never moves or rewrites the project's text without the user's yes.

1. **Find every file that loads.** Look for:
   - `CLAUDE.md`, `.claude/CLAUDE.md`, `AGENTS.md` and `.claude/AGENTS.md`;
   - the files that these import with `@path`, and `.claude/rules/` if it exists;
   - `CLAUDE.md` and `AGENTS.md` in subfolders (`git ls-files '*CLAUDE.md' '*AGENTS.md'`). They load only when the agent works in their folder. Leave them as they are;
   - symlinks: check `ls -l CLAUDE.md AGENTS.md`.

   `CLAUDE.local.md` belongs to one person and is usually not in git. Count it, but never edit it. Files for other tools (`.cursor/rules/`, `.github/copilot-instructions.md`, `GEMINI.md`) don't load in Claude Code. Leave them. Write each file and its line count in audit row 0.
2. **Put the Shipinetics block in `AGENTS.md`, and make `CLAUDE.md` load it.** The block is the text between the `shipinetics:begin` and `shipinetics:end` lines of `templates/AGENTS.md`. The skills point to `AGENTS.md`, so the block always goes in the root `AGENTS.md`:

   | The project has | Do this |
   |---|---|
   | Neither file | Write both from the templates |
   | `AGENTS.md` only | Add the block at the end of `AGENTS.md`. Create `CLAUDE.md` from the template |
   | `CLAUDE.md` only | Create `AGENTS.md` with the block. Add `@AGENTS.md` as the last line of `CLAUDE.md`. An import path is relative to the file that holds it: in `.claude/CLAUDE.md`, the line is `@../AGENTS.md` |
   | Both, and `CLAUDE.md` imports `AGENTS.md` | Add the block at the end of `AGENTS.md` |
   | Both, and no import | Add the import line to `CLAUDE.md`. Tell the user first: Claude Code didn't read this `AGENTS.md` before, because it reads only `CLAUDE.md` when both exist, so its text now loads in each session. Show what it says. If the two files say the same things, tell the user which parts, but don't merge them |
   | One is a symlink to the other | It is one file. Add the block to the real file that the link points to, not to the link, and add no import |

   The template's sections above the block (Run the app, Where to find things, Secrets, fresh clone) go into `AGENTS.md` only when no existing file covers them yet. When a file covers one, leave it there. If it is out of date, tell the user. "Security targets" always goes in `AGENTS.md`, because the block names that section.

   The proof: put on the For you list "In a new session, run `/memory` and check that it lists `AGENTS.md`." An import with a wrong path fails without an error.
3. **Find the rules that disagree.** Read each file from step 1 and compare it with the block. Put each disagreement in the ask-once message, with both texts. Common ones:

   | The project says | Shipinetics says | What to tell the user |
   |---|---|---|
   | "Write tests first", "TDD", "add tests with each change" | test-writer writes the tests | A hook enforces this: in a set-up project, the main agent can't write test files. The project's rule must change |
   | "Update the snapshots with `-u` when they fail", "regenerate the baseline" | Never regenerate a test, a snapshot or a baseline to get a pass | This rule always holds, and the project's rule must change. A human updates a snapshot or a baseline through `.shipinetics/pending/` |
   | "One commit at the end", "squash" | A commit for each step, at most 400 lines | The pre-commit hook enforces the size. `max_lines` at the top of `.githooks/pre-commit` changes it, and `0` turns it off. PRs can still be squashed when they merge |
   | "Never use subagents" | Reviewers and test-writer are subagents | Without them, there is no independent review and no independent tests |
   | "Run `npm test` before you finish" | `shipinetics-verify` | Not a disagreement: set `verify_cmd` to the project's command ("Projects that already have a harness") |
   | "Don't start the servers, I run them" | Agents run the app | Not a disagreement: set `launch = user` in `.shipinetics/config` |
   | A commit format, such as Conventional Commits | The plain-language guide | Not a disagreement: the format sets the shape of the first line, and the guide sets the words |

   For each real disagreement, the user chooses:
   - **The project's rule.** Write it under "## Where this project differs from Shipinetics", outside the block, with its reason, the block rule that it replaces, and "Approved by <name> on <date>". The block makes that rule win. Two kinds can't go there: a rule that weakens one of the rules that the block says always hold (secrets, protected files, tests, scans, Strix and deepsec approvals), and a rule that a hook enforces. For the second kind, name the setting that changes the hook, or say that no setting does.
   - **The Shipinetics rule.** Change or remove the project's rule only after the user's yes, and show the diff.

   Rules that the project and the block both state: tell the user, and offer to remove the project's copy. Never change the text inside the block for one project, because `update` replaces it.
4. **Count what loads in every session.** Add up the lines of the files that load at session start (step 1, without the subfolder files), before and after setup. Write both numbers in the setup log. If the total is over about 300 lines, tell the user that each session pays for it, and suggest what could move into docs that load only when needed. Don't move it during setup.

## Multi-repo workspaces

If the project root isn't a git repo but holds several package repos, use workspace mode:

- Put `.shipinetics/` at the workspace root. Set `packages` to the package folders and `package_verify_cmd` to the per-package check, with `{package}` where the folder name goes. If the package check can scope itself to changed files, set `package_verify_quick_cmd` too, for `shipinetics-verify quick` (`$SHIPINETICS_CHANGED_FILES` lists paths relative to the package repo).
- If packages keep committed copies of worksheets, set `package_worksheets_dir` so the evidence tool can find them on a branch.
- Lists in `.shipinetics/` use paths relative to the workspace root, such as `api/src/config/*`.
- **Don't write into package repos that have uncommitted work.** Per-package pieces (the commit hooks, the CI workflow, the evidence store setting) go on a list for the user to do one package at a time. Leave out the commit-msg hook in packages that record worksheets through `package_worksheets_dir` instead of trailers.
- **Version the harness files.** A root that isn't a git repo leaves `.shipinetics/`, the queue, the worksheets and the root's docs unversioned: one bad edit loses them and nobody reviews changes to the policy lists. `shipinetics-config` warns about it. Flag it in the audit, and offer the user one of these:
  - **The root becomes the harness repo** (simplest): `git init` at the root, with a `.gitignore` that ignores each package folder (`api/`, `web/`) and `.claude/worktrees/`. Commit the harness files.
  - **A separate harness repo**, when the root must stay plain (a shared folder, or a repo already exists for this): a git repo whose top level holds `.shipinetics/`, `AGENTS.md`, `CLAUDE.md`, the queue and `docs/`, with the root's copies replaced by symlinks into it, and the package folder names in its `.gitignore`. Set `harness_repo` in `.shipinetics/config` to its path, relative to the root.
  Changing the root's layout is the user's call, so put the commands on the For you list unless they said yes during the audit.

## Audit

Check each point and fill this table. Status is **in place**, **partial** or **missing**, and evidence is a file path or a one-line reason. Evidence must be live config or code, not a comment or a log entry. Anything you could only infer goes in an "Unconfirmed" list at the end of the audit, and you ask the user about it before Phase 1. Write the table to `docs/shipinetics-setup.md` (create it from scratch, this is the setup log) and show it to the user.

| # | Point | What to look for |
|---|---|---|
| 0 | Router | `AGENTS.md` that routes to docs, skills and tools, with the Shipinetics block between its `shipinetics:begin` and `shipinetics:end` lines. `CLAUDE.md` that imports it with `@AGENTS.md`, or is a symlink to it. List every instruction file that you found, with its line count ("Projects that already have CLAUDE.md or AGENTS.md") |
| 1 | Workflow | A workflow doc or skill (`AGENT_WORKFLOW.md`, or rely on `shipinetics:workflow`) |
| 2 | System docs | `docs/systems/*.md` with 7-line greppable headers, rule in `AGENTS.md` |
| 3 | Run the app | `AGENTS.md` says exactly how to start the app, seed data and log in. `docs/verification/` holds the verification map: launch, doctor, drive, cleanup, and a file per main feature with every entry point |
| 4 | Tests | e2e suite, `docs/testing/how-to-write-tests.md`, `docs/testing/test-index.md` |
| 5 | Lint and fix | pre-commit hook that auto-fixes, with LLM fallback, and a commit size limit. commit-msg hook that requires the `Worksheet:` trailer |
| 6 | Review | The reviewer agents load, project personas if any |
| 7 | Worksheets | `docs/worksheets/`, tagging convention |
| 8 | Feedback | `docs/agent-feedback.md` |
| 9 | Tools | `bin/` or `tools/` with `docs/tools.md` index |
| 10 | Sweeps | sweep reports in `docs/sweeps/` or a schedule for them |
| 11 | Conventions | `docs/conventions.md` with enforcement markers |
| 13 | Task queue | `TODOS.md` in the shipinetics format, or a Linear CLI |
| 14 | Test audit | audit reports or a schedule |
| 15 | Visual regression | screenshot tests with baselines (LFS or PR artifacts), plus `shipinetics:ui-reviewer` for agent visual review |
| 16 | Perf benchmarks | benchmarks with baselines and a regression threshold |
| 17 | Profiling | documented profiling commands per stack |
| S | Secrets | No `.env` files or committed secrets. `.shipinetics/secrets.list`, `bin/with-secrets`. `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` in `.claude/settings.json`. Its deny rules match the vault the project actually uses (`vault` in `.shipinetics/config`, confirmed in live config): rules for a vault the project doesn't use are stale and the real vault is unprotected, so that's **partial** |
| T | Independent tests | `.shipinetics/test-paths` matches the project's test layout, so only `shipinetics:test-writer` writes tests |
| D | Design system (UI projects) | DESIGN.md with token frontmatter, matching the tokens in code (CSS variables, Tailwind theme, CSS-in-JS theme, token files) and the component library (`components.json`, Storybook). PRODUCT.md. The Impeccable block in `.gitignore`. `design-check --all` runs |
| R | Companions | `shipinetics-companions` shows each companion as installed or declined: `security-audit` (for `shipinetics:security-reviewer`), Impeccable (for `shipinetics:ui-reviewer`), `merge-risk` (for merge-risk grades), tasteskill (optional, for UI routes that build a page), Matt Pocock's skills (for the routes in shipinetics:workflow), Whiteboard (`session_capabilities` answers) |
| V | Evidence tools, for when the user asks for evidence | `.shipinetics/ui-paths`, no recording or screenshot tracked in `docs/evidence/`, `ffmpeg` installed (agents check recordings frame by frame) |
| X | Security tools | SkillSpector installed (`scan-skills` runs). Optional: deepsec set up (`.deepsec/` exists, Node.js available), Strix installed with its provider key in the vault, Docker available |
| E | Explainers | `.shipinetics/explainers/` gitignored. Optional: Manim or Remotion, a local TTS, an ElevenLabs key in Secret Manager |

For row R, run `shipinetics-companions`. It reads the plugin's `companions.tsv`. In one message, show the user each missing companion: why Shipinetics uses it, its SkillSpector result and its install command. The user decides what to install, and the install gate asks before each install. Put the installs that the user wants on the For you list. For a companion that the user does not want, ask where to record it in `companions_skip`: in `.shipinetics/config` for the whole team, or in their own `~/.config/shipinetics/config`. Then the session-start notice stops listing it. Also call the Whiteboard `session_capabilities` tool, to check that the Whiteboard app answers.

Skills go in with the `skills` CLI and `-g`, so its lock file records them and `skills-outdated` can find their updates later (README, "Keep the companions up to date").

## Phase 1: core loop (points 0, 3, 4, and the verify gate)

The goal is one loop that works end to end: the agent runs the checks itself, a push or a PR can't leave without a complete pass, and a reviewer checks the work.

1. **Find the commands.** Typecheck, lint, unit tests, e2e, how to start the app, which port, how to seed data, how to log in with a test user. Find out who runs the servers. If the user starts them (they need the user's credentials or devices, or the agent's sandbox can't run them), set `launch = user` in `.shipinetics/config`, and agree a test account for agents' writes. Run each one to confirm it works today. Note any that fail on a clean checkout: that's the first thing to tell the user.
2. **`bin/verify`** from `templates/bin/verify`, with its three tiers. Each check runs at the moment its result is needed, and none is skipped:
   - `--quick` is what the agent runs after each step (`shipinetics-verify quick`). Scope each check to the files in `$SHIPINETICS_CHANGED_FILES` (lint the changed files, type-check incrementally, run the tests related to the changes). Keep it to seconds.
   - The default (complete) tier is every fast check, including the build and the e2e smoke test. The agent runs it before it marks the work done, the PR gate requires its pass, and the pre-push hook runs `bin/verify` on each push. Keep it to a few minutes.
   - `--full` runs everything, in CI.

   Fill in the step functions with the project's real commands. Steps in `parallel` run at once, so only put independent checks there. Local caches (`eslint --cache`, `tsc --incremental`, the build tool's cache) are fine, because CI runs without them. If the project's tools can't scope a check to files, run the whole check in `--quick` too, as long as it's fast. Leave anything slow (a build, e2e) to the complete tier. `chmod +x` it. Run all three tiers and record each one's time in `docs/shipinetics-setup.md`. Set `verify_quick_cmd = bin/verify --quick` in `.shipinetics/config`. If the suite already fails on a clean checkout and the user can't fix it now, quarantine the failures instead of skipping tests (shipinetics:testing, "A suite that already fails"): the user runs `known-failing init`, and `bin/verify` gates on `known-failing check`.
3. **`.shipinetics/`**: decide the contents of `.shipinetics/protected-paths` from `templates/protected-paths` now, and write the file in Finish (see Rules). Create `.shipinetics/test-paths` from `templates/test-paths`, adjusted to where this project's tests actually live (check with `git ls-files`). Create `.shipinetics/ui-paths` from `templates/ui-paths`, adjusted to where this project's UI code lives (it decides which changes need a screen recording as evidence). Append `templates/gitignore-additions` to `.gitignore`.
4. **Secrets.** Find how the project reads configuration today (`rg -l 'process\.env|os\.environ|getenv'`).
   - Create `.shipinetics/secrets.list` with the names (never values) of the secrets the app needs and their Secret Manager names. Ask the user for the Secret Manager names and project if you can't find them in deploy config.
   - Ask the user which files in this project hold secrets (a service-account JSON, `*.pem` keys, `.env` files). If any, create `.shipinetics/secret-paths` from `templates/secret-paths` and add them. The list replaces the built-in one, so keep its default lines.
   - Copy `templates/bin/with-secrets` to `bin/with-secrets` and `chmod +x` it. Check it works with a harmless command: `bin/with-secrets true` (it fails clearly if gcloud isn't logged in, which is fine to report).
   - If any `.env` file is tracked in git, stop and tell the user. Don't read it.
   - Build the merged `.claude/settings.json`: the project's current file, if any, plus `templates/claude/settings.json`. It turns on `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` and denies vault reads and credential files. The template's vault rules are for Google Secret Manager. Swap them for the project's vault: for Infisical, deny its `secrets` and `export` subcommands and `Read(~/.infisical/**)`; for others, the command that prints a secret and the CLI's credential folder. Remove rules for vaults the project doesn't use, so the file says what's really protected. Agents can't edit Claude Code's settings files, so write the result to `.shipinetics/pending/.claude/settings.json`, show the user the diff, and put the output of `shipinetics-config pending` on the For you list. If even that write is refused, put the exact JSON on the For you list instead.
5. **`AGENTS.md`** from the template, filled in for this project, with `{{SHIPINETICS_VERSION}}` set to the plugin's version (`version` in `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`). If the project already has instruction files, follow "Projects that already have CLAUDE.md or AGENTS.md" instead. Keep the part outside the block under about 60 lines. It routes, it doesn't explain.
6. **`CLAUDE.md`**: if missing, create it from the template (it imports `@AGENTS.md`). If it exists, add the import as described in the same section. Never move or rewrite the text in it.
7. **Testing guide** (point 4). From now on, every task gets tests, so make each test run fast and each request to test-writer predictable. Work from config and test names. Don't read test bodies and don't judge the tests now: shipinetics:test-audit does that later, a few files at a time.
   1. **Runners and folders.** Find each test runner, its config and its test folders (`package.json` scripts, `pyproject.toml`, `pytest.ini`, `go.mod`, `Cargo.toml`, the Playwright or Cypress config) and check them with `git ls-files`. `.shipinetics/test-paths` (step 3) must match them.
   2. **The fastest targeted run.** Find the command that runs one test by file and name. Run it on one fast existing test with `/usr/bin/time -p` and record the wall time (with no tests yet, write "no tests yet" and time the smoke test after step 8): that is the fixed cost that each of test-writer's proof runs pays. If it is over 10 seconds, find the cause in the output (the test database is built again from all migrations, a full build before each run, each worker does its own setup) and put the stack's usual fix on the For you list, with the numbers. Don't change the test config.
   3. **Tests related to a change**, for `check_unit_tests_related_to_changes` in `bin/verify --quick` (replace what step 2 put there). Use the runner's own selection: `vitest related <files>`, `jest --findRelatedTests <files>`, `pytest --testmon`, `go test` of the changed packages, `cargo nextest run -p <changed crates>`. Without one, run the test files that match the changed modules by name. When a change touches a file whose users the tool can't see (test config, fixtures, a lockfile, a shared test helper, generated code), the step runs all unit tests. Doubt makes the run bigger, never smaller.
   4. **Parallel copies.** Find out from the config if two copies of the suite can run at the same time (each worker gets its own database and ports). Test-writer runs its mutants in parallel only on yes.
   5. **Write the docs.** `docs/testing/how-to-write-tests.md` from the template, with the facts from steps 1 to 4. `docs/testing/test-index.md` from the template, seeded from test names only (`rg` for `describe(`, `test(`, `def test_`, `func Test`): one row for each test group, Criterion `none yet`, Audited `never`. These rows keep the group's name until shipinetics:test-audit or test-backfill rewrites each one as a behaviour; say so in a note at the top of the index.
   6. **Proof:** the targeted command and the related-tests command each pass. Record both times in `docs/shipinetics-setup.md`.
8. **Playwright smoke test** (web projects): if there's no e2e setup, install Playwright and add `templates/e2e/playwright.config.ts` at the repo root, adapted to the app's real start command (through `bin/with-secrets` if it needs secrets) and port. The smoke test itself is a test file, so you don't write it: first write the criterion that the user approved in the questions message to `docs/specs/smoke.md` ("AC1: Given the app started from empty data, when a user opens <the main screen>, then it shows <its heading> and the console has no errors"), with the line "Approved by <name> on <date>, in setup." Then spawn `shipinetics:test-writer` in `backfill` mode (the app exists, so there is no base commit to fail on) with that spec, `templates/e2e/smoke.spec.ts` as the starting point, the app's main screen, and the instruction to make it a single `@smoke` test that fails on console errors. It runs the test, watches it pass, breaks it on purpose (wrong heading text), watches it fail, and restores it. If the project already has an e2e setup, ask test-writer for just the one `@smoke` test in it. For non-web projects, ask test-writer for the equivalent: one end-to-end test through the real entry point (CLI, API, worker).

   Then build the **verification map** (shipinetics:verification-map `create`): `docs/verification/` with how to launch the app from empty data, a read-only doctor check, how to drive it, how to clean up, and the first 3 to 5 features with every entry point. Its end-to-end self-proof (launch, doctor, drive one feature, evidence survives cleanup) is this step's proof. Point the "Run the app" section of `AGENTS.md` at it.
9. **Prove the gate.** Run `shipinetics-verify` and `shipinetics-verify quick`, then `shipinetics-verify status`, to show both tiers pass and are recorded. Tell the user how to see the gate: make a small change that breaks a test, ask the agent to open a PR, and watch the PR gate refuse it. After a week of use, `shipinetics-verify times` shows where verify time goes.
10. **Prove the reviewers.** Run `shipinetics-companions missing` (exit 1 only means that a required companion is missing) and report each missing companion (row R) with why Shipinetics uses it, its SkillSpector result and its install command.
11. Commit with a message explaining the setup. Update `docs/shipinetics-setup.md`.

## Phase 2: context (points 1, 2, 11, D)

1. `docs/systems/`: one doc per major system (look at top-level source folders, services, packages). Use `templates/docs/systems/_template.md`. Fill the 7-line header with real information from reading the code. Keep bodies short to start: entry points, data flow, gotchas you found.
2. `docs/conventions.md` from the template. Seed it with conventions you can see the code already follows consistently (naming, error handling, file layout). Mark each as `enforced: lint <rule>` or `enforced: review`.
3. Workflow: if the user has their own `AGENT_WORKFLOW.md`, leave it and point `AGENTS.md` at it. Otherwise point `AGENTS.md` at `shipinetics:workflow`.
4. **Design system** (projects with UI; skip otherwise). Impeccable's detector and the UI reviewer can only check conformance against DESIGN.md's token frontmatter, so without it they judge by taste alone.
   1. Find what the project already has: CSS custom properties, a Tailwind theme (`tailwind.config.*`, or `@theme` blocks in CSS for Tailwind v4), CSS-in-JS theme files, `tokens.json` or Style Dictionary files, `components.json` (shadcn), `.storybook/`, an existing DESIGN.md or brand doc in any format, PRODUCT.md. Note what you found in `docs/shipinetics-setup.md`.
   2. If PRODUCT.md is missing and the user said yes, run `/impeccable init` (it interviews the user, so only in an interactive setup).
   3. If DESIGN.md is missing, has no token frontmatter, or is in another format, run `/impeccable document` in scan mode. Point it at what step 1 found that it doesn't read by itself: Tailwind v4 `@theme` blocks, `components.json` and the component folder, Storybook stories. If a DESIGN.md exists, choose merge, never overwrite. Then check the frontmatter lists the colors, typography and radii the code really uses.
   4. Append the Impeccable block from `templates/gitignore-additions` if it isn't there yet.
   5. If the user wants token changes to need a human, uncomment the design lines in the `protected-paths` you'll write in Finish, and add the project's token files. Agents then propose changes in the worksheet's "Design-system change requests" instead of making them.
   6. The Impeccable plugin runs its own detector hooks after UI edits and at Stop, next to shipinetics's. That's fine; mention it to the user, and `/impeccable hooks off` if they'd rather not.
   7. Check: `design-check --all` runs and lists any values outside DESIGN.md (that's the drift already in the code, not a failure), and `"<impeccable skill dir>/scripts/impeccable" doctor` reports no missing DESIGN.md sections.
5. Check: `head -n 7 docs/systems/*.md` gives a useful one-screen map of the system.

## Phase 3: continuity (points 7, 8, 13)

1. `docs/worksheets/_template.md` from `${CLAUDE_PLUGIN_ROOT}/skills/worksheet/template.md`.
2. `docs/agent-feedback.md` and `TODOS.md` from templates. If a task list exists elsewhere (Linear, GitHub issues), record the source of truth the user named in `AGENTS.md`.
3. Check: `worksheet new setup-check`, `worksheet list`, then delete the test worksheet.

## Phase 4: commit hooks (point 5)

1. Copy `templates/bin/lint-fix` and `templates/bin/llm-fix` to `bin/`, `templates/pre-commit` to `.githooks/pre-commit`, `templates/commit-msg` to `.githooks/commit-msg` and `templates/pre-push` to `.githooks/pre-push`. The pre-push hook runs `bin/verify` on every push, shows each check and its time, and stops the push if a check fails. It doesn't need the plugin. Fill in the project's fixers and checkers in `bin/lint-fix`. In `.githooks/pre-commit`, add the project's generated files to `ignore`, and change the worksheets and evidence paths there if `.shipinetics/config` maps them elsewhere. Keep `max_lines` at 400 unless the user asks otherwise.
2. Run `git config core.hooksPath .githooks`, and add that command to the setup section of `AGENTS.md` so fresh clones get it. If the project already uses husky, lefthook or pre-commit, keep both hooks in `.githooks/` and call them from that tool's pre-commit and commit-msg stages instead (the commit-msg hook takes the message file as its argument).
3. Check on a scratch branch, then delete it:
   - Stage a file with a fixable lint error and commit without a trailer. The commit-msg hook should refuse.
   - Commit again with `Worksheet: setup-check` as the last line. The lint error should be fixed and the commit should succeed.
   - Stage more than 400 changed lines and commit. The pre-commit hook should refuse and list the largest files.
   - Run `echo "refs/heads/x $(git rev-parse HEAD) refs/heads/x 0000000000000000000000000000000000000000" | .githooks/pre-push` by hand. It should run `bin/verify`, show each check, and end with "bin/verify passed".

## Phase 5: CI (automation)

1. Copy `templates/github/workflows/verify.yml` to `.github/workflows/verify.yml` (or adapt to the existing CI). It runs `bin/verify --full` on every PR.
2. Recordings never go in git. If the user gave a store for them, set `evidence_upload_cmd` in `.shipinetics/config` (the template shows one with rclone, which reaches SharePoint, OneDrive, S3, Google Drive and others). Each person sets up the store's login on their own machine (for rclone: `rclone config`); never put credentials in the repo. Without a store, agents leave recordings on disk and the human attaches them to the PR. Check that `ffmpeg` is installed: `evidence frames` needs it. If it is missing, put the install on the For you list.
3. Check: validate the YAML. Tell the user it runs on their next push.

## Phase 6: visual and performance (points 15, 16, 17)

Follow `shipinetics:visual-regression` and `shipinetics:perf` to add one visual test and one benchmark with baselines. Add both to `bin/verify --full`. Use git LFS for the baselines only if the user said yes to it.

## Phase 7: security tools (shipinetics:security-scans)

1. Check for SkillSpector. If it's missing, give the user the install command. Once installed, run `scan-skills` and show the user the summary. Anything `DO_NOT_INSTALL` is the first thing to deal with.
2. Check for Strix and Docker. If the user wants app security testing and they're missing, put the install on the For you list: install Strix, store its provider key in Secret Manager and add it to `.shipinetics/secrets.list`.
3. Record the local or staging instance the user said Strix may test under `## Security targets` in `AGENTS.md`, above the block (never inside it). Don't run Strix during setup unless they say so.
4. **deepsec** (optional). If the user wants it, put the first run on the For you list with the cap they chose: `npx deepsec init --agent claude --model-auth local --max-cost-usd <cap> --max-duration 2h`, run from the repo root in their own terminal, because it asks questions. With `--agent claude --model-auth local` it uses their Claude Code login and needs no key. Check that `.gitignore` has the `.deepsec/findings/` line from `templates/gitignore-additions`. Tell them the cost first: with Claude Opus, about 25 to 60 US dollars for each 100 files. Don't run it during setup.
5. Add the weekly security pass to their routine (GETTING-STARTED.md in the plugin repo).
6. Ask how often to run a full security audit (security-audit's full mode: thorough, and it costs many agent runs): off, weekly, monthly, quarterly or every N days. Set `security_audit_every` in `.shipinetics/config` (`off`, `weekly`, `monthly`, `quarterly` or `<days>d`). The weekly sweep runs it when `shipinetics-config due security-audit` says it's due.

## Finish

Write `.shipinetics/protected-paths` now, with the contents you decided in Phase 1 and Phase 2. If it already exists, write the full new version to `.shipinetics/pending/.shipinetics/protected-paths` (same path under that folder) and a human reviews and applies it with `shipinetics-config apply` instead. Run `shipinetics-config pending`: if anything is waiting, put its output near the top of the For you list, with what each change does. The output says why the user must apply the changes, and it gives the exact command.

Update `docs/shipinetics-setup.md` with the new status table, the date, and the line "Shipinetics version: <version>" (the plugin's version). `update` reads that line later. Tell the user, in a few lines (including that the guards cover file tools only, see What the guards cover): what's in place now, what you verified, what failed or was skipped, the For you list, and the gate checks to try themselves (Phase 1 step 9).

Setup writes one smoke test, not the tests of the existing app. End the summary with the next step for tests: `/shipinetics:test-backfill`. It adds tests to the existing app a few features at a time, riskiest first, with one approval round for each batch. Give the user the numbers from the testing guide step (the fixed cost of one run, the time of the related tests), because they decide how fast that goes.

Put any row S that's still partial or missing at the top of the For you list, with what it leaves unprotected, for example "env scrub off: commands the agent runs still see credentials". These rows are guardrails. Until they're done, the protection is only partly in force, and the user needs to know that rather than assume it. The weekly sweep checks them again (shipinetics:sweep).

## Update a set-up project

`/shipinetics:setup update` brings a project that is already set up to the plugin's current version. A plugin update changes the skills, agents, hooks and tools at once. The files that setup wrote into the project stay as they were. Work on a branch: `shipinetics-update-<version>`.

After step 2, show the user the list of steps and offer these four ways, with the first one recommended:

| Way | What happens |
|---|---|
| **All steps** (recommended) | The new block, the steps of breaking changes and the optional steps |
| **Breaking steps only** | The new block and the steps of breaking changes. The optional steps go on the For you list, so the user can do them later |
| **Pick the steps** | The new block, and each step that the user chooses from the list |
| **Preview only** | The list of steps and the diff of the block, and no change |

In an autonomous session, do "Preview only", write the list and the diff in the setup log, and add one task to the Blocked section of the queue: "Choose how to run /shipinetics:setup update".

1. **Find the two versions.** The project's version is the "Shipinetics version:" line in `docs/shipinetics-setup.md`, or the `version=` in the begin line of the block in `AGENTS.md`. The plugin's version is `version` in `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`. If they are the same, say so and stop. If the project has no version, it was set up before the block existed: ask the user which version they set up with. If they don't know, skip step 2 and use the audit in step 5 instead.
2. **List the steps.** `shipinetics-update steps <project version>` prints the "Steps for each project" of each release after that version, from `${CLAUDE_PLUGIN_ROOT}/CHANGELOG.md`. Show the user the list: the steps of breaking changes first, then the optional steps, each with what it gives the project.
3. **Replace the block.** In `AGENTS.md`, replace the text between the `shipinetics:begin` and `shipinetics:end` lines with the template's block, with the new version in the begin line. Don't change the text outside. Show the diff. If a project rule outside the block now disagrees with a new rule in it, ask the user about it as in step 3 of "Projects that already have CLAUDE.md or AGENTS.md".

   No begin and end lines (a project set up before the block existed): the old template's sections go to two places. Show both in one diff, and change the file only after the user's yes:

   | Old section | Where it goes |
   |---|---|
   | Run the app yourself | The commands go to "Run the app", above the block. The rule is in the block |
   | Where to find things | Stays as it is, above the block |
   | Secrets | The vault name and the `secrets.list` sentence go to "Secrets", above the block. The rest is in the block |
   | Security tools | The Strix targets go to "Security targets", above the block. The rest is in the block |
   | Setup for a fresh clone | Stays as it is, above the block |
   | Definition of done, Docs stay true, Every session, Review, Tests come from an independent agent, Every PR carries evidence (now "Evidence (optional)"), Explaining your work, Protected files | Replaced by the block |

   Never drop a value that the project filled in (a command, a vault, a target, a step). Text in a replaced section that the old template didn't have is the user's: ask if it is a real difference (it goes under "Where this project differs from Shipinetics", as in step 3) or if it can go.
4. **Do the steps** that the way the user chose includes. A step that only the user can do (an install, a login, a GitHub setting) goes on the For you list. A protected file goes through `.shipinetics/pending/`.
5. **Check.** Run the audit again and compare its table with the one in the setup log. Each row that got worse is a problem to fix or to report. Run the complete `shipinetics-verify`.
6. **Record.** Set "Shipinetics version:" in the setup log to the new version, and add a dated line with what changed. Commit with `SHIPINETICS_ALLOW_NO_WORKSHEET=1`, each commit under 400 lines. Tell the user what changed and what is on the For you list.
