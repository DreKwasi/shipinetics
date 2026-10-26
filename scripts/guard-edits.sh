#!/usr/bin/env bash
# PreToolUse hook for Edit, Write and NotebookEdit. Three rules, each active only when its
# list exists in .shipinetics/ (so the hook does nothing in projects that aren't set up):
#
#   protected-paths     Existing files matching these globs can't be modified. New files are fine,
#                       so acceptance tests can be written first and then stay fixed.
#   test-paths          Only the shipinetics:test-writer subagent may create or edit test files, and
#                       test-writer may edit nothing except test files and the testing docs.
#   env-allowed-paths   New environment-variable reads (process.env and friends) are only allowed
#                       in files matching these globs, normally the config module.
#
# Globs are bash patterns relative to the Shipinetics root, and * also matches /.
# It also records which files the agent edits this session, so the Stop hook knows which
# packages to verify in workspace mode.
# Per-session overrides, set when starting Claude Code:
#   SHIPINETICS_UNLOCK=1               edit protected paths
#   SHIPINETICS_ALLOW_AUTHOR_TESTS=1   let any agent edit tests
#   SHIPINETICS_ALLOW_ENV_READ=1       allow env reads anywhere in code
#
# These cover Claude's file tools only. Bash can still write files, which is why reviewers
# check test diffs and env access too.

set -uo pipefail

input="$(cat)"
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
root="$(sy_root)" || exit 0
dir="$root/.shipinetics"

jget() { sy_json_field "$input" "$1"; }

deny() {
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  else
    python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": sys.argv[1]}}))' "$1"
  fi
  exit 0
}

path="$(jget tool_input.file_path)"
[ -n "$path" ] || path="$(jget tool_input.notebook_path)"
[ -n "$path" ] || exit 0
case "$path" in /*) ;; *) path="$root/$path" ;; esac
rel="$(sy_rel "$root" "$path")"
agent="$(jget agent_type)"
session="$(jget session_id)"
is_test_writer=0
case "$agent" in *test-writer) is_test_writer=1 ;; esac
testing_guide="$(sy_cfg "$root" testing_guide_file)"
test_index="$(sy_cfg "$root" test_index_file)"

# ---- 1. protected paths: existing files only ----
if [ "${SHIPINETICS_UNLOCK:-0}" != "1" ] && [ -e "$path" ] && sy_in_list "$dir/protected-paths" "$rel"; then
  deny "$rel is protected (matches '$SY_MATCHED' in .shipinetics/protected-paths). These files define what done means, so they don't change to fit the implementation. If you think the file is wrong, add it and your reasoning under 'Test change requests' in your worksheet and carry on with the rest of the task. A human decides."
fi

# ---- 2. test ownership ----
if [ "${SHIPINETICS_ALLOW_AUTHOR_TESTS:-0}" != "1" ] && [ -f "$dir/test-paths" ]; then
  if sy_in_list "$dir/test-paths" "$rel"; then
    if [ "$is_test_writer" != 1 ]; then
      deny "$rel is a test file (matches '$SY_MATCHED' in .shipinetics/test-paths). The agent that writes the code doesn't write its tests. Spawn the shipinetics:test-writer subagent with the spec or acceptance criteria and the files under test, and let it write or change tests in its own context. If an existing test looks wrong, give test-writer your reasoning and the spec, and it decides."
    fi
  elif [ "$is_test_writer" = 1 ]; then
    case "$rel" in
      docs/testing/*|"$testing_guide"|"$test_index") ;;
      *) deny "test-writer only edits test files (.shipinetics/test-paths) and the testing docs ($testing_guide, $test_index). $rel is source. Report the change you need (a bug, an export, a test seam) in your final report instead." ;;
    esac
  fi
fi

# ---- 3. environment reads in code ----
if [ "${SHIPINETICS_ALLOW_ENV_READ:-0}" != "1" ] && [ -f "$dir/env-allowed-paths" ] && ! sy_in_list "$dir/env-allowed-paths" "$rel"; then
  re='process\.env|import\.meta\.env|Deno\.env|Bun\.env|os\.environ|os\.getenv|os\.Getenv|os\.LookupEnv|std::env::var|env::var\(|System\.getenv|ENV\[|ENV\.fetch|getenv\('
  count() { grep -oE "$re" | wc -l | tr -d ' '; }
  tool="$(jget tool_name)"
  case "$tool" in
    Edit)         before="$(jget tool_input.old_string | count)"; after="$(jget tool_input.new_string | count)" ;;
    Write)        before="$( { [ -f "$path" ] && cat "$path"; } | count)"; after="$(jget tool_input.content | count)" ;;
    NotebookEdit) before=0; after="$(jget tool_input.new_source | count)" ;;
    *)            before=0; after=0 ;;
  esac
  if [ "${after:-0}" -gt "${before:-0}" ]; then
    deny "$rel would read environment variables directly. In this project only the config module reads the environment (files in .shipinetics/env-allowed-paths). Secrets come from the vault as environment variables, and the config module validates and exposes them. Import the value from the config module instead. If the variable isn't there yet, add it to the config module and note the new secret in your worksheet so a human can create it in the vault."
  fi
fi

# ---- allowed: remember the edit for the Stop hook ----
if [ -n "$session" ]; then
  cache="$dir/.cache"
  mkdir -p "$cache" 2>/dev/null && {
    [ -e "$cache/session-$session" ] || touch "$cache/session-$session"
    printf '%s\n' "$rel" >>"$cache/touched-$session"
  }
fi

exit 0
