# The bin/verify template: tiers, parallel steps, failure output, changed-file scoping.
. "$(dirname "$0")/helpers.sh"
d="$scratch/vt"; mkdir -p "$d/bin"; cd "$d" || exit 1
python3 - "$SY/skills/setup/templates/bin/verify" "$d/bin/verify" <<'PY'
import re, sys
s = open(sys.argv[1]).read()
# Each slow quick step writes when it started and ended, so the test can check that they overlap
now = 'python3 -c "import time; print(time.time())"'
slow = lambda n: "%s >%s.start; sleep 2; %s >%s.end; echo %s" % (now, n, now, n, n)
fill = {"TYPECHECK_QUICK_CMD": slow("tq"), "UNIT_RELATED_CMD": slow("ur"),
        "LINT_CHANGED_CMD": 'f="$(changed "\\.ts$")"; [ -z "$f" ] && { echo none >lint.out; return 0; }; echo "$f" >lint.out',
        "LINT_CMD": "echo lint-out; [ ! -f FAIL ]"}
s = re.sub(r"\{\{([A-Z_]+)\}\}", lambda m: fill.get(m.group(1), "true"), s)
open(sys.argv[2], "w").write(s)
PY
chmod +x bin/verify; echo x >a.ts; printf 'a.ts\nb.md\n' >list; printf 'b.md\n' >list2
out="$(SHIPINETICS_CHANGED_FILES=list bin/verify --quick)"; rc=$?
eq "quick tier passes" "$rc" 0
# Parallel: each step starts before the other ends. One after the other, the second starts only after
# the first ended. Load can only delay a start, so with 2-second steps this holds on a busy machine too.
overlap="$(python3 -c 'import sys
t = {n: [float(open(n + e).read()) for e in (".start", ".end")] for n in ("tq", "ur")}
print("yes" if max(t["tq"][0], t["ur"][0]) < min(t["tq"][1], t["ur"][1]) else "no %r" % t)' 2>&1)"
eq "quick steps run in parallel (their run times overlap)" "$overlap" "yes"
eq "changed() lists matching changed files" "$(cat lint.out)" "a.ts"
SHIPINETICS_CHANGED_FILES=list2 bin/verify --quick >/dev/null; eq "nothing relevant changed: step skips" "$(cat lint.out)" none
bin/verify --quick >/dev/null; eq "no list means check everything" "$(cat lint.out)" "__all__"
touch FAIL; out="$(bin/verify)"; rc=$?
eq "complete tier fails when a step fails" "$rc" 1
has "failing step's output is shown" "$out" "==> lint: FAILED"
has "failing step's log is shown" "$out" "lint-out"
done_testing
