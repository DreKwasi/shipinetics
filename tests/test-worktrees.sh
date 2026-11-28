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
# apply above removes pending/ once it is empty, so make it again: this block must not depend on that one
mkdir -p "$in/.shipinetics/pending"; printf '.shipinetics/old-list\n' >"$in/.shipinetics/pending/.delete"
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

# ---- settings that the main checkout has, but neither commits nor ignores (as right after setup)
u="$scratch/untracked"; new_repo "$u"; cd "$u" || exit 1
printf '.claude/worktrees/\n' >.gitignore; echo a >a.txt; git add -A; git commit -qm init
mkdir -p .shipinetics/explainers
printf 'verify_cmd = bin/verify\n' >.shipinetics/config; echo main >.shipinetics/explainers/a.md
uw="$scratch/untracked-wt"; ut="$scratch/untracked-tr"
git worktree add -q "$uw" -b uw; git worktree add -q "$ut" -b ut
(cd "$uw" && shipinetics-config root >/dev/null); (cd "$ut" && shipinetics-config root >/dev/null)
eq "safe-local-setup AC1: (setup) the worktree got a copy" "$([ -f "$uw/.shipinetics/.copied-from" ] && echo copy)" copy
has "safe-local-setup AC1: the main checkout's git status still shows its untracked .shipinetics/" "$(git -C "$u" status --porcelain)" "?? .shipinetics/"
git -C "$u" add .shipinetics/config
eq "safe-local-setup AC1: git add in the main checkout adds a .shipinetics/ file" "$(git -C "$u" diff --cached --name-only)" ".shipinetics/config"
git -C "$u" reset -q
hasnt "safe-local-setup AC1: the worktree's git status doesn't show the copy" "$(git -C "$uw" status --porcelain)" ".shipinetics"
eq "safe-local-setup AC1: the copy's own .gitignore ignores it" "$(cat "$uw/.shipinetics/.gitignore" 2>/dev/null)" "*"
eq "safe-local-setup AC1: the shared info/exclude gets no .shipinetics line" "$(grep -c 'shipinetics' "$u/.git/info/exclude" 2>/dev/null || :)" "0"
eq "safe-local-setup AC4: the main checkout's explainers/ isn't copied" "$([ -e "$uw/.shipinetics/explainers/a.md" ] && echo copied || echo left-out)" left-out

# AC3: the branch of worktree ut starts to track its own settings, after it got a copy
printf 'verify_cmd = bin/own\n' >"$ut/.shipinetics/config"; echo own >"$ut/.shipinetics/own-list"
git -C "$ut" add -f .shipinetics/config; git -C "$ut" commit -qm "track settings"
# AC3: a branch that tracks a .shipinetics/ file (but no config) before any copy: nothing is copied into it
uf="$scratch/untracked-first"; git -C "$u" worktree add -q "$uf" -b uf
mkdir -p "$uf/.shipinetics"; printf 'tests/*\n' >"$uf/.shipinetics/test-paths"
git -C "$uf" add -f .shipinetics/test-paths; git -C "$uf" commit -qm "track test-paths"
(cd "$uf" && shipinetics-config root >/dev/null)
eq "safe-local-setup AC3: a branch that tracks .shipinetics/ files gets no copy" "$(ls -A "$uf/.shipinetics" | tr '\n' ' ')" "test-paths "
# AC4: worktree uw has explainers of its own
mkdir -p "$uw/.shipinetics/explainers"; echo own >"$uw/.shipinetics/explainers/b.md"
# a change in the main checkout makes both copies stale
sleep 1; printf 'verify_cmd = bin/verify\nlaunch = user\n' >"$u/.shipinetics/config"
(cd "$uw" && shipinetics-config root >/dev/null); (cd "$ut" && shipinetics-config root >/dev/null)
eq "safe-local-setup AC4: (setup) the stale copy was refreshed" "$(grep -c 'launch = user' "$uw/.shipinetics/config")" 1
eq "safe-local-setup AC4: a refresh keeps the worktree's own explainers and still leaves out the main checkout's" \
  "$([ -f "$uw/.shipinetics/explainers/b.md" ] && echo kept):$([ -e "$uw/.shipinetics/explainers/a.md" ] && echo copied || echo left-out)" "kept:left-out"
