# Contributing to Shipinetics

Thank you for your help. This guide tells you how to set up, how to change each part of Shipinetics, how to test the change, and what a pull request needs before a maintainer merges it.

If you are not sure that a change is wanted, open an issue first (a bug report or a feature request). A short discussion before the work can save you a rejected pull request.

## What you need

- **bash** and **git.** The scripts must run in macOS `/bin/bash` (bash 3.2) and in Linux bash 4 or 5.
- **python3** (3.7 or later, standard library only). The hooks use it, or `jq`, to read their JSON input.
- **Claude Code** or **Antigravity**, to try a change in a real session. The tests don't need either.
- Optional: `ffmpeg` (evidence frames), `uv` (some companions), `shellcheck` (lint for scripts).

Shipinetics runs on macOS and Linux. On Windows, use WSL.

## Local setup

Fork the repository, clone your fork, and try your changes in a harness:

- **Claude Code:** `claude --plugin-dir <path to your clone>`. Or add the clone as a local marketplace (`claude plugin marketplace add <path to your clone>`), then run `/reload-plugins` after each edit.
- **Antigravity (experimental):** `./bin/shipinetics-antigravity install` links your clone into `~/.gemini/config/plugins/shipinetics`. Run `install` again after you change `agents/*.md`.

## How Shipinetics is built

Read [README.md](README.md) first, specially "Instructions and enforcement", "A task, step by step" and "Known limits". In short:

| Part | Where | What it is |
|---|---|---|
| Skills | `skills/<name>/SKILL.md` | Instructions that the agent follows: the task loop, specs, tests, reviews, evidence, setup |
| Agents | `agents/*.md` | Subagents with their own context: test-writer, the reviewers, the live tester |
| Hooks | `hooks/hooks.json` (Claude Code), `hooks.json` (Antigravity), `scripts/*.sh` | Code that enforces a few rules: the edit guard, the secrets guard, the PR gate, the install gate, and notices |
| Shared code | `scripts/lib.sh` | Config, paths, the code fingerprint, and the hook input and reply formats of each harness |
| Tools | `bin/*` | Commands for agents and people: `shipinetics-verify`, `shipinetics-config`, `evidence`, `worksheet` and others |
| Setup templates | `skills/setup/templates/` | The files that `/shipinetics:setup` writes into a project |
| Tests | `tests/test-*.sh`, `tests/helpers.sh` | One file for each part. `tests/run.sh` runs them all |

## Running checks

Run the same checks that CI runs (`.github/workflows/test.yml`):

```bash
# 1. Syntax check every shell script
for f in scripts/*.sh bin/* skills/setup/templates/bin/* skills/setup/templates/pre-* skills/setup/templates/commit-msg tests/*.sh; do
  bash -n "$f" || exit 1
done

# 2. Run all test suites
bash tests/run.sh

# 3. On macOS, also test with system bash 3.2
/bin/bash tests/run.sh
```

Run one test file while you work:

```bash
bash tests/run.sh test-config.sh
```

## Rules for each kind of change

- **A script or a tool** (`scripts/`, `bin/`, `skills/setup/templates/`):
  - It must run in bash 3.2 and in Linux bash. Don't use associative arrays (`declare -A`), `${var,,}`, `mapfile`, or empty array expansions under `set -u` without a guard.
  - Python helpers use the standard library only.
  - A hook must never fail in a way that blocks the person's work. When a hook can't decide, it lets the action through, and the tests prove which case is which.
- **A hook:** keep Claude Code (`hooks/hooks.json`) and Antigravity (`hooks.json`) in step. Each hook has a name that `hooks_off` can turn off. Add the name to the README's list.
- **A skill:**
  - `name` matches the folder. The `description` says what the skill does and when to use it ("Use when ..."), in 1,024 characters or fewer. Claude reads every description in every session, so keep detail out of it.
  - Keep `SKILL.md` short: 350 lines at most, and about 200 is better. Move detail into a reference file beside it, one level deep, and link to it from `SKILL.md`.
  - Each `${CLAUDE_PLUGIN_ROOT}/...` or `${CLAUDE_SKILL_DIR}/...` path, and each relative `.md` link, points to a file that exists. `tests/test-skills.sh` checks this, the name and the description.
  - Add a rule only when real use shows that agents need it. Replace the text that failed instead of adding a paragraph next to it.
  - Skill text has no automatic test of the agent's behaviour. In the pull request, say how you tried the change: the session, the prompt, and what the agent did.
