# Getting started with Shipinetics

This guide gives the steps to start with Shipinetics. Do some steps one time on each machine, and some one time in each project. Then follow the daily and weekly routine. Read the README first: it tells you what each part does.

## 1. Install on each machine (one time)

1. Add the marketplace and install the plugin:

   ```bash
   claude plugin marketplace add DreKwasi/shipinetics
   claude plugin install shipinetics@shipinetics
   ```

2. Install SkillSpector. Then you can scan each companion before you install it:

   ```bash
   uv tool install git+https://github.com/NVIDIA/skillspector.git
   ```

   To scan a source: `skillspector scan <git URL> --no-llm`. The install gate also asks you before any agent installs or updates a skill, plugin or MCP server.

3. Install the companions. Shipinetics uses them together with its own skills. The README ("Companions") gives the reason for each one and its SkillSpector result. Install skills with `-g`, so that `skills-outdated` can find their updates later.

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

4. Check the result. `shipinetics-companions` shows each companion as installed or missing. Until you install a companion, each new session starts with a notice about it. If you do not want a companion, add its name to `companions_skip` in `~/.config/shipinetics/config`.

5. Install the other tools that you want:
   - **Secrets:** run `gcloud auth login` and `gcloud auth application-default login`. Then `bin/with-secrets` can read Secret Manager.
   - **Security tests of your app (optional):** Strix: `curl -sSL https://strix.ai/install | bash`. It needs Docker (running). Keep its LLM provider key in your vault.

## 2. Set up a project (one time)

Start with one test project. Choose a project that has tests and some small tasks to do.

1. Open the project in Claude Code, on a clean branch.
2. Run `/shipinetics:setup`. It audits the project and writes the result to `docs/shipinetics-setup.md`.
3. Answer its questions. They come in one message. For example, setup asks:
   - about facts that it could not confirm;
   - for secret names, and which files hold secrets;
   - about git LFS and the `no-evidence` label;
   - how often to run a full security audit;
   - which optional phases you want.
4. Setup then installs every phase in the same run. It proves that each phase works, and it commits each phase before it starts the next:

   | Phase | Adds | Setup proves it with |
   |---|---|---|
   | 1 | `bin/verify` with its quick, complete and full tiers, `AGENTS.md`, the `.shipinetics/` lists, `bin/with-secrets`, one smoke test, the verification map in `docs/verification/` | Each verify tier through `shipinetics-verify`, the smoke test, and a full run of the map |
   | 2 | System docs with 7-line headers, conventions, and for UI projects `DESIGN.md` from the tokens the code uses | `head -n 7 docs/systems/*.md` reads like a map of the code, and `design-check --all` runs |
   | 3 | The worksheet template, the feedback log, `TODOS.md` | `worksheet new`, then `worksheet list` |
   | 4 | Commit hooks: lint with automatic fixes, a 400-line limit, the `Worksheet:` trailer, and a pre-push hook that runs the complete checks | A commit with a lint error that can be fixed, a commit without a trailer, a commit that is too big, and a run of the pre-push hook |
   | 5 | CI that runs `bin/verify --full` | A check of the workflow file |
   | 6 | One visual test and one benchmark (optional) | Both run in `bin/verify --full` |
   | 7 | Security tools (optional) | `scan-skills` finds nothing marked DO_NOT_INSTALL |

5. Read the report. It ends with a "For you" list: the things only you can do, for example an install, a login or a new GitHub label. Items about secrets and evidence are at the top. Until you do them, those guardrails are only partly active.
   Some changes need a person. Setup puts them in `.shipinetics/pending/`, for example `.claude/settings.json`. Apply them with `shipinetics-config apply`.
   If setup stopped early, run `/shipinetics:setup` again. It starts at the first phase that is not done.
6. **Check the guardrails yourself:**
   - Run `shipinetics-verify quick`, then `shipinetics-verify`. The quick tier must take seconds. The complete tier must take a few minutes at most. Then `shipinetics-verify status` shows that both passed.
   - Ask the agent to make a small change that breaks a test, and then to open a PR. The PR gate must refuse it until `shipinetics-verify` passes.
   - Ask the agent to write a test itself. The edit guard must refuse and tell it to use `shipinetics:test-writer`.
   - Ask the agent to run `env`. The secrets guard must refuse.

To do one phase again later, run `/shipinetics:setup <phase>`, for example `/shipinetics:setup 4`.

