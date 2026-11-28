# check-plugin.sh: scripts/check-plugin.py finds a plugin that a harness can't load or run.
# Each case breaks one thing in a scratch copy of this repo's tracked files, then puts it back.
. "$(dirname "$0")/helpers.sh"

# A git repo with this repo's tracked files, and the same executable bits in its index
# (Windows has no executable bit on disk, so the bits come from this repo's index).
r="$scratch/plugin"; new_repo "$r"
git -C "$SY" ls-files -z | (cd "$SY" && tar --null -T - -cf -) | tar -xf - -C "$r"
git -C "$r" add -A
git -C "$SY" ls-files -s | awk '$1 == "100755"' | cut -f2- | (cd "$r" && xargs git update-index --chmod=+x --)
git -C "$r" commit -qm init

check() { out="$(python3 "$SY/scripts/check-plugin.py" "$r" 2>&1)"; rc=$?; }
# sub <file> <old> <new>: replace bytes in a file of the copy (no newline or encoding changes)
sub() { python3 - "$r/$1" "$2" "$3" <<'PY'
import sys
p, a, b = sys.argv[1], sys.argv[2].encode(), sys.argv[3].encode()
s = open(p, "rb").read()
assert a in s, "%r not in %s" % (a, p)
open(p, "wb").write(s.replace(a, b, 1))
PY
}
restore() { git -C "$r" checkout -q -- "$@"; }

check
eq "CP1: the plugin as it is passes" "$rc" "0"
has "CP1: and says ok" "$out" "check-plugin: ok"

git -C "$r" update-index --chmod=-x scripts/worktree-notice.sh
check
eq "CP2: a hook script tracked as 100644 fails" "$rc" "1"
has "CP2: and names the script and the fix" "$out" "git update-index --chmod=+x scripts/worktree-notice.sh"
git -C "$r" update-index --chmod=+x scripts/worktree-notice.sh

git -C "$r" update-index --chmod=-x bin/worksheet
check
eq "CP3: a tool in bin/ tracked as 100644 fails" "$rc" "1"
has "CP3: and names the tool" "$out" "bin/worksheet: it is a tool in bin/, but git tracks it as 100644"
git -C "$r" update-index --chmod=+x bin/worksheet

for hooks in hooks/hooks.json hooks.json; do
  sub "$hooks" "scripts/worktree-notice.sh" "scripts/no-such-hook.sh"
  check
  eq "CP4: a hook in $hooks that names a missing script fails" "$rc" "1"
  has "CP4: and names the script" "$out" "$hooks: the hook command names scripts/no-such-hook.sh, which doesn't exist"
  restore "$hooks"
done

sub skills/review/SKILL.md "name: review" "name: reviews"
check
eq "CP5: a skill whose name isn't its folder fails" "$rc" "1"
has "CP5: and names the file" "$out" "skills/review/SKILL.md: the name is 'reviews', but the folder is 'review'"
restore skills/review/SKILL.md

sub skills/review/SKILL.md "description:" "summary:"
check
eq "CP5: a skill with no description fails" "$rc" "1"
has "CP5: and names the file" "$out" "skills/review/SKILL.md: the frontmatter has no description"
restore skills/review/SKILL.md

sub plugin.json '"version": "' '"version": "9.'
check
eq "CP6: manifests with different versions fail" "$rc" "1"
has "CP6: and say so" "$out" "plugin.json and .claude-plugin/plugin.json have a different version"
restore plugin.json

sub .claude-plugin/plugin.json '"version"' '"version" '"'"'oops'"'"
check
eq "CP7: invalid JSON in a manifest fails" "$rc" "1"
has "CP7: and names the file" "$out" ".claude-plugin/plugin.json: not valid JSON"
restore .claude-plugin/plugin.json

done_testing
