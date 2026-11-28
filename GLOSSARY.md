# Shipinetics

Shipinetics gives a coding agent one way to work in every project, and checks the most important rules with code. These are the words it uses, in its skills, docs, tools and replies.

## Where it runs

**Harness**:
The agent program that runs Shipinetics and its skills, such as Claude Code, Antigravity, Codex, OpenCode or Copilot.
_Avoid_: Tool, client, IDE, agent CLI, host

**Surface**:
One way to use a harness that behaves differently from the others, such as the Copilot CLI, agent mode in VS Code, or the Copilot cloud agent.
_Avoid_: Mode, flavor

**Adapter**:
The part of Shipinetics that fits it to one harness: how it installs there, how its subagents are written, and how its hooks are read and answered.
_Avoid_: Integration, port, shim, driver

**Install**:
Shipinetics in one harness on one machine, made from a clone, or for Claude Code from its marketplace.
_Avoid_: Deployment, setup (setup is for a project)

**Generated copy**:
The skills and subagents that Shipinetics writes for one harness from the clone, in that harness's format and with real paths.
_Avoid_: Rendered files, build output, dist

**Plan**:
The subscription or billing a person uses with a harness, such as Claude Pro, Claude Max, a ChatGPT plan, a Copilot plan or an API key. It sets how much usage Shipinetics can spend.
_Avoid_: Tier, subscription level, account type

**Model role**:
A kind of job that needs a level of model, such as deep review, build or quick checks. A person or their plan picks the model for each role.
_Avoid_: Model tier, model class

**Model catalog**:
The list of models that each harness offers, with the model role each one can fill.
_Avoid_: Model list, model registry

## Projects

**Set-up project**:
A project that has run Shipinetics setup and holds its settings folder. The guards act only in a set-up project, except the secrets guard and the install gate, which act everywhere.
_Avoid_: Enrolled project, onboarded repo

**Shipinetics root**:
The folder that holds a project's Shipinetics settings. It is the repo itself, or the top of a workspace.
_Avoid_: Project root, config root

**Workspace**:
A Shipinetics root that holds several package repos and is not one repo itself.
_Avoid_: Monorepo, multi-repo

**Package**:
One repo inside a workspace, with its own verify command.
_Avoid_: Subproject, module, service

**Harness repo**:
The git repo that versions a workspace's own Shipinetics files when the workspace root is not a repo.
_Avoid_: Meta repo, config repo

**Shipinetics block**:
The part of a project's agent instructions that Shipinetics owns and replaces on each update. Text outside it is the project's own.
_Avoid_: Managed section, template section

**Companion**:
A skill, plugin or tool from someone else that Shipinetics uses next to its own skills.
_Avoid_: Dependency, extension, add-on

## Rules and how they hold

**Instruction**:
A rule that a skill tells the agent to follow, with nothing to stop the agent when it doesn't.
_Avoid_: Guideline, soft rule

**Enforcement**:
A rule that code checks every time and blocks, with the reason, when it fails.
_Avoid_: Hard rule, policy

**Guard**:
Enforcement that checks an agent's action just before it runs and can refuse it: the edit guard and the secrets guard.
_Avoid_: Check, filter, hook (a hook is how a harness runs a guard)

**Gate**:
A guard on a step that leaves the agent's session: opening a pull request (the PR gate) or installing a skill, plugin or MCP server (the install gate).
_Avoid_: Blocker, barrier

**Protected file**:
A file that an agent may create but never change by itself, because it defines what "done" means, such as an acceptance test, a baseline or a policy list.
_Avoid_: Locked file, read-only file

**Pending change**:
A change to a protected file, or its deletion, that an agent proposes and only a person applies.
_Avoid_: Proposal, patch, suggestion

**For you list**:
The things in a setup or update that only the person can do: a login, a choice, their terminal, or a change outside the repo.
_Avoid_: TODO list, manual steps, action items

## The task loop

**Task**:
One piece of work that goes through the task loop and ends in one pull request, or one push.
_Avoid_: Ticket, job, story

**Size**:
How big a task is: XS, S, M or L. The size sets which steps of the loop a task may skip. An L task is split before work starts.
_Avoid_: Estimate, complexity, points

**Route**:
The set of companion skills that a task uses, chosen at the start from the kind of task.
_Avoid_: Path, track, recipe

**Worksheet**:
The record of one task: its plan, its acceptance criteria, what was checked, and its result. Each commit names its worksheet.
_Avoid_: Trace, task log, journal

**Spec**:
The acceptance criteria for a task, approved by a person before the code.
_Avoid_: Requirements doc, PRD, design doc

**Acceptance criterion**:
One behaviour that a task must show, stated as given, when and then, with an ID such as AC1. Each test names the criterion that it proves.
_Avoid_: Requirement, test case, user story

**Task queue**:
The list of tasks that wait to be done, with the condition that each one waits for.
_Avoid_: Backlog, TODO list

**Feedback log**:
Where agents record what went wrong or slowed them down, so the rules and tools improve.
_Avoid_: Retro, lessons learned

**Docs checkpoint**:
The record that the docs hold what a session settled (its terms, decisions, changed systems and worksheet) at the current code. `/compact` waits for it.
_Avoid_: Save point, snapshot

**Sweep**:
The weekly pass that checks that docs, tests and guardrails are still true, and queues what isn't.
_Avoid_: Audit, maintenance run, health check

## Checks

**Verify**:
Running the project's own checks (types, lint, tests, build) through Shipinetics, so the pass is recorded.
_Avoid_: Validate, CI check, test run

**Verify tier**:
How much of verify runs: quick (only what the changed files touch), complete (every fast check, needed before push and pull request) or full (everything, in CI).
_Avoid_: Level, mode, stage

**Recorded pass**:
A verify tier that passed on exactly the current code. Committing the same code, or editing only worksheets and evidence, keeps it.
_Avoid_: Cached result, green build

**Flaky test**:
A test that failed and then passed with no change to the code. It counts as a failure.
_Avoid_: Intermittent test, random failure

**Evidence**:
Proof from the real running app that a change works: one recording of the flow for a visible change, or the output of the commands for a CLI or API. It is optional: the user decides for each task ([ADR 0005](docs/adr/0005-evidence-is-the-users-choice.md)).
_Avoid_: Proof, artifacts, screenshots, demo

**Verification map**:
A project's recipe for starting the real app, checking that it is usable, and using each feature through every way that a user can reach it.
_Avoid_: Runbook, test plan, QA guide

**Merge-risk grade**:
An independent grade of how risky a pull request is to merge: low, medium or high.
_Avoid_: Risk score, confidence

## Agents

**Main agent**:
The agent that the person talks to. It writes the code and runs the task loop.
_Avoid_: Primary agent, orchestrator, implementer

**Subagent**:
A separate agent that the main agent starts, with a fresh context and its own tools and model.
_Avoid_: Child agent, helper, worker

**Test-writer**:
The only subagent that may write or change tests. It writes them from the acceptance criteria, not from the code.
_Avoid_: Test agent, QA agent

**Reviewer**:
A subagent that reads a change, a plan or a doc and reports findings, but never edits it.
_Avoid_: Critic, checker, auditor

**Live tester**:
A subagent that uses the change in the real running app at wrap-up and reports, for each feature, that it passed, has issues or was blocked.
_Avoid_: E2E agent, QA tester