- **An agent** (`agents/*.md`): its `name` matches the file. If it has a `model`, say why in the pull request. Agents that run often should use the cheapest model that does the job well.
- **A setup template:** `/shipinetics:setup` copies it into other people's projects. Never put a value there that only fits your own project.
- **A companion** (`companions.tsv`): give its license, and say why Shipinetics needs it. Mark it `required` only if a skill fails without it.
- **Tests:** add or update tests in `tests/` for each change of behaviour and for each bug fix. A test runs in a scratch folder under `$TMPDIR` (use `tests/helpers.sh`), and never touches your home folder or this repo. Write one test for each behaviour, not one for each function.
- **Writing:** docs, skill text, commit messages and pull request descriptions follow the plain-language guide (`skills/explain/plain-language.md`), which is based on ASD-STE100. Do your best. A maintainer can help with the wording, and wording never blocks a first contribution.
- **No personal data:** don't commit names of your employer, its projects or tickets, private paths, hostnames, emails or tokens. Use examples such as `web`, `api` and `PROJ-123`.

## Pull requests

1. **One change for each pull request.** Branch from `main`. Use a short branch name that says what changes, for example `fix/pr-gate-docs-only` or `feat/codex-hooks`.
2. **Commits:** small, and each one builds and passes the tests. The first line of the message says what changed (72 characters or fewer). The body says why.
3. **CHANGELOG:** add your entries under `## Unreleased` in [CHANGELOG.md](CHANGELOG.md), in the section that fits (`### Added`, `### Changed`, `### Fixed`, `### Removed`). For a breaking change, say so in the entry and give the steps for each project. CI fails a pull request that changes code without a CHANGELOG entry. A change with nothing to tell users (a typo, a test only) can skip it: a maintainer adds the `no-changelog` label.
4. **Don't change the version.** Don't edit the version in `.claude-plugin/plugin.json` or `plugin.json`, and don't add a `## X.Y.Z` heading. The maintainer sets the version at release time. CI checks this with `scripts/check-pr-version.sh`.
5. **Run the checks** above, and fill in the pull request template: what changed, why, how you tested it, and what you didn't test.
6. **Review:** a maintainer reviews each pull request. CI must pass on Linux and macOS. Answer each review comment, with a fix or a reason. A pull request with no activity for 30 days can be closed. You can open it again.
7. **Merge:** a maintainer squash-merges the pull request, so `main` gets one commit for it, with the pull request's title.

## Releases

Maintainers release the changes that were merged. One release can hold many pull requests, so the version changes once for the batch:

1. Choose the version by the rules at the top of [CHANGELOG.md](CHANGELOG.md). Before 1.0.0, a breaking change increases the minor number (0.9.0 to 0.10.0). Other changes increase the patch number (0.9.3 to 0.9.4).
2. Preview it: `scripts/release.sh minor --dry-run` (or `patch`, `major`, `X.Y.Z`).
3. Run `scripts/release.sh minor`. It runs the tests, turns `## Unreleased` into `## X.Y.Z`, sets the version in both manifests, commits `Release X.Y.Z` and creates the tag `vX.Y.Z`.
4. Push the commit and the tag: `git push origin main vX.Y.Z`. The tag starts `.github/workflows/release.yml`, which checks the manifests and publishes the GitHub Release from the CHANGELOG. A branch named `release/*` can change the version through a pull request instead.

## Reporting a security problem

Don't open a public issue. Follow [SECURITY.md](SECURITY.md).

## Code of conduct

Everyone who takes part follows the [code of conduct](CODE_OF_CONDUCT.md).

## License

By submitting a pull request or other contribution to this repository, you agree that your contribution is licensed under the [MIT License](LICENSE).
