# Changes to protected files go through .shipinetics/pending/, and only a human at a terminal applies them.
. "$(dirname "$0")/helpers.sh"
p="$scratch/pend"; new_repo "$p"; cd "$p" || exit 1
mkdir -p .shipinetics e2e/acceptance
printf '.shipinetics/*\ne2e/acceptance/*\n' >.shipinetics/protected-paths
printf 'e2e/*\n' >.shipinetics/test-paths
echo old >e2e/acceptance/a.spec.ts
git add -A; git commit -qm init

# edit_hook <file> [agent type]: run the edit guard on a Write of that file; sets OUT
edit_hook() {
  OUT="$(printf '{"tool_name":"Write","agent_type":"%s","tool_input":{"file_path":"%s","content":"x"}}' "${2:-}" "$p/$1" |
    CLAUDE_PROJECT_DIR="$p" bash "$SY/scripts/guard-edits.sh" 2>/dev/null)"
}

edit_hook e2e/acceptance/a.spec.ts shipinetics:test-writer
has "protected file: the deny points at the pending folder" "$OUT" ".shipinetics/pending/e2e/acceptance/a.spec.ts"
mkdir -p .shipinetics/pending/e2e/acceptance; echo new >.shipinetics/pending/e2e/acceptance/a.spec.ts
edit_hook .shipinetics/pending/e2e/acceptance/a.spec.ts shipinetics:test-writer
eq "test-writer can revise its proposal" "$OUT" ""
edit_hook .shipinetics/pending/e2e/acceptance/a.spec.ts
has "a proposal for a test file is still test-writer's" "$OUT" "is a test file"

# Claude Code on Windows gives native paths (C:\x\y) in the hook input and CLAUDE_PROJECT_DIR. The
# guard must still find the protected file, or it lets the edit through. Only on Windows: elsewhere
# there is no C: drive, so a C:\ path can't name an existing file.
if on_windows; then
  OUT="$(printf '{"tool_name":"Write","agent_type":"shipinetics:test-writer","cwd":"%s","tool_input":{"file_path":"%s","content":"x"}}' "$(json_path "$p")" "$(json_path "$p/e2e/acceptance/a.spec.ts")" |
    CLAUDE_PROJECT_DIR="$(native_path "$p")" bash "$SY/scripts/guard-edits.sh" 2>/dev/null)"
  has "protected file given as a Windows path (C:\\...): the edit is denied" "$OUT" "is protected"
  has "and the deny points at the pending folder" "$OUT" ".shipinetics/pending/e2e/acceptance/a.spec.ts"
else
  printf '  skip  protected file given as a Windows path (only on Windows: no C: drive here)\n'
fi

edit_hook e2e/acceptance/new.spec.ts shipinetics:test-writer
eq "a new file in a protected path is allowed" "$OUT" ""
edit_hook e2e/unit.spec.ts
has "only test-writer edits a test file" "$OUT" "is a test file"
edit_hook e2e/unit.spec.ts shipinetics:test-writer
eq "test-writer edits a test file" "$OUT" ""
edit_hook src/app.ts shipinetics:test-writer
has "test-writer can't edit source" "$OUT" "test-writer only edits test files"
edit_hook src/app.ts
eq "any other agent edits source" "$OUT" ""
edit_hook docs/testing/test-index.md shipinetics:test-writer
eq "test-writer edits the testing docs" "$OUT" ""

