# Workspace mode: per-package tiers, only packages the agent touched, reuse after commit.
. "$(dirname "$0")/helpers.sh"
w="$scratch/ws"; mkdir -p "$w/.shipinetics/.cache" "$w/docs/worksheets"; cd "$w" || exit 1
for p in api web; do new_repo "$p"; stub_verify "$p/check.sh"; echo a >"$p/a.txt"; git -C "$p" add -A; git -C "$p" commit -qm i; done
printf 'packages = api web\npackage_verify_cmd = sh {package}/check.sh\npackage_verify_quick_cmd = sh {package}/check.sh --quick\n' >.shipinetics/config
printf '*/package.json\n' >.shipinetics/complete-paths
touch .shipinetics/.cache/session-s1
# The worksheet must be newer than the session marker, or the hook sends its once-per-session
# reminder instead of verifying. Linux timestamps are coarse, so the two can tie without a pause.
sleep 1; echo w >docs/worksheets/w.md
echo b >api/a.txt; echo api/a.txt >>.shipinetics/.cache/touched-s1
stop_hook "$w"; has "touched package runs quick" "$(cat .shipinetics/.cache/verify-api.log)" "tier=quick arg=--quick files=a.txt|"
echo b >web/a.txt; rm -f .shipinetics/.cache/verify-web.log; stop_hook "$w"
eq "untouched package isn't verified" "$([ -f .shipinetics/.cache/verify-web.log ] && echo ran || echo skipped)" skipped
echo web/a.txt >>.shipinetics/.cache/touched-s1; echo '{}' >web/package.json; stop_hook "$w"
has "package.json change runs complete" "$(cat .shipinetics/.cache/verify-web.log)" "tier=complete"
git -C api commit -qam s; stop_hook "$w"; eq "committed package reuses" "$(tail -n 2 .shipinetics/.cache/verify-times.tsv | grep -c 'api	quick	0	reused')" 1
done_testing
