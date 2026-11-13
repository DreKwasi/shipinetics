# Test index
> Summary: Every behaviour the tests prove, grouped by system and module, with the test that proves it. Read it before writing a test: if the behaviour is here, extend that test. It also shows the gaps.
> Owns: this list only. The tests themselves are documented in how-to-write-tests.md
> Entry points: grep this file for a system or behaviour name
> Depends on: docs/systems/*.md for system names
> Gotchas: an entry here does not prove that the test works. The false-confidence audit (shipinetics:test-audit) checks that
> Owner persona: test-integrity | Last verified: {{YYYY-MM-DD}} at {{short commit}}

<!-- Write this file in ASD-STE100 (Simplified Technical English): short sentences, active voice, one word for one thing. Where it describes structure or flow, add a Mermaid diagram and a link to its Whiteboard. Write the diagram's labels by the same rules. Rules: shipinetics:explain. -->

One row per behaviour, as a sentence a user or caller would recognise, never a function name. Criterion is the acceptance criterion that the test proves (`refund-rounding AC2`): `rg` finds the tests of a criterion by it. Kind is unit, e2e, acceptance, visual or bench. A behaviour appears once, because it is tested at one layer. When a behaviour is removed, remove its row in the same change.

## {{System name}}

| Behaviour | Criterion | Test (file, group) | Kind | Audited |
|---|---|---|---|---|
| {{e.g. "ties go to whoever reached the total first"}} | {{e.g. league-close AC2}} | `{{path}}`, {{group}} | unit | {{YYYY-MM-DD or never}} |
