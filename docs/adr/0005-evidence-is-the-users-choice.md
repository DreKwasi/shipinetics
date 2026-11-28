# The user decides about evidence for each task

Evidence is optional. When a change works, the agent asks the user one time, "Record evidence for this change?", and gives its advice. The agent records evidence only when the user says yes. In an autonomous session, the agent records no evidence.

No hook or CI job checks for evidence. The PR gate checks only that the complete verify passed on the exact code. A PR without evidence says how the change was verified.

We chose this because many changes and teams don't need a recording. When each PR needed a recording, each PR took more time.

Checked: 2026-11-27. Released in 0.10.0 (`CHANGELOG.md`).

## Considered options

- **A project setting, `evidence = off`.** It was built on a branch and never released. It made the choice one time for each project. But the user wants to decide for each task. Also, the setting added a config key that each skill had to check.
- **Evidence required on each PR, with a label or a path list to skip it** (0.9.6). For each skip, a person had to add the label or keep the list. Also, CI and the hook gave different results for some branches.
