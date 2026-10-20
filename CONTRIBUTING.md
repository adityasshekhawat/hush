# Contributing to Hush

Thanks for helping. Hush is a small, silent companion, so the bar is restraint: a change should make Hush quieter,
kinder or more useful, never louder.

## Before you start
- Read [`CLAUDE.md`](CLAUDE.md) (the code map) and the decision record you're touching in
  [`docs/decisions.md`](docs/decisions.md).
- The rules that win every trade-off: silent; attention is earned (only meeting times, VIPs and your own rules may
  interrupt, never a model on its own); respect focus; scrutable; local first.
- Looks follow [`docs/design-guide.md`](docs/design-guide.md); copy follows its voice rules (plain, warm, short, no
  em-dashes, no exclamation marks in system copy).

## Making a change
1. `swift test` must pass. New logic goes in `Sources/HushCore` with tests (time is injected, storage uses an
   in-memory store).
2. Build and try it: `./scripts/bundle.sh`.
3. Keep idle CPU around 2 to 3 % (ADR-011): no persistent animations, no fast timers while nothing changes.
4. If you add a dependency, say why in the pull request. The app has none today, and that's on purpose. (`video/`,
   the tool that makes the website's videos, uses pinned npm packages; it isn't part of the app.) Check any new
   package for known advisories first, and pin an exact version.
5. Anything that reads more of the user's data, or sends anything off the Mac, needs to be opt-in and named on
   screen. Mention it in the pull request.

## Character art
New art is welcome: wardrobe pieces, held props, effects, buddies, seasonal pieces and edge pieces (flags, doors,
signs). Put them in `assets/character/swag/` (or `edge/`), drawn on the same 160 × 146 canvas with the same layer ids,
and make them fit all three bodies and every pose. `docs/v1-art-brief.md` has the ground rules, and
`docs/character-inventory.md` lists what's there (don't hand-edit the existing SVGs).

Hush itself, its body shapes, face, expressions, poses and animations, stays as it is: please don't redraw or modify
it. See [`LICENSE-ASSETS.md`](LICENSE-ASSETS.md).

## Licence of contributions
Code you contribute is under the [Apache License 2.0](LICENSE). New art in `swag/` or `edge/` is under
[CC BY-SA 4.0](assets/character/swag/LICENSE). You keep your copyright. The Hush character, name and logo stay
reserved ([`LICENSE-ASSETS.md`](LICENSE-ASSETS.md)).

## Licensing your contribution
By sending a pull request you agree that your code is licensed under the [Apache License 2.0](LICENSE) (section 5),
and new art under [CC BY-SA 4.0](assets/character/swag/LICENSE). You keep your copyright. Only send work you made or
have the right to share, and nothing traced from other characters or brands.

## Be kind
Treat everyone here the way Hush treats your attention: with care. Taking part means following the
[code of conduct](CODE_OF_CONDUCT.md); it also says how to report a problem privately.
