#!/usr/bin/env bash
# lib.sh: shared helpers for Shipinetics hooks and tools. Source it, don't run it.
#
# A project's settings live in .shipinetics/config as "key = value" lines. "#" starts a comment.
# Paths are relative to the Shipinetics root, the folder that holds .shipinetics/, except
# evidence_dir, which is relative to the git repo a PR comes from.
# In workspace mode (packages is set), the root holds several package repos and isn't one itself.
# Run `shipinetics-config` to print a project's effective settings.

SY_KEYS="worksheets_dir feedback_file systems_dir conventions_file testing_guide_file test_index_file tools_index_file queue_file evidence_dir reviews_dir personas_dir verify_cmd verify_quick_cmd packages package_verify_cmd package_verify_quick_cmd verify_scope worksheet_new_cmd worksheet_tag_cmd package_worksheets_dir tag_prefix secrets_runner vault infisical_args"

sy_default() {
  case "$1" in
    worksheets_dir) echo "docs/worksheets" ;;
    feedback_file) echo "docs/agent-feedback.md" ;;
    systems_dir) echo "docs/systems" ;;
    conventions_file) echo "docs/conventions.md" ;;
    testing_guide_file) echo "docs/testing/how-to-write-tests.md" ;;
    test_index_file) echo "docs/testing/test-index.md" ;;
    tools_index_file) echo "docs/tools.md" ;;
    queue_file) echo "TODOS.md" ;;
    evidence_dir) echo "docs/evidence" ;;
    reviews_dir) echo "docs/reviews" ;;
    personas_dir) echo "docs/review/personas" ;;
    verify_cmd) echo "bin/verify" ;;
    verify_scope) echo "touched" ;;
    tag_prefix) echo "ws/" ;;
    secrets_runner) echo "bin/with-secrets" ;;
    vault) echo "gsm" ;;
    *) echo "" ;;
  esac
}

# sy_root [start]: nearest folder at or above start (default: the project dir, else PWD) holding .shipinetics/
sy_root() {
  local d="${1:-${CLAUDE_PROJECT_DIR:-$PWD}}"
  d="$(cd "$d" 2>/dev/null && pwd)" || return 1
  while :; do
    if [ -d "$d/.shipinetics" ]; then printf '%s\n' "$d"; return 0; fi
    [ "$d" = "/" ] && return 1
    d="$(dirname "$d")"
  done
}

# sy_cfg <root> <key>: the configured value, or the default
sy_cfg() {
  local f="$1/.shipinetics/config" v=""
  if [ -f "$f" ]; then
    v="$(sed -n "s/^[[:space:]]*$2[[:space:]]*=[[:space:]]*//p" "$f" | tail -n 1 | sed -e 's/[[:space:]]#.*$//' -e 's/[[:space:]]*$//')"
  fi
  if [ -n "$v" ]; then printf '%s\n' "$v"; else sy_default "$2"; fi
}

# sy_is_set <root> <key>: true if the project config sets the key itself
sy_is_set() {
  [ -f "$1/.shipinetics/config" ] && grep -qE "^[[:space:]]*$2[[:space:]]*=[[:space:]]*[^[:space:]#]" "$1/.shipinetics/config"
}

# sy_workspace <root>: true in workspace mode
sy_workspace() { [ -n "$(sy_cfg "$1" packages)" ]; }

