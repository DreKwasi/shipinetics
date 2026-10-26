# Evidence freshness: code changes after recording fail; docs, tests and merged-in work don't.
. "$(dirname "$0")/helpers.sh"
t="$scratch/ev"; new_repo "$t"; cd "$t" || exit 1
mkdir -p .shipyard; printf 'tests/*\n' >.shipyard/test-paths; printf '.shipyard/.cache/\n' >.gitignore
echo a >a.txt; echo o >other.txt; git add -A; git commit -qm init; git checkout -qb feat
mkdir -p docs/worksheets docs/evidence/w; printf '# W\n- [ ] AC1: works\n' >docs/worksheets/w.md
echo b >a.txt; git add -A; git commit -qm code -m "Worksheet: w"
printf '> Commit: %s | Recorded: now\n| Criterion | Feature and entry point | Evidence | What |\n|---|---|---|---|\n| AC1 | F1 | terminal.log | ok |\n' "$(git rev-parse --short HEAD)" >docs/evidence/w/EVIDENCE.md
echo x >docs/evidence/w/terminal.log; git add -A; git commit -qm ev -m "Worksheet: w"
chk() { OUT="$(evidence check w 2>&1)"; }
chk; has "fresh evidence passes" "$OUT" "complete for w"
mkdir -p tests; echo t >tests/a.test.js; git add -A; git commit -qm t; chk; has "tests-only change keeps it" "$OUT" "complete for w"
echo d >README.md; chk; has "docs change keeps it" "$OUT" "complete for w"
git checkout -q main; echo o2 >other.txt; git commit -qam "main work"; git checkout -q feat; git merge -q --no-edit main
chk; has "merging main keeps it" "$OUT" "complete for w"
echo c >a.txt; chk; has "code change makes it stale" "$OUT" "code changed since: a.txt"
git checkout -q a.txt; replace docs/evidence/w/EVIDENCE.md "> Commit: " "> Commit: x"; chk
has "a bad Commit line fails" "$OUT" "doesn't name a commit"
done_testing
