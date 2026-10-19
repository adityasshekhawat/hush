# Brief: Hush v1 character art

For Claude Design. Extend the existing Hush character pack (Guide 02 pose map, the canvas rig) with the props, poses
and sequences the v1 features need (docs/decisions.md ADR-021). Keep the character exactly as it is: same bodies,
same faces, same line weight. Everything here is new pieces that drop into the current pack.

Behaviour ships first with today's props as placeholders, so deliver in the priority order below; each group is
useful on its own.

## Ground rules (the app depends on these)

- **Canvas:** every character file is `viewBox="0 0 160 146"`, character group at `translate(14 8)`, same as
  `assets/character/poses/blob/hold.svg`. Export each new pose for **all three bodies** (blob, bean, square), from the
  canvas rig, like the current `poses/<body>/` files.
- **Layer ids, back to front:** `fx-back`, `character > pose-root > legs-back, topper, body (belly),
  legs-front-seated / legs-front-dangling, accessory, face (…), arms (arm-l, arm-r), props-held, fx-character`. New
  held props go inside `props-held` with an id `prop-<name>`; new effects as `fx-<name>`.
- **Faces:** the face group sits at blob `translate(60 80)`, bean `translate(60 64)`, square `translate(60 84)`. Any
  expression must fit any pose of the same body. Reuse existing expressions where listed.
- **Colour:** draw with the **oat** values so the app can recolour: body `#F4D9A6`, belly `#FFF5E1`, accent
  `#E8876A`, outline ink `#2D2A35`, paper `#FFFDF7`. Cheeks via the `#blush` group. Props use ink, paper and accent
  only, plus flat tints that read on both light and dark desktops.
- **Line weight:** match the rig (outline strokes 2.2, rounded caps and joins).
- **Floor anchors:** edge poses stand on y=112, perches y=116, everything else y=138.
- **No text baked into art.** Where a card, tag, flag or label shows words, leave a blank area and give its rectangle
  (x, y, width, height on the 160 × 146 canvas). The app draws the words (system font, six words or fewer).
- **Sequences:** add each one to `animations/timing.json` in the existing format (`animation`, `folder`, `trigger`,
  `note`, `frames: [{frame, file, ms, pose, expr, caption}]`), with keyframe SVGs in `animations/<NN-name>/`. Keep
  frames to existing or new poses; the app replays them as (pose, expression) on the current body.
- **Calm:** short entrances and exits. Nothing loops for long; anything held still must look fine still
  (performance budget: no constant animation).
- **Licence:** the art ships in the open-source repo under CC BY-SA 4.0. Nothing traced from existing characters.

## Priority 1: pause, battery mode, dismiss (milestone 1)

| Piece | Kind | What it shows |
| --- | --- | --- |
| `pullBlind` | pose | Hush reaches up and pulls a small roller blind down over itself at the edge |
| `hangSign` | pose | Hush hangs a tiny "do not disturb" sign (blank label area) on the blind |
| blind | edge prop (see "Edge props") | Up, half, down. Down covers Hush; only the sign shows |
| sleeping cap | wearable, head slot | Battery mode: a soft nightcap. Same format as `swag/head/<body>-beanie.svg` |
| `tumble` | pose | Flicked away: tumbles backwards out of the edge with a small bounce (2 frames: tipping, gone) |
| menu bar "paused" glyph | template PNG | Matches `assets/brand/menu-bar/HushStatus-*Template` (16/32/48 px, black on transparent) |

Sequences: **pause** (hangSign → pullBlind → blind down), **unpause** (blind up → stretch → stand), **dismiss**
(tumble), **battery on** (yawn → cap on → stand, slower).

## Priority 2: agent watcher, "the flag rail" (milestone 2)

