#!/usr/bin/env bash
# release.sh: cut a Shipinetics release safely.
#
# Usage:
#   scripts/release.sh --check                           Verify manifests and CHANGELOG match
#   scripts/release.sh <patch|minor|major|X.Y.Z>         Bump manifests, run tests, commit and tag vX.Y.Z
#   scripts/release.sh <patch|minor|major|X.Y.Z> --dry-run
#                                                        Show the next version and commits since last tag
# Options:
#   --dry-run   Print what would happen without modifying files or git
#   --no-test   Skip running tests/run.sh (for emergencies only)
#   --check     Validate that plugin.json and .claude-plugin/plugin.json match
#
# Before running, add a `## X.Y.Z` section to CHANGELOG.md (following its SemVer rules).
# After running, push the commit and tag with: git push origin main vX.Y.Z
# Exit codes: 0 ok, 1 validation/test failure, 2 bad usage.

set -uo pipefail
usage() { sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; }
case "${1:-}" in -h|--help|"") usage; exit 0 ;; esac

repo="$(cd "$(dirname "$0")/.." && pwd -P)"
die() { echo "release: $*" >&2; exit 2; }
fail() { echo "release: $*" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || die "python3 is required"

mode="" dry=0 run_tests=1
while [ $# -gt 0 ]; do
  case "$1" in
    --check) mode="check"; shift ;;
    --dry-run) dry=1; shift ;;
    --no-test) run_tests=0; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *) [ -z "$mode" ] || die "unexpected argument: $1"; mode="$1"; shift ;;
  esac
done
[ -n "$mode" ] || die "give patch, minor, major, X.Y.Z, or --check"

read_ver() {
  python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get("version",""))' "$1" 2>/dev/null
}

c_manifest="$repo/.claude-plugin/plugin.json"
a_manifest="$repo/plugin.json"
[ -f "$c_manifest" ] || fail "missing $c_manifest"
[ -f "$a_manifest" ] || fail "missing $a_manifest"

c_ver="$(read_ver "$c_manifest")"
a_ver="$(read_ver "$a_manifest")"
[ -n "$c_ver" ] || fail "no version in $c_manifest"
[ "$c_ver" = "$a_ver" ] || fail "version mismatch: .claude-plugin/plugin.json=$c_ver, plugin.json=$a_ver"

if [ "$mode" = "check" ]; then
  if ! grep -qE "^## ${c_ver}([[:space:]]|\$)" "$repo/CHANGELOG.md"; then
    fail "CHANGELOG.md has no '## $c_ver' section"
  fi
  echo "release: ok (version $c_ver matches both manifests and CHANGELOG.md)"
  exit 0
fi

# Compute next version
next="$(python3 -I - "$c_ver" "$mode" <<'PY'
import re, sys
cur, bump = sys.argv[1], sys.argv[2]
m = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)", cur)
if not m:
    sys.exit("current version is not semver: " + cur)
maj, minor, pat = (int(x) for x in m.groups())
if bump == "patch":
    print(f"{maj}.{minor}.{pat + 1}")
elif bump == "minor":
    print(f"{maj}.{minor + 1}.0")
elif bump == "major":
    print(f"{maj + 1}.0.0")
elif re.fullmatch(r"\d+\.\d+\.\d+", bump):
    print(bump)
else:
    sys.exit("invalid bump or version: " + bump)
PY
)" || die "invalid bump or version: $mode (use patch, minor, major, or X.Y.Z)"

[ "$next" != "$c_ver" ] || fail "next version ($next) is the same as current version ($c_ver)"
if git -C "$repo" rev-parse -q --verify "refs/tags/v$next" >/dev/null 2>&1; then
  fail "tag v$next already exists"
fi

last_tag="$(git -C "$repo" tag -l 'v*' --sort=-v:refname | head -n 1)"

if [ "$dry" = 1 ]; then
  echo "Current version: $c_ver"
  echo "Next version:    $next (tag v$next)"
  if [ -n "$last_tag" ]; then
    echo "Commits since $last_tag:"
    git -C "$repo" log --oneline "$last_tag..HEAD" | sed 's/^/  /'
  fi
  if grep -qE "^## ${next}([[:space:]]|\$)" "$repo/CHANGELOG.md"; then
    echo "CHANGELOG.md:    has '## $next' section"
  else
    echo "CHANGELOG.md:    missing '## $next' section (add it before releasing)"
  fi
  exit 0
fi

# Require clean working tree (CHANGELOG.md may be modified/staged if user just wrote the release entry)
dirty="$(git -C "$repo" status --porcelain | grep -vE '^[ M?][ M?] CHANGELOG\.md$' || true)"
[ -z "$dirty" ] || fail "working tree has uncommitted changes (commit or stash first):
$dirty"

if ! grep -qE "^## ${next}([[:space:]]|\$)" "$repo/CHANGELOG.md"; then
  echo "release: CHANGELOG.md has no '## $next' section yet." >&2
  if [ -n "$last_tag" ]; then
    echo "Commits since $last_tag:" >&2
    git -C "$repo" log --oneline "$last_tag..HEAD" | sed 's/^/  /' >&2
  fi
  exit 1
fi

if [ "$run_tests" = 1 ]; then
  echo "Running tests..."
  (cd "$repo" && bash tests/run.sh) || fail "tests failed; release aborted"
fi

# Update version in both manifests
python3 -I - "$next" "$c_manifest" "$a_manifest" <<'PY' || fail "failed to update manifests"
import json, sys
ver = sys.argv[1]
for p in sys.argv[2:]:
    data = json.load(open(p, encoding="utf-8"))
    data["version"] = ver
    with open(p, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
PY

git -C "$repo" add .claude-plugin/plugin.json plugin.json CHANGELOG.md
git -C "$repo" commit -m "Release $next"
git -C "$repo" tag -a "v$next" -m "Release $next"

echo "Created commit and tag v$next."
echo "Push with: git push origin main v$next"