# A session in $p that edits a file in another repo: that repo's lists apply, not $p's.
plain="$scratch/plain"; new_repo "$plain"
setup="$scratch/setup"; new_repo "$setup"; mkdir -p "$setup/.shipinetics"
printf 'tests/*\n' >"$setup/.shipinetics/test-paths"
# edit_other <absolute file> [agent type]: the edit guard, with the session in $p; sets OUT
edit_other() {
  OUT="$(printf '{"tool_name":"Write","agent_type":"%s","cwd":"%s","tool_input":{"file_path":"%s","content":"x"}}' "${2:-}" "$p" "$1" |
    CLAUDE_PROJECT_DIR="$p" bash "$SY/scripts/guard-edits.sh" 2>/dev/null)"
}
edit_other "$plain/tests/test_a.py" shipinetics:test-writer
eq "test-writer edits a file in a repo that isn't set up" "$OUT" ""
edit_other "$setup/tests/test_a.py" shipinetics:test-writer
eq "test-writer edits a test file of another set-up repo" "$OUT" ""
edit_other "$setup/tests/test_a.py"
has "another repo's test list applies to the session's agent" "$OUT" "tests/test_a.py is a test file"
edit_other "$setup/src/a.py" shipinetics:test-writer
has "test-writer can't edit source in another set-up repo" "$OUT" "test-writer only edits test files"

edit_hook .shipinetics/pending/../../e2e/acceptance/a.spec.ts shipinetics:test-writer
has "a .. path can't use the pending folder to reach a protected file" "$OUT" "is protected"
OUT="$(printf '{"tool_name":"Write","agent_type":"shipinetics:test-writer","tool_input":{"file_path":"%s","content":"x"}}' "$p/e2e/acceptance/a.spec.ts" |
  SHIPINETICS_UNLOCK=1 CLAUDE_PROJECT_DIR="$p" bash "$SY/scripts/guard-edits.sh" 2>/dev/null)"
eq "SHIPINETICS_UNLOCK allows a protected edit" "$OUT" ""
pending="$(shipinetics-config pending 2>&1)"
has "pending lists the proposal" "$pending" "e2e/acceptance/a.spec.ts (+1 -1 lines)"
has "pending says why a person applies it" "$pending" "Why you must apply these changes yourself"
has "pending gives the full command for the user's terminal" "$pending" "$SY/bin/shipinetics-config -C $p apply"
has "and the one-time command for the short commands" "$pending" "$SY/bin/shipinetics-shims install"
has "-C runs pending for the project in that folder" "$(cd / && shipinetics-config -C "$p" pending 2>&1)" "e2e/acceptance/a.spec.ts (+1 -1 lines)"
out="$(cd / && shipinetics-config -C "$scratch/no-such-folder" root 2>&1)"; rc=$?
eq "-C with a folder that doesn't exist fails" "$rc" "2"
shipinetics-shims install >/dev/null
pending="$(shipinetics-config pending 2>&1)"
has "with the shims, pending gives the short command" "$pending" "  shipinetics-config -C $p apply"
hasnt "and no install command" "$pending" "shipinetics-shims install"
shipinetics-shims remove >/dev/null
out="$(shipinetics-config apply </dev/null 2>&1)"; rc=$?
eq "apply without a terminal refuses" "$rc:$(cat e2e/acceptance/a.spec.ts)" "1:old"
has "and says why" "$out" "needs a person at a terminal"
has "and tells the agent to give the user the pending output" "$out" "give the user its output"
# The rest needs a pseudo-terminal. Some sandboxes have none; CI does.
if ! python3 -c 'import os, pty; m, s = pty.openpty(); os.close(m); os.close(s)' 2>/dev/null; then
  printf '  skip  apply at a terminal (no pseudo-terminal here)\n'; done_testing; exit
fi
out="$(with_tty 'n
' shipinetics-config apply)"
eq "answering no leaves it pending" "$(cat e2e/acceptance/a.spec.ts):$([ -f .shipinetics/pending/e2e/acceptance/a.spec.ts ] && echo pending)" "old:pending"
has "apply shows the diff" "$out" "+new"
with_tty 'y
' shipinetics-config apply >/dev/null
eq "answering yes applies it" "$(cat e2e/acceptance/a.spec.ts)" "new"
eq "and clears the proposal" "$([ -e .shipinetics/pending ] && echo left || echo gone)" "gone"
done_testing
