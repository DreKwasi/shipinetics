# shipinetics-config: defaults and project values.
. "$(dirname "$0")/helpers.sh"
p="$scratch/cfg"; new_repo "$p"; cd "$p" || exit 1
mkdir -p .shipinetics
eq "agents launch the app by default" "$(shipinetics-config get launch)" agent
printf 'launch = user   # the user runs the servers\n' >.shipinetics/config
eq "launch = user is read" "$(shipinetics-config get launch)" user
done_testing
