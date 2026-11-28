# The post-commit hook runs the quick verify after a fresh commit and tells the agent the result,
# without ever blocking. It stays quiet when there's nothing new to say or nothing to run.
. "$(dirname "$0")/helpers.sh"
r="$scratch/vac"; new_repo "$r"; cd "$r" || exit 1
stub_verify bin/verify; mkdir -p .shipinetics; printf '.shipinetics/.cache/\n' >.gitignore
cfg='verify_quick_cmd = bin/verify quick'
printf '%s\n' "$cfg" >.shipinetics/config
echo a >a.txt; git add -A; git commit -qm init

# hook <command> [cwd]: run the hook on a Bash command; sets OUT and RC
hook() {
  OUT="$(python3 -c 'import json, sys; print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}, "cwd": sys.argv[2]}))' "$1" "${2:-$r}" |
    bash "$SY/scripts/verify-after-commit.sh")"
  RC=$?
}
# runs: the number of verify runs logged so far
runs() { awk 'END { print NR }' "$r/.shipinetics/.cache/verify-times.tsv" 2>/dev/null || echo 0; }
# change: a fresh commit with new code, so no pass is recorded for it
n=0; change() { n=$((n + 1)); echo "$n" >"$r/a.txt"; git -C "$r" commit -qam "change $n"; }
nl=$'\n'

# AC1: a fresh commit runs the quick tier and reports the result, never blocking
change; hook "git commit -m 'change'"
has "AC1: a passing quick verify is reported as context" "$OUT" '"additionalContext": "shipinetics: the quick verify passed'
has "AC1: it ran the quick tier" "$(cat .shipinetics/.cache/verify.log)" "RAN tier=quick"
eq "AC1: a pass exits 0 with no decision" "$RC:$(printf '%s' "$OUT" | grep -c '"decision"\|"deny"\|"block"')" "0:0"
# AC5: that run is logged with source "commit"
eq "AC5: the hook's run is logged with source commit" \
  "$(awk -F'\t' 'END { print $2 "/" $6 }' .shipinetics/.cache/verify-times.tsv)" "commit/pass"
# AC2: the pass is recorded, so the same code says nothing
hook "git commit -m 'change'"
eq "AC2: a recorded pass prints nothing" "$OUT" ""
touch FAIL; git add FAIL; git commit -qm fail; hook "git commit -m fail"
has "AC1: a failing quick verify says FAILED" "$OUT" "FAILED"
has "AC1: with the tail of the verify output" "$OUT" "boom"
eq "AC1: a failure exits 0 with no decision" "$RC:$(printf '%s' "$OUT" | grep -c '"decision"\|"deny"\|"block"')" "0:0"
git rm -q FAIL; git commit -qm unfail

# AC3: each of these prints nothing and runs nothing, on a fresh commit that a real hook run verifies
quiet() { # quiet <name> <command> [cwd]: the hook prints nothing and logs no run
  local before; before="$(runs)"; hook "$2" "${3:-$r}"
  eq "AC3: quiet and no verify: $1" "$OUT|$RC|$(runs)" "|0|$before"
}
change
quiet "git status" "git status"
quiet "a grep for git commit" 'grep -rn "git commit" scripts'
quiet "a heredoc note naming git commit" "cat > notes.md <<'EOF'${nl}Run git commit when it passes.${nl}EOF"
printf '%s\n' "verify_cmd = bin/verify" >.shipinetics/config
quiet "no quick tier" "git commit -m x"
printf '%s\nhooks_off = verify\n' "$cfg" >.shipinetics/config
quiet "hooks_off = verify in the project config" "git commit -m x"
printf '%s\n' "$cfg" >.shipinetics/config
SHIPINETICS_HOOKS_OFF=verify quiet "SHIPINETICS_HOOKS_OFF=verify" "git commit -m x"
echo old >a.txt; GIT_COMMITTER_DATE="$(( $(date +%s) - 900 )) +0000" git commit -qam old
quiet "HEAD committed 15 minutes ago (a refused commit)" "git commit -m x"
change; hook "git commit -m x"
has "AC3: the same repo, with a fresh commit, does verify" "$OUT" "quick verify passed"
p="$scratch/plain"; new_repo "$p"; stub_verify "$p/bin/verify"; echo a >"$p/a.txt"; git -C "$p" add -A; git -C "$p" commit -qm init
hook "git commit -m x" "$p"
eq "AC3: quiet and no verify: a repo with no .shipinetics/" "$OUT|$RC|$(ls -A "$p" | tr '\n' ' ')" "|0|.git a.txt bin "

