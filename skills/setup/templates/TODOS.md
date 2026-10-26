# Task queue

Agents pick from **Ready**, top first. See the shipinetics:task-queue skill for the rules.

Task format:

```
- [ ] T-001 Short title | size: S | priority: P1
  Acceptance: <runnable criteria, one per line or ; separated>
  Context: <links to docs, issues, worksheets>
  Worksheet: <name, once claimed>
```

Sizes: **S** under an hour, one area. **M** a few hours or a couple of systems. **L** needs splitting before an agent picks it up.

## Ready

- [ ] T-001 {{First task}} | size: S | priority: P1
  Acceptance: {{criteria}}
  Context: {{links}}

## In progress

## Blocked

## Done
