#!/usr/bin/env bash
# PreToolUse hook for Bash. Asks the user to confirm before an agent installs a skill, plugin,
# marketplace or MCP server, and reminds them to scan it with SkillSpector first.
# Anything new gets the same permissions as your agents, so a human checks it.
# Active in every project. Start Claude Code with SHIPINETICS_ALLOW_INSTALLS=1 to skip it for a session.

set -uo pipefail

input="$(cat)"
[ "${SHIPINETICS_ALLOW_INSTALLS:-0}" = "1" ] && exit 0

if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
else
  cmd="$(printf '%s' "$input" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))')"
fi

re='(npx|bunx|pnpm[[:space:]]+dlx)[[:space:]]+(-y[[:space:]]+)?skills[[:space:]]+add|claude[[:space:]]+plugin[[:space:]]+(install|marketplace[[:space:]]+add)|claude[[:space:]]+mcp[[:space:]]+add'
[[ "$cmd" =~ $re ]] || exit 0

if command -v skillspector >/dev/null 2>&1; then
  advice="Scan the source first with: skillspector scan <source> --no-llm. Approve only if the result is SAFE, or CAUTION after reading the findings."
else
  advice="SkillSpector isn't installed, so this hasn't been scanned. Install it (uv tool install git+https://github.com/NVIDIA/skillspector.git) and scan the source first, or approve only if you trust it."
fi
reason="shipinetics: this installs new agent tooling that will run with your permissions. $advice See shipinetics:security-scans."

if command -v jq >/dev/null 2>&1; then
  jq -n --arg r "$reason" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $r}}'
else
  python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "ask", "permissionDecisionReason": sys.argv[1]}}))' "$reason"
fi
exit 0
