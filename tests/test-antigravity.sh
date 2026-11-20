# Antigravity support: manifests, dual-harness hooks, companion detection and installer.
. "$(dirname "$0")/helpers.sh"

# ---- manifests match and are valid
ver_claude="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$SY/.claude-plugin/plugin.json")"
ver_agy="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$SY/plugin.json")"
eq "root plugin.json version matches .claude-plugin/plugin.json" "$ver_agy" "$ver_claude"

bad_fields="$(python3 -c 'import json,sys
allowed = {"name","displayName","version","description","author","logo","suggestedPrompts","homepage","repository","disabled"}
d = json.load(open(sys.argv[1]))
print(" ".join(sorted(set(d) - allowed)))' "$SY/plugin.json")"
eq "root plugin.json uses only Antigravity manifest fields" "$bad_fields" ""

hj_check="$(python3 -c 'import json,sys
h = json.load(open(sys.argv[1]))["shipinetics"]
ss = [x["command"] for x in h["SessionStart"]]
st = [x["command"] for x in h["Stop"]]
pt = {g["matcher"]: [x["command"] for x in g["hooks"]] for g in h["PreToolUse"]}
print("ss=" + ",".join(ss))
print("st=" + ",".join(st))
for m, cmds in sorted(pt.items()):
    print(m + "=" + ",".join(cmds))' "$SY/hooks.json")"
has "root hooks.json runs companions-notice.sh at SessionStart" "$hj_check" "ss=./scripts/companions-notice.sh"
has "root hooks.json runs usage-record.sh at Stop" "$hj_check" "st=./scripts/usage-record.sh"
has "root hooks.json wires guard-edits.sh to edit_file/write_file" "$hj_check" "edit_file|write_file"
has "root hooks.json wires guard-secrets.sh to run_command/read_file" "$hj_check" "run_command|read_file"
has "root hooks.json wires guard-pr.sh and guard-installs.sh to run_command" "$hj_check" "run_command=./scripts/guard-pr.sh,./scripts/guard-installs.sh"

# ---- Antigravity PreToolUse hooks run with PWD set to the plugin dir, not the project
p="$scratch/proj"; new_repo "$p"
mkdir -p "$p/.shipinetics" "$p/e2e/acceptance" "$p/src"
printf '.shipinetics/*\ne2e/acceptance/*\n' >"$p/.shipinetics/protected-paths"
printf 'e2e/*\n' >"$p/.shipinetics/test-paths"
printf 'secrets_runner = bin/secrets\n' >"$p/.shipinetics/config"
printf '.shipinetics/.cache/\n' >"$p/.gitignore"
echo old >"$p/e2e/acceptance/a.spec.ts"
echo app >"$p/src/app.ts"
stub_verify "$p/bin/verify"
git -C "$p" add -A; git -C "$p" commit -qm init

agy_hook() {
  local script="$1" payload="$2"
  OUT="$(cd "$SY" && printf '%s' "$payload" | PLUGIN_ROOT="$SY" bash "$SY/scripts/$script" 2>/dev/null)"
}
jfield() {
  local json="$1"; shift
  printf '%s' "$json" | python3 -c 'import json,sys
v = json.load(sys.stdin)
for k in sys.argv[1:]:
    v = v[int(k)] if isinstance(v, list) else v.get(k)
print("" if v is None else v)' "$@" 2>/dev/null || true
}

# guard-edits.sh
agy_hook guard-edits.sh "$(python3 -c 'import json,sys; print(json.dumps({"hookEventName":"PreToolUse","cwd":sys.argv[1],"workspacePaths":[sys.argv[1]],"toolCall":{"name":"edit_file","args":{"Path":sys.argv[2]}}}))' "$p" "$p/e2e/acceptance/a.spec.ts")"
eq "Antigravity edit guard denies existing protected file" "$(jfield "$OUT" decision)" "deny"
has "Antigravity edit guard points to pending folder" "$(jfield "$OUT" reason)" ".shipinetics/pending/e2e/acceptance/a.spec.ts"
hasnt "Antigravity edit guard uses native format (no hookSpecificOutput)" "$OUT" "hookSpecificOutput"

agy_hook guard-edits.sh "$(python3 -c 'import json,sys; print(json.dumps({"hookEventName":"PreToolUse","workspacePaths":[sys.argv[1]],"toolCall":{"name":"write_file","args":{"Path":sys.argv[2]}}}))' "$p" "$p/src/app.ts")"
eq "Antigravity edit guard pass-through returns empty stdout" "$OUT" ""

