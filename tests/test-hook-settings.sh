# Hooks are modular: each can be switched off, and the user chooses the secret files.
. "$(dirname "$0")/helpers.sh"
p="$scratch/mod"; new_repo "$p"; cd "$p" || exit 1
stub_verify bin/verify; mkdir -p .shipinetics/.cache config; printf '.shipinetics/.cache/\n' >.gitignore
echo a >a.txt; git add -A; git commit -qm init
user="$XDG_CONFIG_HOME/shipinetics"; mkdir -p "$user"

# hook <script> <tool> <field> <value>: run a PreToolUse hook; sets OUT (empty means allowed)
hook() {
  OUT="$(python3 -c 'import json, sys; print(json.dumps({"tool_name": sys.argv[1], "tool_input": {sys.argv[2]: sys.argv[3]}}))' "$2" "$3" "$4" |
    CLAUDE_PROJECT_DIR="$p" bash "$SY/scripts/$1" 2>/dev/null)"
}

# ---- switching hooks off
hook guard-secrets.sh Bash command env; has "secrets guard is on by default" "$OUT" '"deny"'
printf 'hooks_off = secrets installs\n' >.shipinetics/config
hook guard-secrets.sh Bash command env; eq "hooks_off in the project switches it off" "$OUT" ""
hook guard-installs.sh Bash command "claude plugin install x@y"; eq "and the install gate" "$OUT" ""
: >.shipinetics/config
printf 'hooks_off = secrets\n' >"$user/config"
hook guard-secrets.sh Bash command env; eq "hooks_off in the user's config switches it off" "$OUT" ""
printf 'hooks_off = pr\n' >.shipinetics/config
hook guard-secrets.sh Bash command env; has "a project's hooks_off replaces the user's" "$OUT" '"deny"'
: >.shipinetics/config; rm "$user/config"
OUT="$(printf '{"tool_name":"Bash","tool_input":{"command":"env"}}' | SHIPINETICS_HOOKS_OFF=secrets CLAUDE_PROJECT_DIR="$p" bash "$SY/scripts/guard-secrets.sh" 2>/dev/null)"
eq "SHIPINETICS_HOOKS_OFF switches it off for a session" "$OUT" ""

# ---- choosing the secret files
hook guard-secrets.sh Read file_path "$HOME/.aws/credentials"; has "defaults guard ~/.aws/credentials" "$OUT" "secret file"
hook guard-secrets.sh Read file_path "$p/config/service-account.json"; eq "defaults don't know the project's own files" "$OUT" ""
printf '# ours\nconfig/service-account.json\n*.pem\n' >.shipinetics/secret-paths
hook guard-secrets.sh Read file_path "$p/config/service-account.json"; has "a project list guards its files" "$OUT" "matches 'config/service-account.json'"
hook guard-secrets.sh Read file_path "$p/certs/server.pem"; has "a glob without / matches the file name anywhere" "$OUT" "matches '*.pem'"
hook guard-secrets.sh Bash command "cat config/service-account.json | head"; has "naming it in a command is blocked too" "$OUT" "secret file"
hook guard-secrets.sh Read file_path "$HOME/.aws/credentials"; eq "the project list is the whole list" "$OUT" ""
rm .shipinetics/secret-paths; printf 'secrets.enc\n' >"$user/secret-paths"
hook guard-secrets.sh Bash command "sops -d secrets.enc"; has "the user's list applies when the project has none" "$OUT" "matches 'secrets.enc'"
rm "$user/secret-paths"

# ---- agents can't change the user's settings
hook guard-edits.sh Write file_path "$user/config"; has "the edit guard keeps agents out of the user's settings" "$OUT" "Shipinetics settings"
XDG_CONFIG_HOME="$XDG_CONFIG_HOME/" hook guard-edits.sh Write file_path "$user/config"; has "and when XDG_CONFIG_HOME ends in /" "$OUT" "Shipinetics settings"
done_testing
