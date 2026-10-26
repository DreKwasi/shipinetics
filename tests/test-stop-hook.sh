# The Stop hook picks the right tier, reuses passes, blocks failures and releases a stuck agent.
. "$(dirname "$0")/helpers.sh"
p="$scratch/proj"; new_repo "$p"; cd "$p" || exit 1
stub_verify bin/verify; mkdir -p .shipinetics/.cache
printf 'verify_quick_cmd = bin/verify --quick\n' >.shipinetics/config
printf 'package.json\n*/package.json\n' >.shipinetics/complete-paths
printf '.shipinetics/.cache/\n' >.gitignore
echo a >a.txt; git add -A; git commit -qm init
touch .shipinetics/.cache/session-s1

echo b >a.txt; stop_hook "$p"
eq "mid-task stop runs quick" "$(last_timing "$p")" "quick pass"
has "user is told only quick ran" "$OUT" "quick checks passed"
has "quick tier gets --quick and the changed files" "$(cat .shipinetics/.cache/verify.log)" "arg=--quick files=a.txt|"
stop_hook "$p"; eq "same code reuses the pass" "$(last_timing "$p")" "quick reused"
git commit -qam step; stop_hook "$p"; eq "commit keeps the pass" "$(last_timing "$p")" "quick reused"
mkdir -p docs/worksheets; printf '# W\n> Status: done | Task: x\n' >docs/worksheets/w.md
echo docs/worksheets/w.md >.shipinetics/.cache/current-worksheet
stop_hook "$p"; eq "done stop runs complete" "$(last_timing "$p")" "complete pass"
git add -A; git commit -qm wrap; stop_hook "$p"; eq "committing the worksheet reuses" "$(last_timing "$p")" "complete reused"
replace docs/worksheets/w.md "Status: done" "Status: in progress"
echo '{}' >package.json; stop_hook "$p"; eq "complete-paths change runs complete" "$(last_timing "$p")" "complete pass"
echo c >a.txt; touch FAIL; stop_hook "$p"
eq "failure blocks the stop" "$RC" 2
has "failure shows the output" "$OUT" "boom"
stop_hook "$p" true; eq "stuck agent is released" "$RC" 0
has "release tells the user" "$OUT" "still failing"
rm FAIL

# A renamed file and a path with a space reach the quick tier as plain paths.
git add -A; git commit -qm more; replace docs/worksheets/w.md "Status: done" "Status: in progress"
git mv a.txt "b c.txt"; stop_hook "$p"
has "rename lists the new path unquoted" "$(cat .shipinetics/.cache/verify.log)" "|b c.txt|"
has "rename lists the old path too" "$(cat .shipinetics/.cache/verify.log)" "a.txt|"

# A resumed session that only marks the task done still gets the complete tier.
git commit -qm renamed; rm -f .shipinetics/.cache/pass-* .shipinetics/.cache/head-s1
git commit -q --allow-empty -m start
replace docs/worksheets/w.md "Status: in progress" "Status: done"
stop_hook "$p"; eq "done-only stop runs complete" "$(last_timing "$p")" "complete pass"

# SHIPINETICS_SKIP_VERIFY turns the hook off for a session.
echo e >>"b c.txt"; rm -f .shipinetics/.cache/verify.log
SHIPINETICS_SKIP_VERIFY=1 stop_hook "$p"
eq "SHIPINETICS_SKIP_VERIFY turns the Stop hook off" "$([ -f .shipinetics/.cache/verify.log ] && echo ran || echo skipped)" skipped

# No quick tier configured: every stop runs complete, as before.
: >.shipinetics/config; echo d >>"b c.txt"; replace docs/worksheets/w.md "Status: done" "Status: in progress"
stop_hook "$p"; eq "without a quick tier, complete runs" "$(last_timing "$p")" "complete pass"
done_testing