agy_hook guard-edits.sh "$(python3 -c 'import json,sys; print(json.dumps({"hookEventName":"PreToolUse","workspacePaths":[sys.argv[1]],"toolCall":{"name":"write_file","args":{"Path":sys.argv[2]}}}))' "$p" "$p/e2e/unit.spec.ts")"
eq "Antigravity edit guard does not deadlock test files when agentType is omitted" "$OUT" ""

agy_hook guard-edits.sh "$(python3 -c 'import json,sys; print(json.dumps({"hookEventName":"PreToolUse","agentType":"main","workspacePaths":[sys.argv[1]],"toolCall":{"name":"write_file","args":{"Path":sys.argv[2]}}}))' "$p" "$p/e2e/unit.spec.ts")"
eq "Antigravity edit guard enforces test ownership when agentType is provided" "$(jfield "$OUT" decision)" "deny"

agy_hook guard-edits.sh "$(python3 -c 'import json,sys; print(json.dumps({"hookEventName":"PreToolUse","agentType":"test-writer","workspacePaths":[sys.argv[1]],"toolCall":{"name":"write_file","args":{"Path":sys.argv[2]}}}))' "$p" "$p/e2e/unit.spec.ts")"
eq "Antigravity edit guard allows test-writer on test files when agentType is provided" "$OUT" ""

agy_hook guard-edits.sh "$(python3 -c 'import json,sys; print(json.dumps({"hookEventName":"PreToolUse","agentType":"test-writer","workspacePaths":[sys.argv[1]],"toolCall":{"name":"edit_file","args":{"Path":sys.argv[2]}}}))' "$p" "$p/src/app.ts")"
eq "Antigravity edit guard blocks test-writer on source when agentType is provided" "$(jfield "$OUT" decision)" "deny"

# guard-secrets.sh
agy_hook guard-secrets.sh "$(python3 -c 'import json,sys; print(json.dumps({"hookEventName":"PreToolUse","workspacePaths":[sys.argv[1]],"toolCall":{"name":"run_command","args":{"CommandLine":"env"}}}))' "$p")"
eq "Antigravity secrets guard denies env dump" "$(jfield "$OUT" decision)" "deny"
has "Antigravity secrets guard reads project secrets_runner from workspacePaths" "$(jfield "$OUT" reason)" "use bin/secrets <command>"

agy_hook guard-secrets.sh "$(python3 -c 'import json,sys; print(json.dumps({"hookEventName":"PreToolUse","workspacePaths":[sys.argv[1]],"toolCall":{"name":"read_file","args":{"Path":sys.argv[2]}}}))' "$p" "$HOME/.aws/credentials")"
eq "Antigravity secrets guard denies read_file on secret file" "$(jfield "$OUT" decision)" "deny"

agy_hook guard-secrets.sh "$(python3 -c 'import json,sys; print(json.dumps({"hookEventName":"PreToolUse","workspacePaths":[sys.argv[1]],"toolCall":{"name":"view_file","args":{"AbsolutePath":sys.argv[2]}}}))' "$p" "$HOME/.aws/credentials")"
eq "Antigravity secrets guard denies view_file on secret file" "$(jfield "$OUT" decision)" "deny"

agy_hook guard-secrets.sh "$(python3 -c 'import json,sys; print(json.dumps({"hookEventName":"PreToolUse","workspacePaths":[sys.argv[1]],"toolCall":{"name":"run_command","args":{"CommandLine":"echo hello"}}}))' "$p")"
eq "Antigravity secrets guard pass-through returns empty stdout" "$OUT" ""

# guard-installs.sh
agy_hook guard-installs.sh "$(python3 -c 'import json,sys; print(json.dumps({"hookEventName":"PreToolUse","workspacePaths":[sys.argv[1]],"toolCall":{"name":"run_command","args":{"CommandLine":"agy plugin install foo"}}}))' "$p")"
eq "Antigravity install guard asks on agy plugin install" "$(jfield "$OUT" decision)" "ask"

agy_hook guard-installs.sh "$(python3 -c 'import json,sys; print(json.dumps({"hookEventName":"PreToolUse","workspacePaths":[sys.argv[1]],"toolCall":{"name":"run_command","args":{"CommandLine":"npx skills add mattpocock/skills -g"}}}))' "$p")"
eq "Antigravity install guard asks on npx skills add" "$(jfield "$OUT" decision)" "ask"

