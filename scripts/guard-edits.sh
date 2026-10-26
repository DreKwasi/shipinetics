#!/usr/bin/env bash
# PreToolUse hook for Edit, Write and NotebookEdit. Three rules, each active only when its
# list exists in .shipyard/ (so the hook does nothing in projects that aren't set up):
#
#   protected-paths     Existing files matching these globs can't be modified. New files are fine,
#                       so acceptance tests can be written first and then stay fixed.
#   test-paths          Only the shipyard:test-writer subagent may create or edit test files, and
#                       test-writer may edit nothing except test files and docs/testing/.
#   env-allowed-paths   New environment-variable reads (process.env and friends) are only allowed
#                       in files matching these globs, normally the config module.
#
# Globs are bash patterns relative to the repo root, and * also matches /.
# Per-session overrides, set when starting Claude Code:
#   SHIPYARD_UNLOCK=1               edit protected paths
#   SHIPYARD_ALLOW_AUTHOR_TESTS=1   let any agent edit tests
#   SHIPYARD_ALLOW_ENV_READ=1       allow env reads anywhere in code
#
# These cover Claude's file tools only. Bash can still write files, which is why reviewers
# check test diffs and env access too.

set -uo pipefail

input="$(cat)"
root="${CLAUDE_PROJECT_DIR:-$PWD}"
dir="$root/.shipyard"
[ -d "$dir" ] || exit 0

jget() { # jget <path> [<path>...]: first non-empty value, paths like tool_input.file_path
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r "$(printf '.%s // ' "$@")empty"
  else
    printf '%s' "$input" | python3 -c 'import json,sys
d = json.load(sys.stdin)
for k in sys.argv[1:]:
    v = d
    for p in k.split("."):
        v = v.get(p) if isinstance(v, dict) else None
    if v not in (None, ""):
        sys.stdout.write(str(v)); break' "$@"
  fi
}

deny() {
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  else
    python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": sys.argv[1]}}))' "$1"
  fi
  exit 0
}

matched=""
in_list() { # in_list <listfile> <relpath>: sets $matched to the glob that matched
  local glob
  [ -f "$1" ] || return 1
  while IFS= read -r glob || [ -n "$glob" ]; do
    glob="${glob%%#*}"
    glob="$(printf '%s' "$glob" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ -z "$glob" ] && continue
    # shellcheck disable=SC2053  # the right-hand side is meant to be a pattern
    if [[ "$2" == $glob ]]; then matched="$glob"; return 0; fi
  done <"$1"
  return 1
}

path="$(jget tool_input.file_path tool_input.notebook_path)"
[ -n "$path" ] || exit 0
case "$path" in /*) ;; *) path="$root/$path" ;; esac
rel="${path#"$root"/}"
agent="$(jget agent_type)"
is_test_writer=0
case "$agent" in *test-writer) is_test_writer=1 ;; esac

# ---- 1. protected paths: existing files only ----
if [ "${SHIPYARD_UNLOCK:-0}" != "1" ] && [ -e "$path" ] && in_list "$dir/protected-paths" "$rel"; then
  deny "$rel is protected (matches '$matched' in .shipyard/protected-paths). These files define what done means, so they don't change to fit the implementation. If you think the file is wrong, add it and your reasoning under 'Test change requests' in your worksheet and carry on with the rest of the task. A human decides."
fi

# ---- 2. test ownership ----
if [ "${SHIPYARD_ALLOW_AUTHOR_TESTS:-0}" != "1" ] && [ -f "$dir/test-paths" ]; then
  if in_list "$dir/test-paths" "$rel"; then
    if [ "$is_test_writer" != 1 ]; then
      deny "$rel is a test file (matches '$matched' in .shipyard/test-paths). The agent that writes the code doesn't write its tests. Spawn the shipyard:test-writer subagent with the spec or acceptance criteria and the files under test, and let it write or change tests in its own context. If an existing test looks wrong, give test-writer your reasoning and the spec, and it decides."
    fi
  elif [ "$is_test_writer" = 1 ]; then
    case "$rel" in
      docs/testing/*) ;;
      *) deny "test-writer only edits test files (.shipyard/test-paths) and docs/testing/. $rel is source. Report the change you need (a bug, an export, a test seam) in your final report instead." ;;
    esac
  fi
fi

# ---- 3. environment reads in code ----
if [ "${SHIPYARD_ALLOW_ENV_READ:-0}" != "1" ] && [ -f "$dir/env-allowed-paths" ] && ! in_list "$dir/env-allowed-paths" "$rel"; then
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
    deny "$rel would read environment variables directly. In this project only the config module reads the environment (files in .shipyard/env-allowed-paths). Secrets come from the vault (e.g. Google Secret Manager) as environment variables, and the config module validates and exposes them. Import the value from the config module instead. If the variable isn't there yet, add it to the config module and note the new secret in your worksheet so a human can create it in the vault."
  fi
fi

exit 0
