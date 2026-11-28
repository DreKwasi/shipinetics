# Git worktrees: a worktree of a set-up repo gets the main checkout's settings, with paths relative
# to the worktree, wherever the worktree is. A workspace package worktree in the workspace folder
# counts as its package. A container that can't reach the main checkout uses the copy.
. "$(dirname "$0")/helpers.sh"
scratch="$(cd "$scratch" && pwd -P)"   # macOS: /var is /private/var, and git and the tools print the resolved path

# edit <session folder> <file> [agent type]: run the edit guard on an Edit of that file; prints DENIED or allowed
edit() {
  local r
  r="$(printf '{"tool_name":"Edit","cwd":"%s","agent_type":"%s","tool_input":{"file_path":"%s"}}' "$1" "${3:-}" "$2" |
    CLAUDE_PROJECT_DIR="$1" bash "$SY/scripts/guard-edits.sh" 2>&1)"
  case "$r" in *deny*) echo DENIED ;; *) echo allowed ;; esac
}
# notice <folder>: the worktree notice's output for a session that starts there
notice() { printf '{"hook_event_name":"SessionStart","cwd":"%s"}' "$1" | bash "$SY/scripts/worktree-notice.sh" 2>&1; }

# ---- a single repo whose .shipinetics/ git ignores
m="$scratch/app"; new_repo "$m"; cd "$m" || exit 1
mkdir -p .shipinetics e2e/acceptance docs
printf '.shipinetics/\n.claude/worktrees/\n' >.gitignore
printf 'verify_cmd = bin/verify\nworksheets_dir = docs/worksheets\n' >.shipinetics/config
printf 'e2e/acceptance/*\n' >.shipinetics/protected-paths
printf '*.spec.ts\ne2e/*\n' >.shipinetics/test-paths
echo t >e2e/acceptance/login.spec.ts; echo h >e2e/helper.ts; stub_verify bin/verify
git add -A; git commit -qm init
git worktree add -q .claude/worktrees/in -b in
git worktree add -q "$scratch/out" -b out
in="$m/.claude/worktrees/in"; out="$scratch/out"

for w in "$in" "$out"; do
  case "$w" in "$in") n="inside the main checkout" ;; *) n="outside the main checkout" ;; esac
  eq "$n: a protected acceptance test stays protected" "$(edit "$w" "$w/e2e/acceptance/login.spec.ts" test-writer)" DENIED
  eq "$n: a folder rule (e2e/*) still keeps the author out of tests" "$(edit "$w" "$w/e2e/helper.ts")" DENIED
  eq "$n: other files can be edited" "$(edit "$w" "$w/src/app.ts")" allowed
  eq "$n: the worktree is its own root" "$(cd "$w" && shipinetics-config root)" "$w"
  has "$n: the settings say where they came from" "$(cd "$w" && shipinetics-config)" "copied from $m"
  OUT="$(cd "$w" && worksheet new wt-task)"
  has "$n: worksheet new writes in the worktree" "$OUT" "$w/docs/worksheets/"
  OUT="$(cd "$w" && shipinetics-verify 2>&1)"; RC=$?
  eq "$n: shipinetics-verify runs" "$RC" 0
  has "$n: and records the pass in the worktree" "$OUT" "$w/.shipinetics/.cache/"
  hasnt "$n: git doesn't see the copied settings" "$(git -C "$w" status --porcelain)" ".shipinetics"
done
[ ! -d "$m/docs/worksheets" ] && ok "the main checkout gets no worksheet" || bad "the main checkout gets no worksheet" "$(ls "$m/docs/worksheets")"
[ ! -d "$m/.shipinetics/.cache" ] || ! ls "$m/.shipinetics/.cache" | grep -q verify &&
  ok "the main checkout gets no verify pass" || bad "the main checkout gets no verify pass" "$(ls "$m/.shipinetics/.cache")"
eq "a worktree that no Shipinetics call reached has no copy" "$(git worktree add -q "$scratch/idle" -b idle; [ -e "$scratch/idle/.shipinetics" ] && echo yes || echo no)" no

# A settings change in the main checkout reaches the worktree's copy
sleep 1; printf 'e2e/acceptance/*\nsrc/locked.ts\n' >"$m/.shipinetics/protected-paths"; mkdir -p "$out/src"; echo x >"$out/src/locked.ts"
eq "a new protected path in the main checkout applies in the worktree" "$(edit "$out" "$out/src/locked.ts")" DENIED
has "the copy has the new list" "$(cat "$out/.shipinetics/protected-paths")" "src/locked.ts"

# A container that mounts only the worktree: its git folder isn't reachable, so it uses the copy
printf 'gitdir: /nowhere/app/.git/worktrees/out\n' >"$out/.git"
eq "with the main checkout out of reach, the copy keeps the guard on" "$(edit "$out" "$out/e2e/acceptance/login.spec.ts" test-writer)" DENIED
eq "and no notice" "$(notice "$out" | grep -c 'off in this session')" 0
c="$scratch/box"; git worktree add -q "$c" -b box; printf 'gitdir: /nowhere/app/.git/worktrees/box\n' >"$c/.git"
OUT="$(notice "$c")"
has "with no copy, the notice says Shipinetics is off" "$OUT" "Shipinetics is off in this session"
has "and says to mount the main checkout or run it on the host" "$OUT" "mount the main checkout"

