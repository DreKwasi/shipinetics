# Workspace mode: per-package tiers, only packages the agent touched, reuse after commit.
. "$(dirname "$0")/helpers.sh"
w="$scratch/ws"; mkdir -p "$w/.shipyard/.cache" "$w/docs/worksheets"; cd "$w" || exit 1
for p in api web; do new_repo "$p"; stub_verify "$p/check.sh"; echo a >"$p/a.txt"; git -C "$p" add -A; git -C "$p" commit -qm i; done
printf 'packages = api web\npackage_verify_cmd = sh {package}/check.sh\npackage_verify_quick_cmd = sh {package}/check.sh --quick\n' >.shipyard/config
printf '*/package.json\n' >.shipyard/complete-paths
touch .shipyard/.cache/session-s1; echo w >docs/worksheets/w.md
echo b >api/a.txt; echo api/a.txt >>.shipyard/.cache/touched-s1
stop_hook "$w"; has "touched package runs quick" "$(cat .shipyard/.cache/verify-api.log)" "tier=quick arg=--quick files=a.txt|"
echo b >web/a.txt; rm -f .shipyard/.cache/verify-web.log; stop_hook "$w"
eq "untouched package isn't verified" "$([ -f .shipyard/.cache/verify-web.log ] && echo ran || echo skipped)" skipped
echo web/a.txt >>.shipyard/.cache/touched-s1; echo '{}' >web/package.json; stop_hook "$w"
has "package.json change runs complete" "$(cat .shipyard/.cache/verify-web.log)" "tier=complete"
git -C api commit -qam s; stop_hook "$w"; eq "committed package reuses" "$(tail -n 2 .shipyard/.cache/verify-times.tsv | grep -c 'api	quick	0	reused')" 1
done_testing
