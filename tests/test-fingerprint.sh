# The verify fingerprint: content-based, stable across commits, blind to records, never touches the index.
. "$(dirname "$0")/helpers.sh"
. "$SY/scripts/lib.sh"
r="$scratch/repo"; new_repo "$r"; cd "$r" || exit 1
mkdir -p docs/worksheets; echo a >a.txt; echo w >docs/worksheets/w.md; printf '.shipinetics/.cache/\n' >.gitignore
x=(':(exclude).shipinetics/.cache' ':(exclude)docs/worksheets')
f1="$(sy_fingerprint "$r" "${x[@]}")"
eq "fingerprint is a git tree" "$(git cat-file -t "$f1")" tree
git add -A; git commit -qm one
eq "same before and after commit" "$(sy_fingerprint "$r" "${x[@]}")" "$f1"
echo w2 >docs/worksheets/w.md
eq "excluded paths don't count" "$(sy_fingerprint "$r" "${x[@]}")" "$f1"
echo b >a.txt
f2="$(sy_fingerprint "$r" "${x[@]}")"
[ "$f2" != "$f1" ] && ok "code change changes it" || bad "code change changes it" "unchanged"
echo new >new.txt
[ "$(sy_fingerprint "$r" "${x[@]}")" != "$f2" ] && ok "untracked file changes it" || bad "untracked file changes it" "unchanged"
eq "real index untouched" "$(git diff --cached --name-only | wc -l | tr -d ' ')" 0
mkdir -p "$scratch/plain"
out="$(sy_fingerprint "$scratch/plain" "${x[@]}")"; rc=$?
eq "no fingerprint outside git" "$out:$rc" ":1"

# Racy git: a same-size change in the same second as the commit must still be hashed as new.
r2="$scratch/racy"; new_repo "$r2"; cd "$r2" || exit 1
seen=0
for i in 1 2 3; do
  echo a >f.txt; git add f.txt; git commit -qm "c$i" --allow-empty
  echo b >f.txt
  sleep 1   # the fingerprint runs a second later, as a later verify does
  fp="$(sy_fingerprint "$r2")"
  [ "$(git rev-parse "$fp:f.txt")" = "$(git hash-object f.txt)" ] && seen=$((seen + 1))
  git checkout -q f.txt
done
eq "same-second, same-size edits are hashed as new" "$seen" 3
done_testing
