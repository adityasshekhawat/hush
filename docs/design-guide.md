# Hush design guide (for implementation)

This guide covers every surface in [`features.md`](features.md). The visual reference is the **Design guide** page of the Hush canvas (boards Guide 00 to 09, including 08 Rare finds and 10 Wardrobe and packs). Where this file and the README disagree on behaviour, the README wins. Where they disagree on looks, this file wins.

Assets in this folder:

| Folder | What |
| --- | --- |
| `character/` | Hush as clean, layered SVGs. `rig/` has every layer (hidden ones at opacity 0) for Rive. `poses/` has 54 poses × 3 bodies, `expressions/` has 17 × 3 bodies, `swag/` has 14 wearables × 3 bodies plus `swag/packs/` (17 pack pieces and 4 colours) and `swag/rare/` (14 rare finds), each on 3 bodies, and `animations/` has keyframes plus `timing.json`. |
| `logo/` | The Tucked mark, the outlined wordmark, lockups, app icon PNGs (16 to 1024) and the menu bar template images (@1x, @2x, @3x). |

Layer ids in the SVGs (`body`, `eyes`, `arm-l`, `leg-r`, `topper-leaf`, `head-cap` and so on) are stable. Use them as Rive bone and state names.

---

## 1. Principles for the UI

1. **Native first.** Use system fonts, SF Symbols, materials, continuous corners and system semantic colours for status. Hush's warmth comes from the character and the copy, not from decoration.
2. **Cards never cover Hush** (see section 4).
3. **One card at a time.** A newer card replaces the older one, and the older one goes back into what Hush is holding.
4. **No focus stealing.** Panels are non-activating. They take focus only when they contain a field and you click into it.
5. **Brand colour never carries status on its own.** Always pair it with a word or a symbol.

## 2. Tokens

### Colour

| Token | Value | Use |
| --- | --- | --- |
| ink | `#2D2A35` | text, outlines, primary pill (light) |
| paper | `#FFFDF7` | envelopes, card tint |
| oat | `#F4D9A6` | default Hush |
| coral | `#E8876A` | Hush accent, "new" and "now" tags |
| lilac | `#C9BBEC` | app icon, held-back count, brand moments |
| lilacInk | `#5B47A8` on `#F1ECFB` | quick lane chip, held-back number |
| working | `systemBlue` | running, browser task badge |
| done | `systemGreen` | finished, connected, receipts |
| needsYou | `systemOrange` | "asks first", question box, consent pill |
| failed | `systemRed` | errors, Stop, Forget |
| quietFill | `labelColor` at 6% | secondary pills, inner blocks |

Tag tints (light): blue `#E1ECFD`/`#1F5FBF`, green `#DDF3E4`/`#1E7A3C`, orange `#FFEBD1`/`#A35A00`, red `#FDE1DE`/`#B4261A`, grey 6% black / `#4F4858`. In dark mode use the system colour at 22% for the fill and the system colour itself for the text.

### Type (system fonts only)

| Role | Spec |
| --- | --- |
| Card title | 15 semibold, up to 2 lines |
| Onboarding title | 20 bold (the only title above 15) |
| Body, gist | 13 regular; 13.5 on answer cards; envelopes clamp at 3 lines |
| Subtitle | 12.5 secondary, one line, facts joined with " · " |
| Footer, header | 11.5 tertiary |
| Tags | 11 semibold |
| Hush's numbers | SF Pro Rounded bold (held-back count 26 to 34, fact answer 40) |
| Code, formula, command | SF Mono 12.5 to 13 |

### Shape and space

| Token | Value |
| --- | --- |
| Card corner | 16, continuous (`RoundedRectangle(cornerRadius: 16, style: .continuous)`) |
| Inner block (code, question box, sites note) | 10 to 12 |
| Pill | height 28 (30 in onboarding), radius = height / 2, padding 12 to 15 |
| Tag | radius 6 |
| Card padding | 16 at the sides, 14 at the top and bottom |
| Spacing scale | 4 · 8 · 12 · 16 · 24 |
| Card widths | **320** envelope · **400** onboarding · **420** command box and answer card · **440** digest |
| Command box | 420 × 46, radius 14 |
| Material | `.regularMaterial`, or `glassEffect` on macOS 26. Shadow 0 12 32 at 18% plus a 0.5 pt hairline. |

