# The secrets guards: block what could print a secret, and leave alone what only mentions one.
. "$(dirname "$0")/helpers.sh"
p="$scratch/sec"; new_repo "$p"; cd "$p" || exit 1
mkdir -p .shipinetics
printf 'secrets_runner = bin/secrets\nenv_safe_names = APP_MODE\n' >.shipinetics/config

# bash_hook <command>: run the Bash secrets guard; sets OUT (empty means allowed)
bash_hook() {
  OUT="$(python3 -c 'import json, sys; print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}}))' "$1" |
    CLAUDE_PROJECT_DIR="$p" bash "$SY/scripts/guard-secrets.sh" 2>/dev/null)"
}
blocked() { bash_hook "$2"; has "blocked: $1" "$OUT" '"deny"'; }
allowed() { bash_hook "$2"; eq "allowed: $1" "$OUT" ""; }

js_secret='console.log(process.env.API_KEY)'
js_safe='console.log(process.env.NODE_ENV)'
py_safe='import os; print(os.environ["HOME"])'

blocked "whole environment" "env"
blocked "printenv of a secret" "printenv GITHUB_TOKEN"
blocked "echo of a secret" 'echo $API_KEY'
blocked "inline script reading a secret" "node -e '$js_secret'"
blocked "heredoc fed to python" "python3 - <<'PY'
import os; print(os.environ['API_KEY'])
PY"
blocked "heredoc fed to a shell" "cat <<EOF | sh
printenv
EOF"
blocked "grep through a credential file" "grep token ~/.npmrc"
has "deny names the project's secrets runner" "$OUT" "use bin/secrets <command>"
blocked "the runner doesn't hide a dump" "bin/secrets env"
# Text the shell would still run is never dropped (each was a hole in a first version).
blocked "unquoted heredoc to a file expands \$(...)" 'cat > /tmp/e <<EOF
$(env >&2)
EOF'
blocked "heredoc written by tee and piped to sh" "tee f <<'EOF' | sh
printenv
EOF"
blocked "heredoc written to a script that then runs" "cat > x.sh <<'EOF'
printenv
EOF
bash x.sh"
blocked "a here-string isn't a heredoc" 'cat > f <<<"hi"
env'
blocked "<< inside a comment isn't a heredoc" "cat > f # <<EOF
env
EOF"
blocked "a grep pattern with a substitution" 'grep "$(env >&2)" /dev/null'
blocked "an ANSI-C quoted pattern doesn't hide what follows" "grep \$'\\'' ; env ; echo ''"
blocked "grep -T takes no argument, so the path stays visible" "grep -a -T . /proc/self/environ"
blocked "grep -f has no pattern argument, so the path stays visible" "grep -f pats ~/.aws/credentials"

allowed "printenv of safe variables" "printenv HOME PATH"
allowed "inline script reading NODE_ENV" "node -e '$js_safe'"
allowed "inline script reading HOME" "python3 -c '$py_safe'"
allowed "project safe name" "node -e 'console.log(process.env.APP_MODE)'"
allowed "heredoc written to a file" "cat > notes.sh <<'EOF'
echo \$API_KEY
EOF"
allowed "grep pattern" "grep -n 'echo \$API_KEY' scripts/deploy.sh"
allowed "rg pattern after a node folder" "cd node-app && rg -t ts 'process.env' src"
allowed "git grep -e pattern" "git grep -e 'echo \$SECRET_KEY' -- scripts"
done_testing
