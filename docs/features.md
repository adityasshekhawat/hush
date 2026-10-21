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
   you ask for leave the Mac, and the README says exactly which.
6. **A doorway, not a destination.** One question, one answer card (plus up to 3 follow-ups), then act in your app
   or continue in ChatGPT/Claude.
7. **Light on the Mac.** Measured, not promised: see [`docs/performance.md`](performance.md).

What leaves the Mac, and when: see the [README](../README.md#what-leaves-your-mac).

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
| Flick away / right-click | Shoo: tumbles backwards out of sight with a puff of dust (3 shoos of one sender lowers that sender) |
| Double-click / ⌘⇧H | Command window sequence: rises, listens, thinks |
| Type | Ducks after ~2 s, back ~8 s after you stop |
| Join a call | Disappears; things queue until you're done |
| ⌥⇧⌘H | Puts away what it's showing; with nothing showing, pauses for an hour; paused, comes back |
| Menu bar ▸ Pause | 15 minutes, 1 hour or until tomorrow: Hush pulls down a little blind with a "Do not disturb" sign, then goes; the menu bar shows a paused glyph. Things queue and show when it ends; the blind rolls up and it stretches |

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
| Charger in / battery under 20 % | Perks up / droopy and yawny; energy saver (Low Power Mode or under 20 %): one big yawn, then a nightcap until it ends |
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
Material background (Liquid Glass on macOS 26 and later, ADR-030), 16 pt continuous corners, SF Symbols, system fonts, custom pill buttons (macOS's own prominent
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
| ▸_ "check your sessions" | Sessions | "What's Claude doing?" answered on the Mac from hooks and transcripts, no model call. "Let me know when it finishes" watches one; "stop watching" stops |

Tab or the chip's menu overrides the route. Routing runs in code (word rules, the app you're in, recent repo
activity), not in a model.

**Follow-up mode:** with an answer showing, ⌘⇧H (or **Follow up** on the card) opens the box above the card with a
"↩ Follow-up ×" chip and placeholder "Ask a follow-up…". It keeps the card's lane and sends the last turns as
context. Backspace on an empty box or × asks something new. Up to 3 turns; after that, carry on in your assistant.

### 3.3 Answer card ✅ (420 pt)
Header (lane, status, Stop) · body shaped to the answer · action row (max 3) · a quiet footer (no model, time or cost:
those live in History and Settings ▸ Ask Hush),
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
  screenshots (on by default; also the eye button in the menu bar panel's footer, and its ··· menu) · Show count in menu bar · Open at login
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

### 3.9 Meeting card ✅ (ADR-025)
5 minutes before: a gentle envelope with the title, who's coming and one line about what the meeting is for, written
on this Mac from the notes. A minute before, Hush hurries up with a clock and waits. With a call link, one click on
Hush joins; **1 more min** snoozes; your mic turning on puts it away. Up to 5 minutes after the start it reads
"running late".

### 3.10 Hand it to Hush ✅ (ADR-019)
After a copy, Hush's cheeks are full. Click it: a small card offers **Simpler** · **Shorter** · **Bullets**. Hush chews
(on this Mac, Apple's on-device model), then hands the result back on the clipboard; ⌘V blows the cheeks out.
**Original** puts your text back. Asks once before reading what you copied; code is left alone.

### 3.11 What Hush saw ✅ (ADR-026)
Menu bar ▸ What I saw: every item Hush looked at in the last 7 days, grouped by day, with what it did and why
("Held back · can wait", "Shown · your rule"). Filter: All · Shown · Held back. Footer: "Stays on this Mac · kept for
7 days", **Forget…** empties it. Logs titles, category, outcome and reasons; never snippets, notes or model inputs.

### 3.12 What I've learned ✅ (420 pt)
Every rule as a first-person sentence you can edit in place ("I tap the glass when boss@acme.com writes"); edits are
parsed back in code. Forget leaves a 6 s Undo. **+ Add a rule**, and **Tell Hush what matters**: type it your way and
Apple's on-device model proposes rules, each with its own **Add**. Rules also come from **Not this kind again** on a
card and from shoos (3 shoos of one sender lowers it).

### 3.13 Held-back cards ✅
After 18:30, a tuck-in card: "You got 4 things from me today. I held back 63." Fridays: the week. The menu bar panel
shows the same ledger.

### 3.14 Rare finds ✅
14 pieces Hush wears on its own, very rarely: at most one a day, never while you're busy or something waits. Silent;
the only trace is a muted line under "All quiet" in the menu bar panel ("New find: a little bird"). Found pieces stay wearable; unfound
ones show as silhouettes with a vague hint.

### 3.15 What Hush holds up ✅ (ADR-030)
Held states show what kind of thing is waiting, still poses after a short entrance: an agent needs you (knocks, then
raises a hand), a risky request (worried, a card that says "Look carefully"), a run that stopped (shrugs over a
smoking laptop), a meeting in 5 minutes (checks a pocket watch), a meeting now (holds a little door open, taps a foot
now and then; ajar with warm light when you're late; one finger up when you snooze). Mail digest: walks in with a
satchel sized by how much there is, tosses what could wait into a bin. Rule suggestions: glasses on, reading.

### 3.16 The flag rail ✅ (ADR-030)
Agent sessions waiting behind the one Hush holds stand as flags on the bottom edge, left of Hush, newest nearest,
with the project name: finished (check), needs you (raised hand), look carefully (striped ribbon), stopped (smoke).
At most 5, then a "+N more" bundle. Click a flag to open its card. A finished run that has to wait gets planted
there by Hush itself; three finished runs in 15 minutes get a small cheer. Click-through except the flags; hidden
with Hush; left out of screen shares.

### 3.17 Pause and the hush key ✅ (ADR-022)
Menu bar ▸ Pause: 15 minutes, 1 hour or until tomorrow; things queue and show when it ends. ⌥⇧⌘H puts away what Hush
is showing, pauses it with nothing showing, and brings it back when paused. Energy saver in Low Power Mode or under
20 % battery: calm, no idle fidgets, alerts still arrive.

---

## 4. What Hush pays attention to

| Source | Status | How |
| --- | --- | --- |
| Calendar | ✅ | macOS Calendar (ADR-025): gentle 5 min before, with an on-device context line from the notes; interrupt 1 min before, which stays until you join, snooze ("1 more min") or dismiss, or 5 min after the start ("running late"). A call link (Zoom, Meet, Teams, Webex, Whereby, FaceTime, Slack huddle, Jitsi, Around, Gather) found in the event URL, location or notes makes one click on Hush join. The mic turning on near the start clears it. Skips declined, cancelled, all-day and "free" events. Lead times in Settings ▸ General |
| Claude Code and Codex sessions | ✅ | Hooks send Hush the event, session id, folder, host app and terminal device; on a permission request also the tool and up to 200 characters of its input; on a failed run the error type (private socket, memory only, ADR-024): working, needs you ("Claude wants to run npm test"), finished (with run time), stopped ("Hit a usage limit"). Risky requests (deleting, force-pushing, production, secrets, admin, publishing) read "Look carefully", by rules in code, and stay until answered. Cards line up risky > needs you > finished > stopped, with "Also waiting: …". Open goes to the exact Terminal or iTerm tab; other terminals come forward. Going to the session's terminal clears its card when it's the only waiting session there. Cards say which agent: "Codex finished in hush". Codex needs its hooks trusted once with `/hooks`. Codex shell commands arrive as `Bash` like Claude Code's; its file edits (`apply_patch`) show the files they change ("wants to edit app.ts") and get the same secrets, production and delete rules. Built from Codex's documented hooks (0.160+); not yet run against a live Codex session |
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
| Smart routing | Haiku | Where an unclear question goes (on by default; Settings ▸ Ask Hush) |
| Digest summaries | Haiku | Summarise button |
| Browser tasks | Sonnet | Plan + run (hidden from the Models menu for now) |
| Hand it to Hush, meeting context line, rule suggestions | Apple's on-device model | On this Mac only, free |
| Mail triage + gist | Apple's on-device model | Whether a mail is worth showing, and its one-line gist. On this Mac only, free; rules when Apple Intelligence is off (Settings ▸ Connections) |

Aliases always point at the newest model of each tier, so upgrades arrive for free. The Claude lanes run on your
own Claude Code login and use your own Claude usage. A small test set of real asks (`swift run hush-eval`) decides when a default changes: on the
first run Haiku and Sonnet both got every quick ask right, and Haiku cost about 20× less, so Haiku stays.
Plan: [`docs/lanes-plan.md`](lanes-plan.md).

## 6. Coming next ⏳

- Mail: an Apple Mail extension that feeds the judging, rules and digest already built (ADR-027).
- Quick answers and Summarise on Apple's on-device model; the other Claude features behind one opt-in switch.
- More agents, once they can be tested.
- A signed, notarised download. Until then, Hush is built from source.
- Every wardrobe piece stays free and in this repo.

The design guide's surfaces are all built: see [`docs/design-guide-plan.md`](design-guide-plan.md) for what differs.

## 7. Copy rules

Plain, warm and short. Hush talks like a small friend, not an assistant. No em-dashes, no AI-tell adjectives, no
exclamation spam.