### Buttons

Use custom pills, because macOS prominent buttons render grey in non-activating panels.

- **Primary:** ink fill, white text. Inverted (paper fill) in dark mode. One per card.
- **Secondary:** quietFill, label colour, medium weight.
- **Quiet:** text only, secondary colour, pushed to the trailing edge ("Later", "Close", "Follow up").
- **Consent:** systemOrange fill, ink text. Only for "Yes, go ahead" on browser task questions.
- **Small stop:** height 22, 12 pt, quietFill. Sits in card headers.
- **States:** hover 8% darker, pressed scale 0.97, system focus ring.
- **Shortcut hints** go inside the pill at 60% opacity, for example "Run it ⌘⏎".

### SF Symbols

| Meaning | Symbol |
| --- | --- |
| Quick lane | `bolt.fill` |
| Repo lane | `chevron.left.forwardslash.chevron.right` |
| Hand-off | `arrow.up.right` |
| Browser task | `safari` |
| Meeting | `calendar.badge.clock` |
| Mail | `envelope.fill` |
| Finished, needs you, stopped | `checkmark.circle.fill`, `exclamationmark.circle.fill`, `stop.circle.fill` |
| Digest, tuck-in | `moon.fill` |
| Rules | `pencil.line` |
| Follow-up | `arrow.turn.down.left` |
| Copy, Stop | `doc.on.doc`, `stop.fill` |

The header icon on envelope cards is an 18 pt tile with radius 5. Its fill is the tag tint and the symbol is drawn in the tag text colour.

## 3. Motion

| Moment | SwiftUI | Reduce Motion |
| --- | --- | --- |
| Card appears | `.spring(duration: 0.35, bounce: 0.12)`, scale 0.96 → 1, anchored at Hush | fade 0.15 |
| Card dismisses | `.easeIn(duration: 0.2)`, sinks toward Hush | fade 0.15 |
| Card height changes | `.smooth(duration: 0.3)` | instant |
| Streaming text | `.easeOut(duration: 0.14)` per token | whole text at once |
| Hush pose change | Rive state blend, 0.18 s | swap |
| Onboarding step | cross-fade `.smooth(duration: 0.25)`, resize `.spring(duration: 0.35, bounce: 0.15)` | fade |
| Receipt line | appears with the card spring, fades after 8 s | stays, no fade |
| Menu bar glyph | instant swap | same |

## 4. Placement

From Hush upward, the stack is:

1. Hush's head
2. 16 pt headroom
3. 36 pt reserved for the hover rise
4. 14 pt gap
5. the card

Centre the card horizontally on Hush, then clamp it 12 pt inside the visible screen frame. When Hush moves (walking, perching or being dragged), the card follows with the same spring.

**Command box:** it sits where a card would. When an answer card is showing, the box stacks directly above the card with an 8 pt gap (follow-up mode).

**Browser task status pill:** this appears when the card is closed mid-run. It is a 24 pt capsule beside Hush's head with a coloured dot (blue, orange or green) and the text "In Comet · 3 of 5". Clicking it reopens the card.

## 5. Surfaces

### 5.1 Envelope card, 320 pt (Guide 03)

**Structure:**
- Header: icon tile, source and when, and the clock time on the right.
- Title.
- Subtitle.
- Gist: optional, up to 3 lines.
- Actions: **Open** · **Not this kind again** · **Later**.
- Keys: Return = Open, Esc = Later.

