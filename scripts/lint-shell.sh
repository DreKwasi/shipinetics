#!/usr/bin/env bash
# lint-shell.sh: runs shellcheck on each shell script that the plugin ships, at severity warning.
# Usage: bash scripts/lint-shell.sh   (needs shellcheck on the PATH)
# The templates in skills/setup/templates/bin/ that hold {{placeholders}} are left out: setup fills
# them in for each project, so they aren't valid shell until then.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v shellcheck >/dev/null 2>&1 || { echo "lint-shell: shellcheck isn't installed" >&2; exit 2; }
files=()
for f in scripts/*.sh bin/* skills/setup/templates/pre-push skills/setup/templates/pre-commit \
         skills/setup/templates/commit-msg skills/setup/templates/bin/*; do
  [ -f "$f" ] || continue
  head -n 1 "$f" | grep -qE '^#!.*(bash|/sh)' || continue
  case "$f" in skills/setup/templates/bin/*) grep -q '{{' "$f" && continue ;; esac
  files+=("$f")
done
echo "lint-shell: ${#files[@]} files"
# SC1090, SC1091: the tools source scripts/lib.sh and compat.sh by a path that they work out when
# they run, so shellcheck can't follow it.
shellcheck --severity=warning --external-sources --exclude=SC1090,SC1091 "${files[@]}"
echo "lint-shell: ok"
