---
name: explain
description: Present work, findings and systems to the human in the form that's fastest to understand, in ASD-STE100 (the default language for all text for people, labels on boards and diagrams too), from prose through diagrams, Whiteboards and interactive HTML pages to narrated explainer videos. Use when reporting what you did, summarizing a review, explaining how code or a change works, before writing a PR description or a commit message, or when the user asks to understand something.
argument-hint: "[topic] [prose|diagram|whiteboard|html|video]"
---

# Explain it so a human gets it fast

> Paths below are Shipinetics's defaults. A project can map them elsewhere in `.shipinetics/config`: run `shipinetics-config` to see this project's actual paths and commands, and use those.

As agents do more of the work, the human's job moves up to oversight and understanding. Your output is only useful if they can take it in quickly. Code and intelligence are cheap now, so it's fine to build a large, custom, throwaway artifact (a web page, a video) just to explain one thing.

Topic and format: `$ARGUMENTS`. If no format is given, pick one with the ladder below.

**Language.** Everything Shipinetics writes for a person uses ASD-STE100, as "Prose" and "Labels" below describe: docs and READMEs, system docs, reports, worksheets, PR descriptions, commit messages, review comments, evidence notes, Whiteboards, HTML pages, video scripts and replies in chat. That includes every label: the text on a diagram node or edge, a table cell, a title and a caption. Where that text describes structure or flow, show it on a Whiteboard. A committed file also gets a Mermaid diagram of it. Without Whiteboard, use Mermaid only ("Diagrams" below). Other skills point here for the rules.

## The ladder

Each step up costs more to make and is usually faster to understand. Pick the lowest step that does the job.