| Variant | Header | Title / subtitle | Primary | Hush |
| --- | --- | --- | --- | --- |
| Meeting, gentle (10 min) | calendar, orange | event name / "15:00 to 15:30 · Zoom" | Open | `clock` |
| Meeting, interrupt (2 min) | calendar, orange | "Design review is starting" | Join (no "Not this kind again") | `hurry` + alert |
| Mail (simulated) | envelope, blue | subject / "Priya is on your VIP list" (why you are seeing it) | Open in Mail | `hold` |
| Agent finished | check, green | "Claude finished in hush" / "Ran for 4m · Terminal" | Open | `hold` + happy |
| Agent needs you | exclamation, orange | "Claude needs you in site" / "Waiting for a permission prompt · Cursor" | Open | `perk` + alert |
| Answer ready | bolt, lilac | "Answer ready" / the question in quotes | Open, Copy | `handOver` |
| Browser task done | safari, blue | "Browser task done" / summary · steps | Open, See steps | `handOver` |
| Digest | moon, lilac | "3 Claude sessions ran" / "2 finished · 1 stopped" | Show me | `hold` |

**After "Not this kind again":** the same card turns into a receipt.
- Title: "Got it. I'll hold these back."
- Subtitle: the rule sentence in quotes.
- Actions: **Undo** · **Edit rule**.
- The card closes itself after 6 s. Hush plays `bow`.

### 5.2 Held-back count (coming next, Guide 03)

1. **Tuck-in card** (daily, 18:30):
   - Shows two SF Rounded numbers: "4 shown" and "63 held back" (the held-back number in lilacInk).
   - One line says what was held. VIPs are mentioned only to reassure.
   - Actions: **See what I held** · **Goodnight**. Hush plays `yawn`, then `doze`.
2. **Weekly card** (Friday after 17:00):
   - Title: "I kept 284 things off your screen."
   - A five-day bar chart: lilac bars for held back, with an ink inset for shown.
   - Actions: **What I learned** · **Close**. Hush plays `proud`.
3. **Panel header:** a lilac row in the menu bar panel reading "63 held back today · 4 shown · 2 rules learned", which opens the held list.
   - **Never show the held-back number on the menu bar glyph.** It would invite checking.

### 5.3 What I've learned (coming next, Guide 03)

- A 420 pt card listing rules as first-person sentences, for example "Newsletters can wait until the evening."
- Each sentence is editable in place. Store the rule as structured data, generate the sentence from it, and re-parse edits in code.
- If an edit can't be parsed, show "I didn't follow that one" and keep the old rule.
- **Forget** is red text and leaves a 6 s Undo in place of the row.
- **+ Add a rule** is at the bottom.

### 5.4 Command box (Guide 04)

- 420 × 46 field. Placeholder "Ask Hush…". The route chip sits on the trailing side.
- Below it, a hint line in 11.5: "Return ask · Tab change route · Esc close".

| Route | Chip | Chip colours |
| --- | --- | --- |
| Quick | ⚡ answer here | lilac `#F1ECFB` / `#5B47A8` |
| Repo | ‹/› ask about *repo* | grey `#ECEAF0` / ink |
| Hand-off | ↗ open in Claude | coral `#FBE1D8` / `#9A3E22` |
| Browser | 🧭 plan it for your browser | blue `#E1ECFD` / `#1F5FBF` |

**Chip menu:** clicking the chip shows a 260 pt menu with the four routes. The selected route is ink-filled, and the model or submenu arrow is trailing. Tab cycles through the routes.

**Follow-up:**
- An ink chip "↩ Follow-up ×" sits on the leading side, and the placeholder is "Ask a follow-up…".
- After 3 turns, the field is replaced by "That's three. Carry on in Claude ↗".

**Hush poses:** `sitListen` while typing (eyes follow the caret), `sitThink` for the repo route, `sitPoint` for hand-off.

### 5.5 Answer card, 420 pt (Guide 04)

**Structure:**
- Header: lane chip (20 pt tall), status dot and word, and **Stop** on the right while running.
- The question, in 13 secondary.
- Body.
- Action row: at most 3.
- Receipt line.
- Footer: "Haiku · 1.1 s · $0.001" on the left, **Follow up** as quiet text on the right.

