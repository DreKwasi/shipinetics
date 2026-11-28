# Spec: CI checks for the plugin itself

Status: done. Size: S. Tests: `tests/test-check-plugin.sh` (CP1-CP7); CI runs CP8-CP10.

## Goal

Each pull request runs more checks than the tests. They catch what broke 0.12's first pull request
(new scripts without the executable bit), shell mistakes, broken workflows, and an install that
leaves files on a machine. No check calls a model. The tools are pinned by version and sha256.

## Acceptance criteria

`scripts/check-plugin.py [repo]`:

- **CP1.** On the plugin as it is, it prints `check-plugin: ok` and exits 0.
- **CP2.** A hook script that git tracks as 100644 makes it exit 1, and the output names the script
  and the fix command (`git update-index --chmod=+x <path>`).
- **CP3.** A tool in `bin/` that git tracks as 100644 makes it exit 1, and the output names it.
- **CP4.** A hook command in `hooks/hooks.json` or `hooks.json` that names a script that doesn't
  exist makes it exit 1, and the output names the script.
- **CP5.** A `SKILL.md` whose frontmatter name differs from its folder, or that has no description,
  makes it exit 1, and the output names the file.
- **CP6.** `plugin.json` and `.claude-plugin/plugin.json` with different versions make it exit 1.
- **CP7.** Invalid JSON in a manifest makes it exit 1, and the output names the file.

The other checks:

- **CP8.** `scripts/lint-shell.sh` runs shellcheck at severity warning on every shell script that
  the plugin ships. It leaves out only the setup templates in `skills/setup/templates/bin/` that hold
  `{{placeholders}}`.
- **CP9.** `scripts/smoke-install.sh` installs into an empty HOME, never the runner's own, and then:
  status says the copies are current; `uninstall --all --dry-run` changes nothing; `uninstall --all
  --yes` exits 0 and leaves no file of Shipinetics, the caches or the usage log, and doesn't change
  the person's own `~/.config/shipinetics/config`.
- **CP10.** `.github/workflows/checks.yml` runs CP1-CP9 and actionlint on each pull request and
  each push to `main`, with read-only permissions and pinned tools.
