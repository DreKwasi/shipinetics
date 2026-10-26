# The bin/verify template: tiers, parallel steps, failure output, changed-file scoping.
. "$(dirname "$0")/helpers.sh"
d="$scratch/vt"; mkdir -p "$d/bin"; cd "$d" || exit 1
python3 - "$SY/skills/setup/templates/bin/verify" "$d/bin/verify" <<'PY'
import re, sys
s = open(sys.argv[1]).read()
fill = {"TYPECHECK_QUICK_CMD": "sleep 1; echo tq", "UNIT_RELATED_CMD": "sleep 1; echo ur",
        "LINT_CHANGED_CMD": 'f="$(changed "\\.ts$")"; [ -z "$f" ] && { echo none >lint.out; return 0; }; echo "$f" >lint.out',
        "LINT_CMD": "echo lint-out; [ ! -f FAIL ]"}
s = re.sub(r"\{\{([A-Z_]+)\}\}", lambda m: fill.get(m.group(1), "true"), s)
open(sys.argv[2], "w").write(s)
PY
chmod +x bin/verify; echo x >a.ts; printf 'a.ts\nb.md\n' >list; printf 'b.md\n' >list2
start=$(date +%s); out="$(SHIPYARD_CHANGED_FILES=list bin/verify --quick)"; rc=$?; took=$(( $(date +%s) - start ))
eq "quick tier passes" "$rc" 0
[ "$took" -le 2 ] && ok "quick steps run in parallel (${took}s)" || bad "quick steps run in parallel" "took ${took}s"
eq "changed() lists matching changed files" "$(cat lint.out)" "a.ts"
SHIPYARD_CHANGED_FILES=list2 bin/verify --quick >/dev/null; eq "nothing relevant changed: step skips" "$(cat lint.out)" none
bin/verify --quick >/dev/null; eq "no list means check everything" "$(cat lint.out)" "__all__"
touch FAIL; out="$(bin/verify)"; rc=$?
eq "complete tier fails when a step fails" "$rc" 1
has "failing step's output is shown" "$out" "==> lint: FAILED"
has "failing step's log is shown" "$out" "lint-out"
done_testing
