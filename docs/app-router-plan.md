# App router (plan)

Status: **R0 built** (action row, permission-free); R1–R4 not started · 2026-10-18 · builds on docs/ask-design.md (Ask Hush v2) and docs/personas.md.

## Decisions (2026-10-18)

- **R0 apps:** Excel + Google Sheets, Cursor + Warp, Notion + Obsidian (plus the assistants already supported).
  Shortcuts (R1) not prioritised yet.
- **R2 Apple Events:** yes, opt-in per app, off by default, turned on from the menu with a plain explanation.
- **R3 MCP actions** (Linear, Slack, Notion): on the roadmap, always behind a "Review and send" step.

## The idea

Ask Hush answers questions and hands conversations to ChatGPT, Claude or Perplexity. The app router takes the next
step: **the answer goes where you're working.** A formula lands in Excel, a command in Warp, a fix request in Cursor, a
note in Obsidian or Notion, a reminder in Reminders.

People toggle between apps about 1,200 times a day (HBR via secondary coverage) and use about 40 apps at work (Torii,
vendor data). Hush already knows which app you were in when you pressed ⌘⇧H. The router turns that into one click
instead of copy, switch, find the spot, paste.

## Design principles

1. **Actions on the result, not more prefixes.** The router mostly appears as the answer card's action row: two or three
   buttons chosen for the answer's shape and the app you came from. `@notion` and similar prefixes exist for power use,
   but nobody should have to learn them.
2. **One obvious primary action.** Copy is always there; the primary button is the most likely next step
   ("Paste in Excel" for a formula asked from Excel). Never more than three buttons.
3. **Nothing happens without a click.** Hush never types into another app or sends anything on its own. Writes to
   other services (Linear, Slack, Notion) always show what will be sent and need an explicit **Send**.
4. **Show where it's going.** Each button carries the target app's icon; after acting, a small receipt says what
   happened ("Opened in Cursor; review the prompt there").
5. **Least permission first.** Use the integration that needs no permission. Ask for more only when it clearly buys
   something, once per app, with a plain explanation.
6. **Learn, but out loud.** If you always pick "Send to Warp" for commands, that becomes the primary action, as a
   visible, editable preference (PRD: scrutable).

## How Hush can reach each app (cheapest first)

| Rung | Mechanism | Permission | Good for | Limits |
| --- | --- | --- | --- | --- |
| 1 | **Deep links / URL schemes** | None | Opening an app at the right place, pre-filled prompts | Often undocumented; can't insert into a document |
| 2 | **Copy + bring the app forward** | None | Universal fallback: formula → Excel, command → terminal | You still press ⌘V |
| 3 | **Shortcuts** (`shortcuts run "…" -i`) | Shortcuts' own prompts, not Hush's | Your own automations; apps' App Intents actions | You build or import the shortcut |
| 4 | **Apple Events** (AppleScript) | One Automation prompt per target app | Insert a formula into Excel's selected cell, create a Note or Reminder | A prompt per app; resets are clumsy |
| 5 | **Agent + MCP connectors** (Claude Code) | Sign-in per service; sends data to it | Create a Linear issue, draft a Slack message, write a Notion page | Data leaves the Mac; every write needs approval |
| ✗ | Accessibility (read selections, window titles, type for you) | Accessibility | — | **Not used.** You declined it; it's also the most invasive |

What's on this Mac today: Excel (`ms-excel:`), Notion (`notion://`), Cursor (`cursor://`), Figma, Warp, Obsidian,
Reminders, Shortcuts (CLI available; 4 shortcuts), Claude desktop, Comet (default browser). Claude Code has no
work-tool MCP servers connected yet (only Claude Docs, plus Apify and Vercel needing sign-in).

## The action row (what the user sees)