| Shape | Body |
| --- | --- |
| formula | SF Mono in a 10 pt block on `#F2EFEA`, with Copy inline |
| command | terminal block `#1E1C23`, green `$` prompt, an optional one-line caution below it |
| fact | SF Rounded 40 bold, with the working beside it in secondary |
| steps | numbered list with 20 pt grey number discs |
| prose | 13.5, up to about 5 lines |
| repo | tool chips (`Read ×6`, `Grep ×2`), streamed text with a caret, and footer "Sonnet · 22 s · $0.03 · turn 4" |

**States:**
- Thinking: two skeleton lines, blue dot, Stop. Hush plays `sitThink`.
- Handed off: "Opened in Claude with your question filled in." Hush plays `wave`.
- Failed: a red-tint block `#FDF0EE` with a plain cause and a fix, plus **Try again**. Hush plays `sorry`.
- Delivered: Hush plays `handOver`.

**Receipts:** one line on a green tint `#E9F6EE`, between the actions and the footer, for example "✓ Copied. Press ⌘V in Excel." The next action replaces it. It fades after 8 s.

**App router icons:** use the real app icon via `NSWorkspace.shared.icon(forFile:)` at 16 pt with radius 4, inside the leading pill.

### 5.6 Browser tasks, 420 pt (Guide 05)

**Header:** the blue badge "◎ Browser task", a BETA micro-tag, then the status.

**Plan:**
- Title: a one-line summary.
- Numbered steps: at most 7, plain verbs.
- An orange **asks first** tag on any step that sends, buys, deletes or posts.
- A grey sites note naming the allowed sites in bold, plus the two safety sentences from `features.md`.
- Footer: "Runs in Comet ▾" on the left, then **Cancel** (quiet) and **Run it ⌘⏎** (primary).
- Hush plays `handOver`.

**Running:**
- Shows the last 5 steps. Number discs are green ✓ when done, blue when current, and grey at 45% when waiting.
- A blue working line, for example "Typing 40 into A2".
- Footer: "Sonnet · 48 s so far · step 4 of 5". **Stop** is in the header.
- Hush plays `sitThink`.

**Question:** an inset box with background `#FFF4E3` and a 1 pt `#FFD79A` stroke.
- An orange title: "Before I do this" or "This needs your OK".
- The question as a sentence that names the thing.
- One line of consequence.
- **No** (secondary) · **Yes, go ahead** (orange), with an mm:ss countdown on the right.
- Footer: "Unanswered counts as no."
- Hush plays `perk`.

**Done:**
- Title: the result. A one-line note.
- Actions: **Open the sheet** · **See steps** · **Close**.
- Footer: model · time · cost · "5 steps, 1 OK from you".
- Hush plays `handOver`.

**Failed or stopped:**
- A red-tint cause, for example "Google asked you to sign in, and I don't type passwords."
- Actions: **Run it again** · **Open Comet**.
- Footer: "Nothing was sent or changed."
- Hush plays `sorry`.

**Keys:** ⌘⏎ Run it, Esc Cancel, ⌘. Stop.

### 5.7 Digest, 440 pt (Guide 06)

**Header:** "While you were away · 42 min". Title "3 Claude sessions ran". Subtitle with counts.

**Session block** (inner block on 3.5% black, radius 12):
- Header line: project in bold, branch in SF Mono, and a status tag (working blue, finished green, stopped red).
- The session title.
- "*You asked:* …" and "*Claude:* …".
- Meta: files · commits · run time · a PR link in blue.
- Actions: **Open** · **Summarise** (small pills, height 24).

**Summarise** replaces "Claude:" in place with a white inset of 2 to 3 sentences, showing a 2-line skeleton while it loads.

**Limits:** show at most 5 sessions, then "and 3 more in History". The footer carries the privacy line from `features.md`.

**Consent dialog** (first use): standard alert layout with the app icon, bold title, small body, and an ink **Allow** button plus **Not now**.

### 5.8 History window (Guide 06)

- A standard NSWindow with a unified toolbar: title, a segmented filter (All · Quick · Repo · Hand-off · Browser), and search.
- Columns: lane symbol · question · lane and app · model · cost (SF Mono) · result (tag for browser tasks).
- Rows are grouped by day.
- Footer: "Kept on this Mac · 128 questions · $1.84 this month", plus **Forget history…** in red.
- Space on a selected row reopens its answer card, read-only.

