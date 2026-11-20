#!/usr/bin/env bash
# PreToolUse hook for Bash and Read. Keeps secret values out of the agent's context.
#
# Secrets live in a vault (e.g. Google Secret Manager) and reach processes as environment
# variables. The agent never needs to see their values, so this blocks:
#   - dumping the environment (env, printenv, export -p, declare -x, /proc/*/environ, ps e)
#   - inline interpreter one-liners that read the environment (node -e "process.env...", python -c "os.environ...")
#   - echoing or printing variables whose names look like secrets
#   - reading a vault directly (gcloud secrets versions access, vault kv get, aws secretsmanager, op read, ...)
#   - reading or naming a secret file: by default gcloud ADC, ~/.aws/credentials, SSH keys,
#     .netrc and the like. You choose the files with a secret-paths list (one glob per line) in the
#     project's .shipinetics/ or in ~/.config/shipinetics/ for every project. See sy_secret_paths.
#
# Active in every project, because secrets in your shell environment are exposed everywhere.
# Switch it off with "hooks_off = secrets" in the project or user config (see sy_hook_off).
# Run things that need secrets through bin/with-secrets (or the project's secrets_runner), which
# injects them without printing them.
#
# Not judged: reads of variables that never hold secrets (HOME, PATH, TMPDIR, NODE_ENV, CI and the
# rest of SY_SAFE_ENV in lib.sh, plus the project's env_safe_names), heredoc bodies written to a
# file, and the pattern given to grep, rg and similar search commands.
# Start Claude Code with SHIPINETICS_ALLOW_ENV_READ=1 to turn this off for a session.
#
# It's a backstop that matches command text, not a sandbox. The stronger layer is
# CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1, which strips credentials from every command Claude runs.

set -uo pipefail

input="$(cat)"
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
harness="$(sy_hook_harness "$input")"
noop() { sy_hook_noop "$harness"; exit 0; }

sy_flag ALLOW_ENV_READ && noop
cwd="$(sy_hook_cwd "$input")"
root="$(sy_root "$cwd" 2>/dev/null)" || root=""
sy_hook_off secrets "$root" && noop

runner="bin/with-secrets"
[ -n "$root" ] && runner="$(sy_cfg "$root" secrets_runner)"

deny() {
  local reason="shipinetics: blocked because this would $1. Secrets here live in a vault and reach the app as environment variables, so agents never read their values. To run something that needs secrets, use $runner <command>. To check a variable is set without seeing it: [ -n \"\${NAME+x}\" ] && echo set. If the user really wants this, they can run it themselves or start the session with SHIPINETICS_ALLOW_ENV_READ=1."
  sy_hook_pretool_reply "$harness" deny "$reason"
  exit 0
}

secret_paths=()
while IFS= read -r g; do [ -n "$g" ] && secret_paths+=("$g"); done < <(sy_secret_paths "$root")
# secret_file <path>: deny if the path is on the secret-paths list
secret_file() {
  [ "${#secret_paths[@]}" -gt 0 ] && sy_secret_match "$1" "${secret_paths[@]}" &&
    deny "$2 a secret file ($1 matches '$SY_MATCHED' in the secret-paths list)"
}

tool="$(sy_hook_tool "$input")"

case "$tool" in
  Read|read_file|view_file)
    secret_file "$(sy_hook_file_path "$input")" "read"
    noop
    ;;
esac

cmd="$(sy_hook_command "$input")"
[ -n "$cmd" ] || noop
# Judge only what would run. If perl is missing, judge the whole command.
clean="$(printf '%s' "$cmd" | sy_sanitize cmd "$(sy_safe_env_names "$root")")" && cmd="$clean"

nl=$'\n'
# Command position: start of the command, or after ; & | ( $( ` a newline or " -- " (as in evidence run -- cmd),
# optionally behind a wrapper (the secrets runner included).
wrap="with-secrets"
rb="${runner%% *}"; rb="${rb##*/}"
[ -n "$rb" ] && [ "$rb" != "with-secrets" ] && wrap="$wrap|$(printf '%s' "$rb" | sed 's/[][\.*^$+?(){}|]/\\&/g')"
pos='(^|[;&|(`'"$nl"']|\$\(|[[:space:]]--[[:space:]])[[:space:]]*((sudo|exec|command|nohup|time|[^[:space:];&|]*('"$wrap"'))[[:space:]]+)*'

r_env="$pos"'env([[:space:]]+-[A-Za-z0-9]+)*[[:blank:]]*($|[|;&>)`'"$nl"'])'
r_printenv="$pos"'printenv([[:space:]]|$)'
r_export="$pos"'(export[[:space:]]+-p|export[[:blank:]]*($|[;&|>'"$nl"'])|declare[[:space:]]+-[A-Za-z]*[xp]|typeset[[:space:]]+-[A-Za-z]*x|set[[:blank:]]*($|[;&|>'"$nl"'])|compgen[[:space:]]+-[A-Za-z]*e)'
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
# Any word in the command that names a secret file (quotes, redirections and separators split words).
while IFS= read -r w; do
  [ -n "$w" ] && secret_file "$w" "touch"
done < <(printf '%s\n' "$cmd" | tr -s " \t;&|()<>=\"'\`" '\n')

noop
