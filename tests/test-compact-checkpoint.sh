# Docs before /compact (docs/specs/compact-checkpoint.md): the PreCompact hook and shipinetics-checkpoint.
. "$(dirname "$0")/helpers.sh"

# A set-up project with code, a worksheet folder and a feedback log
p="$scratch/proj"; new_repo "$p"
mkdir -p "$p/.shipinetics" "$p/src" "$p/docs/worksheets"
: >"$p/.shipinetics/config"
printf '.shipinetics/.cache/\n' >"$p/.gitignore"
echo one >"$p/src/app.ts"
echo "# W" >"$p/docs/worksheets/2026-11-22-login.md"
echo "# Feedback" >"$p/docs/agent-feedback.md"
git -C "$p" add -A; git -C "$p" commit -qm init
mkdir -p "$p/.shipinetics/.cache"; echo "2026-11-22-login" >"$p/.shipinetics/.cache/current-worksheet"
blocked="$p/.shipinetics/.cache/compact-blocked"

# compact [trigger] [dir]: run the PreCompact hook with Claude Code's input; sets RC, OUT (stdout), ERR (stderr)
compact() {
  local trig="${1:-manual}" dir="${2:-$p}"
  printf '{"hook_event_name":"PreCompact","trigger":"%s","custom_instructions":null,"cwd":"%s"}' "$trig" "$dir" |
    bash "$SY/scripts/compact-checkpoint.sh" >"$scratch/out" 2>"$scratch/err"
  RC=$?; OUT="$(cat "$scratch/out")"; ERR="$(cat "$scratch/err")"
}
record() { (cd "$p" && shipinetics-checkpoint record >/dev/null 2>&1); }
check() { (cd "$p" && shipinetics-checkpoint check >/dev/null 2>&1); echo $?; }
# age_block <seconds>: make the hook's last stop look that many seconds old
age_block() {
  local fp="" t=""
  [ -f "$blocked" ] || return 0   # no stop recorded: the next check fails on its own
  read -r fp t <"$blocked"
  printf '%s %s\n' "$fp" "$(( $(date +%s) - $1 ))" >"$blocked"
}
# keeps <name>: AC4, the summary instructions keep the worksheet, the criteria, the unwritten decisions
# and terms, and the next step
keeps() {
  has "compact-checkpoint AC4: $1: the summary keeps the current worksheet's name" "$OUT" "2026-11-22-login"
  has "compact-checkpoint AC4: $1: the summary keeps the acceptance criteria done and open" "$OUT" "acceptance criteria are done, and which are still open"
  has "compact-checkpoint AC4: $1: the summary keeps decisions and terms not yet written down" "$OUT" "Decisions and terms"
  has "compact-checkpoint AC4: $1: the summary keeps the next step" "$OUT" "next step"
}

# ---- AC1: no checkpoint at the current code: /compact stops and says what to do
hooks="$(python3 -c 'import json,sys
for g in json.load(open(sys.argv[1]))["hooks"].get("PreCompact", []):
    for h in g.get("hooks", []):
        print(g.get("matcher", ""), h.get("command", ""))' "$SY/hooks/hooks.json")"
has "compact-checkpoint AC1: Claude Code runs the hook for a manual /compact" "$hooks" "manual \"\${CLAUDE_PLUGIN_ROOT}\"/scripts/compact-checkpoint.sh"

for case in "never recorded" "recorded before the code changed"; do
  rm -f "$blocked" "$p/.shipinetics/.cache/docs-checkpoint"
  if [ "$case" = "recorded before the code changed" ]; then record; echo two >"$p/src/app.ts"; fi
  compact
  eq "compact-checkpoint AC1: $case: the hook stops /compact (exit 2)" "$RC" 2
  has "compact-checkpoint AC1: $case: the message says to run the checkpoint skill" "$ERR" "Run /shipinetics:checkpoint"
  has "compact-checkpoint AC1: $case: then /compact again" "$ERR" "Then run /compact again"
  has "compact-checkpoint AC1: $case: and that a second /compact skips the docs" "$ERR" "To compact now without the docs, run /compact again within 10 minutes"
  has "compact-checkpoint AC1: $case: and names the off switch" "$ERR" "hooks_off"
done

