# shipinetics-config migrate moves a project set up as Shipyard to the new names, and nothing else.
. "$(dirname "$0")/helpers.sh"
p="$scratch/m"; new_repo "$p"; cd "$p" || exit 1
mkdir -p .shipyard/.cache .githooks bin docs
printf 'verify_quick_cmd = bin/verify --quick\n' >.shipyard/config
printf '.shipyard/*\ne2e/acceptance/*\n' >.shipyard/protected-paths
echo state >.shipyard/.cache/current-worksheet
printf '.shipyard/.cache/\n' >.gitignore
printf '#!/bin/sh\nexec shipyard-verify complete\n' >.githooks/pre-push
printf '#!/bin/sh\ncat "$SHIPYARD_CHANGED_FILES"\n' >bin/verify
printf 'Tests come from shipyard:test-writer. Run /shipyard:setup.\nOur ship, the shipyard team.\n' >AGENTS.md
echo log >docs/shipyard-setup.md
git add -A; git commit -qm init

out="$(shipinetics-config migrate --dry-run 2>/dev/null)"
has "dry run lists the folder move" "$out" "would move .shipyard to .shipinetics"
eq "dry run changes nothing" "$(git status --porcelain)" ""
echo dirty >>AGENTS.md
shipinetics-config migrate >/dev/null 2>&1; eq "refuses with uncommitted changes" "$?" 1
git checkout -q AGENTS.md

out="$(shipinetics-config migrate 2>/dev/null)"; eq "migrate succeeds" "$?" 0
eq "folder moved, cache included" "$(cat .shipinetics/.cache/current-worksheet 2>/dev/null):$([ -d .shipyard ] && echo old)" "state:"
eq "protected-paths line rewritten" "$(head -n 1 .shipinetics/protected-paths 2>/dev/null)" ".shipinetics/*"
eq "gitignore rewritten" "$(cat .gitignore)" ".shipinetics/.cache/"
has "git hook calls the new command" "$(cat .githooks/pre-push)" "exec shipinetics-verify complete"
has "verify script reads the new variable" "$(cat bin/verify)" '$SHIPINETICS_CHANGED_FILES'
has "agent and skill names rewritten" "$(cat AGENTS.md)" "shipinetics:test-writer. Run /shipinetics:setup."
has "other uses of the word are left alone" "$(cat AGENTS.md)" "the shipyard team"
eq "setup log renamed" "$(cat docs/shipinetics-setup.md 2>/dev/null)" log
eq "config still reads after migrating" "$(shipinetics-config get verify_quick_cmd 2>&1)" "bin/verify --quick"
eq "nothing is committed for you" "$(git log --oneline | wc -l | tr -d ' ')" 1
done_testing
