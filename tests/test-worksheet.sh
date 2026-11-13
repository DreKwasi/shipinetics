# worksheet: help, and where the current worksheet is kept. In a repo that isn't set up, no
# command may create .shipinetics/: that folder is what makes the hooks treat a repo as set up.
. "$(dirname "$0")/helpers.sh"

day="$(date +%Y-%m-%d)"
clean() { [ -e "$1/.shipinetics" ] && echo "has .shipinetics" || echo "no .shipinetics"; }

# ---- help creates nothing, and prints only the usage
plain="$scratch/plain"; new_repo "$plain"; cd "$plain" || exit 1
for arg in --help -h ""; do
  OUT="$(worksheet $arg 2>&1)"; RC=$?
  eq "help ($arg) exits 0" "$RC" 0
  has "help ($arg) prints the usage" "$OUT" "worksheet new <slug>"
  hasnt "help ($arg) prints no code" "$OUT" "set -euo"
done
eq "help leaves a plain repo without .shipinetics" "$(clean "$plain")" "no .shipinetics"
eq "help leaves a plain repo without docs/" "$([ -e "$plain/docs" ] && echo has || echo none)" "none"
nogit="$scratch/nogit"; mkdir -p "$nogit"; cd "$nogit" || exit 1
for arg in --help -h ""; do
  OUT="$(worksheet $arg 2>&1)"; RC=$?
  eq "help ($arg) works outside a git repo" "$RC" 0
done
eq "and creates nothing there" "$(ls -A "$nogit")" ""

# ---- a plain git repo: the commands work, and .shipinetics never appears
cd "$plain" || exit 1
plain="$(pwd -P)"   # git gives the resolved path (/tmp is /private/tmp on macOS)
OUT="$(worksheet current 2>&1)"; RC=$?
eq "current with no worksheet fails" "$RC" 1
has "and says how to start one" "$OUT" "worksheet new"
worksheet list >/dev/null 2>&1
eq "current and list create no .shipinetics" "$(clean "$plain")" "no .shipinetics"
path="$(worksheet new demo "Demo task")"
eq "new prints the worksheet's path" "$path" "$plain/docs/worksheets/$day-demo.md"
has "new fills in the title" "$(cat "$path" 2>/dev/null)" "Demo task"
eq "new makes it current" "$(worksheet current)" "$path"
has "list shows it" "$(worksheet list)" "$day-demo"
worksheet new other >/dev/null
eq "a second new becomes current" "$(worksheet current)" "$plain/docs/worksheets/$day-other.md"
worksheet use "$day-demo" >/dev/null
eq "use makes an older one current" "$(worksheet current)" "$path"
git add -A && git commit -qm "work" && worksheet tag >/dev/null
eq "tag tags HEAD for the current worksheet" "$(git tag -l "ws/$day-demo")" "ws/$day-demo"
eq "new, use and tag create no .shipinetics" "$(clean "$plain")" "no .shipinetics"
evidence init >/dev/null 2>&1
eq "evidence finds the current worksheet in a plain repo" "$([ -f "$plain/docs/evidence/$day-demo/EVIDENCE.md" ] && echo found || echo missing)" "found"
eq "and creates no .shipinetics either" "$(clean "$plain")" "no .shipinetics"

# ---- each worktree of a plain repo has its own current worksheet
wt="$scratch/plain-wt"; git -C "$plain" worktree add -q --detach "$wt"
cd "$wt" || exit 1
OUT="$(worksheet current 2>&1)"; RC=$?
eq "a new worktree has no current worksheet" "$RC" 1
cd "$plain" || exit 1
eq "the main checkout keeps its own" "$(worksheet current)" "$path"
git worktree remove --force "$wt"

# ---- a set-up project: the current worksheet stays in .shipinetics/.cache
proj="$scratch/proj"; new_repo "$proj"; mkdir -p "$proj/.shipinetics"; cd "$proj" || exit 1
path="$(worksheet new setup-demo)"
eq "in a set-up project the current worksheet is in .shipinetics/.cache" "$(cat "$proj/.shipinetics/.cache/current-worksheet" 2>/dev/null)" "$path"
eq "and current reads it" "$(worksheet current)" "$path"
evidence init >/dev/null 2>&1
eq "evidence finds it there" "$([ -f "$proj/docs/evidence/$day-setup-demo/EVIDENCE.md" ] && echo found || echo missing)" "found"

# ---- a project's own new command still gets its worksheets folder
custom="$scratch/custom"; new_repo "$custom"; mkdir -p "$custom/.shipinetics" "$custom/scripts"; cd "$custom" || exit 1
printf 'worksheets_dir = work/ws\nworksheet_new_cmd = scripts/new.sh\n' >.shipinetics/config
printf '#!/bin/sh\necho "# $1" >"work/ws/$1.md"\necho "work/ws/$1.md"\n' >scripts/new.sh; chmod +x scripts/new.sh
OUT="$(worksheet new cdemo 2>&1)"; RC=$?
eq "a custom new command can write into a worksheets folder that didn't exist" "$RC" 0
eq "and its path is current" "$(worksheet current 2>&1)" "$custom/work/ws/cdemo.md"

# ---- workspace mode: the root isn't a repo; the current worksheet stays in the root's .shipinetics
ws="$scratch/workspace"; mkdir -p "$ws/.shipinetics"; printf 'packages = pkg\n' >"$ws/.shipinetics/config"
new_repo "$ws/pkg"; cd "$ws/pkg" || exit 1
path="$(worksheet new wdemo)"
eq "in workspace mode the current worksheet is in the root's .shipinetics/.cache" "$(cat "$ws/.shipinetics/.cache/current-worksheet" 2>/dev/null)" "$path"
eq "and a package gets no .shipinetics" "$(clean "$ws/pkg")" "no .shipinetics"
evidence init >/dev/null 2>&1
eq "evidence in the package finds it" "$([ -f "$ws/pkg/docs/evidence/$day-wdemo/EVIDENCE.md" ] && echo found || echo missing)" "found"

done_testing
