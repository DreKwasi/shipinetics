#!/usr/bin/env bash
# Stop hook. Keeps the agent working while the project's checks fail.
#
# Only active in projects with a .shipinetics/ folder (here or in a parent folder).
# Runs when the repo has changes: uncommitted ones, or commits made since the session started.
# Agents commit each step as they go, so a clean tree doesn't mean there's nothing to check.
# Which tier runs (see shipinetics-verify and lib.sh):
#   complete (verify_cmd, default bin/verify) when the worksheet's Status says done or handed off,
#     when a changed file matches .shipinetics/complete-paths (build config, manifests, lockfiles),
#     or when the project has no quick tier.
#   quick (verify_quick_cmd) at every other stop, scoped to the files changed this session.
# A pass is reused while the code's contents stay the same, so committing verified work or
# editing only the worksheet, evidence or feedback log doesn't run anything again.
# Workspace mode (packages set in .shipinetics/config): the same per package repo with changes, using
# package_verify_cmd and package_verify_quick_cmd. With verify_scope = touched (the default), only packages
# the agent edited this session count, so the user's own unrelated work never blocks the agent.
# The session's starting HEAD is recorded per repo in .shipinetics/.cache/head-<session>*.
# Lets a stuck agent stop with a message to the user. Each run's time goes in
# .shipinetics/.cache/verify-times.tsv (shipinetics-verify times summarises it).
# Reminds the agent once per session to update its worksheet and feedback log.
# Set SHIPINETICS_SKIP_VERIFY=1 in the environment to turn it off for a session.

set -uo pipefail

input="$(cat)"
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
sy_flag SKIP_VERIFY && exit 0

root="$(sy_root)" || exit 0
cd "$root" || exit 0

dn="$(sy_dir_name "$root")"
cache="$root/$dn/.cache"
mkdir -p "$cache"

stop_active="$(sy_json_field "$input" stop_hook_active)"
session="$(sy_json_field "$input" session_id)"
worksheets="$(sy_cfg "$root" worksheets_dir)"
feedback="$(sy_cfg "$root" feedback_file)"
evidence="$(sy_cfg "$root" evidence_dir)"

emit_context() {
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg m "$1" '{hookSpecificOutput: {hookEventName: "Stop", additionalContext: $m}}'
  else
    python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput": {"hookEventName": "Stop", "additionalContext": sys.argv[1]}}))' "$1"
  fi
}

# committed_since_start <repo dir> <cache key> <exclude pathspecs...>: files changed by commits
# made since the session started. Records the starting HEAD the first time it sees the session.
# The first Stop can come after the agent has already committed, so that first lookup asks the
# reflog where HEAD was when the session marker was made (guard-edits.sh makes it at the
# session's first edit). With no marker or no reflog, it falls back to the current HEAD.
committed_since_start() {
  local repo="$1" f="$cache/head-$session${2:+-$2}" since start
  shift 2
  if [ ! -f "$f" ]; then
    since="$(date -r "$cache/session-$session" +%s 2>/dev/null)"
    { { [ -n "$since" ] && git -C "$repo" rev-parse -q --verify "HEAD@{@$since +0000}" 2>/dev/null; } ||
      git -C "$repo" rev-parse -q --verify HEAD 2>/dev/null; } >"$f"
  fi
  start="$(cat "$f")"
  [ -n "$start" ] || start="$(git -C "$repo" hash-object -t tree /dev/null)" # no commits yet at start
  git -C "$repo" -c core.quotePath=false diff --name-only --no-renames "$start" HEAD -- . "$@" 2>/dev/null
}

reminder_text() { # reminder_text <missing>
  printf 'shipinetics: there are code changes this session, but you have not updated %s. If your task is finished, do that before you stop (see the shipinetics:worksheet and shipinetics:feedback skills). If you are mid-task or waiting on the user, ignore this.' "$1"
}

