#!/usr/bin/env bash
# lib.sh: shared helpers for Shipinetics hooks and tools. Source it, don't run it.
#
# A project's settings live in .shipinetics/config as "key = value" lines. "#" starts a comment.
# Paths are relative to the Shipinetics root, the folder that holds .shipinetics/, except
# evidence_dir, which is relative to the git repo a PR comes from.
# In workspace mode (packages is set), the root holds several package repos and isn't one itself.
# Run `shipinetics-config` to print a project's effective settings.

SY_KEYS="worksheets_dir feedback_file systems_dir conventions_file testing_guide_file test_index_file tools_index_file queue_file evidence evidence_dir evidence_upload_cmd personas_dir verify_cmd verify_quick_cmd packages package_verify_cmd package_verify_quick_cmd worksheet_new_cmd worksheet_tag_cmd package_worksheets_dir tag_prefix secrets_runner vault infisical_args env_safe_names launch bench_cmd package_bench_cmd harness_repo hooks_off companions_skip security_audit_every"

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
    evidence) echo "optional" ;;
    evidence_dir) echo "docs/evidence" ;;
    personas_dir) echo "docs/review/personas" ;;
    verify_cmd) echo "bin/verify" ;;
    tag_prefix) echo "ws/" ;;
    secrets_runner) echo "bin/with-secrets" ;;
    vault) echo "gsm" ;;
    launch) echo "agent" ;;
    security_audit_every) echo "off" ;;
    bench_cmd) echo "bin/bench" ;;
    *) echo "" ;;
  esac
}

SY_DIR_NAME=".shipinetics"

# sy_env <NAME> [default]: $SHIPINETICS_<NAME>, else the default. A variable set to empty counts
# as set.
sy_env() {
  local n="SHIPINETICS_$1"
  if [ -n "${!n+x}" ]; then printf '%s\n' "${!n}"; else printf '%s\n' "${2:-}"; fi
}

# sy_flag <NAME>: true if the setting (see sy_env) is 1
sy_flag() { [ "$(sy_env "$1" 0)" = "1" ]; }

# sy_dir <root>: the project's folder (settings, policy lists and .cache)
sy_dir() { printf '%s/%s\n' "$1" "$SY_DIR_NAME"; }

# sy_state_dir <root>: where tools keep local state, such as the current worksheet. In a set-up
# project it is .shipinetics/.cache. In a plain git repo it is a folder in the git directory, so
# that no tool creates .shipinetics/ there: that folder makes the hooks treat a repo as set up.
# Each git worktree gets its own folder. Fails when root is neither. Doesn't create the folder.
sy_state_dir() {
  local p
  if [ -d "$(sy_dir "$1")" ]; then printf '%s/.cache\n' "$(sy_dir "$1")"; return 0; fi
  p="$(git -C "$1" rev-parse --git-path shipinetics 2>/dev/null)" || return 1
  case "$p" in /*) ;; *) p="$1/$p" ;; esac
  printf '%s\n' "$p"
}

# sy_root [start]: nearest folder at or above start (default: the project dir, else PWD) holding
# .shipinetics/
sy_root() {
  local d="${1:-${CLAUDE_PROJECT_DIR:-$PWD}}"
  d="$(cd "$d" 2>/dev/null && pwd)" || return 1
  while :; do
    if [ -d "$d/$SY_DIR_NAME" ]; then printf '%s\n' "$d"; return 0; fi
    [ "$d" = "/" ] && return 1
    d="$(dirname "$d")"
  done
}

# sy_cfg_file <file> <key>: the key's value in a config file, empty if it's not set
sy_cfg_file() {
  [ -f "$1" ] || return 0
  sed -n "s/^[[:space:]]*$2[[:space:]]*=[[:space:]]*//p" "$1" | tail -n 1 | sed -e 's/[[:space:]]#.*$//' -e 's/[[:space:]]*$//'
}

# sy_cfg <root> <key>: the configured value, or the default
sy_cfg() {
  local v
  v="$(sy_cfg_file "$(sy_dir "$1")/config" "$2")"
  if [ -n "$v" ]; then printf '%s\n' "$v"; else sy_default "$2"; fi
}

# sy_is_set <root> <key>: true if the project config sets the key itself
sy_is_set() {
  local f
  f="$(sy_dir "$1")/config"
  [ -f "$f" ] && grep -qE "^[[:space:]]*$2[[:space:]]*=[[:space:]]*[^[:space:]#]" "$f"
}

# sy_workspace <root>: true in workspace mode
sy_workspace() { [ -n "$(sy_cfg "$1" packages)" ]; }

