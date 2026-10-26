# Coding conventions
> Summary: Project-specific coding rules that reviewers check and linters increasingly enforce. Generic best practice doesn't belong here, only choices this codebase has made.
> Owns: every source file
> Entry points: this file; lint config at {{LINT_CONFIG_PATH}}
> Depends on: docs/systems/*.md for system-specific rules
> Gotchas: a rule marked "enforced: review" is a candidate for a lint rule. Move it when you can (shipinetics:lint-rule).
> Owner persona: code-quality, ai-smells | Last verified: {{YYYY-MM-DD}} at {{short commit}}

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

### C-001: Only the config module reads the environment
Why: secrets come from Secret Manager as environment variables. One module validates them, fails fast when one is missing, and keeps values out of logs.
Do: `import { config } from '{{CONFIG_MODULE_IMPORT}}'; config.stripeKey`
Don't: `process.env.STRIPE_KEY` anywhere else
Enforced: hook (guard-edits) and lint {{e.g. n/no-process-env with an override for the config module}}

### C-002: Tests are written by shipinetics:test-writer, not the implementer
Why: tests written by the author share the author's blind spots.
Enforced: hook (guard-edits)

### C-003: {{rule}}
Why: {{reason}}
Do: `{{good}}`
Don't: `{{bad}}`
Enforced: review
