#!/usr/bin/env bash
# PreCompact hook (Claude Code, matcher "manual": the /compact command). Before the conversation
# is replaced by a summary, the docs must hold what the session settled: the glossary, the ADRs,
# the system docs and the worksheet. /shipinetics:checkpoint writes them and records a checkpoint
# for the code (bin/shipinetics-checkpoint).
#
# - The checkpoint matches the current code: /compact runs.
# - It doesn't: the hook stops /compact (exit 2), and the person reads why and what to do.
# - A second /compact within 10 minutes of a stop runs anyway, whatever changed in between (a log
#   file or a watcher can change files), so nobody gets stuck. Only the person types /compact.
# - If the hook can't record the stop, it lets /compact run rather than stop it every time.
# When /compact runs, the hook's output tells the summary what to keep (Claude Code uses a
# PreCompact hook's stdout as instructions for the summary).
# Does nothing for automatic compaction, outside a set-up project, or with "hooks_off = compact"
# (or SHIPINETICS_HOOKS_OFF=compact).

set -uo pipefail

input="$(cat)"
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"
[ "$(sy_hook_harness "$input")" = claude ] || exit 0
[ "$(sy_json_field "$input" trigger)" = manual ] || exit 0
cwd="$(sy_hook_cwd "$input")"
repo="$(sy_git_top "$cwd")" || exit 0
root="$(sy_root "$repo")" || exit 0
sy_hook_off compact "$root" && exit 0
pkg=""
if [ "$root" != "$repo" ]; then
  pkg="$(sy_rel "$root" "$repo")"
  sy_workspace "$root" && sy_package_of "$root" "$pkg" >/dev/null || exit 0
fi

cache="$(sy_dir "$root")/.cache"; sfx="$(sy_key_suffix "$pkg")"
excl=()
while IFS= read -r l; do excl+=("$l"); done < <(sy_verify_excludes "$root" "$pkg")
fp="$(sy_fingerprint "$repo" "${excl[@]}")"

# keep_list: the instructions for the summary
keep_list() {
  local ws=""
  ws="$(cat "$(sy_state_dir "$root" 2>/dev/null)/current-worksheet" 2>/dev/null || true)"
  cat <<TXT
Shipinetics: keep these in the summary, word for word where they are names:
- The current worksheet${ws:+: $ws}. The next session reads it first.
- Which acceptance criteria are done, and which are still open.
- Decisions and terms that the session settled and that are not yet in GLOSSARY.md, docs/adr/, the system docs or the worksheet.
- Changed files that are not committed yet.
- The exact next step.
TXT
}

if [ -n "$fp" ] && [ "$fp" = "$(cat "$cache/docs-checkpoint$sfx" 2>/dev/null)" ]; then
  keep_list; exit 0
fi

now="$(date +%s)"
bt=0
[ -f "$cache/compact-blocked$sfx" ] && read -r _ bt <"$cache/compact-blocked$sfx"
case "$bt" in ''|*[!0-9]*) bt=0 ;; esac
if [ "$bt" -gt 0 ] && [ $((now - bt)) -le 600 ]; then
  rm -f "$cache/compact-blocked$sfx"
  keep_list; exit 0
fi

# Record the stop. If that fails, a stop could never be skipped, so let /compact run instead.
if ! { mkdir -p "$cache" && printf '%s %s\n' "$fp" "$now" >"$cache/compact-blocked$sfx"; } 2>/dev/null; then
  keep_list; exit 0
fi
cat >&2 <<'TXT'
Shipinetics: write the docs before you compact. A summary keeps less than the docs do.
1. Run /shipinetics:checkpoint. The agent writes the glossary terms, ADRs, system docs and worksheet for what this session settled.
2. Then run /compact again.
To compact now without the docs, run /compact again within 10 minutes. To turn this check off, add compact to hooks_off in .shipinetics/config.
TXT
exit 2
