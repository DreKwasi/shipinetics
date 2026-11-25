# Changes that need no evidence: one rule for evidence check, the PR hook and the CI template.
. "$(dirname "$0")/helpers.sh"
t="$scratch/ne"; new_repo "$t"; cd "$t" || exit 1
mkdir -p .shipinetics src tests docs; printf 'tests/*\n' >.shipinetics/test-paths
printf 'evidence = required\n' >.shipinetics/config  # the rules below apply when evidence is required
printf '.shipinetics/.cache/\n' >.gitignore
echo a >src/a.js; echo d >docs/x.txt; git add -A; git commit -qm init; git checkout -qb feat
base="$(git rev-parse HEAD)"

# ---- evidence check --branch and evidence needed
echo t >tests/a.test.js; git add -A; git commit -qm t
OUT="$(evidence check --branch 2>&1)"; rc=$?
eq "tests only: check passes" "$rc" 0
has "tests only: says no evidence is needed" "$OUT" "no evidence needed. Every changed file"
hasnt "tests only: not called docs only" "$OUT" "docs only"
evidence needed >/dev/null 2>&1; eq "tests only: needed exits 1" "$?" 1
mkdir -p .github/workflows; echo w >.github/workflows/ci.yml; git add -A; git commit -qm ci
evidence needed >/dev/null 2>&1; eq "default list covers .github/" "$?" 1
echo b >src/a.js; git add -A; git commit -qm code
eq "code change: needed lists it" "$(evidence needed 2>/dev/null)" "src/a.js"
OUT="$(evidence check --branch 2>&1)"; eq "code change: check fails without a worksheet" "$?" 1
printf 'docs/*\nsrc/*\n.github/*\n' >.shipinetics/no-evidence-paths
evidence needed >/dev/null 2>&1; eq "the project's list exempts src/" "$?" 1
echo m >NOTES.md; git add -A; git commit -qm notes
eq "the project's list replaces the defaults" "$(evidence needed 2>/dev/null)" "NOTES.md"
eq "shipinetics-config match reads the list" "$(shipinetics-config match no-evidence-paths src/a.js)" "src/a.js matches 'src/*' in no-evidence-paths"
rm .shipinetics/no-evidence-paths

# ---- the PR hook
printf '## Evidence\n' >"$scratch/body.md"
pr() { OUT="$(printf '{"tool_input":{"command":"gh pr create --body-file %s"},"cwd":"%s"}' "$scratch/body.md" "$t" | CLAUDE_PROJECT_DIR="$t" bash "$SY/scripts/guard-pr.sh")"; }
pr; has "hook: code change is denied" "$OUT" "no complete evidence yet"
has "hook: names the files that need evidence" "$OUT" "src/a.js"
has "hook: names the list" "$OUT" "no-evidence-paths"
has "hook: names the label for a person" "$OUT" "no-evidence label"
git reset -q --hard "$base"; git clean -fdq; mkdir -p tests
echo t2 >tests/b.test.js; git add -A; git commit -qm t2
pr; eq "hook: tests only opens without evidence" "$OUT" ""
stub_verify bin/verify; printf 'verify_cmd = bin/verify\n' >>.shipinetics/config
printf 'tests/*\nbin/*\n' >.shipinetics/test-paths
pr; has "hook: tests only still needs the verify" "$OUT" "complete verify hasn't passed"
git reset -q --hard "$base"; git clean -fdq; printf 'tests/*\n' >.shipinetics/test-paths
echo more >docs/x.txt; git commit -qam docs
pr; eq "hook: docs only opens" "$OUT" ""

# ---- the CI template's evidence job
python3 - "$SY/skills/setup/templates/github/workflows/verify.yml" "$scratch/ci.sh" <<'PY'
import sys
lines = open(sys.argv[1]).read().split("\n")
i = next(n for n, l in enumerate(lines) if "Require evidence for changes that need it" in l)
i = next(n for n in range(i, len(lines)) if lines[n].strip() == "run: |") + 1
body = []
for l in lines[i:]:
    if l.strip() and not l.startswith(" " * 10): break
    body.append(l[10:])
open(sys.argv[2], "w").write("\n".join(body).replace("${{ github.event.pull_request.number }}", "7") + "\n")
PY
ci() { OUT="$(PR_BODY="$1" BASE_SHA="$base" HEAD_SHA="$(git rev-parse HEAD)" RUNNER_TEMP="$scratch" bash "$scratch/ci.sh" 2>&1)"; RC=$?; }
git reset -q --hard "$base"; git clean -fdq; mkdir -p tests
echo t3 >tests/c.test.js; mkdir -p .github; echo x >.github/x.yml; git add -A; git commit -qm tests
ci ""; eq "CI: tests and .github/ pass with no section" "$RC" 0
has "CI: says why" "$OUT" "No evidence needed"
echo c >src/a.js; git commit -qam code
ci "Summary"; eq "CI: code change without a section fails" "$RC" 1
has "CI: lists the file" "$OUT" "src/a.js"
has "CI: gives the label command" "$OUT" "gh pr edit 7 --add-label no-evidence"
has "CI: says how to create the label" "$OUT" "gh label create no-evidence"
ci "$(printf '## Evidence\r\n\r\nNone: refactor, no behaviour change\r\n')"; eq "CI: a None reason passes (CRLF body)" "$RC" 0
has "CI: shows the reason" "$OUT" "refactor, no behaviour change"
ci "$(printf '## Evidence\n\nNone:\n')"; eq "CI: None without a reason fails" "$RC" 1
ci "$(printf '## Evidence\n\nTerminal transcript: [terminal.log](x)\n')"; eq "CI: a transcript link passes" "$RC" 0
ci "$(printf '## Evidence\n\nsoon\n\n## Notes\nNone: later\n')"; eq "CI: a None line outside the section doesn't count" "$RC" 1
printf 'src/*\n.github/*\n' >.shipinetics/no-evidence-paths; git add -A; git commit -qm list
ci ""; eq "CI: reads the project's list" "$RC" 0
# ---- evidence = optional (the default): no evidence asked for, the verify still is
git reset -q --hard "$base"; git clean -fdq
sed -i.bak '/^evidence/d' .shipinetics/config && rm -f .shipinetics/config.bak; git commit -qam "default"
echo d >src/a.js; git add -A; git commit -qm code2
eq "optional: the default setting" "$(shipinetics-config get evidence)" "optional"
pr; eq "optional: a code change opens with no evidence and no Evidence section" "$OUT" ""
printf 'Summary only\n' >"$scratch/body.md"; pr; eq "optional: the body needs no Evidence section" "$OUT" ""
stub_verify bin/verify; git add -A; git commit -qm v; printf 'verify_cmd = bin/verify\n' >>.shipinetics/config
pr; has "optional: the verify is still required" "$OUT" "complete verify hasn't passed"
git checkout -q .shipinetics/config
ci "Summary"; eq "optional: the CI evidence job passes" "$RC" 0
has "optional: and says how to require it" "$OUT" "evidence = required"
done_testing
