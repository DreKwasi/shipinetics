#!/usr/bin/env bash
# Token usage log: counting, recording (hook, record and backfill), the report, one session, the HTML
# page, the hook switch and the command line. Fixtures are small transcripts in a scratch Claude
# folder; the expected numbers are worked out by hand in the comments, never read from the tool.
. "$(dirname "$0")/helpers.sh"

cdir="$scratch/claude"
log="$scratch/usage.tsv"
userdir="$XDG_CONFIG_HOME/shipinetics"
hook="$SY/scripts/usage-record.sh"
# pwd -P: git reports real paths, and the project path in a transcript must match it
mkdir -p "$scratch/ws"; ws="$(cd "$scratch/ws" && pwd -P)"
proj="$ws/app"
sibling="$ws/app2"            # same prefix as the project, another project
other="$ws/other"
linked="$ws/app-wt"           # a git worktree of the project, outside its folder
export CLAUDE_CONFIG_DIR="$cdir" SHIPINETICS_USAGE_LOG="$log" CLAUDE_PROJECT_DIR="$proj"

reset() {
  rm -rf "$cdir" "$log" "$log.lock" "$userdir" "$ws" "$scratch/tmpout"
  mkdir -p "$cdir" "$scratch/tmpout"
  new_repo "$proj"; new_repo "$sibling"; new_repo "$other"
  export TMPDIR="$scratch/tmpout" CLAUDE_PROJECT_DIR="$proj"
  unset SHIPINETICS_HOOKS_OFF
  cd "$proj" || exit 1
}

