#!/usr/bin/env bash
# compat.sh: makes python3 and jq behave on Windows (Git Bash) as they do on macOS and Linux.
# Source it, don't run it. scripts/lib.sh sources it, and so does each tool that doesn't use lib.sh.
#
# The problems on Windows, and what this file does about them:
# - python3 is often missing, or it is a Microsoft Store stub that only prints an error. Python from
#   python.org installs "python" and the "py" launcher instead. This file finds a working Python 3.
# - Windows Python and jq end each line with "\r\n", so bash sees a stray "\r" in each value. The
#   python3 and jq functions below remove the "\r" from what they print, and keep the exit code.
#   python3 runs unbuffered (-u), so a long-running command such as a server shows its output at once.
# It exports the functions, so child bash scripts get them too. On macOS and Linux it does nothing.

case "${OSTYPE:-}" in
  msys*|cygwin*|win*)
    if [ -z "${SY_PYTHON+x}" ]; then
      if command python3 -c '' >/dev/null 2>&1; then SY_PYTHON="python3"
      elif command python -c 'import sys; sys.exit(sys.version_info[0] != 3)' >/dev/null 2>&1; then SY_PYTHON="python"
      elif command py -3 -c '' >/dev/null 2>&1; then SY_PYTHON="py -3"
      else SY_PYTHON=""
      fi
      export SY_PYTHON
    fi
    if [ -n "$SY_PYTHON" ]; then
      # shellcheck disable=SC2086  # SY_PYTHON can be "py -3"
      python3() { command $SY_PYTHON -u "$@" | tr -d '\r'; return "${PIPESTATUS[0]}"; }
      export -f python3
    fi
    if command -v jq >/dev/null 2>&1; then
      jq() { command jq "$@" | tr -d '\r'; return "${PIPESTATUS[0]}"; }
      export -f jq
    fi
    ;;
esac