## 3. Daily: a normal task

Tell the agent what you want, as you do now. The agent follows `shipinetics:workflow`:

1. It starts a worksheet.
2. For small tasks and larger, it gives you two or three routes for the task, and recommends one. Each route names the companion skills that it uses, for example `grilling` for decisions or `research` for external facts. You choose the route.
3. For medium tasks and larger, it asks you questions about the design first. Each question has its recommended answer. When the code can answer a question, it reads the code and does not ask you. Then it writes a spec with acceptance criteria. New domain terms go in `GLOSSARY.md`. You approve the criteria.
4. `shipinetics:test-writer` writes the acceptance tests, then unit tests, in its own context. It writes one test for each behaviour, never one test for each function. When the task changes or removes behaviour, it first changes or deletes the old tests. It reports the net change in tests, and it runs the full suite.
5. The agent writes the code. After each step, it runs the quick checks on what changed (`shipinetics-verify quick`). The agent uses the feature in the real app, from the verification map, through each entry point. Before it says the work is done, it runs the complete checks (`shipinetics-verify`). A push or a PR needs the complete checks to pass on the final code. No hook runs checks when the agent stops.
6. It gets reviews: `shipinetics:reviewer` (Opus, in its own context), and the security or UI reviewer when the change needs them. UI changes are compared with `DESIGN.md`. If the design needs a new token, the agent asks you in the worksheet. It does not add the token. For medium tasks and larger, the final reviewer uses the change in the app itself.
7. It records evidence from the running app, on the final code:
   - a screenshot of the result for each acceptance criterion;
   - a recording for UI changes;
   - terminal output for CLIs and APIs.

   If the code changes after that, the old evidence fails the check.
8. For medium tasks and larger, it makes a Whiteboard of the change for you.
9. It commits each step that works. Each commit has a `Worksheet:` trailer and fewer than 400 changed lines. The git hooks refuse other commits. At the end, it tags the worksheet and writes feedback. It also fills in the worksheet's metrics, with the tokens from `shipinetics-usage session`.
10. For a PR, it writes the body with the Evidence section and an independent merge-risk grade. The PR cannot open without the evidence.

**What you do:**
1. Choose a route, and answer the questions about the design.
2. Approve the acceptance criteria.
3. Decide the design-system change requests.
4. Review the PR as its merge-risk grade tells you:
   - **low:** check the evidence, read the change quickly, merge;
   - **medium:** read the Whiteboard and the files that the grade names;
   - **high:** do a full review.
5. Fill in the three fields for you in the worksheet's Metrics: corrections, review time, and accepted or not.

If a message from the agent is not clear, type `/wait-what`. The agent explains it again, more simply.

For long tasks, paste the `/goal` line from the spec. Claude continues until a separate check sees all the results: the tests pass, the checks pass, the review is done and the work is committed.

**Useful commands:**

| Command | When |
|---|---|
| `/shipinetics:spec <issue or idea>` | To make acceptance criteria and failing tests first |
| `/shipinetics:review impl` | To get a review now |
| `/shipinetics:explain <topic> html` | To get an interactive page that explains something |
| `/shipinetics:explain <topic> video` | To get a video with narration (it asks first) |
| `/shipinetics:evidence` | To record or check the evidence for the current task |
| `/shipinetics:security-scans app` | To test your own app with Strix (it asks you to approve the targets first) |
| `/wait-what` | When the last message was not clear |

## 4. Weekly: keep the setup good

