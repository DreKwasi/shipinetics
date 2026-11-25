# The PR gate requires fresh evidence and a complete verify pass on exactly this code.
. "$(dirname "$0")/helpers.sh"
t="$scratch/pr"; new_repo "$t"; cd "$t" || exit 1
stub_verify bin/verify; mkdir -p .shipinetics; printf '.shipinetics/.cache/\n' >.gitignore
printf 'evidence = required\n' >.shipinetics/config  # this file tests the gate with evidence required
echo a >a.txt; git add -A; git commit -qm init; git checkout -qb feat
mkdir -p docs/worksheets docs/evidence/w; printf '# W\n> Status: done\n- [x] AC1: works\n' >docs/worksheets/w.md
echo b >a.txt; git add -A; git commit -qm code -m "Worksheet: w"
printf '> Commit: %s | Recorded: now\n| Criterion | Evidence | What |\n|---|---|---|\n| AC1 | terminal.log | ok |\n' "$(git rev-parse --short HEAD)" >docs/evidence/w/EVIDENCE.md
echo '$ run' >docs/evidence/w/terminal.log; git add -A; git commit -qm ev -m "Worksheet: w"
printf '## Evidence\n' >"$scratch/body.md"
pr() { OUT="$(printf '{"tool_input":{"command":"gh pr create --body-file %s"},"cwd":"%s"}' "$scratch/body.md" "$t" | CLAUDE_PROJECT_DIR="$t" bash "$SY/scripts/guard-pr.sh")"; }
pr; has "denied before verify" "$OUT" "complete verify hasn't passed"
shipinetics-verify >/dev/null; pr; eq "allowed after shipinetics-verify" "$OUT" ""
echo note >>docs/worksheets/w.md; git commit -qam ws -m "Worksheet: w"; pr; eq "worksheet-only commit keeps the pass" "$OUT" ""
echo c >a.txt; git commit -qam fix -m "Worksheet: w"; pr; has "code change makes evidence stale" "$OUT" "code changed since: a.txt"
# ---- what the gate judges: commands that would run, not the same words in text
# A branch with code and no evidence, so a real PR command is denied.
g="$scratch/words"; new_repo "$g"; cd "$g" || exit 1
mkdir -p .shipinetics; printf '.shipinetics/.cache/\n' >.gitignore
printf 'evidence = required\n' >.shipinetics/config
echo a >a.txt; git add -A; git commit -qm init; git checkout -qb feat
echo b >a.txt; git commit -qam code
# prg <command>: run the gate on a Bash command in this repo; sets OUT
prg() {
  OUT="$(python3 -c 'import json, sys; print(json.dumps({"tool_name": "Bash", "tool_input": {"command": sys.argv[1]}, "cwd": sys.argv[2]}))' "$1" "$g" |
    CLAUDE_PROJECT_DIR="$g" bash "$SY/scripts/guard-pr.sh")"
}
nl=$'\n'
passes() { prg "$2"; eq "text passes: $1" "$OUT" ""; }
denied() { prg "$2"; has "still denied: $1" "$OUT" '"deny"'; }

passes "a heredoc written to a file" "cat > notes.md <<'EOF'${nl}Open it with gh pr create and then gh pr ready when it passes${nl}EOF"
passes "a commit message in double quotes" 'git commit -m "Docs: explain gh pr create and gh pr ready"'
passes "a commit message in single quotes" "git commit -qm 'gh pr ready waits for the evidence'"
passes "a commit message after -am" 'git commit -am "gh pr create needs evidence"'
passes "a commit message after --message=" "git commit --message='gh pr ready waits for the checks'"
passes "a commit message from a quoted heredoc" "git commit -m \"\$(cat <<'EOF'${nl}The gate blocks gh pr create without evidence.${nl}${nl}Co-Authored-By: A <a@example.com>${nl}EOF${nl})\""
passes "a grep pattern" 'grep -rn "gh pr create " scripts'
passes "an rg pattern" "rg 'gh pr create ' ."
passes "a note, then git add and commit" "cat > docs/notes.md <<'EOF'${nl}Open the PR with gh pr create when it passes.${nl}EOF${nl}git add docs/notes.md && git commit -m 'Add notes on gh pr create '"
passes "a note with && on its first line" "cat > notes.md <<'EOF' && git add notes.md${nl}gh pr ready comes last${nl}EOF"
passes "cd, then a commit" 'cd docs && git commit -m "gh pr create needs evidence"'
passes "a search piped into head" "grep -rn 'gh pr create ' scripts | head -5"

