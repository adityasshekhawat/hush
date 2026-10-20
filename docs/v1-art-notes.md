# Hush v1 character art: notes for the app

> From the designer, kept as delivered. Licence in this repo (ADR-023, ADR-030): poses, expressions and sequences of
> Hush are reserved with the character; props, wearables, effects, edge pieces and `assets/ui` are CC BY-SA 4.0.

Everything here drops into the current pack. Same bodies, faces, line weights and palette (drawn in **oat**). New files only; folders mirror `assets/character` (plus `assets/brand` and `assets/ui`). Licence: CC BY-SA 4.0, all original.

Visual reference: the **v1 character art** page of the Hush canvas, and the live rig (pose, expression, head = nightcap, bag = s/m/l are all in its Tweaks).

## Conventions (and two places this differs from the brief)

- Canvas `viewBox="0 0 160 146"`. The `character` group's translate comes from the rig: `translate(20 + dx, 2 + dy)` per pose, exactly like the existing files (only `hold` happens to be `14 8`). Read it from each file instead of assuming one value.
- Layer order is unchanged. New held props sit in `props-held`; new effects in `fx-character` (or `fx-back` for `fx-edge-dust`, which sits on the screen edge outside the clip).
- Some held props carry small body-coloured "paw" ellipses (fill `#F4D9A6`) so hands read as gripping. Recolour them with the body colour.
- **Menu bar glyph sizes:** the brief says 16/32/48 px, but the existing `HushStatus-*Template` files are 18/36/54 px (@1x/@2x/@3x). The paused glyph matches the existing files.
- **Pause order:** pullBlind → hangSign → blind down (the brief has hangSign first). Hush's arms can't reach the hem while the blind is rolled up, so it pulls the blind halfway, clips the sign onto the hem, then the blind finishes. The sign rides down on the hem and stays visible.

## New ids

**Poses** (all three bodies, `poses/<body>/<pose>.svg`, 26):
`pullBlind`, `hangSign`, `tumble`, `tumbleGone`, `plantFlag`, `knock`, `knockUp`, `raiseHand`, `holdCardBoth`, `shrug`, `shrugLaptop`, `read`, `checkWatch`, `checkWatchTap`, `holdDoor`, `holdDoor2`, `beckon`, `beckon2`, `oneFinger`, `sniff`, `holdJournal`, `pullOut`, `toss`, `chewOpen`, `chewClosed`, `spitOut`.

Extras beyond the brief, each needed by a sequence: `knockUp` (the fist pulled back between knocks), `holdDoor2`/`beckon2` (second beckon frame), `beckon` (beckoning without holding the door, for snooze/late), `shrug` (digest, no laptop), `holdJournal` (a pose to carry `prop-journal`).

**Expressions** (`expressions/<body>/`): `worried` (brows up and pinched together, small tight mouth, slightly bigger eyes; `apologetic` keeps its downward look and wavy mouth), `chewOpen`, `chewClosed` (cheeks full, contented closed eyes).

