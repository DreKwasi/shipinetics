# helpers.sh: shared setup and assertions for shipinetics's own tests. Source it from a test.
# Every test works in a scratch folder under $TMPDIR and never touches this repo.

set -uo pipefail
# The physical path (pwd -P): the tools resolve symlinks (/tmp -> /private/tmp on macOS), so the
# tests must compare against the same path.
SY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fails=0
t="${TMPDIR:-/tmp}"; scratch="$(mktemp -d "${t%/}/shipinetics-test.XXXXXX")"   # macOS runners end TMPDIR in /
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
  case "$v" in SHIPINETICS_*|CLAUDE_PROJECT_DIR|CLAUDE_PLUGIN_ROOT|CLAUDECODE|CLAUDE_CODE_*|PLUGIN_ROOT|PLUGIN_DATA|GEMINI_CONFIG_DIR|GEMINI_HOME) unset "$v" ;; esac
done
tool_dirs="$(dirname "${BASH:-/bin/bash}")"
tools="git jq python3 perl ffmpeg"
case "${OSTYPE:-}" in msys*|cygwin*|win*) tools="$tools python py cygpath" ;; esac   # compat.sh may pick python or py
for t in $tools; do
  t="$(command -v "$t" 2>/dev/null)" && tool_dirs="$tool_dirs:$(dirname "$t")"
done
export PATH="$SY/bin:$tool_dirs:/usr/bin:/bin:/usr/sbin:/sbin"
unset t v tool_dirs tools
# The tests' own python3 and jq behave like the tools' (on Windows: no "\r" in their output). After
# PATH is set: compat.sh defines python3 as a function, so command -v python3 above must run first.
# On macOS and Linux it does nothing.
# shellcheck source=../scripts/compat.sh
. "$SY/scripts/compat.sh"

# on_windows: true in Git Bash (or Cygwin) on Windows
on_windows() { case "${OSTYPE:-}" in msys*|cygwin*|win*) return 0 ;; esac; return 1; }

# same_path <path>: a path in one form, to compare a path that a native Windows program printed
# (C:\x, C:/x, 8.3 short names such as RUNNER~1) with the shell's (/tmp/x, /c/x). Long names first,
# so the /tmp mount (a short name) and its long name give the same result. Use it on both sides of a
# comparison, on paths that exist. Elsewhere the path comes back unchanged, so comparisons stay exact.
same_path() {
  if on_windows && command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$(cygpath -l -w "$1" 2>/dev/null || cygpath -w "$1")"
  else
    printf '%s\n' "$1"
  fi
}

# native_path <path>: the path as a native program writes it in a transcript or hook input:
# C:\x\y on Windows (long names when the path exists), unchanged elsewhere.
native_path() {
  if on_windows && command -v cygpath >/dev/null 2>&1; then
    cygpath -l -w "$1" 2>/dev/null || cygpath -w "$1"
  else
    printf '%s\n' "$1"
  fi
}

# json_path <path>: native_path, escaped for a JSON string (backslashes doubled)
json_path() { native_path "$1" | sed 's/\\/\\\\/g'; }

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

# with_tty <input> <command...>: run a command with a terminal on stdin, typing the input
# (Not pty.spawn: it stops copying when the child exits, so output can go missing on macOS.)
with_tty() {
  python3 - "$@" <<'PY' 2>&1
import os, pty, sys
pid, fd = pty.fork()
if pid == 0:
    os.execvp(sys.argv[2], sys.argv[2:])
os.write(fd, sys.argv[1].encode())
out = b""
while True:
    try:
        chunk = os.read(fd, 4096)
    except OSError:    # Linux: EIO once the child has gone and the output is drained
        break
    if not chunk:      # macOS: end of file
        break
    out += chunk
_, status = os.waitpid(pid, 0)
sys.stdout.write(out.decode(errors="replace"))
sys.exit((status >> 8) & 0xff)
PY
}

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
