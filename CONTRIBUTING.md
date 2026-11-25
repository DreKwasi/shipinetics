# Contributing to Shipinetics

Thank you for contributing to Shipinetics. This guide covers how to run tests, follow the repo's rules, and open a pull request.

## Local setup

Clone the repository and try your changes in either harness:

- **Claude Code:** `claude --plugin-dir <path to this clone>` (or add the clone as a local marketplace and run `/reload-plugins`).
- **Antigravity:** `./bin/shipinetics-antigravity install` links this clone into `~/.gemini/config/plugins/shipinetics` and generates Antigravity-native subagents. Re-run `install` after editing `agents/*.md`.

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

Run a single test file while iterating:

```bash
/bin/bash tests/run.sh test-antigravity.sh
```

## Guidelines

- **Bash 3.2 compatibility:** Every script in `scripts/`, `bin/`, `tests/`, and `skills/setup/templates/` must run under macOS `/bin/bash` (bash 3.2) and Linux bash. Avoid associative arrays (`declare -A`), `${var,,}`, and unguarded empty array expansions under `set -u`.
- **Standard library only for Python:** `scripts/usage.py` and inline Python helpers must use Python 3.7+ standard library modules only (no third-party pip packages).
- **Dual-harness support:** Keep Claude Code (`.claude-plugin/plugin.json`, `hooks/hooks.json`, `agents/*.md`) and Antigravity (`plugin.json`, `hooks.json`, `bin/shipinetics-antigravity`) working together. Keep versions in `.claude-plugin/plugin.json` and `plugin.json` aligned.
- **Plain language:** Write docs, skill text, commit messages, and PR summaries in clear active voice following `skills/explain/plain-language.md`.
- **Writing a skill:** `tests/test-skills.sh` checks the first four rules.
  - `name` matches the folder. The `description` says what the skill does and when to use it ("Use when ..."), in 1,024 characters or fewer. Claude reads every description in every session, so keep detail out of it.
  - Keep `SKILL.md` short: 350 lines at most, and about 200 is better. Move detail into a reference file beside it, one level deep, and link to it from `SKILL.md`.
  - Each `${CLAUDE_PLUGIN_ROOT}/...` or `${CLAUDE_SKILL_DIR}/...` path, and each relative `.md` link, points to a file that exists.
  - Add a rule only when real use shows that agents need it. Replace the text that failed instead of adding a paragraph next to it. Text for agents follows the hard rules in `skills/explain/plain-language.md`: one word for one action.
- **Tests:** Add or update tests in `tests/` for any behavior change or bug fix. Tests must run in a scratch directory under `$TMPDIR` and never touch the user's real home directory or this repo.

## Pull requests

1. Branch from `main`.
2. Keep commits small and focused, with clear commit messages stating what changed and why.
3. Add your CHANGELOG entries under `## Unreleased`. Don't change the version in `.claude-plugin/plugin.json`, `plugin.json` or the CHANGELOG headings: `scripts/release.sh` sets the version when the maintainer releases. CI checks this with `scripts/check-pr-version.sh`.
4. Verify all checks above pass locally.
5. Open a pull request against `main` summarizing the change and how you verified it.

## License

By submitting a pull request or other contribution to this repository, you agree that your contribution is licensed under the [MIT License](LICENSE).
