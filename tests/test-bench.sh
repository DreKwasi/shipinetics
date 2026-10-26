# bench-compare: per-machine baselines, regressions, noise, budgets, and protected re-baselining.
. "$(dirname "$0")/helpers.sh"
p="$scratch/bench"; new_repo "$p"; cd "$p" || exit 1
mkdir -p .shipinetics; echo x >a; git add -A; git commit -qm init
# fake bench: each run prints the next line of vals (cycling), as "<scenario> <ms>" pairs
cat >bench.sh <<'B'
#!/bin/sh
n=$(cat count 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" >count
total=$(wc -l <vals); line=$(( (n - 1) % total + 1 ))
sed -n "${line}p" vals | tr ',' '\n'
B
chmod +x bench.sh
bc() { rm -f count; OUT="$(bench-compare --machine m1 "$@" -- ./bench.sh 2>&1)"; RC=$?; }

printf 'load 100,api 50\n' >vals
bc; eq "no baseline and no budgets: nothing to compare" "$RC" 2
has "and it says how to record one" "$OUT" "--init"
bc --init; eq "init records the baseline" "$RC:$(grep -c '' perf/baselines/m1.tsv)" "0:6"
bc; eq "same timings pass" "$RC" 0
printf 'load 130,api 50\n' >vals
bc; eq "30% slower fails" "$RC" 1
has "and names the scenario" "$OUT" "SLOWER"
printf 'load 60,api 50\nload 140,api 50\n' >vals
bc --runs 6; eq "a noisy scenario can't pass or fail" "$RC" 3
printf 'load 100,api 50\n' >vals; printf 'api 40\n' >perf/baselines/budgets.tsv
bc; eq "over budget fails" "$RC" 1
has "and says so" "$OUT" "OVER BUDGET"
rm perf/baselines/budgets.tsv
printf 'load 80,api 50\n' >vals
bc --init; has "re-baselining goes to pending" "$OUT" ".shipinetics/pending/perf/baselines/m1.tsv"
eq "and leaves the baseline alone" "$(grep '^load' perf/baselines/m1.tsv | cut -f2)" "100.000"
rm -f count; OUT="$(bench-compare --machine m2 -- ./bench.sh 2>&1)"
eq "another machine needs its own baseline" "$?" 2
done_testing
