#!/usr/bin/env bash
# smoke-install.sh: installs Shipinetics from this clone into a new, empty HOME, checks it, and
# removes it again with `shipinetics uninstall --all`. Then nothing that Shipinetics wrote may be
# left in that HOME. Your own HOME is never used.
# Usage: bash scripts/smoke-install.sh   (needs bash, git and python3; Claude Code isn't needed)
set -euo pipefail
clone="$(cd "$(dirname "$0")/.." && pwd -P)"
base="$(mktemp -d "${TMPDIR:-/tmp}/shipinetics-smoke.XXXXXX")"
# Remove the scratch HOME when the test passes; keep it when it fails, to look at.
trap '[ "$?" = 0 ] && rm -rf "$base"' EXIT
export HOME="$base/home"
unset XDG_CONFIG_HOME XDG_CACHE_HOME XDG_DATA_HOME GEMINI_CONFIG_DIR CLAUDE_CONFIG_DIR SHIPINETICS_SHIM_DIR
mkdir -p "$HOME/.local/bin"
# What earlier sessions write: the caches and the usage log (uninstall --all removes them), and
# the person's own settings (uninstall --all leaves them).
mkdir -p "$HOME/.cache/shipinetics" "$HOME/Library/Caches/shipinetics" "$HOME/.local/share/shipinetics" "$HOME/.config/shipinetics"
echo stamp >"$HOME/.cache/shipinetics/companions-notice"
echo cache >"$HOME/Library/Caches/shipinetics/explainer.mp4"
printf 'ts\tsession\n' >"$HOME/.local/share/shipinetics/usage.tsv"
echo "hooks_off = usage" >"$HOME/.config/shipinetics/config"
export PATH="$HOME/.local/bin:$PATH"
ship="$clone/bin/shipinetics"
step() { printf '\n== %s\n' "$*"; }
fail() { echo "smoke-install: FAILED: $*" >&2; exit 1; }

step "install antigravity"
"$ship" install antigravity
[ -f "$HOME/.gemini/config/plugins/shipinetics/.shipinetics-copies" ] || fail "no install stamp"
[ -f "$HOME/.gemini/config/plugins/shipinetics/skills/workflow/SKILL.md" ] || fail "no generated skills"

step "link-skills antigravity"
"$ship" link-skills antigravity

step "status antigravity"
out="$("$ship" status antigravity 2>&1 || true)"
printf '%s\n' "$out"
printf '%s\n' "$out" | grep -q "Copies: current" || fail "status doesn't say the copies are current"

step "refresh antigravity"
"$ship" refresh antigravity

step "the short commands"
"$clone/bin/shipinetics-shims" install
[ -x "$HOME/.local/bin/shipinetics-config" ] || fail "no shim for shipinetics-config"

step "uninstall --all --dry-run changes nothing"
before="$(cd "$HOME" && find . | LC_ALL=C sort)"
"$ship" uninstall --all --dry-run
[ "$(cd "$HOME" && find . | LC_ALL=C sort)" = "$before" ] || fail "the dry run changed HOME"

step "uninstall --all --yes"
"$ship" uninstall --all --yes || fail "uninstall --all exited non-zero"
left="$(cd "$HOME" && find . ! -type d ! -path './.gemini/config/skills.json' ! -path './.config/shipinetics/config' | LC_ALL=C sort)"
[ -z "$left" ] || fail "files left in HOME after uninstall --all:
$left"
[ "$(cat "$HOME/.config/shipinetics/config")" = "hooks_off = usage" ] || fail "uninstall --all changed the person's own config"
for d in .cache/shipinetics Library/Caches/shipinetics .local/share/shipinetics; do
  [ ! -e "$HOME/$d" ] || fail "$d is still there"
done
[ ! -e "$HOME/.gemini/config/plugins/shipinetics" ] || fail "the Antigravity install is still there"

echo
echo "smoke-install: ok"