# ---- fixture builders
enc()  { printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'; }
tpath() { printf '%s/projects/%s/%s.jsonl' "$cdir" "${QF:-$(enc "$1")}" "$2"; }   # <cwd> <session id>
# ts <days ago> <minutes later>: a transcript time (UTC)
ts() { python3 -c 'import sys, datetime as d
t = d.datetime.now(d.timezone.utc) - d.timedelta(days=float(sys.argv[1])) + d.timedelta(minutes=int(sys.argv[2]))
print(t.strftime("%Y-%m-%dT%H:%M:%S.000Z"))' "$1" "$2"; }
# mtime_at <file> <transcript time> <seconds later>: set the file's modification time
mtime_at() { python3 - "$@" <<'PY'
import datetime as d, os, sys
f, t, s = sys.argv[1:4]
e = d.datetime.strptime(t, "%Y-%m-%dT%H:%M:%S.000Z").replace(tzinfo=d.timezone.utc).timestamp() + int(s)
os.utime(f, (e, e))
PY
}
# asst <time> <cwd> <message id> <model> <input> <cache write> <cache read> <output> [effort]
# (the line gets "sessionId" when $ASID is set)
asst() {
  local eff="" sid=""
  [ -n "${9:-}" ] && eff="\"effort\":\"$9\","
  [ -n "${ASID:-}" ] && sid="\"sessionId\":\"$ASID\","
  printf '{"type":"assistant","timestamp":"%s","cwd":"%s","gitBranch":"main","entrypoint":"cli",%s%s"requestId":"req_%s","message":{"id":"%s","model":"%s","usage":{"input_tokens":%s,"cache_creation_input_tokens":%s,"cache_read_input_tokens":%s,"output_tokens":%s}}}\n' \
    "$1" "$2" "$sid" "$eff" "$3" "$3" "$4" "$5" "$6" "$7" "$8"
}
# quick <cwd> <session id> <title> <time> <input> <cache write> <cache read> <output>: one-call session
# (in the folder $QF when it is set, else the one Claude Code would use)
quick() {
  local f; f="$(tpath "$1" "$2")"; mkdir -p "$(dirname "$f")"
  { printf '{"type":"custom-title","customTitle":"%s"}\n' "$3"
    asst "$4" "$1" "msg_$2" claude-opus-5-5 "$5" "$6" "$7" "$8" high; } >"$f"
}

# col <session> <agent> <model> <field>: a value of the log row
col() { awk -F'\t' -v s="$1" -v a="$2" -v m="$3" -v f="$4" \
  'NR == 1 { for (i = 1; i <= NF; i++) h[$i] = i; next }
   $h["session_id"] == s && $h["agent"] == a && $h["model"] == m { print $h[f] }' "$log"; }
# scol <session> <field>: a value that every row of the session shares (first row)
scol() { awk -F'\t' -v s="$1" -v f="$2" \
  'NR == 1 { for (i = 1; i <= NF; i++) h[$i] = i; next } $h["session_id"] == s { print $h[f]; exit }' "$log"; }
nrows() { grep -c "^$1	" "$log" 2>/dev/null || true; }
# wait_until <command>: poll up to 10 s for the command to succeed (the hook works in the background)
wait_until() { local i=0; while [ "$i" -lt 100 ]; do eval "$1" 2>/dev/null && return 0; sleep 0.1; i=$((i + 1)); done; return 1; }
run_hook() { printf '{"hook_event_name":"SessionEnd","transcript_path":"%s"}' "$1" | "$hook" >/dev/null 2>&1; RC=$?; }
rec() { python3 "$SY/scripts/usage.py" record "$1" >/dev/null 2>&1; RC=$?; }   # record, in the foreground
sq() { printf '%s\n' "$1" | tr -s ' '; }    # squeeze runs of spaces so table columns compare
usage() { OUT="$(shipinetics-usage "$@" 2>"$scratch/err")"; RC=$?; ERR="$(cat "$scratch/err")"; }

# ---- the session fixture for counting
# Main transcript S1 (every line carries its sessionId):
#   opus msg_1, written three times (once for each content block) with growing and shrinking usage;
#   opus msg_2 and msg_3; sonnet msg_4; a <synthetic> entry (no API call); opus msg_zero, whose
#   usage is all zero (no API call); two lines copied from a parent session (another sessionId),
#   one earlier and one later than the whole session.
# Subagent "tester" (agent-a, from its meta.json): opus msg_s1, written twice.
# Subagent without a meta.json (agent-b): sonnet msg_s2, and msg_3 again (the main agent's call).
S1="11111111-aaaa-4aaa-8aaa-000000000001"
build_s1() {
  local f folder; f="$(tpath "$proj" "$S1")"; folder="${f%.jsonl}"
  mkdir -p "$folder/subagents"
  T0="$(ts 1 0)"; T1="$(ts 1 1)"; T2="$(ts 1 2)"; T3="$(ts 1 3)"; T4="$(ts 1 4)"; T5="$(ts 1 5)"
  {
    ASID="9999aaaa-0000-4000-8000-parentsession" asst "$(ts 5 0)" "$proj" msg_hist1 claude-opus-5-5 500000 500000 500000 500000 high
    ASID=$S1
    asst "$T0" "$proj" msg_1 claude-opus-5-5 2 100 1000 7 low
    asst "$T0" "$proj" msg_1 claude-opus-5-5 2 60 1000 50 low
    asst "$T0" "$proj" msg_1 claude-opus-5-5 1 100 900 7 low
    printf '{"type":"user","timestamp":"%s","cwd":"%s","message":{"role":"user","content":"hi"}}\n' "$T1" "$proj"
    printf '{"type":"custom-title","customTitle":"My task"}\n'
    asst "$T2" "$proj" msg_2 claude-opus-5-5 3 200 2000 70 high
    asst "$T3" "$proj" msg_syn "<synthetic>" 999999 999999 999999 999999 high
    asst "$T3" "$proj" msg_zero claude-opus-5-5 0 0 0 0 high
    asst "$T4" "$proj" msg_3 claude-opus-5-5 1 0 0 10 high
    asst "$T5" "$proj" msg_4 claude-sonnet-5 7 0 5 9 medium
    ASID="9999aaaa-0000-4000-8000-parentsession" asst "$(ts 0 0)" "$proj" msg_hist2 claude-opus-5-5 500000 500000 500000 500000 high
    ASID=
  } >"$f"
  printf '{"customTitle":"Json title"}\n' >"$folder/custom-title.json"
  { asst "$T2" "$proj" msg_s1 claude-opus-5-5 4 10 20 30 high
    asst "$T2" "$proj" msg_s1 claude-opus-5-5 4 10 20 30 high; } >"$folder/subagents/agent-a.jsonl"
  printf '{"agentType":"tester"}\n' >"$folder/subagents/agent-a.meta.json"
  # a subagent file's sessionId is the parent's, not its own: those lines still count
  { ASID="agent-b-own-id" asst "$T3" "$proj" msg_s2 claude-sonnet-5 5 6 7 8
    ASID="agent-b-own-id" asst "$T4" "$proj" msg_3 claude-opus-5-5 1 0 0 10 high; } >"$folder/subagents/agent-b.jsonl"
  S1_FILE="$f"
}
O=claude-opus-5-5; N=claude-sonnet-5

# =================================================================== counting
reset; build_s1
usage backfill
eq "backfill exits 0" "$RC" 0
# main/opus: msg_1 once, each field at its largest over the repeats (input 2, cache write 100,
#   cache read 1000, output 50), msg_2, msg_3 -> 3 calls (msg_zero is no call; msg_3 in agent-b is
#   the same message again);
#   input 2+3+1 = 6, cache write 100+200 = 300, cache read 1000+2000 = 3000, output 50+70+10 = 130
eq "a message written several times counts once: calls" "$(col "$S1" main $O api_calls)" 3
eq "each field takes the largest value of the repeats: input" "$(col "$S1" main $O input)" 6
eq "each field takes the largest value of the repeats: cache write" "$(col "$S1" main $O cache_write)" 300
eq "each field takes the largest value of the repeats: cache read" "$(col "$S1" main $O cache_read)" 3000
eq "each field takes the largest value of the repeats: output" "$(col "$S1" main $O output)" 130
eq "the effort is the most common one among the messages" "$(col "$S1" main $O effort)" high
eq "a main-agent row for each model" "$(col "$S1" main $N api_calls)/$(col "$S1" main $N input)/$(col "$S1" main $N cache_read)/$(col "$S1" main $N output)/$(col "$S1" main $N effort)" "1/7/5/9/medium"
eq "a subagent has its own row, named by its agentType" "$(col "$S1" tester $O api_calls)/$(col "$S1" tester $O input)/$(col "$S1" tester $O cache_write)/$(col "$S1" tester $O cache_read)/$(col "$S1" tester $O output)" "1/4/10/20/30"
eq "a subagent without meta.json is called subagent" "$(col "$S1" subagent $N api_calls)/$(col "$S1" subagent $N input)/$(col "$S1" subagent $N effort)" "1/5/-"
eq "synthetic and all-zero messages, and a message in two files, make no extra rows" "$(nrows "$S1")" 4
eq "the title is the custom-title entry before custom-title.json" "$(scol "$S1" title)" "My task"
eq "the project is the cwd of the main transcript" "$(scol "$S1" project)" "$proj"
# the copied lines (other sessionId) are before and after the real ones: they set no time and no tokens
eq "the session starts at its first own timestamp" "$(scol "$S1" start)" "$T0"
eq "the session ends at its last own timestamp" "$(scol "$S1" end)" "$T5"

# the title falls back to custom-title.json
S2="22222222-aaaa-4aaa-8aaa-000000000002"
f="$(tpath "$proj" "$S2")"; mkdir -p "${f%.jsonl}"
asst "$(ts 1 0)" "$proj" msg_x claude-opus-5-5 1 1 1 1 high >"$f"
printf '{"customTitle":"Json title"}\n' >"${f%.jsonl}/custom-title.json"
usage backfill
eq "without a custom-title entry the title comes from custom-title.json" "$(scol "$S2" title)" "Json title"

# =================================================================== recording
# ---- the hook records the same rows as backfill
reset; build_s1
run_hook "$S1_FILE"
eq "the hook exits 0" "$RC" 0
wait_until '[ "$(nrows "$S1")" = 4 ]'
hook_rows="$(grep "^$S1	" "$log")"
rm -f "$log"; usage backfill
eq "the hook records the same rows as backfill" "$hook_rows" "$(grep "^$S1	" "$log")"

# ---- recording a session again replaces its rows and leaves the others alone
reset; build_s1
quick "$proj" "$S2" "Other session" "$(ts 1 0)" 11 12 13 14
rec "$S1_FILE"; rec "$(tpath "$proj" "$S2")"
s2_before="$(grep "^$S2	" "$log")"
asst "$(ts 1 6)" "$proj" msg_5 claude-opus-5-5 1 1 1 1 high >>"$S1_FILE"      # a fourth opus call
rec "$S1_FILE"
eq "recording again replaces the session's rows (new call counted)" "$(col "$S1" main $O api_calls)" 4
eq "recording again leaves no duplicate rows" "$(nrows "$S1")" 4
eq "recording again leaves other sessions' rows alone" "$(grep "^$S2	" "$log")" "$s2_before"

# ---- rows of agents and models that the new record lacks stay (Claude Code prunes subagent files)
rm -rf "${S1_FILE%.jsonl}"
rec "$S1_FILE"
eq "a record keeps the old rows of an agent that it lacks" "$(col "$S1" tester $O api_calls)/$(col "$S1" subagent $N output)" "1/8"
eq "and replaces the rows that it has" "$(col "$S1" main $O api_calls)/$(nrows "$S1")" "4/4"

# ---- a transcript without rows changes nothing
reset; build_s1
rec "$S1_FILE"
before="$(cat "$log")"
printf '{"type":"user","timestamp":"%s","cwd":"%s","message":{"role":"user","content":"hi"}}\n' "$(ts 0 0)" "$proj" >"$S1_FILE"
rec "$S1_FILE"
eq "a record with no rows exits 0" "$RC" 0
eq "a record with no rows leaves the log as it was" "$(cat "$log")" "$before"

# ---- a missing transcript records nothing and exits 0
reset
run_hook "$scratch/no/such/transcript.jsonl"
eq "a missing transcript path exits 0" "$RC" 0
printf '{}' | "$hook" >/dev/null 2>&1; eq "hook input without a path exits 0" "$?" 0
sleep 0.5
eq "a missing transcript records nothing" "$([ -e "$log" ] && echo log || echo none)" none

# ---- malformed log lines stay in the file
reset; build_s1
rec "$S1_FILE"
bad1="this is not a row"
bad2="$(awk -F'\t' -v OFS='\t' 'NR == 1 { for (i = 1; i <= NF; i++) h[$i] = i; next } NR == 2 { $h["api_calls"] = "x"; print; exit }' "$log")"
printf '%s\n%s\n' "$bad1" "$bad2" >>"$log"
quick "$proj" "$S2" "Other session" "$(ts 1 0)" 11 12 13 14
rec "$(tpath "$proj" "$S2")"
eq "malformed log lines stay after the valid rows when the log is rewritten" "$(tail -n 2 "$log")" "$bad1
$bad2"
eq "and the valid rows are all there" "$(nrows "$S1")/$(nrows "$S2")" "4/1"

# ---- backfill and a session that is in the log
reset
f="$(tpath "$proj" "$S1")"; mkdir -p "$(dirname "$f")"
E0="$(ts 0 -20)"
{ asst "$(ts 0 -30)" "$proj" msg_b1 claude-opus-5-5 1 1 1 1 high
  asst "$E0" "$proj" msg_b2 claude-opus-5-5 1 1 1 1 high; } >"$f"
usage backfill
eq "backfill records a session that the log does not have" "$(col "$S1" main $O api_calls)" 2
asst "$(ts 0 -30)" "$proj" msg_b1 claude-opus-5-5 1 1 1 1 high >"$f"      # a shorter transcript
mtime_at "$f" "$E0" 180
usage backfill
eq "backfill never replaces a session with one that ends earlier" "$(col "$S1" main $O api_calls)" 2
{ asst "$(ts 0 -30)" "$proj" msg_b1 claude-opus-5-5 1 1 1 1 high
  asst "$E0" "$proj" msg_b2 claude-opus-5-5 1 1 1 1 high
  asst "$(ts 0 -10)" "$proj" msg_b3 claude-opus-5-5 1 1 1 1 high; } >"$f"
mtime_at "$f" "$E0" 90
usage backfill
eq "backfill leaves a session whose file changed within 2 minutes of its logged end" "$(col "$S1" main $O api_calls)" 2
mtime_at "$f" "$E0" 180
usage backfill
eq "backfill records a session again when its file changed over 2 minutes after its logged end" "$(col "$S1" main $O api_calls)" 3

# ---- the hook returns without waiting for the work (Claude Code gives SessionEnd 1.5 s)
reset; build_s1
python3 - "$log" "$scratch/held" "$scratch/release" >/dev/null 2>&1 <<'PY' &
import fcntl, os, sys, time
log, held, release = sys.argv[1:4]
os.makedirs(os.path.dirname(log), exist_ok=True)
lock = open(log + ".lock", "w")
fcntl.flock(lock, fcntl.LOCK_EX)
open(held, "w").write("held")
end = time.time() + 20
while not os.path.exists(release) and time.time() < end:
    time.sleep(0.05)
PY
holder=$!
rm -f "$scratch/release"
wait_until "[ -e '$scratch/held' ]"
run_hook "$S1_FILE"
alive=dead; kill -0 "$holder" 2>/dev/null && alive=alive
eq "the hook returns while the recording is still waiting for the log" "$alive/$RC" "alive/0"
eq "nothing is recorded while the log is locked" "$([ -e "$log" ] && echo log || echo none)" none
: >"$scratch/release"
wait_until '[ "$(nrows "$S1")" = 4 ]'
eq "the recording finishes in the background" "$(nrows "$S1")" 4
wait "$holder" 2>/dev/null

# ---- the hook switch
reset
quick "$proj" "aaaaaaaa-0000-4000-8000-00000000000a" "Off by user" "$(ts 1 0)" 1 1 1 1
quick "$proj" "bbbbbbbb-0000-4000-8000-00000000000b" "Off by project" "$(ts 1 0)" 1 1 1 1
quick "$proj" "cccccccc-0000-4000-8000-00000000000c" "Off by env" "$(ts 1 0)" 1 1 1 1
quick "$proj" "dddddddd-0000-4000-8000-00000000000d" "Control" "$(ts 1 0)" 1 1 1 1
mkdir -p "$userdir" "$proj/.shipinetics"
printf 'hooks_off = usage\n' >"$userdir/config"
run_hook "$(tpath "$proj" aaaaaaaa-0000-4000-8000-00000000000a)"
printf 'hooks_off = usage\n' >"$proj/.shipinetics/config"
run_hook "$(tpath "$proj" bbbbbbbb-0000-4000-8000-00000000000b)"
rm -f "$proj/.shipinetics/config"; rm -f "$userdir/config"
SHIPINETICS_HOOKS_OFF=usage run_hook "$(tpath "$proj" cccccccc-0000-4000-8000-00000000000c)"
# the control: the user's config turns the hook off, but the project's own hooks_off replaces it
printf 'hooks_off = usage\n' >"$userdir/config"; printf 'hooks_off = pr\n' >"$proj/.shipinetics/config"
run_hook "$(tpath "$proj" dddddddd-0000-4000-8000-00000000000d)"
wait_until '[ "$(nrows dddddddd-0000-4000-8000-00000000000d)" = 1 ]'; sleep 1
eq "the control session is recorded" "$(nrows dddddddd-0000-4000-8000-00000000000d)" 1
eq "hooks_off = usage in the user's config records nothing" "$(nrows aaaaaaaa-0000-4000-8000-00000000000a)" 0
eq "hooks_off = usage in the project's config records nothing" "$(nrows bbbbbbbb-0000-4000-8000-00000000000b)" 0
eq "SHIPINETICS_HOOKS_OFF=usage records nothing" "$(nrows cccccccc-0000-4000-8000-00000000000c)" 0

# =================================================================== the report
# P1 in the project; P2 in a folder below it (a worktree path); P3 in a sibling project whose path
# starts the same; P4 in the project, 60 days old; P5 in a git worktree outside the project folder;
# P6 in the project, but stored in a Claude folder with another name.
P1="11110000-0000-4000-8000-0000000000a1"; P2="22220000-0000-4000-8000-0000000000a2"
P3="33330000-0000-4000-8000-0000000000a3"; P4="44440000-0000-4000-8000-0000000000a4"
P5="55550000-0000-4000-8000-0000000000a5"; P6="66660000-0000-4000-8000-0000000000a6"
build_report() {
  reset
  git -C "$proj" commit --allow-empty -q -m init
  git -C "$proj" worktree add -q -b feat "$linked"
  quick "$proj" "$P1" "Alpha job" "$(ts 1 0)" 1000 2000 3000 500
  quick "$proj/.worktrees/wt" "$P2" "Worktree job" "$(ts 5 0)" 500 1000 0 500
  quick "$sibling" "$P3" "Sibling job" "$(ts 1 0)" 1 1 1 1
  quick "$proj" "$P4" "Old job" "$(ts 60 0)" 1 1 1 1
  quick "$linked" "$P5" "Linked job" "$(ts 1 0)" 100 0 0 0
  QF=renamed-folder quick "$proj/pkg" "$P6" "Odd folder job" "$(ts 1 0)" 400 0 0 0
}
build_report
usage
eq "the report exits 0" "$RC" 0
has "the report lists the project's sessions" "$OUT" "Alpha job"
has "a folder below the project counts" "$OUT" "Worktree job"
has "a git worktree of the project counts" "$OUT" "Linked job"
has "the Claude folder name does not decide: the cwd in the transcript does" "$OUT" "Odd folder job"
hasnt "a sibling project with the same prefix does not count" "$OUT" "Sibling job"
hasnt "the default is the last 30 days" "$OUT" "Old job"
# Total = P1 + P2 + P5 + P6: 4 calls; input 1000+500+100+400 = 2000 = 2K, cache write 3000 = 3K,
# cache read 3000 = 3K, output 1000 = 1K, all 9000 = 9K
has "the Total row adds up the sessions" "$(sq "$OUT")" "Total 4 sessions 4 2K 3K 3K 1K 9K"
CLAUDE_PROJECT_DIR="$linked" usage
has "run from a worktree, the report has the main checkout's sessions" "$OUT" "Alpha job"
has "run from a worktree, the report has its own sessions" "$OUT" "Linked job"
hasnt "run from a worktree, a sibling project still does not count" "$OUT" "Sibling job"
usage --days 0
has "--days 0 keeps all sessions" "$OUT" "Old job"
usage --days 90
has "--days N keeps the sessions inside N days" "$OUT" "Old job"
usage --days 3
hasnt "--days N drops the sessions that started earlier" "$OUT" "Worktree job"
has "--days N keeps the newer sessions" "$OUT" "Alpha job"
usage --all
has "--all lists every project" "$OUT" "Sibling job"
# the log keeps the numbers after Claude Code deletes the transcript
rm -rf "$cdir/projects"
usage
has "a session stays in the report after its transcript is gone" "$OUT" "Alpha job"

# outside git the project is the folder itself
reset
plain="$ws/plain"; mkdir -p "$plain/sub" "$ws/plain2"
quick "$plain" "$P1" "Plain job" "$(ts 1 0)" 1 1 1 1
quick "$plain/sub" "$P2" "Plain sub job" "$(ts 1 0)" 1 1 1 1
quick "$ws/plain2" "$P3" "Plain sibling job" "$(ts 1 0)" 1 1 1 1
CLAUDE_PROJECT_DIR="$plain" usage
has "outside git the folder's own sessions count" "$OUT" "Plain job"
has "outside git a folder below it counts" "$OUT" "Plain sub job"
hasnt "outside git a sibling with the same prefix does not count" "$OUT" "Plain sibling job"

# numbers just under a unit round up to the next one
reset
quick "$proj" "$P1" "Big job" "$(ts 1 0)" 999999 0 0 0
usage
has "999,999 shows as 1M, never 1000K" "$(sq "$OUT")" "Total 1 sessions 1 1M 0 0 0 1M"

# ---- one session
build_report
touch -t 202601010000 "$(tpath "$proj" "$P1")"
touch -t 202601020000 "$(tpath "$proj/.worktrees/wt" "$P2")"
touch -t 202601030000 "$(tpath "$sibling" "$P3")"
touch -t 202501010000 "$(tpath "$proj" "$P4")"
touch -t 202501020000 "$(tpath "$linked" "$P5")"
touch -t 202501030000 "$(QF=renamed-folder tpath "$proj/pkg" "$P6")"
usage session
eq "session without an id exits 0" "$RC" 0
has "session without an id shows the project's newest session" "$OUT" "Worktree job"
hasnt "and not a newer session of another project" "$OUT" "Sibling job"
eq "session reads the transcript, not the log (no log was written)" "$([ -e "$log" ] && echo log || echo none)" none
CLAUDE_PROJECT_DIR="$other" usage session 3333
has "session with an id prefix finds it in any project" "$OUT" "Sibling job"
usage session 9999
eq "session exits 1 when no id matches" "$RC" 1
has "and says that no session was found" "$ERR" "no session"
rm -rf "$cdir/projects"
usage session
eq "session exits 1 when the project has no transcript" "$RC" 1

# a prefix that matches more than one session
reset
quick "$proj" "5555aaaa-0000-4000-8000-0000000000b1" "First of two" "$(ts 1 0)" 1 1 1 1
quick "$proj" "5555bbbb-0000-4000-8000-0000000000b2" "Second of two" "$(ts 1 0)" 1 1 1 1
usage session 5555
eq "session exits 2 when the prefix matches several sessions" "$RC" 2
has "and lists the first" "$OUT$ERR" "5555aaaa-0000-4000-8000-0000000000b1"
has "and lists the second" "$OUT$ERR" "5555bbbb-0000-4000-8000-0000000000b2"
usage session 5555a
eq "a longer prefix picks one" "$RC" 0

# a title with a tab and a new line prints on one line
reset
quick "$proj" "$P1" 'tab\there\nnew' "$(ts 1 0)" 1 1 1 1
usage session
has "session prints the title with tabs and new lines as spaces" "$OUT" "tab here new"

reset; build_s1
usage session 1111
# Totals over all agents and models: calls 3+1+1+1 = 6; input 6+7+4+5 = 22; cache write
# 300+0+10+6 = 316; cache read 3000+5+20+7 = 3032; output 130+9+30+8 = 177
has "session prints the Metrics tokens with exact comma-grouped totals" "$OUT" "| Tokens: input / cache write / cache read / output | 22 / 316 / 3,032 / 177 |"
has "session prints the Metrics API calls" "$OUT" "| API calls | 6 |"
has "session prints the span line" "$OUT" "| Session span (first to last message) |"
hasnt "session no longer calls the span Wall time" "$OUT" "Wall time"
has "session shows a row for the main agent and a model" "$(sq "$OUT" | grep -Fx 'main claude-opus-5-5 high 3 6 300 3K 130 3.4K')" "main claude-opus-5-5 high 3 6 300 3K 130 3.4K"
has "session shows a row for the other model of the main agent" "$(sq "$OUT" | grep -Fx 'main claude-sonnet-5 medium 1 7 0 5 9 21')" "main claude-sonnet-5 medium 1 7 0 5 9 21"
has "session shows a row for a named subagent" "$(sq "$OUT" | grep -Fx 'tester claude-opus-5-5 high 1 4 10 20 30 64')" "tester claude-opus-5-5 high 1 4 10 20 30 64"
has "session shows a row for an unnamed subagent" "$(sq "$OUT" | grep -Fx 'subagent claude-sonnet-5 - 1 5 6 7 8 26')" "subagent claude-sonnet-5 - 1 5 6 7 8 26"
transcript_out="$OUT"
usage backfill; rm -rf "$cdir/projects"
usage session 1111
eq "session falls back to the log when the transcript is gone: exit" "$RC" 0
has "and prints the same Metrics tokens" "$OUT" "| Tokens: input / cache write / cache read / output | 22 / 316 / 3,032 / 177 |"
has "and the same API calls" "$OUT" "| API calls | 6 |"
has "and the per-agent rows" "$(sq "$OUT" | grep -Fx 'tester claude-opus-5-5 high 1 4 10 20 30 64')" "tester claude-opus-5-5 high 1 4 10 20 30 64"

# =================================================================== the HTML page
reset
evil='</script><script>alert(1)</script>'
quick "$proj" "$S1" "$evil" "$(ts 1 0)" 5 6 7 8
quick "$proj" "$S2" "Old one" "$(ts 60 0)" 1 1 1 1
usage html
page="$(printf '%s\n' "$OUT" | head -n 1)"
case "$page" in "$scratch/tmpout/"*) ok "html prints a path in \$TMPDIR when there is no .shipinetics folder" ;; *) bad "html path in TMPDIR" "got [$page]" ;; esac
eq "html writes the page it names" "$([ -f "$page" ] && echo file || echo none)" file
eq "the page keeps no __USAGE_ placeholder" "$(grep -c '__USAGE_' "$page" || true)" 0
eq "a title cannot add a script element to the page" "$(grep -o '<script' "$page" | wc -l | tr -d ' ')" "$(grep -o '<script' "$SY/scripts/usage-page.html" | wc -l | tr -d ' ')"
embed() { python3 - "$1" "$2" <<'PY'
import json, re, sys
page = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'<script type="application/json" id="usage-data">(.*?)</script>', page, re.S)
data = json.loads(m.group(1))
if sys.argv[2] == "row":
    r = [x for x in data["rows"] if x["title"] != "Old one"][0]
    print(r["title"], r["input"], r["cache_write"], r["cache_read"], r["output"])
elif sys.argv[2] == "rows":
    print(len(data["rows"]))
else:
    print(data.get(sys.argv[2]))
PY
}
eq "the embedded data keeps the title and the tokens" "$(embed "$page" row)" "$evil 5 6 7 8"
eq "the embedded rows are not cut by the date range" "$(embed "$page" rows)" 2
eq "the page's initial date range is 30 days by default" "$(embed "$page" days)" 30
usage html --days 7
eq "html --days N sets the initial date range" "$(embed "$(printf '%s\n' "$OUT" | head -n 1)" days)" 7
eq "and still embeds all the rows" "$(embed "$(printf '%s\n' "$OUT" | head -n 1)" rows)" 2
usage html --days 0
eq "html --days 0 is all time" "$(embed "$(printf '%s\n' "$OUT" | head -n 1)" days)" 0

