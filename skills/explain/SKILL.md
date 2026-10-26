---
name: explain
description: Present work, findings and systems to the human in the form that's fastest to understand, from controlled-English prose (about 80% ASD-STE100) through diagrams, Whiteboards and interactive HTML pages to narrated explainer videos. Use when reporting what you did, summarizing a review or shift, explaining how code or a change works, or when the user asks to understand something.
argument-hint: "[topic] [prose|diagram|whiteboard|html|video]"
---

# Explain it so a human gets it fast

> Paths below are Shipyard's defaults. A project can map them elsewhere in `.shipyard/config`: run `shipyard-config` to see this project's actual paths and commands, and use those.

As agents do more of the work, the human's job moves up to oversight and understanding. Your output is only useful if they can take it in quickly. Code and intelligence are cheap now, so it's fine to build a large, custom, throwaway artifact (a web page, a video) just to explain one thing.

Topic and format: `$ARGUMENTS`. If no format is given, pick one with the ladder below.

## The ladder

Each step up costs more to make and is usually faster to understand. Pick the lowest step that does the job.

| Format | Use it for |
|---|---|
| **Prose (STE-80)** | Final messages, worksheet summaries, review findings, anything a few paragraphs long |
| **Diagram** | Anything with structure or flow: call paths, data flow, state machines, architecture, before and after |
| **Whiteboard** | Explaining a code change or how part of the codebase works, when the Whiteboard tools (dev.fast) are available |
| **HTML page** | Shift reports, big changes, comparisons, anything the human will explore or click through |
| **Explainer video** | Concepts, onboarding to a system, algorithms. Only when the user asks or agrees |

## Prose: about 80% of ASD-STE100

ASD-STE100 (Simplified Technical English) is the controlled language used for aerospace maintenance manuals. The full spec is strict. Aim for about 80% of it:

- One topic per sentence. Sentences of 20 words or fewer for instructions, 25 or fewer for descriptions.
- Paragraphs of six sentences or fewer.
- Active voice. Present tense when you can.
- Simple, common words, with one meaning each. Use the same word for the same thing every time. Don't switch between "job", "task" and "work item" for one concept.
- Instructions as numbered steps, one action per step, imperative verb first ("Run `bin/verify`.").
- Keep articles ("the", "a"). Don't drop words to sound terse.
- Say what's true plainly. No hedging on what you verified. Say exactly what you didn't verify.
- Every factual claim in an explainer or report needs evidence you opened: `file:line`, or a primary source URL with the date checked. Mark anything unverified as unverified. Don't let a polished page or video make a guess look like a fact.
- Avoid noun stacks ("user session token refresh handler failure") and vague words ("various", "appropriate", "robust").

The 20% you relax: technical terms and code names are fine, and so are short sentences that read naturally over strict word lists.

## Diagrams

- Mermaid inside Markdown is the default. It renders in GitHub and most viewers.
- Sequence diagram when participants interact over time. Flowchart when the point is branches, retries or states. Entity diagram for data. Before and after pairs for changes.
- Keep a diagram to what one screen can show. Split big ones.
- Label nodes with real names from the code, and link to `file:line` beside the diagram.
- If Whiteboard is available and the user wants to be shown how code works, draw on the Whiteboard scratchpad: call `session_capabilities`, then `session_get_instructions` with topic `scratchpad`, and follow it.

## Whiteboard

For a change or a system, if the Whiteboard MCP tools are available: call `session_capabilities`, then `session_get_instructions` (default topic for a change review, `scratchpad` for a quick drawing, `trace-archaeology` to explain how code came to be), and follow them exactly. Whiteboard's own guidance already asks for STE-80 prose and a visual every few sentences. Link the Whiteboard from the worksheet.

## HTML pages

A single self-contained `.html` file: inline CSS and JS, no external requests, no build step. It must open straight from disk.

- Put it in `.shipyard/explainers/YYYY-MM-DD-<slug>.html`. That folder is gitignored because these are throwaway. Commit one only if the user asks. Shift reports are the exception: put them beside the Markdown report as `docs/shifts/YYYY-MM-DD.html`.
- Structure: the one-line answer at the top, then a diagram, then detail the reader can expand. Make it interactive where that helps understanding: toggles between before and after, collapsible sections, step-through animations of a flow, sortable tables, a filter on findings.
- Draw diagrams with inline SVG, or an inline Mermaid render if you embed the library source. Don't link a CDN.
- Link to code with relative paths and line numbers. Use real data from the repo, not placeholders.
- Make it look good. If the `impeccable` skill is installed, use it for the visual design.
- Tell the user the path. You can't open it for them inside the sandbox, so give them the command: `open <path>`.
- Never put secrets, tokens or personal data in an explainer.

## Explainer videos

Bespoke videos are starting to work well for concepts and systems. They cost time and sometimes money, so make one only when the user asks or agrees.

1. **Script first.** Write the narration in STE-80, scene by scene, with what's on screen for each line. Show the script to the user (interactive) before rendering.
2. **Pick a renderer:**
   - **Manim** (Python, the 3Blue1Brown style) for math, algorithms, data structures and step-by-step flows.
   - **Remotion** (React) for product walkthroughs, UI, and anything built from the app's own components. The `remotion-best-practices` skill helps if installed.
3. **Narration:**
   - **ElevenLabs** when the project has a key. The key comes from the vault like any secret: run the render through `bin/with-secrets` so it's injected as `ELEVENLABS_API_KEY`, and never print it. Each render spends paid quota, so say roughly how many characters of narration you'll send before you start.
   - **Local and free:** macOS `say`, Piper or Kokoro TTS. Lower quality, no cost, nothing leaves the machine.
4. **Render** to `.shipyard/explainers/YYYY-MM-DD-<slug>.mp4`, keep the script beside it, and tell the user the path.
5. Keep videos short: two to five minutes. Make several short ones rather than one long one.

## Where each output goes

| Output | Default format |
|---|---|
| Final message to the user | STE-80 prose, plus a diagram if there's flow |
| Worksheet summary and log | STE-80 prose |
| Review of a change (M and up) | Whiteboard, else HTML page |
| Shift report | Markdown report plus `docs/shifts/YYYY-MM-DD.html` |
| "How does X work?" | Whiteboard scratchpad, else diagram plus prose, else HTML page |
| Onboarding to a system, or a hard concept | Offer an explainer video |
