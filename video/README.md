# Hush's videos

The website's playful videos, made with [Remotion](https://www.remotion.dev) from Hush's own art pack: the character
is drawn by `site/hush.js` from `site/hush-data.js`, exactly as the website draws it (ADR-032).

```sh
npm ci            # exact, pinned versions; install scripts are off (.npmrc)
npm run studio    # preview and scrub
npm run render    # every video in 16:9, 1:1 and 9:16 → out/
```

- `src/Day.tsx`: "A day with Hush" (the website's film). `src/Flood.tsx`: "The flood".
- `npm run sync` copies the website's fonts and the edge art, and exports the icons of apps installed on this Mac
  (`scripts/app-icons.swift`). Those icons belong to their owners, so they're never committed (`.gitignore`).
- Show only what Hush does today; anything not built yet says so on screen.
- Licence: Remotion is free for individuals and companies of up to 3 people; larger teams need a
  [company licence](https://www.remotion.dev/docs/license).
