# Getting started with Shipinetics

This guide gives the steps to start with Shipinetics, in order:

1. Install it on each machine, one time.
2. Set up each project, one time.
3. Then work with it day by day, and keep it in good condition each week.

The [README](README.md) says what each part does, and which rules code enforces.

## 1. Install on each machine (one time)

1. Add the marketplace and install the plugin:

   ```bash
   claude plugin marketplace add DreKwasi/shipinetics
   claude plugin install shipinetics@shipinetics
   ```

2. Install SkillSpector, so that you can scan each companion before you install it:

   ```bash
   uv tool install git+https://github.com/NVIDIA/skillspector.git
   ```

   To scan a source quickly, with no key and nothing sent anywhere: `skillspector scan <git URL> --no-llm`. This static mode gives false positives. For the full scan, which also checks those findings with a model, use your Claude Code login: `SKILLSPECTOR_PROVIDER=claude_cli skillspector scan <git URL>`. The full scan uses your plan's tokens. The install gate also asks you before any agent installs or updates a skill, plugin or MCP server.

3. Install the companions. Shipinetics uses them together with its own skills. The README's "Companions" section gives the reason for each one and its SkillSpector result. Install skills with `-g`, so that `skills-outdated` can find their updates later.

   ```bash
   npx skills add mattpocock/skills --skill grilling --skill domain-modeling --skill wait-what --skill research --skill prototype --skill codebase-design --skill diagnosing-bugs -g -a claude-code
   npx skills add cloudflare/security-audit-skill -g -a claude-code
   npx skills add warpdotdev/common-skills --skill merge-risk -g -a claude-code
   claude plugin marketplace add pbakaus/impeccable
   claude plugin install impeccable@impeccable
   claude plugin marketplace add devdotfast/whiteboard
   claude plugin install whiteboard@devfast
   ```

   Also install the dev.fast Whiteboard app. The Whiteboard plugin starts it.

4. Check the result. `shipinetics-companions` shows each companion as installed, missing or declined. While a required companion is missing, each new session starts with a notice that lists the missing ones. If you don't want a companion, add its name to `companions_skip` in `~/.config/shipinetics/config`.

5. Install the optional tools that you want:
   - **Secrets in Google Secret Manager:** run `gcloud auth login` and `gcloud auth application-default login`. Then `bin/with-secrets` can read Secret Manager.
   - **Security tests of your app:** Strix: `curl -sSL https://strix.ai/install | bash`. It needs Docker, running. Keep its LLM provider key in your vault.
   - **Agent review of all your code:** deepsec (Vercel). There is nothing to install: it needs Node.js, and it runs with `npx` in each project. Each run costs money (with Claude Opus, about 25 to 60 US dollars for each 100 files), so the agent asks you first and always sets a cap.
   - **Page design:** tasteskill: `claude plugin marketplace add Leonxlnx/taste-skill`, then `claude plugin install taste-skill@taste-skill`. The agent offers it as a route when a task builds or redesigns a page. It needs Node 22 or newer, and Chrome, Edge or Chromium.

## 2. Set up a project (one time)

Start with one test project. Choose a project that has tests and some small tasks to do.

1. Open the project in Claude Code, on a clean branch.
2. Run `/shipinetics:setup`. It audits the project and writes the result to `docs/shipinetics-setup.md`.
3. Answer its questions. They come in one message. For example, setup asks:
   - about the facts that it couldn't confirm;
   - for the secret names, and which files hold secrets;
   - where recordings go: your team's store, or attached to the PR by hand;
   - whether to create the `no-evidence` label;
   - how often to run the full security audit;
   - which optional phases you want.
