## What changes

<!-- One or two sentences: what this pull request changes, for whom. Link the issue, if there is one: "Fixes #123". -->

## Why

<!-- The problem, or what a user can do now that they couldn't before. -->

## How I tested it

<!--
- Commands you ran and what they showed (bash tests/run.sh, /bin/bash tests/run.sh on macOS).
- For a skill or an agent: the session, the prompt, and what the agent did.
- What you didn't test, and why.
-->

## Checklist

- [ ] One change in this pull request.
- [ ] Tests added or updated for each change of behaviour or bug fix, and `bash tests/run.sh` passes.
- [ ] Scripts work in bash 3.2 (`/bin/bash tests/run.sh` on macOS, or CI).
- [ ] An entry under `## Unreleased` in `CHANGELOG.md`, or the change has nothing to tell users. A breaking change says so and gives the steps for each project.
- [ ] The version in `plugin.json` and `.claude-plugin/plugin.json` is unchanged.
- [ ] Claude Code and Antigravity files are both updated, if the change touches hooks or manifests.
- [ ] No personal data: no employer, project or ticket names, private paths, emails or tokens.
