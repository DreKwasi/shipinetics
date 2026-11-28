#!/usr/bin/env bash
# PostToolUse hook for Bash. After a command that runs `git commit`, it runs the quick verify
# (shipinetics-verify quick) on the repo the commit went to, and tells the agent the result.
# It never blocks: the commit has happened, and a failing test can be expected mid-task (the tests
# of changed behaviour fail until test-writer updates them). The complete verify stays the gate,
# before push and before PR.
#
# Runs only in a set-up project with a quick tier (verify_quick_cmd, or package_verify_quick_cmd in
# workspace mode): without one, quick would run the complete tier, which takes minutes.
# Says nothing when a pass is already recorded for this exact code, so it reports once per change.
# Switch it off with "hooks_off = verify", or SHIPINETICS_HOOKS_OFF=verify for a session.

set -uo pipefail

input="$(cat)"
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
here="$(cd "$(dirname "$0")/.." && pwd)"
harness="$(sy_hook_harness "$input")"
[ "$harness" = claude ] || exit 0

cmd="$(sy_hook_command "$input")"
[ -n "$cmd" ] || exit 0
# Judge only text that can run, so a commit message or a search that names `git commit` doesn't
# count. If perl is missing, judge all of it: a run too many costs seconds, not a wrong result.
run="$(printf '%s' "$cmd" | sy_sanitize gate "")" || run="$cmd"
re='(^|[^[:alnum:]_.-])git([[:space:]]+(-C|-c)[[:space:]]+[^[:space:]]+|[[:space:]]+--no-pager)*[[:space:]]+commit([^[:alnum:]_-]|$)'
[[ "$run" =~ $re ]] || exit 0

cwd="$(sy_hook_cwd "$input")"
# A leading "cd <dir> &&", or "git -C <dir> commit", decides which repo the commit went to.
cd_re='^[[:space:]]*cd[[:space:]]+([^[:space:];&|]+)[[:space:]]*&&'
gitc_re='git[[:space:]]+-C[[:space:]]+([^[:space:];&|]+)[[:space:]]+([^;&|]*[[:space:]])?commit([^[:alnum:]_-]|$)'
d=""
# Match the runnable text, so a commit message that names "git -C x commit" can't move the check.
if [[ "$run" =~ $cd_re ]]; then d="${BASH_REMATCH[1]}"; elif [[ "$run" =~ $gitc_re ]]; then d="${BASH_REMATCH[1]}"; fi
if [ -n "$d" ]; then
  d="${d/#\~/$HOME}"; d="${d%\"}"; d="${d#\"}"; d="${d%\'}"; d="${d#\'}"; d="$(sy_unix_path "$d")"
  case "$d" in /*) ;; *) d="$cwd/$d" ;; esac
  [ -d "$d" ] && cwd="$d"
fi
repo="$(sy_git_top "$cwd")" || exit 0
root="$(sy_root "$repo")" || exit 0
sy_hook_off verify "$root" && exit 0
pkg=""
if [ "$root" != "$repo" ]; then
  pkg="$(sy_rel "$root" "$repo")"
  sy_workspace "$root" && sy_package_of "$root" "$pkg" >/dev/null || exit 0
fi
sy_verify_configured "$root" "$pkg" || exit 0
sy_has_quick "$root" "$pkg" || exit 0
# A refused or failed commit leaves HEAD where it was. Run only when HEAD was committed in the last
# 10 minutes (a slow pre-commit hook can take a while). After a refused commit that follows a recent
# one, it still runs, on the uncommitted code: that costs seconds, and the result is still true.
ct="$(git -C "$repo" log -1 --format=%ct 2>/dev/null)" || exit 0
[ -n "$ct" ] && [ $(( $(date +%s) - ct )) -le 600 ] || exit 0

out="$(cd "$repo" && SHIPINETICS_VERIFY_SOURCE=commit "$here/bin/shipinetics-verify" quick 2>&1)"
rc=$?
case "$out" in *"already passed on this exact code"*) exit 0 ;; esac
log="$(sy_dir "$root")/.cache/verify$(sy_key_suffix "$pkg").log"
# shipinetics-verify ends a run of the check with "<tier> failed (exit N)". Without that line, the
# wrapper itself refused (no repo, no config). The exit code alone can't tell: make and many test
# runners exit 2 on a failed test.
if [ "$rc" = 0 ]; then
  sy_hook_posttool_context "$harness" "shipinetics: the quick verify passed after this commit (recorded for this code)."
elif ! printf '%s' "$out" | grep -q '^shipinetics-verify: [a-z]* failed (exit'; then
  sy_hook_posttool_context "$harness" "shipinetics: the quick verify after this commit could not run: $(printf '%s' "$out" | tail -n 3 | tail -c 1000)"
else
  sy_hook_posttool_context "$harness" "shipinetics: the quick verify FAILED after this commit (exit $rc). The commit stays. Last lines of the output (full output: $log):
$(printf '%s\n' "$out" | tail -n 40 | tail -c 4000)

What to do: if a failure is in a test of behaviour that this task changed or removed, and test-writer hasn't updated the tests yet, that is expected. Any other failure is yours to fix in the next step. A test that fails and then passes on a re-run is flaky, which is still a failure (shipinetics:testing). Don't re-run verify to get a pass."
fi
exit 0