4. Setup installs each phase in the same run. It proves that each phase works, and commits it before it starts the next one:

   | Phase | What it adds | How setup proves it |
   |---|---|---|
   | 1 | `bin/verify`, `AGENTS.md`, `CLAUDE.md`, the `.shipinetics/` lists, `bin/with-secrets`, the `.gitignore` lines, the testing guide and test index, a smoke test, the verification map, and a `.claude/settings.json` proposal for you | It runs the checks through `shipinetics-verify`, times one targeted test run, runs the smoke test, and uses one feature through the map |
   | 2 | System docs with 7-line headers, the conventions, and for UI projects `DESIGN.md` from the tokens that the code uses | `head -n 7 docs/systems/*.md` reads like a map of the code, and `design-check --all` runs |
   | 3 | The worksheet template, the feedback log and `TODOS.md` | `worksheet new`, then `worksheet list` |
   | 4 | The git hooks, `bin/lint-fix` and `bin/llm-fix` | It makes four test commits and runs the pre-push hook |
   | 5 | CI, the evidence store setting, and the `no-evidence` label if you said yes | It validates the workflow file |
   | 6 (optional) | One visual test and one benchmark | Both run in `bin/verify --full` |
   | 7 (optional) | The security tools, and `security_audit_every` | `scan-skills` runs, and you see its summary. Each DO_NOT_INSTALL result is a companion that was checked by hand (the README lists them), or a tool to remove |

5. Read the report. It ends with a "For you" list: the things that only you can do, for example an install, a login or a new GitHub label. The items about secrets and evidence come first. Until you do them, those guardrails work only in part.

   Some changes need a person. Setup puts them in `.shipinetics/pending/`, for example `.claude/settings.json`. Apply them with `shipinetics-config apply` in your terminal.

   If setup stopped early, run `/shipinetics:setup` again. It starts at the first phase that isn't done. To do one phase again later, run `/shipinetics:setup <phase>`, for example `/shipinetics:setup 4`.

6. **Add tests to the existing app.** Setup writes one smoke test only. Run `/shipinetics:test-backfill`. It ranks the app's features by risk, and then works in batches of 3:
   1. It writes acceptance criteria for each feature, from what users see.
   2. You approve, change or remove them, for the whole batch in one message. It also shows what looks like a bug, and you decide.
   3. One test-writer for each feature writes the tests, in parallel when the tests can run at the same time.
   4. It commits each feature's tests and proposes the next batch.

   Run it again for each batch. `docs/testing/backfill.md` records where it stopped. Stop when the features that are left are low risk: their tests come when a task changes them.

   The speed depends on one number: the time of one targeted test run. Setup measured it. If it is over 10 seconds, fix that first (the setup report gives the likely cause), because each test that the agent writes runs many times.

7. **Check the guardrails yourself:**
   - Run `shipinetics-verify quick`, then `shipinetics-verify`. The quick tier must take seconds, and the complete tier a few minutes at most. Then `shipinetics-verify status` shows that both passed.
   - Ask the agent to make a small change that breaks a test, and then to open a PR. The PR gate must refuse. It checks the evidence first, so the first refusal is often about missing evidence. It must also refuse until `shipinetics-verify` passes.
   - Ask the agent to write a test itself. The edit guard must refuse, and tell it to use `shipinetics:test-writer`.
   - Ask the agent to run `env`. The secrets guard must refuse.

## 3. Day by day: a normal task

Tell the agent what you want, as you do now. The README's "A task, step by step" lists what the agent does. Your part:

1. Choose a route. For tasks of size S and larger, the agent offers two or three, and recommends one.
2. Answer the design questions. Each question has a recommended answer. When the code can answer a question, the agent reads the code and doesn't ask you.
3. Approve the acceptance criteria. Tests are only written for what a criterion states. So when test-writer proposes a new criterion, decide whether the spec needs it.
4. Decide the design-system change requests in the worksheet, if there are any.
5. Review the PR as its merge-risk grade tells you:
   - **low:** look at the evidence, read the change quickly, and merge;
   - **medium:** read the Whiteboard and the files that the grade names;
   - **high:** do a full review.
6. If the project doesn't set `evidence_upload_cmd`, drag the recording into the PR.
7. Fill in the three fields for you in the worksheet's Metrics: the corrections, your review time, and whether you accepted the work.

If a message from the agent isn't clear, type `/wait-what`. The agent explains it again, more simply.

For M tasks and larger, paste the `/goal` line from the spec into Claude Code. Claude keeps working until a separate evaluator sees each result: the tests pass, the checks pass, the review is done and the work is committed.