### 5.9 Onboarding, 400 pt (Guide 07)

- 7 pips sit top left; the current pip stretches to 16 pt. **Skip setup** is top right (steps 1 to 6).
- Footer: **Back** (quiet) on the left, primary on the right.

| Step | Content | Hush |
| --- | --- | --- |
| 1 Arrival | "Hi, I'm Hush." + 2 lines | walks in, `wave` |
| 2 Make me yours | rows for Body, Colour (5 swatches), Topper and Wear as segmented controls; **🎲 Surprise me** | live preview, `proud`, a hop on Surprise |
| 3 What do you do | 2×2 multi-select tiles, each says what it switches on | `think` |
| 4 Say hi | 3 tries with check circles; Next is secondary until one is done | reacts live (`pat` + blissful) |
| 5 Connect | rows for Calendar, Claude Code sessions and ⌘⇧H, each with a Connect button or a "✓ Connected" state; "Nothing leaves your Mac unless you ask." | `listen` |
| 6 Tap the glass | 4 big choices 1 · 3 · 5 · 8 (labelled rarely, calm, usual, busy), 5 selected; quiet hours line | `tap` |
| 7 Goodbye | "That's it. I'll be right down here." **Done** | `bow`, then idle |

**After onboarding:**
- First-week tips arrive as 320 pt mini cards, one a day, with **Got it** · **No more tips**.
- **Menu ▸ Setup** shows the steps left, each with a **Do it** button, plus **Replay the intro**.

### 5.10 Menu bar panel and Settings (Guide 09)

Panel v2 (Guide 09b, ADR-034): one glance, one action. `MenuPanel.swift`; the words are `MenuPanelText` (tested).

- Our own non-activating panel under the status item (not MenuBarExtra), 320 pt, Liquid Glass on macOS 26,
  material before. Padding 6 top, 8 bottom.
- **Header:** this Hush peeking (40 pt, `hush.portrait`, drawn once per look and expression, no live renderer), a plain
  sentence ("All quiet", "2 things need you", "Paused until 16:15", "Almost set up") with a second line, a coral or
  grey 8 pt dot when something waits or Hush is paused, and the ··· menu.
- **What waits:** up to 3 rows, each with its one action (Open, Join); more than 3 shows 2 and "and N more".
  While paused, "Resume now" sits under the header instead. Setup shows one nudge at a time (the next missing step).
- **Today:** the lilac tile, "63 held back today · 4 shown to you · Open journal" (opens What I saw), or "Nothing
  held back yet today". Dimmed while paused.
- **Places:** Agents (sessions; "Update my hooks" or "Not watching yet" go to Settings ▸ Connections), While you
  were away (only after coming back to an unopened digest), Ask Hush (History; the count this month).
- **Footer, never moves:** Pause (native menu: 15 minutes, 1 hour, until tomorrow morning; "Change pause" while
  paused), the eye button (show me in screenshots and shares, one click), Settings.
- **··· menu:** Show me in screenshots, Open Hush's settings…, Replay the intro, developer items (hold ⌥ while
  opening), Quit Hush.
- Connections and Ask Hush cost live in Settings (Connections; Ask Hush ▸ this month).
- **Settings window** with these sections: General, Character, Home spot, Perch and moods, Ask Hush (models per lane), Browser tasks, Connections, Setup, Developer.
- **Glyph:** template image from `logo/menu-bar/`. Use the outline when idle and the filled version when something waits. An optional count caps at "9+".

## 6. Pose map (Rive state names)

**Attention ladder:**
- Ambient: `doze`
- Gentle: `hold`, or `clock` for meetings, or `notice` when an agent asks
- Interrupt: `hurry`
- Agent working: `sitThink`

**Playing with Hush:**

