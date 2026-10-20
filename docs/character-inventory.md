# Character pack inventory

Generated from `assets/character` (design guide pack, 2026-10-19; v1 art added 2026-10-20, notes in [`v1-art-notes.md`](v1-art-notes.md)) so nobody has to open the SVGs; they're excluded from search by `.ignore`.
Layout: `poses/<body>/<pose>.svg`, `expressions/<body>/<expr>.svg`, `rig/hush-rig-<body>-<eyes>.svg`, `swag/<slot>/<body>-<piece>.svg`, `swag/packs/<pack>/…`, `swag/rare/<slot>/…`, `animations/<NN-name>/<frame>.svg` + `timing.json`, `palettes.json`.

- **Bodies:** blob, bean, square. Face group offset differs per body (blob `translate(60 80)`, bean `translate(60 64)`, square `translate(60 84)`), so faces only swap within a body.
- **Eye styles (rig only):** round, oval, pebble. The renderer rescales `#eyes-open > ellipse`.
- **Poses (80):** beckon, beckon2, checkWatch, checkWatchTap, chewClosed, chewOpen, hangSign, holdCardBoth, holdDoor, holdDoor2, holdJournal, knock, knockUp, oneFinger, plantFlag, pullBlind, pullOut, raiseHand, read, shrug, shrugLaptop, sniff, spitOut, toss, tumble, tumbleGone (v1 art), bob, bow, cheer, clock, cross, crouch, dance, dive, dizzy, doze, droopy, flinch, giggle, grab, handOver, hide, hold, hop, huff, hurry, land, listen, notice, pat, peek, perch, perch2, perchDoze, perk, pile, poked, proud, puff, shake, sit, sitListen, sitPoint, sitThink, sorry, stand, stomp, stretch, swing, tap, tapfoot, think, walk1, walk2, walk3, walk4, wave, wiggleL, wiggleR, yawn
- **Expressions (20):** worried, chewOpen, chewClosed (v1 art), alert, angry, apologetic, blissful, dizzy, droopy, grumpy, happy, hmph, neutral, pout, puff, sleepy, squint, surprised, thinking, yawn
- **Toppers:** antenna, ears, leaf · **Wearables:** 46 pieces in 5 slots (head, face, neck, carry, buddy), catalogue in `Sources/HushCore/Wardrobe.swift` (piece → rig layer ids). Face pieces go inside `#face`, the cape's back layer first in `#pose-root`, the rest in `#accessory`; ground pieces are skipped on edge and perch poses.
- **Mouths (rig):** mouth-line, mouth-smile, mouth-open, mouth-small-o
- **Nightcap** (`head-nightcap`, v1 art): in every rig file (opacity 0) like the other wearables, a free head piece, and worn on its own in energy saver. **Extra swag (not in the rig):** `swag/carry/<body>-satchel-s|m|l.svg` (`prop-satchel-*`, the mail digest), loaded by the renderer as `extras`.
- **Edge props (`edge/`, v1 art):** blind-up/half/low/down, door-closed/half/open/ajar, flag-plain/done/needs/careful/error, flag-bundle, bin-empty/full. Each file's (0, 0) touches the screen edge; units match the 160 × 146 canvas. Words (sign, flag, bin count) are drawn by the app.
- **UI art:** `assets/ui/journal/` (cover and pages for What Hush saw). **App icon layers:** `assets/brand/app-icon-layers/` and the Icon Composer icon `assets/brand/Hush.icon`.
- **Props:** prop-pull-ring, prop-sign, prop-flag, prop-knuckles, prop-card, prop-laptop, prop-pocket-watch, prop-finger, prop-journal, prop-satchel-s/m/l, prop-envelopes-toss, prop-note-folded (v1 art), prop-window, prop-envelope-stack, prop-envelope, prop-clock, prop-cursor, prop-command-box (the renderer removes `prop-cursor`, `prop-window` and `screen-edge`)
- **Effects:** fx-edge-dust, fx-smoke, fx-sniff, fx-beckon, fx-plant-ticks (v1 art), fx-speed-lines, fx-motion-arcs, fx-puffs, fx-dust, fx-zzz, fx-confetti, fx-tap-marks, fx-dizzy-stars, fx-steam, fx-anger-mark, fx-thought-dots, fx-shake, fx-alert-ticks, fx-impact, fx-foot-tap, fx-sparkles
- **Palettes:** oat, mint, lilac, sky, rose (slots: body `#F4D9A6`, belly `#FFF5E1`, accent `#E8876A`, cheek via `#blush`; ink `#2D2A35`, paper `#FFFDF7`)
- **Edge poses** (clipped at the screen edge y=112): peek, hide, dive, pullBlind, hangSign, tumble, tumbleGone. **Perches** stand on y=116; everything else on y=138.

## Sequences (`animations/timing.json`)

| Folder | Trigger | Frames (pose/expression) |
| --- | --- | --- |
| `01-command-window` | global hotkey, or double-click Hush | peek/neutral → stand/neutral → listen/neutral → think/thinking → hold/happy |
| `02-dragged-around-then-dizzy` | user drags and flings Hush | grab/surprised → swing/squint → land/squint → dizzy/dizzy → shake/squint → stand/apologetic |
| `03-ignored-getting-grumpy` | notification untouched for 10 / 20 / 40 min | hold/neutral → tapfoot/grumpy → cross/pout → stomp/angry → huff/hmph |
| `04-poke` | single click on Hush | poked/squint → giggle/happy → wiggleL/happy → wiggleR/happy → stand/happy |
| `05-inbox-zero` | last unread item cleared | crouch/happy → cheer/happy → land/happy → proud/happy |
| `06-window-perch` | idle; sits on the top edge of the focused window | perch/neutral → perch2/neutral → perch/neutral → perchDoze/sleepy |
| `07-edge-walk` | moving between screen edges or corners | walk1/neutral → walk2/neutral → walk3/neutral → walk4/neutral |
| `08-morning-wake-up` | first unlock of the day | doze/sleepy → yawn/yawn → stretch/squint → stand/happy |
| `09-focus-mode-and-screen-sharing` | Do Not Disturb, screen share or full-screen video | stand/neutral → notice/surprised → dive/squint → hide/neutral |
| `10-eye-tracking` | cursor within about 200 px | stand/neutral → stand/neutral → stand/neutral → stand/neutral → stand/neutral → stand/neutral |
| `11-pause` … `29-hand-it-to-hush` | v1 art (ADR-030) | Renderer names: pause, unpause, dismiss, battery, agentDone, agentNeeds, careful, agentError, streak, readOnDevice, meetingSoon, meetingNow, snooze, late, arrival, foundAgents, mailUrgent, mailDigest, handIt. Frames may carry `wear`, `dx` and `edge`; `expr: "auto"` keeps the pose's own face |

The renderer replays these as (pose, expression) on the current body; only the command box is taken from the keyframe files.
Held states take a **variant** from the app (`CharacterVariant` in `Presence.swift`): `11-notice:needs` raiseHand,
`11-notice:careful` holdCardBoth + worried + card, `04-hold:error` shrugLaptop, `05-clock:meeting` checkWatch, `07-tap:door`
holdDoor + open door, `07-tap:late` beckon2 + door ajar; `08-bow` is the tumble. Each plays its sequence once on the way in.
