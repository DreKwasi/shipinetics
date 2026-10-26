# The secrets guards: block what could print a secret, and leave alone what only mentions one.
. "$(dirname "$0")/helpers.sh"
p="$scratch/sec"; new_repo "$p"; cd "$p" || exit 1
mkdir -p .shipinetics src docs
printf 'src/config.ts\n' >.shipinetics/env-allowed-paths
printf 'secrets_runner = bin/secrets\nenv_safe_names = APP_MODE\n' >.shipinetics/config
echo 'export const x = 1' >src/app.ts

# bash_hook <command>: run the Bash secrets guard; sets OUT (empty means allowed)
bash_hook() {
  OUT="$(python3 -c 'import json, sys; print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}}))' "$1" |
    CLAUDE_PROJECT_DIR="$p" bash "$SY/scripts/guard-secrets.sh" 2>/dev/null)"
}
blocked() { bash_hook "$2"; has "blocked: $1" "$OUT" '"deny"'; }
allowed() { bash_hook "$2"; eq "allowed: $1" "$OUT" ""; }

# edit_hook <file> <new text>: run the edit guard on an Edit that adds the text; sets OUT
edit_hook() {
  OUT="$(python3 -c 'import json, sys; print(json.dumps({"tool_name": "Edit", "tool_input": {"file_path": sys.argv[1], "old_string": "", "new_string": sys.argv[2]}}))' "$p/$1" "$2" |
    CLAUDE_PROJECT_DIR="$p" bash "$SY/scripts/guard-edits.sh" 2>/dev/null)"
}

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

edit_hook src/app.ts "$js_secret"; has "code: new secret read is blocked" "$OUT" "would read environment variables"
edit_hook src/app.ts "$js_safe"; eq "code: NODE_ENV read is allowed" "$OUT" ""
edit_hook README.md "$js_secret"; eq "docs: an example in Markdown is allowed" "$OUT" ""
edit_hook docs/setup.txt "$js_secret"; eq "docs: plain text is allowed" "$OUT" ""
done_testing
