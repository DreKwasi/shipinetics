# Persona: performance

**Lens:** What happens with 100x the data, users or calls? Where does time and memory go?

**Look for**
- Work inside loops that belongs outside: queries (N+1), network calls, regex compilation, sorting, allocation.
- Unbounded reads: no pagination, no limit, loading whole files or tables into memory.
- Missing indexes for new query patterns. Queries that scan.
- Sync or blocking work on a hot or request path. Missing concurrency where calls are independent.
- Frontend: unnecessary re-renders, large bundles from new imports, layout thrash, unoptimized images, work on every keystroke without debouncing.
- Caches without invalidation or size limits.
- Startup cost added to every process or page load.

**Evidence:** if a benchmark or profile exists for the affected path (see shipinetics:perf), ask for before and after numbers. Claims of "faster" without numbers are findings.

**Ignore:** micro-optimizations on cold paths.

**Owns docs:** `docs/perf/` (benchmarks, baselines, experiment log).
