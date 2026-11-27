# Companions: the list, which ones are installed, the session-start notice and the docs that match.
# The tool and the hook run from a copy of the plugin with a small companions.tsv of our own, so
# the results never depend on the real list or on what is installed on this machine.
. "$(dirname "$0")/helpers.sh"

plug="$scratch/plug"; mkdir -p "$plug"
cp -R "$SY/bin" "$SY/scripts" "$plug/"
mkdir -p "$plug/.claude-plugin"
# plugin_version <x.y.z>: the version of the plugin copy that the notice runs from
plugin_version() { printf '{\n  "name": "shipinetics",\n  "version": "%s"\n}\n' "$1" >"$plug/.claude-plugin/plugin.json"; }
plugin_version 0.9.6
tab="$(printf '\t')"
row() { printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$@"; }
{
  echo '# a comment line'
  row alpha skill alpha recommended "Alpha does A." "install-alpha --now" "SAFE. alpha scan line"
  # Beta keeps the old level word, required, which counts as recommended
  row Beta plugin beta@mkt required "Beta does B." "plugin-install beta" "CAUTION. beta scan line"
  echo
  row gamma cli gammacli optional "Gamma does G." "See the gamma README" "SAFE. gamma scan line"
  row delta skill delta optional "Delta does D." "touch $scratch/ran-delta" "SAFE. delta scan line"
} >"$plug/companions.tsv"

cdir="$scratch/claude"; clibin="$scratch/clibin"; proj="$scratch/proj"; other="$scratch/other"
userdir="$XDG_CONFIG_HOME/shipinetics"; cache="$scratch/cache"
export PATH="$clibin:$PATH"

# reset: nothing installed, nothing configured, the project is not set up
reset() {
  rm -rf "$cdir" "$clibin" "$proj" "$other" "$HOME/.agents" "$HOME/.claude" "$HOME/.config" "$HOME/.cache" "$cache" "$userdir" "$scratch/ran-delta"
  mkdir -p "$cdir" "$clibin" "$proj" "$other" "$userdir"
  export CLAUDE_CONFIG_DIR="$cdir" CLAUDE_PROJECT_DIR="$proj" XDG_CONFIG_HOME="$scratch/xdg" XDG_CACHE_HOME="$cache"
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
# notice: one new session in the current folder (the hook input names it in cwd); ERR is its stderr
notice() {
  OUT="$(printf '{"hook_event_name":"SessionStart","source":"startup","cwd":"%s"}' "$PWD" | "$plug/scripts/companions-notice.sh" 2>"$scratch/notice.err")"; RC=$?
  ERR="$(cat "$scratch/notice.err")"
}
# agy_notice: the same for an Antigravity session (its hook input, and PLUGIN_ROOT set)
agy_notice() {
  OUT="$(printf '{"hookEventName":"SessionStart","workspacePaths":["%s"]}' "$PWD" | PLUGIN_ROOT="$plug" "$plug/scripts/companions-notice.sh" 2>"$scratch/notice.err")"; RC=$?
  ERR="$(cat "$scratch/notice.err")"
}
setup_proj() { mkdir -p "$proj/.shipinetics"; : >"$proj/.shipinetics/config"; }
jf()     { printf '%s' "$OUT" | python3 -c 'import json, sys
v = json.load(sys.stdin)
for k in sys.argv[1:]: v = v[k]
print(v)' "$@"; }

# ---- the list: every companion, its status, its reason and its scan result
reset; run
eq "the list exits 0 when companions are missing" "$RC" 0
has "a missing companion shows its status, kind and level" "$OUT" "[missing] alpha (skill, recommended)"
has "an optional one says so" "$OUT" "[missing] gamma (cli, optional)"
has "teams-and-plans AC1: a row with the old level word required is listed as recommended" "$OUT" "[missing] Beta (plugin, recommended)"
has "each entry shows why" "$OUT" "Why: Delta does D."
has "each entry shows its SkillSpector line" "$OUT" "SkillSpector: CAUTION. beta scan line"
has "a missing entry shows its install command" "$OUT" "Install: install-alpha --now"
hasnt "comment lines are not companions" "$OUT" "a comment line"
skill "$cdir/skills" alpha; run
has "an installed companion shows as installed" "$OUT" "[installed] alpha (skill, recommended)"
has "an installed entry still shows why" "$OUT" "Why: Alpha does A."
has "an installed entry still shows its SkillSpector line" "$OUT" "SkillSpector: SAFE. alpha scan line"
hasnt "an installed entry has no install command" "$OUT" "install-alpha"
printf 'companions_skip = Beta\n' >"$userdir/config"; run
has "teams-and-plans AC1: a declined companion shows as declined, an old required one as recommended" "$OUT" "[declined] Beta (plugin, recommended)"
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

# ---- missing: only what is missing, and the exit code says if a recommended one is
reset; run missing
eq "missing exits 1 when recommended companions are missing" "$RC" 1
has "missing lists a missing recommended one" "$OUT" "[missing] alpha"
has "missing lists a missing optional one" "$OUT" "[missing] gamma"
reset; skill "$cdir/skills" alpha; plugins_json '"beta@mkt":[]'; run missing
eq "teams-and-plans AC1: missing exits 0 when only optional ones are missing" "$RC" 0
has "and still lists the optional ones" "$OUT" "[missing] gamma"
hasnt "and not the installed ones" "$OUT" "alpha"
hasnt "and not the installed plugin" "$OUT" "Beta"
reset; skill "$cdir/skills" alpha; cli gammacli; run missing
eq "teams-and-plans AC1: a missing companion with the old level word required counts as recommended: exit 1" "$RC" 1
hasnt "missing leaves out an installed optional one" "$OUT" "gamma"
reset; plugins_json '"beta@mkt":[]'; cli gammacli; skill "$cdir/skills" delta; run missing
eq "teams-and-plans AC1: a missing companion at level recommended gives exit 1" "$RC" 1
has "and it is listed" "$OUT" "[missing] alpha"
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
# The model gets the names and where to look, not the list itself (the person's message keeps it)
has "teams-and-plans: Claude's context names the missing companions" "$ctx" "Shipinetics companions that are missing on this machine: alpha, Beta, gamma, delta."
has "teams-and-plans: and points to shipinetics-companions missing for the details" "$ctx" "run shipinetics-companions missing"
for t in "Alpha does A." "SkillSpector:" "Install: install-alpha --now"; do
  hasnt "teams-and-plans: Claude's context leaves out the list's text ($t)" "$ctx" "$t"
done
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
has "a missing optional companion is listed when a recommended one is missing, and counted" "$msg" "2 Shipinetics companions are missing."
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
eq "declining every recommended companion silences the notice, optional ones missing" "$RC:$OUT" "0:"
reset; mkdir -p "$proj/.shipinetics"; printf 'hooks_off = companions\n' >"$proj/.shipinetics/config"; notice
eq "hooks_off in the project switches the notice off" "$OUT" ""
reset; printf 'hooks_off = companions\n' >"$userdir/config"; notice
eq "hooks_off in the user's config switches it off" "$OUT" ""
reset; SHIPINETICS_HOOKS_OFF=companions notice
eq "SHIPINETICS_HOOKS_OFF switches it off for a session" "$OUT" ""
reset; mkdir -p "$proj/.shipinetics"; printf 'hooks_off = pr\n' >"$proj/.shipinetics/config"; printf 'hooks_off = companions\n' >"$userdir/config"; notice
has "a project's hooks_off replaces the user's" "$OUT" "systemMessage"
reset; notice; has "the notice works outside a set-up project" "$OUT" "4 Shipinetics companions are missing."

# teams-and-plans AC2: in a set-up project, the list shows in every new session
reset; setup_proj; notice; first="$OUT"; notice
has "teams-and-plans AC2: a set-up project gets the list in its first session" "$first" "4 Shipinetics companions are missing."
has "teams-and-plans AC2: and again in the next one" "$OUT" "4 Shipinetics companions are missing."
reset; mkdir -p "$cache/shipinetics"; : >"$cache/shipinetics/companions-notice"; setup_proj; notice
has "teams-and-plans AC2 AC3: in a set-up project a fresh weekly stamp doesn't hide the list" "$OUT" "4 Shipinetics companions are missing."

# teams-and-plans AC3: outside a set-up project, at most once in 7 days, with a stamp in the cache folder
reset; notice; first="$OUT"; stamp="$cache/shipinetics/companions-notice"
has "teams-and-plans AC3: outside a set-up project the first session gets the list" "$first" "4 Shipinetics companions are missing."
eq "teams-and-plans AC3: and the stamp is written in XDG_CACHE_HOME" "$([ -f "$stamp" ] && echo yes || echo no)" yes
notice
eq "teams-and-plans AC3: a session right after gets no notice" "$RC:$OUT" "0:"
touch -t 202001010000 "$stamp"; notice
has "teams-and-plans AC3: with the stamp older than 7 days the list shows again" "$OUT" "4 Shipinetics companions are missing."
reset; unset XDG_CACHE_HOME; notice
eq "teams-and-plans AC3: without XDG_CACHE_HOME the stamp is in ~/.cache" "$([ -f "$HOME/.cache/shipinetics/companions-notice" ] && echo yes || echo no)" yes
reset; mkdir -p "$cache"; chmod 555 "$cache"; notice; chmod 755 "$cache"
eq "teams-and-plans AC3: with a cache folder that can't be written, the notice exits 0" "$RC" 0
has "teams-and-plans AC3: and still shows the list" "$(jf systemMessage)" "4 Shipinetics companions are missing."
eq "teams-and-plans AC3: and writes nothing to stderr" "$ERR" ""

# teams-and-plans AC4: when neither jq nor python3 runs, the notice warns, whatever the companions
# nojq: the system commands, and this bash, but no jq and no python
nojq="$scratch/nojq"; mkdir -p "$nojq"; ln -s "$BASH" "$nojq/bash"
for dir in /usr/bin /bin /usr/sbin /sbin; do
  for f in "$dir"/*; do
    case "${f##*/}" in jq|python*) continue ;; esac
    [ -e "$nojq/${f##*/}" ] || ln -s "$f" "$nojq/${f##*/}"
  done
done
for c in jq python3; do PATH="$nojq" command -v "$c" >/dev/null && bad "the scratch PATH has no $c" "found $c"; done
# stubpy: a python3 that exists but fails, like the macOS stub that only offers to install tools
stubpy="$scratch/stubpy"; mkdir -p "$stubpy"; printf '#!/bin/sh\nexit 1\n' >"$stubpy/python3"; chmod +x "$stubpy/python3"
# The reply is read from the test side, with the python of the test's own PATH (not the scratch one).
py="$(command -v python3)"
# jpath <key...>: the value at that path in OUT, or "invalid JSON: ..." (numbers index lists)
jpath() { printf '%s' "$OUT" | "$py" -c 'import json, sys
try: v = json.load(sys.stdin)
except Exception as e: print("invalid JSON: %s" % e); sys.exit()
try:
    for k in sys.argv[1:]: v = v[int(k)] if isinstance(v, list) else v[k]
except Exception as e: print("missing key: %r" % e); sys.exit()
print(v)' "$@"; }
noparser_warn="Neither jq nor python3 runs on this machine"
# no_parser_case <label> <path prefix> <where: proj|setup> <companions: none|all> <harness: claude|agy>
no_parser_case() {
  local label="teams-and-plans AC4: $1" pre="$2"
  reset; [ "$3" = setup ] && setup_proj; [ "$4" = all ] && all_installed
  if [ "$5" = agy ]; then
    PATH="$pre$nojq:$clibin" agy_notice
    eq "$label: exit 0" "$RC" 0
    has "$label: the person's message warns" "$(jpath injectSteps 0 systemMessage metadata user_markdown)" "$noparser_warn"
    has "$label: the model's context warns" "$(jpath injectSteps 0 systemMessage systemMessage)" "$noparser_warn"
  else
    PATH="$pre$nojq:$clibin" notice
    eq "$label: exit 0" "$RC" 0
    has "$label: systemMessage warns" "$(jpath systemMessage)" "$noparser_warn"
    has "$label: additionalContext warns" "$(jpath hookSpecificOutput additionalContext)" "$noparser_warn"
  fi
}
no_parser_case "no jq or python3, outside a set-up project, nothing missing (Claude)" "" proj all claude
no_parser_case "no jq or python3, in a set-up project, nothing missing (Claude)" "" setup all claude
no_parser_case "no jq or python3, in a set-up project, companions missing (Claude)" "" setup none claude
has "teams-and-plans AC4: and the message still lists the missing companions" "$(jpath systemMessage)" "alpha: Alpha does A."
no_parser_case "no jq or python3, outside a set-up project (Antigravity)" "" proj all agy
no_parser_case "no jq or python3, in a set-up project (Antigravity)" "" setup none agy
no_parser_case "a python3 that fails and no jq, outside a set-up project (Claude)" "$stubpy:" proj all claude
no_parser_case "a python3 that fails and no jq, in a set-up project (Claude)" "$stubpy:" setup none claude
no_parser_case "a python3 that fails and no jq, in a set-up project (Antigravity)" "$stubpy:" setup none agy
reset; notice; PATH="$nojq:$clibin" notice
has "teams-and-plans AC4: no jq or python3, weekly stamp fresh: the notice still warns" "$(jpath systemMessage)" "$noparser_warn"
reset; all_installed; notice
eq "teams-and-plans AC4: with a parser and nothing missing there is no warning" "$RC:$OUT" "0:"

# teams-and-plans AC4: the reply written in plain bash (sy_json_str) is valid JSON that keeps the
# text, and drops the control characters that JSON doesn't allow raw (here ESC and BEL)
# json_str_decoded <text>: the text through sy_json_str, decoded by python, as a Python repr
json_str_decoded() {
  (. "$SY/scripts/lib.sh"; sy_json_str "$1") | "$py" -c 'import json, sys
try: print(repr(json.loads(sys.stdin.read())))
except Exception as e: print("invalid JSON: %s" % e)'
}
eq "teams-and-plans AC4: sy_json_str keeps backslash, quote, tab, newline and CR, and drops ESC and BEL" \
  "$(json_str_decoded "$(printf 'a\\b"c\td\ne\rf\033g\007h')")" "'a\\\\b\"c\\td\\ne\\rfgh'"
eq "teams-and-plans AC4: sy_json_str keeps a newline at the end of the text" \
  "$(json_str_decoded $'one\ntwo\n')" "'one\\ntwo\\n'"

# teams-and-plans AC5: a set-up project that names a newer Shipinetics than this machine has
# agents_version <x.y.z>: the version in the project's AGENTS.md block, as setup writes it
agents_version() { printf '# Project\n\n<!-- shipinetics:begin version=%s. /shipinetics:setup update replaces the text between this line and the shipinetics:end line. -->\nrules\n<!-- shipinetics:end -->\n' "$1" >"$proj/AGENTS.md"; }
newer="was set up with Shipinetics"
for c in "0.9.6 0.10.0 warn" "0.9.6 0.9.6 none" "0.10.0 0.9.6 none"; do
  set -- $c
  reset; setup_proj; all_installed; plugin_version "$1"; agents_version "$2"; notice
  if [ "$3" = warn ]; then
    has "teams-and-plans AC5: plugin $1, project $2: the notice warns" "$OUT" "was set up with Shipinetics $2, but this machine has $1"
  else
    hasnt "teams-and-plans AC5: plugin $1, project $2: no version warning" "$OUT" "$newer"
  fi
done
for v in 0.11.0.1 0.11.0-rc1; do
  reset; setup_proj; all_installed; plugin_version 0.11.0; agents_version "$v"; notice
  eq "teams-and-plans AC5: plugin 0.11.0, project $v: no version warning" "$RC:$OUT" "0:"
  eq "teams-and-plans AC5: plugin 0.11.0, project $v: nothing on stderr" "$ERR" ""
done
plugin_version 0.9.6

# ---- the plugin's own files match each other
hj="$SY/hooks/hooks.json"
sess="$(python3 -c 'import json, sys
h = json.load(open(sys.argv[1]))["hooks"]["SessionStart"]
print(" ".join(g["matcher"] + ":" + x["command"] for g in h for x in g["hooks"]))' "$hj")"
has "hooks.json runs companions-notice.sh for SessionStart" "$sess" "companions-notice.sh"
has "and only for a new session (matcher startup)" "$sess" "startup:"
tsv="$SY/companions.tsv"
bad_rows="$(awk -F'\t' '/^#/ || NF == 0 { next }
  { ok = (NF == 7 && ($2 == "skill" || $2 == "plugin" || $2 == "cli") && ($4 == "recommended" || $4 == "optional"))
    for (i = 1; i <= NF; i++) if ($i == "") ok = 0
    if (!ok) print $1 }' "$tsv")"
eq "teams-and-plans AC1: every row of companions.tsv has 7 fields, none empty, a valid kind and a level recommended or optional" "$bad_rows" ""
section="$(awk '/^## Companions/ { on = 1; next } on && /^###? / { exit } on && /^\|/ { split($0, c, "|"); print c[2] }' "$SY/README.md")"
missing_docs=""
while IFS="$tab" read -r name _; do
  case "$name" in ''|'#'*) continue ;; esac
  case "$section" in *"$name"*) ;; *) missing_docs="$missing_docs $name" ;; esac
done <"$tsv"
eq "every companion in companions.tsv is in the README's Companions table" "$missing_docs" ""
done_testing
