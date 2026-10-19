# Hush: everything it does

The full inventory of what's built, organised by the surfaces a designer works on. The short version, with what
leaves your Mac and how to install, is the [README](../README.md). When this file and the design guide disagree,
this file wins on behaviour and [`design-guide.md`](design-guide.md) wins on looks.

✅ built · ⏳ planned.

---

## 1. Design principles (the rules that win every trade-off)

1. **Silent.** Body language first. No sound, no voice, no chat persona.
2. **Attention is earned.** Only meeting times, VIPs and your own rules may interrupt; the model never does on its
   own. A daily cap (default 5) bounds interrupts.
3. **Respect focus.** Hush ducks while you type, vanishes during calls, stays out of screen shares and screenshots,
   and follows or hides in full-screen apps.
4. **Delight never interrupts.** Play happens only when you're idle and nothing real is waiting, and never counts
   toward the cap.
5. **Scrutable and local.** Every decision is logged on your Mac. Nothing is sent anywhere on its own: only things
   you ask for leave the Mac, and the table below says exactly which.
6. **A doorway, not a destination.** One question, one answer card (plus up to 3 follow-ups), then act in your app
   or continue in ChatGPT/Claude.
7. **Light on the Mac.** Measured, not promised: see [`docs/performance.md`](performance.md).

