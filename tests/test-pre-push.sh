# The pre-push template: runs bin/verify itself, shows it, and works in a worktree with no .shipinetics/.
. "$(dirname "$0")/helpers.sh"
t="$scratch/pp"; new_repo "$t"; cd "$t" || exit 1
mkdir -p .githooks; cp "$SY/skills/setup/templates/pre-push" .githooks/pre-push; chmod +x .githooks/pre-push
stub_verify bin/verify
printf '.shipinetics/\n.claude/worktrees/\n' >.gitignore
mkdir -p .shipinetics; printf 'verify_cmd = bin/verify\n' >.shipinetics/config
echo a >a.txt; git add -A; git commit -qm init
sha="$(git rev-parse HEAD)"; zero=0000000000000000000000000000000000000000
push() { OUT="$(printf 'refs/heads/main %s refs/heads/main %s\n' "$1" "$zero" | .githooks/pre-push 2>&1)"; RC=$?; }

push "$sha"; eq "a passing verify lets the push go" "$RC" 0
has "it says what it runs" "$OUT" "pre-push: running bin/verify"
has "it shows the checks' output" "$OUT" "RAN tier=none"
has "it says it passed and how long it took" "$OUT" "bin/verify passed in"
hasnt "a clean tree gives no note" "$OUT" "uncommitted"
echo b >a.txt; push "$sha"; has "uncommitted changes are named" "$OUT" "you have uncommitted changes"
git checkout -q a.txt
touch FAIL; push "$sha"; eq "a failing verify stops the push" "$RC" 1
has "it says the push was stopped" "$OUT" "so the push was stopped"
push "$zero"; eq "a branch delete runs nothing" "$OUT" ""
rm FAIL

# ---- safe-local-setup AC8: in a repo that uses Git LFS, git lfs pre-push runs first
# A fake git-lfs, first on the PATH: it says how it was called, keeps what it read, and exits $FAKE_LFS_RC
lfs="$scratch/lfs-bin"; mkdir -p "$lfs"
cat >"$lfs/git-lfs" <<EOF
#!/bin/sh
echo "LFS RAN \$*"
cat >"$scratch/lfs-stdin"
exit \${FAKE_LFS_RC:-0}
EOF
chmod +x "$lfs/git-lfs"
url=https://example.test/r.git
line="refs/heads/main $sha refs/heads/main $zero"
lfs_push() { OUT="$(printf '%s\n' "$line" | PATH="$lfs:$PATH" .githooks/pre-push origin "$url" 2>&1)"; RC=$?; }
printf '*.bin filter=lfs diff=lfs merge=lfs -text\n' >.gitattributes
lfs_push
eq "safe-local-setup AC8: with LFS, the push goes" "$RC" 0
has "safe-local-setup AC8: git lfs pre-push gets the hook's arguments" "$OUT" "LFS RAN pre-push origin $url"
eq "safe-local-setup AC8: and the ref lines" "$(cat "$scratch/lfs-stdin" 2>/dev/null)" "$line"
eq "safe-local-setup AC8: LFS runs before bin/verify, and bin/verify still runs" \
  "$(printf '%s\n' "$OUT" | grep -o -e 'LFS RAN' -e 'running bin/verify' -e 'bin/verify passed' | tr '\n' ',')" "LFS RAN,running bin/verify,bin/verify passed,"
FAKE_LFS_RC=1 lfs_push
[ "$RC" -ne 0 ] && ok "safe-local-setup AC8: a failing git lfs pre-push stops the push" || bad "safe-local-setup AC8: a failing git lfs pre-push stops the push" "exit $RC: $OUT"
# git-lfs not installed: a PATH with only the tools the hook and bin/verify use (git-lfs often sits next to git)
nolfs="$scratch/nolfs-bin"; mkdir -p "$nolfs"
for tool in git cat grep date tr; do
  printf '#!/bin/sh\nexec "%s" "$@"\n' "$(command -v "$tool")" >"$nolfs/$tool"; chmod +x "$nolfs/$tool"
done
OUT="$(printf '%s\n' "$line" | PATH="$nolfs" "${BASH:-bash}" .githooks/pre-push origin "$url" 2>&1)"; RC=$?
eq "safe-local-setup AC8: with LFS in .gitattributes but no git-lfs, the hook doesn't fail" "$RC" 0
has "safe-local-setup AC8: and bin/verify runs" "$OUT" "bin/verify passed"
printf '*.txt text\n' >.gitattributes
lfs_push
hasnt "safe-local-setup AC8: a repo that doesn't use LFS doesn't call git lfs" "$OUT" "LFS RAN"
rm -f .gitattributes
mkdir -p sub; printf '*.psd filter=lfs diff=lfs merge=lfs -text\n' >sub/.gitattributes
lfs_push
has "safe-local-setup AC8: an LFS line only in a nested sub/.gitattributes calls git lfs too" "$OUT" "LFS RAN pre-push origin $url"
rm -rf sub

# A worktree inside the main checkout, which has .shipinetics/ but git ignores it
git worktree add -q .claude/worktrees/w -b w
cd .claude/worktrees/w || exit 1
[ ! -d .shipinetics ] && ok "the worktree has no .shipinetics/" || bad "the worktree has no .shipinetics/" "it has one"
push "$(git rev-parse HEAD)"; eq "the hook passes in a worktree" "$RC" 0
has "and runs bin/verify there" "$OUT" "bin/verify passed in"
rm bin/verify; push "$(git rev-parse HEAD)"; eq "no bin/verify: the push goes" "$RC" 0
has "and it says no checks ran" "$OUT" "no bin/verify in this repo"
done_testing
