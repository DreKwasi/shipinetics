# known-failing: only failures that aren't on the protected list fail the suite.
. "$(dirname "$0")/helpers.sh"
p="$scratch/kf"; new_repo "$p"; cd "$p" || exit 1
mkdir -p .shipinetics; echo x >a; git add -A; git commit -qm init
# report <file> <name:pass|fail>...: a JUnit report
report() {
  local f="$1"; shift
  { echo '<testsuites><testsuite name="s">'
    for t in "$@"; do
      if [ "${t#*:}" = fail ]; then printf '<testcase classname="cart" name="%s"><failure>boom</failure></testcase>\n' "${t%:*}"
      else printf '<testcase classname="cart" name="%s"/>\n' "${t%:*}"; fi
    done
    echo '</testsuite></testsuites>'; } >"$f"
}

report r1.xml "adds item:pass" "rounds [chromium]:fail" "old flake:fail"
known-failing check r1.xml >/dev/null 2>&1; eq "without a list every failure counts" "$?" 1
known-failing init r1.xml >/dev/null; eq "init lists today's failures" "$(known-failing count)" 2
out="$(known-failing check r1.xml 2>&1)"; eq "known failures pass" "$?" 0
has "and are counted" "$out" "2 known failures (quarantined), 0 new"
report r2.xml "adds item:fail" "rounds [chromium]:fail" "old flake:pass"
out="$(known-failing check r2.xml 2>&1)"; eq "a new failure fails" "$?" 1
has "and is named" "$out" "cart::adds item"
has "a listed test that passes is reported" "$out" "cart::old flake"
printf 'cart::adds*\n' >>.shipinetics/known-failing
known-failing check r2.xml >/dev/null 2>&1; eq "a wildcard entry matches" "$?" 0
printf '# only a comment\n' >"$scratch/k"; cp .shipinetics/known-failing "$scratch/k.bak"; cp "$scratch/k" .shipinetics/known-failing
eq "an empty list counts 0" "$(known-failing count; echo ":$?")" "0
:0"
printf 'Cart#adds item\ncart::test_a[1]\n' >.shipinetics/known-failing
report r4.xml "test_a1:fail"
known-failing check r4.xml >/dev/null 2>&1; eq "a literal [1] entry doesn't match a 1" "$?" 1
printf '<testsuites><testcase classname="Cart#adds" name="item"><failure/></testcase></testsuites>\n' >r5.xml
printf 'Cart#adds::item\n' >.shipinetics/known-failing
known-failing check r5.xml >/dev/null 2>&1; eq "an ID with # can be quarantined" "$?" 0
cp "$scratch/k.bak" .shipinetics/known-failing
echo '<testsuites/>' >empty.xml
known-failing check empty.xml >/dev/null 2>&1; eq "an empty report fails" "$?" 2
known-failing init r2.xml >/dev/null
eq "re-init goes to pending" "$(grep -c '^cart' .shipinetics/pending/.shipinetics/known-failing):$(known-failing count)" "2:3"
mkdir -p bin; cp "$SY/bin/known-failing" bin/
bin/known-failing check r2.xml >/dev/null 2>&1; eq "a copy works without the plugin" "$?" 0
# Flaky tests: a re-run names them but never passes the check; hunt finds mixed results.
rm -f .shipinetics/known-failing; rm -rf .shipinetics/pending
# flip.sh <junit>: "steady" always passes, "broken" always fails, "racy" fails on odd runs
cat >flip.sh <<'SH'
n=$(( $(cat count 2>/dev/null || echo 0) + 1 )); echo "$n" >count
r=pass; [ $((n % 2)) = 1 ] && r=fail
{ echo '<testsuites><testsuite name="s">'
  echo '<testcase classname="cart" name="steady"/>'
  echo '<testcase classname="cart" name="broken"><failure>x</failure></testcase>'
  if [ "$r" = fail ]; then echo '<testcase classname="cart" name="racy"><failure>x</failure></testcase>'
  else echo '<testcase classname="cart" name="racy"/>'; fi
  echo '</testsuite></testsuites>'; } >"$1"
SH
rm -f count; sh flip.sh first.xml
out="$(known-failing check --rerun 'sh flip.sh {junit}' first.xml 2>&1)"; eq "a flaky failure still fails the check" "$?" 1
has "a test that passes on the re-run is named flaky" "$out" "Flaky (failed, then passed on a re-run)"
has "a test that fails again is named failing" "$out" "failed again on a re-run):
  cart::broken"
OUT="$(known-failing flaky)"; has "flaky lists what the re-run found" "$OUT" "1  cart::racy"
rm -f count; out="$(known-failing hunt -n 4 -- sh flip.sh {junit} 2>&1)"; eq "hunt fails when a test is flaky" "$?" 1
has "hunt names the flaky test and its rate" "$out" "cart::racy (failed 2 of 4)"
has "hunt names a test that always fails as broken" "$out" "Failed on every run (broken, not flaky):
  cart::broken"
hasnt "hunt doesn't name a steady test" "$out" "steady"
out="$(known-failing hunt -n 2 -- true 2>&1)"; eq "hunt fails when a run writes no report" "$?" 2
done_testing
