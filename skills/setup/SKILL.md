---
name: setup
description: Audit a project against the shipinetics setup (19 points plus secrets, independent tests, specialist reviewers and explainers) and scaffold what's missing, one phase at a time. Use when the user runs /shipinetics:setup, asks to set up the agentic workflow in a repo, or asks what's missing from their setup.
argument-hint: "[audit|1|2|3|4|5|6|7|8]"
disable-model-invocation: true
---

# Shipinetics setup

You're installing a working agentic setup into this project. The plugin carries the generic parts (skills, reviewer, hooks, scripts). This skill puts the project-specific parts into the repo so they're committed, visible to every agent and to CI, and work without the plugin.

Argument: `$ARGUMENTS`. No argument means: run the audit, ask every question in one message, then run every phase in order in this one run. If `docs/shipinetics-setup.md` shows phases already done, start at the first one that isn't. A number runs just that phase, to redo or repair it. `audit` means audit only.

## Rules

- **Audit before you build.** Never overwrite an existing file. If a file exists, merge into it and show the user the diff. If an existing setup does something differently (a different test runner, a `tools/` folder instead of `bin/`), adapt to it, don't replace it.
- **Detect, don't ask, where you can.** Read `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Makefile`, CI config, lockfiles and existing scripts to find the real commands. Ask only for what you can't find out.
- **Confirm, don't infer.** Live config and scripts are evidence. Comments, TODOs, feedback logs, worksheets and old docs are history: they say what was true once. Before you act on a fact about infrastructure (the secrets vault, deploy target, CI, package manager, which package or runtime is active), find it in live config. If the only evidence is historical, or two sources disagree, ask the user. Say what you inferred and from where, so they can correct it in one answer. A wrong guess here gets written into config and every agent repeats it.
- **Each phase ends with proof.** Run the thing you set up and show it working before you move on. If it doesn't work, fix it or stop and say what's blocking.
- **Ask once, then run straight through.** After the audit, put every question the phases need in one message: the Unconfirmed list, secret names you couldn't find, git LFS for evidence, the `no-evidence` label, which optional phases to run (6 visual and perf, 7 night shift, 8 security tools), for UI projects whether to write PRODUCT.md with `/impeccable init` and whether token changes should need a human (protected design files), which task list is the source of truth if one exists outside `TODOS.md`, whether agents start the app or the user runs the servers (`launch`), and for Phase 8 which instance Strix may test. Then work through the phases without stopping. Stop early only when a phase's proof fails and you can't fix it, or when something comes up that the answers don't cover.
- **What only the user can do goes on a list, not a pause.** Installing a CLI, logging in, creating a GitHub label they didn't approve: add it to a "For you" list in `docs/shipinetics-setup.md` and carry on.
- **Commit as you go.** At least one commit per phase, more where a phase is big (in Phase 2, a commit per few system docs), each under 400 changed lines. Log each phase's result and proof in `docs/shipinetics-setup.md` as you finish it, so a stopped run can resume. From Phase 4 on the commit hooks are live. Setup belongs to no worksheet, so commit with `SHIPINETICS_ALLOW_NO_WORKSHEET=1`.
- Templates are in `${CLAUDE_SKILL_DIR}/templates/`. Copy them, then replace every `{{PLACEHOLDER}}` with real values. Delete sections that don't apply. No placeholder survives into the repo. (GitHub Actions `${{ ... }}` expressions in the CI template aren't placeholders. Leave them.)
- Use a branch: `shipinetics-setup` unless the user is already on one for this.
- **Protected files go through pending.** The edit guard stops agents changing any existing file that `.shipinetics/protected-paths` covers, `.shipinetics/` itself included, and Claude Code stops agents editing `.claude/settings.json`. So write `protected-paths` in Finish, after the phases that edit `.shipinetics/`. For a protected file (on a resumed run, or `.claude/settings.json` at any time), write the full new version to `.shipinetics/pending/<path>` (same path under that folder) and a human reviews and applies it with `shipinetics-config apply`. Put `shipinetics-config apply` on the For you list. Never ask the user to restart with `SHIPINETICS_UNLOCK=1` to get setup through.

## What the guards cover

