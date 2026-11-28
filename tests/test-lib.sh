# scripts/lib.sh helpers that no tool's test covers on its own: sy_unix_path, which turns a Windows
# path (C:\x, C:/x) into the form Git Bash uses (/c/x), so paths from hook input, git and config
# compare with the shell's own.
. "$(dirname "$0")/helpers.sh"
# shellcheck source=../scripts/lib.sh
. "$SY/scripts/lib.sh"

# nocyg: a PATH without cygpath, so the bash branch runs on every system, Windows too. It needs only
# tr, from a wrapper (a copied tr.exe can't find its DLLs on Windows).
nocyg="$scratch/nocyg"; mkdir -p "$nocyg"
printf '#!/bin/sh\nexec %s "$@"\n' "$(command -v tr)" >"$nocyg/tr"; chmod +x "$nocyg/tr"
# unix_bash <path>: sy_unix_path without cygpath
unix_bash() { (PATH="$nocyg"; sy_unix_path "$1"); }
# unix_msys <path>: sy_unix_path without cygpath, as if in Git Bash on Windows
unix_msys() { (PATH="$nocyg"; OSTYPE=msys; sy_unix_path "$1"); }

# ---- the bash branch (no cygpath)
eq "sy_unix_path: C:\\ with a space and backslashes becomes /c/... with slashes" "$(unix_bash 'C:\a b\x')" "/c/a b/x"
eq "sy_unix_path: a lower-case drive with a slash becomes /c/x" "$(unix_bash 'c:/x')" "/c/x"
eq "sy_unix_path: a bare drive becomes /c" "$(unix_bash 'C:')" "/c"
eq "sy_unix_path: a drive-relative C:foo stays as it is" "$(unix_bash 'C:foo')" "C:foo"
eq "sy_unix_path: a path already in Git Bash form stays as it is" "$(unix_bash '/c/x')" "/c/x"
if on_windows; then
  eq "sy_unix_path: on Windows a relative a\\b gets slashes" "$(unix_bash 'a\b')" "a/b"
else
  eq "sy_unix_path: off Windows a relative a\\b stays as it is (a backslash is a file name character)" "$(unix_bash 'a\b')" 'a\b'
fi
eq "sy_unix_path: in Git Bash (OSTYPE=msys) a relative a\\b gets slashes" "$(unix_msys 'a\b')" "a/b"

# ---- with cygpath (Windows): the same answers
if command -v cygpath >/dev/null 2>&1; then
  eq "sy_unix_path with cygpath: C:\\a b\\x becomes /c/a b/x" "$(sy_unix_path 'C:\a b\x')" "/c/a b/x"
  eq "sy_unix_path with cygpath: c:/x becomes /c/x" "$(sy_unix_path 'c:/x')" "/c/x"
else
  printf '  skip  sy_unix_path with cygpath (no cygpath here: only Git Bash on Windows has it)\n'
fi

done_testing