**Commands that you can run:**

| Command | When |
|---|---|
| `/shipinetics:spec <issue or idea>` | To get testable acceptance criteria before the code |
| `/shipinetics:review impl` | To get a review now |
| `/shipinetics:pr-review <PR links>` | To understand and review someone else's PR. It posts to GitHub only after your yes |
| `/shipinetics:explain <topic> html` | To get an interactive page that explains something |
| `/shipinetics:explain <topic> video` | To get a video with narration. It asks you first |
| `/shipinetics:evidence` | To record or check the evidence for the current task |
| `/shipinetics:security-scans repo` | To review all your code with deepsec. It asks you to approve the cost cap first |
| `/shipinetics:security-scans app` | To test your own app with Strix. It asks you to approve the targets first |
| `/wait-what` | When the last message wasn't clear |

## 4. Each week: keep the setup in good condition

Nothing runs these on its own. Run them yourself, or schedule them.

| Command | What it does |
|---|---|
| `/shipinetics:sweep` | Looks at the commits since the last sweep (or the last 7 days) for duplicate code, drift and unfinished work. It also checks the verification map, the design system, the secrets and evidence guardrails, the time that checks take, flaky tests, and companions that have updates. When the full security audit is due, it runs the audit |
| `/shipinetics:feedback ingest` | Groups the agents' feedback, and proposes fixes to docs, tools and lint rules. You approve each fix |
| `/shipinetics:test-audit` | Finds tests that don't test what they say. It removes tests that add nothing, and turns tests of functions into tests of behaviours |
| `/shipinetics:state-audit` | Writes down the states, invariants and transitions of one to three systems in their docs. It finds the invalid states that the code can reach, also through retries and two requests at the same time, and adds a task for each group of confirmed bugs. It fixes nothing unless you ask |
| `scan-skills` | Scans the skills and agent files that can reach your sessions with SkillSpector. Act on each result marked DO_NOT_INSTALL. The README lists the known false positives |
| `shipinetics-usage html` | A page with charts of the tokens that each session and each agent used. It reads Claude Code's transcripts, so it costs nothing |

When the sweep finds the same problem areas each week, it suggests Matt Pocock's `improve-codebase-architecture` skill. It isn't a companion, so install it only if you want it.

**The full security audit.** Setup asks how often to run it, and writes `security_audit_every` in `.shipinetics/config`: `off`, `weekly`, `monthly`, `quarterly` or a number of days such as `14d`. `shipinetics-config due security-audit` says if an audit is due, and the sweep runs it then. You can also ask for one at any time, for example before a release.

## 5. Use it in more projects

When the test project has run for two weeks without problems, run `/shipinetics:setup` in the next project. Each project keeps its own `AGENTS.md`, docs and lists. All projects share the plugin, so an improvement from one project's feedback reaches every project at the next plugin update.

## 6. Update to a new version

If you added the marketplace from a local clone (`claude plugin marketplace add <path to the clone>`), Claude Code reads the plugin from that folder. Edits take effect at the next session, or when you run `/reload-plugins`, and you can skip the steps below.

For an install from GitHub:

1. Update the plugin, then restart Claude Code:

   ```bash
   claude plugin marketplace update shipinetics
   claude plugin update shipinetics@shipinetics
   ```

2. Read the new entry in `CHANGELOG.md`. If it has a **breaking** change, do its steps in each project.
3. Optional: run `/shipinetics:setup audit` in a project. It shows which parts are missing or only partly in place. A plugin update doesn't change the files that setup wrote into the project. `/shipinetics:setup <phase>` does a phase again, and merges into your files.

## Prompts for larger clean-ups

These prompts come from other teams' work, adapted to Shipinetics. Paste one into Claude Code in a set-up project. Each one shows you its plan before it changes anything.

