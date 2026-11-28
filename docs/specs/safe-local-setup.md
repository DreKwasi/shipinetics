# Spec: safe on each user's machine and in each user's project

Status: done. Size: L.

## Goal

A person can install Shipinetics, set up a project and use it, and then remove it, without
Shipinetics changing, hiding or deleting something that the person did not agree to. An audit of
0.12.0 found the problems below. Each acceptance criterion fixes one of them.

## Acceptance criteria

### Worktrees

- **AC1.** When Shipinetics copies the main checkout's `.shipinetics/` into a linked worktree, it
  tells git to ignore the copy in that worktree only: it writes `.shipinetics/.gitignore` with the
  line `*` in the copy. It no longer writes to the shared `info/exclude`. In the main checkout,
  `git status` still shows an untracked or changed file in `.shipinetics/`, and `git add` adds it.
  The first copy never replaces a file that the worktree already has. A sync never writes or
  deletes a file outside the worktree's `.shipinetics/`, whatever the file names are.
- **AC2.** When a sync runs and the shared `info/exclude` holds the exact line `/.shipinetics/`
  (which 0.11 and 0.12 added), Shipinetics removes that line and keeps every other line. A main
  checkout with no worktree loses the line too. A line that ends in CRLF counts as the same line,
  and the other lines keep their CRLF. An `info/exclude` that is a symlink stays a symlink.
- **AC3.** When the worktree's branch tracks files in `.shipinetics/` (`git ls-files .shipinetics`
  in the worktree prints a path), Shipinetics never copies into it and never deletes from it. It
  removes `.shipinetics/.copied-from` and its own `.shipinetics/.gitignore` there, so the worktree
  uses its own tracked settings from then on.
- **AC4.** The copy leaves out `.shipinetics/explainers/`, as it leaves out `.cache/` and
  `pending/`.

### Setup (instructions in `skills/setup/SKILL.md`)

- **AC5.** Setup checks `git status --porcelain` before its first write. If the tree has changes,
  it shows them and asks the person to commit or stash them first. It never commits a file that
  setup didn't write.
- **AC6.** The line-ending step renormalizes only the paths in the lines that setup added:
  `git add --renormalize -- bin .githooks .shipinetics` and the `*.sh` files, not `.`.
- **AC7.** Before setup sets `core.hooksPath`, it reads the current value and the hook files in
  `.git/hooks` that don't end in `.sample`. If either exists (a hook manager such as husky,
  lefthook or pre-commit, or Git LFS), setup tells the person, asks, and records the old value in
  `docs/shipinetics-setup.md`, so that the person can restore it.
- **AC8.** The `pre-push` template runs `git lfs pre-push "$@"` first when `git-lfs` is installed
  and the repo uses LFS (a `filter=lfs` line in `.gitattributes`), so that LFS objects still go up. When `git lfs pre-push` fails, the hook fails and the push stops.
- **AC9.** The `.gitignore` additions keep `.env.example` and `.env.sample` (`!.env.example`,
  `!.env.sample`).

### Task queue

- **AC10.** The task-queue skill pushes a claim or a new task ID to the default branch only when
  `.shipinetics/config` has `queue_push = yes`. The skill asks the person once, and the person sets
  the key (the file is protected). Without the key, the agent claims in its own branch only.

### Installer (`bin/shipinetics`)

- **AC11.** `shipinetics link-skills antigravity --dry-run` says what it would add, and changes
  nothing. Without `--dry-run`, it writes `skills.json` only when it adds an entry, keeps non-ASCII
  text as it is, and writes through a temp file that it renames into place. A `skills.json` that is a symlink stays a symlink, and its target gets the new text.
- **AC12.** `shipinetics uninstall antigravity` removes only what install writes (the items that
  `link_items` links, `skills`, `agents`, the stamp and the agents temp folder), then removes the
  folder if it is empty. Another file in the folder stays, and the command says that it stayed. When the target is a symlink, only the link is removed, and the folder that it points to doesn't change.
  An install over an install also keeps each file that install didn't write, and names it.
- **AC13.** `install` and `uninstall` refuse a `--target` whose last part isn't `shipinetics`,
  unless `--force` is given. The message names the folder and `--force`. `--force` works only with
  install and uninstall, and `--all` and `--yes` only with uninstall. Any other use exits 2 and
  names the flag.
- **AC14.** `shipinetics uninstall claude` also removes the `shipinetics` marketplace when it
  points at this clone (`claude plugin marketplace remove shipinetics`). It leaves a marketplace
  from another source. When the plugin uninstall fails, the marketplace stays, and the command
  exits non-zero.

### Other tools

- **AC15.** `shipinetics-shims` never writes through a symlink: a target that is a symlink, also a
  broken one, is skipped, by `install` and by the automatic install.
- **AC16.** test-writer's instructions no longer run `git worktree prune`.
- **AC17.** `shipinetics-usage serve` answers a request only when its `Host` header is
  `127.0.0.1:<port>` or `localhost:<port>`. A POST to `/api/pricing` must also have
  `Content-Type: application/json`. Any other request gets 403 and changes nothing.

### Remove Shipinetics

- **AC18.** `shipinetics uninstall --all` removes, after one confirmation at a terminal (or with
  `--yes`): the install in each harness, the shims that `shipinetics-shims` wrote, and the folders
  `~/.cache/shipinetics/` and `~/.local/share/shipinetics/` (the usage log). It lists
  `~/.config/shipinetics/` and the PATH line, and leaves them, because the person wrote them.
  `--dry-run` lists all of it and changes nothing. When one step fails, the other steps still run, the
  command names the step that failed, and it exits non-zero.
- **AC19.** The README has a section "Remove Shipinetics", for a machine (AC18) and for a project:
  the files and settings that setup added, and the command to restore the old `core.hooksPath`.
  Its `.gitignore` step says to keep the `.env` lines.

## Out of scope

- The fingerprint's loose objects in `.git/objects` (git removes them in about two weeks).
- Asking before the automatic shims, the usage log, the `/compact` check and the quick verify after
  a commit. They stay on by default. The README lists them, and `hooks_off` turns each one off.
