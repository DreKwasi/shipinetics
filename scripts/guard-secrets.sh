#!/usr/bin/env bash
# PreToolUse hook for Bash and Read. Keeps secret values out of the agent's context.
#
# Secrets live in a vault (e.g. Google Secret Manager) and reach processes as environment
# variables. The agent never needs to see their values, so this blocks:
#   - dumping the environment (env, printenv, export -p, declare -x, /proc/*/environ, ps e)
#   - inline interpreter one-liners that read the environment (node -e "process.env...", python -c "os.environ...")
#   - echoing or printing variables whose names look like secrets
#   - reading a vault directly (gcloud secrets versions access, vault kv get, aws secretsmanager, op read, ...)
#   - reading credential files (gcloud ADC, ~/.aws/credentials, SSH keys, .netrc, ...)
#
# Active in every project, because secrets in your shell environment are exposed everywhere.
# Run things that need secrets through bin/with-secrets, which injects them without printing them.
# Start Claude Code with SHIPYARD_ALLOW_ENV_READ=1 to turn this off for a session.
#
# It's a backstop that matches command text, not a sandbox. The stronger layer is
# CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1, which strips credentials from every command Claude runs.

set -uo pipefail

input="$(cat)"
[ "${SHIPYARD_ALLOW_ENV_READ:-0}" = "1" ] && exit 0

jget() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r ".$1 // empty"
  else
    printf '%s' "$input" | python3 -c 'import json,sys
v = json.load(sys.stdin)
for p in sys.argv[1].split("."):
    v = v.get(p) if isinstance(v, dict) else None
sys.stdout.write("" if v is None else str(v))' "$1"
  fi
}

deny() {
  local reason="shipyard: blocked because this would $1. Secrets here live in a vault and reach the app as environment variables, so agents never read their values. To run something that needs secrets, use bin/with-secrets <command>. To check a variable is set without seeing it: [ -n \"\${NAME+x}\" ] && echo set. If the user really wants this, they can run it themselves or start Claude Code with SHIPYARD_ALLOW_ENV_READ=1."
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg r "$reason" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  else
    python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": sys.argv[1]}}))' "$reason"
  fi
  exit 0
}

creds='\.config/gcloud|application_default_credentials\.json|\.aws/credentials|\.aws/config|\.azure/|\.ssh/id_|\.netrc|\.npmrc|\.pypirc|\.docker/config\.json|\.kube/config|\.git-credentials|\.infisical(/|[[:space:]"]|$)|\.railway(/|[[:space:]"]|$)'

tool="$(jget tool_name)"

if [ "$tool" = "Read" ]; then
  p="$(jget tool_input.file_path)"
  [[ "$p" =~ $creds ]] && deny "read a credential file ($p)"
  exit 0
fi

cmd="$(jget tool_input.command)"
[ -n "$cmd" ] || exit 0

nl=$'\n'
# Command position: start of the command, or after ; & | ( $( ` a newline or " -- " (as in evidence run -- cmd),
# optionally behind a wrapper.
pos='(^|[;&|(`'"$nl"']|\$\(|[[:space:]]--[[:space:]])[[:space:]]*((sudo|exec|command|nohup|time|[^[:space:];&|]*with-secrets)[[:space:]]+)*'

r_env="$pos"'env([[:space:]]+-[A-Za-z0-9]+)*[[:space:]]*($|[|;&>)`])'
r_printenv="$pos"'printenv([[:space:]]|$)'
r_export="$pos"'(export[[:space:]]+-p|export[[:space:]]*($|[;&|>])|declare[[:space:]]+-[A-Za-z]*[xp]|typeset[[:space:]]+-[A-Za-z]*x|set[[:space:]]*($|[;&|>])|compgen[[:space:]]+-[A-Za-z]*e)'
r_proc='/proc/[^[:space:]]*/environ'
r_ps="$pos"'ps[[:space:]]+([^;&|]*[[:space:]])?(e|eww?|auxe|axe|-[A-Za-z]*E)([[:space:]]|$)'
r_inline='(^|[^A-Za-z0-9_])(node|nodejs|deno|bun|tsx|ts-node|python|python3|ruby|perl|php|irb)([^A-Za-z0-9_].*)?(process\.env|import\.meta\.env|Deno\.env|Bun\.env|os\.environ|os\.getenv|ENV\[|ENV\.(fetch|to_h|each|keys)|getenv\(|System\.getenv|\$env:|GetEnvironmentVariable)'
r_echo='(^|[^A-Za-z0-9_])(echo|printf|print)([[:space:]][^;&|]*)?\$\{?[A-Za-z0-9_]*(KEY|SECRET|TOKEN|PASSWORD|PASSWD|CREDENTIAL|PRIVATE|DSN)'
r_vault='gcloud[[:space:]]+((alpha|beta)[[:space:]]+)?secrets[[:space:]]+versions[[:space:]]+access|gcloud[[:space:]]+auth[[:space:]]+(application-default[[:space:]]+)?print-(access|identity)-token|vault[[:space:]]+(kv[[:space:]]+get|read)([[:space:]]|$)|aws[[:space:]]+secretsmanager[[:space:]]+get-secret-value|aws[[:space:]]+ssm[[:space:]]+get-parameters?[[:space:]].*--with-decryption|az[[:space:]]+keyvault[[:space:]]+secret[[:space:]]+(show|download)|(^|[^A-Za-z0-9_-])op[[:space:]]+(read|item[[:space:]]+get)([[:space:]]|$)|doppler[[:space:]]+secrets|infisical[[:space:]]+(secrets|export)|security[[:space:]]+find-(generic|internet)-password'

[[ "$cmd" =~ $r_env ]] && deny "print the whole environment"
[[ "$cmd" =~ $r_printenv ]] && deny "print environment variables"
[[ "$cmd" =~ $r_export ]] && deny "print exported variables"
[[ "$cmd" =~ $r_proc ]] && deny "read a process environment from /proc"
[[ "$cmd" =~ $r_ps ]] && deny "print process environments with ps"
[[ "$cmd" =~ $r_inline ]] && deny "read environment variables from an inline script"
shopt -s nocasematch
[[ "$cmd" =~ $r_echo ]] && deny "print a secret-looking variable"
shopt -u nocasematch
[[ "$cmd" =~ $r_vault ]] && deny "read a secret straight from the vault"
[[ "$cmd" =~ $creds ]] && deny "touch a credential file"

exit 0