**Clean up the test suite** (from the test clean-up in [OpenClaw's CI cost work](https://vincent.build/openclaw-ci-cost-reduction/)). Use it when the suite is slow or large and many tests catch nothing:

```
/goal Clean up this repo's test suite, one system at a time, with /shipinetics:test-audit.
For each system in docs/systems/: read its production code and its system doc first, then its tests.
Name the behaviours that the tests must protect. Follow test-audit's rules: delete tests that copy
the implementation, repeat another test, or test code that is gone; fix flaky tests that protect a
real behaviour; never delete the only test of a behaviour. List tests that no criterion traces to,
and ask me before you delete one. A deletion is part of the result: record each one in the audit report,
with its reason. Keep each change to one system and under 400 lines, and run shipinetics-verify
before each commit. Don't release. Stop when every system is audited. Report the tests and the
mutants caught, before and after.
```

**Make CI faster and cheaper** (from the same article). Use it when CI takes long or costs much:

```
Audit this repo's CI for time and cost. First measure a baseline from the last 2 weeks of runs
(gh run list, or the CI provider's API): runner minutes for each workflow, the slowest jobs, cache
hit rates, and the runs that a newer push made useless. Then propose the changes with the most value,
in this order: delete tests that protect nothing; run each check at the stage that needs it (PR, main
branch, schedule); skip a job before its setup starts (job conditions, path filters); cancel runs that
a newer push replaces; select tests from the diff, and run the full suite when the selection is not
sure; cache by lockfile, toolchain and platform, and check that the cache hits; balance the shards.
Keep every required check. Show me the proposal first. Then make each change a small PR, and measure
the time and cost again after it.
```

**Write the tests of many approved features** without a person between batches: see "Prompt for a long backfill" in the test-backfill skill. You approve the criteria first, and the prompt only writes their tests.

## Problems and solutions

| Problem | Cause and solution |
|---|---|
| `shipinetics-verify quick` is slow | Set `verify_quick_cmd = bin/verify --quick` in `.shipinetics/config`, and make `--quick` check only the changed files. `shipinetics-verify times` shows how long each tier takes. Put slow suites behind `--full` |
| `gh pr create` is refused | The PR gate works as designed. The complete checks didn't pass on this exact code (run `shipinetics-verify`), the evidence isn't complete, or the body has no Evidence section. `evidence check --branch` shows what is missing |
| `evidence check` says that the code changed after the evidence | A code fix came after the recording. Record the affected criteria again, and update the Commit line in `EVIDENCE.md`. Changes to docs and tests don't cause this |
| `design-check` says that there is no design system | `DESIGN.md` is missing, or it has no token frontmatter. Run `/shipinetics:setup 2` (or `/impeccable document`) to write it from the code |
| The agent says that it can't write a test | The edit guard works as designed. The agent must use `shipinetics:test-writer`. For a large one-time change, start Claude Code with `SHIPINETICS_ALLOW_AUTHOR_TESTS=1` |
| A session starts with a list of missing companions | Install them (step 3 of section 1), or add the ones that you don't want to `companions_skip` in `~/.config/shipinetics/config` |
| A guard blocks a safe command | Report the command, so that the rule can be fixed. Until then, run the command yourself. To keep agents away from more files, or fewer, write a `secret-paths` list. To turn off one guard for a session, start Claude Code with its variable: `SHIPINETICS_ALLOW_ENV_READ=1` (the whole secrets guard), `SHIPINETICS_ALLOW_INSTALLS=1`, `SHIPINETICS_ALLOW_NO_EVIDENCE=1`, `SHIPINETICS_UNLOCK=1` or `SHIPINETICS_ALLOW_AUTHOR_TESTS=1`. The README lists them |
| `bin/with-secrets` fails | gcloud isn't installed or isn't logged in, a name in `.shipinetics/secrets.list` isn't in Secret Manager, or the project sets `vault = infisical` and the Infisical CLI isn't installed |
| The agents still use the old model or rules after a change to the plugin | A session loads the plugin when it starts. Run `/reload-plugins`, or start a new session. For an install from GitHub, update the plugin first (section 6) |
| The number of tests grows with each task | Tell the agent to use test-writer's `change` mode after it commits a change. Read the net change in test-writer's report. Run `/shipinetics:test-audit` to delete tests whose code is gone |
