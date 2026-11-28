# scripts/compat.sh on a simulated Windows (OSTYPE=msys in a subshell): which Python it picks, the
# cache of that answer, and the python3 function it defines. Fake Pythons on a scratch PATH log each
# run, so the test sees what compat.sh ran. On a real Windows this runs the same way.
. "$(dirname "$0")/helpers.sh"

fake="$scratch/fake"; calls="$scratch/calls"; xdg_cache="$scratch/cache"
mkdir -p "$fake/WindowsApps" "$fake/bin"
# A Microsoft Store stub named python3 that would pass the version check if it ran: compat.sh must
# skip it by its path, without running it.
printf '#!/bin/sh\necho "stub $*" >>"%s"\nexit 0\n' "$calls" >"$fake/WindowsApps/python3"
# A real-looking Python 3 named python: the version check (-c) passes; any other run prints a line
# that ends in CRLF, as Windows Python does.
printf '#!/bin/sh\necho "python $*" >>"%s"\ncase "$1" in -c) exit 0 ;; esac\nprintf '"'"'out\\r\\n'"'"'\n' "$calls" >"$fake/bin/python"
chmod +x "$fake/WindowsApps/python3" "$fake/bin/python"
# The system tools after the fakes; in front of them, so a real python3 there never answers first.
fpath="$fake/WindowsApps:$fake/bin:$(dirname "$(command -v head)"):/usr/bin:/bin"

# simulate <commands>: in a subshell, as Git Bash on Windows, with no python3 or jq function and no
# SY_PYTHON from this shell: source compat.sh, then run the commands
simulate() {
  ( unset -f python3 jq; unset SY_PYTHON
    OSTYPE=msys; PATH="$fpath"; XDG_CACHE_HOME="$xdg_cache"
    . "$SY/scripts/compat.sh"
    eval "$1" )
}

: >"$calls"
first="$(simulate 'printf "%s|" "${SY_PYTHON:-none}"; python3 hello')"
eq "compat on Windows: a python3 in WindowsApps is skipped and python is picked" "${first%%|*}" python
eq "compat on Windows: the WindowsApps stub never runs" "$(grep -c '^stub' "$calls" || true)" 0
eq "compat on Windows: the python3 function drops the \\r of Windows Python's output" "${first#*|}" out
has "compat on Windows: the python3 function runs Python in UTF-8 mode, unbuffered" "$(grep -v ' -c ' "$calls")" "python -X utf8 -u hello"
eq "compat on Windows: the Python it found is cached" "$(cat "$xdg_cache/shipinetics/python" 2>/dev/null)" python

: >"$calls"
second="$(simulate 'printf "%s" "${SY_PYTHON:-none}"')"
eq "compat on Windows: a second source takes the Python from the cache, and runs none to find it" "$second/$(wc -l <"$calls" | tr -d ' ')" python/0

# a cached answer whose command is gone is found again
printf 'py -3\n' >"$xdg_cache/shipinetics/python"; : >"$calls"
eq "compat on Windows: a cached Python that no longer exists is found again, and the cache updated" "$(simulate 'printf "%s" "${SY_PYTHON:-none}"')/$(cat "$xdg_cache/shipinetics/python")" python/python

# off Windows compat.sh changes nothing
eq "compat off Windows: no python3 function" "$( (unset -f python3 jq; OSTYPE=darwin; . "$SY/scripts/compat.sh"; declare -F python3 || echo none) )" none

done_testing