denied "the command itself" "gh pr create --fill"
denied "gh pr ready" "gh pr ready 12"
denied "after cd" "cd . && gh pr create"
denied "after another command" "git status; gh pr create"
denied "after &&" "git push && gh pr ready"
denied "in a pipe" "echo hi | gh pr create --body-file -"
denied "behind sudo" "sudo gh pr create"
denied "behind env" "env GH_DEBUG=1 gh pr create"
denied "behind an assignment" "GH_DEBUG=1 gh pr create"
denied "in bash -c" 'bash -c "gh pr create --title x"'
denied "in sh -c" "sh -c 'gh pr ready'"
denied "echo piped into sh" 'echo "gh pr create" | sh'
denied "a commit message that runs a command" 'git commit -m "$(gh pr create)"'
denied "a commit message piped into sh" 'git commit -m "gh pr create" | sh'
denied "a heredoc fed to bash" "bash <<'EOF'${nl}gh pr create${nl}EOF"
denied "a heredoc fed to python" "python3 - <<'EOF'${nl}import os; os.system('gh pr create')${nl}EOF"
denied "a heredoc that expands" "cat > f <<EOF${nl}\$(gh pr create)${nl}EOF"
denied "the line after a comment with a quote" "# don't${nl}gh pr create"
denied "a comment after the command" "gh pr create # open it"
# Shapes that a reviewer built to get past the gate. Each one runs the command in bash.
denied "a comment line inside a single quote" "echo '${nl}# '; gh pr create"
denied "a comment line inside a double quote" "echo \"x${nl}# \$(gh pr create )\""
denied "a comment line after a backslash" "echo foo\\${nl}#x; gh pr create"
denied "a JavaScript private field" "node <<'EOF'${nl}class A {${nl}#x = require('child_process').execSync('gh pr create ')${nl}}${nl}EOF"
denied "a commit whose output goes into sh" "git commit --allow-empty -m 'x; gh pr create ' 2>&1 | sh"
denied "a commit inside eval" "eval \$(git commit --allow-empty -m 'x; gh pr create ; #')"
denied "a commit written to a script that runs" "git commit -m 'x; gh pr create ' >out.sh; sh out.sh"
denied "a commit message that a comment hides" "git commit -m #'${nl}gh pr create${nl}: ''"
denied "a commit inside a heredoc for bash" "bash <<EOF${nl}git commit -m 'x${nl}EOF${nl}gh pr create${nl}: ''"
denied "a commit that git log later runs" "git commit --allow-empty -m 'x; gh pr create ' && git log -1 --format=%s | sh"
denied "a heredoc inside a quote" "echo '${nl}cat > notes.txt <<EOF${nl}'${nl}gh pr create${nl}EOF"
denied "tee in a group piped into sh" "{${nl}tee notes.txt <<'EOF'${nl}gh pr create${nl}EOF${nl}} | sh"
denied "a Makefile, then make" "cat > Makefile <<'EOF'${nl}all:${nl}	gh pr create${nl}EOF${nl}make"
denied "a note, then a command that isn't git" "cat > notes.md <<'EOF'${nl}gh pr create${nl}EOF${nl}sh notes.md"
denied "cat replaced by a function" "cat() { sh; }${nl}cat > notes.txt <<'EOF'${nl}gh pr create${nl}EOF"
denied "git replaced by a function" "git() { sh -c \"\$3\"; }${nl}git commit -m 'gh pr create '"
denied "grep replaced by a function" "grep() { sh -c \"\$1\"; }${nl}grep 'gh pr create ' x"
denied "a grep that prints its pattern into sh" "grep -ohF 'gh pr create ' -r docs | head -1 | sh"
denied "git -c with an alias" "git -c alias.x='!gh pr create' x"
# Round two: shapes that get past the first shape-based version.
cr=$'\r'
denied "a message that git log writes into .git/config" "git commit --allow-empty -m '[core]${nl}	fsmonitor = gh pr create ;:' ; git log -1 --format=%B --output=.git/config ; git status"
denied "a quote left open on the first line of a note" "cat > notes.md <<'EOF' ; git commit --allow-empty -m 'x${nl}EOF${nl}git commit --allow-empty -m '${nl}EOF${nl}gh pr create ${nl}'${nl}git status '"
denied "a carriage return after the delimiter" "cat > notes.md <<'EOF'${cr}${nl}EOF${cr}${nl}gh pr create ${nl}EOF"
denied "a ) in a heredoc message (bash 3.2)" "git commit --allow-empty -m \"\$(cat <<'EOF'${nl}x ) \$(gh pr create )${nl}EOF${nl})\""
denied "sort that runs a program" "grep -rhoF 'gh pr create ' docs | sort -S 1 --compress-program=sh"
denied "a note moved into a hook" "cat > notes.md <<'EOF'${nl}gh pr create ${nl}EOF${nl}git add notes.md && git mv -f notes.md .husky/pre-commit && git commit -qm x"
denied "a note run by git push --receive-pack" "cat > notes.md <<'EOF'${nl}gh pr create ${nl}EOF${nl}git push --receive-pack='sh notes.md' . HEAD"
denied "git diff --ext-diff after a note" "cat > notes.md <<'EOF'${nl}gh pr create ${nl}EOF${nl}git diff --ext-diff"
passes "a commit, then git log" "git commit -m 'gh pr create docs' && git log -1 --oneline"

done_testing
