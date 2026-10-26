# Changelog

Shipinetics follows [Semantic Versioning](https://semver.org). Before 1.0.0, a release that breaks
something a project relies on (a removed command, setting, file name or hook behaviour) bumps the
minor version (0.6.0 to 0.7.0). Anything else bumps the patch version (0.7.0 to 0.7.1). Each
release has a git tag, `vX.Y.Z`, on the commit that set its version.

## 0.7.0

### Removed (breaking)
- Support for the plugin's former name. Projects must use `.shipinetics/`, `SHIPINETICS_*`
  variables, and the `shipinetics-config` and `shipinetics-verify` commands. Removed: the
  fallback to the old project folder and variable names, the old command names,
  `shipinetics-config migrate` and the migration guide.

### Added
- Modular hooks. Switch any hook off with `hooks_off` (`stop`, `edits`, `secrets`, `pr`,
  `installs`) in the project's config or in `~/.config/shipinetics/config`, or for a session with
  `SHIPINETICS_HOOKS_OFF`.
- You choose the secret files. A `secret-paths` list (one glob per line) in `.shipinetics/` or in
  `~/.config/shipinetics/` replaces the built-in list of credential files. Setup has a template.
- The edit guard keeps agents out of `~/.config/shipinetics/`.
- Tests for the `SHIPINETICS_SKIP_VERIFY` and `SHIPINETICS_UNLOCK` overrides.

## 0.6.0

### Added
- Pending changes for protected files. Agents write a proposal to `.shipinetics/pending/<path>`, and
  `shipinetics-config pending` and `apply` let a human review and apply it.
- `launch = user`, for projects where the user runs the dev servers.
- `bench-compare`, with per-machine baselines, budgets and a noise check, plus the `bench_cmd` and
  `package_bench_cmd` keys.
- `known-failing`, which gates a suite with existing failures on new failures only.
- `harness_repo`, and a warning when a workspace's own files aren't in git.
- `night-shift` in workspace mode.
- A Stop-hook reminder to write a regression test first on bug fixes.
- `shipinetics-config match <list> <path>`.
- `env_safe_names`, for variables the env guards should ignore.

### Changed
- The secrets guards ignore heredoc bodies written to files, inert search patterns, docs, and reads
  of variables that never hold secrets. Deny messages name the project's `secrets_runner`.
- Setup proposes `.claude/settings.json` through pending instead of editing it, and writes
  `protected-paths` last.

### Fixed
- The secrets guard missed `env`, `export` and `set` when a newline followed them.
- On a `..` path, the edit guard could reach a protected file through the pending folder.

### Deprecated
- The former name's folder, variables and commands, which still worked in this release with a
  notice. Removed in 0.7.0.

## 0.5.0

### Changed (breaking)
- Renamed the plugin to Shipinetics: the plugin and skill namespace (`shipinetics:`), the project
  folder (`.shipinetics/`), the environment variables (`SHIPINETICS_*`) and the commands
  (`shipinetics-config`, `shipinetics-verify`).

## 0.4.0

### Added
- Tests for the hooks and tools, run in CI on Linux and on macOS's bash 3.2.

### Fixed
- Review findings in the verify tiers, the PR gate and the evidence check.

## 0.3.0

### Added
- Verify tiers (quick, complete, full). A pass is reused while the code is unchanged.
- The verification map, the design-system check (`design-check`, ui-reviewer) and the evidence
  freshness check.

### Changed
- Setup runs in one pass. The Stop hook also verifies work committed during the session.

## 0.2.0

### Added
- Project config (`config`), workspace mode, and commit hooks for the `Worksheet:` trailer and the
  400-line limit.

## 0.1.0

- First release: the verify-gated Stop hook, read-only cross-model review, worksheets, night shift,
  and the skills that tie them together.
