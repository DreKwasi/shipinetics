# Spec: write the docs before `/compact`

Status: approved on 2026-11-22 (settled in conversation: document before compaction, tied to the `/compact` command for now). Terms: [GLOSSARY.md](../../GLOSSARY.md).

## Problem

Compaction replaces the conversation with a summary. Terms, decisions and changes that the session settled but didn't write down are then lost: the glossary, the ADRs, the system docs and the worksheet miss them.

## Acceptance criteria

- **AC1.** Given a set-up project where the docs checkpoint was not recorded at the current code, when the person runs `/compact`, then the PreCompact hook stops the compaction (exit 2), and its message tells the person to run `/shipinetics:checkpoint`, then `/compact` again, and that a second `/compact` skips the docs.
- **AC2.** Given that the hook stopped a `/compact`, when the person runs `/compact` again within 10 minutes, then the compaction runs, whatever changed in between (a log file or a watcher can change files). After 10 minutes, the hook stops it again. If the hook can't record the stop, the compaction runs.
- **AC3.** Given that `shipinetics-checkpoint record` ran at the current code, when the person runs `/compact`, then the compaction runs.
- **AC4.** Whenever the hook lets a compaction run in a set-up project, its output (the instructions for the summary) asks the summary to keep the current worksheet's name, the acceptance criteria that are done and open, the decisions and terms not yet written down, and the next step.
- **AC5.** The hook does nothing (exit 0, no output) for automatic compaction, outside a set-up project, and when `compact` is in `hooks_off` or `SHIPINETICS_HOOKS_OFF`.
- **AC6.** `shipinetics-checkpoint check` exits 0 when the recorded checkpoint matches the current code, and 1 when it doesn't or none was recorded. Editing only the worksheet or the feedback log keeps the checkpoint, as it keeps a verify pass.
- **AC7.** The `/shipinetics:checkpoint` skill writes, for what the session decided or changed: new and sharpened terms in `GLOSSARY.md`, ADRs for decisions that pass the three tests, the system docs that changed, and the worksheet. Then it runs `shipinetics-checkpoint record` and tells the person to run `/compact`.

## Out of scope

Automatic compaction (it isn't blocked: a blocked automatic compaction can fail the current request). Harnesses other than Claude Code (Codex also has PreCompact; its adapter adds it).

## Approach

A PreCompact hook with the matcher `manual` (`scripts/compact-checkpoint.sh`), a tool that records and checks the checkpoint (`bin/shipinetics-checkpoint`), and a skill (`skills/checkpoint`). The checkpoint is the code fingerprint that verify uses, so the same files count as code. Test seams: the hook script with recorded PreCompact input, and the tool's exit codes.

Sources (checked 2026-11-22): https://code.claude.com/docs/en/hooks, sections PreCompact and PostCompact. PreCompact gets `trigger` and `custom_instructions`. Exit 2 blocks, and for a manual `/compact` the person sees the message. On exit 0, stdout becomes instructions for the summary (up to 10,000 characters).