The edit guard sees only Claude's file tools (Edit, Write, NotebookEdit). It doesn't see Bash, so `mv`, `cp`, `sed -i`, `git mv` or a script can change a protected file, a test file or a policy list without being stopped. That's a gap in the enforcement, not permission: the rule still holds, and reviewers check diffs for it. So a maintenance move on a guarded file goes through a human or a named command, never a Bash workaround:

| Move | Route |
|---|---|
| Change a protected file (acceptance test, baseline, policy list, `.claude/settings.json`) | The new version in `.shipinetics/pending/<path>`, then a human runs `shipinetics-config apply` |
| Rename, move or rewrite tests in bulk (framework migration) | `shipinetics:test-writer`, or a human starts the session with `SHIPINETICS_ALLOW_AUTHOR_TESTS=1` |
| Reset a benchmark baseline | `bench-compare --init` (a pending proposal once a baseline exists) |
| Quarantine failing tests | `known-failing init` (a pending proposal once the list exists) |
| Move a project from Shipyard | `shipinetics-config migrate` |
| Check which rule covers a path | `shipinetics-config match <list> <path>` |

Tell the user this in the Finish summary in one or two sentences, so they don't read the guards as a sandbox.

## Projects set up under the old name

Shipinetics used to be called Shipyard. A project with a `.shipyard/` folder and no `.shipinetics/` was set up before the rename. It still works for one version, but migrate it before anything else: with a clean tree, run `shipinetics-config migrate --dry-run`, show the user the plan, then run `shipinetics-config migrate` and commit the result on its own (see `${CLAUDE_SKILL_DIR}/../../MIGRATING.md`). The setup log moves to `docs/shipinetics-setup.md` and still says which phases are done.

## Projects that already have a harness

Many projects already have their own versions of these pieces under other names: a router, worksheet scripts, a validate script, review and testing docs. Shipinetics fits over them instead of replacing them.

- **Map, don't duplicate.** For each point the audit marks in place, set the matching key in `.shipinetics/config` (from `templates/config`) to the existing file or command: `worksheets_dir`, `feedback_file`, `systems_dir`, `conventions_file`, `test_index_file`, `testing_guide_file`, `verify_cmd`, `worksheet_new_cmd`, `worksheet_tag_cmd`, `tag_prefix`, `secrets_runner`. Shipinetics's skills, hooks and tools then use the project's own files. Show the user the mapping, and check it with `shipinetics-config`.
- **Only add what's missing.** Skip any template that duplicates something the project already has (`bin/verify`, the docs templates, `TODOS.md`). Add the `.shipinetics/` lists and a short Shipinetics section in the existing router that points to the new capabilities.
- **Leave the router and CLAUDE.md alone** beyond that section. If `CLAUDE.md` is very long, tell the user what it costs (it loads into every session) and suggest trimming, but don't do it during setup.
- **Secrets:** match how the project already runs things with secrets. For Infisical, set `secrets_runner = infisical run --env=<env> --` (and `vault = infisical` if the project copies `bin/with-secrets`).

## Multi-repo workspaces

If the project root isn't a git repo but holds several package repos, use workspace mode:

- Put `.shipinetics/` at the workspace root. Set `packages` to the package folders and `package_verify_cmd` to the per-package check, with `{package}` where the folder name goes. If the package check can scope itself to changed files, set `package_verify_quick_cmd` for mid-task stops too (`$SHIPINETICS_CHANGED_FILES` lists paths relative to the package repo).
- Keep `verify_scope = touched` (the default). The Stop hook then verifies only the packages the agent edited in that session, so the user's own unrelated work in progress never blocks an agent.
- If packages keep committed copies of worksheets, set `package_worksheets_dir` so the evidence tool can find them on a branch.
- Lists in `.shipinetics/` use paths relative to the workspace root, such as `api/src/config/*`.
- **Don't write into package repos that have uncommitted work.** Per-package pieces (the commit hooks, the CI evidence job, git LFS, the `no-evidence` label) go on a list for the user to do one package at a time. Leave out the commit-msg hook in packages that record worksheets through `package_worksheets_dir` instead of trailers.
- **Version the harness files.** A root that isn't a git repo leaves `.shipinetics/`, the queue, the worksheets and the root's docs unversioned: one bad edit loses them, nobody reviews changes to the policy lists, and `night-shift` can't run. `shipinetics-config` warns about it. Flag it in the audit, and offer the user one of these:
  - **The root becomes the harness repo** (simplest): `git init` at the root, with a `.gitignore` that ignores each package folder (`api/`, `web/`) and `.claude/worktrees/`. Commit the harness files.
  - **A separate harness repo**, when the root must stay plain (a shared folder, or a repo already exists for this): a git repo whose top level holds `.shipinetics/`, `AGENTS.md`, `CLAUDE.md`, the queue and `docs/`, with the root's copies replaced by symlinks into it, and the package folder names in its `.gitignore`. Set `harness_repo` in `.shipinetics/config` to its path, relative to the root.
  Changing the root's layout is the user's call, so put the commands on the For you list unless they said yes during the audit.
