# Spec: one installer for every harness (step 1 of multi-harness support)

Status: approved on 2026-11-22. Design approved on 2026-11-22 ([research](../research/harnesses.md), [ADR 0001](../adr/0001-generated-copies-per-harness.md)). Terms: [GLOSSARY.md](../../GLOSSARY.md).

## Goal

One command installs Shipinetics from a local clone into a harness, and one command shows what works there. This step covers Claude Code and Antigravity, and it builds the parts that the Codex, Copilot and OpenCode adapters (steps 2 to 4) will use: generated copies of the skills, a check that the copies are current, and a table of which guards each harness enforces.

Out of scope for this step: the Codex, Copilot and OpenCode adapters and their hook formats, model roles and the model catalog, and the plan-aware setup.

## Acceptance criteria

- **AC1.** Given a clone, when a person runs `shipinetics install antigravity`, then the installed skills are copies in which no `${CLAUDE_PLUGIN_ROOT}` or `${CLAUDE_SKILL_DIR}` remains, and each path that replaced them exists in the clone.
- **AC2.** Given an install, when a skill file in the clone changes, then `shipinetics status antigravity` says that the copies are older than the clone, names `shipinetics refresh antigravity`, and exits 1. Right after an install or a refresh, it says that the copies are current.
- **AC3.** When a person runs `shipinetics refresh antigravity`, then the copies match the clone again, and nothing outside the install folder changes.
- **AC4.** Given an Antigravity session start in a project, when the copies are older than the clone, then the session-start notice says so and names the refresh command. When they are current, it adds nothing.
- **AC5.** When a person runs `shipinetics status` with no harness, then it prints, for each of the five harnesses, whether Shipinetics is installed there, and for each guard and gate whether that harness enforces it, gives it as an instruction only, or isn't supported yet. The table matches `docs/research/harnesses.md`.
- **AC6.** When a person runs `shipinetics install` for `codex`, `opencode` or `copilot`, then it exits 2, says that the harness isn't supported yet, and points to `shipinetics status`.
- **AC7.** When a person runs `shipinetics install claude`, then it runs `claude plugin marketplace add <clone>` and `claude plugin install shipinetics@shipinetics`. With `--dry-run`, it prints them instead. An agent that runs it meets the install gate, as for any plugin install.
- **AC8.** `shipinetics-antigravity install`, `link-skills` and `status` keep working as before, apart from AC1 (skills become copies).
- **AC9.** When the install folder exists and doesn't look like a Shipinetics install, then install and refresh refuse to change it, for every harness.
- **AC10.** When a person runs `shipinetics uninstall antigravity`, then the install folder is removed, and nothing else changes.
- **AC11.** When the folder that `uninstall` would remove isn't a Shipinetics install (another plugin's folder, an unrelated folder, the clone itself, or a git repo), then it refuses (exit 2), and the folder stays as it was. Install and refresh refuse the clone and a git repo too, and refresh refuses to write through a symlink.
- **AC12.** When a person adds `--dry-run` to `install`, `refresh` or `uninstall`, then it says what it would do, and nothing on disk changes. The install gate doesn't ask about a lone `shipinetics install ... --dry-run` made of plain words, and still asks when another command can ride along.
- **AC13.** Given an Antigravity install with a stamp where `hooks.json`, `scripts` or `bin` is missing, when a person runs `shipinetics status antigravity`, then it says the install is incomplete, names `shipinetics refresh antigravity`, and exits 1. Where `ln -s` makes copies (Windows without Developer Mode), `install` and `refresh` copy those items, and `status` says the install is made of copies.

## Decisions

1. One machine-level command, `shipinetics`, with `install`, `refresh`, `status` and `uninstall`. `shipinetics-config` stays for the project.
2. Each harness's generated copies live in that harness's own plugin folder (for Antigravity, `~/.gemini/config/plugins/shipinetics/`).
3. In the copies, `${CLAUDE_PLUGIN_ROOT}` becomes the clone's path, and `${CLAUDE_SKILL_DIR}` the skill's folder in the clone. Scripts, templates and `bin/` are used from the clone.
4. A copy is out of date when a hash of the clone's `skills/` and `agents/` differs from the hash it was made from.
5. Refresh is a command. `shipinetics-update merge` runs it for each installed harness. The session-start hook only reports.
6. `shipinetics install claude` stops when a `shipinetics` marketplace exists from another source, and only reports when it already points at this clone.
7. `shipinetics status` reads `harnesses.tsv` (one row for each harness and guard). `docs/research/harnesses.md` stays the dated research behind it.
8. The session-start hook becomes "the session notice". Its `hooks_off` name is `notice`, and `companions` keeps working.
9. `shipinetics-antigravity` stays as an alias that prints a one-line hint, until a later breaking release.
10. Release it in the next minor version (0.12.0). Each Antigravity user runs `shipinetics install antigravity` once more (a step for each machine).

## How to check it

`bash tests/run.sh` and `/bin/bash tests/run.sh`, with tests from test-writer for each criterion. A real Antigravity session for AC4, if one is available; otherwise the hook is tested with recorded input, and the summary says so.