What leaves the Mac, and when: see the [README](../README.md#what-leaves-your-mac).

--- | --- | --- |
| Press Return in Ask Hush (quick or code question) | Your question and the name of the app you were in. For a code question, Claude Code reads files in that repo, which you allowed first | Anthropic, through **your own** Claude Code login and usage |
| Press Return when Hush isn't sure where a question should go (Smart routing, on by default, Settings ▸ Ask Hush) | Your question, your allowed repos' names, how many sessions are running, the app you're in | Anthropic, through your Claude Code login |
| Click **Summarise** on a "While you were away" card | A short excerpt of that one session | Anthropic, through your Claude Code login |
| Run a browser task (beta, off by default) | The task, and what Claude does in your browser | Anthropic, through Claude Code and the Claude browser extension |
| Hand a question off ("open in ChatGPT / Claude / Perplexity") | The question, in the link that opens (from "hand it to Hush", only the instruction: you paste the text yourself) | The assistant you picked |

**Stays on the Mac:** your calendar (read through macOS); the Claude Code and Codex hooks, which send Hush only the
event, session id, folder, host app and terminal device; mail judging and its gist, and "hand it to Hush", which use
Apple's on-device model when Apple Intelligence is on; transcripts for the digest (only if you turn it on); the
clipboard, which Hush reads only when you click it to rework what you copied.

Planned (ADR-021): quick answers and Summarise move to Apple's on-device model, and the remaining Claude features
sit behind one switch that's off until you turn it on.

---

## 2. The character

### Look (menu bar ▸ Character, and in onboarding)

| Slot | Options |
| --- | --- |
| Body | blob, bean, square |
| Palette | oat, mint, lilac, sky, rose (body, belly, accent, cheek; ink `#2D2A35`, paper `#FFFDF7`) |
| Eyes | round, oval, pebble |
| Topper | none, antenna, ears, leaf |
| Accessory | none, scarf, cap, glasses |

Art: 39 poses × 14 expressions per body, 16 effects, 6 props, 10 keyframed sequences
([`docs/character-inventory.md`](character-inventory.md)). Rendered as SVG in a transparent overlay, ~140 pt.

### Where it lives

- **Sneak mode (default):** peeks over the bottom screen edge, only head and hands showing.
- **Home spot:** bottom left, centre or right (menu ▸ Home spot); it walks there along the edge.
- **Perch:** after 2 idle minutes it hops onto the top edge of the focused window, swings its legs, rides along when
  the window moves, dozes after 5 min. Drop it on any window's top edge and it settles there.
- **Follows you** into full-screen apps and across Spaces (or hides there; a setting).

### Attention ladder (how it signals something real, without words)

| Level | Meaning | Hush does |
| --- | --- | --- |
| Ambient | Logged, not shown | Nothing visible; counted as "held back" |
| Gentle | Worth knowing | Rises and **holds an envelope**; holds a **clock** for meetings; **notices** (alert) when an agent asks permission |
| Interrupt | Can't wait (meeting in 2 min, VIP, your rule) | **Hurries** up, eager |
| Thinking | A Claude Code agent is working somewhere you're not looking | Ambient **think** pose |

Ignored too long, with Moods on (off by default): taps a foot (10 min) → crosses arms (20) → stomp and huff (40).

### Playing with it

| You | Hush |
| --- | --- |
| Move the cursor near | Eyes follow, leans toward you |
| Hover | Pops half out of the edge and waves |
| Click | Opens what it's holding; otherwise a hop, wave or wiggle |
| Click 4+ times fast | Dizzy spin, then grumpy |
| Press and hold | A pat: leans into your hand, blissful |
| Drag and drop | Startled grab, swings with your motion, lands with squash and dust; drop point = new home |
| Flick away / right-click | Shoo: bows and backs off (3 shoos of one sender lowers that sender) |
| Double-click / ⌘⇧H | Command window sequence: rises, listens, thinks |
| Type | Ducks after ~2 s, back ~8 s after you stop |
| Join a call | Disappears; things queue until you're done |
| ⌥⇧⌘H | Puts away what it's showing; with nothing showing, pauses for an hour; paused, comes back |
| Menu bar ▸ Pause | 15 minutes, 1 hour or until tomorrow. Things queue and show when it ends |

### Antics (only when it's quiet)

| When | Hush |
| --- | --- |
| You copy | Cheeks puff like a hamster and stay full; paste blows the air out (copy again: gulp, refill) |
| Click it with full cheeks | **Hand it to Hush:** Simpler, Shorter or Bullets. It chews, hands the result back on your clipboard, and your ⌘V blows the cheeks out. On this Mac with Apple Intelligence; asks once before reading what you copied; **Original** puts your text back |
| Screenshot | Caught in the flash, squints |
| Shake the cursor | Woozy |
| Rest the cursor on it 20 s | Falls asleep under your hand |
| Drag a window past it | Flinches |
| Music playing | Bobs along |
| Charger in / battery under 20 % | Perks up / droopy and yawny |
| First unlock of the day, or back from a long break | Morning yawn and stretch |
| Late at night | Yawns more |
| Friday after 18:00 | A little dance, once |
| 30 min without a pat | Pops up hopefully and asks for one (max 3/day; sighs if ignored) |
| Inbox zero | Crouch, cheer, proud |
| End of day (after 18:30) | **Tuck-in card:** "You got 4 things from me today. I held back 63." On Fridays, the week: "This week you got 18 things from me. I held back 240." |

Between moments: blinking, breathing, glancing around, small stretches, dozing after 5 min idle.

---

## 3. Surfaces (UI)

All cards are floating panels that **never cover Hush**: placed above it (14 pt gap, 16 pt headroom, room for its
36 pt hover rise) and re-placed when it moves. They don't steal keyboard focus unless you type in them.
Material background, 16 pt continuous corners, SF Symbols, system fonts, custom pill buttons (macOS's own prominent
buttons render grey in these non-activating panels).

### 3.1 Envelope card ✅ (320 pt)
Opens when you click Hush while it's holding something. Title, subtitle, a 3-line gist, then **Open** ·
**Not this kind again** (becomes a rule) · **Later**. Shown for:
- meeting reminders
- mail (simulated until MailKit)
- agent events: "Claude finished in hush · Ran for 4m" / "Claude needs you in hush · Waiting for a permission prompt"
- Ask Hush results you closed the card on: "Answer ready", "Browser task done"
- the digest (opens it directly)

### 3.2 Ask Hush: command box ✅ (⌘⇧H or double-click)
One text field above Hush with a live **route chip** showing Hush's plan as you type:

| Chip | Lane | What happens |
| --- | --- | --- |
| ⚡ "answer here" | Quick | One fast model call; the answer comes back as a shaped card |
| ‹/› "ask about *repo*" | Repo | Read-only Claude Code run in an allowed repo; the card streams progress |
| ↗ "open in ChatGPT / Claude / Perplexity" | Hand-off | Opens that assistant with the question pre-filled |
| 🧭 "plan it for your browser" | Browser task (beta, opt-in) | A plan card first; after **Run it**, it works in your browser (see 3.8) |

Tab or the chip's menu overrides the route. Routing runs in code (word rules, the app you're in, recent repo
activity), not in a model.

**Follow-up mode:** with an answer showing, ⌘⇧H (or **Follow up** on the card) opens the box above the card with a
"↩ Follow-up ×" chip and placeholder "Ask a follow-up…". It keeps the card's lane and sends the last turns as
context. Backspace on an empty box or × asks something new. Up to 3 turns; after that, carry on in your assistant.

