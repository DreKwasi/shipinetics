## What changes

<!-- One or two sentences: what this pull request changes, and for whom. If there is an issue, link it: "Fixes #123". -->

## Why

<!-- The problem, or what a user can do now that they could not do before. -->

## How I tested it

<!--
- The commands that you ran, and what they showed (bash tests/run.sh, and /bin/bash tests/run.sh on macOS).
- For a skill or an agent: the session, the prompt, and what the agent did.
- What you did not test, and why.
-->

## Checklist

- [ ] This pull request has one change.
- [ ] I added or updated tests for each change of behaviour or bug fix, and `bash tests/run.sh` passes.
- [ ] The scripts work in bash 3.2 (`/bin/bash tests/run.sh` on macOS, or CI).
- [ ] `CHANGELOG.md` has an entry under `## Unreleased`, or the change has nothing to tell users. The entry for a breaking change says that it is breaking, and gives the steps for each project.
- [ ] The version in `plugin.json` and `.claude-plugin/plugin.json` is unchanged.
- [ ] If the change touches hooks or manifests, I updated the Claude Code files and the Antigravity files.
- [ ] The pull request has no personal data: no employer, project or ticket names, private paths, emails or tokens.
