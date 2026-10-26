# helpers.sh: shared setup and assertions for shipinetics's own tests. Source it from a test.
# Every test works in a scratch folder under $TMPDIR and never touches this repo.

set -uo pipefail
SY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fails=0
scratch="$(mktemp -d "${TMPDIR:-/tmp}/shipinetics-test.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT

# Isolate the tests from this machine, so they pass or fail the same everywhere:
# - a scratch home and settings folder, so the user's ~/.config/shipinetics, ~/.gitconfig and
#   credential files never count;
# - no git config but each repo's own (no global hooks, signing or default branch);
# - no SHIPINETICS_* switches from the user's shell, and no Claude Code session variables;
# - a PATH with this plugin's bin/ and the system tools only, so another plugin's commands
#   (or an installed copy of this one) can't answer for ours. The bash running the tests comes
#   first, so the tools run on the same bash.
export HOME="$scratch/home" XDG_CONFIG_HOME="$scratch/xdg"
mkdir -p "$HOME" "$XDG_CONFIG_HOME"
export GIT_CONFIG_GLOBAL="$scratch/gitconfig" GIT_CONFIG_NOSYSTEM=1
for v in $(compgen -e); do
  case "$v" in SHIPINETICS_*|CLAUDE_PROJECT_DIR|CLAUDE_PLUGIN_ROOT|CLAUDECODE|CLAUDE_CODE_*) unset "$v" ;; esac
done
tool_dirs="$(dirname "${BASH:-/bin/bash}")"
for t in git jq python3 perl; do
  t="$(command -v "$t" 2>/dev/null)" && tool_dirs="$tool_dirs:$(dirname "$t")"
done
export PATH="$SY/bin:$tool_dirs:/usr/bin:/bin:/usr/sbin:/sbin"
unset t v tool_dirs

# new_repo <dir>: an empty git repo on main with a test identity
new_repo() {
  mkdir -p "$1" && git -C "$1" init -q -b main 2>/dev/null || git -C "$1" init -q
  git -C "$1" config user.email test@example.com
  git -C "$1" config user.name test
  git -C "$1" config commit.gpgsign false
}

# stub_verify <file>: a verify command that reports its tier and changed files, and fails if FAIL exists
stub_verify() {
  mkdir -p "$(dirname "$1")"
  cat >"$1" <<'V'
#!/bin/sh
printf 'RAN tier=%s arg=%s files=' "${SHIPINETICS_VERIFY_TIER:-none}" "${1:-}"
if [ -n "${SHIPINETICS_CHANGED_FILES:-}" ]; then tr '\n' '|' <"$SHIPINETICS_CHANGED_FILES"; fi
echo
[ -f FAIL ] && { echo boom; exit 1; }
exit 0
V
  chmod +x "$1"
}

# stop_hook <project root> [stop_hook_active]: run the Stop hook as Claude Code would; sets OUT and RC
stop_hook() {
  OUT="$(printf '{"session_id":"s1","stop_hook_active":%s}' "${2:-false}" | CLAUDE_PROJECT_DIR="$1" bash "$SY/scripts/stop-verify.sh" 2>&1)"
  RC=$?
}

# last_timing <project root>: "<tier> <result>" from the newest timing row
last_timing() { tail -n 1 "$1/.shipinetics/.cache/verify-times.tsv" | cut -f4,6 | tr '\t' ' '; }

# replace <file> <old> <new>: in-place literal replacement, portable across macOS and Linux
replace() { python3 - "$@" <<'PY'
import sys
p, a, b = sys.argv[1:4]
s = open(p).read()
open(p, "w").write(s.replace(a, b))
PY
}

ok()   { printf '  ok    %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n        %s\n' "$1" "$2"; fails=$((fails + 1)); }
eq()   { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected [$3], got [$2]"; fi; }
has()  { case "$2" in *"$3"*) ok "$1" ;; *) bad "$1" "expected output to contain [$3], got [$2]" ;; esac; }
hasnt(){ case "$2" in *"$3"*) bad "$1" "expected output not to contain [$3], got [$2]" ;; *) ok "$1" ;; esac; }
done_testing() { [ "$fails" = 0 ]; }
