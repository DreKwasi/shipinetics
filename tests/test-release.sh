# release.sh: manifest validation, semver bumping, changelog gate, and release commit + tag.
. "$(dirname "$0")/helpers.sh"

r="$scratch/rel"; new_repo "$r"
mkdir -p "$r/.claude-plugin" "$r/scripts" "$r/tests"
cp "$SY/scripts/release.sh" "$r/scripts/release.sh"
chmod +x "$r/scripts/release.sh"
printf '{"name":"shipinetics","version":"0.9.3"}\n' >"$r/.claude-plugin/plugin.json"
printf '{"name":"shipinetics","version":"0.9.3"}\n' >"$r/plugin.json"
printf '# Changelog\n\n## 0.9.3\n\n- Initial.\n' >"$r/CHANGELOG.md"
printf '#!/usr/bin/env bash\necho all tests passed\n' >"$r/tests/run.sh"
chmod +x "$r/tests/run.sh"
git -C "$r" add -A; git -C "$r" commit -qm "init"; git -C "$r" tag v0.9.3

out="$(bash "$r/scripts/release.sh" --check 2>&1)"; rc=$?
eq "--check exits 0 when manifests and CHANGELOG match" "$rc" 0
has "--check confirms version" "$out" "version 0.9.3"

# Mismatched manifests fail --check
printf '{"name":"shipinetics","version":"0.9.2"}\n' >"$r/plugin.json"
out="$(bash "$r/scripts/release.sh" --check 2>&1)"; rc=$?
eq "--check fails on manifest version mismatch" "$rc" 1
has "--check names the mismatch" "$out" "version mismatch"
printf '{"name":"shipinetics","version":"0.9.3"}\n' >"$r/plugin.json"

# --dry-run computes patch, minor, major without touching files
out="$(bash "$r/scripts/release.sh" patch --dry-run 2>&1)"; rc=$?
eq "patch --dry-run exits 0" "$rc" 0
has "patch --dry-run computes 0.9.4" "$out" "Next version:    0.9.4"

out="$(bash "$r/scripts/release.sh" minor --dry-run 2>&1)"; rc=$?
has "minor --dry-run computes 0.10.0" "$out" "Next version:    0.10.0"

out="$(bash "$r/scripts/release.sh" major --dry-run 2>&1)"; rc=$?
has "major --dry-run computes 1.0.0" "$out" "Next version:    1.0.0"

# Refuses release without CHANGELOG entry
out="$(bash "$r/scripts/release.sh" patch 2>&1)"; rc=$?
eq "release refuses missing CHANGELOG section" "$rc" 1
has "release says there is nothing to release" "$out" "nothing under '## Unreleased'"
printf '# Changelog\n\n## Unreleased\n\n## 0.9.3\n\n- Initial.\n' >"$r/CHANGELOG.md"
out="$(bash "$r/scripts/release.sh" patch 2>&1)"; rc=$?
eq "release refuses an empty Unreleased section" "$rc" 1
git -C "$r" checkout -q CHANGELOG.md

# Refuses dirty working tree (other than CHANGELOG.md)
echo dirty >"$r/dirty.txt"
out="$(bash "$r/scripts/release.sh" patch 2>&1)"; rc=$?
eq "release refuses dirty tree" "$rc" 1
has "release says uncommitted changes" "$out" "uncommitted changes"
rm -f "$r/dirty.txt"

# Clean release updates both manifests, commits, and tags v0.9.4
printf '# Changelog\n\n## 0.9.4\n\n### Added\n- Antigravity support.\n\n## 0.9.3\n\n- Initial.\n' >"$r/CHANGELOG.md"
out="$(bash "$r/scripts/release.sh" patch 2>&1)"; rc=$?
eq "clean patch release exits 0" "$rc" 0
has "release reports tag v0.9.4" "$out" "Created commit and tag v0.9.4"
eq ".claude-plugin/plugin.json updated to 0.9.4" "$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$r/.claude-plugin/plugin.json")" "0.9.4"
eq "plugin.json updated to 0.9.4" "$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$r/plugin.json")" "0.9.4"
eq "git tag v0.9.4 points at HEAD" "$(git -C "$r" rev-parse v0.9.4^{commit})" "$(git -C "$r" rev-parse HEAD)"

# A release turns '## Unreleased' into the version's section, and adds a new empty one
printf '# Changelog\n\n## Unreleased\n\n### Fixed\n- A fix.\n\n## 0.9.4\n\n### Added\n- Antigravity support.\n\n## 0.9.3\n\n- Initial.\n' >"$r/CHANGELOG.md"
git -C "$r" commit -qam "a fix"
out="$(bash "$r/scripts/release.sh" patch --dry-run 2>&1)"
has "dry run says Unreleased becomes the version" "$out" "'## Unreleased' becomes '## 0.9.5'"
out="$(bash "$r/scripts/release.sh" patch 2>&1)"; rc=$?
eq "release from Unreleased exits 0" "$rc" 0
eq "Unreleased becomes 0.9.5, with a new empty Unreleased above it" "$(sed -n 3,8p "$r/CHANGELOG.md" | tr '\n' '|')" "## Unreleased||## 0.9.5||### Fixed|- A fix.|"
eq "the release commit has the CHANGELOG change" "$(git -C "$r" status --porcelain)" ""
out="$(bash "$r/scripts/release.sh" --check 2>&1)"; rc=$?
eq "--check passes after the release" "$rc" 0

# Refuses duplicate tag
out="$(bash "$r/scripts/release.sh" 0.9.4 2>&1)"; rc=$?
eq "release refuses same version" "$rc" 1

done_testing
