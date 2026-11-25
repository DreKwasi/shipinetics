#!/usr/bin/env bash
# check-pr-version.sh: a pull request never sets the version. Only scripts/release.sh does.
#
# Usage: scripts/check-pr-version.sh <base ref>
#   Fails (exit 1) when, compared with <base ref>:
#   - the version in .claude-plugin/plugin.json or plugin.json changed, or
#   - CHANGELOG.md has a new "## X.Y.Z" heading.
#   A pull request puts its CHANGELOG entries under "## Unreleased" instead.
# CI runs it on each pull request, except from a release/* branch.
# Exit codes: 0 ok, 1 the pull request sets the version, 2 bad usage.

set -uo pipefail
base="${1:-}"
[ -n "$base" ] || { echo "usage: scripts/check-pr-version.sh <base ref>" >&2; exit 2; }
repo="$(cd "$(dirname "$0")/.." && pwd -P)"
git -C "$repo" rev-parse -q --verify "$base^{commit}" >/dev/null || { echo "check-pr-version: can't find $base" >&2; exit 2; }

problems=""
ver_at() {
  git -C "$repo" show "$1:$2" 2>/dev/null |
    python3 -I -c 'import json,sys; print(json.load(sys.stdin).get("version",""))' 2>/dev/null
}
for m in .claude-plugin/plugin.json plugin.json; do
  old="$(ver_at "$base" "$m")"
  new="$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1])).get("version",""))' "$repo/$m" 2>/dev/null)"
  if [ -n "$old" ] && [ "$old" != "$new" ]; then
    problems="$problems
- $m changes the version from $old to $new."
  fi
done

added="$(git -C "$repo" diff "$base" -- CHANGELOG.md | grep -E '^\+## [0-9]+\.[0-9]+\.[0-9]+' | sed 's/^+//' || true)"
if [ -n "$added" ]; then
  problems="$problems
- CHANGELOG.md adds a release heading: $(printf '%s' "$added" | tr '\n' ' ')"
fi

if [ -n "$problems" ]; then
  echo "check-pr-version: this pull request sets the version.$problems" >&2
  echo "Put the CHANGELOG entries under '## Unreleased' and keep the manifest versions. scripts/release.sh sets the version when you release." >&2
  exit 1
fi
echo "check-pr-version: ok (the pull request doesn't set the version)"