| Piece | Kind | What it shows |
| --- | --- | --- |
| `prop-flag` | held prop | A small pennant on a stick, blank area for a project name (about 8 characters) |
| `plantFlag` | pose | Kneels and pushes the flag into the screen edge |
| `knock` | pose | Seen from inside the screen, knuckles on the glass (reuse `fx-tap-marks`) |
| `raiseHand` | pose | One hand up like a student, eager but polite |
| `prop-card` | held prop | A small handwritten-style card, blank text area for six words |
| `holdCardBoth` | pose | Holds the card up with both hands |
| `worried` | expression | Eyebrows up and together, small mouth. Different from `apologetic` |
| `fx-smoke` | effect | A small puff of smoke for the laptop (`swag/packs/builder/<body>-laptop.svg` exists) |
| `shrugLaptop` | pose | Holds the laptop, sheepish shrug |
| reading glasses | reuse | `swag/face/<body>-glasses.svg` exists; add a `read` pose: holds an item close, leaning in, for the moment the on-device model is thinking |

Edge props: **flag, planted** in four states: done (accent check), needs you (raised-hand icon), look carefully
(striped warning ribbon), error (small smoke). Flags line up as a **rail** along the bottom edge; give the spacing and
how three, five and "+4 more" look.

Sequences: **finished** (hop → plantFlag → walk off), **needs you** (knock ×2 → raiseHand, holds), **look carefully**
(holdCardBoth with `worried`, holds), **error** (shrugLaptop with smoke), **streak** (toss confetti, reuse
`fx-confetti`), **thinking on-device** (glasses on → read, under 1 s).

## Priority 3: meetings, "the door" (milestone 3)

| Piece | Kind | What it shows |
| --- | --- | --- |
| `prop-pocket-watch` | held prop | A round pocket watch on a chain (the current `prop-clock` stays for other uses) |
| `checkWatch` | pose | Pulls out the watch and glances at it; a second frame taps it |
| `holdDoor` | pose | Holds a small door open at the edge, beckoning with the other hand |
| `oneFinger` | pose | Holds up one finger: "1 more minute" |
| door | edge prop | Closed, half closed, open, and ajar with warm light spilling out (running late) |

Sequences: **T-5** (walk in → checkWatch → tap → holds up the card → walks off), **T-1** (hurry → holdDoor, holds with
an occasional `tapfoot`), **snooze** (door half closed → oneFinger), **late** (door ajar, light, faster beckon).

## Priority 4: first run and the journal (milestone 4)

| Piece | Kind | What it shows |
| --- | --- | --- |
| `sniff` | pose | Leans and sniffs toward one side, curious (toward the terminal) |
| `prop-journal` | held prop | A small notebook, cover with a blank label area |
| journal window art | UI illustration | Cover and two page backgrounds for the "What Hush saw" window (about 360 × 480 pt). Plain, warm, paper `#FFFDF7`. Cover line in the app's font: "Stays on this Mac" |

Sequences: **arrival** (walk in → look around → wave), **found your agents** (sniff → holds up the card).

## Priority 5: mail, "the satchel" (milestone 5)

| Piece | Kind | What it shows |
| --- | --- | --- |
| satchel, three sizes | held prop | `prop-satchel-s/m/l`; the current carry wearable is the starting point |
| `pullOut` | pose | Pulls one envelope out of the satchel (reuse `prop-envelope`) |
| `toss` | pose | Tosses a handful of envelopes away over its shoulder |
| bin | edge prop | A small bin with a blank count label |

Sequences: **urgent** (slide in → hold envelope toward the cursor), **digest** (walk in with satchel → pullOut ×2 →
shrug → toss into the bin → walk off).

## Also from the app (not character art, but please cover)

1. **Hand it to Hush polish:** two chew frames (`chewOpen`, `chewClosed`, cheeks full, all three bodies) and a
   `spitOut` pose that hands back a small folded paper. Today the chew is the `puff` pose with a squash.
2. **App icon for macOS 26+:** the current icon is a pre-drawn rounded square. Deliver the lilac icon as layers for
   Icon Composer: a full-bleed background and the character as a separate foreground layer (1024 × 1024, no rounded
   corners, no drop shadow).
3. **Liquid Glass:** how the floating cards (envelope, answer, command box, menu panel) should look on macOS 26+ glass
   vs today's material: tints, whether the 0.5 pt hairline and shadow stay. A short addition to the design guide.

## Deliverables

A zip shaped like `assets/character` (new files only, in the same folders), the updated `timing.json`, edge props in a
new `assets/character/edge/` folder (one SVG per state, with its own viewBox and the anchor point that touches the
screen edge), and a short note listing every new id, the text rectangles, and any pose that needs a new expression.
