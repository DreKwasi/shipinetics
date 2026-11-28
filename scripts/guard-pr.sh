#!/usr/bin/env bash
# PreToolUse hook for Bash. Blocks `gh pr create` and `gh pr ready` until the complete verify has
# passed on exactly this code (shipinetics-verify). It doesn't ask for evidence: evidence is
# recorded only when the user asks for it (shipinetics:evidence).
#
# Works from the repo the command runs in, so in workspace mode it checks the package repo.
# Active only when a .shipinetics/ folder exists at or above that repo. A branch that changes
# only docs and Markdown passes with no verify.
# Start Claude Code with SHIPINETICS_SKIP_VERIFY=1 (or its old name, SHIPINETICS_ALLOW_NO_EVIDENCE=1)
# to skip the gate for a session. Switch it off for a project with "hooks_off = pr" in its config.

set -uo pipefail

input="$(cat)"
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
harness="$(sy_hook_harness "$input")"
noop() { sy_hook_noop "$harness"; exit 0; }
sy_flag ALLOW_NO_EVIDENCE && noop   # the old name of SKIP_VERIFY for this gate
sy_flag SKIP_VERIFY && noop

cmd="$(sy_hook_command "$input")"
# Judge only text that can run: an inert heredoc body, a commit message, a search pattern or a
# comment line can name the command without running it. If perl is missing, judge all of it.
run="$(printf '%s' "$cmd" | sy_sanitize gate "")" || run="$cmd"
re='(^|[^[:alnum:]_.-])gh[[:space:]]+pr[[:space:]]+(create|ready)([^[:alnum:]_-]|$)'
[[ "$run" =~ $re ]] || noop

cwd="$(sy_hook_cwd "$input")"
# A leading "cd <dir> &&" decides where gh runs. Follow it when it's a plain path.
cd_re='^[[:space:]]*cd[[:space:]]+([^[:space:];&|]+)[[:space:]]*&&'
if [[ "$cmd" =~ $cd_re ]]; then
  d="${BASH_REMATCH[1]}"; d="${d/#\~/$HOME}"; d="$(sy_unix_path "$d")"
  case "$d" in /*) ;; *) d="$cwd/$d" ;; esac
  [ -d "$d" ] && cwd="$d"
fi
repo="$(sy_git_top "$cwd")" || noop
root="$(sy_root "$repo")" || noop
sy_hook_off pr "$root" && noop

deny() { sy_hook_pretool_reply "$harness" deny "$1"; exit 0; }

# Docs only: nothing to verify.
base=""
for b in origin/main main origin/master master; do
  if git -C "$repo" rev-parse -q --verify "$b" >/dev/null; then base="$(git -C "$repo" merge-base HEAD "$b" 2>/dev/null)"; break; fi
done
changed="$(sy_changed_paths "$repo" "$base")"
if [ -n "$changed" ] && ! printf '%s\n' "$changed" | grep -vqE '^docs/|\.md$'; then noop; fi

# The complete verify must have passed on exactly this code. The agent may only have run the
# quick tier, so this is where the complete tier is guaranteed. A recorded pass is reused, so
# this costs nothing when the agent already ran it.
# A repo under the root that isn't one of the workspace's packages has no verify command of its
# own, so there's nothing to require.
pkg=""; [ "$root" != "$repo" ] && pkg="$(sy_rel "$root" "$repo")"
enrolled=1
if [ -n "$pkg" ]; then sy_workspace "$root" && sy_package_of "$root" "$pkg" >/dev/null || enrolled=0; fi
if ! sy_flag SKIP_VERIFY && [ "$enrolled" = 1 ] && sy_verify_configured "$root" "$pkg" &&
   ! sy_verify_passed "$root" "$pkg" complete; then
  deny "shipinetics: the complete verify hasn't passed on this exact code, so the PR can't open yet. Run shipinetics-verify (it runs $(sy_verify_cmd "$root" complete "$pkg") and records the pass), fix anything that fails, then open the PR again."
fi

noop