| Answer | You came from | Primary | Also |
| --- | --- | --- | --- |
| Formula | Excel | **Paste in Excel** (copy + bring Excel forward; with Automation on: **Insert in selected cell**) | Copy · New Google Sheet |
| Formula | Browser / anything | **Copy** | Open in Excel · New Google Sheet (`sheets.new`) |
| Command | Warp / Terminal | **Send to Warp** (copy + bring forward) | Copy · Explain more |
| Code fix / repo answer | Cursor | **Ask Cursor to apply** (Cursor's official prompt link: opens Cursor with the prompt pre-filled; you confirm) | Copy · Continue in Claude |
| Steps / prose | Notion | **Save to Notion** (copy + open Notion; with an MCP connector: a real page) | Copy · Save to Obsidian |
| Any | Obsidian | **Save to Obsidian** (`obsidian://new`, documented) | Copy |
| "Remind me…" phrasing | Any | **Add to Reminders** (Automation prompt once) | Copy |
| Any | Any | **Run a Shortcut…** (your shortcuts, answer passed as input) | — |

## Architecture

- **`AppAdapter` registry (HushCore, tested):** each adapter declares bundle ids, a display name, and actions
  (`kind`: paste/open/send/save/remind, `mechanism`: deepLink/copyAndActivate/shortcut/appleEvent/mcp,
  `permission`, the shapes it accepts). Deep-link adapters are plain data, so new apps are cheap (and could later come from
  the community as JSON).
- **`ActionRanker` (HushCore, tested):** (answer shape, frontmost app, your history) → up to three actions, primary
  first. Rules in code, learned preferences as visible overrides.
- **`ActionRunner` (HushMac):** performs a mechanism, returns a receipt; Apple Events and MCP behind explicit opt-in.
- **Card:** the action row replaces today's fixed "Continue in ChatGPT · Copy"; hand-offs to assistants become just
  another adapter.

## Phases

| Phase | What | Permission | Done when |
| --- | --- | --- | --- |
| **R0** | Registry + ranker + action row. Adapters: Excel, Google Sheets (web), Warp/Terminal, Cursor (prompt link), Obsidian, Notion (open + copy), assistants (existing). | None | Ask a formula from Excel → **Paste in Excel** works; a command from Warp → **Send to Warp**; a code answer → **Ask Cursor** opens Cursor pre-filled |
| **R1** | Shortcuts bridge: "Run a Shortcut…" on every card; `@shortcut <name>` in the box. | None for Hush | Your existing "Take a Break" shortcut runs from a card |
| **R2** | Opt-in Apple Events for the highest-value inserts: Excel (insert formula into the selected cell), Reminders, Notes. One clear prompt per app, togglable in the menu. | Automation, per app | Formula lands in the selected Excel cell without ⌘V |
| **R3** | Agent actions through MCP (Linear issue, Slack draft, Notion page) with a "Review and send" card showing exactly what goes out. | Sign-in per service; data leaves the Mac | One real Linear issue created from a card, after review |
| **R4** | Learned defaults: the action you keep picking becomes primary, listed and editable in settings. | — | Primary action changes after a few repeats, and you can see why |

Per persona: the **Conductor** gets Cursor, Warp and (R3) GitHub/Linear; the **Juggler** gets Excel/Sheets, Notion, Reminders
and (R3) Slack; the **Maker** gets Cursor prompts and (later) deploy dashboards; the **Learner** gets Obsidian/Notes.

## Risks

| Risk | Mitigation |
| --- | --- |
| Deep links are undocumented and break (Cursor's prompt link has known decoding bugs; Notion has no official scheme) | Every action falls back to copy + bring forward; the receipt says so |
| Permission fatigue (Automation prompts per app) | Rungs 1–3 first; Apple Events only for a few apps, only after you turn them on |
| Writing to the wrong place | No auto-typing; inserts only into Excel's *selected* cell after a click; every SaaS write reviewed first |
| Data leaving the Mac via MCP | Off by default; per-service; the review card shows the exact payload; logged in history |
| Button clutter | Max three actions; ranked; the rest live behind "More" |
