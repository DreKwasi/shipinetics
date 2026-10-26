#!/usr/bin/env bash
# run.sh: run every shipinetics test. Exit code 0 means all passed.
# Usage: tests/run.sh [test file...]
# Run it with the bash you want to check, for example /bin/bash tests/run.sh on macOS (bash 3.2).

cd "$(dirname "$0")" || exit 1
status=0
[ $# -gt 0 ] || set -- test-*.sh
for t in "$@"; do
  echo "== $t"
  "${BASH:-bash}" "$t" || status=1
done
[ "$status" = 0 ] && echo "all tests passed" || echo "some tests failed"
exit "$status"
