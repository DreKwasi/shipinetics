#!/usr/bin/env bash
# PreToolUse hook for Bash. Blocks `gh pr create` and `gh pr ready` until the branch has
# complete evidence (screenshots, recordings or terminal transcripts for every acceptance
# criterion; see shipyard:evidence) and the PR body carries the "## Evidence" section.
#
# Active only in set-up projects (a .shipyard/ folder). Docs-only branches pass.
# Start Claude Code with SHIPYARD_ALLOW_NO_EVIDENCE=1 to skip it for a session.

set -uo pipefail

input="$(cat)"
[ "${SHIPYARD_ALLOW_NO_EVIDENCE:-0}" = "1" ] && exit 0
root="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -d "$root/.shipyard" ] || exit 0

if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
else
  cmd="$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))')"
fi
re='gh[[:space:]]+pr[[:space:]]+(create|ready)([[:space:]]|$)'
[[ "$cmd" =~ $re ]] || exit 0

deny() {
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  else
    python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": sys.argv[1]}}))' "$1"
  fi
  exit 0
}

evidence="$(cd "$(dirname "$0")/.." && pwd)/bin/evidence"
if ! out="$(cd "$root" && "$evidence" check --branch 2>&1)"; then
  deny "shipyard: this PR has no complete evidence yet, so it can't be opened.
$out
Capture it (shipyard:evidence): screenshots per acceptance criterion, a screen recording for UI changes, terminal transcripts for CLIs and APIs. Then build the PR body with: evidence pr-body > \$TMPDIR/pr-body.md, and pass --body-file \$TMPDIR/pr-body.md (add your summary above the Evidence section)."
fi
case "$out" in *docs-only*) exit 0 ;; esac

# The body must carry the Evidence section.
body=""
file_re='(--body-file|-F)[[:space:]=]+([^[:space:]]+)'
text_re='(--body|-b)[[:space:]=]+'
if [[ "$cmd" =~ $file_re ]]; then
  f="${BASH_REMATCH[2]}"; f="${f%\"}"; f="${f#\"}"; f="${f%\'}"; f="${f#\'}"
  # Expand only the variables a body file path usually uses. Never eval: this runs before permissions.
  f="${f/#\~/$HOME}"; f="${f//\$\{TMPDIR\}/${TMPDIR:-/tmp}}"; f="${f//\$TMPDIR/${TMPDIR:-/tmp}}"
  case "$f" in /*) ;; *) f="$root/$f" ;; esac
  [ -f "$f" ] && body="$(cat "$f")"
elif [[ "$cmd" =~ $text_re ]]; then
  body="$cmd"
fi
if ! printf '%s' "$body" | grep -q '## Evidence'; then
  deny "shipyard: the PR body needs the '## Evidence' section. Generate it with: evidence pr-body > \$TMPDIR/pr-body.md, put your summary above it, and pass --body-file \$TMPDIR/pr-body.md. Don't use --fill."
fi

exit 0