agy_hook guard-installs.sh "$(python3 -c 'import json,sys; print(json.dumps({"hookEventName":"PreToolUse","workspacePaths":[sys.argv[1]],"toolCall":{"name":"run_command","args":{"CommandLine":"npm install left-pad"}}}))' "$p")"
eq "Antigravity install guard pass-through returns empty stdout" "$OUT" ""

# guard-pr.sh
git -C "$p" checkout -qb feat
mkdir -p "$p/docs/worksheets" "$p/docs/evidence/w"
printf '# W\n> Status: done\n- [x] AC1: ok\n' >"$p/docs/worksheets/w.md"
echo b >"$p/src/app.ts"
git -C "$p" add -A; git -C "$p" commit -qm code -m "Worksheet: w"
printf '> Commit: %s | Recorded: now\n| Criterion | Evidence | What |\n|---|---|---|\n| AC1 | terminal.log | ok |\n' "$(git -C "$p" rev-parse --short HEAD)" >"$p/docs/evidence/w/EVIDENCE.md"
echo '$ run' >"$p/docs/evidence/w/terminal.log"
git -C "$p" add -A; git -C "$p" commit -qm ev -m "Worksheet: w"
printf '## Evidence\n' >"$scratch/body.md"

agy_hook guard-pr.sh "$(python3 -c 'import json,sys; print(json.dumps({"hookEventName":"PreToolUse","workspacePaths":[sys.argv[1]],"toolCall":{"name":"run_command","args":{"CommandLine":"gh pr create --body-file " + sys.argv[2]}}}))' "$p" "$scratch/body.md")"
eq "Antigravity PR gate denies before verify" "$(jfield "$OUT" decision)" "deny"
has "Antigravity PR gate says verify hasn't passed" "$(jfield "$OUT" reason)" "complete verify hasn't passed"

(cd "$p" && shipinetics-verify >/dev/null)
agy_hook guard-pr.sh "$(python3 -c 'import json,sys; print(json.dumps({"hookEventName":"PreToolUse","workspacePaths":[sys.argv[1]],"toolCall":{"name":"run_command","args":{"CommandLine":"gh pr create --body-file " + sys.argv[2]}}}))' "$p" "$scratch/body.md")"
eq "Antigravity PR gate passes with empty stdout after verify" "$OUT" ""

# ---- SessionStart notice & Antigravity companion detection
plug="$scratch/plug"; mkdir -p "$plug"
cp -R "$SY/bin" "$SY/scripts" "$plug/"
printf 'alpha\tskill\talpha\trequired\tAlpha.\tinstall-alpha\tSAFE\n' >"$plug/companions.tsv"
printf 'Beta\tplugin\tbeta@mkt\trequired\tBeta.\tinstall-beta\tSAFE\n' >>"$plug/companions.tsv"

gdir="$scratch/gemini"
export GEMINI_CONFIG_DIR="$gdir"
OUT="$(cd "$plug" && printf '{"hookEventName":"SessionStart","workspacePaths":["%s"]}' "$p" | "$plug/scripts/companions-notice.sh" 2>/dev/null)"
has "Antigravity SessionStart notice emits injectSteps user_markdown" "$(jfield "$OUT" injectSteps 0 systemMessage metadata user_markdown)" "2 Shipinetics companions are missing."
has "Antigravity SessionStart notice emits model systemMessage" "$(jfield "$OUT" injectSteps 0 systemMessage systemMessage)" "alpha, Beta"

mkdir -p "$gdir/skills/alpha" "$gdir/plugins/beta"
echo x >"$gdir/skills/alpha/SKILL.md"
printf '{"name":"beta"}\n' >"$gdir/plugins/beta/plugin.json"
OUT="$("$plug/bin/shipinetics-companions" 2>&1)"
has "companion check finds skill in GEMINI_CONFIG_DIR/skills" "$OUT" "[installed] alpha"
has "companion check finds plugin in GEMINI_CONFIG_DIR/plugins" "$OUT" "[installed] Beta"

OUT="$(cd "$plug" && printf '{"hookEventName":"SessionStart","workspacePaths":["%s"]}' "$p" | "$plug/scripts/companions-notice.sh" 2>/dev/null)"
eq "Antigravity SessionStart notice returns empty stdout when all required companions are installed" "$OUT" ""

