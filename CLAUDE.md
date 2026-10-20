# Hush

Silent macOS desktop companion (Swift, SwiftPM, no Xcode). Read only what the task needs; the map below says where.

## Rules that win every trade-off
Silent · attention earned (only VIPs, user rules, meeting times interrupt; the model never does) · respect focus ·
scrutable · local-first. Rules run in code, not prompts. Delight never interrupts or counts toward the cap.
Idle CPU stays ~2–3 % (ADR-011): no persistent animation inside the SVG, no fast timers while nothing changes.

## Map
| Area | Files |
| --- | --- |
| Decision engine (pure, tested) | `Sources/HushCore/`: `DecisionEngine` (cascade), `Models`, `Settings`, `Store` (SQLite), `Meetings`, `Presence` (state → pose), `Antics` (when play is allowed), `AgentSessions` (Claude Code + Codex sessions, `AgentKind`), `ClaudeHooksConfig` (merge/remove hooks; Claude settings.json and Codex hooks.json), `AgentTasks` (task log, read-only profile, repo choice), `AskRouting` (lanes + router) + `SmartRouting` (learned routes, model check), `SessionsReport` (sessions lane: hooks + transcripts, no model; `HushCommand` watch/unwatch + targeting), `TerminalScript` (type into a session's Terminal/iTerm tab by tty), `FollowUp` (follow-up threads, capped at 3 turns), `AnswerShape` (quick-answer schema), `AppRouter` (answer → app actions, ranked), `RuleText` (rules ↔ first-person sentences), `SessionDigest` (transcript → "while you were away", opt-in), `MenuBarBadge` (glyph state: idle/mail/meeting/focus/sleep + optional count), `Wardrobe` (45 wearables, slots, packs, rare), `RareFinds` (rolls, dated finds, daily cap, leaving rules), `Lanes` (model + caps per lane; overrides via `Sources/Hush/LaneSettings`), `AskEval` (eval set + grading), `BrowserTasks` (do-lane intent, plan, gate rules, gate protocol), `MailTriage` (on-device mail prompt, schema guidance, parsing), `Pouch` (hand it to Hush: verbs, limits, code check, prompt, cleanup; ADR-019), `PasteGuess` (was that ⌘ shortcut a paste; ADR-020), `Pause` (pause lengths and text; ADR-022), `AgentRequest` (what an agent asks for, `AgentRisk` rules, `AgentFailure` wording; ADR-024), `AgentChannel` (hushctl → Hush socket path and validation) |
| macOS adapters | `Sources/HushMac/`: `CalendarSource`, `FocusMonitor`, `PlaySensors` (copy/paste, screenshot, power, audio), `AgentStatusReceiver`, `ClaudeCodeRunner`, `LaneOptions` (runner options per lane, shared with `hush-eval`), `TranscriptScanner` (opt-in digest), `GateServer` (browser-task approval socket), `SessionInput` (send a message to a session), `TaskBrowsers` (which browser has the Claude extension; its connection manifest), `OnDeviceTriage` (Apple's on-device model: classifier + gist writer, falls back to rules; ADR-018), `OnDeviceRewriter` (reworks copied text on-device; ADR-019), `DiagnosticsLog` |
| App wiring | `Sources/Hush/AppController.swift` (state + `refresh()`), split by concern into `AppController+Engine/Gestures/Pointer/Placement/Settings/Agents/Controls/Debug.swift` (`+Controls`: pause, ⌥⇧⌘H, energy saver, instant click-through; ADR-022) |
| Character | `CharacterRenderer` (web view bridge), `Assets` (loads the pack + renderer page), `Reaction` (everything the app can ask the character to do) |
| Ask Hush | `CommandPanel` (⌘⇧H panel) + `CommandBoxView` (field, route chip) + `GlobalHotKey`; `AskController` (lanes → runner / hand-off) + `+History`; `AnswerCard` (panel, model) + `AnswerView` (frame, header, footer) + `AnswerShapeViews` (formula/command/fact/steps/prose); `BrowserTaskController` + `BrowserTaskViews` (browser tasks: plan → approve → run) |
| Design system | `DesignSystem` (tokens: colours, tones, type, pills, tags, tiles, motion) + `CardWindow` (card chrome, shadow, spring in/out, placement). Spec: `docs/design-guide.md` |
| Cards | `EnvelopeCard` (variants + rule receipt), `RulesCard` (What I've learned), `HeldBackCards` (tuck-in + weekly), `TaskStatusPill` |
| Windows | `MenuBar` (glyph) + `MenuPanel` (320 pt panel), `RareFindsController` + `PieceArt` (rare finds, piece previews), `WardrobeWindow` (all pieces, free for now), `SettingsModel` + `SettingsWindow`, `HistoryWindow` |
| Other app pieces | `PouchController` (hand it to Hush: click full cheeks → verb card → chew → clipboard; ADR-019), `OverlayPanel` (panel + gestures), `Wanderer` (perch, edge walk), `AnticsController`, `HookInstaller`, `MenuBarIcon` (designer template PNGs in `assets/brand/menu-bar`) |
| Renderer (JS) | `assets/renderer/`: `index.html` + `style.css` + fragments `setup.js` → `compose.js` (composition, frame owner, `refresh`) → `life.js` (overlays, gaze, blink, sequences) → `reactions.js` (reactions + `window.hush` API). Swift inlines them into one closure. |
| Landing page | `site/` (static: `index.html`, `style.css`, `app.js`; `hush.js` draws Hush from the app's own pack like `compose.js`). `site/hush-data.js` is generated: run `python3 scripts/build-site.py` after changing `assets/character` or `Wardrobe.swift`. Links and the waitlist endpoint live in `CONFIG` at the top of `app.js` |
| Hook helper | `Sources/hushctl/main.swift` (hooks), `Gate.swift` (`hushctl gate`: browser-task permission gate) |
| Character art | `assets/character/` (search-ignored); brand (logo, app icon, menu bar glyphs) in `assets/brand/`. **Don't open SVGs**; use `docs/character-inventory.md`. |
| Docs | `docs/decisions.md` (ADRs: read the one you touch), `docs/agent-plan.md` (agent phases), `docs/ask-design.md` (Ask Hush lanes, routing, card shapes), `docs/app-router-plan.md` (answers → the app you work in), `docs/onboarding-plan.md` (install paths + first-run journey), `docs/personas.md` (who it's for), `docs/positioning.md` (how Hush differs from other companions), `docs/lanes-plan.md` (models as settings, "do it" lane), `docs/features.md` (**everything Hush does**; wins on behaviour), `docs/design-guide.md` (**looks: tokens, motion, every surface**) + `docs/design-guide-plan.md` (phases D1 to D7), `docs/PRD.md` (spec; large) |

## Renderer invariants
One frame owner: lifted > sequence > mode (walk/perch) > mood > half-rise > base state; don't add parallel flags.
Floor anchors: edge poses y=112, perches y=116, others y=138. Sequences come from `timing.json`; custom ones use `F(pose, expr, ms)`.

## Commands
- `./scripts/swift.sh test` (core; plain `swift test` also works with Xcode) · `./scripts/bundle.sh` builds, installs to `/Applications/Hush.app`, relaunches it
  (`--no-install` to only build). `./scripts/swift.sh run hush-eval` runs `evals/asks.json` against a real model (costs money); `--lane mail` / `--lane pouch` run `evals/mail.json` / `evals/pouch.json` on the on-device model (free). Hush repoints its Claude Code hooks to wherever it runs from, on launch.
- Logs (renderer errors, paste, agent, hooks): `~/Library/Application Support/Hush/diagnostics.log`
- README media: `swift scripts/render-media.swift` renders `docs/media` GIFs/PNGs from the pack (after new art); `./scripts/record-media.sh` records the feature GIFs from the running app (debug hooks; leaves no trace, ADR-028)
- Cost: `./scripts/measure.sh 40` (CPU and memory of Hush + WebKit helpers; results in `docs/performance.md`)
- Debug hooks: `defaults write dev.hush.Hush HushDebugHooks -bool YES`, then post distributed notification
  `dev.hush.debug` with a command; the list is the `switch` in `AppController+Debug.swift`. Turn it off after, then relaunch Hush
  (the observer lives until restart; `approve`/`answer` can approve browser tasks from any local process).

## Conventions
- `HushCore`: Foundation + SQLite3 only; time injected (`now:`); tests use `HushStore(path: ":memory:")`.
- Backends conform to `AttentionClassifier` / `GistWriter` / `CharacterRenderer`.
- New dependency → the advisory check from the global CLAUDE.md first.
- Toolchain: dev Mac is macOS 27 with Xcode 27.0 (Swift 6.4, macOS 27 SDK). Build through `scripts/swift.sh` /
  `bundle.sh` so binaries record the real SDK; on a CLT-only Mac they also pick the 26 SDK (ADR-017). Deployment
  target stays macOS 15. If SwiftPM fails with "Undefined symbols … PackageDescription" or
  "redefinition of module 'SwiftBridging'", look for stale orphan files under `/Library/Developer/CommandLineTools` (ADR-001).
