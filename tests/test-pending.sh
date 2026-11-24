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
# with_tty <input> <command...>: run a command with a terminal on stdin, typing the input
# (Not pty.spawn: it stops copying when the child exits, so output can go missing on macOS.)
with_tty() {
  python3 - "$@" <<'PY' 2>&1
import os, pty, sys
pid, fd = pty.fork()
if pid == 0:
    os.execvp(sys.argv[2], sys.argv[2:])
os.write(fd, sys.argv[1].encode())
out = b""
while True:
    try:
        chunk = os.read(fd, 4096)
    except OSError:    # Linux: EIO once the child has gone and the output is drained
        break
    if not chunk:      # macOS: end of file
        break
    out += chunk
_, status = os.waitpid(pid, 0)
sys.stdout.write(out.decode(errors="replace"))
sys.exit((status >> 8) & 0xff)
PY
}

edit_hook e2e/acceptance/a.spec.ts shipinetics:test-writer
has "protected file: the deny points at the pending folder" "$OUT" ".shipinetics/pending/e2e/acceptance/a.spec.ts"
mkdir -p .shipinetics/pending/e2e/acceptance; echo new >.shipinetics/pending/e2e/acceptance/a.spec.ts
edit_hook .shipinetics/pending/e2e/acceptance/a.spec.ts shipinetics:test-writer
eq "test-writer can revise its proposal" "$OUT" ""
edit_hook .shipinetics/pending/e2e/acceptance/a.spec.ts
has "a proposal for a test file is still test-writer's" "$OUT" "is a test file"

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
has "pending gives the full command for the user's terminal" "$pending" "&& $SY/bin/shipinetics-config apply"
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
