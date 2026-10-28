# Coding conventions
> Summary: Project-specific coding rules that reviewers check and linters increasingly enforce. Generic best practice doesn't belong here, only choices this codebase has made.
> Owns: every source file
> Entry points: this file; lint config at {{LINT_CONFIG_PATH}}
> Depends on: docs/systems/*.md for system-specific rules
> Gotchas: a rule marked "enforced: review" is a candidate for a lint rule. Move it when you can (shipinetics:lint-rule).
> Owner persona: code-quality, ai-smells | Last verified: {{YYYY-MM-DD}} at {{short commit}}

<!-- Write this file in ASD-STE100 (Simplified Technical English): short sentences, active voice, one word for one thing. Where it describes structure or flow, add a Mermaid diagram and a link to its Whiteboard. Rules: shipinetics:explain. -->

Each convention has an ID so reviews can cite it. Keep entries short. If a rule needs a paragraph of explanation, it probably belongs in a system doc.

Format:

```
### C-001: <rule in one line>
Why: <one line>
Do: <tiny example>
Don't: <tiny example>
Enforced: lint <rule-name> | review
```

## Conventions

### C-001: Tests are written by shipinetics:test-writer, not the implementer
Why: tests written by the author share the author's blind spots.
Enforced: hook (guard-edits)

### C-002: {{rule}}
Why: {{reason}}
Do: `{{good}}`
Don't: `{{bad}}`
Enforced: review
