# Brief: Hush landing page, the loud version

For Claude Design. Redesign the "Launch landing page — It grows on you" board on the Hush canvas
(Landing.dc.html). Keep the brand foundations (Guide 01) and the character pack; change the energy.

## The problem with the current page

It feels busy and quiet at the same time. Twelve sections all carry the same weight, mostly small mock cards
inside a 1200 px column, alternating dark and cream. Hush is small almost everywhere. A lot happens, but nothing
is big.

## The idea: a loud page about a quiet thing

The world on your screen is noisy. Hush is the calm in it. The page gets loud by showing that noise, then
showing Hush take it away. Only the page is loud. Hush itself never shouts, flashes or uses exclamation marks;
all the noise belongs to the notifications it protects you from.

## Principles

- **Fewer, bigger moments.** Six sections, one idea per screen.
- **Hush is huge.** It's the hero, often 60 to 70% of the viewport height, not an illustration in a box.
- **Giant type.** Headlines at 10 to 14 vw, edge to edge, Bricolage Grotesque ExtraBold, tight tracking.
- **Full-bleed colour.** Each section owns one brand colour (Oat #F4D9A6, Coral #E8876A, Lilac #C9BBEC,
  Mint #C6E8D2, Ink #16141B). Hush recolours to match the section it's in (its palettes: oat, rose, lilac,
  mint, and so on).
- **Hush lives at the bottom of the browser.** The page treats the browser window as the desktop: Hush peeks
  over the bottom edge, exactly as it does on a Mac.
- **Motion with meaning.** Every animation is Hush reacting or the noise arriving and leaving. No decorative
  parallax.

## Structure (6 sections)

### 1 · Hero (full viewport, Oat)
- Hush at 60 to 70 vh, peeking over the bottom edge of the viewport (pose `peek`), eyes following the cursor.
  A poke makes it giggle and the whole hero gives a small squash.
- Headline, giant: **The companion that knows when not to.**
- Sub (one line on desktop): Hush sits at the bottom of your Mac, holds back what can wait and tells you when
  Claude needs you.
- Buttons: **Get it on GitHub** (primary, Ink pill) · **Try it here first** (outline).
- Small line: Free and open source · macOS 15 or later · Ask Hush and agent alerts use your Claude Code login.
- A coral "stamp" sticker, slightly rotated, near the headline: **Never makes a sound.**

### 2 · The flood (scroll-driven, Ink, the centrepiece)
A pinned scene that plays as you scroll, about 2 to 3 screens of scroll distance.
1. The screen is calm: a desk, Hush peeking at the bottom.
2. Notifications start arriving, then pour in: Slack pings, newsletters, calendar invites, "Claude finished in
   hush", GitHub mentions, promo mail. They stack, overlap, tilt and pile up toward the top. The page gets
   visually loud: density, overlap, colour, speed.
3. Hush rises (pose `stand`, then `hold`). One by one, then in bulk, the notifications fall back behind it and
   fade. A counter in SF Pro Rounded runs up to **63**, very large, in Lilac.
4. Four envelopes get through and land in a neat row: a meeting in 2 minutes, a VIP, Claude needs you,
   Claude finished.
5. Line: **You got 4 things today. It held back 63.**
- A thin ticker runs along the bottom of the section: "Newsletter from Notion · held", "#random · held",
  "Promo from Figma · held", and so on.
- Reduce Motion: show the end state (pile behind Hush, 63, four envelopes) with a simple fade.

### 3 · Try it (full width, Cream #F7F3EC)
The existing six-step tutorial, made bigger: the stage spans the full width, Hush at about 50 vh.
Keep the steps, the notebook ("What I've learned") and every reaction from the current board. The notebook
can float as a tilted paper card over the right side of the stage.

### 4 · For people building with AI (Lilac)
- Headline: **It watches your agents so you don't have to.**
- A slot for a real 15 s video of Hush on a Mac desktop (typing makes Hush duck, a Claude run finishes and
  Hush holds an envelope, the evening tuck-in). Design the frame; the clip comes later.
- Beside it, three big lane chips with one line each: ⚡ answer here · ‹/› ask about your repo ·
  ↗ open in Claude. Browser tasks as a fourth, marked beta.
- Mention that it watches Claude Code and Codex, and stays out of screen shares.

### 5 · Make it yours (Coral, then Mint on hover/selection)
- The customizer from the current board, with Hush at 60 vh in the middle of the section and options around
  it as big chunky pills.
- Name field and **🎲 Surprise me** (a big hop when pressed).
- Fold rare finds in here as a row of "secret" silhouettes: "14 pieces you can't pick. Hush finds them on its
  own." Hovering one shows its hint (Quiet mornings, Late nights, and so on).

### 6 · Close (Ink)
- Hush, huge, wearing whatever the visitor built in section 5, pose `bow`.
- Headline, giant: **Never says a word. Always gets it.**
- Buttons: **Get it on GitHub** · **Try it here first**.
- One-line Hushverse teaser, small: "Hushverse is coming: a small world where Hushies visit each other."
- Footer: hush · GitHub · Changelog · Privacy.