eq "safe-local-setup AC3: a branch that tracks .shipinetics/ keeps its own tracked config" "$(cat "$ut/.shipinetics/config")" "verify_cmd = bin/own"
eq "safe-local-setup AC3: and its other files (nothing is deleted)" "$(cat "$ut/.shipinetics/own-list" 2>/dev/null)" own
eq "safe-local-setup AC3: .copied-from and the copy's .gitignore are removed" \
  "$([ -e "$ut/.shipinetics/.copied-from" ] && echo copied-from):$([ -e "$ut/.shipinetics/.gitignore" ] && echo gitignore)" ":"

# AC2: a copy from 0.12 (no .gitignore of its own) and the line that 0.12 wrote to the shared info/exclude
rm -f "$uw/.shipinetics/.gitignore"
printf '*.log\n/.shipinetics/\n/.shipinetics\n/.shipinetics/x\n' >"$u/.git/info/exclude"
(cd "$uw" && shipinetics-config root >/dev/null)
eq "safe-local-setup AC2: the exact line /.shipinetics/ is removed from info/exclude, and every other line stays" \
  "$(sort "$u/.git/info/exclude")" "$(printf '*.log\n/.shipinetics\n/.shipinetics/x\n' | sort)"
eq "safe-local-setup AC2: and the old copy gets its own .gitignore" "$(cat "$uw/.shipinetics/.gitignore" 2>/dev/null)" "*"

# ---- settings tracked in git: the worktree has its own, and nothing is copied
t="$scratch/tracked"; new_repo "$t"; cd "$t" || exit 1
mkdir -p .shipinetics; printf '.cache/\n' >.shipinetics/.gitignore
printf 'verify_cmd = bin/verify\n' >.shipinetics/config; printf 'e2e/*\n' >.shipinetics/protected-paths
mkdir -p e2e; echo t >e2e/a.spec.ts; git add -A; git commit -qm init
git worktree add -q "$scratch/tracked-wt" -b x
eq "tracked settings: the worktree is its own root" "$(cd "$scratch/tracked-wt" && shipinetics-config root)" "$scratch/tracked-wt"
[ ! -f "$scratch/tracked-wt/.shipinetics/.copied-from" ] && ok "tracked settings: nothing is copied" || bad "tracked settings: nothing is copied" "a copy exists"
# safe-local-setup AC3: a .copied-from left from an older copy goes, and the branch's own tracked .gitignore stays
printf '%s\n' "$t" >"$scratch/tracked-wt/.shipinetics/.copied-from"
(cd "$scratch/tracked-wt" && shipinetics-config root >/dev/null)
eq "safe-local-setup AC3: tracked settings: the old .copied-from is removed, and the tracked .gitignore is unchanged" \
  "$([ -e "$scratch/tracked-wt/.shipinetics/.copied-from" ] && echo copied-from):$(cat "$scratch/tracked-wt/.shipinetics/.gitignore")" ":.cache/"

# ---- safe-local-setup AC2: a main checkout (no worktree) loses the line that 0.11 and 0.12 wrote to info/exclude
mc="$scratch/main-only"; new_repo "$mc"; mkdir -p "$mc/.shipinetics"; printf 'verify_cmd = bin/verify\n' >"$mc/.shipinetics/config"
bytes() { python3 -c 'import sys; print(repr(open(sys.argv[1], "rb").read()))' "$1"; }
printf '*.log\n/.shipinetics/\n/.shipinetics/x\n' >"$mc/.git/info/exclude"
(cd "$mc" && shipinetics-config root >/dev/null)
eq "safe-local-setup AC2: in a main checkout, the line /.shipinetics/ is removed and the other lines stay" "$(bytes "$mc/.git/info/exclude")" "b'*.log\\n/.shipinetics/x\\n'"
printf '*.log\r\n/.shipinetics/\r\n/.shipinetics/x\r\n' >"$mc/.git/info/exclude"
(cd "$mc" && shipinetics-config root >/dev/null)
eq "safe-local-setup AC2: a CRLF line /.shipinetics/ is removed too, and the other lines keep their CRLF" "$(bytes "$mc/.git/info/exclude")" "b'*.log\\r\\n/.shipinetics/x\\r\\n'"
printf '*.log\n/.shipinetics/\n' >"$scratch/shared-exclude"; rm -f "$mc/.git/info/exclude"
if ln -s "$scratch/shared-exclude" "$mc/.git/info/exclude" 2>/dev/null && [ -L "$mc/.git/info/exclude" ]; then
  (cd "$mc" && shipinetics-config root >/dev/null)
  eq "safe-local-setup AC2: an info/exclude that is a symlink stays one, and its target loses the line" \
    "$([ -L "$mc/.git/info/exclude" ] && echo link):$(bytes "$scratch/shared-exclude")" "link:b'*.log\\n'"
