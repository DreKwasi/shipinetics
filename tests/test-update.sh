# shipinetics-update: a fork or clone sees the latest release, its conflicts and its notes, and
# merges a release only into a clean tree. steps lists each release's steps for each project.
. "$(dirname "$0")/helpers.sh"

up="$scratch/upstream"; new_repo "$up"; cd "$up" || exit 1
mkdir -p .claude-plugin tests
write_release() {
  printf '{"name": "shipinetics", "version": "%s"}\n' "$1" >.claude-plugin/plugin.json
  python3 - "$1" <<'PY'
import sys
v = sys.argv[1]
old = open("CHANGELOG.md").read().split("\n", 2)[2] if v != "0.1.0" else ""
new = "## %s\n\n### Added\n- Feature of %s.\n\n" % (v, v)
if v == "0.2.0":
    new = ("## 0.2.0\n\n### Changed (breaking)\n- The hook moved.\n\n  Steps for each project: copy the new hook\n"
           "  into .githooks/.\n\n### Added\n- A tool.\n\n  Steps for each project (optional): run the tool.\n\n")
open("CHANGELOG.md", "w").write("# Changelog\n\n" + new + old)
PY
  git add -A; git commit -qm "release $1"; git tag "v$1"
}
printf '#!/usr/bin/env bash\n[ -f FAIL_TESTS ] && exit 1\necho all tests passed\n' >tests/run.sh
echo "shared line" >shared.txt
write_release 0.1.0

fork="$scratch/fork"; git clone -q "$up" "$fork"
git -C "$fork" config user.email test@example.com; git -C "$fork" config user.name test
export SHIPINETICS_UPSTREAM="$up"

out="$(shipinetics-update -C "$fork" check)"; rc=$?
eq "a clone at the latest release is up to date" "$rc" 0
has "and says so" "$out" "Up to date"

write_release 0.2.0
echo "upstream change" >shared.txt; git commit -qam "change shared"; write_release 0.3.0
echo "my change" >"$fork/shared.txt"; git -C "$fork" commit -qam "my local change"

out="$(shipinetics-update -C "$fork" check)"; rc=$?
eq "a clone behind the latest release waits for an update" "$rc" 1
has "it names the latest release" "$out" "Latest release: 0.3.0"
has "it names the file that a merge conflicts in" "$out" "  shared.txt"
has "it shows the release notes after the clone's version" "$out" "## 0.2.0"
hasnt "and not the clone's own release" "$out" "Feature of 0.1.0"
eq "check changes no file" "$(git -C "$fork" status --porcelain)" ""

out="$(cd "$fork" && shipinetics-update check)"; rc=$?
eq "check works from inside the clone without -C" "$rc" 1

echo dirty >>"$fork/shared.txt"
out="$(shipinetics-update -C "$fork" merge 2>&1)"; rc=$?
eq "merge refuses a tree with changes" "$rc" 2
has "and says why" "$out" "uncommitted changes"
git -C "$fork" checkout -q -- shared.txt

out="$(shipinetics-update -C "$fork" merge)"; rc=$?
eq "a merge with a conflict stops" "$rc" 1
has "and lists the file" "$out" "  shared.txt"
has "and says how to undo it" "$out" "merge --abort"
out="$(shipinetics-update -C "$fork" merge 2>&1)"; rc=$?
eq "merge refuses a clone in the middle of a merge" "$rc" 2
git -C "$fork" merge --abort

git -C "$fork" reset -q --hard HEAD~1   # drop the local change: no conflict now
out="$(shipinetics-update -C "$fork" merge v0.2.0)"; rc=$?
eq "a clean merge of a named release passes" "$rc" 0
eq "and the clone is at that release" "$(git -C "$fork" describe --tags)" "v0.2.0"
has "and the clone's tests ran" "$out" "All tests passed"
out="$(shipinetics-update -C "$fork" merge v0.2.0)"
has "merging a release the clone holds does nothing" "$out" "Up to date"

touch "$up/FAIL_TESTS"; git -C "$up" add FAIL_TESTS; git -C "$up" commit -qm "break tests"; (cd "$up" && write_release 0.4.0)
out="$(shipinetics-update -C "$fork" merge)"; rc=$?
eq "a merge with failing tests reports a failure" "$rc" 1
has "and says how to undo it" "$out" "reset --hard ORIG_HEAD"
git -C "$fork" reset -q --hard ORIG_HEAD

out="$(shipinetics-update -C "$scratch" check 2>&1)"; rc=$?
eq "a folder that isn't a clone can't be checked" "$rc" 2

