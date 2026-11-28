# shipinetics-config: defaults and project values.
. "$(dirname "$0")/helpers.sh"
p="$scratch/cfg"; new_repo "$p"; cd "$p" || exit 1
mkdir -p .shipinetics
eq "agents launch the app by default" "$(shipinetics-config get launch)" agent
printf 'launch = user   # the user runs the servers\n' >.shipinetics/config
eq "launch = user is read" "$(shipinetics-config get launch)" user

# safe-local-setup AC10: the task queue pushes to the default branch only with queue_push = yes
pushes() { [ "$(shipinetics-config get queue_push 2>/dev/null)" = yes ] && echo pushes || echo stays; }
eq "safe-local-setup AC10: without queue_push the queue stays in the branch, and queue_push = yes is read as yes" \
  "$(rm -f .shipinetics/config; pushes):$(printf 'queue_push = yes\n' >.shipinetics/config; pushes)" "stays:pushes"
printf 'launch = user   # the user runs the servers\n' >.shipinetics/config

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

# due security-audit: the cadence the user chose, against the last audit in docs/security/audits.md
days_ago() { python3 -c 'import datetime, sys; print(datetime.date.today() - datetime.timedelta(days=int(sys.argv[1])))' "$1"; }
printf 'launch = agent\n' >.shipinetics/config
shipinetics-config due security-audit >/dev/null; eq "no cadence: not scheduled" "$?" 2
printf 'security_audit_every = monthly\n' >.shipinetics/config
has "never run: due" "$(shipinetics-config due security-audit)" "due (never run"
mkdir -p docs/security; printf '# Security audits\n- %s abc1234 standard: 0 critical, 0 high\n' "$(days_ago 10)" >docs/security/audits.md
shipinetics-config due security-audit >/dev/null; eq "10 days after a monthly audit: not due" "$?" 1
printf -- '- %s def5678 standard: 0 critical, 0 high\n' "$(days_ago 40)" >>docs/security/audits.md
shipinetics-config due security-audit >/dev/null; eq "the newest audit counts, not the last line" "$?" 1
printf 'security_audit_every = 7d\n' >.shipinetics/config
has "a custom cadence in days" "$(shipinetics-config due security-audit)" "due (last run $(days_ago 10)"
printf 'security_audit_every = fortnightly\n' >.shipinetics/config
shipinetics-config due security-audit >/dev/null 2>&1; eq "an unknown cadence is an error" "$?" 2
done_testing