| Trigger | Pose |
| --- | --- |
| Cursor near | `stand` (eyes follow) |
| Hover | `wave` |
| Click with nothing held | `hop` |
| Click 4 or more times fast | `dizzy`, then grumpy |
| Press and hold | `pat` (blissful) |
| Drag | `grab`, then `swing` |
| Drop | `land` |
| Shoo | `bow` |
| Command window | `listen`, `sitListen`, `sitThink` |
| Typing | `dive` |
| On a call | `hide` |

**Antics:**

| Trigger | Pose |
| --- | --- |
| Copy | `puff` (puff expression); paste releases it |
| Screenshot | `stand` + squint |
| Cursor shake | `dizzy` |
| Cursor rests on Hush 20 s | `doze` |
| Window dragged past | `flinch` |
| Music | `bob` |
| Charger in | `perk` |
| Battery under 20% | `droopy` |
| First unlock | `stretch` |
| Friday after 18:00 | `dance` |
| 30 min without a pat | `hop` + surprised |
| Inbox zero | `crouch`, then `cheer`, then `proud` |

**Moods (ignored too long):** `tapfoot` (10 min), then `cross` (20), `stomp` (40), `huff`. **Perch:** `perch`, `perch2`, `perchDoze`. **Walk cycle:** `walk1` to `walk4`.

**Card reactions:**

| Event | Pose |
| --- | --- |
| Delivered | `handOver` |
| Handed off | `wave` |
| Failed | `sorry` |
| Needs you | `perk` |
| Working | `sitThink` |
| Rule saved | `bow` |

**Expressions:** neutral, happy, sleepy, apologetic, alert, surprised, thinking, dizzy, squint, grumpy, pout, angry, hmph, yawn, blissful, puff, droopy.

**Swag slots:**
- head: cap, capBack, beanie, bucket, headphones, crown, sweatband
- face: glasses, shades
- neck: scarf, bandana, bowtie, chain
- carry: satchel

Every pose, expression and wearable works on all three bodies (blob, bean, square).

## 6a. Wardrobe and packs (Guide 10)

**Principle:** everything Hush *does* is free. Packs only change what it wears. Rare finds are never sold. Behaviour, interrupts and privacy are never for sale either.

**Catalogue:** 45 pieces in total.

| Group | Pieces |
| --- | --- |
| Free | 3 bodies, 5 colours (oat, mint, lilac, sky, rose), 3 eyes, 4 toppers, and 14 classic pieces |
| Builder pack | `hardHat`, `pixelShades`, `lanyard`, `laptop` |
| Cozy pack | `frogHat`, `bunny`, `coffee`, `books` |
| Studio pack | `beret`, `flowerClip`, `starGlasses`, `plant` |
| Dress-up pack | `wizard`, `chef`, `straw`, `tie`, `cape` |
| Colours pack | `peach`, `matcha`, `butter`, `berry` |
| Rare finds | 14 pieces, earned only (section 6b) |

- Every piece works on every body, pose and colour.
- **Cape:** it has a back layer (`pack-cape-back`, drawn behind the body and legs) and a front clasp.
- **Carry items:** these sit on the ground, to the right (laptop, coffee) or to the left (plant, books).

SVGs are in `character/swag/packs/`.

**Pricing:** the prices below are placeholders. Always read real prices from StoreKit.
- $1.99 per pack, $0.99 for Colours.
- **Everything closet:** $5.99 once. It includes all current and future packs.
- All purchases are StoreKit 2 non-consumables with Family Sharing on, and Restore purchases in Settings. No subscription.

**Gentle ways in:**
- **Try on for a day:** once per piece, until midnight. The tile gets a lilac ring and the preview shows a lilac bar reading "Trying on Frog hat · until midnight". Afterwards, "Keep it?" appears in the preview only.
- **Birthday gift:** on Hush's birthday, the user can pick one locked piece to keep, free.
- **Gift a pack:** a code for a friend.

**Wardrobe window** (Character ▸ Wardrobe):
- **Sidebar:** Body, Colour, Eyes, Topper | Head, Face, Neck, Carry, Buddy | Packs, Rare finds, each with a count.
- **Grid:** 6 columns, grouped Yours / From packs / Rare, not found yet. Locked tiles are full colour with a dark pack tag. Rare tiles are silhouettes tagged "Rare".
- **Preview:** a 300 pt pane with live Hush wearing the selection. Primary button "Get Cozy · $1.99", secondary "Everything $5.99".