# ---- AC2: a second /compact within 10 minutes, at the same code, runs
for age in 0 540; do
  rm -f "$blocked"; compact; age_block "$age"; compact
  eq "compact-checkpoint AC2: a second /compact $age seconds after the stop runs" "$RC" 0
  [ "$age" = 540 ] && keeps "a second /compact"
done
rm -f "$blocked"; compact; age_block 660; compact
eq "compact-checkpoint AC2: a second /compact 11 minutes after the stop is stopped again" "$RC" 2
rm -f "$blocked"; compact; echo three >"$p/src/app.ts"; compact
eq "compact-checkpoint AC2: a second /compact within 10 minutes runs, even after the code changed" "$RC" 0
# The hook can't record the stop (the cache folder is read-only): /compact runs
rm -f "$blocked"; echo four >"$p/src/app.ts"; chmod 555 "$p/.shipinetics/.cache"
if [ -w "$p/.shipinetics/.cache" ]; then
  printf '  skip  compact-checkpoint AC2: unwritable cache (this user can write a read-only folder)\n'
else
  compact
  eq "compact-checkpoint AC2: when the stop can't be recorded, /compact runs" "$RC" 0
fi
chmod 755 "$p/.shipinetics/.cache"

# ---- AC3: a checkpoint recorded at the current code lets /compact run
rm -f "$blocked"; record; compact
eq "compact-checkpoint AC3: after shipinetics-checkpoint record, /compact runs" "$RC" 0
eq "compact-checkpoint AC3: and nothing is shown as a stop" "$ERR" ""
keeps "after a checkpoint"

# ---- AC5: the hook does nothing for automatic compaction, outside a set-up project, or when switched off
echo four >"$p/src/app.ts"   # no checkpoint for this code: a manual /compact would stop
rm -f "$blocked"
compact auto
eq "compact-checkpoint AC5: automatic compaction: no output, exit 0" "$RC|$OUT|$ERR" "0||"
eq "compact-checkpoint AC5: automatic compaction leaves no stop behind" "$([ -e "$blocked" ] && echo yes || echo no)" no
plain="$scratch/plain"; new_repo "$plain"; echo x >"$plain/a"; git -C "$plain" add -A; git -C "$plain" commit -qm init
compact manual "$plain"
eq "compact-checkpoint AC5: outside a set-up project: no output, exit 0" "$RC|$OUT|$ERR" "0||"
printf 'hooks_off = compact\n' >"$p/.shipinetics/config"; compact
eq "compact-checkpoint AC5: hooks_off = compact: no output, exit 0" "$RC|$OUT|$ERR" "0||"
: >"$p/.shipinetics/config"
SHIPINETICS_HOOKS_OFF=compact compact
eq "compact-checkpoint AC5: SHIPINETICS_HOOKS_OFF=compact: no output, exit 0" "$RC|$OUT|$ERR" "0||"

# ---- AC6: shipinetics-checkpoint check
rm -f "$p/.shipinetics/.cache/docs-checkpoint"
eq "compact-checkpoint AC6: check exits 1 when no checkpoint was recorded" "$(check)" 1
record
eq "compact-checkpoint AC6: check exits 0 right after record" "$(check)" 0
echo "- [x] AC1" >>"$p/docs/worksheets/2026-11-22-login.md"
eq "compact-checkpoint AC6: editing only the worksheet keeps the checkpoint" "$(check)" 0
echo "- slow test run" >>"$p/docs/agent-feedback.md"
eq "compact-checkpoint AC6: editing only the feedback log keeps the checkpoint" "$(check)" 0
echo five >"$p/src/app.ts"
eq "compact-checkpoint AC6: check exits 1 after the code changed" "$(check)" 1

# ---- AC7: the skill is a set of instructions for the agent. Code can see only that the skill which
# the hook names exists, and that it ends with the record command that AC3 reads.
skill="$SY/skills/checkpoint/SKILL.md"
eq "compact-checkpoint AC7: /shipinetics:checkpoint exists (skills/checkpoint/SKILL.md, name: checkpoint)" \
  "$(sed -n 's/^name: //p' "$skill" 2>/dev/null | head -n 1)" "checkpoint"
has "compact-checkpoint AC7: the skill runs shipinetics-checkpoint record" "$(cat "$skill" 2>/dev/null)" "shipinetics-checkpoint record"

done_testing
