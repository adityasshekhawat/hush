Hush - SVG export (generated from the canvas rig, so it matches the canvas exactly)

rig/          9 rig files: 3 body shapes x 3 eye styles. Every optional layer is included;
              unused toppers, accessories, props and effects sit at opacity 0 so they
              import into Rive. Toggle opacity (or use Solo groups) to swap parts.
poses/        all 39 poses on each body (blob/, bean/, square/)
expressions/  all 14 facial expressions on each body (blob/, bean/, square/)
states/       the 9 character-sheet states
animations/   10 folders of numbered keyframes, plus timing.json with each frame's
              duration (ms), pose, expression and caption. Rebuild each sequence in Rive
              as keys on one rig and tween between them; don't flip whole images.

Every pose and expression uses the same layer ids on every body, so one Rive state
machine can drive any body: swap the body/face artboard, keep the animations.

Layer ids (back to front): fx-back, prop-envelope-stack, character > pose-root >
legs-back, topper, body (belly), legs-front-seated / legs-front-dangling, accessory,
face (blush, eyes, eyelids, brows, accessory-glasses, mouth), arms (arm-l, arm-r),
props-held, fx-character; then screen-edge, hands-on-edge, prop-command-box.

Recolour: body / belly / accent fills come from the palette; ink outline is #2D2A35.
