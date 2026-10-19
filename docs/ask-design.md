# Ask Hush v2: design

2026-10-18 · Supersedes the Phase 2 card (one generic text box for every answer). Builds on docs/personas.md.

## What we learned about how people use apps today

- **Many tools, constant switching.** Workers toggle between apps about 1,200 times a day, roughly 4 hours a week spent
  reorienting (HBR study via secondary coverage). The typical worker touches about 40 SaaS apps (Torii, vendor data).
- **More than one assistant.** Power users mix assistants (one unverified survey: 78% use three or more of ChatGPT, Claude,
  Gemini and Perplexity). Market share is spreading: ChatGPT is about 55% of AI-assistant web traffic, Gemini 26%,
  Claude 9% (Similarweb, Aug 2026). Most casual users still default to one assistant.
- **What people ask.** About 80% of ChatGPT conversations are practical guidance, information seeking or writing;
  programming is a small share (NBER w34255, 2025). The XLOOKUP question is the typical case: short, practical, and
  asked mid-task in another app.
- **Answers beat chat for simple questions.** The design consensus (practitioner writing, not controlled studies): for
  simple, factual or predictable questions asked mid-task, show the answer in place; keep chat for open-ended work.

**So:** Hush is not another chat app. It's the fastest path from "I need to know X" to the answer, inside whatever app
you're in, and a polite router to the assistant you already use when the question deserves a conversation.

## Three lanes

| Lane | For | How | Shown as |
| --- | --- | --- | --- |
| **Quick** | Formulas, syntax, definitions, conversions, "how do I…" | One fast model call, no tools, structured output (about 4 s, under $0.001) | A card shaped to the answer |
| **Repo** | Questions about your code | Read-only Claude Code run in an allowed repo (Phase 2) | Streaming card with the repo name |
| **Hand-off** | Open-ended, long, research, or "ask ChatGPT" | Opens your assistant (ChatGPT web, Claude app, Perplexity) with the question pre-filled | A small "Sent to ChatGPT" card; Hush waves it off |

## Routing: Hush shows its plan before you press Enter

A **route chip** in the box updates as you type, so routing is never a surprise and always one key away from changing.

1. **Explicit always wins:** `@gpt` / `@chatgpt`, `@claude`, `@perplexity` / `@pplx` (hand-off), `@code` or `@<repo name>`
   (repo), `@quick`. **Tab** cycles lanes.
2. **Repo signals:** names an allowed repo, or mentions code things (file paths, `function`, `PR`, `commit`, `diff`,
   "this repo", "in the code") **and** a repo is available.
3. **Hand-off signals:** long prompts (over about 40 words), open-ended asks ("plan", "brainstorm", "write me", "help me
   think", "compare … in depth", "research", "essay").
4. **Otherwise, Quick.**

Rules run in code (cheap, predictable, testable); no model call to decide the route.

## Answer shapes (Quick lane)

The model returns one of five shapes through a JSON schema; the card renders each its own way.

| Shape | Example | Card |
| --- | --- | --- |
| `formula` | XLOOKUP in Google Sheets | App chip (Sheets green / Excel green / Numbers), the formula in a large monospace block with **Copy**, one row per argument (name in monospace, meaning in plain text), optional example |
| `command` | "undo last git commit but keep changes" | The command in a monospace block with **Copy**, a one-line "what it does", a warning line if it's destructive |
| `fact` | "how many ml in a cup" | One big answer, one supporting line |
| `steps` | "turn on dark mode in Notion" | Numbered steps, each a short line |
| `prose` | Anything else short | Two to five sentences, inline Markdown |

Every card has: the question (small, top), the shape-specific body, and a footer with the source ("Claude · 4 s") plus
**Copy** and **Continue in ChatGPT/Claude** (hand-off with the question and Hush's answer, so the conversation picks up
where Hush left off). The card sizes itself to the content (up to a limit, then scrolls). It never steals focus;
Esc or a click elsewhere puts it away.

## Context Hush may use (and what it can't see)

- **Frontmost app when you pressed ⌘⇧H** (bundle id only). Excel → formulas default to Excel syntax; Cursor, Warp,
  Terminal → code questions lean toward the repo lane; a browser → no assumption. The card shows it ("in Excel").
- **Not available without extra permissions** (deliberately not requested): window titles, which tab or sheet is open,
  selected text. So "in gsheet" in the question still matters; Hush says what it assumed.

## Body language per state

| State | Hush |
| --- | --- |
| Box open, you're typing | `listen` (head tilt), the designer's command-window sequence |
| Quick / repo answer in progress | `think` with thought dots |
| Answer shown | `hold` (hands it over), then settles |
| Handed off | A small wave as the assistant opens; the card says where it went |
| Failed | `apologetic`; the card explains in one line and offers the hand-off |

## Providers

| Provider | Today | Later |
| --- | --- | --- |
| Claude (inline) | Claude Code CLI, lean profile, builder-only (ADR-012) | API key (Phase 5) |
| ChatGPT | Hand-off: `https://chatgpt.com/?q=` in the default browser (no desktop app installed) | Inline via Sign in with ChatGPT (PRD v2) |
| Claude app | Hand-off: `claude://claude.ai/new?q=` (Claude.app installed), web fallback | — |
| Perplexity | Hand-off: `https://www.perplexity.ai/search?q=` | — |

Pre-fill parameters are undocumented and can change; if one stops working, Hush still opens the assistant and copies
the question so you only need to paste.

## Privacy

Quick-lane questions go to Claude (the question and the frontmost app's name only, no files, no repo). Hand-offs go
where you send them. Everything is in Agent → Show history.

## Follow-ups (2026-10-19)
A finished answer card shows **Follow up**; ⌘⇧H while an answer is showing does the same. The box opens above the
card with a "↩ Follow-up ×" chip and keeps the card's lane (an explicit @prefix or Tab still wins). The model gets
the earlier turns (`FollowUp`, HushCore: last 3, answers capped at 1,500 chars) plus the new question. Backspace on
an empty box or × asks something new. At 3 turns the button goes away: carry on in ChatGPT/Claude, where a long
conversation belongs. Works for quick, repo and browser-task answers; a browser follow-up plans a new task with the
earlier task and its result as context.

## Smarter routing (2026-10-19)
Three layers, cheapest first:
1. **Rules** (AskRouter) drive the live chip on every keystroke. Each route says whether it's sure; only the
   fallback ("short question") is unsure, and quick-shaped asks (formulas, how-tos, shortcuts) count as sure.
2. **Learned routes** (`LearnedRoutes`, UserDefaults `learnedRoutes`, 200 kept): when you change the lane with Tab
   or the menu before sending, that phrasing goes your way next time. Settings ▸ Ask Hush shows the count and Forget.
3. **Model check** (`RouteCheck`, lane `route`, Haiku by default): on Return, when the rules aren't sure and you
   didn't pick a lane, a quick model chooses from quick / repo / handoff / sessions / browser, seeing only the
   question, repo names, the count of running sessions, the app you're in and whether browser tasks are on.
   The card header says "routed by Haiku: why". Settings ▸ Ask Hush ▸ Smart routing turns it off.

First measurement (`swift run hush-eval --lane route`): the model alone picks the expected lane for 41 of 45
asks (91%), $0.0002 and 1.6 s p50 each; misses were borderline (pros and cons → quick, a tutorial → handoff).
In use it only runs for asks the rules aren't sure about.
