---
name: perf
description: Performance benchmarks that catch regressions automatically, plus profiling and an experiment protocol for trying optimizations and comparing results. Use when adding benchmarks, when a benchmark regresses, when something feels slow, when trying an optimization, or when the user asks about performance.
---

# Performance: benchmarks and profiling

> Paths below are Shipinetics's defaults. A project can map them elsewhere in `.shipinetics/config`: run `shipinetics-config` to see this project's actual paths and commands, and use those.

Two jobs. **Benchmarks** run automatically and fail when a key path gets slower. **Profiling** is how you find out why, and how you prove an optimization worked.

## Benchmarks (catching regressions)

### Setting up

1. **Pick 3 to 6 scenarios that matter to users:** page load or time to interactive for the main screen, the most-called API endpoint, the heaviest computation, startup time, build time if it hurts. Each scenario gets a name.
2. **Pick the tool for the stack:**

   | Stack | Tool |
   |---|---|
   | JS/TS functions | `vitest bench` or `tinybench` |
   | Web page load | Playwright with the Performance API, or Lighthouse CI |
   | HTTP API | `k6` or `autocannon` |
   | Python | `pytest-benchmark` |
   | Rust | `criterion` |
   | Go | `go test -bench` with `benchstat` |
   | CLI commands | `hyperfine` |

3. **Store baselines** in `perf/baselines/<scenario>.json` with the median, the spread (p95 or stddev), the number of runs, the machine and the commit. `perf/baselines/*` is protected, so agents can't quietly reset them.
4. **Build the comparison** as a project script, `bin/bench` (shipinetics:build-tool). It runs every scenario N times (at least 5, after a warmup), compares the median to the baseline, and fails if any scenario is slower by more than the threshold. Start with 10% and tune it for noise. Its output says which scenario, baseline vs now, and by how much.
5. Add `bin/bench` to `bin/verify --full`.

### Noise

Benchmarks on laptops and shared CI runners are noisy. Use medians, never single runs. Run the baseline and the current code on the same machine in the same session when you can (check out the base commit in a worktree). If a scenario's spread is bigger than the threshold, it can't detect regressions: make it more stable or raise its threshold, and say so.

### When a benchmark regresses

1. Re-run it to rule out noise.
2. If it's real, find the cause: `git bisect run bin/bench <scenario>` over the commits since the baseline.
3. Fix it, or if the slowdown is an accepted cost of a feature, write that up in the worksheet under "Test change requests", with the new baseline at `.shipinetics/pending/<baseline path>`. A human applies it with `shipinetics-config apply`.

## Profiling (finding out why)

| Stack | Tools |
|---|---|
| Node | `node --cpu-prof` then open in Chrome DevTools; `clinic flame`; `--heap-prof` for memory |
| Browser | Playwright `page.context().tracing` or a Chrome performance trace; Lighthouse for page loads |
| Python | `py-spy record -o profile.svg -- <cmd>`; `cProfile` with `snakeviz`; `memray` for memory |
| Go | `pprof` (`go test -cpuprofile`, `go tool pprof -http`) |
| Rust | `cargo flamegraph`, `samply` |
| macOS native | Instruments via `xcrun xctrace` |
| SQL | `EXPLAIN ANALYZE` on the actual queries, with production-like data volume |

Save profiles under `perf/profiles/` (gitignored unless small) with the commit and scenario in the file name, so you can compare before and after.

## The experiment protocol (trying an optimization)

Every optimization attempt follows this, and gets a line in `docs/perf/experiments.md`, including the ones that didn't work. Failed experiments are as valuable as wins: they stop the next agent from trying the same thing.

1. **Hypothesis:** "Rendering the list is slow because each row re-computes the formatted date. Memoizing should cut list render time by over 30%."
2. **Baseline:** run the scenario at least 5 times on the current code. Record the median and spread. Profile it.
3. **Change one thing.**
4. **Measure** the same way, same machine, same session.
5. **Compare** medians and profiles. Is the difference bigger than the noise? Did the hot spot in the profile actually shrink?
6. **Check correctness:** `bin/verify` still passes, and outputs are identical where they should be (diff the output, not just the timing).
7. **Keep or revert.** Keep only if it's a clear win and doesn't make the code much worse. Otherwise revert.
8. **Record** in `docs/perf/experiments.md`:

```
## YYYY-MM-DD <scenario>: <one-line hypothesis>
Result: kept | reverted. Before: <median ± spread>. After: <median ± spread>. Runs: N. Commit: <sha or none>
Notes: <what the profile showed, why it did or didn't work>
```
