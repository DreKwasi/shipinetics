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

# safe-local-setup AC15: a symlink in the shim folder is never written through, also a broken one.
# Two links: a broken one, and one to an outside file that looks like a shim (it has the marker).
links_ok() { ln -s "$scratch/nowhere" "$scratch/probe" 2>/dev/null && [ -L "$scratch/probe" ]; local r=$?; rm -f "$scratch/probe"; return "$r"; }
outside="$scratch/outside"; mkdir -p "$outside"
sym_setup() {   # sym_setup <shim folder>
  rm -f "$1/shipinetics-config" "$1/shipinetics-verify" "$outside/looks-like-a-shim"; rm -rf "$outside/missing"; mkdir -p "$outside/missing"   # the folder exists, so a write through the broken link would make its target
  printf '#!/bin/sh\n# Written by shipinetics-shims. Run '"'"'shipinetics-shims remove'"'"' to remove it.\necho outside\n' >"$outside/looks-like-a-shim"
  cp "$outside/looks-like-a-shim" "$scratch/looks-before"
  ln -s "$outside/missing/target" "$1/shipinetics-config"
  ln -s "$outside/looks-like-a-shim" "$1/shipinetics-verify"
}
# sym_result <shim folder>: "links:N broken-target:<made|none> outside-file:<same|changed>"
sym_result() {
  local n=0
  [ -L "$1/shipinetics-config" ] && n=$((n + 1)); [ -L "$1/shipinetics-verify" ] && n=$((n + 1))
  printf 'links:%s broken-target:%s outside-file:%s' "$n" \
    "$([ -e "$outside/missing/target" ] && echo made || echo none)" \
    "$(cmp -s "$outside/looks-like-a-shim" "$scratch/looks-before" && echo same || echo changed)"
}
if links_ok; then
  sym_setup "$dir"
  hook "$dir:$PATH"
  eq "safe-local-setup AC15: the automatic install skips both symlinks and writes nothing through them" "$(sym_result "$dir")" "links:2 broken-target:none outside-file:same"
  rm -f "$dir/shipinetics-config" "$dir/shipinetics-verify"
else
  printf '  skip  automatic shims and symlinks (ln -s makes copies here)\n'
fi

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
