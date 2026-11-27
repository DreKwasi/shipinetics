#!/usr/bin/env bash
# SessionStart hook (new sessions only). Tells the user which Shipinetics companions are missing on
# this machine, why Shipinetics uses each one, and its SkillSpector result. It also gives Claude the
# same list, so Claude can offer the install command when a task needs a missing companion.
# In a set-up project it runs in each new session. Elsewhere it shows the list at most once in 7 days
# (a timestamp in ${XDG_CACHE_HOME:-~/.cache}/shipinetics/), so the user sees it soon after the install.
# Quiet when every recommended companion is installed or declined (companions_skip in the project or
# user config). Missing optional companions are listed only together with a missing recommended one, so
# the notice doesn't come back in every session for an optional tool.
# Two more warnings show in any project, whatever the companions: no JSON parser (jq or python3), so
# the guards can't read their input, and a set-up project that names a newer Shipinetics version than
# the installed plugin.
# Switch it off with "hooks_off = companions", or SHIPINETICS_HOOKS_OFF=companions.

set -uo pipefail

input="$(cat)"
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
harness="$(sy_hook_harness "$input")"
noop() { sy_hook_noop "$harness"; exit 0; }
project="$(sy_hook_cwd "$input")"
root="$(sy_root "$project" 2>/dev/null)" || root=""
sy_hook_off companions "$root" && noop
file="$(sy_companions_file)"

# Warnings that don't depend on the companions.
warn=""
# A parser must really run: on a new Mac, /usr/bin/python3 can be a stub that only asks to install tools.
if ! jq -n 1 >/dev/null 2>&1 && ! python3 -c 'import json' >/dev/null 2>&1; then
  warn="$warn
- Neither jq nor python3 runs on this machine. The Shipinetics guards read their input with one of them, so without both they let every action through. Install python3 (or jq)."
fi
# vnum <x.y.z>: a number that sorts like the version (each part up to 999)
vnum() {
  local a b c x
  IFS=. read -r a b c x <<<"$1"
  case "${a:-0}${b:-0}${c:-0}" in *[!0-9]*) echo 0; return ;; esac
  echo "$(( 10#${a:-0} * 1000000 + 10#${b:-0} * 1000 + 10#${c:-0} ))"
}
if [ -n "$root" ] && [ -f "$root/AGENTS.md" ]; then
  pv="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([0-9][0-9.]*\)".*/\1/p' "$(dirname "$file")/.claude-plugin/plugin.json" 2>/dev/null | head -n 1)"
  jv="$(sed -n 's/.*shipinetics:begin version=\([0-9][0-9.]*[0-9]\).*/\1/p' "$root/AGENTS.md" | head -n 1)"
  if [ -n "$pv" ] && [ -n "$jv" ] && [ "$(vnum "$jv")" -gt "$(vnum "$pv")" ]; then
    warn="$warn
- This project was set up with Shipinetics $jv, but this machine has $pv. Some skills and hooks may not match the project's files. Update the plugin (shipinetics-update says how)."
  fi
fi

[ -f "$file" ] || file=/dev/null
n=0 req=0 lines="" names=""
while IFS=$'\t' read -r name kind id level why install scan; do
  case "$name" in ''|'#'*) continue ;; esac
  sy_companion_installed "$kind" "$id" "$project" && continue
  sy_companion_declined "$name" "$id" "$root" && continue
  n=$((n + 1))
  case "$level" in required|recommended) req=$((req + 1)) ;; esac
  tag=""; [ "$level" = optional ] && tag=" (optional)"
  lines="$lines
- $name$tag: $why
  SkillSpector: $scan
  Install: $install"
  names="$names${names:+, }$name"
done <"$file"
# Outside a set-up project, show the companions at most once in 7 days.
if [ "$req" -gt 0 ] && [ -z "$root" ]; then
  stamp="${XDG_CACHE_HOME:-$HOME/.cache}/shipinetics/companions-notice"
  if [ -n "$(find "$stamp" -mtime -7 2>/dev/null)" ]; then req=0
  else { mkdir -p "$(dirname "$stamp")" && : >"$stamp"; } 2>/dev/null; fi
fi
if [ "$req" = 0 ]; then
  [ -n "$warn" ] || noop
  sy_hook_session_start_reply "$harness" "Shipinetics:$warn" "Shipinetics warnings for this session:$warn"
  exit 0
fi

if [ "$n" = 1 ]; then head="1 Shipinetics companion is missing."; else head="$n Shipinetics companions are missing."; fi
msg="${warn:+Shipinetics:$warn

}$head Shipinetics works without them, but the steps that use them are weaker or skipped.$lines

Scan each one with SkillSpector before you install it. To see the list again: shipinetics-companions. To stop this notice for a companion that you don't want, add its name to companions_skip in ~/.config/shipinetics/config."
ctx="${warn:+Shipinetics warnings for this session:$warn
}Shipinetics companions that are missing on this machine: $names. The user saw the list at session start. When a task needs one of them, or the user asks about them, run shipinetics-companions missing for why Shipinetics uses each one, its SkillSpector result and its install command, and offer a route without it. Never install one without the user's yes. The install gate also asks the user."

sy_hook_session_start_reply "$harness" "$msg" "$ctx"
exit 0
