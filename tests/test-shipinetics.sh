# shipinetics: one installer for every harness (docs/specs/multi-harness-installer.md).
# Each test runs a scratch copy of the plugin, so the copies can go out of date without this repo changing.
. "$(dirname "$0")/helpers.sh"

# A scratch clone: the plugin's files, without .git and local state
clone_src="$scratch/clone"; mkdir -p "$clone_src"
for item in agents bin skills scripts hooks companions.tsv harnesses.tsv hooks.json plugin.json .claude-plugin \
  README.md GETTING-STARTED.md CHANGELOG.md; do
  [ -e "$SY/$item" ] && cp -R "$SY/$item" "$clone_src/"
done
clone="$(cd "$clone_src" && pwd -P)"
SHIP="$clone/bin/shipinetics"
: >"$clone/companions.tsv"   # no companions, so the session notice reports only the copies
printf '\377\376\000not text' >"$clone/skills/evidence/sample.bin"   # a skill file that isn't UTF-8 text

export GEMINI_CONFIG_DIR="$scratch/gemini" CLAUDE_CONFIG_DIR="$scratch/claude-config"
mkdir -p "$GEMINI_CONFIG_DIR" "$CLAUDE_CONFIG_DIR"
target="$GEMINI_CONFIG_DIR/plugins/shipinetics"   # the default Antigravity install folder

# A stub claude command that records each call, so no test runs the real one
stub="$scratch/stub"; mkdir -p "$stub"; calls="$scratch/claude-calls"
printf '#!/bin/sh\necho "$*" >>"%s"\nexit 0\n' "$calls" >"$stub/claude"; chmod +x "$stub/claude"
export PATH="$stub:$PATH"

# snapshot <dir> <excluded dir>: one line per path under dir (type, contents or link target), sorted
snapshot() {
  python3 -I - "$1" "$2" <<'PY'
import hashlib, os, sys
root, skip = sys.argv[1], os.path.realpath(sys.argv[2])
out = []
for d, dirs, files in os.walk(root):
    if os.path.realpath(d) == skip:
        dirs[:] = []; continue
    dirs[:] = [x for x in dirs if os.path.realpath(os.path.join(d, x)) != skip or os.path.islink(os.path.join(d, x))]
    for n in sorted(dirs + files):
        p = os.path.join(d, n); rel = os.path.relpath(p, root)
        if os.path.realpath(p) == skip and not os.path.islink(p):
            continue
        if os.path.islink(p):
            out.append("L %s -> %s" % (rel, os.readlink(p)))
        elif os.path.isdir(p):
            out.append("D %s" % rel)
        else:
            out.append("F %s %s %o" % (rel, hashlib.sha256(open(p, "rb").read()).hexdigest(), os.stat(p).st_mode))
print("\n".join(sorted(set(out))))
PY
}

# notice: the session-start notice from the install folder, with Antigravity's input; sets MSG (the user's text)
proj="$scratch/proj"; new_repo "$proj"
notice() {
  local out
  out="$(cd "$target" && printf '{"hookEventName":"SessionStart","workspacePaths":["%s"]}' "$proj" |
    PLUGIN_ROOT="$target" bash "$target/scripts/companions-notice.sh" 2>/dev/null)"
  OUT="$out"
  MSG="$(printf '%s' "$out" | python3 -c 'import json,sys
try: print(json.load(sys.stdin)["injectSteps"][0]["systemMessage"]["metadata"]["user_markdown"])
except Exception: pass' 2>/dev/null)"
}

# ---- AC1: install writes copies with real paths that exist in the clone
out="$("$SHIP" install antigravity 2>&1)"; rc=$?
eq "multi-harness-installer AC1: install antigravity exits 0" "$rc" 0
ac1="$(python3 -I - "$clone" "$target" <<'PY'
import os, re, sys
clone, target = sys.argv[1], sys.argv[2]
src, dst = os.path.join(clone, "skills"), os.path.join(target, "skills")
problems, refs, kinds = [], 0, set()
if os.path.islink(dst) or not os.path.isdir(dst):
    problems.append("skills is not a folder of copies")
