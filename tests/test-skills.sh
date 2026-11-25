# The plugin's own skills and agents: frontmatter, size, and the files they point to.
# Rules from CONTRIBUTING.md, "Writing a skill".
. "$(dirname "$0")/helpers.sh"
cd "$SY" || exit 1
max_lines=350

frontmatter() { awk 'NR==1 && $0=="---"{f=1; next} f && $0=="---"{exit} f' "$1"; }

for f in skills/*/SKILL.md; do
  dir="$(basename "$(dirname "$f")")"
  fm="$(frontmatter "$f")"
  name="$(printf '%s\n' "$fm" | sed -n 's/^name: //p' | head -n 1)"
  # The description, also when it is a YAML block (description: >- with indented lines below)
  desc="$(printf '%s\n' "$fm" | awk '/^description:/{sub(/^description:[ ]*/,""); if ($0 ~ /^[>|]/) {b=1; next} print; exit} b && /^[ ]/{sub(/^[ ]+/,""); printf "%s ", $0; next} b{exit}')"
  eq "$dir: name matches the folder" "$name" "$dir"
  [ -n "$desc" ] && [ "${#desc}" -le 1024 ] && ok "$dir: description is 1-1024 characters" || bad "$dir: description is 1-1024 characters" "${#desc} characters"
  printf '%s' "$desc" | grep -q 'Use ' && ok "$dir: description says when to use it" || bad "$dir: description says when to use it" "no 'Use ...' clause"
  n="$(wc -l <"$f" | tr -d ' ')"
  [ "$n" -le "$max_lines" ] && ok "$dir: SKILL.md is $max_lines lines or fewer" || bad "$dir: SKILL.md is $max_lines lines or fewer" "$n lines. Move detail into a reference file"
done

for f in agents/*.md; do
  base="$(basename "$f" .md)"
  name="$(frontmatter "$f" | sed -n 's/^name: //p' | head -n 1)"
  eq "agent $base: name matches the file" "$name" "$base"
done

# Every ${CLAUDE_PLUGIN_ROOT}/... and ${CLAUDE_SKILL_DIR}/... path a skill or agent names exists
missing=""
while IFS= read -r f; do
  skill_dir="$(dirname "$f")"
  while IFS= read -r ref; do
    case "$ref" in
      '${CLAUDE_PLUGIN_ROOT}/'*) p="${ref#\$\{CLAUDE_PLUGIN_ROOT\}/}" ;;
      '${CLAUDE_SKILL_DIR}/'*) p="skills/$(printf '%s' "$f" | cut -d/ -f2)/${ref#\$\{CLAUDE_SKILL_DIR\}/}" ;;
      *) continue ;;
    esac
    p="${p%.}"; p="${p%/}"
    [ -e "$p" ] || missing="$missing $f:$ref"
  done < <(grep -oE '\$\{CLAUDE_(PLUGIN_ROOT|SKILL_DIR)\}/[A-Za-z0-9_./-]+' "$f" | sort -u)
  # Relative Markdown links to files beside the skill: [text](name.md)
  while IFS= read -r ref; do
    [ -e "$skill_dir/$ref" ] || missing="$missing $f:($ref)"
  done < <(grep -oE '\]\([A-Za-z0-9_./-]+\.md(#[A-Za-z0-9_-]*)?\)' "$f" | sed 's/^](//; s/)$//; s/#.*$//' | sort -u)
done < <(find skills agents -name '*.md' -not -path 'skills/setup/templates/*' | sort)
eq "every file a skill or agent points to exists" "$missing" ""
done_testing