- `night-shift` runs in workspace mode once the harness files are versioned: it makes a worktree of the harness repo with a worktree of each package inside it (or of `--packages`), all on `night/<date>`, and the Stop hook verifies each package with `package_verify_cmd`.

## Audit

Check each point and fill this table. Status is **in place**, **partial** or **missing**, and evidence is a file path or a one-line reason. Evidence must be live config or code, not a comment or a log entry. Anything you could only infer goes in an "Unconfirmed" list at the end of the audit, and you ask the user about it before Phase 1. Write the table to `docs/shipinetics-setup.md` (create it from scratch, this is the setup log) and show it to the user.

| # | Point | What to look for |
|---|---|---|
| 0 | Router | `AGENTS.md` that routes to docs, skills and tools. `CLAUDE.md` that imports it with `@AGENTS.md` |
| 1 | Workflow | A workflow doc or skill (`AGENT_WORKFLOW.md`, or rely on `shipinetics:workflow`) |
| 2 | System docs | `docs/systems/*.md` with 7-line greppable headers, rule in `AGENTS.md` |
| 3 | Run the app | `AGENTS.md` says exactly how to start the app, seed data and log in. `docs/verification/` holds the verification map: launch, doctor, drive, cleanup, and a file per main feature with every entry point |
| 4 | Tests | e2e suite, `docs/testing/how-to-write-tests.md`, `docs/testing/test-index.md` |
| 5 | Lint and fix | pre-commit hook that auto-fixes, with LLM fallback, and a commit size limit. commit-msg hook that requires the `Worksheet:` trailer |
| 6 | Review | `agent_review` works and finds a non-Claude CLI, project personas if any |
| 7 | Worksheets | `docs/worksheets/`, tagging convention |
| 8 | Feedback | `docs/agent-feedback.md` |
| 9 | Tools | `bin/` or `tools/` with `docs/tools.md` index |
| 10 | Sweeps | sweep reports in `docs/sweeps/` or a schedule for them |
| 11 | Conventions | `docs/conventions.md` with enforcement markers |
| 12 | Night shift | `night-shift` runs, guardrail settings in place |
| 13 | Task queue | `TODOS.md` in the shipinetics format, or a Linear CLI |
| 14 | Test audit | audit reports or a schedule |
| 15 | Visual regression | screenshot tests with baselines (LFS or PR artifacts), plus `shipinetics:ui-reviewer` for agent visual review |
| 16 | Perf benchmarks | benchmarks with baselines and a regression threshold |
| 17 | Profiling | documented profiling commands per stack |
| 18 | End of shift | `bin/verify --full` covers everything |
| S | Secrets | No `.env` files or committed secrets. A config module is the only reader of the environment. `.shipinetics/secrets.list`, `bin/with-secrets`, `.shipinetics/env-allowed-paths`. `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` in `.claude/settings.json`. Its deny rules match the vault the project actually uses (`vault` in `.shipinetics/config`, confirmed in live config): rules for a vault the project doesn't use are stale and the real vault is unprotected, so that's **partial** |
| T | Independent tests | `.shipinetics/test-paths` matches the project's test layout, so only `shipinetics:test-writer` writes tests |
| D | Design system (UI projects) | DESIGN.md with token frontmatter, matching the tokens in code (CSS variables, Tailwind theme, CSS-in-JS theme, token files) and the component library (`components.json`, Storybook). PRODUCT.md. The Impeccable block in `.gitignore`. `design-check --all` runs |
| R | Specialist reviewers | `security-audit` skill installed (for `shipinetics:security-reviewer`), `impeccable` skill installed (for `shipinetics:ui-reviewer`), `merge-risk` skill installed (for merge-risk grades), Whiteboard MCP available (`session_capabilities` answers) |
| V | Evidence on every PR | `.shipinetics/ui-paths`, `docs/evidence/` tracked with git LFS, the CI evidence job in every repo that opens PRs (each package repo in workspace mode), a `no-evidence` label in the GitHub repo |
| X | Security tools | SkillSpector installed (`scan-skills` runs), Strix installed with its provider key in the vault, Docker available |
| E | Explainers | `.shipinetics/explainers/` gitignored. Optional: Manim or Remotion, a local TTS, an ElevenLabs key in Secret Manager |

