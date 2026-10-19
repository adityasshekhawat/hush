# Decision log

Short records of choices that aren't obvious from the code. Newest last.

## ADR-001 · Build on macOS 15 with Command Line Tools first (2026-10-17)

**Context.** The PRD targets macOS 26+ (Foundation Models, FR-4/FR-9) and needs a MailKit extension (FR-1/2/10).
The dev Mac runs macOS 15.6.1 with Command Line Tools only, no Xcode.

**Decision.** Build everything that doesn't need macOS 26 or Xcode now:
`HushCore` (cascade, caps, log), `HushMac` (EventKit, focus), and the overlay app as a SwiftPM executable,
bundled into an ad-hoc-signed `Hush.app` by `scripts/bundle.sh` so TCC grants Calendar access.
The classifier is `RulesOnlyClassifier` (FR-14) behind `AttentionClassifier`.

**Unblocks later.** macOS 26 → a `FoundationModelsClassifier` + `GistWriter` (one new file each, `#if canImport(FoundationModels)`).
Xcode → the MailKit extension target, which will call `AppController.submit(_:)` through an app group / XPC.
Then the two PRD spikes (Mail-while-hidden, on-device accuracy) can run.

## ADR-002 · SVG rig in a WKWebView until a Rive file exists (2026-10-17)

**Context.** The PRD picks Rive, but only a layered SVG pack exists. Rigging in the Rive editor is manual work.

**Decision.** `WebCharacterRenderer` plays `assets/character` in a transparent `WKWebView`, using logic ported from
the Character Lab (`applyLook`, gaze). It sits behind the `CharacterRenderer` protocol, whose inputs
(state, body, palette, eyes, topper, accessory, pointer) are exactly the planned Rive state-machine inputs.
Swapping to `RiveRuntime` later touches one file. Run the dependency advisory check before adding it.

## ADR-003 · Low confidence caps at gentle; it never promotes (2026-10-17)

**Context.** FR-5 says "low confidence resolves to gentle, never interrupt". Read literally, every unsure
ambient item would be promoted to gentle. In rules-only mode (always unsure) that would surface almost everything.
Principle 2 says "When unsure, stay quiet", and the PRD says principles win conflicts.

**Decision.** Low confidence is a *ceiling* (at most gentle), not a floor. An unsure "ambient" stays ambient.
Test: `lowConfidenceNeverEscalatesAmbient`.

## ADR-004 · "In a call" = microphone in use (2026-10-17)

**Context.** FR-7 needs call detection; the PRD's open question asks which apps count.

**Decision.** Primary signal is CoreAudio `kAudioDevicePropertyDeviceIsRunningSomewhere` on the default input.
No permission needed, and it catches browser calls (Meet), which an app list can't. Dictation also trips it,
which errs toward quiet. Screen sharing isn't detected separately yet; it almost always coincides with a call.
When hidden for a call the panel is ordered out entirely (not just the hide pose), so it can't appear in a share.

## ADR-005 · "Type" for shoos = sender (2026-10-17)

FR-11 says three shoos of one *type* lower that type. For mail, type = sender address; all meeting
reminders share one type. Explicit rules (VIP, always-*) are not lowered by shoos. Revisit with real data.

## ADR-006 · Stay visible in full-screen apps by default (2026-10-17)

**Context.** The PRD hides Hush during "full-screen work" (Principle 3). The builder, who is the first user, runs nearly every app
in macOS full-screen (Excel, Cursor, Claude, Figma, Notes…), so Hush vanished on every Space swipe and came
back on normal desktops. It read as broken, and it was absent most of the day.

**Decision.** Default: the panel joins full-screen Spaces (`.fullScreenAuxiliary`) and full-screen no longer counts
as busy. Calls (mic in use) still remove it entirely, so it can't appear in a screen share. Typing still ducks.
Menu → "Hide in full-screen apps" restores the PRD behaviour. Revisit if full-screen *video/presentations* need
their own rule (e.g. detect Keynote/QuickTime/browser video).