| Format | Use it for |
|---|---|
| **Prose (plain language, ASD-STE100)** | Final messages, worksheet summaries, review findings, anything a few paragraphs long |
| **Whiteboard** | Anything with structure or flow (call paths, data flow, state machines, architecture, before and after), a code change, how part of the codebase works, or a set of findings and numbered questions for the user (setup's audit and questions). The default visual when the Whiteboard tools (dev.fast) are available |
| **Mermaid diagram** | The same, in a committed file (with a link to the Whiteboard), and the only visual when Whiteboard is not installed |
| **HTML page** | Big changes, comparisons, anything the human will explore or click through |
| **Explainer video** | Concepts, onboarding to a system, algorithms. Only when the user asks or agrees |

## Prose: plain language (ASD-STE100)

ASD-STE100 (Simplified Technical English) is a controlled language for technical text that a person reads fast, under load, and did not write. Use it as a baseline, not as a compliance target. The goal is text that the reader parses correctly on the first pass.

The full guide, with its examples, is [plain-language.md](plain-language.md) (`${CLAUDE_SKILL_DIR}/plain-language.md`). It is written for PR descriptions, and its rules apply to all text for people. Read it before you write a PR description or a commit message. The rules:

- **Use the active voice, and name the actor.** "The parser rejects unknown keys", not "Unknown keys are rejected."
- **One topic per sentence.** A fact, its consequence and a caveat are two or three sentences.
- **Short sentences.** An instruction has 20 words or fewer. A description has about 25 words or fewer.
- **Simple tenses.** Simple past, simple present and simple future. Keep the present perfect only when it says something that the simple past can't. "The job has completed" says that the output is ready now. "The request may have failed" keeps a doubt.
- **Keep the articles and the connecting words:** "the", "a", "that", "which". Don't drop words to sound terse.
- **One term for each concept, in the whole text.** Don't switch between "tenant", "organization" and "account" for one concept. Don't use one word for two concepts. Use the terms in `GLOSSARY.md`. Also keep each word in one part of speech: "Apply oil to the valve", not "Oil the valve".
- **No more than three nouns in a stack.** Use prepositions: "the override for the retry backoff on the consumer".
- **A vertical list** when there is more than one condition or step. Write instructions as numbered steps, with one action each and the imperative verb first ("Run `bin/verify`.").
- **The specific verb.** "Validates", "retries", "rejects" and "caches" say what the code does. "Handles", "supports", "manages" and "processes" don't.
- **The verb, not a noun made from it.** "Analyze the log", not "Perform an analysis of the log". "The hook blocks the push", not "The hook provides blocking of the push". The noun form is longer, and it hides the actor.
- **One-word verbs, not phrasal verbs.** "Start the job", not "spin up the job". Also: "contact", not "reach out to". "Read", not "dive into". "Begin", not "kick off". A two-word verb has meanings that its parts don't predict.
- **No semicolons.** Make two sentences. An em dash that joins two ideas usually means the same thing: split the sentence.
- **Paragraphs of about six sentences** or fewer. Past that, split them or make a list.
- **State results, not intent.** Say what the code does now and what shows it: "`migrate down` drops the index. The integration test checks this." Not "Added tests to make sure the migration is safe."
- **Say what's true plainly.** No hedging on what you verified. Say exactly what you didn't verify.
- **Keep the strength of each claim when you rewrite.** A hedge ("may", "could", "is likely to") is part of the content. Don't shorten "The request may have failed" to "The request failed". Don't add a cause, a frequency or a mechanism that the source doesn't state. If a shorter sentence loses a condition, a scope or a number, keep the longer sentence.
- **Every factual claim in an explainer or report needs evidence you opened:** `file:line`, or a primary source URL with the date checked. Mark anything unverified as unverified. Don't let a polished page or video make a guess look like a fact.
- **Cut the words that add nothing,** unless they carry weight: comprehensive, robust, cleanly, properly, simply, just, basically, essentially, various, appropriate, in order to, it should be noted that, a number of. "Simply" and "just" tell the reader that something is easy. That is redundant or wrong. Also cut the adjectives that claim quality: seamless, powerful, cutting-edge, effortless, blazing-fast. Give the measurement instead, or delete the word.

**Text that agents and programs read.** Apply the rules above as hard rules, not as a baseline, to text that a model or a program reads with no person to resolve a doubt. That text includes skill text, agent and subagent prompts, tool descriptions, hook and error messages, and instructions from one agent to another. For this text, also use one word for one action everywhere. For example, always "check", never "check", "verify" and "confirm" for the same action.

**What is exempt.** Don't use STE's approved-word list. These names stay exactly as they are:

- Code identifiers, type names, field names and file paths: `FactoryConfig`, `logic/factories.go`.
- Command lines and their flags, word for word.
- Established repository and domain jargon (merge queue, feature flag, migration, presubmit, one-way door), and the terms in `GLOSSARY.md`.
- Product and service names.

Never paraphrase an identifier to satisfy a word rule. `nil` is `nil`, not "an empty value".

Shipinetics adds some rules to the guide: the 20-word limit for instructions, numbered steps, the terms in `GLOSSARY.md`, "various" and "appropriate" in the word list, the evidence for each claim, the rule against hedging and the hard rules for text that agents and programs read. They don't change the guide's rules.

When the user runs `/wait-what`, or says a message didn't land, re-pitch it with these rules: a little context first, then the point, in the terms from `GLOSSARY.md`.

## Labels: ASD-STE100 in short text

A label is short text on a board, a diagram or a table: a node, an edge, a sequence step, a table cell, a callout title, a section title or a caption. A label has little space, so agents break the rules most often in labels. Short text follows the same rules as prose:

- **A node is a short sentence, or a name with its article.** A state, a finding or a result is a sentence with a subject and a verb: "The sessions row has a newer role than the users row." A thing is a name: "The orders table", "The capture webhook".
- **An edge or a step says what happens,** with a verb in the present tense: "writes the status", "calls capture()", "The payment webhook arrives".
- **A decision node** is a question that ends with "?": "Is the payment captured?" Its edges are "Yes" and "No".
- **Keep the small words.** Keep "the", "a", "is", "has" and the verb. A label without them is hard to understand.
- **No private codes.** Don't make up tags such as `[I]`, `[V]`, `INV-2`, `S3` or `T1`. Write the word: "Invalid state:", "Invariant:", "Step 3:". The project's own IDs (`AC2`, `T-114`) are names, and they stay.
- **One idea in each label.** Don't add a second idea in brackets. Put the detail in the text below the diagram, or in the diagram's description. Whiteboard shows a node's own description only when the node has no code attached.
- **Words with their usual meaning.** No metaphors or slang, such as "behind", "ahead", "wins", "stomps", "clobbers" or "blows up". Say the fact: "The users row has the old role." Established jargon stays ("What is exempt" above), for example "one-way door".
- **Name the things.** Not "the stores", "both sides" or "it". Write "the sessions table and the users table".
- **No symbols in place of words.** Write "and", "or", "to", "compared to" and "with", not `&`, `/`, `→`, `vs`, `w/` or `~`. The arrows of a diagram are not words, and they stay. A number has its unit: "30 seconds", not "30s".
- **A title** says what the reader sees: "The order states after this PR", not "States (post-PR)".
- **Code names:** in prose and in Markdown table cells, put them in backticks. In Whiteboard and Mermaid labels, write them without backticks. Whiteboard shows the backticks as characters, and Mermaid can read them as Markdown.
- **Table cells** that hold a value can be the value alone: a code value, a `file:line`, "Yes" or "No", a severity, a number with its unit, or a name. A cell that gives a result, a finding or a reason is a sentence.

**Length.** Whiteboard cuts long labels and shows "…" in place of the rest:

- A flow edge label shows 28 characters at most. Write a verb and its object in that space.
- A flow node label shows three lines at most, about 70 characters. Put the rest below the diagram.
- A chip in an animation has space for about 12 characters. Use a short name ("Webhook", "Retry"), still with no made-up codes.

| Where | Don't write | Write |
|---|---|---|
| Node | `[I] user row behind session (stores disagree)` | "Invalid state: the users row has older data than the sessions row." Below the diagram: "The two tables show different values for the same user." |
| Node | `retry → dup charge` | "A second try charges the card again." |
| Edge | `retry → dup charge` | "charges the card again" |
| Node | `webhook vs job race` | "The webhook and the nightly job can change one order at the same time." |
| Decision | `status OK?` | "Is the order status paid?" |
| Table cell | `Guard: ✗` | "No guard stops this change." |
| Title | `States (post-PR)` | "The order states after this PR" |

**Read each label alone** before you finish a board or a diagram. Read it as a person who has not seen the code. If it makes no sense without the diagram, rewrite it.

## Diagrams

- Show a diagram to the user on a Whiteboard when the Whiteboard tools are available ("Whiteboard" below).
- In a committed file (a system doc, a worksheet, a spec, a PR body), also put the diagram in Mermaid, with a link to the Whiteboard. GitHub, CI and other people cannot open your Whiteboard, and Mermaid renders in GitHub and most viewers.
- Without Whiteboard, Mermaid is the only diagram.
- Sequence diagram when participants interact over time. Flowchart when the point is branches, retries or states. Entity diagram for data. Before and after pairs for changes.
- Keep a diagram to what one screen can show. Split big ones.
- Use real names from the code in the labels, inside a sentence or a name ("Labels" above), and link to `file:line` beside the diagram. Mermaid labels follow the same rules.
- If Whiteboard is available and the user wants to be shown how code works, draw on the Whiteboard scratchpad: call `session_capabilities`, then `session_get_instructions` with topic `scratchpad`, and follow it.

## Whiteboard

For a change or a system, if the Whiteboard MCP tools are available: call `session_capabilities`, then `session_get_instructions` (default topic for a change review, `scratchpad` for a quick drawing, `trace-archaeology` to explain how code came to be), and follow them, with two additions:

1. **Language.** Whiteboard's guidance names ASD-STE100 only for prose, at about 80%. Shipinetics applies its own rules ("Prose" and "Labels" above) to every word of the board. That includes the titles, the node and edge labels, the sequence steps, the table cells, the captions and the callouts.
2. **The numbers under a node.** Whiteboard shows `+N` and `−M` under each flow node that has code attached. They count the added and removed lines of that code that the reader has not viewed yet. You can't change them. So, in the description of each flow diagram that has code attached, say once what they mean: "The numbers under a node count the added and removed lines of its code that you have not viewed yet."

If the Whiteboard plugin is installed but `session_capabilities` doesn't answer, the dev.fast Whiteboard app is probably missing. Tell the user once, and recommend that they install the app and restart the session. Until then, use Mermaid.

When you read the board back (Whiteboard's last step), also read each label alone. Rewrite each label that makes no sense without the diagram. Link the Whiteboard from the worksheet.

## HTML pages

A single self-contained `.html` file: inline CSS and JS, no external requests, no build step. It must open straight from disk.

- Put it in `.shipinetics/explainers/YYYY-MM-DD-<slug>.html`. That folder is gitignored because these are throwaway. Commit one only if the user asks.
- Structure: the one-line answer at the top, then a diagram, then detail the reader can expand. Make it interactive where that helps understanding: toggles between before and after, collapsible sections, step-through animations of a flow, sortable tables, a filter on findings.
- Draw diagrams with inline SVG, or an inline Mermaid render if you embed the library source. Don't link a CDN.
- Link to code with relative paths and line numbers. Use real data from the repo, not placeholders.
- Make it look good. If the `impeccable` skill is installed, use it for the visual design.
- Tell the user the path. You can't open it for them inside the sandbox, so give them the command: `open <path>`.
- Never put secrets, tokens or personal data in an explainer.

## Explainer videos

Bespoke videos are starting to work well for concepts and systems. They cost time and sometimes money, so make one only when the user asks or agrees.

1. **Script first.** Write the narration in ASD-STE100, scene by scene, with what's on screen for each line. Show the script to the user (interactive) before rendering.
2. **Pick a renderer:**
   - **Manim** (Python, the 3Blue1Brown style) for math, algorithms, data structures and step-by-step flows.
   - **Remotion** (React) for product walkthroughs, UI, and anything built from the app's own components. The `remotion-best-practices` skill helps if installed.
3. **Narration:**
   - **ElevenLabs** when the project has a key. The key comes from the vault like any secret: run the render through `bin/with-secrets` so it's injected as `ELEVENLABS_API_KEY`, and never print it. Each render spends paid quota, so say roughly how many characters of narration you'll send before you start.
   - **Local and free:** macOS `say`, Piper or Kokoro TTS. Lower quality, no cost, nothing leaves the machine.
4. **Render** to `.shipinetics/explainers/YYYY-MM-DD-<slug>.mp4`, keep the script beside it, and tell the user the path.
5. Keep videos short: two to five minutes. Make several short ones rather than one long one.

## Where each output goes

| Output | Default format |
|---|---|
| Final message to the user | ASD-STE100 prose, plus a Whiteboard if there's flow (Mermaid without Whiteboard) |
| Worksheet summary and log | ASD-STE100 prose. Where there's flow, a Mermaid diagram and a link to the Whiteboard |
| Review of a change (M and up) | Whiteboard, else HTML page |
| "How does X work?" | Whiteboard scratchpad, else a Mermaid diagram plus prose, else HTML page |
| Onboarding to a system, or a hard concept | Offer an explainer video |
| PR description | By [pr-description.md](pr-description.md): the repo's PR template, what changed and why, the decisions with the alternatives that lost, what you did not verify, and a review guide when it helps. Prose by [plain-language.md](plain-language.md). A diagram if there's flow |
| Commit message | The same rules. The first line says what changed. The body says why |
| Comment on someone else's PR | One finding in one or two sentences: the problem, a failure case and the fix (shipinetics:pr-review) |
