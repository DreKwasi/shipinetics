# Subagents name a model role, not a model

Status: accepted, not built yet. Today `agents/*.md` still name Claude models (`opus`, `sonnet`).

Each subagent asks for a model role (deep review, build or quick checks), and a model catalog for each harness lists the models that can fill each role. The person picks a model for each role, or Shipinetics picks from their plan. We chose this because each harness offers different models, new models arrive every few weeks, and people on smaller plans can't afford the largest model for every job. A smaller model is the person's choice, shown with what it costs in review depth, never a silent downgrade.
