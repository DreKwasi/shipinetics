#!/usr/bin/env bash
# Stop hook. Keeps the agent working while the project's verify command fails.
#
# Only active in projects that have a .shipyard/ directory and an executable bin/verify,
# so it does nothing in repos that haven't been set up.
# Skips when nothing is uncommitted, and when nothing changed since the last passing run.
# Reminds the agent once per session to update its worksheet and leave feedback.
# Set SHIPYARD_SKIP_VERIFY=1 in the environment to turn it off for a session.

set -uo pipefail

input="$(cat)"
[ "${SHIPYARD_SKIP_VERIFY:-0}" = "1" ] && exit 0

root="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$root" 2>/dev/null || exit 0
[ -d .shipyard ] || exit 0
[ -x bin/verify ] || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

cache=.shipyard/.cache
mkdir -p "$cache"

# Paths that never affect verify: the hook's own cache, worksheets, the feedback log and evidence.
# Leaving them out means writing up a blocker doesn't trigger another verify run.
ignore=(':(exclude).shipyard/.cache' ':(exclude)docs/worksheets' ':(exclude)docs/agent-feedback.md' ':(exclude)docs/evidence')

json_field() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r --arg k "$1" '.[$k] // empty'
  else
    printf '%s' "$input" | python3 -c 'import json,sys
v = json.load(sys.stdin).get(sys.argv[1])
print("" if v is None else (str(v).lower() if isinstance(v, bool) else v))' "$1"
  fi
}

emit_context() {
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg m "$1" '{hookSpecificOutput: {hookEventName: "Stop", additionalContext: $m}}'
  else
    python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput": {"hookEventName": "Stop", "additionalContext": sys.argv[1]}}))' "$1"
  fi
}

fingerprint() {
  {
    git rev-parse HEAD 2>/dev/null
    git diff HEAD --binary -- . "${ignore[@]}" 2>/dev/null || { git diff --cached --binary; git diff --binary; }
    git ls-files --others --exclude-standard -z -- . "${ignore[@]}" |
      while IFS= read -r -d '' f; do
        printf '%s\n' "$f"
        [ -f "$f" ] && shasum "$f"
      done
  } | shasum | cut -d' ' -f1
}

stop_active="$(json_field stop_hook_active)"
session="$(json_field session_id)"

changed="$(git status --porcelain --untracked-files=all -- . ':(exclude).shipyard/.cache' | cut -c4-)"
[ -z "$changed" ] && exit 0

# Once per session: nudge toward the worksheet and feedback log when code changed but they didn't.
reminded="$cache/reminded-${session:-none}"
code_changed="$(printf '%s\n' "$changed" | grep -v -e '^docs/worksheets/' -e '^docs/agent-feedback.md$' || true)"
if [ "$stop_active" != "true" ] && [ -n "$session" ] && [ -n "$code_changed" ] && [ ! -e "$reminded" ]; then
  missing=""
  if [ -d docs/worksheets ] && ! printf '%s\n' "$changed" | grep -q '^docs/worksheets/'; then
    missing="your worksheet (docs/worksheets/)"
  fi
  if [ -f docs/agent-feedback.md ] && ! printf '%s\n' "$changed" | grep -qx 'docs/agent-feedback.md'; then
    missing="${missing:+$missing or }the feedback log (docs/agent-feedback.md)"
  fi
  if [ -n "$missing" ]; then
    touch "$reminded"
    emit_context "shipyard: there are uncommitted code changes, but you haven't updated $missing. If your task is finished, do that before you stop (see the shipyard:worksheet and shipyard:feedback skills). If you're mid-task or waiting on the user, ignore this."
    exit 0
  fi
fi

fp="$(fingerprint)"
[ "$fp" = "$(cat "$cache/last-pass" 2>/dev/null)" ] && exit 0

log="$cache/verify.log"
if bin/verify >"$log" 2>&1; then
  printf '%s' "$fp" >"$cache/last-pass"
  rm -f "$cache/last-fail"
  exit 0
fi

# Same failure as last time and the agent changed nothing: it's stuck. Let it stop and tell the user.
if [ "$stop_active" = "true" ] && [ "$fp" = "$(cat "$cache/last-fail" 2>/dev/null)" ]; then
  printf '%s\n' '{"systemMessage": "shipyard: bin/verify is still failing and the agent stopped without changing anything. Log: .shipyard/.cache/verify.log"}'
  exit 0
fi
printf '%s' "$fp" >"$cache/last-fail"

{
  echo "bin/verify failed, so you're not done yet. Last 60 lines of its output:"
  echo
  tail -n 60 "$log"
  echo
  echo "Fix the cause, then finish. Don't edit, skip or delete tests, and don't weaken checks, to get a pass."
  echo "If the failure isn't caused by your change, or you can't fix it, write it under Blockers in your worksheet, say so plainly in your final message, and stop without touching any other files."
} >&2
exit 2
