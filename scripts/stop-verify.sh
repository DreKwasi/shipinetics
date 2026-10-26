#!/usr/bin/env bash
# Stop hook. Keeps the agent working while the project's verify command fails.
#
# Only active in projects with a .shipyard/ folder (here or in a parent folder).
# Single-repo mode: runs verify_cmd (default bin/verify) when the repo has uncommitted changes.
# Workspace mode (packages set in .shipyard/config): runs package_verify_cmd for each package
# repo with uncommitted changes. With verify_scope = touched (the default), only packages the
# agent edited this session count, so the user's own unrelated work never blocks the agent.
# Skips states that already passed, and lets a stuck agent stop with a message to the user.
# Reminds the agent once per session to update its worksheet and feedback log.
# Set SHIPYARD_SKIP_VERIFY=1 in the environment to turn it off for a session.

set -uo pipefail

input="$(cat)"
[ "${SHIPYARD_SKIP_VERIFY:-0}" = "1" ] && exit 0

# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
root="$(sy_root)" || exit 0
cd "$root" || exit 0

cache="$root/.shipyard/.cache"
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

# fingerprint <repo dir> <exclude pathspecs...>: hash of HEAD, diff and untracked files
fingerprint() {
  local repo="$1"; shift
  (
    cd "$repo" || exit 0
    git rev-parse HEAD 2>/dev/null
    git diff HEAD --binary -- . "$@" 2>/dev/null || { git diff --cached --binary; git diff --binary; }
    git ls-files --others --exclude-standard -z -- . "$@" |
      while IFS= read -r -d '' f; do
        printf '%s\n' "$f"
        [ -f "$f" ] && shasum "$f"
      done
  ) | shasum | cut -d' ' -f1
}

reminder_text() { # reminder_text <missing>
  printf 'shipyard: there are uncommitted code changes, but you have not updated %s. If your task is finished, do that before you stop (see the shipyard:worksheet and shipyard:feedback skills). If you are mid-task or waiting on the user, ignore this.' "$1"
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
  printf '%s\n' '{"systemMessage": "shipyard: verify is still failing and the agent stopped without changing anything. Logs are in .shipyard/.cache/."}'
  exit 0
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
    [ -n "$(git -C "$root/$p" status --porcelain --untracked-files=all -- . "${excl[@]}" 2>/dev/null)" ] || continue
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
  failed="" all_same=1
  for p in "${candidates[@]}"; do
    excl=(':(exclude)'"$evidence")
    [ -n "$pkg_ws" ] && excl+=(':(exclude)'"$pkg_ws")
    fp="$(fingerprint "$root/$p" "${excl[@]}")"
    [ "$fp" = "$(cat "$cache/last-pass-${p//\//_}" 2>/dev/null)" ] && continue
    log="$cache/verify-${p//\//_}.log"
    cmd="${verify_tpl//\{package\}/$p}"
    if (cd "$root" && sh -c "$cmd") >"$log" 2>&1; then
      printf '%s' "$fp" >"$cache/last-pass-${p//\//_}"
      rm -f "$cache/last-fail-${p//\//_}"
    else
      [ "$fp" = "$(cat "$cache/last-fail-${p//\//_}" 2>/dev/null)" ] || all_same=0
      printf '%s' "$fp" >"$cache/last-fail-${p//\//_}"
      failed="${failed:+$failed }$p"
    fi
  done
  [ -z "$failed" ] && exit 0
  [ "$stop_active" = "true" ] && [ "$all_same" = 1 ] && stuck_release
  first="${failed%% *}"
  block_with "$cache/verify-${first//\//_}.log" "Verify for $failed (${verify_tpl//\{package\}/<package>})"
fi

# ---------------------------------------------------------------- single-repo mode
verify_cmd="$(sy_cfg "$root" verify_cmd)"
verify_bin="${verify_cmd%% *}"
[ -x "$root/$verify_bin" ] || command -v "$verify_bin" >/dev/null 2>&1 || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

ignore=(':(exclude).shipyard/.cache' ':(exclude)'"$worksheets" ':(exclude)'"$feedback" ':(exclude)'"$evidence")

changed="$(git status --porcelain --untracked-files=all -- . ':(exclude).shipyard/.cache' | cut -c4-)"
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

fp="$(fingerprint "$root" "${ignore[@]}")"
[ "$fp" = "$(cat "$cache/last-pass" 2>/dev/null)" ] && exit 0

log="$cache/verify.log"
if sh -c "$verify_cmd" >"$log" 2>&1; then
  printf '%s' "$fp" >"$cache/last-pass"
  rm -f "$cache/last-fail"
  exit 0
fi
[ "$stop_active" = "true" ] && [ "$fp" = "$(cat "$cache/last-fail" 2>/dev/null)" ] && stuck_release
printf '%s' "$fp" >"$cache/last-fail"
block_with "$log" "$verify_cmd"
