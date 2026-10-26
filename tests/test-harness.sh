# Workspace mode: shipinetics-config warns when the root's own files aren't in any git repo.
. "$(dirname "$0")/helpers.sh"
w="$scratch/ws"; mkdir -p "$w/.shipinetics"; cd "$w" || exit 1
new_repo api
printf 'packages = api\npackage_verify_cmd = true\n' >.shipinetics/config
has "plain root: warns" "$(shipinetics-config 2>&1)" "warning: the root isn't a git repo"
new_repo "$scratch/harness"
printf 'harness_repo = ../harness\n' >>.shipinetics/config
has "harness_repo set: no warning" "$(shipinetics-config 2>&1)" "harness files versioned in: $(cd "$scratch/harness" && pwd -P)"
printf 'packages = api\nharness_repo = ../nowhere\n' >.shipinetics/config
has "harness_repo that isn't a repo: warns" "$(shipinetics-config 2>&1)" "warning:"
printf 'packages = api\n' >.shipinetics/config; new_repo "$w"
has "root is a repo: no warning" "$(shipinetics-config 2>&1)" "harness files versioned in: $w"
done_testing