For row R, check with the tools you have: try loading each skill, and call the Whiteboard `session_capabilities` tool. If one is missing, give the user the install command:

- security-audit: `npx skills add cloudflare/security-audit-skill`
- Impeccable: the Claude Code plugin (`/plugin marketplace add pbakaus/impeccable`, then install it from `/plugin`), or `npx impeccable install --providers=claude`. Avoid `npx skills add pbakaus/impeccable` for Claude Code: it installs the copy in the repo's `.agents/skills/` folder, written for Codex (`$impeccable` commands, Codex's question tool). If both are installed, `shipinetics:ui-reviewer` uses the plugin.
- merge-risk: `npx skills add warpdotdev/common-skills --skill merge-risk`
- Whiteboard: the dev.fast Whiteboard plugin from its marketplace.

## Phase 1: core loop (points 0, 3, and the verify gate)

The goal is one loop that works end to end: the agent can't stop while checks fail, and a reviewer checks the work.

1. **Find the commands.** Typecheck, lint, unit tests, e2e, how to start the app, which port, how to seed data, how to log in with a test user. Find out who runs the servers. If the user starts them (they need the user's credentials or devices, or the agent's sandbox can't run them), set `launch = user` in `.shipinetics/config`, and agree a test account for agents' writes. Run each one to confirm it works today. Note any that fail on a clean checkout: that's the first thing to tell the user.
2. **`bin/verify`** from `templates/bin/verify`, with its three tiers. Each check runs at the moment its result is needed, and none is skipped:
   - `--quick` runs at mid-task stops. Scope each check to the files in `$SHIPINETICS_CHANGED_FILES` (lint the changed files, type-check incrementally, run the tests related to the changes). Keep it to seconds.
   - The default (complete) tier is every fast check, including the build and the e2e smoke test. It runs at the stop after the worksheet is marked done, at any stop that changes a path in `.shipinetics/complete-paths`, before a push and before a PR. Keep it to a few minutes.
   - `--full` runs everything, in CI and at end of shift.

   Fill in the step functions with the project's real commands. Steps in `parallel` run at once, so only put independent checks there. Local caches (`eslint --cache`, `tsc --incremental`, the build tool's cache) are fine, because CI runs without them. If the project's tools can't scope a check to files, run the whole check in `--quick` too, as long as it's fast. Leave anything slow (a build, e2e) to the complete tier. `chmod +x` it. Run all three tiers and record each one's time in `docs/shipinetics-setup.md`. Set `verify_quick_cmd = bin/verify --quick` in `.shipinetics/config`. If the suite already fails on a clean checkout and the user can't fix it now, quarantine the failures instead of skipping tests (shipinetics:testing, "A suite that already fails"): the user runs `known-failing init`, and `bin/verify` gates on `known-failing check`.
