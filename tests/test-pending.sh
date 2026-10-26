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

edit_hook .shipinetics/pending/../../e2e/acceptance/a.spec.ts shipinetics:test-writer
has "a .. path can't use the pending folder to reach a protected file" "$OUT" "is protected"
has "pending lists the proposal" "$(shipinetics-config pending 2>&1)" "e2e/acceptance/a.spec.ts (+1 -1 lines)"
out="$(shipinetics-config apply </dev/null 2>&1)"; rc=$?
eq "apply without a terminal refuses" "$rc:$(cat e2e/acceptance/a.spec.ts)" "1:old"
has "and says why" "$out" "needs a human at a terminal"
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
