#!/usr/bin/env bash
# SessionStart hook (new sessions only). Tells the user which Shipinetics companions are missing on
# this machine, why Shipinetics uses each one, and its SkillSpector result. It also gives Claude the
# same list, so Claude can offer the install command when a task needs a missing companion.
# It runs in every project, so the user sees the list from the first session after the install.
# Quiet when every required companion is installed or declined (companions_skip in the project or
# user config). Missing optional companions are listed only together with a missing required one, so
# the notice doesn't come back in every session for an optional tool.
# Switch it off with "hooks_off = companions", or SHIPINETICS_HOOKS_OFF=companions.

set -uo pipefail

cat >/dev/null
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
root="$(sy_root 2>/dev/null)" || root=""
sy_hook_off companions "$root" && exit 0
file="$(sy_companions_file)"
[ -f "$file" ] || exit 0
project="${CLAUDE_PROJECT_DIR:-$PWD}"

n=0 req=0 lines="" names=""
while IFS=$'\t' read -r name kind id level why install scan; do
  case "$name" in ''|'#'*) continue ;; esac
  sy_companion_installed "$kind" "$id" "$project" && continue
  sy_companion_declined "$name" "$id" "$root" && continue
  n=$((n + 1))
  [ "$level" = required ] && req=$((req + 1))
  tag=""; [ "$level" = optional ] && tag=" (optional)"
  lines="$lines
- $name$tag: $why
  SkillSpector: $scan
  Install: $install"
  names="$names${names:+, }$name"
done <"$file"
[ "$req" -gt 0 ] || exit 0

if [ "$n" = 1 ]; then head="1 Shipinetics companion is missing."; else head="$n Shipinetics companions are missing."; fi
msg="$head Shipinetics works without them, but the steps that use them are weaker or skipped.$lines

Scan each one with SkillSpector before you install it. To see the list again: shipinetics-companions. To stop this notice for a companion that you don't want, add its name to companions_skip in ~/.config/shipinetics/config."
ctx="Shipinetics companions that are missing on this machine: $names. The user saw this list at session start: $lines
When a task needs one of these companions, or the user asks about them, say why Shipinetics uses it, give its SkillSpector result and its install command, and offer a route without it. Never install one without the user's yes. The install gate also asks the user."

if command -v jq >/dev/null 2>&1; then
  jq -n --arg m "$msg" --arg c "$ctx" '{systemMessage: $m, hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'
else
  python3 -c 'import json,sys; print(json.dumps({"systemMessage": sys.argv[1], "hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": sys.argv[2]}}))' "$msg" "$ctx"
fi
exit 0