3. **`.shipinetics/`**: decide the contents of `.shipinetics/protected-paths` from `templates/protected-paths` now, and write the file in Finish (see Rules). Create `.shipinetics/test-paths` from `templates/test-paths`, adjusted to where this project's tests actually live (check with `git ls-files`). Create `.shipinetics/ui-paths` from `templates/ui-paths`, adjusted to where this project's UI code lives (it decides which changes need a screen recording as evidence). Create `.shipinetics/complete-paths` from `templates/complete-paths`: the build config, manifests and lockfiles whose changes need the complete tier at every stop, because a check scoped to changed files can't see their effect. Append `templates/gitignore-additions` to `.gitignore`.
4. **Secrets.** Find how the project reads configuration today (`rg -l 'process\.env|os\.environ|getenv'`).
   - If there's no single config module, propose one to the user (`src/config/` or the stack's equivalent) that reads, validates and exports every variable. Moving existing reads into it is its own task: add it to the queue rather than doing it during setup.
   - Create `.shipinetics/env-allowed-paths` from the template with the config module's path. If existing code reads the environment elsewhere, the hook only blocks new reads, so nothing breaks.
   - Create `.shipinetics/secrets.list` with the names (never values) of the secrets the config module needs and their Secret Manager names. Ask the user for the Secret Manager names and project if you can't find them in deploy config.
   - Copy `templates/bin/with-secrets` to `bin/with-secrets` and `chmod +x` it. Check it works with a harmless command: `bin/with-secrets true` (it fails clearly if gcloud isn't logged in, which is fine to report).
   - If any `.env` file is tracked in git, stop and tell the user. Don't read it.
   - Build the merged `.claude/settings.json`: the project's current file, if any, plus `templates/claude/settings.json`. It turns on `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` and denies vault reads and credential files. The template's vault rules are for Google Secret Manager. Swap them for the project's vault: for Infisical, deny its `secrets` and `export` subcommands and `Read(~/.infisical/**)`; for others, the command that prints a secret and the CLI's credential folder. Remove rules for vaults the project doesn't use, so the file says what's really protected. Agents can't edit Claude Code's settings files, so write the result to `.shipinetics/pending/.claude/settings.json`, show the user the diff, and put `shipinetics-config apply` on the For you list. If even that write is refused, put the exact JSON on the For you list instead.
5. **`AGENTS.md`** from the template, filled in for this project. If one exists, merge: keep everything the user wrote and add the missing sections. Keep it under about 120 lines. It routes, it doesn't explain.
6. **`CLAUDE.md`**: if missing, create it from the template (it imports `@AGENTS.md`). If it exists with real content, move that content into `AGENTS.md` and leave the import, after showing the user.
7. **Playwright smoke test** (web projects): if there's no e2e setup, install Playwright and add `templates/e2e/playwright.config.ts` at the repo root, adapted to the app's real start command (through `bin/with-secrets` if it needs secrets) and port. The smoke test itself is a test file, so you don't write it: spawn `shipinetics:test-writer` with `templates/e2e/smoke.spec.ts` as the starting point, the app's main screen, and the instruction to make it a single `@smoke` test that fails on console errors. It runs the test, watches it pass, breaks it on purpose (wrong heading text), watches it fail, and restores it. If the project already has an e2e setup, ask test-writer for just the one `@smoke` test in it. For non-web projects, ask test-writer for the equivalent: one end-to-end test through the real entry point (CLI, API, worker).

   Then build the **verification map** (shipinetics:verification-map `create`): `docs/verification/` with how to launch the app from empty data, a read-only doctor check, how to drive it, how to clean up, and the first 3 to 5 features with every entry point. Its end-to-end self-proof (launch, doctor, drive one feature, evidence survives cleanup) is this step's proof. Point "Run the app yourself" in `AGENTS.md` at it.
8. **Prove the gate.** Run `shipinetics-verify` and `shipinetics-verify quick`, then `shipinetics-verify status`, to show both tiers pass and are recorded. Tell the user how to see the hook: make a small change that breaks a test, ask the agent to finish, and watch the Stop hook send it back. You can't trigger your own Stop hook in a way the user sees, so describe it and leave the test to them. After a week of use, `shipinetics-verify times` shows where verify time goes.
9. **Prove the reviewers.** Run `agent_review --list` and report which CLIs are installed. If none is from a different family than Claude, tell the user cross-family review needs one of Codex, Gemini or Cursor's CLI. Check row R of the audit (security-audit, impeccable, Whiteboard) and report what's missing, with install commands.
10. Commit with a message explaining the setup. Update `docs/shipinetics-setup.md`.

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

1. Copy `templates/bin/lint-fix` and `templates/bin/llm-fix` to `bin/`, `templates/pre-commit` to `.githooks/pre-commit`, `templates/commit-msg` to `.githooks/commit-msg` and `templates/pre-push` to `.githooks/pre-push`. The pre-push hook runs the complete verify, and reuses a pass the agent already recorded for the same code. Fill in the project's fixers and checkers in `bin/lint-fix`. In `.githooks/pre-commit`, add the project's generated files to `ignore`, and change the worksheets and evidence paths there if `.shipinetics/config` maps them elsewhere. Keep `max_lines` at 400 unless the user asks otherwise.
2. Run `git config core.hooksPath .githooks`, and add that command to the setup section of `AGENTS.md` so fresh clones get it. If the project already uses husky, lefthook or pre-commit, keep both hooks in `.githooks/` and call them from that tool's pre-commit and commit-msg stages instead (the commit-msg hook takes the message file as its argument).
3. Check on a scratch branch, then delete it:
   - Stage a file with a fixable lint error and commit without a trailer. The commit-msg hook should refuse.
   - Commit again with `Worksheet: setup-check` as the last line. The lint error should be fixed and the commit should succeed.
   - Stage more than 400 changed lines and commit. The pre-commit hook should refuse and list the largest files.
   - Run `.githooks/pre-push` by hand. It should report the complete verify as passed (reused if you ran `shipinetics-verify` already).

## Phase 5: CI (automation)

1. Copy `templates/github/workflows/verify.yml` to `.github/workflows/verify.yml` (or adapt to the existing CI). It runs `bin/verify --full` on every PR, and its `evidence` job fails any PR whose description has no `## Evidence` section with a screenshot, recording or transcript.
2. If the user said yes to git LFS for evidence: `git lfs install`, `git lfs track "docs/evidence/**"`, commit `.gitattributes`. Without LFS, screenshots go in git and recordings stay small or get attached to the PR by hand.
3. If the user approved the `no-evidence` label for docs-only PRs, run `gh label create no-evidence`. Otherwise it goes on the For you list, since it changes the GitHub repo.
4. Check: validate the YAML. Tell the user it runs on their next push.

## Phase 6: visual and performance (points 15, 16, 17)

Follow `shipinetics:visual-regression` and `shipinetics:perf` to add one visual test and one benchmark with baselines. Add both to `bin/verify --full`. Use git LFS for the baselines only if the user said yes to it.

## Phase 7: night shift (points 12, 18)

1. Make sure `TODOS.md` has at least one task marked ready, with acceptance criteria.
2. Check `.claude/settings.json` has the template's settings from Phase 1 (env scrub and deny list), or that the proposal in `.shipinetics/pending/.claude/settings.json` is still waiting on the For you list. If secrets are needed by tasks, make sure `bin/with-secrets` works inside the sandbox: gcloud needs network access to `secretmanager.googleapis.com` and `oauth2.googleapis.com`. Tell the user to add those to their sandbox network allowlist if it fails.
3. Check: `night-shift --dry-run` creates the worktree and exits cleanly. Explain the real command and its limits to the user. Don't start a real shift without the user saying so.

## Phase 8: security tools (shipinetics:security-scans)

1. Check for SkillSpector. If it's missing, give the user the install command. Once installed, run `scan-skills` and show the user the summary. Anything `DO_NOT_INSTALL` is the first thing to deal with.
2. Check for Strix and Docker. If the user wants app security testing and they're missing, put the install on the For you list: install Strix, store its provider key in Secret Manager and add it to `.shipinetics/secrets.list`.
3. Record the local or staging instance the user said Strix may test in the Secrets or Security section of `AGENTS.md`. Don't run Strix during setup unless they say so.
4. Add the weekly security pass to their routine (GETTING-STARTED.md in the plugin repo).

## Finish

Write `.shipinetics/protected-paths` now, with the contents you decided in Phase 1 and Phase 2. If it already exists, write the full new version to `.shipinetics/pending/.shipinetics/protected-paths` (same path under that folder) and a human reviews and applies it with `shipinetics-config apply` instead. Run `shipinetics-config pending`: if anything is waiting, put `shipinetics-config apply` near the top of the For you list, with what each change does.

Update `docs/shipinetics-setup.md` with the new status table and the date. Tell the user, in a few lines (including that the guards cover file tools only, see What the guards cover): what's in place now, what you verified, what failed or was skipped, the For you list, and the gate checks to try themselves (Phase 1 step 8).

Put any row S or V that's still partial or missing at the top of the For you list, with what it leaves unprotected, for example "env scrub off: commands the agent runs still see credentials" or "no CI evidence job in `web`: PRs from it can merge without evidence". These rows are guardrails. Until they're done, the protection is only partly in force, and the user needs to know that rather than assume it. The weekly sweep checks them again (shipinetics:sweep).