else
  printf '  skip  info/exclude as a symlink (ln -s makes copies here)\n'
fi

# ---- safe-local-setup AC1, AC3: the first copy into a worktree keeps the worktree's own files
fc="$scratch/first-copy"; new_repo "$fc"; echo a >"$fc/a.txt"; git -C "$fc" add -A; git -C "$fc" commit -qm init
mkdir -p "$fc/.shipinetics"; printf 'verify_cmd = bin/verify\n' >"$fc/.shipinetics/config"
printf 'src/main-ui/*\n' >"$fc/.shipinetics/ui-paths"; printf 'e2e/*\n' >"$fc/.shipinetics/protected-paths"
fw="$scratch/first-copy-wt"; git -C "$fc" worktree add -q "$fw" -b fw
mkdir -p "$fw/.shipinetics"; printf 'src/my-ui/*\n' >"$fw/.shipinetics/ui-paths"
(cd "$fw" && shipinetics-config root >/dev/null)
eq "safe-local-setup AC1, AC3: the first copy keeps the worktree's own untracked ui-paths, and copies the main checkout's other files" \
  "$(cat "$fw/.shipinetics/ui-paths"):$(cat "$fw/.shipinetics/config" 2>/dev/null):$(cat "$fw/.shipinetics/protected-paths" 2>/dev/null)" \
  "src/my-ui/*:verify_cmd = bin/verify:e2e/*"

# ---- safe-local-setup AC1: a file name with a newline in the main checkout's .shipinetics/ can't reach
# outside the worktree's .shipinetics/. Read line by line, the name "a<newline>../w-victim" is "./a" and
# "../w-victim": a refresh would copy the main checkout's w-victim over the worktree's, and remove the
# worktree's d-victim (the source no longer has it).
if on_windows; then
  printf '  skip  file names with a newline (Windows has none)\n'
else
  nl="$scratch/newline"; new_repo "$nl"; echo a >"$nl/a.txt"; git -C "$nl" add -A; git -C "$nl" commit -qm init
  nd="$(printf 'a\n..')"
  mkdir -p "$nl/.shipinetics/$nd"; printf 'verify_cmd = bin/verify\n' >"$nl/.shipinetics/config"
  echo main >"$nl/.shipinetics/$nd/w-victim"; echo main >"$nl/.shipinetics/$nd/d-victim"; echo main >"$nl/w-victim"
  nw="$scratch/newline-wt"; git -C "$nl" worktree add -q "$nw" -b nw
  echo mine >"$nw/w-victim"; echo mine >"$nw/d-victim"
  outside() {   # the files of the worktree and of the main checkout outside .shipinetics/ and .git, with their contents
    local r
    for r in "$nw" "$nl"; do
      (cd "$r" && find . \( -path ./.shipinetics -o -path ./.git \) -prune -o -type f -print | sort | while IFS= read -r f; do printf '%s=%s\n' "$r/$f" "$(cat "$f")"; done)
    done
  }
  o_before="$(outside)"
  (cd "$nw" && shipinetics-config root >/dev/null)
  eq "safe-local-setup AC1: (setup) the worktree got a copy" "$([ -f "$nw/.shipinetics/.copied-from" ] && echo copy)" copy
  rm -f "$nl/.shipinetics/$nd/d-victim"
  sleep 1; printf 'verify_cmd = bin/verify\nlaunch = user\n' >"$nl/.shipinetics/config"
  (cd "$nw" && shipinetics-config root >/dev/null)
  eq "safe-local-setup AC1: (setup) the copy was refreshed" "$(grep -c 'launch = user' "$nw/.shipinetics/config")" 1
  eq "safe-local-setup AC1: a sync and a refresh with a newline in a file name write and delete nothing outside .shipinetics/" "$(outside)" "$o_before"
fi

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