| Command | What it does |
|---|---|
| `/shipinetics:feedback ingest` | Groups the agents' feedback and proposes fixes to docs, tools and lint rules. You approve them |
| `/shipinetics:sweep` | Looks at the week's commits for duplicate code, drift and work that is not complete. It also checks the verification map, the design system, the secrets and evidence guardrails, the time that checks take, and companions that have updates (`skills-outdated`). When a full security audit is due, it runs the audit |
| `/improve-codebase-architecture` | Optional (Matt Pocock's skills). When the sweep finds the same problem areas each week, it proposes better modules. You choose what goes in the queue |
| `/shipinetics:test-audit` | Finds tests that do not test what they say. It removes tests that add nothing, and it changes tests for each function into tests for each behaviour |
| `scan-skills` | Scans all installed skills, agents and plugins with SkillSpector. Act on each result marked DO_NOT_INSTALL |
| `shipinetics-usage html` | A page with charts of the tokens that each session and each agent used. It reads Claude Code's transcripts, so it costs nothing. `shipinetics-usage` gives the same numbers in the terminal |

**Full security audit.** Setup asks how often to run it: `security_audit_every` in `.shipinetics/config` (`off`, `weekly`, `monthly`, `quarterly` or a number of days, such as `14d`). `shipinetics-config due security-audit` tells you if an audit is due. The weekly sweep runs it when it is due. You can also ask for one at any time, for example before a release.

## 5. Use it in more projects

When the test project has run for two weeks without problems, run `/shipinetics:setup` in the next project. Each project keeps its own `AGENTS.md`, docs and lists. All projects share the plugin. So an improvement from one project's feedback goes to all projects at the next plugin update.

## 6. Update to a new version

If you added the marketplace from a local clone (`claude plugin marketplace add <path to the clone>`), Claude Code reads the plugin from that folder. Then edits take effect at the next session, or when you run `/reload-plugins`. You do not need the steps below.

For an install from GitHub:

1. Update the plugin, then restart Claude Code:

   ```bash
   claude plugin marketplace update shipinetics
   claude plugin update shipinetics@shipinetics
   ```

2. Read the new entry in `CHANGELOG.md`. If it has a **breaking** change, do its steps in each project.
3. Optional: run `/shipinetics:setup audit` in a project. It compares the project with the newest templates. A plugin update does not change the files that setup copied into the project.

## 7. Release a change (for the plugin's maintainer)

1. Choose the version with the rules at the top of `CHANGELOG.md`. Before 1.0.0, a breaking change increases the minor number (0.7.0 to 0.8.0). Other changes increase the last number (0.7.0 to 0.7.1).
2. Set the version in `.claude-plugin/plugin.json`.
3. Write the entry in `CHANGELOG.md`. For a breaking change, give the steps for each project.
4. Commit, and tag the commit `vX.Y.Z`.
5. Push the commit and the tag.

If the version does not change, `claude plugin update` does nothing for installs from GitHub. An install from a folder does not use the version: it reads the folder.

## Effort

The main session runs at high effort. The `reviewer` agent runs on Opus at high effort, and the other three agents run on Opus at medium effort. To use a different effort for a session, start Claude Code with `CLAUDE_CODE_EFFORT_LEVEL=medium`. This setting overrides all others, also for agents. The README lists the settings for each part.

## Problems and solutions

| Problem | Cause and solution |
|---|---|
| `shipinetics-verify quick` is slow | Set `verify_quick_cmd = bin/verify --quick` in `.shipinetics/config`, and make `--quick` check only the changed files. `shipinetics-verify times` shows which tier and step is slow. Put slow suites behind `--full` |
| `gh pr create` is refused | This is correct. The complete checks did not pass on this exact code (run `shipinetics-verify`), the branch has no complete evidence, or the body has no Evidence section. `evidence check --branch` shows what is missing |
| `evidence check` says the code changed after the evidence | A code fix came after the screenshots. Record the affected criteria again, and update the Commit line in `EVIDENCE.md`. Changes to docs and tests do not cause this |
| `design-check` says there is no design system | `DESIGN.md` is missing or has no token frontmatter. Run `/shipinetics:setup 2` (or `/impeccable document`) to write it from the code |
| The agent says it cannot write a test | This is correct. It must use `shipinetics:test-writer`. For a large one-time change, start Claude Code with `SHIPINETICS_ALLOW_AUTHOR_TESTS=1` |
| A session starts with a list of missing companions | Install them (step 3 of section 1), or add the ones that you do not want to `companions_skip` in `~/.config/shipinetics/config` |
| A guard blocks a safe command | Report the command, so the rule can be fixed. Until then, run the command yourself, or start the session with `SHIPINETICS_ALLOW_ENV_READ=1`. To keep agents away from more files, or fewer, write a `secret-paths` list |
| `bin/with-secrets` fails | gcloud is not logged in, or a name in `.shipinetics/secrets.list` is not in Secret Manager |
| The agents still use the old model or rules after a change to the plugin | A session loads the plugin when it starts. Run `/reload-plugins`, or start a new session. For an install from GitHub, update the plugin first (section 6) |
| The number of tests grows on each task | Tell the agent to use test-writer `change` mode before it changes the code. Read the net change in test-writer's report. Run `/shipinetics:test-audit` to delete orphan tests |
