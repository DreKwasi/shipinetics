#!/usr/bin/env bash
# SessionEnd hook. Records the tokens that the session used (subagents included) in the usage log,
# from the session's transcript. No model runs, so it costs nothing. The work goes on in the
# background, because Claude Code gives SessionEnd hooks 1.5 seconds. Runs in every project.
# Switch it off with "hooks_off = usage", or SHIPINETICS_HOOKS_OFF=usage. See bin/shipinetics-usage.

set -uo pipefail

input="$(cat)"
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
root="$(sy_root 2>/dev/null)" || root=""
sy_hook_off usage "$root" && exit 0
command -v python3 >/dev/null 2>&1 || exit 0
transcript="$(sy_json_field "$input" transcript_path)"
[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0
python3 "$(dirname "$0")/usage.py" record "$transcript" --detach >/dev/null 2>&1
exit 0
