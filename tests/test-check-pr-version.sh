# check-pr-version.sh: a pull request never sets the version. Only release.sh does.
. "$(dirname "$0")/helpers.sh"

r="$scratch/pr"; new_repo "$r"
mkdir -p "$r/.claude-plugin" "$r/scripts"
cp "$SY/scripts/check-pr-version.sh" "$r/scripts/"
printf '{"name":"shipinetics","version":"0.9.5"}\n' >"$r/.claude-plugin/plugin.json"
printf '{"name":"shipinetics","version":"0.9.5"}\n' >"$r/plugin.json"
printf '# Changelog\n\n## Unreleased\n\n## 0.9.5\n\n- Initial.\n' >"$r/CHANGELOG.md"
git -C "$r" add -A; git -C "$r" commit -qm init; git -C "$r" branch base
check() { out="$(bash "$r/scripts/check-pr-version.sh" base 2>&1)"; rc=$?; }

printf '# Changelog\n\n## Unreleased\n\n### Fixed\n- A fix.\n\n## 0.9.5\n\n- Initial.\n' >"$r/CHANGELOG.md"
check
eq "an entry under Unreleased passes" "$rc" "0"

printf '# Changelog\n\n## 0.9.6\n\n### Fixed\n- A fix.\n\n## 0.9.5\n\n- Initial.\n' >"$r/CHANGELOG.md"
check
eq "a new release heading fails" "$rc" "1"
has "and names it" "$out" "adds a release heading: ## 0.9.6"
git -C "$r" checkout -q CHANGELOG.md

printf '{"name":"shipinetics","version":"0.9.6"}\n' >"$r/plugin.json"
check
eq "a version change in a manifest fails" "$rc" "1"
has "and names the manifest" "$out" "plugin.json changes the version from 0.9.5 to 0.9.6"
git -C "$r" checkout -q plugin.json

out="$(bash "$r/scripts/check-pr-version.sh" 2>&1)"; rc=$?
eq "no base ref is bad usage" "$rc" "2"
done_testing