block_with() { # block_with <log> <label>
  {
    echo "$2 failed, so you're not done yet. Last 60 lines of its output:"
    echo
    tail -n 60 "$1"
    echo
    echo "Fix the cause, then finish. Don't edit, skip or delete tests, and don't weaken checks, to get a pass."
    echo "If the failure isn't caused by your change, or you can't fix it, write it under Blockers in your worksheet, say so plainly in your final message, and stop without touching any other files."
  } >&2
  exit 2
}

stuck_release() {
  printf '{"systemMessage": "shipinetics: verify is still failing and the agent stopped without changing anything. Logs are in %s/.cache/."}\n' "$dn"
  exit 0
}

# quick_note <what>: tell the user, without blocking, that only the quick tier has run on this code
quick_note() {
  local m="shipinetics: quick checks passed for $1. The complete verify hasn't run on this code yet. It runs at the stop after the worksheet is marked done, before a push or PR, or now with shipinetics-verify."
  if command -v jq >/dev/null 2>&1; then jq -n --arg m "$m" '{systemMessage: $m}'
  else python3 -c 'import json,sys; print(json.dumps({"systemMessage": sys.argv[1]}))' "$m"; fi
  exit 0
}

# pick_tier <list of changed files> <path prefix for the folder's lists> [worksheet paths...]
pick_tier() {
  local list="$1" prefix="$2" f
  shift 2
  if sy_task_done "$root" "$@"; then echo complete; return; fi
  if [ -f "$root/$dn/complete-paths" ]; then
    while IFS= read -r f; do
      [ -n "$f" ] && sy_in_list "$root/$dn/complete-paths" "$prefix$f" && { echo complete; return; }
    done <"$list"
  fi
  echo quick
}

