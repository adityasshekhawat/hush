# Character pack inventory

Generated from `assets/character` (design guide pack, 2026-10-19) so nobody has to open the SVGs; they're excluded from search by `.ignore`.
Layout: `poses/<body>/<pose>.svg`, `expressions/<body>/<expr>.svg`, `rig/hush-rig-<body>-<eyes>.svg`, `swag/<slot>/<body>-<piece>.svg`, `swag/packs/<pack>/…`, `swag/rare/<slot>/…`, `animations/<NN-name>/<frame>.svg` + `timing.json`, `palettes.json`.

- **Bodies:** blob, bean, square. Face group offset differs per body (blob `translate(60 80)`, bean `translate(60 64)`, square `translate(60 84)`), so faces only swap within a body.
- **Eye styles (rig only):** round, oval, pebble. The renderer rescales `#eyes-open > ellipse`.
- **Poses (54):** bob, bow, cheer, clock, cross, crouch, dance, dive, dizzy, doze, droopy, flinch, giggle, grab, handOver, hide, hold, hop, huff, hurry, land, listen, notice, pat, peek, perch, perch2, perchDoze, perk, pile, poked, proud, puff, shake, sit, sitListen, sitPoint, sitThink, sorry, stand, stomp, stretch, swing, tap, tapfoot, think, walk1, walk2, walk3, walk4, wave, wiggleL, wiggleR, yawn
- **Expressions (17):** alert, angry, apologetic, blissful, dizzy, droopy, grumpy, happy, hmph, neutral, pout, puff, sleepy, squint, surprised, thinking, yawn
- **Toppers:** antenna, ears, leaf · **Wearables:** 45 pieces in 5 slots (head, face, neck, carry, buddy), catalogue in `Sources/HushCore/Wardrobe.swift` (piece → rig layer ids). Face pieces go inside `#face`, the cape's back layer first in `#pose-root`, the rest in `#accessory`; ground pieces are skipped on edge and perch poses.
- **Mouths (rig):** mouth-line, mouth-smile, mouth-open, mouth-small-o
- **Props:** prop-window, prop-envelope-stack, prop-envelope, prop-clock, prop-cursor, prop-command-box (the renderer removes `prop-cursor`, `prop-window` and `screen-edge`)
- **Effects:** fx-speed-lines, fx-motion-arcs, fx-puffs, fx-dust, fx-zzz, fx-confetti, fx-tap-marks, fx-dizzy-stars, fx-steam, fx-anger-mark, fx-thought-dots, fx-shake, fx-alert-ticks, fx-impact, fx-foot-tap, fx-sparkles
- **Palettes:** oat, mint, lilac, sky, rose (slots: body `#F4D9A6`, belly `#FFF5E1`, accent `#E8876A`, cheek via `#blush`; ink `#2D2A35`, paper `#FFFDF7`)
- **Edge poses** (clipped at the screen edge y=112): peek, hide, dive. **Perches** stand on y=116; everything else on y=138.

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

The renderer replays these as (pose, expression) on the current body; only the command box is taken from the keyframe files.