ref = re.compile(r"\$\{CLAUDE_(PLUGIN_ROOT|SKILL_DIR)\}([^\s\x60\x22\x27()<>\]]*)")  # stops at a backtick or a quote
for d, _, files in os.walk(src):
    if "__pycache__" in d:
        continue
    for n in files:
        if n == ".DS_Store":
            continue
        sp = os.path.join(d, n); rel = os.path.relpath(sp, src)
        dp = os.path.join(dst, rel)
        if not os.path.isfile(dp):
            problems.append("no copy of " + rel); continue
        try:
            text, copy = open(sp, encoding="utf-8").read(), open(dp, encoding="utf-8").read()
        except UnicodeDecodeError:
            if open(sp, "rb").read() != open(dp, "rb").read():
                problems.append("the copy of %s differs" % rel)
            continue
        if "${CLAUDE_PLUGIN_ROOT}" in copy or "${CLAUDE_SKILL_DIR}" in copy:
            problems.append("a variable remains in " + rel)
        skill = os.path.join(src, rel.split(os.sep)[0])
        for m in ref.finditer(text):
            tail = m.group(2).rstrip(".,:;")
            base = clone if m.group(1) == "PLUGIN_ROOT" else skill
            want = base + tail
            refs += 1; kinds.add(m.group(1))
            if want not in copy:
                problems.append("%s: %s not replaced by %s" % (rel, m.group(0), want))
            elif not os.path.exists(want):
                problems.append("%s: %s does not exist" % (rel, want))
if refs == 0 or len(kinds) < 2:
    problems.append("the skills in the clone hold too few references to check (%d)" % refs)
print("\n".join(problems) or "ok")
PY
)"
eq "multi-harness-installer AC1: every skill file is a copy, no variable remains, and each replaced path exists in the clone" "$ac1" "ok"

# ---- AC2: status says whether the copies are older than the clone
mkdir -p "$GEMINI_CONFIG_DIR"; printf '{"entries":[{"path":"~/.agents/skills"}]}\n' >"$GEMINI_CONFIG_DIR/skills.json"
st() { OUT="$(PATH="$clone/bin:$PATH" "$SHIP" status antigravity 2>&1)"; RC=$?; }
st
has "multi-harness-installer AC2: right after an install, status says the copies are current" "$OUT" "Copies: current"
eq "multi-harness-installer AC2: (setup) status passes when nothing else is wrong" "$RC" 0

skill_md="$clone/skills/workflow/SKILL.md"
for change in skill agent; do
  case "$change" in
    skill) cp "$skill_md" "$scratch/keep"; echo "A new line in the clone." >>"$skill_md" ;;
    agent) cp "$clone/agents/reviewer.md" "$scratch/keep"; echo "A new agent line." >>"$clone/agents/reviewer.md" ;;
  esac
  st
  eq "multi-harness-installer AC2: a changed $change file makes status exit 1" "$RC" 1
  has "multi-harness-installer AC2: a changed $change file: status says the copies are older and names the refresh" "$OUT" "older than the clone. Run: shipinetics refresh antigravity"
  case "$change" in
    skill) cp "$scratch/keep" "$skill_md" ;;
    agent) cp "$scratch/keep" "$clone/agents/reviewer.md" ;;
  esac
done

