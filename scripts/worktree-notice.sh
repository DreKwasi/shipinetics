#!/usr/bin/env bash
# SessionStart hook. When the session starts in a git worktree where Shipinetics can't find the
# project's settings, it says why and what to do (sy_wt_hint): a workspace package worktree outside
# the workspace folder, or a worktree whose main checkout isn't reachable, as in a container that
# mounts only the worktree. Without the settings, no Shipinetics guard runs there.
# In any other case it says nothing. A worktree of a set-up repo needs no notice: the first
# Shipinetics call there copies the main checkout's settings into it (sy_root).
# Switch it off with "hooks_off = worktrees", or SHIPINETICS_HOOKS_OFF=worktrees.

set -uo pipefail

input="$(cat)"
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
harness="$(sy_hook_harness "$input")"
noop() { sy_hook_noop "$harness"; exit 0; }
cwd="$(sy_hook_cwd "$input")"
sy_hook_off worktrees && noop
sy_root "$cwd" >/dev/null 2>&1 && noop
hint="$(sy_wt_hint "$cwd")" || noop

msg="Shipinetics is off in this session. $hint"
ctx="Shipinetics found no project settings for this session's folder, so its guards, worksheets and verify don't apply here. The user saw this at session start: $hint
Tell the user once if they ask you to use a Shipinetics tool here."
sy_hook_session_start_reply "$harness" "$msg" "$ctx"
exit 0
