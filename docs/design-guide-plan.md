# Design guide: implementation plan

2026-10-19 · Source: `docs/design-guide.md` (from `hush-design-guide (1).zip`), plus the canvas boards Guide 00 to 10
(not in the zip; needed for pixel matching). Per the guide: docs/features.md wins on behaviour, the guide wins on looks.

## What the package changes

| Area | Today | Guide |
| --- | --- | --- |
| Character pack | 39 poses, 14 expressions per body; scarf/cap/glasses accessories | 54 poses, 17 expressions; 14 wearables in 4 slots (head, face, neck, carry); packs + rare finds. **Same canvas and layer ids: drop-in** |
| Tokens | ad-hoc colours, orange primary pill | ink primary pill (paper in dark), lilac/lilacInk brand, system colours for status, tag tints, 16/14 card padding, shadow 0 12 32 @18% + 0.5 pt hairline |
| Motion | panels just appear | spring in (0.35, bounce 0.12, scale 0.96 from Hush), sink out, smooth resize, Reduce Motion fades |
| Placement | 14 gap, 16 headroom, 36 rise, clamp 8 | same stack, clamp **12**, box stacks **8 pt** above an answer card, cards follow Hush with the spring |
| Envelope | 320, title/gist/3 actions | icon tile header with time, 8 variants, "Not this kind again" turns into a receipt (Undo / Edit rule, 6 s) |
| Command box | 540 × 74, sparkle, orange chip | **420 × 46**, radius 14, "Ask Hush…", coloured route chips, hint "Return ask · Tab change route · Esc close", 260 pt chip menu, ink follow-up chip, 3-turn hand-off line |
| Answer card | close button, orange primary | lane chip + status dot + header Stop, shaped bodies (formula block `#F2EFEA`, terminal `#1E1C23`, Rounded 40 facts, number discs), skeleton thinking, red failed block + Try again, green receipt (fades 8 s) |
| Browser tasks | functional | BETA tag, discs (done/current/waiting), step x of y, question box `#FFF4E3`/`#FFD79A` with mm:ss countdown, done/failed layouts, **status pill beside Hush** when the card is closed |
| Digest, onboarding | built | restyle to the block/pip specs |
| New surfaces | none | tuck-in + weekly held-back cards, What I've learned, History window, **menu bar panel** (MenuBarExtra `.window`), **Settings window**, Wardrobe, Rare finds |
| Brand | Line Peek glyph | Tucked mark, app icon (lilac), 5 menu bar template states (idle, mail, meeting, focus, sleep) |

## Decisions (2026-10-19)
- Rive: **no**. Keep the SVG renderer, add short cross-fades between poses.
- Packs: **free for now**. Build the wardrobe with every piece unlocked; payments decided at launch.
- Scope: **all phases D1 to D7**.

## Conflicts (as raised)

1. **Rive.** The guide names Rive states and a 0.18 s blend. Hush renders the SVG pack in a web view. Keeping the SVG
   renderer and adding a short cross-fade gets most of the feel with no new dependency; Rive is a renderer rewrite plus
   a third-party runtime.
2. **Packs and StoreKit.** StoreKit purchases only work for Mac App Store apps, and the App Store sandbox would break
   core Hush features (writing Claude Code hooks, running `claude`, reading transcripts). Options: ship packs free for
   now, sell outside the store (Paddle / Lemon Squeezy licence keys), or a separate store build without agent features.
3. **glassEffect** needs macOS 26; this Mac is on 15, so `.regularMaterial` for now (the guide allows it).
4. **Menu bar panel** replaces today's NSMenu with a SwiftUI panel and a Settings window: a big but clean change.

## Phases

| Phase | Scope | Size |
| --- | --- | --- |
| D1 | Tokens + components (colours light/dark, type, pills incl. consent and small stop, tags, card chrome, motion, placement 12/8) | 1 to 2 days |
| D2 | Character pack swap (54 poses, 17 expressions, new card-reaction poses, wearables in 4 slots) + logo, app icon, menu bar states | 1 to 2 days |
| D3 | Restyle shipped surfaces: envelope (variants + rule receipt), command box, answer card (shapes, states, receipts), browser tasks (+ status pill), digest, onboarding | 3 to 4 days |
| D4 | Held-back cards (tuck-in, weekly chart), menu bar panel + Settings window, History window | 3 to 4 days |
| D5 | What I've learned (editable rule sentences) | 2 days |
| D6 | Rare finds (silent, local, daily cap) | 2 days |
| D7 | Wardrobe window + packs (after the payment decision) | 2 to 3 days + payments |

## Status (2026-10-19): D1 to D7 built

All phases are in. Known differences from the guide:
- Hush's character uses the SVG renderer with 0.18 s cross-fades (decision), not Rive.
- Packs are free; the wardrobe has no prices, locks or "Get" buttons until payments are decided.
- `glassEffect` waits for macOS 26 (`.regularMaterial` today).
- The Wardrobe preview shows the designer's art of the selected piece; Hush on screen is the live preview.
- Weekly card: shown at Friday's tuck-in (18:30), which is after the guide's 17:00.
- Southern-hemisphere spring is guessed from the time zone.
- Cards never show the model, time or cost (user decision, 2026-10-19; the guide's footers had them). They live in
  History and in the menu bar panel's "Ask Hush this month" line.
- The canvas boards (Guide 00 to 10) weren't in the package, so spacing was matched to the written spec only.
