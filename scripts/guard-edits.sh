#!/usr/bin/env bash
# PreToolUse hook for Edit, Write and NotebookEdit. Two rules, each active only when its
# list exists in .shipinetics/ (so the hook does nothing in projects that aren't set up):
#
#   protected-paths     Existing files matching these globs can't be modified. New files are fine,
#                       so acceptance tests can be written first and then stay fixed. To change one,
#                       an agent writes the full new version to .shipinetics/pending/<path>, and a
#                       human reviews and applies it with shipinetics-config apply.
#   test-paths          Only the shipinetics:test-writer subagent may create or edit test files, and
#                       test-writer may edit nothing except test files and the testing docs.
#
# Globs are bash patterns relative to the Shipinetics root, and * also matches /.
# Switch this hook off with "hooks_off = edits" in the project or user config.
# Per-session overrides, set when starting Claude Code:
#   SHIPINETICS_UNLOCK=1               edit protected paths
#   SHIPINETICS_ALLOW_AUTHOR_TESTS=1   let any agent edit tests
#
# These cover Claude's file tools only. Bash can still write files, which is why reviewers
# check test diffs too.

set -uo pipefail

input="$(cat)"
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
root="$(sy_root 2>/dev/null)" || root=""

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
case "$path" in /*) ;; *) path="${root:-${CLAUDE_PROJECT_DIR:-$PWD}}/$path" ;; esac
path="$(sy_norm_path "$path")"   # so .. can't step out of the pending folder past the rules

[ -n "$root" ] || exit 0
sy_hook_off edits "$root" && exit 0
dir="$(sy_dir "$root")"
dn="$SY_DIR_NAME"
rel="$(sy_rel "$root" "$path")"
agent="$(jget agent_type)"
is_test_writer=0
case "$agent" in *test-writer) is_test_writer=1 ;; esac
# A proposal in the pending folder is never protected itself, and the other rules check it as the
# file it would replace (sy_list_match does both).
target_rel="$rel"
case "$rel" in "$dn/pending/"*) target_rel="${rel#"$dn/pending/"}" ;; esac
testing_guide="$(sy_cfg "$root" testing_guide_file)"
test_index="$(sy_cfg "$root" test_index_file)"

# ---- 1. protected paths: existing files only ----
if ! sy_flag UNLOCK && [ -e "$path" ] && sy_list_match "$root" protected-paths "$rel"; then
  deny "$rel is protected (matches '$SY_MATCHED' in $dn/protected-paths). These files define what done means, so they don't change to fit the implementation. If you think the file is wrong, write the full new version to $dn/pending/$rel, add your reasoning under 'Test change requests' in your worksheet, and carry on with the rest of the task. A human reviews it and applies it with shipinetics-config apply."
fi

# ---- 2. test ownership ----
if ! sy_flag ALLOW_AUTHOR_TESTS && [ -f "$dir/test-paths" ]; then
  if sy_list_match "$root" test-paths "$rel"; then
    if [ "$is_test_writer" != 1 ]; then
      deny "$rel is a test file (matches '$SY_MATCHED' in $dn/test-paths). The agent that writes the code doesn't write its tests. Spawn the shipinetics:test-writer subagent with the spec or acceptance criteria and the files under test, and let it write or change tests in its own context. If an existing test looks wrong, give test-writer your reasoning and the spec, and it decides."
    fi
  elif [ "$is_test_writer" = 1 ]; then
    case "$target_rel" in
      docs/testing/*|"$testing_guide"|"$test_index") ;;
      *) deny "test-writer only edits test files ($dn/test-paths) and the testing docs ($testing_guide, $test_index). $rel is source. Report the change you need (a bug, an export, a test seam) in your final report instead." ;;
    esac
  fi
fi

exit 0