# Also check project .agents/skills and plugin-bundled skills
rm -rf "$gdir/skills/alpha"
mkdir -p "$gdir/plugins/bundle/skills/alpha"
echo x >"$gdir/plugins/bundle/skills/alpha/SKILL.md"
has "companion check finds skill inside an Antigravity plugin" "$("$plug/bin/shipinetics-companions" 2>&1)" "[installed] alpha"
rm -rf "$gdir/plugins/bundle"
mkdir -p "$p/.agents/skills/alpha"
echo x >"$p/.agents/skills/alpha/SKILL.md"
has "companion check finds skill in project .agents/skills" "$(cd "$p" && "$plug/bin/shipinetics-companions" 2>&1)" "[installed] alpha"

# ---- shipinetics-antigravity CLI
out="$(shipinetics-antigravity --help)"; rc=$?
eq "shipinetics-antigravity --help exits 0" "$rc" 0
has "shipinetics-antigravity --help prints usage" "$out" "shipinetics-antigravity install"

target="$gdir/plugins/shipinetics"
out="$(shipinetics-antigravity install --target "$target" 2>&1)"; rc=$?
eq "shipinetics-antigravity install exits 0" "$rc" 0
has "install reports generated agents" "$out" "Generated 6 Antigravity agent(s)"
eq "install symlinks skills to repo" "$(readlink "$target/skills")" "$SY/skills"
eq "install symlinks hooks.json to repo" "$(readlink "$target/hooks.json")" "$SY/hooks.json"

rev="$(cat "$target/agents/reviewer.md")"
has "generated reviewer sets subagent: true" "$rev" "subagent: true"
has "generated reviewer sets mainAgent: false" "$rev" "mainAgent: false"
has "generated reviewer maps tools to YAML list" "$rev" "tools: [read_file, run_command, manage_task, search_web]"
hasnt "generated reviewer drops Claude model field" "$rev" "model: opus"
hasnt "generated reviewer resolves CLAUDE_PLUGIN_ROOT" "$rev" '${CLAUDE_PLUGIN_ROOT}'

tw="$(cat "$target/agents/test-writer.md")"
has "generated test-writer includes edit_file and write_file" "$tw" "tools: [read_file, run_command, manage_task, edit_file, write_file]"

# Refuse to overwrite an unrelated non-empty directory
unrelated="$scratch/unrelated"; mkdir -p "$unrelated"; echo keep >"$unrelated/notes.txt"
out="$(shipinetics-antigravity install --target "$unrelated" 2>&1)"; rc=$?
eq "install refuses to overwrite unrelated directory" "$rc" 2
eq "unrelated directory stays intact" "$(cat "$unrelated/notes.txt")" "keep"

# link-skills preserves existing entries and is idempotent
mkdir -p "$gdir"
printf '{"entries":[{"path":"~/custom-skills"}]}\n' >"$gdir/skills.json"
out="$(shipinetics-antigravity link-skills 2>&1)"; rc=$?
eq "link-skills exits 0" "$rc" 0
sf_paths="$(python3 -c 'import json,sys; print(",".join(e["path"] for e in json.load(open(sys.argv[1]))["entries"]))' "$gdir/skills.json")"
eq "link-skills preserves existing entry and adds shared skill dirs" "$sf_paths" "~/custom-skills,~/.agents/skills,~/.claude/skills"
out2="$(shipinetics-antigravity link-skills 2>&1)"
has "link-skills is idempotent" "$out2" "already includes"

out="$(shipinetics-antigravity status --target "$target" 2>&1)"; rc=$?
eq "status exits 0 when installed, agents native, PATH set and skills linked" "$rc" 0
has "status reports 6/6 native agents" "$out" "Agents: 6/6 Antigravity-native"

