# The session-start hook installs the shims by itself, only into a folder on the PATH, and stays quiet after.
. "$(dirname "$0")/helpers.sh"
dir="$scratch/shimbin"; mkdir -p "$dir"
export SHIPINETICS_SHIM_DIR="$dir"
t="$scratch/proj"; mkdir -p "$t"
hook() { OUT="$(printf '{"hook_event_name":"SessionStart","cwd":"%s"}' "$t" | PATH="$1" bash "$SY/scripts/shims-auto.sh" 2>&1)"; RC=$?; }

hook "$PATH"; eq "not on the PATH: the hook exits 0" "$RC" 0
eq "not on the PATH: it writes nothing" "$(ls "$dir")" ""

hook "$dir:$PATH"; has "on the PATH: it tells the user" "$OUT" "your terminal can now run the shipinetics-* tools by name"
has "and names the tools" "$OUT" "shipinetics-config"
has "and how to switch it off" "$OUT" "hooks_off = shims"
[ -x "$dir/shipinetics-config" ] && ok "the shim is there and runs" || bad "the shim is there and runs" "missing"
mkdir -p "$t/.shipinetics"
eq "the shim runs the plugin's tool" "$(SHIPINETICS_HOME="$SY" "$dir/shipinetics-config" -C "$t" root 2>&1)" "$(cd "$t" && pwd)"

hook "$dir:$PATH"; eq "a second session says nothing" "$OUT" ""
printf '#!/bin/sh\n# Written by shipinetics-shims. Run '"'"'shipinetics-shims remove'"'"' to remove it.\necho old\n' >"$dir/shipinetics-verify"
hook "$dir:$PATH"; has "an old shim is refreshed" "$OUT" "shipinetics-verify"
hasnt "and only that one is named" "$OUT" "shipinetics-config"

printf '#!/bin/sh\necho mine\n' >"$dir/shipinetics-update"
rm "$dir/shipinetics-config"
hook "$dir:$PATH"; eq "another program's file stays" "$(cat "$dir/shipinetics-update")" "$(printf '#!/bin/sh\necho mine')"
hasnt "and isn't named" "$OUT" "shipinetics-update"

rm "$dir/shipinetics-config"
SHIPINETICS_HOOKS_OFF=shims hook "$dir:$PATH"; eq "SHIPINETICS_HOOKS_OFF=shims: nothing" "$OUT" ""
[ -e "$dir/shipinetics-config" ] && bad "hooks off: no shim written" "written" || ok "hooks off: no shim written"
mkdir -p "$XDG_CONFIG_HOME/shipinetics"; echo "hooks_off = shims" >"$XDG_CONFIG_HOME/shipinetics/config"
hook "$dir:$PATH"; eq "hooks_off = shims in the user config: nothing" "$OUT" ""
rm "$XDG_CONFIG_HOME/shipinetics/config"

rmdir "$scratch/none" 2>/dev/null; SHIPINETICS_SHIM_DIR="$scratch/none" hook "$scratch/none:$PATH"
[ -e "$scratch/none" ] && bad "a missing folder isn't created" "created" || ok "a missing folder isn't created"

python3 - "$SY" <<'PY' && ok "both hook files register it" || bad "both hook files register it" "missing"
import json, sys
r = sys.argv[1]
c = json.load(open(r + "/hooks/hooks.json"))["hooks"]["SessionStart"]
a = json.load(open(r + "/hooks.json"))["shipinetics"]["SessionStart"]
assert any("shims-auto.sh" in h["command"] for e in c for h in e["hooks"])
assert any("shims-auto.sh" in h["command"] for h in a)
PY
done_testing
