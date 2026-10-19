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
4. If you add a dependency, say why in the pull request. Hush has none today, and that's on purpose.
5. Anything that reads more of the user's data, or sends anything off the Mac, needs to be opt-in and named on
   screen. Mention it in the pull request.

## Character art
The character pack lives in `assets/character` (don't hand-edit SVGs; see `docs/character-inventory.md`). New pieces
should work on all three bodies and every pose.

## Licence of contributions
Code you contribute is under the [Apache License 2.0](LICENSE), and character art under
[CC BY-SA 4.0](assets/character/LICENSE), the same as the rest of the project. You keep your copyright. The Hush name
and logo stay reserved ([`TRADEMARKS.md`](TRADEMARKS.md)).