# AC4: the repo named by "cd <dir> &&" or "git -C <dir>" is verified, not the hook's cwd
mkdir -p "$scratch/elsewhere"
change; before="$(runs)"; hook "cd vac && git commit -m x" "$scratch"
eq "AC4: cd <dir> && git commit verifies <dir>" "$(printf '%s' "$OUT" | grep -c 'quick verify passed'):$(( $(runs) - before ))" "1:1"
change; before="$(runs)"; hook "git -C $r commit -m x" "$scratch/elsewhere"
eq "AC4: git -C <dir> commit verifies <dir>" "$(printf '%s' "$OUT" | grep -c 'quick verify passed'):$(( $(runs) - before ))" "1:1"
# AC4 on Windows: an agent there names the repo as a native path (git -C C:\x commit, cd C:\x &&).
# Only on Windows: elsewhere there is no C: drive, so a C:\ path can't name the repo.
if on_windows; then
  change; before="$(runs)"; hook "git -C $(native_path "$r") commit -m x" "$scratch/elsewhere"
  eq "AC4: git -C <native Windows path> commit verifies that repo" "$(printf '%s' "$OUT" | grep -c 'quick verify passed'):$(( $(runs) - before ))" "1:1"
  change; before="$(runs)"; hook "cd $(native_path "$r") && git commit -m x" "$scratch/elsewhere"
  eq "AC4: cd <native Windows path> && git commit verifies that repo" "$(printf '%s' "$OUT" | grep -c 'quick verify passed'):$(( $(runs) - before ))" "1:1"
else
  printf '  skip  git -C / cd with a native Windows path (only on Windows: no C: drive here)\n'
fi
# AC13: a commit message that names "git -C <dir> commit" doesn't move the check to <dir>
change; before="$(runs)"; hook 'git commit -m "fix git -C ../plain commit parsing"'
eq "AC13: a message naming git -C <dir> commit still verifies the cwd's repo" "$(printf '%s' "$OUT" | grep -c 'quick verify passed'):$(( $(runs) - before ))" "1:1"
# ctx: the additionalContext text of OUT
ctx() { printf '%s' "$OUT" | python3 -c 'import json, sys; print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])'; }
# AC12: a check that fails with exit 2 (as make does) is a failure, not "could not run"
printf '#!/bin/sh\necho "FAIL test_login: expected 200"\nexit 2\n' >bin/exit2; chmod +x bin/exit2
printf 'verify_quick_cmd = bin/exit2\n' >.shipinetics/config
change; hook "git commit -m x"
eq "AC12: exit 2 from the check says FAILED with the tail, not could not run" \
  "$(ctx | grep -c 'FAILED'):$(ctx | grep -c 'FAIL test_login'):$(ctx | grep -c 'could not run')" "1:1:0"
# AC14: the failure context holds at most about 4,000 bytes of output, even with very long lines
printf '#!/bin/sh\nfor i in 1 2 3; do python3 -c "print(\\"x\\" * 10000)"; done\nexit 1\n' >bin/long; chmod +x bin/long
printf 'verify_quick_cmd = bin/long\n' >.shipinetics/config
change; hook "git commit -m x"; size="$(ctx | wc -c | tr -d ' ')"
eq "AC14: very long output lines are cut to about 4,000 bytes of context" "$(ctx | grep -c FAILED):$([ "$size" -le 5000 ] && echo small || echo "$size bytes")" "1:small"
printf '%s\n' "$cfg" >.shipinetics/config
done_testing