**Default expressions:** each new pose has one (it's in the rig and in `timing.json`). Poses that need a new expression: `holdCardBoth` uses `worried` for "look carefully"; `chewOpen`/`chewClosed` use their own. Everything else reuses existing expressions.

**Held props** (`props-held`): `prop-pull-ring`, `prop-sign`, `prop-flag`, `prop-knuckles`, `prop-card`, `prop-laptop`, `prop-pocket-watch`, `prop-finger`, `prop-journal`, `prop-satchel-s`, `prop-satchel-m`, `prop-satchel-l`, `prop-envelopes-toss`, `prop-note-folded`. `prop-envelope` is reused by `pullOut`.

**Effects:** `fx-edge-dust` (fx-back), `fx-smoke`, `fx-sniff`, `fx-beckon`, `fx-plant-ticks` (fx-character). `fx-tap-marks` is reused for `knock` and `checkWatchTap`. `fx-confetti` is reused for streak.

**Wearables:** `swag/head/<body>-nightcap.svg` (`head-nightcap`), and `swag/carry/<body>-satchel-s|m|l.svg` (satchel by mail count: s 1–5, m 6–20, l 21+).

## Edge props (`edge/`)

Each file has its own viewBox; **(0, 0) is the anchor that touches the screen edge**, and units match the 160 × 146 character canvas (1 unit ≈ 0.96 pt at the 140 pt display size).

| File | Anchor | Notes |
| --- | --- | --- |
| `blind-up/half/low/down` | centre of Hush's spot on the bottom edge (canvas 80, 112) | Hem at canvas y 20 / 66 / 76 / 110. `low` is the hangSign state. `down` includes the sign. Draw the blind **in front of** Hush, except during `hangSign`: there it goes between `face` and `arms` so the hands can clip the sign on. |
| `flag-plain/done/needs/careful/error` | bottom of the stick | done: accent check badge. needs: raised-hand badge. careful: striped ribbon on the stick. error: charred tip and smoke. |
| `flag-bundle` | bottom of the sticks | The "+N more" bundle; the tag holds the count. |
| `door-closed/half/open/ajar` | bottom centre of the doorway | Hinge on the right; Hush stands to its right (canvas anchor 24, 140 in the sequences). `ajar` has the warm light. |
| `bin-empty/full` | bottom centre | Blank count label on the front. |

**The flag rail:** flags stand on the bottom edge, left of Hush's spot, **64 pt apart** (stick to stick; flags are 50 wide), newest nearest Hush. Show at most 5; from the 6th, replace the oldest four with `flag-bundle` and the label "+4 more" (the bundle sits where the 5th flag would be). See the board for 3, 5 and 5 + bundle.

## Text rectangles (x, y, width, height; the app draws the words)

On the 160 × 146 canvas unless noted. System font, six words or fewer.

| Where | Rect | Fits |
| --- | --- | --- |
| `prop-sign` in `hangSign` | 70, 47, 38, 22 | "Do not / disturb" (2 lines, 8 pt) |
| sign on `blind-down` | 70, 80, 38, 22 (canvas) · -10, -32, 38, 22 (local) | same |
| `prop-flag` in `plantFlag` | 111, 73, 38, 12 | about 8 characters, 8 pt |
| `flag-*` edge | 5, -67, 38, 12 (local) | project name, about 8 characters |
| `flag-bundle` tag | 11, -14, 22, 10 (local) | "+4 more" at 7 pt, or "+4" |
| `prop-card` in `holdCardBoth` | blob 58, 103, 44, 26 · bean 58, 92, 44, 26 · square 58, 107, 44, 26 | six words over 2–3 lines; the card is rotated −3°, rotate the text with it |
| `bin` label | -8, -21, 16, 9 (local) | a count |
| `prop-journal` label | blob 73.5, 97, 13, 8.5 | an icon or 1–2 characters only; usually leave blank |
| journal cover title plate | 90, 148, 180, 64 (pt, on 360 × 480) | "What Hush saw" |
| journal cover line | 74, 244, 212, 20 (pt) | "Stays on this Mac" |
| journal pages | ruled every 28 pt from y 112; text from x 84 to 324 | |

## Sequences (`animations/timing.json`, folders 11–29)

Same format as before, with three optional fields: `wear` (wearable or satchel to show), `dx` (horizontal offset in canvas units, for walking in or off), and `edge` (edge prop, state, anchor and z-order). Keyframes are on blob, as before.

11 pause · 12 unpause · 13 dismiss · 14 battery on · 15 agent finished · 16 agent needs you · 17 look carefully · 18 agent error · 19 streak · 20 thinking on device · 21 meeting T-5 · 22 meeting T-1 · 23 snooze · 24 running late · 25 arrival · 26 found your agents · 27 urgent mail · 28 mail digest · 29 hand it to Hush.

Holds are still poses (raiseHand, holdCardBoth, holdDoor, the paused blind). The only loops are the chew (while the model works) and the late beckon (4 times at most). `sniff` faces right; mirror it when the terminal is to the left.

## App icon for macOS 26 (`brand/app-icon-layers/`)

1024 × 1024, full bleed, no corners, no shadow, SVG and PNG:
`01-background` (lilac `#C9BBEC`), `02-hush-body` (body and leaf), `03-hush-face` (eyes, cheeks, mouth). `foreground-combined` is 02 + 03 in one layer if you'd rather keep two layers. In Icon Composer, put body and face in separate groups so the glass gives the face a little depth; keep specular on, shadow "neutral".

## Liquid Glass (add to the design guide, section 2 "Material")

On macOS 26 the floating cards move from `.regularMaterial` to glass. Everything else in the card (layout, type, pills) stays.

| | macOS 15 (today) | macOS 26 glass |
| --- | --- | --- |
| Background | `.regularMaterial` | `.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))` |
| 0.5 pt hairline | yes | **drop it**: glass draws its own edge highlight; a hairline on top looks doubled |
| Shadow 0 12 32 @ 18 % | yes | **drop it**: glass panels get the system shadow |
| Tint | none | none on envelope, answer and digest cards. The command box may take a very light lilac tint (`.tint(lilac.opacity(0.12))`) to mark it as Hush's; never tint for status |
| Inner blocks (code, question box) | quietFill | keep quietFill, or `.fill(.quaternary)`; never nest glass in glass |
| Primary pill | ink / paper | unchanged (solid). Solid is right for the one primary action on a glass card |
| Command box | material, radius 14 | `.glassEffect(.regular.interactive(), …)`; put the field and the route chip in one `GlassEffectContainer` so the chip can morph |
| Menu bar panel | custom material | let the system menu-bar window glass show through; don't add a background |
| Reduce Transparency | n/a | the system swaps glass for a solid fill; check text contrast in both modes |

Keep 16 pt continuous corners and the 14 pt gap above Hush. Hush is never put behind glass.
