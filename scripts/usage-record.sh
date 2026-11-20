#!/usr/bin/env bash
# SessionEnd hook. Records the tokens that the session used (subagents included) in the usage log,
# from the session's transcript. No model runs, so it costs nothing. The work goes on in the
# background, because Claude Code gives SessionEnd hooks 1.5 seconds. Runs in every project.
# Switch it off with "hooks_off = usage", or SHIPINETICS_HOOKS_OFF=usage. See bin/shipinetics-usage.

set -uo pipefail

input="$(cat)"
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
cwd="$(sy_hook_cwd "$input")"
root="$(sy_root "$cwd" 2>/dev/null)" || root=""
sy_hook_off usage "$root" && exit 0
command -v python3 >/dev/null 2>&1 || exit 0
transcript="$(sy_json_field "$input" transcript_path)"
[ -n "$transcript" ] || transcript="$(sy_json_field "$input" transcriptPath)"
[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0
conv_id="$(sy_json_field "$input" conversationId)"
args=(record "$transcript" --detach)
[ -n "$cwd" ] && args+=(--cwd "$cwd")
[ -n "$conv_id" ] && args+=(--session-id "$conv_id")
python3 -I "$(dirname "$0")/usage.py" "${args[@]}" >/dev/null 2>&1
exit 0
