# Changelog

Shipinetics uses [Semantic Versioning](https://semver.org).

- Before 1.0.0, a **breaking** change increases the minor number (0.6.0 to 0.7.0). A breaking change removes or changes something that a project uses: a command, a setting, a file name or a hook rule. Its entry gives the steps for each project.
- Other changes increase the last number (0.7.0 to 0.7.1).
- Each release has a git tag, `vX.Y.Z`, on the commit that sets its version.

## Unreleased

### Changed
- A new agent, `shipinetics:test-plan-reviewer`, reviews test-writer's test plan before any test is written, for tasks M and up. It runs on Sonnet at high effort. Test-writer gets "Plan first", returns its plan and writes no files. The reviewer gives each row KEEP, CUT, MERGE, MOVE or REWRITE, by the spec and the test index, and lists acceptance criteria with no row. Then the same test-writer writes the tests of the approved plan. Before, irrelevant tests were found only after they were written and mutation-proven. S tasks and regression-only requests skip the review. A cut row that test-writer keeps goes under "Plan disputes", and the test-integrity review decides.
- A new agent, `shipinetics:live-tester`, does the re-check at wrap-up. It runs on Sonnet at medium effort. Before, `shipinetics:reviewer` drove the app on Opus at high effort. The re-check only drives the app and reports PASS, ISSUES or BLOCKED, so it does not need the reviewer's model. The reviewer no longer drives the app. The steps of the re-check did not change.
- Tests come after the code. The agent implements the change and commits it. Then `shipinetics:test-writer` writes the tests for that commit, in one request with every mode the task needs. Before, test-writer wrote acceptance tests before the code, and they failed by design. Test-writer still works from the spec and the public interface, and it still proves that each test catches its bug.
  - New tests must pass on the code. A failure is a suspected bug.
  - New and changed tests must also fail on the code before the change. Test-writer runs them once against the base commit, in a git worktree. This keeps the old fail-first proof.
  - `change` mode runs after the code changes. Until then, the old tests of changed behaviour can fail.
  - The `spec` skill no longer starts test-writer. It checks that each criterion is testable. The `/goal` line says that test-writer wrote the tests after the implementation.
- Test-writer is faster. In 7 measured runs, most of the time went to test runs and waits, not to writing (57, 36 and 16 minutes for the three longest). Now:
  - One script runs all the mutants, in a git worktree under `$TMPDIR` with a unique path (not a full copy of the repo). Each mutant runs only the new and changed tests, not the suite. Mutants run in parallel, one worktree per worker, when `how-to-write-tests.md` says that copies can run at the same time. A sanity mutant first shows that the worktree runs its own code.
  - Test-writer waits for a done file with a short poll, never with a fixed long `sleep`.
  - Test-writer runs only targeted tests. It no longer runs the full suite: the complete `shipinetics-verify`, before the work is done, runs it.
  - Slow tests are reported to the user. Test-writer measures the fixed cost of one targeted run. If it is over 10 seconds, or the proof runs take over 5 minutes, its report has a "Slow test runs" section: the numbers, the likely cause and the usual fix. The agent tells the user, once per project, and doesn't change the test setup without the user's yes. In an autonomous session, it adds a queue task.
  - Test-writer starts only after the change is committed, and nobody edits source while it runs. So it never waits for edits to stop.
  - The `how-to-write-tests.md` template has the fastest targeted command, its fixed cost per run, and whether copies can run at the same time. A high fixed cost (for example, a test database built again from all migrations on each run) makes each proof run slow.
- **Steps for each project.** Test-writer reads the project's own copies of these files, so the old order stays until you change them:
  - `AGENTS.md`: change "Give it the spec and the interface" to "Implement and commit first. Then give it the spec and the commit range".
  - `docs/testing/how-to-write-tests.md`, "Which test to write": the new behaviour row says the e2e test is written "after the code", not "before the code". The bug fix row says the case "passes on the fix and fails on the code before the fix (test-writer runs it against the base commit)", not "failing without the fix. Watch it fail first". The changed behaviour row says "in the same task", not "before the code".
  - `docs/testing/how-to-write-tests.md`, "Rules": "changes its tests in the same task", not "changes its tests first". "a scratch worktree", not "a scratch copy".
  - `docs/testing/how-to-write-tests.md`, "Layout and commands": add the fastest targeted command, its fixed cost per run, and whether copies can run at the same time. `/shipinetics:setup audit` shows these differences.

## 0.8.1

### Added
- Companions. `companions.tsv` lists the skills, plugins and tools that Shipinetics uses together with its own skills. They are Matt Pocock's `grilling`, `domain-modeling`, `wait-what`, `research`, `prototype`, `codebase-design` and `diagnosing-bugs`, Cloudflare's `security-audit`, Warp's `merge-risk`, Impeccable, Whiteboard, SkillSpector and Strix (optional). Each row gives why Shipinetics uses the companion, its install command and its SkillSpector result.
  - The SkillSpector results come from SkillSpector 2.12.0 in static mode, on 2026-10-28. Impeccable and `security-audit` get DO_NOT_INSTALL in static mode. Each of their HIGH findings was checked by hand, and all of them are false positives. The README gives the details and the versions that were scanned.
  - A session-start notice (`scripts/companions-notice.sh`) lists each missing companion, with the reason, the SkillSpector result and the install command. It installs nothing.
  - `shipinetics-companions` shows the status of each companion. `shipinetics-companions install` prints the install commands of the missing ones.
  - `companions_skip` (project or user config) declines a companion. Then the notice does not list it. `hooks_off = companions` switches off the notice.
  - The README and GETTING-STARTED install steps include the companions. Setup checks them with `shipinetics-companions`.
- Token usage. `shipinetics-usage` shows the tokens that each Claude Code session used: new input, cache write, cache read and output, for each agent and model, subagents included. It reads Claude Code's own transcripts, so no model runs and it costs nothing. Each API call counts once (Claude Code writes one response several times).
  - A SessionEnd hook (`scripts/usage-record.sh`) records each session in `~/.local/share/shipinetics/usage.tsv` when it ends. The log keeps the numbers after Claude Code deletes old transcripts. `hooks_off = usage` switches it off.
  - `shipinetics-usage html` makes a page with charts of the tokens for each session and each agent, with a table view for each chart.
  - The worksheet Metrics block has rows for tokens and API calls, from `shipinetics-usage session`. The Turns row is gone. The feedback ingest compares tokens across tasks.
- Routes. For small tasks and larger, the agent offers two or three routes for the task and recommends one. Each route names the companion skills that it uses (`shipinetics:workflow`, "Choose a route").

### Changed
- Tests grow only with new behaviour. Test-writer has a `change` mode. Before code changes or is deleted, it changes or deletes the tests that cover it. It names each deleted test. One test covers one behaviour, with every assertion that the behaviour needs. Test-writer reports the net change in tests and runs the full suite. The test-integrity reviewer flags tests left behind for removed code, and the test audit deletes orphans first.
- The agents run on Opus. `reviewer` uses high effort. `test-writer`, `security-reviewer` and `ui-reviewer` use medium effort. Before, all four ran on Sonnet at high effort. The `review` and `testing` skills no longer tell the main agent to start these agents on a different model.
- Text for people is in ASD-STE100 in every skill that writes it, and in the doc and worksheet templates. Structure and flow go on a Whiteboard. A committed file also gets a Mermaid diagram and a link to the Whiteboard. Without Whiteboard, Mermaid is the only diagram.
- The `feedback` skill gives a format for the ingest report, and its examples are in ASD-STE100.

### Removed (breaking)
- `agent_review`, and with it every use of the Codex, Gemini and Cursor CLIs. Shipinetics is a Claude Code plugin, so it uses Claude only. `shipinetics:reviewer` gives the review at each checkpoint. Also removed: the `reviews_dir` config key, the variables `SHIPINETICS_AUTHOR`, `SHIPINETICS_REVIEW_ORDER`, `SHIPINETICS_CODEX_*`, `SHIPINETICS_GEMINI_MODEL`, `SHIPINETICS_CURSOR_*`, `SHIPINETICS_CLAUDE_REVIEW_*` and `SHIPINETICS_FIX_CLI`, and the Cursor option of `bin/llm-fix`.
  - **Steps for each project:** remove the `agent_review` lines from `AGENTS.md` and `docs/tools.md`. Remove `reviews_dir` from `.shipinetics/config`. If `bin/llm-fix` has a `cursor` branch, remove it.
- Rule 3 of the edit guard: new reads of the environment only in the files of `env-allowed-paths`. The rule that only the config module reads the environment is gone with it. The secrets guard is not changed.
  - **Steps for each project:** delete `.shipinetics/env-allowed-paths`. In `AGENTS.md`, remove the sentences about the config module. In `docs/conventions.md`, remove the convention "Only the config module reads the environment".
- The edit guard no longer blocks edits to `~/.config/shipinetics/`.
- The `build-tool` skill. Its main rules are now in step 9 of `shipinetics:workflow`. A script has a `--help` usage block, no prompts, clear errors and fixed exit codes, and a line in `docs/tools.md`.
  - **Steps for each project:** in `AGENTS.md`, replace `shipinetics:build-tool` with `shipinetics:workflow, step 9`.
- The lists of skills not to use with Shipinetics, in the workflow skill and the README. You can use other skills. The edit guard still lets only test-writer write tests.

### Fixed
- Test-writer and the test audit broke the source file in the working tree to prove that a test can fail. Then they restored it with `git checkout -- <file>`. That deletes every uncommitted change in the file, and it changes files that another agent may be editing at the same time. Now they break a scratch copy of the project under `$TMPDIR`, and never write a file outside the test paths.
- `shipinetics-verify`, the README, the config template and the setup skill still described the Stop hook, which 0.8.0 removed. GETTING-STARTED still named a nightly routine.

## 0.8.0

### Removed (breaking)
- The Stop hook. It ran verify each time the agent stopped. Then a failing or flaky test sent the agent back again and again, and a short question cost minutes of checks. Now the agent runs verify itself: `shipinetics-verify quick` after each step, and `shipinetics-verify` before the work is done. The pre-push hook and the PR gate still refuse code without a complete pass.
  - The once-a-session reminders (worksheet, feedback log, a regression test first for a bug) are gone with it. The workflow skill already gives these steps.
  - `.shipinetics/complete-paths`, `verify_scope` and the `stop` name in `hooks_off` are gone. They were only for the Stop hook.
  - **Steps for each project:** delete `.shipinetics/complete-paths`. Remove `verify_scope` and `stop` from `.shipinetics/config` (old values do nothing now). In `AGENTS.md`, replace the sentences about mid-task stops with the new text from `skills/setup/templates/AGENTS.md`.
- The night shift: the `night-shift` launcher and the `night-shift` and `end-of-shift` skills.
  - **Steps for each project:** remove the `night-shift` line from `docs/tools.md`. Delete `docs/shifts/` if you do not need the old reports.

## 0.7.3

### Fixed
- The edit guard did not keep agents out of your settings when `XDG_CONFIG_HOME` ended in `/` or had `//` in it. Now it does.
- Three tests failed on macOS in CI. There, `$TMPDIR` ends in `/`. The tests now remove that `/`.

## 0.7.2

### Changed
- All text for people uses ASD-STE100 (Simplified Technical English). This includes the README, GETTING-STARTED, this changelog, system docs, reports, worksheets, PR bodies, Whiteboards and chat replies. The `explain` skill gives the rules. Other skills point to it.
- The README and GETTING-STARTED are written again in ASD-STE100. They now include steps to update to a new version, and steps to release a version.

### Fixed
- The README and GETTING-STARTED had old install steps. They said the plugin was not on GitHub, and they installed Matt Pocock's skills as a plugin.

## 0.7.1

### Changed
- Tests are written for each behaviour, never for each function. This is Google's rule ("Software Engineering at Google", chapter 12).
  - Test-writer's plan lists behaviours. Each one is a sentence from the spec. For each one, the plan gives the bug that the test catches, the layer, the entry point, and the existing test that it extends.
  - Test-writer sorts the code first. Domain logic gets tests of its behaviours. Glue code gets one test at its entry point. Trivial code gets no tests. Logic mixed with I/O is reported, so that someone can split it.
  - Each behaviour has one layer and one test file. A fix adds a case to the test of its behaviour. It does not make a new file with the name of the fix.
- The test-integrity persona finds four problems: tests for each function, behaviours tested at two layers, test files named after fixes, and tests that break when the code is restructured. `test-audit` changes these tests into tests for each behaviour.
- The test index lists behaviours, not files. Test-writer uses it to find the test to extend.

## 0.7.0

### Changed (breaking)
- The glossary is `GLOSSARY.md` (and `GLOSSARY-MAP.md` when there are several). The old name was `CONTEXT.md`. Matt Pocock's `domain-modeling` uses the new name. **Step:** if a project has `CONTEXT.md`, run `git mv CONTEXT.md GLOSSARY.md`.
- The install gate also asks you before these commands: `npx skills update`, `npx skills check`, `claude plugin update` and `claude plugin marketplace update`. An update brings new code. `skills check` can update and remove skills while it checks.

### Removed (breaking)
- The plugin's former name. Projects must use `.shipinetics/`, the `SHIPINETICS_*` variables, and the commands `shipinetics-config` and `shipinetics-verify`. These parts are removed: the fallback to the old folder and variable names, the old command names, `shipinetics-config migrate`, and the migration guide. **Step:** if a project still has the old folder, rename it to `.shipinetics/`. Then rename the old variables in its scripts and docs.

### Added
- Hooks are modular. Switch off any hook with `hooks_off` (`stop`, `edits`, `secrets`, `pr`, `installs`). Put it in the project's config, or in `~/.config/shipinetics/config`. For one session, use `SHIPINETICS_HOOKS_OFF`.
- You choose the secret files. Write a `secret-paths` list (one pattern on each line) in `.shipinetics/` or in `~/.config/shipinetics/`. It replaces the built-in list of credential files. Setup has a template.
- The edit guard keeps agents out of `~/.config/shipinetics/`.
- A schedule for the full security audit: `security_audit_every` (`off`, `weekly`, `monthly`, `quarterly` or a number of days such as `14d`). Setup asks for it. `shipinetics-config due security-audit` tells you when an audit is due. The weekly sweep runs it. Each audit adds one line of counts to `docs/security/audits.md`. The findings stay outside the repo.
- `/wait-what` (Matt Pocock) in the workflow and explain skills. You type it when a message is not clear, and the agent explains again, more simply.
- Grilling also happens before each decision that is hard to reverse, not only before specs.
- Companions stay up to date. The weekly sweep runs `skills-outdated`, a read-only check of each installed skill against its repo. It also compares plugins with their marketplaces. You scan and update. Then the sweep checks the details that Shipinetics needs (README, "What Shipinetics needs from each companion"). Setup installs skills with `-g`, so the check finds them.
- The tests are isolated from the machine. Each test has its own home folder, settings folder and git config. It ignores `SHIPINETICS_*` and Claude Code variables from the shell. Only this plugin's commands are on the `PATH`.
- Tests for the `SHIPINETICS_SKIP_VERIFY` and `SHIPINETICS_UNLOCK` overrides.

## 0.6.0

### Added
- Pending changes for protected files. An agent writes a proposal to `.shipinetics/pending/<path>`. A person reviews and applies it with `shipinetics-config pending` and `apply`.
- `launch = user`, for projects where you start the dev servers yourself.
- `bench-compare`, with baselines for each machine, budgets and a noise check. Also the keys `bench_cmd` and `package_bench_cmd`.
- `known-failing`. When a suite already has failures, only new failures fail the check.
- `harness_repo`. Also a warning when the own files of a workspace are not in git.
- `night-shift` in workspace mode.
- A Stop hook reminder: on a bug fix, write a failing regression test first.
- `shipinetics-config match <list> <path>`.
- `env_safe_names`: variables that the environment guards ignore.

### Changed
- The secrets guards ignore text that cannot show a secret: heredoc bodies that go into files, search patterns, docs, and reads of safe variables. Block messages name the project's `secrets_runner`.
- Setup proposes `.claude/settings.json` through pending changes. It does not edit the file. Setup writes `protected-paths` last.

### Fixed
- The secrets guard did not find `env`, `export` or `set` when a new line came after them.
- With a `..` path, the edit guard let an agent reach a protected file through the pending folder.

### Deprecated
- The former name's folder, variables and commands. They still worked in this release, with a notice. 0.7.0 removed them.

## 0.5.0

### Changed (breaking)
- The plugin's new name is Shipinetics. This changed the skill prefix (`shipinetics:`), the project folder (`.shipinetics/`), the environment variables (`SHIPINETICS_*`) and the commands (`shipinetics-config`, `shipinetics-verify`).

## 0.4.0

### Added
- Tests for the hooks and tools. CI runs them on Linux, and on macOS's bash 3.2.

### Fixed
- Problems that a review found in the verify tiers, the PR gate and the evidence check.

## 0.3.0

### Added
- Verify tiers: quick, complete and full. A pass stays valid while the code does not change.
- The verification map, the design-system check (`design-check`, the UI reviewer) and the check that evidence is newer than the code.

### Changed
- Setup runs in one pass. The Stop hook also checks work that was committed during the session.

## 0.2.0

### Added
- The project config (`config`), workspace mode, and commit hooks for the `Worksheet:` trailer and the 400-line limit.

## 0.1.0

- The first release: the Stop hook that runs the checks, read-only reviews on other models, worksheets, the night shift, and the skills that connect them.
