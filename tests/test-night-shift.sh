# night-shift --dry-run sets up the shift's worktrees, in a single repo and in workspace mode.
. "$(dirname "$0")/helpers.sh"
mkdir -p "$scratch/fakebin"; printf '#!/bin/sh\nexit 0\n' >"$scratch/fakebin/claude"; chmod +x "$scratch/fakebin/claude"
PATH="$PATH:$scratch/fakebin"
day="$(date +%Y-%m-%d)"

s="$scratch/single"; new_repo "$s"; cd "$s" || exit 1
stub_verify bin/verify; mkdir -p .shipinetics; printf '.shipinetics/.cache/\n.claude/worktrees/\n' >.gitignore
git add -A; git commit -qm init
night-shift --dry-run >/dev/null 2>&1; eq "single repo: dry run succeeds" "$?" 0
eq "single repo: worktree on the night branch" "$(git -C .claude/worktrees/night-"$day" branch --show-current 2>/dev/null)" "night/$day"

w="$scratch/ws"; mkdir -p "$w/.shipinetics"; cd "$w" || exit 1
for p in api web; do new_repo "$p"; stub_verify "$p/check.sh"; git -C "$p" add -A; git -C "$p" commit -qm i; done
printf 'packages = api web\npackage_verify_cmd = sh {package}/check.sh\n' >.shipinetics/config
out="$(night-shift --dry-run 2>&1)"; rc=$?
eq "workspace without a harness repo: refuses" "$rc" 1
has "and says how to fix it" "$out" "harness_repo"
new_repo "$w"; printf '.shipinetics/.cache/\n.claude/worktrees/\napi/\n' >.gitignore; git add .gitignore .shipinetics; git commit -qm harness
out="$(night-shift --dry-run 2>&1)"
has "a package the harness repo doesn't ignore: refuses" "$out" "doesn't ignore web/"
echo 'web/' >>.gitignore; git commit -qam ignore
night-shift --dry-run >/dev/null 2>&1; eq "workspace: dry run succeeds" "$?" 0
t="$w/.claude/worktrees/night-$day"
eq "workspace: the harness worktree is on the night branch" "$(git -C "$t" branch --show-current 2>/dev/null)" "night/$day"
eq "workspace: each package worktree is too" "$(git -C "$t/api" branch --show-current 2>/dev/null):$(git -C "$t/web" branch --show-current 2>/dev/null)" "night/$day:night/$day"
eq "workspace: inside it, the hooks see the shift's workspace" "$(cd "$t/api" && shipinetics-config root 2>/dev/null)" "$t"
night-shift --dry-run >/dev/null 2>&1; eq "workspace: a second run resumes" "$?" 0
done_testing