### 3.3 Answer card ✅ (420 pt)
Header (lane, status, Stop) · body shaped to the answer · action row (max 3) · a quiet footer (no model, time or cost:
those live in History and the menu bar panel's "this month" line),
a receipt line after an action, and **Follow up** (quiet text button, bottom right).

**Shapes:** formula (monospace, copyable) · command (terminal block) · fact (big short answer) · steps (numbered) ·
prose · repo (streamed text, tools used, cost and turns).

**Action row (app router)**, ranked by the answer's shape and the app you asked from, with that app's icon:

| Answer | Actions |
| --- | --- |
| Formula | Paste in Excel (when you're in it) or Open in Excel · New Google Sheet |
| Command | Send to Warp / iTerm / Terminal |
| Code (repo) | Ask Cursor (opens Cursor's chat pre-filled) |
| Notes / steps | Save to Notion (in Notion) · Save to Obsidian (new note) · Ask Cursor (in Cursor) |
| Every answer | Copy · Continue in your assistant (ChatGPT / Claude / Perplexity) |

Receipts: "Copied. Press ⌘V in Excel." · "Saved as a new note (also copied)." · "Opened in Cursor. Review the prompt
there." Nothing is pasted or run in another app automatically. Character reactions: **wave** (handed off),
**hand over** (answer delivered), **sorry** (failed).

### 3.4 History ✅
Menu ▸ Agent ▸ Show history: every question with its lane, model, cost and result, kept on the Mac.
"Forget history" clears it.

### 3.5 "While you were away" digest ✅ (opt-in, 440 pt)
After 10+ min away, Hush holds a gentle envelope. The card lists each Claude Code session that ran:
- project, branch, status pill (working / finished / stopped), title
- "You asked: …" and "Claude: …"
- files changed, commands, commits, PR links
- **Open** (jumps to the terminal or editor it ran in) and **Summarise** (2–3 sentences)

Footer: "Read on this Mac from ~/.claude/projects. Summarise sends a short excerpt to Claude." Consent dialog on
first use. Menu ▸ Agent ▸ Show digest (last 3 hours).

### 3.6 Onboarding ✅ (400 pt card)
1. **Arrival:** "Hi, I'm Hush."
2. **Make me yours:** body, colour, topper, accessory, "Surprise me".
3. **"What do you mostly do on your Mac?"** (pick any): I build software · I build with AI · I manage work and
   messages · I just want company. Answers switch on matching features.
4. **Say hi:** three tiny tries (hover, press and hold for a pat, double-click).
5. **Connect:** Calendar, Claude Code sessions, ⌘⇧H, each optional. "Nothing leaves your Mac unless you ask."
6. **"How often may I tap the glass?"** Interrupts per day.
7. **Goodbye:** "That's it. I'll be right down here." Then first-week tips, one at a time.

Skip setup and Back are always available. Menu ▸ Setup shows what's left and replays the intro.

### 3.7 Menu bar ✅
The menu opens with the **held-back ledger**: "Today: 4 shown · 63 held back" and "This week: 18 shown · 240 held
back". Template glyph ("Line Peek"): **outline** when idle, **filled** when something waits, optional count (off by
default, caps at "9+"). The menu:

- **Status:** Calendar connected · Mail (waiting on MailKit) · Claude Code: watching (remove hooks…) · Codex: watching (when Codex is set up)
- **Character:** Body, Palette, Eyes, Topper, Accessory
- **Home spot** · **Interrupts per day** (1 / 3 / 5 / 8) · **Quiet hours** 22:00–07:00
- **Toggles:** Perch on windows when idle · Moods · Hide in full-screen apps · Hide from screen shares and
  screenshots (on by default) · Show count in menu bar · Open at login
- **Agent:** Open long questions in (ChatGPT / Claude / Perplexity) · Models (per lane: Haiku / Sonnet / Opus) ·
  allowed repos · digest on/off · history
- **Agent ▸ Browser tasks (beta)** on/off · **Run browser tasks in** (Automatic, or a browser that has the Claude
  extension: Chrome, Comet, Arc, Brave, Edge)
- **Setup** (steps left, replay intro, first-week tips) · Developer (simulators) · Quit

### 3.8 Browser tasks ✅ beta (answer card, 420 pt)
Opt-in. You ask for something done in the browser ("make a google sheet of these numbers: 12, 40, 7"). Three states
on the answer card, blue **Browser task** badge:

1. **Plan:** a one-line summary, numbered steps, an orange **asks first** tag on steps that send, buy, delete or
   post, "Opens only *sites*. A new address asks you first; links it clicks aren't checked.", "It's told to ask
   before sending, buying or deleting, and never to type passwords." Footer: "Runs in Comet" · **Cancel** ·
   **Run it** (⌘⏎).
2. **Running:** the last few steps with checkmarks ("Opening a tab", "Going to the page", "Reading the page",
   "Working in the page"), a working line, **Stop**.
3. **A question:** an orange box inside the card: "Before I do this" (the model is about to do something
   irreversible) or "This needs your OK" (a site outside the plan), with **No** · **Yes, go ahead**. Unanswered
   questions expire after about 5 minutes and count as no.

Done shows a short summary and the usual footer; if the card was closed, it arrives as a gentle envelope. Hush's
reactions: **hand over** (plan ready, done), **perk** (needs you), **sorry** (failed). What's enforced in code: which
tools run, which addresses open; everything is logged on the Mac.

Needs the Claude extension (claude.ai/chrome) signed in with the same account as Claude Code. Claude Code connects
it to Chrome, Arc, Brave and Edge itself; for Comet, Hush adds the missing connection file when you press Run it.

---

## 4. What Hush pays attention to

| Source | Status | How |
| --- | --- | --- |
| Calendar | ✅ | macOS Calendar (ADR-025): gentle 5 min before, with an on-device context line from the notes; interrupt 1 min before, which stays until you join, snooze ("1 more min") or dismiss, or 5 min after the start ("running late"). A call link (Zoom, Meet, Teams, Webex, Whereby, FaceTime, Slack huddle, Jitsi, Around, Gather) found in the event URL, location or notes makes one click on Hush join. The mic turning on near the start clears it. Skips declined, cancelled, all-day and "free" events. Lead times in Settings ▸ General |
| Claude Code and Codex sessions | ✅ | Hooks send Hush the event, session id, folder, host app and terminal device; on a permission request also the tool and up to 200 characters of its input; on a failed run the error type (private socket, memory only, ADR-024): working, needs you ("Claude wants to run npm test"), finished (with run time), stopped ("Hit a usage limit"). Risky requests (deleting, force-pushing, production, secrets, admin, publishing) read "Look carefully", by rules in code, and stay until answered. Cards line up risky > needs you > finished > stopped, with "Also waiting: …". Open goes to the exact Terminal or iTerm tab; other terminals come forward. Going to the session's terminal clears its card when it's the only waiting session there. Cards say which agent: "Codex finished in hush". Codex needs its hooks trusted once with `/hooks` |
| Claude Code transcripts | ✅ opt-in | Read on the Mac for the digest |
| Your focus | ✅ | Mic in use (calls), full-screen, typing, away |
| Copy/paste, screenshots, power, audio | ✅ | For antics only; no permissions needed |
| Mail | ⏳ not connected yet | MailKit extension is next; until then mail is only simulated from the Developer menu. When it lands, it's judged on this Mac by Apple Intelligence when that's on, otherwise by rules |
| Screen sharing | ✅ | Hush's windows are left out of screen shares, recordings and screenshots (a setting, on by default), so viewers never see it. Presenting without a call isn't detected, so Hush may still appear on your own screen |

## 5. Models (they're settings)

| Lane | Default | Used for |
| --- | --- | --- |
| Quick answers | Haiku | Ask Hush quick lane |
| Code questions | Sonnet | Ask Hush repo lane (read-only tools) |
| Digest summaries | Haiku | Summarise button |
| Browser tasks | Sonnet | Plan + run (hidden from the Models menu for now) |
| Mail triage + gist | Apple's on-device model | Whether a mail is worth showing, and its one-line gist. On this Mac only, free; rules when Apple Intelligence is off (Settings ▸ Connections) |

Aliases always point at the newest model of each tier, so upgrades arrive for free. The Claude lanes run on your
own Claude Code login and use your own Claude usage. A small test set of real asks (`swift run hush-eval`) decides when a default changes: on the
first run Haiku and Sonnet both got every quick ask right, and Haiku cost about 20× less, so Haiku stays.
Plan: [`docs/lanes-plan.md`](lanes-plan.md).

## 6. Coming next ⏳

- The v1 plan ([`docs/decisions.md`](decisions.md) ADR-021): agent watcher with a flag rail and one-click jump
  to the right terminal, meetings with one-click join, first run, the "What Hush saw" journal, then mail.
- Quick answers and Summarise on Apple's on-device model; the other Claude features behind one opt-in switch.
- A signed, notarised download. Until then, Hush is built from source.
- Every wardrobe piece stays free and in this repo.

The design guide's surfaces are all built: see [`docs/design-guide-plan.md`](design-guide-plan.md) for what differs.

## 7. Copy rules

Plain, warm and short. Hush talks like a small friend, not an assistant. No em-dashes, no AI-tell adjectives, no
exclamation spam.