# sy_harness_repo <root>: the git repo that versions the root's own files (.shipinetics/, the queue,
# root docs). That's the root itself when it's the top of a repo, else the repo harness_repo names
# (its top level mirrors the root's harness files, which the root links to). Fails if neither.
sy_harness_repo() {
  local top h
  if top="$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)" &&
     [ "$(cd "$top" && pwd -P)" = "$(cd "$1" && pwd -P)" ]; then
    printf '%s\n' "$1"; return 0
  fi
  h="$(sy_cfg "$1" harness_repo)"
  [ -n "$h" ] || return 1
  case "$h" in /*) ;; *) h="$1/$h" ;; esac
  git -C "$h" rev-parse --show-toplevel 2>/dev/null
}

# sy_package_of <root> <path relative to root>: the package folder the path belongs to, if any
sy_package_of() {
  local p
  for p in $(sy_cfg "$1" packages); do
    case "$2" in "$p"/*|"$p") printf '%s\n' "$p"; return 0 ;; esac
  done
  return 1
}

# sy_norm_path <absolute path>: the same path without . and .. parts (no symlinks resolved)
sy_norm_path() {
  local part parts out=()
  IFS=/ read -r -a parts <<<"$1"
  for part in ${parts[@]+"${parts[@]}"}; do
    case "$part" in
      ''|.) ;;
      ..) [ "${#out[@]}" -gt 0 ] && unset "out[$((${#out[@]} - 1))]" ;;
      *) out+=("$part") ;;
    esac
  done
  if [ "${#out[@]}" -gt 0 ]; then printf '/%s' "${out[@]}"; echo; else echo /; fi
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

# Changes that need no evidence (shipinetics:evidence). The project's .shipinetics/no-evidence-paths
# replaces these defaults. Keep them the same as templates/no-evidence-paths and the CI template.
SY_NO_EVIDENCE_DEFAULTS='docs/*
*.md
.github/*
.gitignore
.gitattributes
.editorconfig
.vscode/*
LICENSE*'

# sy_no_evidence <root> <path relative to root>: true if a change to this path needs no evidence.
# That is .shipinetics/, a test file (test-paths), or a match in no-evidence-paths (else the defaults).
# Sets SY_MATCHED to the glob or the list that matched.
sy_no_evidence() {
  local d="$1/$SY_DIR_NAME" glob
  case "$2" in "$SY_DIR_NAME"/*) SY_MATCHED="$SY_DIR_NAME/"; return 0 ;; esac
  sy_in_list "$d/test-paths" "$2" && return 0
  if [ -f "$d/no-evidence-paths" ]; then sy_in_list "$d/no-evidence-paths" "$2"; return; fi
  SY_MATCHED=""
  while IFS= read -r glob; do
    # shellcheck disable=SC2053  # the right-hand side is meant to be a pattern
    if [[ "$2" == $glob ]]; then SY_MATCHED="$glob"; return 0; fi
  done <<<"$SY_NO_EVIDENCE_DEFAULTS"
  return 1
}

# ---------------------------------------------------------------- hook settings
# Each hook can be switched off, and the secrets guard's file list is the user's to set. Settings
# come from the project (.shipinetics/) or from the user's own folder, for every project.

# sy_user_dir: the user's settings folder (config and secret-paths), for every project
sy_user_dir() { printf '%s/shipinetics\n' "${XDG_CONFIG_HOME:-$HOME/.config}"; }

# sy_hook_off <name> [root]: true if the hook is switched off. The names are edits,
# secrets, pr, installs, companions and usage. Off means listed in $SHIPINETICS_HOOKS_OFF, or in hooks_off in the
# project's config, or (when the project doesn't set hooks_off) in the user's config.
sy_hook_off() {
  local off
  if [ -n "${2:-}" ] && sy_is_set "$2" hooks_off; then off="$(sy_cfg "$2" hooks_off)"
  else off="$(sy_cfg_file "$(sy_user_dir)/config" hooks_off)"; fi
  case " $(sy_env HOOKS_OFF) $off " in *" $1 "*) return 0 ;; esac
  return 1
}

# sy_companions_file: the plugin's list of companions (see the header of companions.tsv)
sy_companions_file() { printf '%s/companions.tsv\n' "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; }

# sy_claude_dir: Claude Code's own settings folder
sy_claude_dir() { printf '%s\n' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; }

# sy_gemini_dir: Antigravity's global config folder
sy_gemini_dir() { printf '%s\n' "${GEMINI_CONFIG_DIR:-$HOME/.gemini/config}"; }

# sy_companion_installed <kind> <id> [project dir]: true if the companion is installed. A skill is
# in Claude Code's skills, Antigravity's skills or plugins, the skills CLI's global folder, or the
# project's .claude/skills or .agents/skills. A plugin is in Claude Code's installed_plugins.json
# or Antigravity's plugins folder. A cli is on the PATH.
sy_companion_installed() {
  local c g f pname
  c="$(sy_claude_dir)"
  g="$(sy_gemini_dir)"
  case "$1" in
    skill)
      [ -f "$c/skills/$2/SKILL.md" ] && return 0
      [ -f "$HOME/.agents/skills/$2/SKILL.md" ] && return 0
      [ -f "$g/skills/$2/SKILL.md" ] && return 0
      if [ -n "${3:-}" ]; then
        [ -f "$3/.claude/skills/$2/SKILL.md" ] && return 0
        [ -f "$3/.agents/skills/$2/SKILL.md" ] && return 0
      fi
      for f in "$g"/plugins/*/skills/"$2"/SKILL.md; do
        [ -f "$f" ] && return 0
      done
      return 1
      ;;
    plugin)
      if [ -f "$c/plugins/installed_plugins.json" ] && grep -qF "\"$2\"" "$c/plugins/installed_plugins.json"; then
        return 0
      fi
      pname="${2%%@*}"
      [ -f "$g/plugins/$pname/plugin.json" ] && return 0
      for f in "$g"/plugins/*/plugin.json; do
        [ -f "$f" ] && grep -qE "\"name\"[[:space:]]*:[[:space:]]*\"$pname\"" "$f" && return 0
      done
      return 1
      ;;
    cli)    command -v "$2" >/dev/null 2>&1 ;;
    *)      return 1 ;;
  esac
}

# sy_companion_declined <name> <id> [root]: true if companions_skip names the companion (by name
# or id, any case; names are separated by spaces or commas). The project's companions_skip wins, else the user's, like hooks_off.
sy_companion_declined() {
  local skip w
  if [ -n "${3:-}" ] && sy_is_set "$3" companions_skip; then skip="$(sy_cfg "$3" companions_skip)"
  else skip="$(sy_cfg_file "$(sy_user_dir)/config" companions_skip)"; fi
  skip="${skip//,/ }"
  for w in $skip; do
    w="$(printf '%s' "$w" | tr '[:upper:]' '[:lower:]')"
    case "$w" in "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"|"$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')") return 0 ;; esac
  done
  return 1
}

# The credential files the secrets guard keeps agents away from when no list is set.
SY_SECRET_PATHS_DEFAULT='.config/gcloud
.config/gcloud/*
application_default_credentials.json
.aws/credentials
.aws/config
.azure
.azure/*
.ssh/id_*
.netrc
.npmrc
.pypirc
.docker/config.json
.kube/config
.git-credentials
.infisical
.infisical/*
.railway
.railway/*'

# sy_secret_paths [root]: the secret-path globs in force, one per line. The project's
# .shipinetics/secret-paths, else the user's secret-paths, else the defaults above. The first list
# found is the whole list (they don't add up), so a list says exactly what's guarded.
sy_secret_paths() {
  local f
  for f in ${1:+"$(sy_dir "$1")/secret-paths"} "$(sy_user_dir)/secret-paths"; do
    if [ -f "$f" ]; then
      sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$f" | grep -v '^$' || true
      return 0
    fi
  done
  printf '%s\n' "$SY_SECRET_PATHS_DEFAULT"
}

# sy_secret_match <path> <glob>...: true if the path is covered by one of the globs, and sets
# SY_MATCHED to it. A glob without / matches the file or folder name anywhere. A glob with / matches
# the end of the path. ~ is the home folder, and * also matches /.
sy_secret_match() {
  local p="${1%/}" g base
  shift
  case "$p" in "~") p="$HOME" ;; "~/"*) p="$HOME/${p#\~/}" ;; esac
  base="${p##*/}"
  SY_MATCHED=""
  for g in "$@"; do
    case "$g" in "~/"*) g="$HOME/${g#\~/}" ;; esac
    case "$g" in
      */*) # shellcheck disable=SC2053  # the glob is meant to be a pattern
           if [[ "$p" == $g || "$p" == */$g ]]; then SY_MATCHED="$g"; return 0; fi ;;
      *)   # shellcheck disable=SC2053
           if [[ "$base" == $g ]]; then SY_MATCHED="$g"; return 0; fi ;;
    esac
  done
  return 1
}

