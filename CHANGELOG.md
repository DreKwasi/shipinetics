# Changelog

Shipinetics uses [Semantic Versioning](https://semver.org).

- Before 1.0.0, a **breaking** change increases the minor number (0.6.0 to 0.7.0). A breaking change removes or changes something that a project uses: a command, a setting, a file name or a hook rule. Its entry gives the steps for each project.
- Other changes increase the last number (0.7.0 to 0.7.1).
- Each release has a git tag, `vX.Y.Z`, on the commit that sets its version.

## 0.9.3

### Added
- **`/shipinetics:test-backfill`** adds tests to an existing app in batches of 3 to 5 features, riskiest first. For each batch it drafts acceptance criteria from what users see, asks for one approval round, and runs one test-writer for each feature, in parallel when the tests can run at the same time. `docs/testing/backfill.md` records the progress, so each run continues where the last one stopped. Users said that writing tests during setup was slow and had no clear order: this gives it an order.
- **test-writer `backfill` mode** for behaviour that the app has today. It reuses the tests that exist, writes acceptance tests first, and proves each test with mutants (there is no code before a change to fail on). A test that fails on an approved criterion stays out of the tree and comes back as a suspected bug.
- **Property tests and differential tests.** test-writer writes a property test when a criterion states a rule for every input (a round trip, an invariant, idempotency), and a differential test for a rewrite that must not change behaviour. From the Claude Code team's article on verification.
- **deepsec** (Vercel) is an optional companion. shipinetics:security-scans has a `repo` scope for it: an agent review of the whole repository, or of one diff with `process --diff`. Each AI run needs the user's yes and has a cost cap, and it can use the Claude Code login (`--agent claude --model-auth local`). Setup's Phase 7 offers it, and the `.gitignore` additions keep its exported findings out of git.
- **`shipinetics-update`** says how this machine gets Shipinetics (GitHub, your fork on GitHub, or a clone that Claude Code reads from the folder) and what to do to update. For a fork or clone, `check` shows the latest release, how far behind the clone is, the files where a merge would conflict, and the release notes. `merge` merges a release into a clean tree and runs the tests. `steps <version>` lists the steps for each project since that version. The install gate asks the user before `shipinetics-update merge`, because it brings new plugin code.
- **Choices of how to run Shipinetics.**
  - Setup offers four ways: all phases in one run (recommended), one phase at a time, Phase 1 only, or audit only. A resumed run keeps the choice.
  - `/shipinetics:setup update` offers all steps (recommended), the breaking steps only, the steps that you pick, or a preview with no change.
  - GETTING-STARTED.md compares the four ways to install the plugin: from GitHub, from your fork on GitHub, from a clone on this machine, or for one session with `--plugin-dir`, each with how it updates.
  - At the start of a task, the agent tells you the size that it gave the task and what that size skips, and you can choose another size.
- **`/shipinetics:setup update`** brings a set-up project to the plugin's version. It lists the steps for each project from each release since the project's version, breaking ones first, replaces the Shipinetics block in `AGENTS.md`, does the steps that you choose, and runs the audit and the checks again. Setup now writes "Shipinetics version:" in `docs/shipinetics-setup.md`.
- GETTING-STARTED.md has "Prompts for larger clean-ups": a test-suite clean-up and a CI time and cost audit, adapted from OpenClaw's CI cost work.

### Changed
- Shipinetics's rules in the `AGENTS.md` template are now one block, between `<!-- shipinetics:begin version=... -->` and `<!-- shipinetics:end -->`. The project's own sections (run the app, where to find things, secrets, security targets, fresh clone) stay above it. A rule that the user approved under "Where this project differs from Shipinetics" wins over the block rule that it names. No other text wins, and five rules always hold: secrets stay unseen, protected files change only through `.shipinetics/pending/`, no test, snapshot or baseline is regenerated to get a pass, each install is scanned first, and each Strix or deepsec run needs the user's yes.

  Steps for each project (optional): run `/shipinetics:setup update`. In a project set up before this version, it shows which sections of `AGENTS.md` came from the template, and puts them in the block after your yes.
- Setup fits around an existing `CLAUDE.md` or `AGENTS.md`. It no longer moves the text of `CLAUDE.md` into `AGENTS.md`. It adds the block to `AGENTS.md` and one `@AGENTS.md` line to `CLAUDE.md` (`@../AGENTS.md` in `.claude/CLAUDE.md`). When one file is a symlink to the other, it adds no import. It lists each project rule that disagrees with the block, with both texts, and says which ones a hook enforces. It counts the lines that load into every session, before and after.
- GETTING-STARTED.md, section 6, has the update steps for each kind of install, what to put in the project instead of a fork, and how to keep the merges of a fork small. It says that Claude Code takes a new copy of a plugin from GitHub only when its version changes.
- Setup's Phase 1 has a "Testing guide" step. It writes `docs/testing/how-to-write-tests.md` and the test index, which the audit checked for but no phase wrote. It measures the time of one targeted test run, finds the related-tests command for `bin/verify --quick`, and finds out if test copies can run in parallel. It reads config and test names only, not test bodies. The setup summary ends with `/shipinetics:test-backfill` as the next step for tests.
- `bin/verify --quick` runs the tests related to the change with the runner's own selection. When the selection is not sure (test config, fixtures, a lockfile, a shared helper), it runs all unit tests. The template and the testing guide say so.
- The README and GETTING-STARTED.md are rewritten from the code. The README starts with a task from start to end, and then separates the rules that code enforces from the rules that are only instructions. It lists each skill, agent, tool, setting and variable. Corrections to the old text:
  - Nothing runs the sweep on a timer. You run it, and the full security audit runs inside it when it is due.
  - `SHIPINETICS_ALLOW_ENV_READ=1` turns off the whole secrets guard, not only its environment checks.
  - `/shipinetics:setup audit` shows the missing and partial parts. It doesn't compare files with the templates.
  - The pre-push hook checks the working tree. CI blocks a merge only if branch protection requires its jobs.
  - The settings template's deny rules (force push, `git reset --hard`, `gh pr merge`, `npm publish`) are now documented.
- SkillSpector's full scan can use your Claude Code login: `SKILLSPECTOR_PROVIDER=claude_cli scan-skills --llm`. The README, the security-scans skill and `scan-skills --help` say so.
- `/shipinetics:setup` no longer offers a phase 8, which never existed.
- `/shipinetics:review` lists `merge-risk` in its argument hint.
- The security-scans skill names all three companions that score DO_NOT_INSTALL in static mode and were checked by hand: `security-audit`, Impeccable and tasteskill.
- ASD-STE100 covers labels too: the text on a Whiteboard or diagram node, an edge, a sequence step, a table cell, a title and a caption. shipinetics:explain has a new "Labels" section:
  - A node is a short sentence, or a name with its article. An edge says what happens, with a verb. A decision node is a question.
  - No made-up tags (`[I]`, `INV-2`), no metaphors, no second idea in brackets and no symbols in place of words.
  - Labels fit the space that Whiteboard shows: 28 characters for a flow edge, about 70 for a flow node. The rest goes in the text below the diagram, because Whiteboard hides the description of a node that has code attached.
  - A table shows the rules on examples. Before a board is done, the agent reads each label alone and rewrites the ones that make no sense without the diagram.
- Whiteboard's own guidance names ASD-STE100 only for prose, at about 80%. Shipinetics now applies the same rules as prose to every word of a board.
- Whiteboard shows `+N` and `−M` under each flow node that has code attached: the added and removed lines of that code that the reader has not viewed yet. Agents can't change these numbers. So each flow diagram with code attached now says what they mean in its description.
- The same rules are in the shared header of each skill that has it, in pr-review, review, system-docs (state diagrams and their example table), in the comment of each docs template, and in the `AGENTS.md` template.
- Shipinetics has a plain-language guide, `skills/explain/plain-language.md`. It applies to all text for people, and it is written for PR descriptions first. ASD-STE100 is its baseline, not a compliance target. The guide asks for these points:
  - the active voice, with the actor named;
  - one topic in each sentence, and one term for each concept;
  - the specific verb;
  - a vertical list for more than one condition or step.

  The guide also lists the words that add nothing, such as "simply", "just" and "robust". Identifiers, commands, established jargon and product names are exempt. The "Prose" rules of shipinetics:explain now match the guide. They keep some rules of Shipinetics's own, for example the 20-word limit for instructions, the terms in `GLOSSARY.md`, evidence for each claim and no hedging.
  - The shared header of each skill names the guide and its path, for PR descriptions, commit messages and review comments.
  - The agent writes the PR title and summary by the guide. It reads the summary against the guide before `gh pr create`. The PR gate's messages name the guide.
  - Commit messages follow the same rules. The first line says what changed, and the body says why.
  - pr-review writes its comments and its review body by the guide.
  - At the wrap-up review, the reviewer reads the branch's commit messages against the guide. Each problem is a minor finding. The author applies it to the commits still to come and to the PR summary, and doesn't rewrite commits.

  Steps for each project (optional): copy the new sentences of "Explaining your work" from `templates/AGENTS.md` into the project's `AGENTS.md`.

### Fixed
- The PR gate and the install gate no longer react to their command words in three common kinds of command. Before, they reacted to the words anywhere, so a commit message, a note or a search that named `gh pr create` or `npx skills add` triggered them. Now they skip the words in:
  - a note: `cat > <file> <<'EOF'` to a `.md`, `.txt`, `.rst` or `.adoc` file, with a quoted delimiter;
  - commits: plain `cd` and `git` steps joined by `;`, `&&` or new lines, with commit messages that can't expand. This includes the `-m "$(cat <<'EOF' ... EOF)"` form. The git steps are `add`, `commit`, `push`, `status`, `diff`, `log`, `show`, `fetch` and `pull`, each with a short list of allowed options. Options that write files or run programs, such as `--output`, `--ext-diff` or `--receive-pack`, don't count. A note may come first;
  - a search: one `grep`, `rg` or `git grep`, piped only into `head`, `tail`, `wc`, `sort`, `uniq`, `cut` or `tr`, with options that only print.

  Any other command is judged whole, as before. A command with a pipe into a program, a redirect, a substitution, a function, `git -c`, a comment, a quote left open or a carriage return doesn't count as one of these shapes. Two review rounds found 27 ways around earlier versions. The tests now hold each of them.
- The PR gate also caught too little. It needed a space or the end of the command after `gh pr create` or `gh pr ready`, so `sh -c 'gh pr ready'` and `"$(gh pr create)"` got past it. Now any character that can't continue the word ends the match.
- `worksheet` no longer makes a plain git repo look set up. Before, every call, `worksheet --help` included, created `.shipinetics/.cache/` and `docs/worksheets/` before it read its arguments. Then the edit guard and the PR gate acted in a repo that nobody had set up.
  - Help now runs first and creates nothing, also outside a git repo. It no longer prints a line of code.
  - Only `worksheet new` and `worksheet use` create folders.
  - In a plain repo, the current worksheet is kept in the git directory (`git rev-parse --git-path shipinetics`), so each worktree has its own. In a set-up project, it stays in `.shipinetics/.cache/`. `evidence` reads it from the same place.

  Steps for each project: none. A repo that isn't set up can have a `.shipinetics/` folder that holds only `.cache/`, from an earlier `worksheet` call. Remove that folder, then run `worksheet use <name>` to make your worksheet current again.

## 0.9.2

### Added
- A new skill, `/shipinetics:pr-review`, reviews someone else's pull request, or paired PRs in two repos. It explains the change on Whiteboard boards (or an HTML explainer), checks each decision in the code at the PR head, and runs the independent reviewers in the background. Findings are ranked, each with `file:line`, a failure case and a fix. It reads the PR with `gh`, never from the local checkout, and it posts comments to GitHub only after a yes.
  - If the PR changes a state, a transition or a guard, the overview shows the state machine after the PR (states, invariants, transition table, diagram), and the `state-integrity` reviewer looks for the invalid states that the code can reach, through retries and concurrent calls too. A changed transition with no change to the system doc's States table is a finding.

## 0.9.1

### Changed
- Every test proves an acceptance criterion. Test-writer writes a test, or a case in a test, only for what a criterion states, and names the criterion at the start of the test's name: `refund-rounding AC2` (the spec's slug or, with no spec, the worksheet's name, and the ID). In a file of one spec's tests, the ID alone is enough.
  - Its plan table has a Criterion column and a Cases column. A behaviour that no criterion states gets no test: test-writer lists it under "Proposed criteria", and the human (or, in an autonomous session, the agent for a technical detail) decides whether to add it to the spec.
  - Test-plan-reviewer cuts a row with no criterion, a row whose criterion doesn't state what it checks (a false link), and cases that the criterion doesn't state. The implementation reviewer and the test-integrity persona check the same in the diff.
  - A bug fix gets a criterion for the correct behaviour before test-writer writes the regression test.
  - Criterion IDs are stable. A new criterion takes the next free number. A removed one stays, struck through.
  - The test audit looks for the criterion of each old test with no reference. It never deletes a test for that reason alone.

  Steps for each project (optional): add a Criterion column to `docs/testing/test-index.md`, and give the criteria in open specs and worksheets IDs (`AC1`, `AC2` ...). `/shipinetics:setup audit` shows the template changes. Old tests keep working: test-writer adds a reference only to a test that it changes.

### Added
- State machines are documented, reviewed and audited.
  - A system doc can have a "States" section: where the state lives, the states, the invariants with what enforces each one, a transition table with a guard for each row, and a diagram. The template has it. A system with no states doesn't need it.
  - A new review persona, `state-integrity`, checks a diff that writes a status, a lifecycle field or flags that depend on each other: unguarded writes, transitions that the table doesn't list, retries that repeat a side effect, and two requests at the same time. Each finding is "reachable by trace" (the path as `file:line` and the order of events) or "reproduced". The implementation reviewer has a short form of the check in its Correctness step.
  - A new skill, `/shipinetics:state-audit`, audits one to three systems. It finds the explicit and implicit state machines, writes their tables from every write in the code, looks for the invalid states that the code can reach, confirms each one, and queues the confirmed bugs by impact, one task for each group that one fix closes. Each fix states the invariant as an acceptance criterion, gets a regression test from test-writer and updates the table in the same commit.
  - The sweep compares the States tables with the period's changes and queues an audit where a table is missing. It never runs the audit itself.
- tasteskill as an optional companion (`taste-skill@taste-skill`). The workflow offers it as a route for UI work that builds or redesigns a page or an app screen. Its rules here: `DESIGN.md` wins over its kit, the kit files that the page loads go in as one vendored commit, its screenshots stay out of git, and its checkers don't replace `design-check`, the UI reviewer or the evidence. SkillSpector 2.12.0 gives version 2.5.1 DO_NOT_INSTALL in static mode. All 23 HIGH findings were checked by hand as false positives (README, "SkillSpector results").
- Ways to catch flaky tests (a test that passes and fails on the same code). None of them turns a failure into a pass.
  - Test-writer runs each new or changed test 5 more times at HEAD. A test that fails once is not done: it finds the cause and fixes it, without retries, longer timeouts or sleeps.
  - `known-failing check --rerun '<cmd>'` runs the new failures once more. The ones that pass then are named flaky and logged in `.shipinetics/.cache/flaky.tsv`. The check still fails. `known-failing flaky` lists them, most often first.
  - `known-failing hunt -n N -- <cmd>` runs the suite N times on the same code and names each test that both passed and failed, with its failure rate. The weekly sweep runs it and queues a task for each one.

  Steps for each project (optional): in `bin/verify`, gate the test suite with `known-failing check --rerun '<the suite's command, writing its JUnit report to {junit}>' <report>`, as the `bin/verify` template shows. Copy the new `known-failing` from the plugin's `bin/` into the project's `bin/` for CI.

## 0.9.0

### Changed (breaking)
- Evidence for a UI change is one paced recording of the flow, not a screenshot per criterion plus a recording. Each criterion's row in EVIDENCE.md names the recording and the time where its result shows: `walkthrough.webm @ 0:07`. Screenshots are only for a change that can't be recorded, with a `> No recording: <reason>` line, and never beside a recording.
  - Recordings and screenshots never go in git. `evidence init` writes a `.gitignore` in the evidence folder, and `evidence check` fails when one is tracked.
  - New opt-in setting `evidence_upload_cmd`: a command that uploads a file to the team's store (SharePoint or OneDrive, S3, Google Drive...) and prints its link. `evidence upload` runs it and puts the links in EVIDENCE.md. Without it, the human drags the recording into the PR.
  - New `evidence frames`: it extracts the frame at each criterion's time (needs `ffmpeg`). Agents and reviewers can't watch a video, so they check these frames.
  - The record template paces the recording for a person: pauses, typing at reading speed, and a hold on each result.
  - The CI evidence job accepts a `Video:` or `Screenshot:` link, a GitHub attachment or `terminal.log`. A file name alone no longer passes.

  Steps for each project: copy the new `evidence` job from `templates/github/workflows/verify.yml` into `.github/workflows/verify.yml`. Install `ffmpeg`. If the team has a store, set `evidence_upload_cmd` in `.shipinetics/config` (the config template has an rclone example). Evidence folders of open branches that commit media: run `git rm --cached` on the media and add the folder's `.gitignore` (`evidence init <worksheet>` writes it). If the project tracked `docs/evidence/**` with git LFS, remove that line from `.gitattributes`.

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
