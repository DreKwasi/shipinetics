#!/usr/bin/env bash
# compat.sh: makes python3 and jq behave on Windows (Git Bash) as they do on macOS and Linux.
# Source it, don't run it. scripts/lib.sh sources it, and so does each tool that doesn't use lib.sh.
#
# The problems on Windows, and what this file does about them:
# - python3 is often missing, or it is a Microsoft Store stub that only prints an error. Python from
#   python.org installs "python" and the "py" launcher instead. This file finds a working Python 3
#   once, and keeps the answer in ${XDG_CACHE_HOME:-~/.cache}/shipinetics/python, so each hook doesn't
#   start Python up to three times to find it. A Store stub is skipped by its path, without running it.
# - Windows Python and jq end each line with "\r\n", so bash sees a stray "\r" in each value. The
#   python3 and jq functions below remove the "\r" from what they print, and keep the exit code.
# - Windows Python reads and writes pipes in the ANSI code page, so a UTF-8 path in hook input can
#   decode wrongly. The python3 function runs Python in UTF-8 mode (-X utf8), and unbuffered (-u).
# The functions are not exported: each Shipinetics tool sources this file itself, and a project's
# own commands (bin/verify, its tests) must get the real python3 and jq. On macOS and Linux this
# file does nothing.

case "${OSTYPE:-}" in
  msys*|cygwin*|win*)
    # sy_py_ok <python command>: it is a real Python 3 (not a Store stub) that runs
    sy_py_ok() {
      local p; p="$(command -v "${1%% *}" 2>/dev/null)" || return 1
      case "$p" in */WindowsApps/*) return 1 ;; esac
      # shellcheck disable=SC2086  # $1 can be "py -3"
      PYTHON_MANAGER_AUTOMATIC_INSTALL=0 command $1 -c 'import sys; sys.exit(sys.version_info[0] != 3)' </dev/null >/dev/null 2>&1
    }
    sy_py_cache="${XDG_CACHE_HOME:-$HOME/.cache}/shipinetics/python"
    if [ -z "${SY_PYTHON:-}" ] && [ -f "$sy_py_cache" ]; then SY_PYTHON="$(head -n 1 "$sy_py_cache")"; fi
    # A remembered answer must still name a command that exists and isn't a Store stub (checked by its
    # path, without running it); else find it again.
    if [ -n "${SY_PYTHON:-}" ]; then
      sy_py_path="$(command -v "${SY_PYTHON%% *}" 2>/dev/null)" || sy_py_path=""
      case "$sy_py_path" in ""|*/WindowsApps/*) SY_PYTHON="" ;; esac
    fi
    if [ -z "${SY_PYTHON:-}" ]; then
      for c in python3 python "py -3"; do
        if sy_py_ok "$c"; then SY_PYTHON="$c"; break; fi
      done
      if [ -n "${SY_PYTHON:-}" ]; then
        { mkdir -p "${sy_py_cache%/*}" && printf '%s\n' "$SY_PYTHON" >"$sy_py_cache"; } 2>/dev/null
      fi
    fi
    if [ -n "${SY_PYTHON:-}" ]; then
      # shellcheck disable=SC2086  # SY_PYTHON can be "py -3"
      python3() { command $SY_PYTHON -X utf8 -u "$@" | tr -d '\r'; return "${PIPESTATUS[0]}"; }
    fi
    if command -v jq >/dev/null 2>&1; then
      jq() { command jq "$@" | tr -d '\r'; return "${PIPESTATUS[0]}"; }
    fi
    ;;
esac
