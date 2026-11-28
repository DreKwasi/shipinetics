# The user decides about evidence for each task

Evidence is optional. When a change works, the agent asks the user once, "Record evidence for this change?", with its advice, and records evidence only on a yes. In an autonomous session it records none. No hook or CI job checks for evidence: the PR gate checks only the complete verify pass on the exact code, and a PR without evidence says how the change was verified. We chose this because many changes and teams don't need a recording, and a required recording cost time on each PR.

Checked: 2026-11-27. Released in 0.10.0 (`CHANGELOG.md`).

## Considered options

- **A project setting, `evidence = off`.** It was built on a branch and never released. It made the choice once for each project, but the user wants to decide for each task, and the setting added a config key that each skill had to check.
- **Evidence required on each PR, with a label or a path list to skip it** (0.9.6). Each skip needed a person to add the label or keep the list, and CI and the hook disagreed about some branches.