## ADR-007 · Antics are permission-free and never interrupt (2026-10-18)

**Context.** The builder wanted more play: cheeks that fill when you copy and blow out when you paste, a pat request
after 30 minutes untouched, and more. macOS gives no paste event; seeing ⌘V needs Accessibility (system-wide key
monitoring), which conflicts with the PRD's "no keystroke monitoring". The builder chose to stay permission-free.

**Decision.**
- Sensors read signals, never content: pasteboard change *count*, power state, audio output running, window
  bounds, the screenshot UI's window owner name, and a Spotlight query for new screen captures.
- Copy → cheeks fill; they blow out on their own after 60 s, or gulp and refill on the next copy.
- `AnticPolicy` (HushCore, tested) splits antics into *invited* (a reaction to something you just did; plays
  any time Hush is visible) and *unprompted* (pat request, morning stretch, Friday dance, tuck-in; only when you're
  not typing, not away, not in a call, and no real appearance is waiting). Pat requests: after 30 min untouched,
  at most 3 a day, 15 s each, ending in a sigh if ignored.
- Nothing playful is logged as a decision or counts toward the interrupt cap.

**Unverified.** Whether the Spotlight screenshot query returns Desktop items to Hush without a TCC prompt; the
screenshot-UI window signal covers ⌘⇧4/⌘⇧5 either way.

## ADR-008 · Blow out on paste via ⌘V key state, only while holding a copy (2026-10-18)

**Context.** After a copy the cheeks stayed puffed through the paste; the builder expected the blow-out on paste.
macOS has no paste notification, and the builder had declined Accessibility (ADR-007).

**Decision.** While the cheeks are full (and only then) Hush polls at 30 Hz whether ⌘ is held and the physical V key
is down (`CGEventSource.flagsState` / `keyState`). These need no permission and no event tap; no other keys are read
and nothing is stored. Polling stops the moment the cheeks empty. Rising edge → blow.

**Update (same day).** ⌘V key state didn't fire on the builder's Mac; macOS likely hides letter-key state from apps
without Input Monitoring. Added a fallback that uses only unrestricted signals: ⌘ held + "a key just went down"
(`secondsSinceLastEventType`) + the clipboard *not* changing within 0.3 s → paste (if it changed, it was ⌘C/⌘X:
a copy, shown as a gulp). Trade-off: other ⌘ shortcuts while holding a copy also blow it out. Decisions are logged
under `dev.hush.Hush` / `play` for diagnosis. The timer fallback is gone: cheeks stay puffed until a paste, or a
click on Hush pops them.

**Limits.** Paste from a menu or right-click isn't seen (click Hush to pop the cheeks).

## ADR-009 · Move to the v3 character pack; blob-only for now (2026-10-18)

**Context.** The designer's v3 pack adds 39 poses, 14 expressions and 10 keyframed sequences with timings, built from
one canvas rig. It is a different format from v2: poses are flattened (only active parts), everything except the rig
is blob-only, oval/pebble eyes and bean/square bodies exist only in the rig, there is no light rim for dark
desktops, and the floor line is back in edge poses.

**Decision.** v3 becomes `assets/character`; v2 is archived (`assets/archive/character-v2`) and still loadable with
`defaults write dev.hush.Hush HushRendererV2 -bool YES`. The new renderer (`renderer/v3.html`):
- composes pose + expression face (the face group sits at translate(60 80) in all 48 files, so any face fits any
  pose) + topper/accessory from the blob rig + eye shape rescaled per style + palette;
- generates the light rim in code; drops the floor line and the drawn cursor/window props (the desktop has real ones);
- builds the SVG skeleton once and swaps only the pose under stable wrappers, so blink/gaze/overlays survive frames;
- has one owner for the frame: lifted > sequence > mode (walk/perch) > mood > half-rise > base state;
- anchors poses to the floor by kind: edge poses y=112, perches y=116 (window top), the rest y=138;
- plays the designer's keyframes directly from `timing.json`.