## Persistent element: Hush follows you down the page
A small Hush (about 90 px) pinned to the bottom of the viewport after the hero, reacting to each section:
- scrolling fast: ducks (`hide`), comes back when you stop
- the flood: holds an envelope (`hold`)
- try it: hidden (the big Hush is on stage)
- builders: thinking (`sitThink`)
- make it yours: wears the current outfit
- close: walks off and the big Hush takes over
Clicking it scrolls to the tutorial.

## Dynamic elements (required)

The page should feel alive the whole time, and every dynamic element should be Hush reacting or the noise
arriving and leaving. Design each one with its trigger, its states and its Reduce Motion version.

**Hush reacting to the visitor**
- **Cursor tracking everywhere Hush appears.** Eyes follow the pointer; Hush leans toward it when it gets close
  and looks up when the pointer is above it. On touch screens it follows the last tap.
- **Poke, hold, drag.** Click: giggle and wiggle. Press and hold: a pat, blissful face. Drag (hero and tutorial):
  grab, swing with the motion, land with a squash. Clicking it fast 4 or more times: dizzy, then grumpy.
- **Idle life.** Blinking, breathing and glancing around. After 20 seconds of no input it dozes with a "z";
  any movement wakes it with a small startle.
- **Typing on the page.** Typing in any field makes the pinned Hush duck out of sight, and it peeks back about
  2 seconds after the typing stops (the real app's behaviour).
- **Copy and paste.** Copying any text on the page puffs Hush's cheeks; pasting into a field blows the air out.
- **Scroll speed.** Fast scrolling: Hush ducks. Stopping: it pops back up. Reaching the very bottom: a little
  cheer.
- **Leaving and coming back.** Switching tabs and returning: Hush waves; after more than a minute away, it
  holds a small envelope that says what "happened while you were away" on the page.

**The noise (the flood and beyond)**
- **Notifications that arrive in real time** in the flood, with real-feeling content, varied app icons, slight
  tilt, overlap and stacking physics. They should be hoverable (they lift) and draggable (fling one away and
  Hush shoos it).
- **A live counter.** The "held back" number counts up as cards fall behind Hush, with a small bump on each
  increment, and settles at 63.
- **A ticker** of held-back items scrolling along the bottom of the flood section, pausable on hover.
- **The four that got through** land with a satisfying settle, one at a time, and each is clickable to show
  why it got through ("a meeting in 2 minutes", "Priya is a VIP", "Claude needs you", "Claude finished").

**The page reacting to the visitor's Hush**
- **Colour follows Hush.** Changing Hush's colour in Make it yours shifts that section's background toward the
  matching brand colour, smoothly.
- **The visitor's Hush stays theirs.** Whatever they build in Make it yours (name, outfit, colour) is the Hush
  that follows them down the page, bows at the close, and appears in the tutorial if they scroll back up.
- **Surprise me** shuffles with a quick slot-machine flicker through outfits before landing, then Hush hops.
- **Rare finds** silhouettes wiggle on hover and show their hint; one random rare piece can appear on the
  pinned Hush once per visit, with no announcement.

**Time-aware touches**
- The page knows the visitor's local time: before 10:00 Hush yawns and stretches when the page loads; after
  18:30 the hero shows the tuck-in card; on Friday evening it does a small dance once.
- The flood's sample notifications use the visitor's current time for their timestamps.

**Ambient motion**
- The hero headline settles in word by word on load (under 1 second).
- Section colour transitions as you scroll, with Hush's palette changing at the same moment.
- Buttons squash slightly on press, like Hush does.

**Rules for all of it**
- Nothing plays sound. Nothing auto-plays faster than the visitor scrolls. No pop-ups.
- Every effect has a Reduce Motion version (instant state changes, simple fades).
- Keep it light: the page should stay smooth on a phone, so prefer CSS transforms and a single animation
  loop for Hush.

## Keep from the current page
- The tutorial and notebook logic, the customizer options, the tuck-in and weekly card designs.
- The honesty rules: "It's told to ask before sending, buying or deleting" for browser tasks; requirements next
  to the main button; no "Download for Mac" until there's a signed release.

## Copy rules
Plain, warm and short, like a small friend. Numbers as digits. No em-dashes. No three-part lists in
headlines. No exclamation marks in system copy. No "AI-powered", "smart" or "seamless".

## Constraints
- Works at 390 px wide: the flood becomes a shorter pinned scene; Hush stays big (about 45 vh).
- Respects Reduce Motion everywhere.
- Hush poses and expressions come from the pack (Guide 02 pose map); no new art needed except the notification
  "noise" cards, which should look like real macOS and app notifications, slightly exaggerated.

## Deliverables
1. The redesigned landing board, desktop (1440) and phone (390).
2. The flood scene as an interactive prototype (scroll-driven), with its timing.
3. A short motion spec: scroll distances, the counter timing, Hush's poses per beat, Reduce Motion versions.
4. Each dynamic element above, shown with its trigger and states, ideally live in the prototype.
