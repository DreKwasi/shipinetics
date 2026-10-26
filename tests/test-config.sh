# shipinetics-config: defaults and project values.
. "$(dirname "$0")/helpers.sh"
p="$scratch/cfg"; new_repo "$p"; cd "$p" || exit 1
mkdir -p .shipinetics
eq "agents launch the app by default" "$(shipinetics-config get launch)" agent
printf 'launch = user   # the user runs the servers\n' >.shipinetics/config
eq "launch = user is read" "$(shipinetics-config get launch)" user

# match: which glob in a list covers a path, as the guards see it
printf '.shipinetics/*\ne2e/acceptance/*\n' >.shipinetics/protected-paths
printf 'tests/*\n' >.shipinetics/test-paths
mkdir -p src
eq "match names the glob" "$(shipinetics-config match protected-paths e2e/acceptance/a.spec.ts)" "e2e/acceptance/a.spec.ts matches 'e2e/acceptance/*' in protected-paths"
out="$(cd src && shipinetics-config match test-paths ../tests/x.test.ts)"
eq "paths are relative to where you are" "$out" "tests/x.test.ts matches 'tests/*' in test-paths"
shipinetics-config match protected-paths src/app.ts >/dev/null; eq "no match exits 1" "$?" 1
has "a pending proposal is never protected" "$(shipinetics-config match protected-paths .shipinetics/pending/e2e/acceptance/a.spec.ts)" "never protected"
has "but it's still a test file" "$(shipinetics-config match test-paths .shipinetics/pending/tests/x.test.ts)" "matches 'tests/*'"
printf '.shipyard/*\n' >.shipinetics/protected-paths
has "an old .shipyard/* line covers .shipinetics/" "$(shipinetics-config match protected-paths .shipinetics/config)" "matches '.shipyard/*'"
done_testing