# a merge that needs a merge commit, and a hook that refuses it: not a conflict
echo "own file" >"$fork/mine.txt"; git -C "$fork" add mine.txt; git -C "$fork" commit -qm "my own file"
(cd "$up" && echo "fixed" >FIXED && git add FIXED && git rm -q FAIL_TESTS && git commit -qm fix && write_release 0.5.0)
mkdir -p "$fork/.git/hooks"; printf '#!/bin/sh\necho "hook says no" >&2\nexit 1\n' >"$fork/.git/hooks/commit-msg"; chmod +x "$fork/.git/hooks/commit-msg"
out="$(shipinetics-update -C "$fork" merge 2>&1)"; rc=$?
eq "a merge that git refuses for another reason can't go on" "$rc" 2
has "and shows git's own message" "$out" "hook says no"
hasnt "and doesn't call it a conflict" "$out" "conflicts in"
rm "$fork/.git/hooks/commit-msg"; git -C "$fork" merge --abort 2>/dev/null; git -C "$fork" reset -q --hard
out="$(shipinetics-update -C "$fork" merge)"; rc=$?
eq "a merge with a merge commit passes" "$rc" 0
eq "and keeps the clone's own commit" "$(cat "$fork/mine.txt")" "own file"
eq "and holds the release" "$(git -C "$fork" merge-base --is-ancestor v0.5.0 HEAD && echo yes)" yes
out="$(SHIPINETICS_UPSTREAM="$scratch/nowhere" shipinetics-update -C "$fork" check 2>&1)"; rc=$?
eq "no way to fetch the releases: can't check" "$rc" 2

# steps reads this plugin's CHANGELOG: point it at a copy with the test releases
plug="$scratch/plugin"; mkdir -p "$plug/bin" "$plug/scripts" "$plug/.claude-plugin"
cp "$SY/bin/shipinetics-update" "$plug/bin/"
cp "$SY/scripts/compat.sh" "$plug/scripts/"    # the tool sources it, as in the real plugin
git -C "$up" show v0.3.0:CHANGELOG.md >"$plug/CHANGELOG.md"
printf '{"name": "shipinetics", "version": "0.3.0"}\n' >"$plug/.claude-plugin/plugin.json"
out="$("$plug/bin/shipinetics-update" steps 0.1.0)"
has "steps lists a breaking entry" "$out" "0.2.0 (breaking)
  - The hook moved."
has "with its whole step paragraph" "$out" "  into .githooks/."
has "and an entry with an optional step" "$out" "0.2.0 (optional)
  - A tool."
eq "steps after the latest release: none" "$("$plug/bin/shipinetics-update" steps 0.3.0)" "(none)"
"$plug/bin/shipinetics-update" steps >/dev/null 2>&1; eq "steps needs a version" "$?" 2
# the real CHANGELOG has used several ways to write the steps
out="$(shipinetics-update steps 0.4.0 0.9.0)"
has "a breaking entry with no step line still counts" "$out" "0.5.0 (breaking)"
has "a breaking entry whose step is written **Step:** counts" "$out" "0.7.0 (breaking)"
has "a list item named Steps for each project counts" "$out" "**Steps for each project.** Test-writer reads"
hasnt "a release after <to> doesn't count" "$out" "0.9.1 ("

# status: an install from a folder on this machine checks that clone
stub="$scratch/stub"; mkdir -p "$stub"
cat >"$stub/claude" <<EOF
#!/bin/sh
case "\$*" in
  "plugin list --json") echo '[{"id": "shipinetics@shipinetics", "version": "0.2.0", "readFromFolder": "$fork"}]' ;;
  "plugin marketplace list --json") echo '[{"name": "shipinetics", "source": "directory", "path": "$fork"}]' ;;
esac
EOF
chmod +x "$stub/claude"
out="$(cd "$scratch" && PATH="$stub:$PATH" shipinetics-update)"; rc=$?
has "status names a folder install" "$out" "a folder on this machine"
has "and checks that clone" "$out" "Latest release: 0.5.0"
eq "and the clone is up to date" "$rc" 0

cat >"$stub/claude" <<'EOF'
#!/bin/sh
case "$*" in
  "plugin list --json") echo '[{"id": "shipinetics@acme", "version": "0.2.0"}]' ;;
  "plugin marketplace list --json") echo '[{"name": "acme", "source": "github", "repo": "acme/shipinetics"}]' ;;
esac
EOF
out="$(cd "$scratch" && PATH="$stub:$PATH" shipinetics-update)"
has "status names a fork on GitHub" "$out" "(your fork)"
has "and says that a new version is needed" "$out" "0.2.0-<your name>.1"
cat >"$stub/claude" <<EOF
#!/bin/sh
case "\$*" in
  "plugin list --json") echo '[{"id": "shipinetics@shipinetics", "version": "0.4.0"}]' ;;
  "plugin marketplace list --json") echo '[{"name": "shipinetics", "source": "github", "repo": "$up"}]' ;;
esac
EOF
out="$(cd "$scratch" && PATH="$stub:$PATH" shipinetics-update)"; rc=$?
has "status names the main repo" "$out" "(the main repo)"
has "and the latest release" "$out" "The latest release is 0.5.0"
eq "and an update is waiting" "$rc" 1

cat >"$stub/claude" <<'EOF'
#!/bin/sh
case "$*" in
  "plugin list --json") echo '[{"id": "shipinetics@gone", "version": "0.4.0"}]' ;;
  "plugin marketplace list --json") echo '[]' ;;
esac
EOF
out="$(cd "$scratch" && PATH="$stub:$PATH" shipinetics-update)"; rc=$?
has "a marketplace that the list doesn't show is named" "$out" "doesn't show"
hasnt "and isn't called a fork" "$out" "(your fork)"
done_testing