# ---- AC4 (with AC2's stale clone): the session notice reports out-of-date copies, and only then
notice
eq "multi-harness-installer AC4: current copies add nothing to the session notice" "$OUT" ""
echo "A new line in the clone." >>"$skill_md"
notice
has "multi-harness-installer AC4: older copies: the notice says so" "$MSG" "older than your clone"
has "multi-harness-installer AC4: older copies: the notice names the refresh command" "$MSG" "shipinetics refresh antigravity"
printf 'alpha\tskill\talpha\trequired\tAlpha.\tinstall-alpha\tSAFE\n' >"$clone/companions.tsv"
# where ln -s makes copies (Windows), the install holds its own copy of the table
[ -L "$target/companions.tsv" ] || cp "$clone/companions.tsv" "$target/companions.tsv"
notice
has "multi-harness-installer AC4: with a missing companion too, the notice still names the refresh command" "$MSG" "shipinetics refresh antigravity"
has "multi-harness-installer AC4: and still lists the companion" "$MSG" "1 Shipinetics companion is missing."
: >"$clone/companions.tsv"
[ -L "$target/companions.tsv" ] || cp "$clone/companions.tsv" "$target/companions.tsv"
# D8: the notice's hooks_off name is notice, and companions keeps working
for name in notice companions; do
  mkdir -p "$proj/.shipinetics"; printf 'hooks_off = %s\n' "$name" >"$proj/.shipinetics/config"
  notice
  eq "multi-harness-installer D8: hooks_off = $name switches the notice off" "$OUT" ""
done
rm -rf "$proj/.shipinetics"

# ---- AC3: refresh makes the copies match the clone, and changes nothing outside the install folder
echo "Written after the install." >"$clone/skills/workflow/added.md"
rm "$clone/skills/review/personas/performance.md"
echo "An agent line after the install." >>"$clone/agents/reviewer.md"
rm "$clone/agents/ui-reviewer.md"
before="$(snapshot "$scratch" "$target")"
out="$("$SHIP" refresh antigravity 2>&1)"; rc=$?
after="$(snapshot "$scratch" "$target")"
eq "multi-harness-installer AC3: refresh exits 0" "$rc" 0
ac3="$(python3 -I - "$clone" "$target" <<'PY'
import os, sys
clone, target = sys.argv[1], sys.argv[2]
src, dst = os.path.join(clone, "skills"), os.path.join(target, "skills")
def files(root):
    return {os.path.relpath(os.path.join(d, n), root) for d, _, fs in os.walk(root) for n in fs
            if n != ".DS_Store" and "__pycache__" not in d}
a, b = files(src), files(dst)
problems = ["missing copy: " + p for p in sorted(a - b)] + ["copy of a removed file: " + p for p in sorted(b - a)]
for rel in sorted(a & b):
    s = open(os.path.join(src, rel), "rb").read()
    if b"\x24{CLAUDE_" not in s and s != open(os.path.join(dst, rel), "rb").read():
        problems.append("copy differs: " + rel)
if "An agent line after the install." not in open(os.path.join(target, "agents", "reviewer.md")).read():
    problems.append("agents/reviewer.md not refreshed")
if os.path.exists(os.path.join(target, "agents", "ui-reviewer.md")):
    problems.append("agents/ui-reviewer.md, removed from the clone, is still installed")
print("\n".join(problems) or "ok")
PY
)"
eq "multi-harness-installer AC3: after refresh, the copies match the clone (changed, added and removed files, a changed and a removed agent)" "$ac3" "ok"
eq "multi-harness-installer AC3: refresh changes nothing outside the install folder" "$after" "$before"
st
has "multi-harness-installer AC2: right after a refresh, status says the copies are current" "$OUT" "Copies: current"
notice
eq "multi-harness-installer AC4: after a refresh, the notice adds nothing" "$OUT" ""

# links_work: true if ln -s makes a real link here. Git Bash on Windows makes a copy instead, unless
# Developer Mode allows links.
links_work() {
  local probe="$scratch/link-probe"
  rm -rf "$probe" "$probe.src"; : >"$probe.src"
  ln -s "$probe.src" "$probe" 2>/dev/null && [ -L "$probe" ]; local rc=$?
  rm -rf "$probe" "$probe.src"; return "$rc"
}