Body choice is locked to blob (bean/square listed as "waiting for art") until bean/square poses are exported.
Typing still ducks into a lowered peek (eyes showing), not v3's sprout-only `hide`, which is reserved for calls.

**Measured.** Idle CPU in peek is unchanged from v2 (Hush ~4–6 %, WebContent ~7 %).

## ADR-010 · All three bodies from the per-body v3 export; drop-to-perch (2026-10-18)

**Context.** The designer re-exported v3 with every pose and expression on blob, bean and square (same layer ids;
blob files identical to before). The animation keyframes are still blob-only. Within a body the face sits at the same
spot in every file, but it differs between bodies (blob 60,80 · bean 60,64 · square 60,84), so faces must come from
the same body. Peek is authored so the face lands at the same height above the edge on all three.

**Decision.** Body choice is unlocked. The renderer picks poses, faces and rig parts by body, and rebuilds each sequence
frame from `timing.json`'s (pose, expression) on the current body instead of playing the blob keyframe files; only the
command box is lifted from those keyframes (it isn't in any pose). Supersedes ADR-009's blob-only lock.

Drop-to-perch: dropping Hush with its floor line within 28 pt of the top edge of the front-most window under it
(not full-screen, not under the menu bar) perches it there. A perch you placed is *pinned*: it ignores keys and
clicks (you chose the spot) and only ends when the window goes away or you drag Hush off. The idle perch still
hops down on any input. Dropping elsewhere keeps the old behaviour (falls to the floor, new home spot).

## ADR-011 · Resource budget: near-zero when nobody's looking (2026-10-18)

**Measured before.** Hush + its three WebKit helpers used ~20 % of a core continuously while idle in peek
(energy impact ~20, ~97 wakeups/s), mostly from infinite CSS loops repainting the SVG at 60 fps, a 30 Hz pointer
poll, a 4 Hz full window-list scan, a 30 Hz paste-key poll and `.latencyCritical` defeating timer coalescing.

**Decisions.**
- *Calm mode:* when the cursor hasn't been within ~250 px for 15 s and nothing is happening, looping animations are
  removed (not paused: WebKit keeps a 60–120 Hz display link for paused animations). Blinks and glances still play.
  Everything stops while the window is ordered out for a call.
- *No persistent loops inside the SVG:* breathing and the music groove run on HTML wrappers the GPU moves without
  repainting; envelope/clock/zzz hold still; peek bob and duck check-up are occasional one-shots. Loops left in the
  SVG (hurry, tap, asking, sequences) are short-lived and stepped.
- *Eyes:* only within ~450 pt does the app send pointer updates; gaze eases per update (≤20 Hz), no per-frame loop.
- *Polling:* pointer 5 Hz still / 20 Hz moving; window scan 1 Hz, 4 Hz only while a mouse button is held; paste keys
  10 Hz, 30 Hz only while ⌘ is held; timers have tolerance; no `.latencyCritical`.

**Measured after** (60 s, real use, mouse moving ~30–50 %): quiet stretches ~1.5–3 % total, median ~3.5 %,
bursts to ~10–15 % only while you move the mouse right next to Hush or it's playing a sequence. Memory ~70 MB across
the four processes; 84 KB of data on disk; no launch agents or background services.

## ADR-012 · Pull "talking to Hush" (agent) ahead of mail (2026-10-18)

**Context.** The PRD puts chat in v2 and agent reactions in "Later", and lists "scope creep into chat and agents → v1
never ships" as a risk. Mail (MailKit) is still blocked on macOS 26 + Xcode, while Claude Code is installed and the
builder uses it all day.

**Decision.** Build the agent next, in small standalone phases (docs/agent-plan.md): first Hush *reacting* to the user's
own Claude Code sessions (no model calls), then read-only "Ask Hush", then isolated background tasks. The CLI backend
runs under a builder-only flag; an API-key backend is required before any public release (PRD: subscription credentials
can't be used by third-party apps). All agent events go through the DecisionEngine, so the principles and the interrupt
cap still hold. Mail returns to the front of the queue once the Mac is on macOS 26 with Xcode.

## ADR-013 · Organise the repo for cheap context (2026-10-18)

Agents (and people) working on Hush should only load what a task needs.
- `AppController` (806 lines) is split by concern into extensions (`+Engine/Gestures/Pointer/Placement/Settings/Agents/Debug`).
- The renderer is `index.html` + `style.css` + four JS fragments that Swift inlines into one closure, instead of one 774-line file.
- The v2 renderer and archived v2 pack are removed (git history keeps them); supersedes the v2 switch in ADR-009.
- `.ignore` keeps ripgrep (Claude Code's Grep/Glob) out of `assets/character/` and `docs/character-lab.html` (~1.2 MB);
  `docs/character-inventory.md` lists what's in the pack instead.
- `CLAUDE.md` is a short map of where things live.
- Agent runs (Phase 2) use a lean Claude Code profile: only the tools the task needs (`--tools`), no MCP servers
  (`--strict-mcp-config`), project settings only (`--setting-sources project`, which also skips the user's global
  CLAUDE.md, plugins and hooks) and a short system prompt. Measured on an empty prompt: **33,250 → 8,098 context
  tokens per run**. `--bare` would go further but skips keychain login, so it needs an API key (Phase 5).

## ADR-014 · Ask Hush v2: three lanes, routed in code, answers shaped for their card (2026-10-18)

**Context.** One generic text card for every answer felt lazy and ignored context. People ask mostly short practical
questions mid-task (NBER: ~80% guidance, information, writing), switch apps ~1,200 times a day, and many use more than
one assistant. ChatGPT can't answer inline without Sign in with ChatGPT or an API key.

**Decision** (docs/ask-design.md).
- Lanes: **quick** (Haiku, no tools, `--json-schema` → `AnswerShape`: formula / command / fact / steps / prose; ~1–3 s,
  under $0.001, ~1.6K context), **repo** (Phase 2 read-only Sonnet run), **hand-off** (ChatGPT web, Claude app,
  Perplexity, pre-filled; "Continue in…" carries Hush's answer along).
- Routing is code (`AskRouter`, tested), shown live as a chip before Enter; `@gpt/@claude/@pplx/@code/@<repo>` and Tab override.
  Code questions need a strong signal or a code word plus a pointer to *your* project ("my", "this", "last 3 commits"),
  so general how-tos ("undo a git commit") stay quick (the first version sent them to the repo agent at ~30× the cost).
- The frontmost app at ⌘⇧H is context (shown as "from Excel"); window titles and selections are not read.
- Cards: no focus stealing, self-sizing, per-shape layouts, Copy (Hush's own copies don't trigger the cheeks),
  hand-off receipt that steps aside after 4 s. Hush: thinks while working, hands the answer over, waves hand-offs off.

## ADR-015 · Onboarding is a character-led card journey; distribution waits for notarization (2026-10-18)

**Onboarding (O1, built).** No wizard window: Hush stands beside a non-activating card through seven skippable steps
(arrival, make it yours, one persona question, say hi with live checks, just-in-time connections, quiet promise,
goodbye). Personas map to presets in code (`OnboardingPreset`, tested). Progress persists (resume after quit),
first-week tips appear once each, and the menu has a setup checklist and "Replay the intro". The card's primary button
uses a custom style because AppKit draws prominent buttons grey in a window that never takes focus.

**Distribution.** Unsigned/ad-hoc downloads are blocked on macOS 15 (only System Settings → Open Anyway), and
Homebrew dropped casks that fail Gatekeeper on 1 Sept 2026. Without the Apple Developer Program, the legitimate open-source
path is **build from source on the user's Mac** (locally built apps aren't quarantined): `git clone` + the bundle script,
or a Homebrew *formula* that builds from source. Downloading a prebuilt app with `curl` to avoid the quarantine flag
is deliberately not used: it sidesteps a security check users rely on. Notarized downloads remain the goal for
non-developer personas.

## ADR-016 · "While you were away" reads transcripts only when you opt in; digest is local (2026-10-18)

Phase 1 hooks pass only session id, folder, event and host app; Hush never reads session content by default.
The digest is the first feature that does, so it is **off by default** behind a consent dialog (Agent menu). When on,
coming back after ≥10 minutes away scans transcripts in `~/.claude/projects` touched in that window (≤12 files, last
12 MB each), and builds per-session digests locally with no model: title (Claude Code's `ai-title`), your prompts
(skipping meta/command records and subagent sidechains), files edited, commands and commits, PR links, Claude's last
message, status. The project is re-anchored to the git root. A gentle "While you were away" envelope goes through the
engine; clicking it opens the digest directly. **Summarise** is the only network step: a capped excerpt of one
session to Claude Haiku.

## ADR-017 · Build on macOS 27 with CLT 27 against the macOS 26 SDK (2026-10-19)

**Context.** Development moved to a Mac on macOS 27.0.1 with Command Line Tools for Xcode 27.0 (Swift 6.4), still no
Xcode. Its default macOS 27 SDK declares SwiftUI's `@State` as a macro (`SwiftUIMacros.StateMacro`), and with that SDK
swift-testing's `@Suite`/`@Test` plugins aren't found either. The SwiftUI macro plugin ships only with Xcode, so
`swift build` and `swift test` fail. The same CLT also installs the macOS 26.5 SDK, which has neither problem and
already has `glassEffect` and `FoundationModels`.

**Decision.** `scripts/sdk.sh` sets `SDKROOT` to the CLT's macOS 26 SDK when only CLT is selected and no `SDKROOT` is
set; `bundle.sh` sources it and `./scripts/swift.sh test` wraps `swift`. With Xcode selected nothing changes.
Even on the 26 SDK, CLT 27's default build system intermittently loses swift-testing's macro plugin ("plugin for module
'TestingMacros' not found"), and once it does every incremental build fails until `.build` is deleted. `swift.sh`
passes `-Xswiftc -plugin-path <CLT>/usr/lib/swift/host/plugins/testing` for build/test/run, which fixed it in 6 of 6
clean and incremental runs. It also passes `-platform_version macos 15.0 <SDK version>` to the linker: without it
the binaries recorded `sdk 15.0` (the deployment target), so macOS would treat Hush as a macOS 15 app; now they
record 26.5 (`otool -l … | grep -A5 LC_BUILD_VERSION`). `bundle.sh` builds through `swift.sh`.
Swift 6.4 also flagged three fire-and-forget throwing `Task`s that silently dropped store errors; they now log to
diagnostics.log. The
deployment target stays macOS 15 (`Package.swift`); macOS 26 features go behind `#available` checks. CI stays on the
`macos-15` runner. Measured: clean build and all 129 tests pass on Swift 6.4 + the 26.5 SDK.

**Revisit** when Xcode is installed (MailKit needs it anyway, ADR-001): build against the 27 SDK and drop the override.
Supersedes ADR-001's "macOS 15, CLT only" for this Mac; the unblocks it lists (Foundation Models, glassEffect) are now
possible without Xcode.

**Update (same day): Xcode 27.0 installed and selected.** With Xcode, the macOS 27 SDK builds and plain `swift test`
passes (it ships `SwiftUIMacros`), so `sdk.sh` and the testing plugin path switch themselves off. The linker problem
is SwiftPM's build system, not CLT: with Xcode the binaries still recorded `sdk 15.0`, so `swift.sh` now passes
`-platform_version` in both setups (`xcrun --show-sdk-version`); Hush records `sdk 27.0`. Always build the app through
`bundle.sh` / `swift.sh`.
