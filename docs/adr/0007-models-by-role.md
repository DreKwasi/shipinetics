# Subagents name a model role, not a model

Status: accepted, not built yet. Today `agents/*.md` still name Claude models (`opus`, `sonnet`).

Each subagent asks for a model role: deep review, build or quick checks. For each harness, a model catalog lists the models that can fill each role. The person picks a model for each role, or Shipinetics picks one from their plan.

We chose this for three reasons:

- Each harness offers different models.
- New models arrive every few weeks.
- People on smaller plans can't pay for the largest model for every job.

A smaller model is the choice of the person. Shipinetics shows what that model costs in review depth. Shipinetics never changes to a smaller model without telling the person.