# AC3: an item that is a plain (and old) copy instead of a link to the clone, as ln -s leaves it on
# Windows, matches the clone again after a refresh: a link on macOS and Linux, a fresh copy on Windows
for item in hooks.json scripts; do
  rm -rf "${target:?}/$item"; cp -R "$clone/$item" "$target/$item"
  if [ -d "$target/$item" ]; then echo "an old file" >"$target/$item/old-copy.txt"; else echo "an old line" >>"$target/$item"; fi
  out="$("$SHIP" refresh antigravity 2>&1)"; rc=$?
  eq "multi-harness-installer AC3: refresh over a copied $item exits 0" "$rc" 0
  if links_work; then
    eq "multi-harness-installer AC3: refresh makes a copied $item a link to the clone again" "$(readlink "$target/$item" 2>/dev/null)" "$clone/$item"
  else
    eq "multi-harness-installer AC3, AC13: refresh copies $item from the clone again" "$(diff -r "$clone/$item" "$target/$item" >/dev/null 2>&1 && echo same || echo differs)" same
  fi
done

# AC13: with hooks.json a copy (as where ln -s makes copies) and the stamp, status says Shipinetics
# is installed as copies of the clone, and passes
rm -f "$target/hooks.json"; cp "$clone/hooks.json" "$target/hooks.json"
st
has "multi-harness-installer AC13: status with copied files says it is installed as copies of the clone" "$OUT" "Plugin: installed as copies of $clone"
eq "multi-harness-installer AC13: status with copied files and current copies exits 0" "$RC" 0
# AC13: a stamped install that lacks hooks.json, scripts or bin is incomplete: status says so,
# names the refresh, and exits 1
for item in hooks.json scripts bin; do
  "$SHIP" refresh antigravity >/dev/null 2>&1
  rm -rf "${target:?}/$item"
  st
  has "multi-harness-installer AC13: with $item missing, status says the install is incomplete and names the refresh" "$OUT" "Plugin: incomplete at $target (hooks.json, scripts or bin is missing). Run: shipinetics refresh antigravity"
  eq "multi-harness-installer AC13: with $item missing, status exits 1" "$RC" 1
done
"$SHIP" refresh antigravity >/dev/null 2>&1

# ---- AC5: status with no harness shows each harness and its guards, as harnesses.tsv says
# ac5 <status output>: "ok", or each way the status table differs from harnesses.tsv. Labels are not
# listed here: each check must have one label of its own (not its raw id), the same in every harness.
ac5() {
  python3 -I - "$clone/harnesses.tsv" "$1" <<'PY'
import sys
tsv, status = sys.argv[1], sys.argv[2]
words = {"enforced": "enforced", "works": "works", "partial": "partial", "instruction": "instruction only",
         "not-yet": "not yet (planned: "}
sections, cur = {}, None
for line in status.splitlines():
    if line.startswith("== "):
        cur = line[3:].strip(); sections[cur] = []
    elif cur and line.startswith("  ") and line.strip():
        sections[cur].append(line)          # the table: the only indented lines in a section
rows = {}
for row in open(tsv):
    if not row.strip() or row.startswith("#"):
        continue
    f = (row.rstrip("\n").split("\t") + ["", "", "", "", ""])[:5]
    rows.setdefault(f[0], []).append(f[1:])
problems, label_of = [], {}
for h in ("claude", "antigravity", "codex", "opencode", "copilot"):
    if h not in rows:
        problems.append("harnesses.tsv has no row for " + h); continue
    lines = sections.get(h)
    if lines is None:
        problems.append("status has no section for " + h); continue
    if len(lines) != len(rows[h]):
        problems.append("%s: %d table lines for %d rows" % (h, len(lines), len(rows[h])))
    for (check, today, planned, note), line in zip(rows[h], lines):
        want = words[today] + (planned + ")" if today == "not-yet" else "")
        i = line.find(" " + want, 2)
        if i < 0:
            problems.append("%s %s: expected %r in %r" % (h, check, want, line)); continue
        label = line[2:i].strip()
        rest = line[i + 1 + len(want):]
        if note.strip() and note.strip() not in rest:
            problems.append("%s %s: note %r missing in %r" % (h, check, note, line))
        if not label or label == check:
            problems.append("%s %s: no label (got %r)" % (h, check, label))
        label_of.setdefault(check, set()).add(label)
for check, labels in sorted(label_of.items()):
    if len(labels) > 1:
        problems.append("%s has different labels: %s" % (check, sorted(labels)))
flat = [l for ls in label_of.values() for l in ls]
if len(flat) != len(set(flat)):
    problems.append("two checks share a label: %s" % sorted(flat))
print("\n".join(problems) or "ok")
PY
}
out="$(PATH="$clone/bin:$PATH" "$SHIP" status 2>&1)"
eq "multi-harness-installer AC5: status shows each harness's guards and gates as harnesses.tsv says" "$(ac5 "$out")" "ok"
section() { printf '%s\n' "$1" | awk -v h="== $2" '$0 == h {on=1; next} /^== / {on=0} on'; }
has "multi-harness-installer AC5: status says Shipinetics is installed in Antigravity" "$(section "$out" antigravity)" "Plugin: installed"
has "multi-harness-installer AC5: status says it isn't installed in Claude Code" "$(section "$out" claude)" "not installed"
for h in codex opencode copilot; do
  has "multi-harness-installer AC5: status says $h isn't supported yet" "$(section "$out" "$h")" "Not supported yet"
