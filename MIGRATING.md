# Migrating from Shipyard

Shipinetics used to be called Shipyard. Version 0.5.0 renamed everything:

| Before | After |
|---|---|
| `.shipyard/` (settings, policy lists, cache) | `.shipinetics/` |
| `SHIPYARD_*` environment variables | `SHIPINETICS_*` |
| `shipyard-config`, `shipyard-verify` | `shipinetics-config`, `shipinetics-verify` |
| `shipyard:<skill>`, `shipyard:<agent>` | `shipinetics:<skill>`, `shipinetics:<agent>` |
| `docs/shipyard-setup.md` | `docs/shipinetics-setup.md` |

## What keeps working in 0.6

0.5.0 only knew the new names, so a project that still had `.shipyard/` had every hook silently off. From 0.6.0, and until 0.7.0 removes it, a project that hasn't migrated still works:

- A project with only `.shipyard/` is still found. Hooks and tools use it and print a one-line notice that asks you to migrate.
- Every `SHIPINETICS_*` setting also accepts its old `SHIPYARD_*` name. The new name wins if both are set.
- The Stop hook and `shipinetics-verify` give verify scripts both `SHIPINETICS_CHANGED_FILES` and `SHIPYARD_CHANGED_FILES`, and both `_VERIFY_TIER` names, so a `bin/verify` copied before the rename still scopes its checks.
- `shipyard-config` and `shipyard-verify` still run, with a deprecation notice.
- A `.shipyard/*` line in `protected-paths` also protects `.shipinetics/`.

The `shipyard:` skill and agent names don't carry over. They come from the plugin's name, so once the new plugin is installed, only `shipinetics:` names exist.

## Switching a project

1. Install the new plugin and remove the old one:

   ```bash
   claude plugin uninstall shipyard@shipyard
   claude plugin marketplace remove shipyard
   claude plugin marketplace add DreKwasi/shipinetics
   claude plugin install shipinetics@shipinetics
   ```

2. In the project, with a clean working tree, preview the migration and then run it:

   ```bash
   shipinetics-config migrate --dry-run
   shipinetics-config migrate
   ```

   It moves `.shipyard/` to `.shipinetics/` (with `git mv`, so the cache moves too) and `docs/shipyard-setup.md` to `docs/shipinetics-setup.md`. Then it rewrites `.shipyard`, `SHIPYARD_*`, `shipyard-verify`, `shipyard-config` and `shipyard:` in the project's tracked text files: `.gitignore`, `protected-paths`, `AGENTS.md`, docs, `bin/verify`, `bin/with-secrets`, `bin/lint-fix`, `bin/llm-fix` and the git hooks. In workspace mode it does the same in each package repo. Other uses of the word "shipyard" stay as they are.

3. Review the result with `git diff` and commit it on its own. The commit touches `.gitignore` and scripts, so the PR gate counts it as code. Open the PR without evidence for this one change (`SHIPINETICS_ALLOW_NO_EVIDENCE=1`) or commit it straight to your main branch.

4. Rename any `SHIPYARD_*` variables you set outside the repo: your shell profile, CI settings and the night-shift environment.

To do it by hand instead: `git mv .shipyard .shipinetics`, then search the repo for `shipyard` and make the same replacements.