# sy_package_of <root> <path relative to root>: the package folder the path belongs to, if any
sy_package_of() {
  local p
  for p in $(sy_cfg "$1" packages); do
    case "$2" in "$p"/*|"$p") printf '%s\n' "$p"; return 0 ;; esac
  done
  return 1
}

# sy_rel <root> <absolute path>: the path relative to root (unchanged if outside it).
# Compares resolved paths too, so a symlinked prefix (macOS /tmp is /private/tmp) still matches.
sy_rel() {
  local r="$1" p="$2" rr pp d
  [ "$p" = "$r" ] && { printf '.\n'; return 0; }
  case "$p" in "$r"/*) printf '%s\n' "${p#"$r"/}"; return 0 ;; esac
  rr="$(cd "$r" 2>/dev/null && pwd -P)" || { printf '%s\n' "$p"; return 0; }
  if [ -d "$p" ]; then pp="$(cd "$p" && pwd -P)"
  else
    d="$(dirname "$p")"
    while [ ! -d "$d" ] && [ "$d" != "/" ]; do d="$(dirname "$d")"; done
    pp="$(cd "$d" && pwd -P)${p#"$d"}"
  fi
  [ "$pp" = "$rr" ] && { printf '.\n'; return 0; }
  case "$pp" in "$rr"/*) printf '%s\n' "${pp#"$rr"/}" ;; *) printf '%s\n' "$p" ;; esac
}

# sy_in_list <listfile> <relpath>: true if a glob in the list matches; sets SY_MATCHED to that glob
sy_in_list() {
  local glob
  SY_MATCHED=""
  [ -f "$1" ] || return 1
  while IFS= read -r glob || [ -n "$glob" ]; do
    glob="${glob%%#*}"
    glob="$(printf '%s' "$glob" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ -z "$glob" ] && continue
    # shellcheck disable=SC2053  # the right-hand side is meant to be a pattern
    if [[ "$2" == $glob ]]; then SY_MATCHED="$glob"; return 0; fi
  done <"$1"
  return 1
}

# sy_json_field <json> <dotted.path>: a value from hook input, with a python fallback when jq is missing
sy_json_field() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$1" | jq -r ".$2 // empty"
  else
    printf '%s' "$1" | python3 -c 'import json,sys
v = json.load(sys.stdin)
for p in sys.argv[1].split("."):
    v = v.get(p) if isinstance(v, dict) else None
sys.stdout.write("" if v is None else str(v))' "$2"
  fi
}

# ---------------------------------------------------------------- verify tiers
# A project's checks run in tiers, each at the moment its result is needed (see shipinetics-verify):
#   quick     mid-task stops: checks scoped to the changed files (verify_quick_cmd)
#   complete  the "done" gate, push and PR: every fast check (verify_cmd, default bin/verify)
# Nothing is skipped. A tier's command just runs later or earlier. Without verify_quick_cmd,
# every stop runs the complete tier, as before. A pass is recorded against a fingerprint of the
# code's contents, so committing verified code, or editing only worksheets, evidence and the
# feedback log, doesn't re-run anything. A complete pass also counts as a quick pass.

# sy_key_suffix <package or empty>: cache-file suffix, "" for the single repo
sy_key_suffix() { if [ -n "$1" ]; then printf -- '-%s' "${1//\//_}"; fi; }

# sy_verify_excludes <root> <package or empty>: pathspecs that aren't code as far as verify goes
sy_verify_excludes() {
  local pkg_ws
  printf '%s\n' ':(exclude).shipinetics/.cache' ":(exclude)$(sy_cfg "$1" evidence_dir)"
  if [ -n "$2" ]; then
    pkg_ws="$(sy_cfg "$1" package_worksheets_dir)"
    if [ -n "$pkg_ws" ]; then printf '%s\n' ":(exclude)$pkg_ws"; fi
  else
    printf '%s\n' ":(exclude)$(sy_cfg "$1" worksheets_dir)" ":(exclude)$(sy_cfg "$1" feedback_file)"
  fi
}

# sy_fingerprint <repo dir> <exclude pathspecs...>: hash of the working tree's contents
# (tracked and untracked, minus ignored files and the excluded paths). It doesn't depend on HEAD,
# so the same code has the same fingerprint before and after it's committed. It builds the tree
# in a throwaway copy of the index and never touches the real one. Falls back to hashing HEAD
# plus the diff if that fails. Prints nothing and returns 1 if the folder isn't a usable git repo,
# so a broken fingerprint can never match a recorded pass. Not covered: ignored files (build
# output), edits inside a nested repo (it counts as one gitlink), and entries flagged
# skip-worktree or assume-unchanged in the real index.
sy_fingerprint() {
  local repo="$1" idx tree="" p paths=() add_excl=()
  shift
  git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || return 1
  for p in "$@"; do
    paths+=("${p#:(exclude)}")
    # git add refuses an exclude pathspec that names an ignored path, and ignored paths aren't
    # added anyway, so only pass the others. Excluding them here saves hashing big evidence files.
    git -C "$repo" check-ignore -q "${p#:(exclude)}" 2>/dev/null || add_excl+=("$p")
  done
  idx="$(mktemp "${TMPDIR:-/tmp}/sy-index.XXXXXX")" || idx=""
  if [ -n "$idx" ]; then
    tree="$(
      cd "$repo" || exit 1
      real="$(git rev-parse --git-path index 2>/dev/null)" || exit 1
      # Keep the mtime of the index file (cp -p). Git compares it with each entry to find racily
      # clean entries, files changed in the same second their entry was written at the same size.
      # A fresh mtime hides them, and the fingerprint would hash the old contents.
      if [ -f "$real" ]; then cp -p "$real" "$idx" || exit 1; else rm -f "$idx"; fi
      export GIT_INDEX_FILE="$idx"
      [ -f "$real" ] || git read-tree --empty || exit 1
      git add -A -- . ${add_excl[@]+"${add_excl[@]}"} >/dev/null 2>&1 || exit 1
      [ "${#paths[@]}" -eq 0 ] || git rm -r -q --cached --ignore-unmatch -- "${paths[@]}" >/dev/null 2>&1 || exit 1
      git write-tree 2>/dev/null
    )" || tree=""
    rm -f "$idx"
  fi
  if [ -n "$tree" ]; then printf '%s\n' "$tree"; return 0; fi
  (
    cd "$repo" || exit 0
    git rev-parse HEAD 2>/dev/null
    git diff HEAD --binary -- . "$@" 2>/dev/null || { git diff --cached --binary; git diff --binary; }
    git ls-files --others --exclude-standard -z -- . "$@" |
      while IFS= read -r -d '' f; do
        printf '%s\n' "$f"
        [ -f "$f" ] && shasum "$f"
      done
  ) | shasum | cut -d' ' -f1
}

# sy_changed_paths <repo> [since commit]: changed paths, one per line, relative to the repo:
# uncommitted changes (staged or not), untracked files, and files changed by commits since the
# given commit. Paths are unquoted, and a rename lists both its old and new path, so a verify
# script can read the list line by line.
sy_changed_paths() {
  {
    git -C "$1" -c core.quotePath=false diff --name-only --no-renames HEAD -- 2>/dev/null ||
      git -C "$1" -c core.quotePath=false diff --name-only --no-renames --cached -- 2>/dev/null
    git -C "$1" -c core.quotePath=false ls-files --others --exclude-standard 2>/dev/null
    if [ -n "${2:-}" ]; then git -C "$1" -c core.quotePath=false diff --name-only --no-renames "$2" HEAD -- 2>/dev/null; fi
  } | sed '/^$/d' | sort -u
}

# sy_has_quick <root> <package or empty>: true if the project defines a quick tier
sy_has_quick() {
  if [ -n "$2" ]; then [ -n "$(sy_cfg "$1" package_verify_quick_cmd)" ]
  else [ -n "$(sy_cfg "$1" verify_quick_cmd)" ]; fi
}

# sy_verify_cmd <root> <quick|complete> <package or empty>: the tier's command, "" if none.
# quick falls back to the complete command when the project has no quick tier.
sy_verify_cmd() {
  local c=""
  if [ -n "$3" ]; then
    if [ "$2" = quick ]; then c="$(sy_cfg "$1" package_verify_quick_cmd)"; fi
    [ -n "$c" ] || c="$(sy_cfg "$1" package_verify_cmd)"
    printf '%s\n' "${c//\{package\}/$3}"
  else
    if [ "$2" = quick ]; then c="$(sy_cfg "$1" verify_quick_cmd)"; fi
    [ -n "$c" ] || c="$(sy_cfg "$1" verify_cmd)"
    printf '%s\n' "$c"
  fi
}

# sy_verify_configured <root> <package or empty>: true if there's a verify command to run
sy_verify_configured() {
  local c b
  c="$(sy_verify_cmd "$1" complete "$2")"
  [ -n "$c" ] || return 1
  [ -n "$2" ] && return 0
  b="${c%% *}"
  [ -x "$1/$b" ] || command -v "$b" >/dev/null 2>&1
}

# sy_verify_passed <root> <package or empty> <quick|complete>: true if that tier (or complete)
# has passed on exactly the current code. Sets SY_VERIFY_FP to the current fingerprint.
sy_verify_passed() {
  local cache="$1/.shipinetics/.cache" sfx l excl=()
  sfx="$(sy_key_suffix "$2")"
  while IFS= read -r l; do excl+=("$l"); done < <(sy_verify_excludes "$1" "$2")
  SY_VERIFY_FP="$(sy_fingerprint "$1${2:+/$2}" "${excl[@]}")"
  [ -n "$SY_VERIFY_FP" ] || return 1
  [ "$SY_VERIFY_FP" = "$(cat "$cache/pass-complete$sfx" 2>/dev/null)" ] && return 0
  [ "$3" = quick ] && [ "$SY_VERIFY_FP" = "$(cat "$cache/pass-quick$sfx" 2>/dev/null)" ]
}

# sy_verify_log <root> <source> <package or empty> <tier> <seconds> <result>: one timing row
sy_verify_log() {
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$2" "${3:-.}" "$4" "$5" "$6" \
    >>"$1/.shipinetics/.cache/verify-times.tsv"
}

# sy_verify_run <root> <package or empty> <quick|complete> <changed-files list or ""> <source>
# Runs the tier's command, unless a pass is already recorded for exactly this code. The command
# runs from the root with SHIPINETICS_VERIFY_TIER set, and SHIPINETICS_CHANGED_FILES naming a file that
# lists the changed paths (relative to the repo being verified; unset means check everything).
# Records the pass, logs the timing, and returns the command's status. Afterwards SY_VERIFY_TIER
# is the tier that ran, SY_VERIFY_FP the fingerprint, SY_VERIFY_LOG the output, and SY_VERIFY_RAN
# is 1 if the command ran (0 if a recorded pass was reused).
sy_verify_run() {
  local root="$1" pkg="$2" tier="$3" list="$4" src="$5" cache sfx cmd t0 rc
  cache="$root/.shipinetics/.cache"; mkdir -p "$cache"
  sfx="$(sy_key_suffix "$pkg")"
  if [ "$tier" = quick ] && ! sy_has_quick "$root" "$pkg"; then tier=complete; fi
  SY_VERIFY_TIER="$tier" SY_VERIFY_LOG="$cache/verify$sfx.log" SY_VERIFY_RAN=0
  cmd="$(sy_verify_cmd "$root" "$tier" "$pkg")"
  [ -n "$cmd" ] || return 0
  if sy_verify_passed "$root" "$pkg" "$tier"; then
    sy_verify_log "$root" "$src" "$pkg" "$tier" 0 reused
    return 0
  fi
  SY_VERIFY_RAN=1
  t0="$(date +%s)"
  (
    cd "$root" || exit 1
    export SHIPINETICS_VERIFY_TIER="$tier"
    if [ -n "$list" ]; then export SHIPINETICS_CHANGED_FILES="$list"; else unset SHIPINETICS_CHANGED_FILES; fi
    sh -c "$cmd"
  ) >"$SY_VERIFY_LOG" 2>&1
  rc=$?
  if [ "$rc" = 0 ]; then
    [ -n "$SY_VERIFY_FP" ] && printf '%s' "$SY_VERIFY_FP" >"$cache/pass-$tier$sfx"
    rm -f "$cache/last-fail$sfx"
    sy_verify_log "$root" "$src" "$pkg" "$tier" "$(( $(date +%s) - t0 ))" pass
  else
    sy_verify_log "$root" "$src" "$pkg" "$tier" "$(( $(date +%s) - t0 ))" fail
  fi
  return "$rc"
}

# sy_task_done <root> [worksheet paths...]: true if the current worksheet, or one of the given
# ones, has its Status line set to done or handed off. That's the signal for the complete tier.
sy_task_done() {
  local root="$1" f p
  shift
  f="$root/.shipinetics/.cache/current-worksheet"
  if [ -f "$f" ]; then set -- "$(cat "$f")" "$@"; fi
  for p in "$@"; do
    case "$p" in /*) ;; *) p="$root/$p" ;; esac
    [ -f "$p" ] && grep -qiE '^>[[:space:]]*Status:[[:space:]]*(done|handed[[:space:]-]off)' "$p" && return 0
  done
  return 1
}
