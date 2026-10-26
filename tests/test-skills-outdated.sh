# skills-outdated: compares each installed skill's folder hash with upstream, and changes nothing.
. "$(dirname "$0")/helpers.sh"
up="$scratch/upstream"; new_repo "$up"; cd "$up" || exit 1
mkdir -p skills/a skills/b; echo one >skills/a/SKILL.md; echo two >skills/b/SKILL.md
git add -A; git commit -qm init
lock="$scratch/lock.json"
# write_lock: a lock file recording both skills at the current upstream hashes
write_lock() {
  python3 - "$lock" "file://$up" "$(git -C "$up" rev-parse HEAD:skills/a)" "$(git -C "$up" rev-parse HEAD:skills/b)" <<'PY'
import json, sys
lock, url, ha, hb = sys.argv[1:5]
skills = {n: {"sourceUrl": url, "skillPath": "skills/%s/SKILL.md" % n, "skillFolderHash": h} for n, h in (("a", ha), ("b", hb))}
skills["local"] = {"source": "../x", "sourceType": "local"}
json.dump({"version": 3, "skills": skills}, open(lock, "w"))
PY
}
write_lock; cp "$lock" "$scratch/lock.before"
out="$(skills-outdated "$lock")"; rc=$?
eq "all current" "$rc" 0
has "and says so" "$out" "2 current, 0 outdated"
echo changed >"$up/skills/a/SKILL.md"; git -C "$up" commit -qam a
out="$(skills-outdated "$lock")"; rc=$?
eq "an upstream change is outdated" "$rc" 1
has "and named, with the update command" "$out" "npx skills update -g a"
git -C "$up" rm -rq skills/b; git -C "$up" commit -qm b
has "a folder removed upstream is reported" "$(skills-outdated "$lock")" "Gone upstream"
eq "the lock file is never changed" "$(cmp -s "$lock" "$scratch/lock.before" && echo same)" same
python3 -c 'import json, sys; json.dump({"skills": {"x": {"sourceUrl": "file:///nowhere", "skillPath": "s/SKILL.md", "skillFolderHash": "abc"}}}, open(sys.argv[1], "w"))' "$lock"
skills-outdated "$lock" >/dev/null; eq "nothing reachable: can't check" "$?" 2
done_testing
