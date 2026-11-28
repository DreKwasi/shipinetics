# shipinetics-shims: short commands for the shipinetics-* tools in the user's own terminal.
. "$(dirname "$0")/helpers.sh"
shims="$HOME/.local/bin"

out="$(shipinetics-shims install 2>&1)"
has "install writes the shims" "$out" "shims in $shims"
eq "a shim for shipinetics-config" "$([ -x "$shims/shipinetics-config" ] && echo yes)" "yes"
eq "no shim for a tool with a common name" "$([ -e "$shims/worksheet" ] && echo yes || echo no)" "no"
has "it says when the folder isn't on the PATH" "$out" "isn't on the PATH here"

# The shim runs the tool from the plugin that Claude Code's installed_plugins.json names.
mkdir -p "$HOME/.claude/plugins"
printf '{"version":2,"plugins":{"shipinetics@shipinetics":[{"scope":"user","installPath":"%s","version":"x"}]}}\n' "$SY" \
  >"$HOME/.claude/plugins/installed_plugins.json"
p="$scratch/proj"; new_repo "$p"; mkdir -p "$p/.shipinetics"
eq "the shim finds the installed plugin" "$(cd / && "$shims/shipinetics-config" -C "$p" root)" "$p"
eq "SHIPINETICS_HOME wins" "$(SHIPINETICS_HOME="$scratch/none" "$shims/shipinetics-config" root 2>&1 >/dev/null | grep -c "doesn't exist")" "1"
rm -f "$HOME/.claude/plugins/installed_plugins.json"
out="$("$shims/shipinetics-config" root 2>&1)"; rc=$?
eq "with no plugin, the shim fails" "$rc" "127"
has "and says why" "$out" "can't find the Shipinetics plugin"

out="$(shipinetics-shims status 2>&1)"; rc=$?
eq "status passes when each shim is there" "$rc" "0"
rm -f "$shims/shipinetics-usage"; echo mine >"$shims/shipinetics-usage"
out="$(shipinetics-shims install 2>&1)"
has "install skips a file that it didn't write" "$out" "skipped $shims/shipinetics-usage"
eq "and leaves it as it was" "$(cat "$shims/shipinetics-usage")" "mine"
out="$(shipinetics-shims status 2>&1)"; rc=$?
eq "status fails when a shim is missing" "$rc" "1"
has "and names the other file" "$out" "[other] $shims/shipinetics-usage"

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
  sym_setup "$shims"
  out="$(shipinetics-shims install 2>&1)"
  eq "safe-local-setup AC15: install skips both symlinks and writes nothing through them" "$(sym_result "$shims")" "links:2 broken-target:none outside-file:same"
  has "safe-local-setup AC15: and says it skipped a symlink" "$out" "skipped $shims/shipinetics-config: it is a symlink"
  rm -f "$shims/shipinetics-config" "$shims/shipinetics-verify"; shipinetics-shims install >/dev/null 2>&1
else
  printf '  skip  shims and symlinks (ln -s makes copies here)\n'
fi

shipinetics-shims remove >/dev/null
eq "remove removes the shims" "$([ -e "$shims/shipinetics-config" ] && echo left || echo gone)" "gone"
eq "and keeps the other file" "$(cat "$shims/shipinetics-usage")" "mine"
done_testing