usage html --out "$scratch/chosen.html"
eq "html --out writes there and prints the path" "$(printf '%s\n' "$OUT" | head -n 1)/$([ -f "$scratch/chosen.html" ] && echo file)" "$scratch/chosen.html/file"

mkdir -p "$proj/.shipinetics"
usage html
page="$(printf '%s\n' "$OUT" | head -n 1)"
case "$page" in "$proj/.shipinetics/explainers/"[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-token-usage.html) ok "html defaults to .shipinetics/explainers/<date>-token-usage.html" ;; *) bad "html default path" "got [$page]" ;; esac
eq "and writes the page there" "$([ -f "$page" ] && echo file || echo none)" file
rm -rf "$proj/.shipinetics"; mkdir -p "$ws/.shipinetics"
usage html
page="$(printf '%s\n' "$OUT" | head -n 1)"
case "$page" in "$ws/.shipinetics/explainers/"*-token-usage.html) ok "html finds a .shipinetics folder above the project" ;; *) bad "html .shipinetics above the project" "got [$page]" ;; esac

# =================================================================== the command line
usage --help
eq "--help exits 0" "$RC" 0
has "--help prints the usage" "$OUT" "shipinetics-usage session [id]"
has "--help prints the exit codes" "$OUT" "Exit codes"
hasnt "--help prints no code lines (set)" "$OUT" "set -uo pipefail"
hasnt "--help prints no code lines (exec)" "$OUT" "exec python3"
usage --bogus
eq "an unknown option exits 2" "$RC" 2
usage session --bogus
eq "an unknown option of a command exits 2" "$RC" 2

# =================================================================== the plugin's files
sess="$(python3 -c 'import json, sys
h = json.load(open(sys.argv[1]))["hooks"]["SessionEnd"]
print(" ".join(x["command"] for g in h for x in g["hooks"]))' "$SY/hooks/hooks.json")"
has "hooks.json runs usage-record.sh for SessionEnd" "$sess" "scripts/usage-record.sh"
eq "usage-record.sh is executable" "$([ -x "$hook" ] && echo yes || echo no)" yes
done_testing
