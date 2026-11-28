# The install gate asks the user before agent tooling is installed or updated, and stays out of the way otherwise.
. "$(dirname "$0")/helpers.sh"
cd "$scratch" || exit 1

# gate <command>: run the install gate on a Bash command; sets OUT
gate() {
  OUT="$(python3 -c 'import json, sys; print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}}))' "$1" |
    bash "$SY/scripts/guard-installs.sh" 2>/dev/null)"
}
asks() { gate "$2"; has "asks: $1" "$OUT" '"ask"'; }

asks "installing a skill" "npx skills add mattpocock/skills --skill wait-what -g"
asks "updating skills" "npx skills update -g grilling domain-modeling"
asks "installing a plugin" "claude plugin install shipinetics@shipinetics"
asks "updating a plugin" "claude plugin update shipinetics@shipinetics"
asks "adding a marketplace" "claude plugin marketplace add DreKwasi/shipinetics"
asks "updating a marketplace" "claude plugin marketplace update shipinetics"
asks "adding an MCP server" "claude mcp add sentry https://mcp.sentry.dev"
has "the question says what to do" "$OUT" "installs or updates agent tooling"
asks "npx skills check, which can update and remove skills" "npx skills check"
gate "skills-outdated"; eq "the read-only check doesn't ask" "$OUT" ""
asks "merging a Shipinetics release into a clone" "shipinetics-update -C ~/src/shipinetics merge v0.9.3"
asks "merging from inside the clone" "shipinetics-update merge"
asks "multi-harness-installer AC7: installing Shipinetics into Claude Code" "shipinetics install claude"
asks "multi-harness-installer AC7: installing Shipinetics by a quoted full path" '"$HOME/x/bin/shipinetics" install claude'
asks "multi-harness-installer AC7: installing Shipinetics by a single-quoted path" "'bin/shipinetics' install claude"
gate 'grep -rn "shipinetics install" .'; eq "multi-harness-installer AC7: searching for the words shipinetics install doesn't ask" "$OUT" ""
# A lone dry run of plain words changes nothing: no question. Anything that can ride along still asks.
for c in "shipinetics install antigravity --dry-run" "./bin/shipinetics install claude --dry-run" \
  "shipinetics-antigravity install --dry-run"; do
  gate "$c"; eq "multi-harness-installer AC7: a lone dry run doesn't ask: $c" "$OUT" ""
done
asks "multi-harness-installer AC7: a dry run followed by && another command" "shipinetics install claude --dry-run && claude plugin install x@y"
asks "multi-harness-installer AC7: a dry run followed by ; another command" "shipinetics install claude --dry-run; shipinetics install claude"
asks "multi-harness-installer AC7: a dry run piped into a command" "shipinetics install claude --dry-run | sh"
asks "multi-harness-installer AC7: a dry run with \$( ) in it" 'shipinetics install claude --dry-run $(shipinetics install antigravity)'
asks "multi-harness-installer AC7: a dry run with backticks in it" 'shipinetics install claude --dry-run `shipinetics install antigravity`'
asks "multi-harness-installer AC7: a dry run by a quoted \$HOME path" '"$HOME/bin/shipinetics" install claude --dry-run'
asks "multi-harness-installer AC7: a dry run by a \$VAR path" '$SY_HOME/bin/shipinetics install claude --dry-run'
gate "shipinetics-update -C ~/src/shipinetics check"; eq "the update check doesn't ask" "$OUT" ""
gate "npm install left-pad"; eq "a project dependency doesn't ask" "$OUT" ""
# ---- the gate judges commands that would run, not the same words in text
nl=$'\n'
silent() { gate "$2"; eq "text doesn't ask: $1" "$OUT" ""; }
silent "a commit message" 'git commit -m "Docs: install companions with npx skills add"'
silent "a commit message from a quoted heredoc" "git commit -m \"\$(cat <<'EOF'${nl}Run claude plugin install impeccable@impeccable.${nl}EOF${nl})\""
silent "a grep pattern" 'grep -rn "claude plugin install" README.md'
silent "a heredoc written to a file" "cat > notes.md <<'EOF'${nl}npx skills add mattpocock/skills${nl}EOF"
silent "a note, then a commit" "cat > notes.md <<'EOF'${nl}npx skills add mattpocock/skills${nl}EOF${nl}git add notes.md && git commit -m 'Note the install'"
silent "an rg pattern" "rg 'claude plugin install' docs"
asks "in bash -c" 'bash -c "npx skills add x/y"'
asks "after cd" "cd /tmp && claude plugin install a@b"
asks "in a pipe" "yes | npx skills add x/y"
asks "a commit message that runs a command" 'git commit -m "$(claude mcp add s https://x)"'
asks "echo piped into sh" 'echo "npx skills add x/y" | sh'
asks "the line after a comment with a quote" "# don't${nl}npx skills update -g"
asks "a comment line inside a double quote" "echo \"x${nl}# \$(npx skills add evil/x)\""
asks "a commit whose output goes into sh" "git commit --allow-empty -m 'x; claude mcp add s https://x ' 2>&1 | sh"
asks "a note, then a command that isn't git" "cat > notes.md <<'EOF'${nl}npx skills add x/y${nl}EOF${nl}sh notes.md"
asks "a message that git log writes into .git/config" "git commit --allow-empty -m '[core]${nl}	fsmonitor = npx skills add x/y ;:' ; git log -1 --format=%B --output=.git/config ; git status"
asks "a carriage return after the delimiter" "cat > notes.md <<'EOF'"$'\r\n'"EOF"$'\r\n'"npx skills add x/y${nl}EOF"

done_testing
