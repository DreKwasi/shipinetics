# The PR gate requires fresh evidence and a complete verify pass on exactly this code.
. "$(dirname "$0")/helpers.sh"
t="$scratch/pr"; new_repo "$t"; cd "$t" || exit 1
stub_verify bin/verify; mkdir -p .shipinetics; printf '.shipinetics/.cache/\n' >.gitignore
echo a >a.txt; git add -A; git commit -qm init; git checkout -qb feat
mkdir -p docs/worksheets docs/evidence/w; printf '# W\n> Status: done\n- [x] AC1: works\n' >docs/worksheets/w.md
echo b >a.txt; git add -A; git commit -qm code -m "Worksheet: w"
printf '> Commit: %s | Recorded: now\n| Criterion | Evidence | What |\n|---|---|---|\n| AC1 | terminal.log | ok |\n' "$(git rev-parse --short HEAD)" >docs/evidence/w/EVIDENCE.md
echo '$ run' >docs/evidence/w/terminal.log; git add -A; git commit -qm ev -m "Worksheet: w"
printf '## Evidence\n' >"$scratch/body.md"
pr() { OUT="$(printf '{"tool_input":{"command":"gh pr create --body-file %s"},"cwd":"%s"}' "$scratch/body.md" "$t" | CLAUDE_PROJECT_DIR="$t" bash "$SY/scripts/guard-pr.sh")"; }
pr; has "denied before verify" "$OUT" "complete verify hasn't passed"
shipinetics-verify >/dev/null; pr; eq "allowed after shipinetics-verify" "$OUT" ""
echo note >>docs/worksheets/w.md; git commit -qam ws -m "Worksheet: w"; pr; eq "worksheet-only commit keeps the pass" "$OUT" ""
echo c >a.txt; git commit -qam fix -m "Worksheet: w"; pr; has "code change makes evidence stale" "$OUT" "code changed since: a.txt"
done_testing