# ---- shipinetics-usage reads Antigravity transcripts (backfill, report, session, Stop hook)
ag_home="$scratch/gemini-home"
ag_log="$scratch/ag-usage.tsv"
ag_sid="aaaaaaaa-1111-4111-8111-0000000000aa"
ag_tdir="$ag_home/antigravity/brain/$ag_sid/.system_generated/logs"
mkdir -p "$ag_tdir"
ag_t="$ag_tdir/transcript.jsonl"
t_now="$(python3 -c 'import datetime as d; print((d.datetime.now(d.timezone.utc) - d.timedelta(minutes=5)).strftime("%Y-%m-%dT%H:%M:%SZ"))')"
t_end="$(python3 -c 'import datetime as d; print((d.datetime.now(d.timezone.utc) - d.timedelta(minutes=1)).strftime("%Y-%m-%dT%H:%M:%SZ"))')"
python3 - "$ag_t" "$p/src/app.ts" "$t_now" "$t_end" <<'PY'
import json, sys
out, fpath, t0, t1 = sys.argv[1:5]
lines = [
    {"step_index": 0, "source": "USER_EXPLICIT", "type": "USER_INPUT", "status": "DONE",
     "created_at": t0, "content": "<USER_REQUEST>\nFix Antigravity usage tracking\n</USER_REQUEST>"},
    {"step_index": 1, "source": "MODEL", "type": "PLANNER_RESPONSE", "status": "DONE",
     "created_at": t0, "model": "gemini-4-carbon-medium",
     "input_tokens": 1200, "cache_read_tokens": 300, "output_tokens": 100,
     "tool_calls": [{"name": "read_file", "args": {"Path": json.dumps(fpath)}}]},
    {"step_index": 2, "source": "MODEL", "type": "PLANNER_RESPONSE", "status": "DONE",
     "created_at": t1, "model": "gemini-4-neon-high",
     "input_tokens": 800, "cache_read_tokens": 700, "output_tokens": 200},
    {"step_index": 3, "source": "MODEL", "type": "PLANNER_RESPONSE", "status": "DONE",
     "created_at": t1, "model": "gemini-4-neon-high",
     "input_tokens": 0, "cache_read_tokens": 0, "output_tokens": 0},
]
with open(out, "w") as f:
    for row in lines:
        f.write(json.dumps(row) + "\n")
PY

ag_out="$(cd "$p" && GEMINI_HOME="$ag_home" SHIPINETICS_USAGE_LOG="$ag_log" shipinetics-usage 2>&1)"
has "shipinetics-usage report lists Antigravity session by inferred git repo" "$ag_out" "Fix Antigravity usage tracking"
has "shipinetics-usage report sums Antigravity tokens (2K input, 1K cache read, 300 output)" "$(printf '%s\n' "$ag_out" | tr -s ' ')" "Total 1 sessions 2 2K 0 1K 300 3.3K"

ag_sess="$(cd "$p" && GEMINI_HOME="$ag_home" SHIPINETICS_USAGE_LOG="$ag_log" shipinetics-usage session aaaaaaaa 2>&1)"
has "shipinetics-usage session finds Antigravity session by conversation id prefix" "$ag_sess" "Session $ag_sid"
has "shipinetics-usage session shows carbon model row" "$ag_sess" "gemini-4-carbon-medium"
has "shipinetics-usage session shows neon model row" "$ag_sess" "gemini-4-neon-high"
has "shipinetics-usage session prints exact comma totals" "$ag_sess" "| Tokens: input / cache write / cache read / output | 2,000 / 0 / 1,000 / 300 |"
has "shipinetics-usage session skips zero-token steps (2 calls)" "$ag_sess" "| API calls | 2 |"

# Antigravity Stop hook records transcriptPath + workspacePaths into usage log
rm -f "$ag_log" "$ag_log.lock"
ag_sid2="bbbbbbbb-2222-4222-8222-0000000000bb"
ag_tdir2="$ag_home/antigravity/brain/$ag_sid2/.system_generated/logs"
mkdir -p "$ag_tdir2"
python3 - "$ag_tdir2/transcript.jsonl" "$t_now" <<'PY'
import json, sys
out, t0 = sys.argv[1:3]
with open(out, "w") as f:
    f.write(json.dumps({"step_index": 0, "type": "USER_INPUT", "created_at": t0, "content": "Stop hook session"}) + "\n")
    f.write(json.dumps({"step_index": 1, "type": "PLANNER_RESPONSE", "created_at": t0, "model": "gemini-4-neon-high",
                        "input_tokens": 500, "cache_read_tokens": 100, "output_tokens": 50}) + "\n")
PY
(cd "$SY" && printf '{"hookEventName":"Stop","transcriptPath":"%s","workspacePaths":["%s"]}' "$ag_tdir2/transcript.jsonl" "$p" |
  GEMINI_HOME="$ag_home" SHIPINETICS_USAGE_LOG="$ag_log" bash "$SY/scripts/usage-record.sh" >/dev/null 2>&1)
i=0
while [ "$i" -lt 50 ] && ! grep -q "^$ag_sid2	" "$ag_log" 2>/dev/null; do sleep 0.1; i=$((i + 1)); done
has "Antigravity Stop hook records session into usage log with workspace path" "$(grep "^$ag_sid2	" "$ag_log" 2>/dev/null || true)" "$p"

done_testing