done

# ---- AC6: codex, opencode and copilot aren't supported yet
for h in codex opencode copilot; do
  out="$("$SHIP" install "$h" 2>&1)"; rc=$?
  eq "multi-harness-installer AC6: install $h exits 2" "$rc" 2
  has "multi-harness-installer AC6: install $h says it isn't supported yet" "$out" "isn't supported yet"
  has "multi-harness-installer AC6: install $h points to shipinetics status" "$out" "shipinetics status"
done

# ---- AC7: install claude runs (or with --dry-run prints) the two claude plugin commands
rm -f "$calls"
out="$("$SHIP" install claude --dry-run 2>&1)"; rc=$?
eq "multi-harness-installer AC7: --dry-run exits 0" "$rc" 0
has "multi-harness-installer AC7: --dry-run prints the marketplace add for this clone" "$out" "claude plugin marketplace add $clone"
has "multi-harness-installer AC7: --dry-run prints the plugin install" "$out" "claude plugin install shipinetics@shipinetics"
eq "multi-harness-installer AC7: --dry-run runs no claude command" "$(cat "$calls" 2>/dev/null)" ""
out="$("$SHIP" install claude 2>&1)"; rc=$?
eq "multi-harness-installer AC7: install claude exits 0" "$rc" 0
eq "multi-harness-installer AC7: install claude runs the two commands, in order" "$(cat "$calls" 2>/dev/null)" "plugin marketplace add $clone
plugin install shipinetics@shipinetics"

# D6: a marketplace that already points at this clone, with the plugin installed: only a report
mkdir -p "$CLAUDE_CONFIG_DIR/plugins"
python3 -c 'import json,sys; json.dump({"shipinetics":{"source":{"source":"directory","path":sys.argv[1]}}}, open(sys.argv[2],"w"))' \
  "$clone" "$CLAUDE_CONFIG_DIR/plugins/known_marketplaces.json"
printf '{"version":2,"plugins":{"shipinetics@shipinetics":[{"scope":"user"}]}}\n' >"$CLAUDE_CONFIG_DIR/plugins/installed_plugins.json"
rm -f "$calls"
out="$("$SHIP" install claude 2>&1)"; rc=$?
eq "multi-harness-installer D6: already installed from this clone: exits 0" "$rc" 0
has "multi-harness-installer D6: already installed from this clone: says so" "$out" "already installed in Claude Code from this clone"
eq "multi-harness-installer D6: already installed from this clone: runs no claude command" "$(cat "$calls" 2>/dev/null)" ""

