# Evidence media: one recording with a time per criterion, screenshots only with a reason, never
# both, never in git. Uploads go through the opt-in evidence_upload_cmd.
. "$(dirname "$0")/helpers.sh"
t="$scratch/media"; new_repo "$t"; cd "$t" || exit 1
mkdir -p .shipinetics; printf '.shipinetics/.cache/\n' >.gitignore
mkdir -p src/ui; echo a >src/ui/app.js; git add -A; git commit -qm init; git checkout -qb feat
mkdir -p docs/worksheets docs/evidence/w; printf '# W\n- [ ] AC1: works\n' >docs/worksheets/w.md
echo b >src/ui/app.js; git add -A; git commit -qm code -m "Worksheet: w"
rec="$(git rev-parse --short HEAD)"; d=docs/evidence/w
# ev <evidence cell> [extra line]: EVIDENCE.md with one AC1 row, recorded at the code commit
ev() { printf '> Commit: %s | Recorded: now\n%s\n| Criterion | Feature and entry point | Evidence | What |\n|---|---|---|---|\n| AC1 | F1 | %s | ok |\n' "$rec" "${2:-}" "$1" >"$d/EVIDENCE.md"; }
chk() { OUT="$(evidence check w 2>&1)"; }
vid='[video](https://files.example.com/walk)'; shot='[screenshot](https://files.example.com/s)'

ev "$vid @ 0:07"; chk; has "a linked recording with a time passes" "$OUT" "complete for w"
ev "$vid"; chk; has "a recording without the criterion's time fails" "$OUT" "not the time where its result shows"

echo png >"$d/shot.png"; git add "$d/shot.png"; chk
has "a screenshot tracked by git fails" "$OUT" "$d/shot.png is in git"
git rm -q --cached "$d/shot.png"; rm "$d/shot.png"

echo vid >"$d/walkthrough.webm"; ev "walkthrough.webm @ 0:07"; chk
has "without a store, a recording on disk passes" "$OUT" "complete for w"
printf 'evidence_upload_cmd = echo uploading; echo "https://store.example.com/$2"\n' >.shipinetics/config; chk
has "with a store, a recording not uploaded fails" "$OUT" "walkthrough.webm is not uploaded"
OUT="$(evidence upload w 2>&1)"; has "upload prints the link" "$OUT" "https://store.example.com/w/walkthrough.webm"
OUT="$(cat "$d/EVIDENCE.md")"; has "upload puts the link in the row and keeps the time" "$OUT" "[video](https://store.example.com/w/walkthrough.webm) @ 0:07"
chk; has "an uploaded recording passes" "$OUT" "complete for w"
eq "upload keeps the local copy" "$(cat "$d/walkthrough.webm")" "vid"
rm .shipinetics/config
ev "walkthrough.webm @ 0:07"; OUT="$(evidence upload w 2>&1)"; has "upload without a store says to attach by hand" "$OUT" "no store is set"
OUT="$(evidence pr-body main 2>&1)"; has "pr-body asks for a recording not uploaded" "$OUT" "Drag "
rm "$d/walkthrough.webm"

ev "$shot $vid @ 0:07"; chk; has "a screenshot and a recording together fail" "$OUT" "Never both"
ev "$vid @ 0:07, [video](https://files.example.com/other) @ 0:09"; chk; has "two recordings fail" "$OUT" "Use one recording"
ev "[ticket](https://jira.example.com/browse/X-1)"; chk; has "a ticket link alone is not evidence" "$OUT" "names no recording"
ev "$shot"; chk; has "screenshots without a reason fail" "$OUT" "only for a change that can't be recorded"
ev "$shot" "> No recording: the app has no browser build"; chk; has "screenshots with a reason pass" "$OUT" "complete for w"

printf 'src/ui/*\n' >.shipinetics/ui-paths; echo x >"$d/terminal.log"
ev "terminal.log"; chk; has "a UI change without a recording fails" "$OUT" "names no recording"
rm .shipinetics/ui-paths "$d/terminal.log"

evidence init w2 >/dev/null; OUT="$(cat docs/evidence/w2/.gitignore 2>&1)"
has "init ignores recordings" "$OUT" "[wW][eE][bB][mM]"; has "init ignores screenshots" "$OUT" "[pP][nN][gG]"
echo v >docs/evidence/w2/CLIP.MOV; OUT="$(git status --porcelain --untracked-files=all docs/evidence/w2)"
hasnt "init ignores upper-case extensions too" "$OUT" "CLIP.MOV"

ev "$vid @ 0:07"; echo png >"$d/shot.png"; OUT="$(evidence pr-body main 2>&1)"
has "pr-body prints the recording link" "$OUT" "Video: https://files.example.com/walk"
hasnt "pr-body links no local media file" "$OUT" "shot.png"
rm "$d/shot.png"

if command -v ffmpeg >/dev/null 2>&1; then
  ffmpeg -v error -f lavfi -i testsrc=duration=3:size=64x48:rate=5 "$d/walkthrough.webm" </dev/null
  ev "$vid @ 0:01.5"; OUT="$(evidence frames w "$scratch/frames" 2>&1)"
  has "frames names the criterion's frame" "$OUT" "AC1.png (AC1 @ 0:01.5)"
  [ -s "$scratch/frames/AC1.png" ] && ok "frames writes the frame" || bad "frames writes the frame" "no $scratch/frames/AC1.png"
else
  ok "frames: skipped, no ffmpeg"
fi
done_testing
