# Changelog

Shipinetics uses [Semantic Versioning](https://semver.org).

- Before 1.0.0, a **breaking** change increases the minor number (0.6.0 to 0.7.0). A breaking change removes or changes something that a project uses: a command, a setting, a file name or a hook rule. Its entry gives the steps for each project.
- Other changes increase the last number (0.7.0 to 0.7.1).
- Each release has a git tag, `vX.Y.Z`, on the commit that sets its version.

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