# A change to the settings, proposed in a worktree, goes to the main checkout
mkdir -p "$in/.shipinetics/pending/.shipinetics"; printf 'e2e/acceptance/*\nsrc/other.ts\n' >"$in/.shipinetics/pending/.shipinetics/protected-paths"
# apply needs a pseudo-terminal. Some sandboxes have none; CI does.
if python3 -c 'import os, pty; m, s = pty.openpty(); os.close(m); os.close(s)' 2>/dev/null; then
  OUT="$(cd "$in" && with_tty 'y
' shipinetics-config apply)"
  has "apply says it changes the main checkout's file" "$OUT" "the main checkout's file: $m/.shipinetics/protected-paths"
  has "the main checkout gets the change" "$(cat "$m/.shipinetics/protected-paths")" "src/other.ts"
  has "and the worktree's copy follows" "$(cd "$in" && shipinetics-config root >/dev/null; cat "$in/.shipinetics/protected-paths")" "src/other.ts"
else
  printf '  skip  apply in a worktree changes the main checkout (no pseudo-terminal here)\n'
fi

# A delete of a settings file, proposed in a worktree, deletes the main checkout's file too
echo old >"$m/.shipinetics/old-list"; (cd "$in" && shipinetics-config root >/dev/null)
printf '.shipinetics/old-list\n' >"$in/.shipinetics/pending/.delete"
if python3 -c 'import os, pty; m, s = pty.openpty(); os.close(m); os.close(s)' 2>/dev/null; then
  OUT="$(cd "$in" && with_tty 'y
' shipinetics-config apply)"
  has "apply says a delete in a worktree deletes the main checkout's file" "$OUT" "(This deletes the main checkout's file: $m/.shipinetics/old-list)"
  eq "the main checkout's file is deleted, and the delete is no longer pending" \
    "$([ -e "$m/.shipinetics/old-list" ] && echo kept || echo deleted):$([ -e "$in/.shipinetics/pending/.delete" ] && echo pending || echo done)" "deleted:done"
else
  printf '  skip  a delete applied in a worktree deletes the main checkout file (no pseudo-terminal here)\n'
fi
rm -f "$in/.shipinetics/pending/.delete"

# ---- settings tracked in git: the worktree has its own, and nothing is copied
t="$scratch/tracked"; new_repo "$t"; cd "$t" || exit 1
mkdir -p .shipinetics; printf '.cache/\n' >.shipinetics/.gitignore
printf 'verify_cmd = bin/verify\n' >.shipinetics/config; printf 'e2e/*\n' >.shipinetics/protected-paths
mkdir -p e2e; echo t >e2e/a.spec.ts; git add -A; git commit -qm init
git worktree add -q "$scratch/tracked-wt" -b x
eq "tracked settings: the worktree is its own root" "$(cd "$scratch/tracked-wt" && shipinetics-config root)" "$scratch/tracked-wt"
[ ! -f "$scratch/tracked-wt/.shipinetics/.copied-from" ] && ok "tracked settings: nothing is copied" || bad "tracked settings: nothing is copied" "a copy exists"

# ---- a workspace: a package worktree in the workspace folder counts as its package
ws="$scratch/ws"; mkdir -p "$ws/.shipinetics" "$ws/bin"; cd "$ws" || exit 1
printf 'packages = api\npackage_verify_cmd = bin/verify-package {package}\n' >.shipinetics/config
printf '#!/bin/sh\necho "verify-package $1"\n' >bin/verify-package; chmod +x bin/verify-package
new_repo "$ws/api"; git -C "$ws/api" commit -q --allow-empty -m init
git -C "$ws/api" worktree add -q "$ws/api-feat" -b feat
git -C "$ws/api" worktree add -q "$scratch/api-away" -b away
OUT="$(cd "$ws/api-feat" && shipinetics-verify 2>&1)"; RC=$?
eq "a package worktree in the workspace passes without a packages entry" "$RC" 0
has "and verify gets the worktree's folder as the package" "$OUT" "verify-package api-feat"
[ ! -e "$ws/api-feat/.shipinetics" ] && ok "a package worktree gets no copy" || bad "a package worktree gets no copy" "it has .shipinetics/"
eq "a folder that isn't a package worktree is still refused" "$(mkdir -p "$ws/other"; new_repo "$ws/other"; cd "$ws/other" && shipinetics-verify >/dev/null 2>&1; echo $?)" 2
OUT="$(cd "$scratch/api-away" && shipinetics-verify 2>&1)"
has "a package worktree outside the workspace says where to create it" "$OUT" "git -C $ws/api worktree add $ws/api-<branch>"
has "and the session notice says the same" "$(notice "$scratch/api-away")" "Shipinetics finds a package worktree only in a folder directly in $ws"
eq "the notice is quiet in a worktree that works" "$(notice "$in" | grep -c 'off in this session')" 0
done_testing
