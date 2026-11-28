---
name: checkpoint
description: Write down what this session settled before the context is compacted or the session ends - new and sharpened terms in GLOSSARY.md, ADRs for hard-to-reverse decisions, the system docs that changed, and the worksheet - then record the docs checkpoint so /compact can run. Use when the user runs /shipinetics:checkpoint, when the PreCompact hook stopped /compact, before a long break, or when the context is getting full.
---

# Checkpoint: write it down before it's summarized

> Paths below are Shipinetics's defaults. A project can map them elsewhere in `.shipinetics/config`: run `shipinetics-config` to see this project's actual paths and commands, and use those.
>
> Text for people (docs, worksheets, reports, PR descriptions, commit messages, review comments, replies, and each label on a board, diagram or table): write it in ASD-STE100, by the plain-language guide (`${CLAUDE_PLUGIN_ROOT}/skills/explain/plain-language.md`). Where the text describes structure or flow (a call path, a data flow, states or steps), show it on a Whiteboard. In a committed file, also put a Mermaid diagram and a link to the Whiteboard, because GitHub and other people cannot open your Whiteboard. Without Whiteboard, use Mermaid only. shipinetics:explain has the rules.

Compaction replaces the conversation with a summary, and a summary keeps less than the docs do. Before it happens, write each thing that this session settled into the place where the next agent looks for it. The PreCompact hook stops `/compact` until this is done for the current code (a second `/compact` within 10 minutes skips it).

## Steps

1. **List what the session settled.** Read back through the conversation, the worksheet, and `git diff` plus `git log` for this session's work. Make a short list: terms that were defined or sharpened, decisions and their reasons, behaviour that changed, and the next step. Only what was really settled: an idea that was discussed and dropped is not a decision.
2. **Terms: `GLOSSARY.md`.** For each term that the session defined or sharpened, add or change its entry in the glossary format (shipinetics:system-docs, "Where decisions and terms go"): the term, one or two sentences on what it is, and the words to avoid. No implementation details. If the `domain-modeling` skill is installed, follow its format. If `GLOSSARY.md` doesn't exist and there is a term to write, create it.
3. **Decisions: `docs/adr/`.** Write an ADR only for a decision that is hard to reverse, surprising without context, and the result of a real trade-off. Take the next free number (`docs/adr/NNNN-<slug>.md`), write one to three sentences (what was decided and why), and add it to the index in `docs/adr/README.md` if there is one. A decision that fails a test goes in the worksheet's Decisions instead. If the session went against an existing ADR, update that ADR's status, or say in the worksheet why it still holds.
4. **Systems: the system docs.** For each system whose behaviour changed, update its doc and its 7-line header (shipinetics:system-docs). Fix what is now wrong, add what is new, and link any new ADR.
5. **The task: the worksheet.** Update the log, the Decisions, the acceptance criteria that are done, and the exact next step (shipinetics:worksheet). If something went wrong or slowed the work down, add it to the feedback log (shipinetics:feedback).
6. **Check yourself.** Read each new glossary entry, ADR and header alone, as a person who hasn't seen the conversation. Each must make sense without it. Don't write anything that the session didn't settle: list the open points in the worksheet instead.
7. **Record the checkpoint.** Run `shipinetics-checkpoint record`. It records the code as it is now. If you change code after this, run it again.
8. **Tell the person, in a few lines:** what you wrote and where, what you left out on purpose, and that `/compact` can run now.

Don't commit unless the task's own work is ready to commit: the docs then go with it, under the same worksheet trailer.
