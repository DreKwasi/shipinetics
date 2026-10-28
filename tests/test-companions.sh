# Companions: the list, which ones are installed, the session-start notice and the docs that match.
# The tool and the hook run from a copy of the plugin with a small companions.tsv of our own, so
# the results never depend on the real list or on what is installed on this machine.
. "$(dirname "$0")/helpers.sh"

plug="$scratch/plug"; mkdir -p "$plug"
cp -R "$SY/bin" "$SY/scripts" "$plug/"
tab="$(printf '\t')"
row() { printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$@"; }
{
  echo '# a comment line'
  row alpha skill alpha required "Alpha does A." "install-alpha --now" "SAFE. alpha scan line"
  row Beta plugin beta@mkt required "Beta does B." "plugin-install beta" "CAUTION. beta scan line"
  echo
  row gamma cli gammacli optional "Gamma does G." "See the gamma README" "SAFE. gamma scan line"
  row delta skill delta optional "Delta does D." "touch $scratch/ran-delta" "SAFE. delta scan line"
} >"$plug/companions.tsv"

cdir="$scratch/claude"; clibin="$scratch/clibin"; proj="$scratch/proj"; other="$scratch/other"
userdir="$XDG_CONFIG_HOME/shipinetics"
export PATH="$clibin:$PATH"

# reset: nothing installed, nothing configured, the project is not set up
reset() {
  rm -rf "$cdir" "$clibin" "$proj" "$other" "$HOME/.agents" "$HOME/.claude" "$HOME/.config" "$userdir" "$scratch/ran-delta"
  mkdir -p "$cdir" "$clibin" "$proj" "$other" "$userdir"
  export CLAUDE_CONFIG_DIR="$cdir" CLAUDE_PROJECT_DIR="$proj" XDG_CONFIG_HOME="$scratch/xdg"
  unset SHIPINETICS_HOOKS_OFF
  cd "$proj" || exit 1
}
skill()  { mkdir -p "$1/$2"; echo x >"$1/$2/SKILL.md"; }
plugins_json() { mkdir -p "$cdir/plugins"; printf '{"version":2,"plugins":{%s}}\n' "$1" >"$cdir/plugins/installed_plugins.json"; }
cli()    { printf '#!/bin/sh\nexit 0\n' >"$clibin/$1"; chmod +x "$clibin/$1"; }
all_installed() {
  skill "$cdir/skills" alpha; skill "$cdir/skills" delta
  plugins_json '"beta@mkt":[{"scope":"user"}]'; cli gammacli
}
run()    { OUT="$("$plug/bin/shipinetics-companions" "$@" 2>&1)"; RC=$?; }
notice() { OUT="$(printf '{"hook_event_name":"SessionStart","source":"startup"}' | "$plug/scripts/companions-notice.sh" 2>/dev/null)"; RC=$?; }
jf()     { printf '%s' "$OUT" | python3 -c 'import json, sys
v = json.load(sys.stdin)
for k in sys.argv[1:]: v = v[k]
print(v)' "$@"; }

# ---- the list: every companion, its status, its reason and its scan result
reset; run
eq "the list exits 0 when companions are missing" "$RC" 0
has "a missing companion shows its status, kind and level" "$OUT" "[missing] alpha (skill, required)"
has "an optional one says so" "$OUT" "[missing] gamma (cli, optional)"
has "a plugin is listed too" "$OUT" "[missing] Beta (plugin, required)"
has "each entry shows why" "$OUT" "Why: Delta does D."
has "each entry shows its SkillSpector line" "$OUT" "SkillSpector: CAUTION. beta scan line"
has "a missing entry shows its install command" "$OUT" "Install: install-alpha --now"
hasnt "comment lines are not companions" "$OUT" "a comment line"
skill "$cdir/skills" alpha; run
has "an installed companion shows as installed" "$OUT" "[installed] alpha (skill, required)"
has "an installed entry still shows why" "$OUT" "Why: Alpha does A."
has "an installed entry still shows its SkillSpector line" "$OUT" "SkillSpector: SAFE. alpha scan line"
hasnt "an installed entry has no install command" "$OUT" "install-alpha"
printf 'companions_skip = Beta\n' >"$userdir/config"; run
has "a declined companion shows as declined" "$OUT" "[declined] Beta (plugin, required)"
hasnt "a declined entry has no install command" "$OUT" "plugin-install beta"

# ---- what counts as installed
reset; run; has "baseline: a skill with no folder is missing" "$OUT" "[missing] alpha"
reset; skill "$cdir/skills" alpha; run;                 has "skill in the Claude config folder" "$OUT" "[installed] alpha"
reset; skill "$HOME/.agents/skills" alpha; run;         has "skill in the skills CLI's global folder" "$OUT" "[installed] alpha"
reset; skill "$proj/.claude/skills" alpha; run;         has "skill in the project's .claude/skills" "$OUT" "[installed] alpha"
reset; skill "$proj/.claude/skills" alpha; unset CLAUDE_PROJECT_DIR; run
has "the project is the current folder without CLAUDE_PROJECT_DIR" "$OUT" "[installed] alpha"
reset; skill "$other/.claude/skills" alpha; run;        has "another project's skill doesn't count" "$OUT" "[missing] alpha"
reset; mkdir -p "$cdir/skills/alpha"; run;              has "a skill folder without SKILL.md doesn't count" "$OUT" "[missing] alpha"
reset; skill "$HOME/.claude/skills" alpha; unset CLAUDE_CONFIG_DIR; run
has "the Claude config folder defaults to ~/.claude" "$OUT" "[installed] alpha"
reset; plugins_json '"beta@mkt":[{"scope":"user"}]'; run; has "a plugin listed in installed_plugins.json" "$OUT" "[installed] Beta"
reset; plugins_json '"beta@other":[{"scope":"user"}]'; run;     has "the same plugin from another marketplace doesn't count" "$OUT" "[missing] Beta"
reset; plugins_json '"beta@mkt-extra":[{"scope":"user"}]'; run; has "a longer plugin id doesn't count" "$OUT" "[missing] Beta"
reset; cli gammacli; run; has "a cli on the PATH" "$OUT" "[installed] gamma"

# ---- missing: only what is missing, and the exit code says if a required one is
reset; run missing
eq "missing exits 1 when a required companion is missing" "$RC" 1
has "missing lists a missing required one" "$OUT" "[missing] alpha"
has "missing lists a missing optional one" "$OUT" "[missing] gamma"
reset; skill "$cdir/skills" alpha; plugins_json '"beta@mkt":[]'; run missing
eq "missing exits 0 when only optional ones are missing" "$RC" 0
has "and still lists the optional ones" "$OUT" "[missing] gamma"
hasnt "and not the installed ones" "$OUT" "alpha"
hasnt "and not the installed plugin" "$OUT" "Beta"
reset; skill "$cdir/skills" alpha; cli gammacli; run missing
eq "a missing required plugin gives exit 1 with optional ones installed" "$RC" 1
hasnt "missing leaves out an installed optional one" "$OUT" "gamma"
reset; all_installed; run missing
eq "missing exits 0 when nothing is missing" "$RC" 0
eq "and prints nothing" "$OUT" ""
reset; printf 'companions_skip = alpha beta@mkt gamma delta\n' >"$userdir/config"; run missing
eq "declined companions are not missing: exit 0" "$RC" 0
eq "declined companions are not listed by missing" "$OUT" ""

# ---- install: the commands of the missing companions, and nothing is run
reset; run install
eq "install exits 0" "$RC" 0
eq "install prints one command per missing companion, and a note for 'See ...'" "$OUT" "install-alpha --now
plugin-install beta
# gamma: See the gamma README
touch $scratch/ran-delta"
eq "install runs nothing" "$([ -e "$scratch/ran-delta" ] && echo ran || echo none)" "none"
reset; skill "$cdir/skills" alpha; printf 'companions_skip = beta\n' >"$userdir/config"; run install
eq "install leaves out installed and declined companions" "$OUT" "# gamma: See the gamma README
touch $scratch/ran-delta"
reset; all_installed; run install
eq "install prints nothing when nothing is missing" "$RC:$OUT" "0:"

# ---- companions_skip: declined companions, by name or id in any case; the project's key wins
reset; printf 'companions_skip = ALPHA beta@MKT\n' >"$userdir/config"; run
has "a name in any case is declined" "$OUT" "[declined] alpha"
has "an id in any case is declined" "$OUT" "[declined] Beta"
has "the others stay missing" "$OUT" "[missing] delta"
reset; printf 'companions_skip = BETA\n' >"$userdir/config"; run
has "the name matches without the case" "$OUT" "[declined] Beta"
reset; printf 'companions_skip = alpha, beta@mkt,gamma\n' >"$userdir/config"; run
has "commas separate names: the first" "$OUT" "[declined] alpha"
has "commas separate names: an id after a comma and a space" "$OUT" "[declined] Beta"
has "commas separate names: after a comma without a space" "$OUT" "[declined] gamma"
has "commas don't decline the others" "$OUT" "[missing] delta"
reset; unset XDG_CONFIG_HOME; mkdir -p "$HOME/.config/shipinetics"; printf 'companions_skip = alpha\n' >"$HOME/.config/shipinetics/config"; run
has "without XDG_CONFIG_HOME the user's config is ~/.config/shipinetics/config" "$OUT" "[declined] alpha"
reset; mkdir -p "$proj/.shipinetics"; printf 'companions_skip = delta\n' >"$proj/.shipinetics/config"
printf 'companions_skip = alpha\n' >"$userdir/config"; run
has "a project's companions_skip is used" "$OUT" "[declined] delta"
has "and replaces the user's" "$OUT" "[missing] alpha"
reset; mkdir -p "$proj/.shipinetics"; printf 'verify_cmd = bin/verify\n' >"$proj/.shipinetics/config"
printf 'companions_skip = alpha\n' >"$userdir/config"; run
has "the user's companions_skip applies when the project doesn't set it" "$OUT" "[declined] alpha"

# ---- a command that doesn't exist
reset; run frobnicate
eq "an unknown command exits 2" "$RC" 2
has "and says which one" "$OUT" "unknown command: frobnicate"

# ---- the session-start notice
reset; notice
eq "the notice exits 0" "$RC" 0
eq "the notice is a SessionStart hook output" "$(jf hookSpecificOutput hookEventName)" "SessionStart"
msg="$(jf systemMessage)"; ctx="$(jf hookSpecificOutput additionalContext)"
has "the message says how many are missing" "$msg" "4 Shipinetics companions are missing."
has "the message lists a missing companion with its reason" "$msg" "alpha: Alpha does A."
has "the message gives its SkillSpector result" "$msg" "SkillSpector: SAFE. alpha scan line"
has "the message gives its install command" "$msg" "Install: install-alpha --now"
has "the message marks optional companions" "$msg" "gamma (optional): Gamma does G."
has "Claude's context names the missing companions" "$ctx" "alpha, Beta, gamma, delta"
reset; skill "$cdir/skills" alpha; skill "$cdir/skills" delta; plugins_json '"beta@mkt":[]'; notice
eq "the notice is silent when only optional companions are missing" "$RC:$OUT" "0:"
reset; skill "$cdir/skills" delta; cli gammacli; plugins_json '"beta@mkt":[]'; notice
msg="$(jf systemMessage)"; ctx="$(jf hookSpecificOutput additionalContext)"
has "the notice counts one missing companion" "$msg" "1 Shipinetics companion is missing."
has "and lists it" "$msg" "alpha: Alpha does A."
hasnt "the notice leaves out installed companions" "$msg" "Delta does D."
hasnt "Claude's context leaves them out too" "$ctx" "Beta"
reset; skill "$cdir/skills" delta; plugins_json '"beta@mkt":[]'; notice
msg="$(jf systemMessage)"; ctx="$(jf hookSpecificOutput additionalContext)"
has "a missing optional companion is listed when a required one is missing, and counted" "$msg" "2 Shipinetics companions are missing."
has "with its optional tag" "$msg" "gamma (optional): Gamma does G."
has "Claude's context names both" "$ctx" "alpha, gamma"
reset; all_installed; notice
eq "the notice is silent when every companion is installed" "$RC:$OUT" "0:"
reset; printf 'companions_skip = alpha beta gamma delta\n' >"$userdir/config"; notice
eq "the notice is silent when every missing companion is declined" "$RC:$OUT" "0:"
reset; printf 'companions_skip = alpha gamma delta\n' >"$userdir/config"; notice
msg="$(jf systemMessage)"
has "a declined companion is not in the notice" "$msg" "1 Shipinetics companion is missing."
hasnt "and not by name" "$msg" "alpha"
reset; printf 'companions_skip = alpha beta\n' >"$userdir/config"; notice
eq "declining every required companion silences the notice, optional ones missing" "$RC:$OUT" "0:"
reset; mkdir -p "$proj/.shipinetics"; printf 'hooks_off = companions\n' >"$proj/.shipinetics/config"; notice
eq "hooks_off in the project switches the notice off" "$OUT" ""
reset; printf 'hooks_off = companions\n' >"$userdir/config"; notice
eq "hooks_off in the user's config switches it off" "$OUT" ""
reset; SHIPINETICS_HOOKS_OFF=companions notice
eq "SHIPINETICS_HOOKS_OFF switches it off for a session" "$OUT" ""
reset; mkdir -p "$proj/.shipinetics"; printf 'hooks_off = pr\n' >"$proj/.shipinetics/config"; printf 'hooks_off = companions\n' >"$userdir/config"; notice
has "a project's hooks_off replaces the user's" "$OUT" "systemMessage"
reset; notice; has "the notice works outside a set-up project" "$OUT" "4 Shipinetics companions are missing."
reset; mkdir -p "$proj/.shipinetics"; : >"$proj/.shipinetics/config"; notice
has "and inside one" "$OUT" "4 Shipinetics companions are missing."

# ---- the plugin's own files match each other
hj="$SY/hooks/hooks.json"
sess="$(python3 -c 'import json, sys
h = json.load(open(sys.argv[1]))["hooks"]["SessionStart"]
print(" ".join(g["matcher"] + ":" + x["command"] for g in h for x in g["hooks"]))' "$hj")"
has "hooks.json runs companions-notice.sh for SessionStart" "$sess" "companions-notice.sh"
has "and only for a new session (matcher startup)" "$sess" "startup:"
tsv="$SY/companions.tsv"
bad_rows="$(awk -F'\t' '/^#/ || NF == 0 { next }
  { ok = (NF == 7 && ($2 == "skill" || $2 == "plugin" || $2 == "cli") && ($4 == "required" || $4 == "optional"))
    for (i = 1; i <= NF; i++) if ($i == "") ok = 0
    if (!ok) print $1 }' "$tsv")"
eq "every row of companions.tsv has 7 fields, none empty, a valid kind and level" "$bad_rows" ""
section="$(awk '/^## Companions/ { on = 1; next } on && /^###? / { exit } on && /^\|/ { split($0, c, "|"); print c[2] }' "$SY/README.md")"
missing_docs=""
while IFS="$tab" read -r name _; do
  case "$name" in ''|'#'*) continue ;; esac
  case "$section" in *"$name"*) ;; *) missing_docs="$missing_docs $name" ;; esac
done <"$tsv"
eq "every companion in companions.tsv is in the README's Companions table" "$missing_docs" ""
done_testing
