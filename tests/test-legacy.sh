# Projects set up under the old Shipyard name keep working for one version: the .shipyard/
# folder, SHIPYARD_* settings, the shipyard-* commands and verify scripts that read the old names.
. "$(dirname "$0")/helpers.sh"

# edit_hook <project root> <file>: run the edit guard on an Edit of that file; sets OUT
edit_hook() {
  OUT="$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s","old_string":"a","new_string":"b"}}' "$2" |
    CLAUDE_PROJECT_DIR="$1" bash "$SY/scripts/guard-edits.sh" 2>/dev/null)"
}

# A project that only has .shipyard/, and a verify script that reads only the old variable names.
p="$scratch/legacy"; new_repo "$p"; cd "$p" || exit 1
mkdir -p bin .shipyard/.cache
cat >bin/verify <<'V'
#!/bin/sh
printf 'RAN tier=%s arg=%s files=' "${SHIPYARD_VERIFY_TIER:-none}" "${1:-}"
if [ -n "${SHIPYARD_CHANGED_FILES:-}" ]; then tr '\n' '|' <"$SHIPYARD_CHANGED_FILES"; fi
echo
V
chmod +x bin/verify
printf 'verify_quick_cmd = bin/verify --quick\n' >.shipyard/config
printf '.shipyard/*\n' >.shipyard/protected-paths
printf '.shipyard/.cache/\n' >.gitignore
echo a >a.txt; git add -A; git commit -qm init; git checkout -qb feat
touch .shipyard/.cache/session-s1

echo b >a.txt; stop_hook "$p"
has "legacy folder: the Stop hook reads its config" "$(cat .shipyard/.cache/verify.log 2>/dev/null)" "arg=--quick"
has "legacy folder: a notice says to rename it" "$OUT" "shipinetics-config migrate"
has "old verify script still gets the tier and changed files" "$(cat .shipyard/.cache/verify.log 2>/dev/null)" "tier=quick arg=--quick files=a.txt|"
rm -f .shipyard/.cache/verify.log; echo c >a.txt
SHIPYARD_SKIP_VERIFY=1 stop_hook "$p"
eq "legacy SHIPYARD_SKIP_VERIFY turns the Stop hook off" "$([ -f .shipyard/.cache/verify.log ] && echo ran || echo skipped)" skipped
git checkout -q a.txt

eq "legacy folder: shipinetics-config reads it" "$(shipinetics-config get verify_quick_cmd 2>/dev/null)" "bin/verify --quick"
edit_hook "$p" "$p/.shipyard/config"
has "legacy folder: its policy files are protected" "$OUT" "is protected"
edit_hook "$p" "$p/.shipinetics/config"
has "legacy folder: creating .shipinetics/ is blocked" "$OUT" "shipinetics-config migrate"
SHIPYARD_UNLOCK=1 edit_hook "$p" "$p/.shipyard/config"
eq "legacy SHIPYARD_UNLOCK unlocks protected paths" "$OUT" ""

# The old command names still work, and say they're deprecated.
out="$("$SY/bin/shipyard-config" root 2>"$scratch/err")"
eq "shipyard-config shim runs shipinetics-config" "$out" "$(cd "$p" && pwd)"
has "shipyard-config shim says it's deprecated" "$(cat "$scratch/err")" "shipyard-config is deprecated"
out="$("$SY/bin/shipyard-verify" status 2>"$scratch/err")"
has "shipyard-verify shim runs shipinetics-verify" "$out" "complete: "
has "shipyard-verify shim says it's deprecated" "$(cat "$scratch/err")" "shipyard-verify is deprecated"

# Migrating: git mv keeps the old protected-paths line, which must still cover the renamed folder,
# and the rename alone doesn't make a branch's evidence stale.
mkdir -p docs/worksheets docs/evidence/w; printf '# W\n- [ ] AC1: works\n' >docs/worksheets/w.md
echo b >a.txt; git add -A; git commit -qm code -m "Worksheet: w"
printf '> Commit: %s | Recorded: now\n| Criterion | Evidence | What |\n|---|---|---|\n| AC1 | terminal.log | ok |\n' "$(git rev-parse --short HEAD)" >docs/evidence/w/EVIDENCE.md
echo x >docs/evidence/w/terminal.log; git add -A; git commit -qm ev -m "Worksheet: w"
git mv .shipyard .shipinetics; git commit -qm migrate
edit_hook "$p" "$p/.shipinetics/config"
has "after git mv, the old .shipyard/* line protects .shipinetics/" "$OUT" "is protected"
has "renaming the folder keeps the evidence fresh" "$(evidence check w 2>&1)" "complete for w"
done_testing
