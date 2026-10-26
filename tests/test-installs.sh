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
gate "npx skills check"; eq "checking for updates doesn't ask" "$OUT" ""
gate "npm install left-pad"; eq "a project dependency doesn't ask" "$OUT" ""
done_testing
