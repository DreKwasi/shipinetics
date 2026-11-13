#!/usr/bin/env bash
# PreToolUse hook for Bash. Asks the user to confirm before an agent installs or updates a skill,
# plugin, marketplace or MCP server, and reminds them to scan it with SkillSpector first.
# Anything new, and any new version, gets the same permissions as your agents, so a human checks it.
# Active in every project. Start Claude Code with SHIPINETICS_ALLOW_INSTALLS=1 to skip it for a session,
# or switch it off with "hooks_off = installs" in the project or user config.

set -uo pipefail

input="$(cat)"
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
sy_flag ALLOW_INSTALLS && exit 0
sy_hook_off installs "$(sy_root 2>/dev/null)" && exit 0

if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
else
  cmd="$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))')"
fi

# Installs and updates: an update pulls new code too. `skills check` counts: it can update and
# remove skills while it checks. bin/skills-outdated is the read-only check.
re='(npx|bunx|pnpm[[:space:]]+dlx)[[:space:]]+(-y[[:space:]]+)?skills[[:space:]]+(add|update|check)|claude[[:space:]]+plugin[[:space:]]+(install|update|marketplace[[:space:]]+(add|update))|claude[[:space:]]+mcp[[:space:]]+add'
# Judge only text that can run: an inert heredoc body, a commit message, a search pattern or a
# comment line can name an install without running it. If perl is missing, judge all of it.
run="$(printf '%s' "$cmd" | sy_sanitize gate "")" || run="$cmd"
[[ "$run" =~ $re ]] || exit 0

if command -v skillspector >/dev/null 2>&1; then
  advice="Scan the source first with: skillspector scan <source> --no-llm. Approve only if the result is SAFE, or CAUTION after reading the findings."
else
  advice="SkillSpector isn't installed, so this hasn't been scanned. Install it (uv tool install git+https://github.com/NVIDIA/skillspector.git) and scan the source first, or approve only if you trust it."
fi
reason="shipinetics: this installs or updates agent tooling that will run with your permissions. $advice For a Shipinetics companion, shipinetics-companions shows the result recorded for the scanned version. Three companions (security-audit, Impeccable, tasteskill) score DO_NOT_INSTALL in static mode, and their findings were checked by hand as false positives. See shipinetics:security-scans."

if command -v jq >/dev/null 2>&1; then
  jq -n --arg r "$reason" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $r}}'
else
  python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "ask", "permissionDecisionReason": sys.argv[1]}}))' "$reason"
fi
exit 0