# ---------------------------------------------------------------- workspace mode
if sy_workspace "$root"; then
  [ -n "$session" ] || exit 0
  touched="$cache/touched-$session"
  marker="$cache/session-$session"
  [ -e "$marker" ] || touch "$marker"
  verify_tpl="$(sy_cfg "$root" package_verify_cmd)"
  scope="$(sy_cfg "$root" verify_scope)"
  pkg_ws="$(sy_cfg "$root" package_worksheets_dir)"

  candidates=()
  for p in $(sy_cfg "$root" packages); do
    [ -d "$root/$p/.git" ] || [ -f "$root/$p/.git" ] || continue
    excl=(':(exclude)'"$evidence")
    [ -n "$pkg_ws" ] && excl+=(':(exclude)'"$pkg_ws")
    committed="$(committed_since_start "$root/$p" "${p//\//_}" "${excl[@]}")"
    [ -n "$committed" ] || [ -n "$(git -C "$root/$p" status --porcelain --untracked-files=all -- . "${excl[@]}" 2>/dev/null)" ] || continue
    if [ "$scope" = "touched" ]; then
      [ -f "$touched" ] && grep -q "^$p/" "$touched" || continue
    fi
    candidates+=("$p")
  done
  [ "${#candidates[@]}" -gt 0 ] || exit 0

  # Once per session: worksheet and feedback reminder, judged by modification time.
  reminded="$cache/reminded-$session"
  if [ "$stop_active" != "true" ] && [ ! -e "$reminded" ]; then
    missing=""
    if [ -d "$root/$worksheets" ] && [ -z "$(find "$root/$worksheets" -type f -newer "$marker" 2>/dev/null | head -n 1)" ]; then
      missing="your worksheet ($worksheets/)"
    fi
    if [ -f "$root/$feedback" ] && [ ! "$root/$feedback" -nt "$marker" ]; then
      missing="${missing:+$missing or }the feedback log ($feedback)"
    fi
    if [ -n "$missing" ]; then
      touch "$reminded"
      emit_context "$(reminder_text "$missing")"
      exit 0
    fi
  fi

  [ -n "$verify_tpl" ] || exit 0
  failed="" all_same=1 quick_only=""
  for p in "${candidates[@]}"; do
    sfx="$(sy_key_suffix "$p")"
    list="$cache/changed-$session$sfx"
    {
      committed_since_start "$root/$p" "${p//\//_}"
      sy_changed_paths "$root/$p"
    } | sed '/^$/d' | sort -u >"$list"
    tier="$(pick_tier "$list" "$p/")"
    if sy_verify_run "$root" "$p" "$tier" "$list" stop; then
      [ "$SY_VERIFY_RAN" = 1 ] && [ "$SY_VERIFY_TIER" = quick ] && quick_only="${quick_only:+$quick_only, }$p"
    else
      [ -n "$SY_VERIFY_FP" ] && [ "$SY_VERIFY_FP" = "$(cat "$cache/last-fail$sfx" 2>/dev/null)" ] || all_same=0
      printf '%s' "$SY_VERIFY_FP" >"$cache/last-fail$sfx"
      failed="${failed:+$failed }$p"
    fi
  done
  if [ -z "$failed" ]; then
    [ -n "$quick_only" ] && quick_note "$quick_only"
    exit 0
  fi
  [ "$stop_active" = "true" ] && [ "$all_same" = 1 ] && stuck_release
  first="${failed%% *}"
  block_with "$cache/verify$(sy_key_suffix "$first").log" "Verify for $failed"
fi

# ---------------------------------------------------------------- single-repo mode
verify_cmd="$(sy_cfg "$root" verify_cmd)"
verify_bin="${verify_cmd%% *}"
[ -x "$root/$verify_bin" ] || command -v "$verify_bin" >/dev/null 2>&1 || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

changed="$(sy_changed_paths "$root" | grep -v "^$dn/\.cache/" || true)"
if [ -n "$session" ]; then
  changed="$(printf '%s\n' "$changed" "$(committed_since_start "$root" "" ":(exclude)$dn/.cache")" | sed '/^$/d')"
fi
[ -z "$changed" ] && exit 0

reminded="$cache/reminded-${session:-none}"
code_changed="$(printf '%s\n' "$changed" | grep -v -e "^$worksheets/" -e "^$feedback\$" -e "^$evidence/" || true)"
if [ "$stop_active" != "true" ] && [ -n "$session" ] && [ -n "$code_changed" ] && [ ! -e "$reminded" ]; then
  missing=""
  if [ -d "$worksheets" ] && ! printf '%s\n' "$changed" | grep -q "^$worksheets/"; then
    missing="your worksheet ($worksheets/)"
  fi
  if [ -f "$feedback" ] && ! printf '%s\n' "$changed" | grep -qx "$feedback"; then
    missing="${missing:+$missing or }the feedback log ($feedback)"
  fi
  if [ -n "$missing" ]; then
    touch "$reminded"
    emit_context "$(reminder_text "$missing")"
    exit 0
  fi
fi

list="$cache/changed-${session:-none}"
printf '%s\n' "$code_changed" | sed '/^$/d' | sort -u >"$list"
ws_changed="$(printf '%s\n' "$changed" | grep "^$worksheets/.*\.md$" || true)"
if [ ! -s "$list" ]; then
  # Only records changed this session. Nothing to check, unless the task was just marked done
  # and the complete tier hasn't passed on this code (a resumed session that only wraps up).
  # shellcheck disable=SC2086  # worksheet paths, one per word
  sy_task_done "$root" $ws_changed && ! sy_verify_passed "$root" "" complete || exit 0
  list=""
fi
# shellcheck disable=SC2086
tier="$(if [ -z "$list" ]; then echo complete; else pick_tier "$list" "" $ws_changed; fi)"
if sy_verify_run "$root" "" "$tier" "$list" stop; then
  [ "$SY_VERIFY_RAN" = 1 ] && [ "$SY_VERIFY_TIER" = quick ] && quick_note "this session's changes"
  exit 0
fi
[ "$stop_active" = "true" ] && [ -n "$SY_VERIFY_FP" ] && [ "$SY_VERIFY_FP" = "$(cat "$cache/last-fail" 2>/dev/null)" ] && stuck_release
printf '%s' "$SY_VERIFY_FP" >"$cache/last-fail"
block_with "$SY_VERIFY_LOG" "$(sy_verify_cmd "$root" "$SY_VERIFY_TIER" "")"
