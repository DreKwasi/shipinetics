#!/usr/bin/env bash
# SessionStart hook (new sessions only). Installs the shipinetics-shims short commands, so your own
# terminal can run shipinetics-config and the other shipinetics-* tools without the plugin's full path.
# It writes only into the shim folder (~/.local/bin, or $SHIPINETICS_SHIM_DIR), and only when that
# folder exists and is on the PATH. It never changes a file that shipinetics-shims didn't write.
# Quiet when the shims are already there and current. After an update, it refreshes them.
# Switch it off with "hooks_off = shims" in ~/.config/shipinetics/config, or SHIPINETICS_HOOKS_OFF=shims.
# Remove the shims with: shipinetics-shims remove

set -uo pipefail

input="$(cat)"
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
harness="$(sy_hook_harness "$input")"
noop() { sy_hook_noop "$harness"; exit 0; }
root="$(sy_root "$(sy_hook_cwd "$input")" 2>/dev/null)" || root=""
sy_hook_off shims "$root" && noop

dir="${SHIPINETICS_SHIM_DIR:-$HOME/.local/bin}"
wrote="$("$(dirname "$0")/../bin/shipinetics-shims" auto 2>/dev/null)" || noop
[ -n "$wrote" ] || noop
names="$(printf '%s\n' "$wrote" | tr '\n' ' ' | sed 's/ $//')"
msg="Shipinetics: your terminal can now run the shipinetics-* tools by name: $names. The short commands are in $dir, and they find the installed plugin each time, so updates don't break them. To switch this off, add 'hooks_off = shims' to ~/.config/shipinetics/config. To remove them, run: shipinetics-shims remove"
sy_hook_session_start_reply "$harness" "$msg" ""