# ---------------------------------------------------------------- guard text
# Variables that never hold secrets. The env guards ignore reads of these, and a project can add
# its own with env_safe_names in the config.
SY_SAFE_ENV="HOME PATH TMPDIR TMP TEMP USER LOGNAME SHELL PWD OLDPWD LANG LC_ALL TERM TZ HOSTNAME EDITOR NODE_ENV CI"

# sy_safe_env_names [root]: the built-in safe names plus the project's env_safe_names
sy_safe_env_names() {
  if [ -n "${1:-}" ]; then printf '%s %s\n' "$SY_SAFE_ENV" "$(sy_cfg "$1" env_safe_names)"
  else printf '%s\n' "$SY_SAFE_ENV"; fi
}

# sy_sanitize <cmd|code|gate> <safe names>: stdin to stdout, minus the text the guards shouldn't
# judge. Both modes turn complete reads of safe variables into SAFE_ENV. cmd mode (a Bash command)
# also drops heredoc bodies that can't run, the inert pattern of grep, egrep, fgrep, git grep and
# rg, and printenv of safe names. gate mode (for the PR gate and the install gate) drops text only
# from three known command shapes: a note written with cat, a list of git steps, and a search.
# Whenever it can't be sure text is inert, it leaves it in, so the guards judge it.
sy_sanitize() { perl -e "$SY_SANITIZE_PL" "$1" "$2"; }
read -r -d '' SY_SANITIZE_PL <<'PL' || true
use strict; use warnings;
my ($mode, $names) = @ARGV;
my $t = do { local $/; <STDIN> }; $t = '' unless defined $t;
my $n = join '|', map { quotemeta } grep { /^[A-Za-z_][A-Za-z0-9_]*$/ } split ' ', ($names // '');

# A heredoc body is dropped only when bash can't run any of it: the command is a plain
# "cat > file", "cat >> file" or "tee [-a] file" alone on its line (no quotes, comments, pipes,
# substitutions or other commands around it), the file isn't a device and isn't named anywhere
# else in the command (so it isn't run afterwards), and the body can't expand: the delimiter is
# quoted, or the body has no $, ` or \.
sub heredocs {
  my $all = shift;
  my (@out, @open);
  my $id = qr/[A-Za-z_][A-Za-z0-9_]*/;
  for my $line (split /\n/, $all, -1) {
    if (@open) {
      my $h = $open[0];
      my $cmp = $h->{dash} ? ($line =~ s/^\t+//r) : $line;
      if ($cmp eq $h->{delim}) {
        shift @open;
        my $inert = $h->{quoted} || !grep { /[\$`\\]/ } @{$h->{body}};
        push @out, ($h->{drop} && $inert) ? map { '' } @{$h->{body}} : @{$h->{body}};
        push @out, $line;
      } else {
        push @{$h->{body}}, $line;
      }
      next;
    }
    push @out, $line;
    while ($line =~ /(?<!<)<<(?!<)(-?)[ \t]*(?:'($id)'|"($id)"|\\($id)|($id))(?=[\s;&|<>()]|$)/g) {
      my $h = { dash => $1, delim => $2 // $3 // $4 // $5, quoted => !defined $5, body => [], drop => 0 };
      my $cmd = substr($line, 0, $-[0]) . ' ' . substr($line, $+[0]);
      if ($cmd =~ /^\s*(?:cat\s*>>?\s*([^\s<>&|;()'"`\$#]+)|tee(?:\s+-a)?\s+([^\s<>&|;()'"`\$#-][^\s<>&|;()'"`\$#]*))\s*$/) {
        my $file = $1 // $2;
        (my $base = $file) =~ s{.*/}{};
        my $mentions = () = $all =~ /\Q$base\E/g;
        $h->{drop} = 1 if $file !~ m{^/dev/} && $mentions == 1;
      }
      push @open, $h;
    }
  }
  push @out, @{$_->{body}} for @open;   # unterminated: keep everything
  return join "\n", @out;
}

# tokens: [type, text], type 'w' (word), 'sp' (blanks) or 's' (separator)
sub tokens {
  my $s = shift; my @tok; my ($i, $len) = (0, length $s);
  while ($i < $len) {
    my $c = substr($s, $i, 1);
    if ($c =~ /[ \t]/) { my $j = $i; $j++ while $j < $len && substr($s, $j, 1) =~ /[ \t]/; push @tok, ['sp', substr($s, $i, $j - $i)]; $i = $j; next }
    if (substr($s, $i, 2) eq '$(') { push @tok, ['s', '$(']; $i += 2; next }
    if ($c =~ /[;&|()`\n<>]/) { push @tok, ['s', $c]; $i++; next }
    my $j = $i;
    while ($j < $len) {
      my $d = substr($s, $j, 1);
      last if $d =~ /[ \t;&|()`\n<>]/ || substr($s, $j, 2) eq '$(';
      if ($d eq "'") { my $k = index($s, "'", $j + 1); $j = $k < 0 ? $len : $k + 1; next }
      if ($d eq '$' && substr($s, $j + 1, 1) eq "'") {   # $'...' with backslash escapes
        my $k = $j + 2; while ($k < $len && substr($s, $k, 1) ne "'") { $k++ if substr($s, $k, 1) eq '\\'; $k++ }
        $j = $k < $len ? $k + 1 : $len; next;
      }
      if ($d eq '"') { my $k = $j + 1; while ($k < $len && substr($s, $k, 1) ne '"') { $k++ if substr($s, $k, 1) eq '\\'; $k++ } $j = $k < $len ? $k + 1 : $len; next }
      $j += $d eq '\\' ? 2 : 1;
    }
    push @tok, ['w', substr($s, $i, $j - $i)]; $i = $j;
  }
  return @tok;
}

sub unquote { my $w = shift; $w =~ s/^'(.*)'$/$1/s or $w =~ s/^"(.*)"$/$1/s; return $w }

# A pattern is blanked only if the shell can't run anything in it: all in single quotes, or
# without $, ` and \. Any option this doesn't know stops the stripping for that command.
sub search_patterns {
  my @tok = tokens(shift);
  my %opts = (
    grep => { arg => [qw(-A -B -C -m -d -D --context --after-context --before-context --max-count
                         --include --exclude --exclude-dir --devices --directories --label)],
              flag => [qw(-r -R -n -i -l -L -c -v -w -x -o -q -s -h -H -E -F -G -P -a -I -z -Z -b -U -T
                          --recursive --dereference-recursive --line-number --ignore-case --files-with-matches
                          --files-without-match --count --invert-match --word-regexp --line-regexp
                          --only-matching --quiet --silent --no-messages --no-filename --with-filename
                          --extended-regexp --fixed-strings --basic-regexp --perl-regexp --text --null
                          --null-data --byte-offset --binary --initial-tab --line-buffered --color)] },
    rg   => { arg => [qw(-A -B -C -m -g -t -T -j -M -E -r -d --context --after-context --before-context
                         --max-count --glob --iglob --type --type-not --threads --max-columns --encoding
                         --replace --max-depth --pre --pre-glob --sort --sortr --type-add --max-filesize)],
              flag => [qw(-n -i -S -s -l -c -v -w -x -o -q -u -uu -uuu -L -H -I -N -F -U -a -z -0 -p
                          --line-number --ignore-case --smart-case --case-sensitive --files-with-matches
                          --files-without-match --count --invert-match --word-regexp --line-regexp
                          --only-matching --quiet --unrestricted --follow --with-filename --no-filename
                          --no-line-number --fixed-strings --multiline --text --hidden --no-ignore
                          --no-heading --heading --json --vimgrep --stats --pretty --color --null)] },
  );
  my @seg;
  for my $k (0 .. $#tok + 1) {
    if ($k <= $#tok && $tok[$k][0] ne 's') { push @seg, $k if $tok[$k][0] eq 'w'; next }
    my @w = @seg; @seg = ();
    shift @w while @w && (unquote($tok[$w[0]][1]) =~ /^[A-Za-z_][A-Za-z0-9_]*=/ || $tok[$w[0]][1] =~ /^(sudo|command|time|nohup|exec)$/);
    next unless @w;
    my $cmd = unquote($tok[$w[0]][1]); $cmd =~ s{.*/}{};
    my $tool;
    if ($cmd eq 'git' && @w > 1 && $tok[$w[1]][1] eq 'grep') { shift @w; $tool = 'grep' }
    elsif ($cmd =~ /^[ef]?grep$/) { $tool = 'grep' }
    elsif ($cmd eq 'rg') { $tool = 'rg' }
    else { next }
    shift @w;
    my %arg = map { $_ => 1 } @{$opts{$tool}{arg}};
    my %flag = map { $_ => 1 } @{$opts{$tool}{flag}};
    my (@blank, $pattern_given, $only_pos);
    my $ok = 1;
    for (my $a = 0; $a < @w; $a++) {
      my $raw = $tok[$w[$a]][1]; my $u = unquote($raw);
      if (!$only_pos && $u eq '--') { $only_pos = 1; next }
      if (!$only_pos && $u =~ /^-./) {
        if ($u eq '-e' || $u eq '--regexp') { push @blank, $a, $a + 1; $a++; $pattern_given = 1; next }
        if ($u =~ /^(?:-e.|--regexp=)/) { push @blank, $a; $pattern_given = 1; next }
        if ($u eq '-f' || $u eq '--file') { $a++; $pattern_given = 1; next }
        if ($u =~ /^(?:-f.|--file=)/) { $pattern_given = 1; next }
        if ($u =~ /^--[\w-]+=/) { next }
        if ($arg{$u}) { $a++; next }
        if ($flag{$u}) { next }
        if ($u =~ /^-([A-Za-z0-9]+)$/ && !grep { !$flag{"-$_"} } split //, $1) { next }   # a cluster of flags
        $ok = 0; last;
      }
      if (!$pattern_given) { push @blank, $a; $pattern_given = 1 }
    }
    next unless $ok;
    for my $a (@blank) {
      next if $a >= @w;
      my $raw = $tok[$w[$a]][1];
      $tok[$w[$a]][1] = '' if $raw =~ /^'[^']*'$/ || $raw !~ /[\$`\\]/;
    }
  }
  return join '', map { $_->[1] } @tok;
}

# gate mode, for the PR gate and the install gate. It drops text only when the whole command has
# one of three known shapes, and leaves every other command whole. The shapes need no parsing of
# comments, pipes into programs, substitutions or functions, where bash and this script could
# disagree about what runs. Any doubt keeps the text, so the gate judges it.
#   1. A note: cat > <file>.md|.txt|.rst|.adoc <<'X' with a quoted delimiter. Its body goes.
#      Plain cd and git steps (shape 2) may follow.
#   2. Commits: plain cd and git steps joined by ;, && or new lines. A commit message that can't
#      expand goes.
#   3. A search: one grep, egrep, fgrep, rg or git grep, piped only into commands that print.
#      The pattern goes.

# A word that the shell can't expand: all in single quotes, no $, ` or \ at all, or
# "$(cat <<'X' ... X)" whose quoted delimiter stops the body from expanding, with nothing after
# the first delimiter line but the closing ). Never a word that starts a comment.
sub inert_word {
  my $w = shift;
  return 0 if $w =~ /^#/ || !closed_quotes($w);
  return 1 if $w =~ /^'[^']*'$/ || $w !~ /[\$`\\]/;
  # The body must not expand at all: bash 3.2 can end the $( early at a ) in the body, and then
  # the rest is plain text in double quotes.
  if ($w =~ /^"\$\(\s*cat\s*<<(-?)\s*'([A-Za-z_][A-Za-z0-9_]*)'[ \t]*\n(.*?)\n(\t*)\2\n(.*)$/s) {
    my ($dash, $body, $tabs, $rest) = ($1, $3, $4, $5);
    return 1 if ($dash || $tabs eq '') && $rest =~ /^\s*\)"$/ && $body !~ /[\$`\\]/;
  }
  return 0;
}

# True if every quote in the word closes. A quote left open makes bash read on, past where the
# tokenizer stops.
sub closed_quotes { (my $x = shift) =~ s/'[^']*'|"(?:[^"\\]|\\.)*"//gs; return $x !~ /['"]/ }

# A word with nothing for the shell to do: no $, ` or \, no new line, no comment, closed quotes.
sub plain_word { my $w = shift; return $w !~ /[\$`\\\n]/ && $w !~ /^#/ && closed_quotes($w) }

# The options that each allowed git step may take. Anything else (--output, --ext-diff,
# --receive-pack, -e ...) fails the shape: some git options write files or run programs.
my %git_opts = (
  add    => qr/^(?:-A|--all|-u|--update|-N|--intent-to-add|-f|--force|-v|--verbose)$/,
  commit => qr/^(?:-a|--all|-q|--quiet|-s|--signoff|--allow-empty|--amend|--no-edit|--no-verify|-n|-v|--verbose)$/,
  push   => qr/^(?:-u|--set-upstream|-q|--quiet|--tags|--follow-tags|--force-with-lease|-f|--force|--no-verify)$/,
  status => qr/^(?:-s|--short|-b|--branch|--porcelain(?:=v[12])?|-u(?:no|normal|all)?)$/,
  diff   => qr/^(?:--stat|--name-only|--name-status|--cached|--staged|--check|--shortstat|--no-color)$/,
  log    => qr/^(?:-\d+|-n|--oneline|--stat|--graph|--decorate|--no-decorate|--(?:format|pretty)=.*|--max-count=\d+|--no-color)$/s,
  show   => qr/^(?:--stat|--name-only|--name-status|--oneline|-s|--no-patch|--(?:format|pretty)=.*|--no-color)$/s,
  fetch  => qr/^(?:-q|--quiet|--prune|-p|--tags|--all)$/,
  pull   => qr/^(?:-q|--quiet|--rebase|--ff-only|--no-rebase)$/,
);

# The options that a command after a search may take. They only print; sort -o, uniq OUT and
# sort --compress-program write files or run programs.
my %sink_words = (
  head => qr/^(?:-[nc]?\d*|\d+)$/,
  tail => qr/^(?:-[nc]?\d*|\d+)$/,
  wc   => qr/^-[lwcm]+$/,
  sort => qr/^(?:-[nrufbd]+|-k[\d.,]+)$/,
  uniq => qr/^-[cud]+$/,
  cut  => qr/^(?:-[fc][\d,-]+|-[fc]|[\d,-]+|-d.?|'.'|"[^"\\\$`]")$/,
  tr   => qr/^(?:-[dsc]+|'[^']*'|"[^"\\\$`]*"|[A-Za-z0-9:\[\]-]+)$/,
);

# Shape 2. Returns the text without its inert commit messages, or undef if it isn't the shape.
sub gate_commits {
  my @tok = tokens(shift);
  my (@segs, @cur);
  for my $i (0 .. $#tok) {
    my ($type, $x) = @{$tok[$i]};
    if ($type eq 's') {
      return undef unless $x eq ';' || $x eq '&' || $x eq "\n";
      push @segs, [@cur] if @cur; @cur = (); next;
    }
    push @cur, $i if $type eq 'w';
  }
  push @segs, [@cur] if @cur;
  return undef unless @segs;
  my @blank;
  for my $seg (@segs) {
    my @w = @$seg;
    my $first = $tok[$w[0]][1];
    if ($first eq 'cd') { return undef unless @w == 2 && plain_word($tok[$w[1]][1]); next }
    return undef unless $first eq 'git';
    my $a = 1;
    while ($a < @w && $tok[$w[$a]][1] =~ /^(?:-C|--no-pager)$/) {
      if ($tok[$w[$a]][1] eq '-C') { return undef unless $a + 1 < @w && plain_word($tok[$w[$a + 1]][1]); $a += 2 } else { $a++ }
    }
    return undef unless $a < @w && $git_opts{$tok[$w[$a]][1]};
    my $sub = $tok[$w[$a]][1];
    my $after_dashes = 0;
    for (my $i = $a + 1; $i < @w; $i++) {
      my $raw = $tok[$w[$i]][1];
      if (!$after_dashes && $raw eq '--') { $after_dashes = 1; next }
      if ($sub eq 'commit' && !$after_dashes) {
        if ($raw eq '--message' || $raw =~ /^-[aqsnv]*m$/) {
          return undef unless $i + 1 < @w && inert_word($tok[$w[$i + 1]][1]);
          push @blank, $w[$i + 1]; $i++; next;
        }
        if ($raw =~ /^(?:--message=|-m)(.+)$/s) {
          return undef unless inert_word($1);
          push @blank, $w[$i]; next;
        }
      }
      return undef unless plain_word($raw);
      return undef if !$after_dashes && $raw =~ /^-/ && $raw !~ $git_opts{$sub};
    }
  }
  $tok[$_][1] = '' for @blank;
  return join '', map { $_->[1] } @tok;
}

# Shape 1. Returns the text without the note's body, or undef if it isn't the shape.
sub gate_note {
  my $s = shift;
  return undef unless $s =~ /\A[ \t]*cat[ \t]*>>?[ \t]*([A-Za-z0-9_.\/-]+\.(?:md|txt|rst|adoc))[ \t]*<<(-?)[ \t]*'([A-Za-z_][A-Za-z0-9_]*)'([^\n]*)\n/;
  my ($file, $dash, $delim, $tail) = ($1, $2, $3, $4);
  my @lines = split /\n/, substr($s, $+[0]), -1;
  my $k;
  for my $j (0 .. $#lines) { my $l = $lines[$j]; $l =~ s/^\t+// if $dash; if ($l eq $delim) { $k = $j; last } }
  return undef unless defined $k;
  my $rest = join "\n", @lines[$k + 1 .. $#lines];
  my $out = "cat > $file\n";
  if ($tail =~ /\S/) {
    return undef unless $tail =~ /^[ \t]*(?:&&|;)[ \t]*(\S.*)$/;
    my $r = gate_commits($1); return undef unless defined $r;
    $out .= "$r\n";
  }
  if ($rest =~ /\S/) { my $r = gate_commits($rest); return undef unless defined $r; $out .= $r }
  return $out;
}

# Shape 3. Returns the text without the search pattern, or undef if it isn't the shape.
sub gate_search {
  (my $s = shift) =~ s/[ \t]+2>\/dev\/null(?=[ \t|]|$)//g;
  my @tok = tokens($s);
  my (@stages, @cur, $prev);
  for my $i (0 .. $#tok) {
    my ($type, $x) = @{$tok[$i]};
    if ($type eq 's') {
      return undef unless $x eq '|' && !(defined $prev && $prev eq '|');
      push @stages, [@cur]; @cur = (); $prev = '|'; next;
    }
    $prev = undef if $type eq 'w';
    push @cur, $i if $type eq 'w';
  }
  push @stages, [@cur];
  return undef if grep { !@$_ } @stages;
  my ($first, @sinks) = @stages;
  my $cmd = $tok[$first->[0]][1];
  return undef unless $cmd =~ /^(?:[ef]?grep|rg)$/ || ($cmd eq 'git' && @$first > 1 && $tok[$first->[1]][1] eq 'grep');
  for my $st (@sinks) {
    my ($name, @args) = map { $tok[$_][1] } @$st;
    my $ok = $sink_words{$name} or return undef;
    for my $a (@args) { return undef unless plain_word($a) && $a =~ $ok }
  }
  return search_patterns($s);
}

sub gate_text {
  my $t = shift;
  return $t if $t =~ /\r/;
  (my $s = $t) =~ s/\n+\z//;
  for my $shape (\&gate_note, \&gate_commits, \&gate_search) {
    my $r = $shape->($s);
    return $r if defined $r;
  }
  return $t;
}

if ($mode eq 'gate') { $t = gate_text($t) }
if ($mode eq 'cmd') {
  $t = search_patterns(heredocs($t));
  $t =~ s/(?<![\w-])printenv((?:[ \t]+(?:$n))+)(?=[ \t]*(?:$|[;&|>)\n]))/:/g if length $n;
}
if (length $n) {
  # Only whole reads: the accessor, the safe name, and the closing bracket, with at most a plain
  # literal as the default. Anything more stays visible.
  my $acc = qr/(?:process\.env|import\.meta\.env|Deno\.env|Bun\.env|os\.environ|ENV)/;
  my $lit = qr/(?:"[^"\\\$`]*"|'[^'\\]*'|-?[0-9][0-9.]*|None|nil|null|undefined|true|false)/;
  $t =~ s/$acc\.(?:$n)(?![\w(\[])/SAFE_ENV/g;
  $t =~ s/$acc\s*\[\s*(["'])(?:$n)\1\s*\]/SAFE_ENV/g;
  $t =~ s/$acc\.(?:get|fetch)\s*\(\s*(["'])(?:$n)\1\s*(?:,\s*$lit\s*)?\)/SAFE_ENV/g;
  $t =~ s/(?:os\.getenv|os\.Getenv|os\.LookupEnv|std::env::var|env::var|System\.getenv|getenv)\s*\(\s*(["'])(?:$n)\1\s*(?:,\s*$lit\s*)?\)/SAFE_ENV/g;
}
print $t;
PL

# sy_list_match <root> <list> <path relative to root>: true if the path matches a glob in one of
# the project's lists (protected-paths, test-paths, ui-paths)
# the way the guards see it, and sets SY_MATCHED to the glob. A proposal in the pending folder is
# checked as the file it would replace, but protected-paths never covers it.
sy_list_match() {
  local rel="$3"
  SY_MATCHED=""
  case "$rel" in
    "$SY_DIR_NAME/pending/"*) [ "$2" = protected-paths ] && return 1; rel="${rel#"$SY_DIR_NAME/pending/"}" ;;
  esac
  sy_in_list "$1/$SY_DIR_NAME/$2" "$rel"
}

# sy_json_field <json> <dotted.path>: a value from hook input, with a python fallback when jq is missing
sy_json_field() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$1" | jq -r ".$2 // empty" 2>/dev/null || true
  else
    printf '%s' "$1" | python3 -c 'import json,sys
try: v = json.load(sys.stdin)
except Exception: sys.exit(0)
for p in sys.argv[1].split("."):
    v = v.get(p) if isinstance(v, dict) else None
sys.stdout.write("" if v is None else str(v))' "$2" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------- hook protocol (Claude Code & Antigravity)
# Claude Code sends snake_case fields (tool_name, tool_input.*) and reads hookSpecificOutput.
# Antigravity sends camelCase protojson (toolCall.name, toolCall.args.*, workspacePaths) and reads
# top-level decision/reason (PreToolUse) or injectSteps (SessionStart). Empty pass-through is ""
# for both harnesses (never "decision":"allow", which would bypass prompts, and never "{}" on
# PreToolUse, which Antigravity parses as an empty decision and denies).

# sy_hook_harness <json>: "antigravity" or "claude"
sy_hook_harness() {
  local h=""
  if [ -n "$1" ]; then
    if command -v jq >/dev/null 2>&1; then
      h="$(printf '%s' "$1" | jq -r 'if (type == "object") and (has("toolCall") or has("hookEventName") or has("workspacePaths") or has("conversationId")) then "antigravity" else "" end' 2>/dev/null || true)"
    else
      h="$(printf '%s' "$1" | python3 -c 'import json,sys
try: v = json.load(sys.stdin)
except Exception: v = None
if isinstance(v, dict) and any(k in v for k in ("toolCall", "hookEventName", "workspacePaths", "conversationId")):
    sys.stdout.write("antigravity")' 2>/dev/null || true)"
    fi
  fi
  if [ -z "$h" ] && [ -n "${PLUGIN_ROOT:-}" ] && [ -z "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    h="antigravity"
  fi
  printf '%s\n' "${h:-claude}"
}

# sy_hook_cwd <json>: workspace directory from hook stdin, falling back to CLAUDE_PROJECT_DIR or PWD
sy_hook_cwd() {
  local d=""
  if [ -n "$1" ]; then
    if command -v jq >/dev/null 2>&1; then
      d="$(printf '%s' "$1" | jq -r '(.cwd // .workspacePaths[0]) // empty' 2>/dev/null || true)"
    else
      d="$(printf '%s' "$1" | python3 -c 'import json,sys
try: v = json.load(sys.stdin)
except Exception: v = {}
if isinstance(v, dict):
    ws = v.get("workspacePaths")
    d = v.get("cwd") or (ws[0] if isinstance(ws, list) and ws else "")
    sys.stdout.write("" if d is None else str(d))' 2>/dev/null || true)"
    fi
  fi
  [ -n "$d" ] || d="${CLAUDE_PROJECT_DIR:-$PWD}"
  printf '%s\n' "$d"
}

# sy_hook_tool <json>: tool name from Claude Code or Antigravity PreToolUse input
sy_hook_tool() {
  local v
  v="$(sy_json_field "$1" tool_name)"
  [ -n "$v" ] || v="$(sy_json_field "$1" toolCall.name)"
  printf '%s\n' "$v"
}

# sy_hook_command <json>: shell command from Bash (Claude Code) or run_command (Antigravity)
sy_hook_command() {
  local v
  v="$(sy_json_field "$1" tool_input.command)"
  [ -n "$v" ] || v="$(sy_json_field "$1" toolCall.args.CommandLine)"
  printf '%s\n' "$v"
}

# sy_hook_file_path <json>: target file path from file tools in Claude Code or Antigravity
sy_hook_file_path() {
  local v k
  for k in tool_input.file_path tool_input.notebook_path toolCall.args.Path toolCall.args.TargetFile toolCall.args.AbsolutePath toolCall.args.NotebookPath; do
    v="$(sy_json_field "$1" "$k")"
    if [ -n "$v" ]; then printf '%s\n' "$v"; return 0; fi
  done
  return 0
}

# sy_hook_agent_type <json>: subagent type when provided by the harness
sy_hook_agent_type() {
  local v
  v="$(sy_json_field "$1" agent_type)"
  [ -n "$v" ] || v="$(sy_json_field "$1" agentType)"
  printf '%s\n' "$v"
}

# sy_hook_has_agent_type <json>: true if agent_type or agentType is present (non-null) in input
sy_hook_has_agent_type() {
  local ok=""
  if command -v jq >/dev/null 2>&1; then
    ok="$(printf '%s' "$1" | jq -r 'if (type == "object") and ((.agent_type != null) or (.agentType != null)) then "1" else "" end' 2>/dev/null || true)"
  else
    ok="$(printf '%s' "$1" | python3 -c 'import json,sys
try: v = json.load(sys.stdin)
except Exception: v = None
if isinstance(v, dict) and (v.get("agent_type") is not None or v.get("agentType") is not None):
    sys.stdout.write("1")' 2>/dev/null || true)"
  fi
  [ "$ok" = "1" ]
}

# sy_hook_noop <harness>: pass-through output (no opinion; leaves normal permission prompts intact)
sy_hook_noop() {
  return 0
}

# sy_hook_pretool_reply <harness> <decision> <reason>: PreToolUse deny or ask output
sy_hook_pretool_reply() {
  local harness="$1" decision="$2" reason="$3"
  if [ "$harness" = "antigravity" ]; then
    if command -v jq >/dev/null 2>&1; then
      jq -n --arg d "$decision" --arg r "$reason" '{decision: $d, reason: $r}'
    else
      python3 -c 'import json,sys; print(json.dumps({"decision": sys.argv[1], "reason": sys.argv[2]}))' "$decision" "$reason"
    fi
  else
    if command -v jq >/dev/null 2>&1; then
      jq -n --arg d "$decision" --arg r "$reason" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r}}'
    else
      python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": sys.argv[1], "permissionDecisionReason": sys.argv[2]}}))' "$decision" "$reason"
    fi
  fi
}

# sy_hook_session_start_reply <harness> <user_msg> <model_ctx>: SessionStart output
sy_hook_session_start_reply() {
  local harness="$1" msg="$2" ctx="$3"
  if [ "$harness" = "antigravity" ]; then
    if command -v jq >/dev/null 2>&1; then
      jq -n --arg m "$msg" --arg c "$ctx" '{injectSteps: [{systemMessage: {systemMessage: $c, metadata: {user_markdown: $m}}}]}'
    else
      python3 -c 'import json,sys; print(json.dumps({"injectSteps": [{"systemMessage": {"systemMessage": sys.argv[2], "metadata": {"user_markdown": sys.argv[1]}}}]}))' "$msg" "$ctx"
    fi
  else
    if command -v jq >/dev/null 2>&1; then
      jq -n --arg m "$msg" --arg c "$ctx" '{systemMessage: $m, hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'
    else
      python3 -c 'import json,sys; print(json.dumps({"systemMessage": sys.argv[1], "hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": sys.argv[2]}}))' "$msg" "$ctx"
    fi
  fi
}

# ---------------------------------------------------------------- verify tiers
# A project's checks run in tiers, each at the moment its result is needed (see shipinetics-verify):
#   quick     after each step: checks scoped to the changed files (verify_quick_cmd)
#   complete  the "done" gate, push and PR: every fast check (verify_cmd, default bin/verify)
# Nothing is skipped. A tier's command just runs later or earlier. Without verify_quick_cmd,
# the quick tier runs the complete command. A pass is recorded against a fingerprint of the
# code's contents, so committing verified code, or editing only worksheets, evidence and the
# feedback log, doesn't re-run anything. A complete pass also counts as a quick pass.

# sy_key_suffix <package or empty>: cache-file suffix, "" for the single repo
sy_key_suffix() { if [ -n "$1" ]; then printf -- '-%s' "${1//\//_}"; fi; }

# sy_verify_excludes <root> <package or empty>: pathspecs that aren't code as far as verify goes
sy_verify_excludes() {
  local pkg_ws
  printf '%s\n' ":(exclude)$SY_DIR_NAME/.cache" ":(exclude)$(sy_cfg "$1" evidence_dir)"
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
  local cache sfx l excl=()
  cache="$(sy_dir "$1")/.cache"
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
    >>"$(sy_dir "$1")/.cache/verify-times.tsv"
}

# sy_verify_run <root> <package or empty> <quick|complete> <changed-files list or ""> <source>
# Runs the tier's command, unless a pass is already recorded for exactly this code. The command
# runs from the root with SHIPINETICS_VERIFY_TIER set, and SHIPINETICS_CHANGED_FILES naming a file
# that lists the changed paths (relative to the repo being verified; unset means check everything).
# Records the pass, logs the timing, and returns the command's status. Afterwards SY_VERIFY_TIER
# is the tier that ran, SY_VERIFY_FP the fingerprint, SY_VERIFY_LOG the output, and SY_VERIFY_RAN
# is 1 if the command ran (0 if a recorded pass was reused).
sy_verify_run() {
  local root="$1" pkg="$2" tier="$3" list="$4" src="$5" cache sfx cmd t0 rc
  cache="$(sy_dir "$root")/.cache"; mkdir -p "$cache"
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
