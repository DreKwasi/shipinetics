#!/usr/bin/env bash
# PreToolUse hook for Bash. Blocks `gh pr create` and `gh pr ready` until the branch has
# complete evidence (a recording, or terminal transcripts, for every acceptance
# criterion; see shipinetics:evidence), the complete verify has passed on exactly this code
# (shipinetics-verify), and the PR body carries the "## Evidence" section.
#
# Works from the repo the command runs in, so in workspace mode it checks the package repo.
# Active only when a .shipinetics/ folder exists at or above that repo. Docs-only branches pass.
# Start Claude Code with SHIPINETICS_ALLOW_NO_EVIDENCE=1 to skip the whole gate for a session
# (evidence and verify), or SHIPINETICS_SKIP_VERIFY=1 to skip only the verify check. Switch it off
# for a project with "hooks_off = pr" in its config.

set -uo pipefail

input="$(cat)"
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
harness="$(sy_hook_harness "$input")"
noop() { sy_hook_noop "$harness"; exit 0; }
sy_flag ALLOW_NO_EVIDENCE && noop

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
  d="${BASH_REMATCH[1]}"; d="${d/#\~/$HOME}"
  case "$d" in /*) ;; *) d="$cwd/$d" ;; esac
  [ -d "$d" ] && cwd="$d"
fi
repo="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)" || noop
root="$(sy_root "$repo")" || noop
sy_hook_off pr "$root" && noop

deny() { sy_hook_pretool_reply "$harness" deny "$1"; exit 0; }

evidence="$(cd "$(dirname "$0")/.." && pwd)/bin/evidence"
guide="$(cd "$(dirname "$0")/.." && pwd)/skills/explain/plain-language.md"
if ! out="$(cd "$repo" && SHIPINETICS_ROOT="$root" "$evidence" check --branch 2>&1)"; then
  deny "shipinetics: this PR has no complete evidence yet, so it can't be opened.
$out
Capture it (shipinetics:evidence): one paced recording of the flow for UI changes, with the time of each acceptance criterion (screenshots only if it can't be recorded), terminal transcripts for CLIs and APIs. Then build the PR body with: evidence pr-body > \$TMPDIR/pr-body.md, and pass --body-file \$TMPDIR/pr-body.md (add your summary above the Evidence section). Write the summary by the plain-language guide: $guide."
fi
case "$out" in *docs-only*) noop ;; esac

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

# The body must carry the Evidence section.
body=""
file_re='(--body-file|-F)[[:space:]=]+([^[:space:]]+)'
text_re='(--body|-b)[[:space:]=]+'
if [[ "$cmd" =~ $file_re ]]; then
  f="${BASH_REMATCH[2]}"; f="${f%\"}"; f="${f#\"}"; f="${f%\'}"; f="${f#\'}"
  # Expand only the variables a body file path usually uses. Never eval: this runs before permissions.
  f="${f/#\~/$HOME}"; f="${f//\$\{TMPDIR\}/${TMPDIR:-/tmp}}"; f="${f//\$TMPDIR/${TMPDIR:-/tmp}}"
  case "$f" in /*) ;; *) f="$cwd/$f" ;; esac
  [ -f "$f" ] && body="$(cat "$f")"
elif [[ "$cmd" =~ $text_re ]]; then
  body="$cmd"
fi
if ! printf '%s' "$body" | grep -q '## Evidence'; then
  deny "shipinetics: the PR body needs the '## Evidence' section. Generate it with: evidence pr-body > \$TMPDIR/pr-body.md, put your summary above it, and pass --body-file \$TMPDIR/pr-body.md. Write the summary by the plain-language guide: $guide. Don't use --fill."
fi

noop