**Never:**
- Packs never appear in cards, the menu bar panel, the digest or onboarding. Onboarding step 2 shows free pieces only.
- No "new pack" badges or nudges.
- Hush never wears a locked piece on its own and never reacts to the store.

## 6b. Rare finds (Guide 08)

These are 14 extra pieces that Hush wears on its own, very rarely. You can't pick them in the wardrobe until Hush has found them. SVGs are in `character/swag/rare/`. Buddies are a new fifth slot, `buddy`, and stack with any outfit.

| Piece | Slot | Tier | When | Odds | Leaves |
| --- | --- | --- | --- | --- | --- |
| Bird | buddy | Lucky | quiet morning before 10:00 with nothing waiting | 1 in 300 mornings | when Hush is dragged, or at noon |
| Snail | buddy | Lucky | afternoon after lunch | 1 in 400 afternoons | crosses the bottom edge in about 10 min |
| Butterfly | buddy | Lucky | spring days (by hemisphere) | 1 in 250 spring days | after 3 min |
| Propeller cap | head | Lucky | any drag | 1 in 500 drags | midnight; spins while dragged |
| Cocoa | carry | Lucky | first unlock on a Monday before 08:00 | 1 in 20 early Mondays | midnight |
| Lantern | carry | Lucky | working past 01:00 | 1 in 50 late nights | morning |
| Party hat | head | Seasonal | Hush's birthday (install date) | yearly | midnight |
| Balloon | carry | Seasonal | Hush's birthday, with the party hat | yearly | floats away at midnight |
| Flower crown | head | Seasonal | first day of spring (by hemisphere) | yearly | midnight |
| Heart glasses | face | Seasonal | 14 February | yearly | midnight |
| Jingle bell | neck | Seasonal | last week of December | yearly | midnight |
| Halo | head | Milestone | a full week with zero interrupts needed | earned | midnight |
| Welcome lei | neck | Milestone | first unlock after 5+ days away | earned | midnight |
| Monocle | face | Milestone | the 100th Ask Hush question | once ever | after that answer |

**Rules:**
- **Daily cap:** at most 1 find per day. A dated find wins over a lucky roll that day.
- **When it can roll:** each roll happens once per eligible moment, on the Mac. It never happens during calls, full-screen, focus or quiet hours, or while anything is waiting.
- **Silent:** no card, no sound, and no menu bar glyph change. The only trace is one muted line in the panel, "New find: a little bird", which is gone the next day. Rare finds never count toward interrupts.
- **Wearing:** a rare piece replaces the same slot for that day, and the user's own piece comes back afterwards.
- **Character ▸ Rare finds:** a 4-column grid with a progress bar ("5 of 14"). Found pieces are wearable any day. Unfound pieces are silhouettes (brightness 0, 13% opacity) with a half-sentence hint, such as "Late nights" or "Something about spring". A hint shows only once another piece in the same tier has been found. Never show the exact rule.
- **First appearance:** Hush reacts once. The bird gets `notice` + surprised while looking up, then blissful. Birthday gets `cheer` + confetti. Halo gets `proud` + sparkle. The lei gets a walk-in, then `wave`.
- **Reduce Motion:** buddies fade in and out instead of flying or crawling.

## 7. Copy

| Write | Not |
| --- | --- |
| I held back 63 today. | 63 notifications were suppressed. |
| Claude needs you in hush. | Action required: permission request pending! |
| Copied. Press ⌘V in Excel. | Successfully copied to clipboard! |
| That didn't work. Try again? | An unexpected error occurred. |

- Plain, warm and short, like a small friend. Hush says "I" on cards it hands you.
- No em-dashes. No exclamation marks in system copy. No "AI-powered", "smart" or "seamless".
- Numbers as digits. Times as 24 h ("15:00 to 15:30").
- Errors name the cause and the fix in one or two sentences. Never say "user" or "notification".
