#!/usr/bin/env bash
# PreToolUse hook for Edit, Write and NotebookEdit. Two rules, each active only when its
# list exists in .shipinetics/ (so the hook does nothing in projects that aren't set up):
#
#   protected-paths     Existing files matching these globs can't be modified. New files are fine,
#                       so test-writer can add acceptance tests, which then stay fixed. To change one,
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
harness="$(sy_hook_harness "$input")"
cwd="$(sy_hook_cwd "$input")"

noop() { sy_hook_noop "$harness"; exit 0; }
deny() { sy_hook_pretool_reply "$harness" deny "$1"; exit 0; }

path="$(sy_hook_file_path "$input")"
[ -n "$path" ] || noop
case "$path" in /*) ;; *) path="$(sy_root "$cwd" 2>/dev/null || printf '%s' "$cwd")/$path" ;; esac
path="$(sy_norm_path "$path")"   # so .. can't step out of the pending folder past the rules

# The rules are those of the project that holds the file, not of the session's folder: a session
# can edit another repo, and that repo's lists apply there (none, if it isn't set up).
start="$(dirname "$path")"
while [ ! -d "$start" ] && [ "$start" != "/" ]; do start="$(dirname "$start")"; done
root="$(sy_root "$start" 2>/dev/null)" || root=""
[ -n "$root" ] || noop
sy_hook_off edits "$root" && noop
dir="$(sy_dir "$root")"
dn="$SY_DIR_NAME"
rel="$(sy_rel "$root" "$path")"
agent="$(sy_hook_agent_type "$input")"
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
# Antigravity's PreToolUse payload omits agentType for both main agents and subagents, so enforce
# test ownership there only when an agent type is present (otherwise test-writer is blocked too).
check_test_owner=1
if [ "$harness" = "antigravity" ] && ! sy_hook_has_agent_type "$input"; then
  check_test_owner=0
fi
if [ "$check_test_owner" = 1 ] && ! sy_flag ALLOW_AUTHOR_TESTS && [ -f "$dir/test-paths" ]; then
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

noop
