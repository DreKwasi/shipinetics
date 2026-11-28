# The setup skill's templates for a project: bin/lint-fix and .claude/settings.json.
. "$(dirname "$0")/helpers.sh"
tpl="$SY/skills/setup/templates"

# ---- bin/lint-fix: the LLM pass runs for a commit by Claude Code's agent, or when switched on, never when off
# A project with the template filled in: the linter's --fix does nothing, the check fails on a
# file that has BAD in it, and bin/llm-fix only logs that it ran.
p="$scratch/lint"; new_repo "$p"; mkdir -p "$p/bin"; cd "$p" || exit 1
python3 - "$tpl/bin/lint-fix" "$p/bin/lint-fix" <<'PY'
import sys
s = open(sys.argv[1]).read()
s = s.replace("{{FIX_CMD}}", "true").replace("{{CHECK_CMD}}", "! grep -q BAD").replace("{{FILE_REGEX}}", r"\.txt$")
open(sys.argv[2], "w").write(s)
PY
printf '#!/bin/sh\necho "$1" >>llm.log\n' >bin/llm-fix
chmod +x bin/lint-fix bin/llm-fix
echo ok >a.txt; git add -A; git commit -qm init
echo BAD >a.txt; git add a.txt

# llm_ran <env assignments...>: commit-time lint-fix with those variables; prints yes if bin/llm-fix ran
llm_ran() {
  rm -f llm.log
  env "$@" bin/lint-fix --staged >/dev/null 2>&1
  [ -f llm.log ] && echo yes || echo no
}
eq "teams-and-plans AC6: a person's commit (no variable set) doesn't call bin/llm-fix" "$(llm_ran)" no
eq "teams-and-plans AC6: a commit by Claude Code's agent (CLAUDE_CODE_CHILD_SESSION=1) calls bin/llm-fix" "$(llm_ran CLAUDE_CODE_CHILD_SESSION=1)" yes
eq "teams-and-plans AC6: CLAUDECODE=1 alone (an IDE terminal) doesn't call bin/llm-fix" "$(llm_ran CLAUDECODE=1)" no
eq "teams-and-plans AC6: SHIPINETICS_LLM_FIX=1 calls bin/llm-fix for a person too" "$(llm_ran SHIPINETICS_LLM_FIX=1)" yes
eq "teams-and-plans AC6: SHIPINETICS_LLM_FIX=0 never calls it, even for Claude Code's agent" "$(llm_ran CLAUDE_CODE_CHILD_SESSION=1 SHIPINETICS_LLM_FIX=0)" no

# ---- .claude/settings.json: valid JSON, and the effort level is left to the user
settings="$(python3 -c 'import json, sys
try: v = json.load(open(sys.argv[1]))
except Exception as e: print("invalid JSON: %s" % e); sys.exit()
print("has effortLevel" if "effortLevel" in v else "ok")' "$tpl/claude/settings.json")"
eq "teams-and-plans AC7: the settings template is valid JSON with no effortLevel key" "$settings" ok

# ---- safe-local-setup AC9: the .gitignore additions keep the example env files
g="$scratch/gi"; new_repo "$g"; cp "$tpl/gitignore-additions" "$g/.gitignore"
envs=""
for f in .env .env.local .env.example .env.sample; do
  if git -C "$g" check-ignore -q "$f"; then envs="$envs $f=ignored"; else envs="$envs $f=kept"; fi
done
eq "safe-local-setup AC9: .env and .env.local are ignored, .env.example and .env.sample are kept" "$envs" \
  " .env=ignored .env.local=ignored .env.example=kept .env.sample=kept"

done_testing
