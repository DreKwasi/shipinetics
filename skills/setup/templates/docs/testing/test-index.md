# Test index
> Summary: Every test file in the repo and the behavior it proves, grouped by system. Use it to find the test for a behavior before writing a new one, and to spot gaps.
> Owns: this list only. The tests themselves are documented in how-to-write-tests.md
> Entry points: grep this file for a system or behavior name
> Depends on: docs/systems/*.md for system names
> Gotchas: an entry here doesn't prove the test works. The false-confidence audit (shipyard:test-audit) checks that
> Owner persona: test-integrity | Last verified: {{YYYY-MM-DD}} at {{short commit}}

Format: `path` | kind (unit, e2e, acceptance, visual, bench) | what it proves | last audited

## {{System name}}

| Test | Kind | Proves | Audited |
|---|---|---|---|
| `{{path}}` | e2e | {{one line}} | {{YYYY-MM-DD or never}} |
