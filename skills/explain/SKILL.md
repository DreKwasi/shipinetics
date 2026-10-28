---
name: explain
description: Present work, findings and systems to the human in the form that's fastest to understand, in ASD-STE100 (the default language for all text for people), from prose through diagrams, Whiteboards and interactive HTML pages to narrated explainer videos. Use when reporting what you did, summarizing a review, explaining how code or a change works, or when the user asks to understand something.
argument-hint: "[topic] [prose|diagram|whiteboard|html|video]"
---

# Explain it so a human gets it fast

> Paths below are Shipinetics's defaults. A project can map them elsewhere in `.shipinetics/config`: run `shipinetics-config` to see this project's actual paths and commands, and use those.

As agents do more of the work, the human's job moves up to oversight and understanding. Your output is only useful if they can take it in quickly. Code and intelligence are cheap now, so it's fine to build a large, custom, throwaway artifact (a web page, a video) just to explain one thing.

Topic and format: `$ARGUMENTS`. If no format is given, pick one with the ladder below.

**Language.** Everything Shipinetics writes for a person uses ASD-STE100, as "Prose" below describes: docs and READMEs, system docs, reports, worksheets, PR bodies, evidence notes, Whiteboards, HTML pages, video scripts and replies in chat. Where that text describes structure or flow, show it on a Whiteboard. A committed file also gets a Mermaid diagram of it. Without Whiteboard, use Mermaid only ("Diagrams" below). Other skills point here for the rules.

## The ladder

Each step up costs more to make and is usually faster to understand. Pick the lowest step that does the job.

| Format | Use it for |
|---|---|
| **Prose (ASD-STE100)** | Final messages, worksheet summaries, review findings, anything a few paragraphs long |
| **Whiteboard** | Anything with structure or flow (call paths, data flow, state machines, architecture, before and after), a code change, or how part of the codebase works. The default visual when the Whiteboard tools (dev.fast) are available |
| **Mermaid diagram** | The same, in a committed file (with a link to the Whiteboard), and the only visual when Whiteboard is not installed |
| **HTML page** | Big changes, comparisons, anything the human will explore or click through |
| **Explainer video** | Concepts, onboarding to a system, algorithms. Only when the user asks or agrees |

## Prose: ASD-STE100

ASD-STE100 (Simplified Technical English) is the controlled language of aerospace maintenance manuals. It makes text simple to understand, also for readers whose first language is not English. Follow these rules:

- One topic per sentence. Sentences of 20 words or fewer for instructions, 25 or fewer for descriptions.
- Paragraphs of six sentences or fewer.
- Active voice. Present tense when you can.
- Simple, common words, with one meaning each. Use the same word for the same thing every time. Don't switch between "job", "task" and "work item" for one concept.
- Instructions as numbered steps, one action per step, imperative verb first ("Run `bin/verify`.").
- Keep articles ("the", "a"). Don't drop words to sound terse.
- Say what's true plainly. No hedging on what you verified. Say exactly what you didn't verify.
- Every factual claim in an explainer or report needs evidence you opened: `file:line`, or a primary source URL with the date checked. Mark anything unverified as unverified. Don't let a polished page or video make a guess look like a fact.
- Avoid noun stacks ("user session token refresh handler failure") and vague words ("various", "appropriate", "robust").

What you can relax: technical terms and code names are fine (the spec allows technical names), and natural short sentences are better than a strict approved-word list.

When the user runs `/wait-what`, or says a message didn't land, re-pitch it with these rules: a little context first, then the point, in the terms from `GLOSSARY.md`.

## Diagrams

- Show a diagram to the user on a Whiteboard when the Whiteboard tools are available ("Whiteboard" below).
- In a committed file (a system doc, a worksheet, a spec, a PR body), also put the diagram in Mermaid, with a link to the Whiteboard. GitHub, CI and other people cannot open your Whiteboard, and Mermaid renders in GitHub and most viewers.
- Without Whiteboard, Mermaid is the only diagram.
- Sequence diagram when participants interact over time. Flowchart when the point is branches, retries or states. Entity diagram for data. Before and after pairs for changes.
- Keep a diagram to what one screen can show. Split big ones.
- Label nodes with real names from the code, and link to `file:line` beside the diagram.
- If Whiteboard is available and the user wants to be shown how code works, draw on the Whiteboard scratchpad: call `session_capabilities`, then `session_get_instructions` with topic `scratchpad`, and follow it.

## Whiteboard

For a change or a system, if the Whiteboard MCP tools are available: call `session_capabilities`, then `session_get_instructions` (default topic for a change review, `scratchpad` for a quick drawing, `trace-archaeology` to explain how code came to be), and follow them exactly. Write its text in ASD-STE100. Whiteboard's own guidance already asks for STE-80 prose and a visual every few sentences. Link the Whiteboard from the worksheet.

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
