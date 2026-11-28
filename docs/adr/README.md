# Decision records

Each file records one decision about Shipinetics. A decision gets a record when it passes three tests:

- It is hard to reverse.
- It can surprise a new reader.
- It came from a real trade-off.

The terms are in [GLOSSARY.md](../../GLOSSARY.md). Give new records the next number. Keep each record to a few sentences: what the decision is, and why.

| # | Decision |
|---|---|
| [0001](0001-generated-copies-per-harness.md) | Each harness gets generated copies of the skills and subagents |
| [0002](0002-push-is-the-hard-verify-gate.md) | The push is the hard verify gate, and the check after a commit only reports |
| [0003](0003-only-test-writer-writes-tests.md) | Only test-writer writes tests, and a guard enforces it |
| [0004](0004-protected-files-change-through-a-person.md) | Protected files change only through a person at a terminal |
| [0005](0005-evidence-is-the-users-choice.md) | The user decides about evidence for each task |
| [0006](0006-local-clone-on-every-harness.md) | One installer from a clone for each harness. Claude Code can also install from GitHub |
| [0007](0007-models-by-role.md) | Subagents name a model role, not a model |
