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

# A worktree inside the main checkout, which has .shipinetics/ but git ignores it
git worktree add -q .claude/worktrees/w -b w
cd .claude/worktrees/w || exit 1
[ ! -d .shipinetics ] && ok "the worktree has no .shipinetics/" || bad "the worktree has no .shipinetics/" "it has one"
push "$(git rev-parse HEAD)"; eq "the hook passes in a worktree" "$RC" 0
has "and runs bin/verify there" "$OUT" "bin/verify passed in"
rm bin/verify; push "$(git rev-parse HEAD)"; eq "no bin/verify: the push goes" "$RC" 0
has "and it says no checks ran" "$OUT" "no bin/verify in this repo"
done_testing