# ---- AC9: install and refresh refuse a folder that isn't a Shipinetics install, for every harness
unrelated="$scratch/unrelated"; mkdir -p "$unrelated"; echo keep >"$unrelated/notes.txt"
u_before="$(snapshot "$unrelated" /nonexistent)"
out="$("$SHIP" refresh antigravity --target "$unrelated" 2>&1)"; rc=$?
eq "multi-harness-installer AC9: refresh refuses an unrelated folder (exit 2)" "$rc" 2
eq "multi-harness-installer AC9: refresh leaves the unrelated folder as it was" "$(snapshot "$unrelated" /nonexistent)" "$u_before"
other="$scratch/other-plugin"
for c in install refresh; do
  rm -rf "$other"; mkdir -p "$other"; printf '{"name":"other-plugin"}\n' >"$other/plugin.json"; echo keep >"$other/notes.txt"
  o_before="$(snapshot "$other" /nonexistent)"
  out="$("$SHIP" "$c" antigravity --target "$other" 2>&1)"; rc=$?
  eq "multi-harness-installer AC9: $c refuses another plugin's folder (exit 2)" "$rc" 2
  eq "multi-harness-installer AC9: $c leaves another plugin's folder as it was" "$(snapshot "$other" /nonexistent)" "$o_before"
done
python3 -c 'import json,sys; json.dump({"shipinetics":{"source":{"source":"github","repo":"x/y"}}}, open(sys.argv[1],"w"))' \
  "$CLAUDE_CONFIG_DIR/plugins/known_marketplaces.json"
rm -f "$calls"
out="$("$SHIP" install claude 2>&1)"; rc=$?
eq "multi-harness-installer AC9 (D6): install claude refuses a shipinetics marketplace from another source (exit 2)" "$rc" 2
has "multi-harness-installer AC9 (D6): and names the other source" "$out" "another source (github x/y)"
eq "multi-harness-installer AC9 (D6): and runs no claude command" "$(cat "$calls" 2>/dev/null)" ""

# ---- AC10: uninstall removes the install folder and nothing else
mkdir -p "$GEMINI_CONFIG_DIR/plugins/neighbour"; echo keep >"$GEMINI_CONFIG_DIR/plugins/neighbour/plugin.json"
before="$(snapshot "$scratch" "$target")"
out="$("$SHIP" uninstall antigravity 2>&1)"; rc=$?
eq "multi-harness-installer AC10: uninstall exits 0" "$rc" 0
eq "multi-harness-installer AC10: the install folder is gone" "$([ -e "$target" ] || [ -L "$target" ] && echo there || echo gone)" gone
eq "multi-harness-installer AC10: nothing outside the install folder changes" "$(snapshot "$scratch" "$target")" "$before"

# ---- AC11: uninstall refuses a folder that isn't a Shipinetics install
for kind in unrelated other-plugin; do
  f="$scratch/keep-$kind"; rm -rf "$f"; mkdir -p "$f"; echo keep >"$f/notes.txt"
  [ "$kind" = other-plugin ] && printf '{"name":"other-plugin"}\n' >"$f/plugin.json"
  f_before="$(snapshot "$f" /nonexistent)"
  out="$("$SHIP" uninstall antigravity --target "$f" 2>&1)"; rc=$?
  eq "multi-harness-installer AC11: uninstall refuses an $kind folder (exit 2)" "$rc" 2
  eq "multi-harness-installer AC11: uninstall leaves the $kind folder as it was" "$(snapshot "$f" /nonexistent)" "$f_before"
done

