# Test index
> Summary: Every behaviour the tests prove, grouped by system and module, with the test that proves it. Read it before writing a test: if the behaviour is here, extend that test. It also shows the gaps.
> Owns: this list only. The tests themselves are documented in how-to-write-tests.md
> Entry points: grep this file for a system or behavior name
> Depends on: docs/systems/*.md for system names
> Gotchas: an entry here doesn't prove the test works. The false-confidence audit (shipinetics:test-audit) checks that
> Owner persona: test-integrity | Last verified: {{YYYY-MM-DD}} at {{short commit}}

One row per behaviour, as a sentence a user or caller would recognise, never a function name. Kind is unit, e2e, acceptance, visual or bench. A behaviour appears once: it's tested at one layer.

## {{System name}}

| Behaviour | Test (file, group) | Kind | Audited |
|---|---|---|---|
| {{e.g. "ties go to whoever reached the total first"}} | `{{path}}`, {{group}} | unit | {{YYYY-MM-DD or never}} |