# AC11: no command changes the clone itself or a git repo. These run last: a regression here
# removes the scratch clone.
gitdir="$scratch/a-repo"; new_repo "$gitdir"; echo keep >"$gitdir/notes.txt"
printf 'harness=antigravity\nclone=%s\nhash=x\n' "$clone" >"$gitdir/.shipinetics-copies"   # refused even with a stamp
for kind in clone git-repo; do
  case "$kind" in clone) f="$clone" ;; git-repo) f="$gitdir" ;; esac
  for c in uninstall install refresh; do
    f_before="$(snapshot "$f" /nonexistent)"
    out="$("$SHIP" "$c" antigravity --target "$f" 2>&1)"; rc=$?
    eq "multi-harness-installer AC11: $c refuses the $kind (exit 2)" "$rc" 2
    eq "multi-harness-installer AC11: $c leaves the $kind as it was" "$(snapshot "$f" /nonexistent)" "$f_before"
  done
done

# AC11: refresh won't write through a symlink to a clone; install replaces only the link.
# These need real links: Git Bash's ln -s on Windows would copy the whole clone.
if links_work; then
  link="$scratch/link-install"; ln -s "$clone" "$link"
  c_before="$(snapshot "$clone" /nonexistent)"
  out="$("$SHIP" refresh antigravity --target "$link" 2>&1)"; rc=$?
  eq "multi-harness-installer AC11: refresh refuses an install path that is a symlink (exit 2)" "$rc" 2
  eq "multi-harness-installer AC11: and the clone the link points to is unchanged" "$(snapshot "$clone" /nonexistent)" "$c_before"
  out="$("$SHIP" install antigravity --target "$link" 2>&1)"; rc=$?
  eq "multi-harness-installer AC11: install over a symlink exits 0" "$rc" 0
  eq "multi-harness-installer AC11: install replaces the link with an install folder" "$([ -d "$link" ] && [ ! -L "$link" ] && [ -f "$link/.shipinetics-copies" ] && echo folder)" folder
  eq "multi-harness-installer AC11: install over a symlink leaves the clone as it was" "$(snapshot "$clone" /nonexistent)" "$c_before"
else
  printf '  skip  refresh and install over a symlink to the clone (ln -s makes copies here)\n'
fi

# AC9: a regular plugin.json that names shipinetics (a fork or a copy) is not an install
fork="$scratch/fork-copy"
for c in install refresh; do
  rm -rf "$fork"; mkdir -p "$fork"; cp "$clone/plugin.json" "$fork/plugin.json"; echo keep >"$fork/notes.txt"
  f_before="$(snapshot "$fork" /nonexistent)"
  out="$("$SHIP" "$c" antigravity --target "$fork" 2>&1)"; rc=$?
  eq "multi-harness-installer AC9: $c refuses a folder with its own shipinetics plugin.json (exit 2)" "$rc" 2
  eq "multi-harness-installer AC9: $c leaves that folder as it was" "$(snapshot "$fork" /nonexistent)" "$f_before"
done
# ... but an install from before 0.10 (plugin.json is a link to a clone's manifest) still is one
# (needs real links: on Windows without them, the old installer's copies had a .source file instead)
if links_work; then
  old="$scratch/old-install"; mkdir -p "$old"
  ln -s "$clone/plugin.json" "$old/plugin.json"; ln -s "$clone/hooks.json" "$old/hooks.json"; ln -s "$clone/skills" "$old/skills"
  c_before="$(snapshot "$clone" /nonexistent)"
  out="$("$SHIP" install antigravity --target "$old" 2>&1)"; rc=$?
  eq "multi-harness-installer AC9: install replaces an install from before 0.10 (exit 0)" "$rc" 0
  eq "multi-harness-installer AC9: which then holds generated copies" "$([ -d "$old/skills" ] && [ ! -L "$old/skills" ] && echo copies)" copies
  eq "multi-harness-installer AC9: and the clone it linked to is unchanged" "$(snapshot "$clone" /nonexistent)" "$c_before"
else
  printf '  skip  install over an install from before 0.10 (ln -s makes copies here)\n'
fi
# ... and so is one that 0.11's shipinetics-antigravity made on Windows, where ln -s copied: copies of
# plugin.json and hooks.json, no stamp, and a .source file whose first line is the clone
win_old="$scratch/old-windows-install"
for src in clone not-a-clone; do
  rm -rf "$win_old"; mkdir -p "$win_old"
  cp "$clone/plugin.json" "$clone/hooks.json" "$win_old/"
  case "$src" in
    clone) printf '%s\n' "$clone" >"$win_old/.source" ;;
    not-a-clone) mkdir -p "$scratch/other-src"; printf '{"name":"other-plugin"}\n' >"$scratch/other-src/plugin.json"
                 printf '%s\n' "$scratch/other-src" >"$win_old/.source" ;;
  esac
  w_before="$(snapshot "$win_old" /nonexistent)"
  out="$("$SHIP" install antigravity --target "$win_old" 2>&1)"; rc=$?
  if [ "$src" = clone ]; then
    eq "multi-harness-installer AC9: install replaces a Windows install from 0.11 (.source names the clone, exit 0)" "$rc" 0
    eq "multi-harness-installer AC9: which then holds generated copies and a stamp" "$([ -d "$win_old/skills" ] && [ ! -L "$win_old/skills" ] && [ -f "$win_old/.shipinetics-copies" ] && echo copies)" copies
  else
    eq "multi-harness-installer AC9: install refuses a folder whose .source names a folder that isn't a Shipinetics clone (exit 2)" "$rc" 2
    eq "multi-harness-installer AC9: and leaves that folder as it was" "$(snapshot "$win_old" /nonexistent)" "$w_before"
  fi
done

# D5: refresh never rewrites an install that another clone made
"$SHIP" install antigravity >/dev/null 2>&1
replace "$target/.shipinetics-copies" "clone=$clone" "clone=/elsewhere/shipinetics"
t_before="$(snapshot "$target" /nonexistent)"
out="$("$SHIP" refresh antigravity 2>&1)"; rc=$?
eq "multi-harness-installer D5: refresh refuses an install from another clone (exit 2)" "$rc" 2
has "multi-harness-installer D5: and names that clone" "$out" "/elsewhere/shipinetics"
out="$("$SHIP" refresh 2>&1)"; rc=$?
eq "multi-harness-installer D5: plain refresh exits 0 with an install from another clone" "$rc" 0
has "multi-harness-installer D5: and says it skipped it, naming that clone" "$out" "Skipped Antigravity: its install was made from another clone (/elsewhere/shipinetics)"
eq "multi-harness-installer D5: the install from another clone is unchanged" "$(snapshot "$target" /nonexistent)" "$t_before"

# ---- AC12: --dry-run says what it would do, and nothing on disk changes
dry() {   # dry <label> <args...>: run with --dry-run; checks exit 0, a "Would" line and an unchanged disk
  local label="$1" before after; shift
  before="$(snapshot "$scratch" /nonexistent)"
  out="$("$SHIP" "$@" --dry-run 2>&1)"; rc=$?
  after="$(snapshot "$scratch" /nonexistent)"
  eq "multi-harness-installer AC12: $label --dry-run exits 0" "$rc" 0
  has "multi-harness-installer AC12: $label --dry-run says what it would do" "$out" "Would"
  eq "multi-harness-installer AC12: $label --dry-run changes nothing on disk" "$after" "$before"
}
fresh="$scratch/dry-fresh"
dry "install into a new folder" install antigravity --target "$fresh"
eq "multi-harness-installer AC12: install --dry-run creates no folder" "$([ -e "$fresh" ] && echo made || echo none)" none
"$SHIP" install antigravity >/dev/null 2>&1                     # an install from this clone ...
echo "A line after the install." >>"$clone/skills/workflow/SKILL.md"   # ... whose copies are now old
dry "install over an install" install antigravity
dry "refresh antigravity" refresh antigravity
dry "plain refresh" refresh
dry "uninstall antigravity" uninstall antigravity
has "multi-harness-installer AC12: after the dry runs the copies are still older than the clone" \
  "$(PATH="$clone/bin:$PATH" "$SHIP" status antigravity 2>&1)" "older than the clone"

done_testing
