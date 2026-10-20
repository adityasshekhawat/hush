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

## ADR-018 · Apple's on-device model judges mail and writes its gist (2026-10-19)

**Context.** ADR-001 deferred FR-4 (classify on-device) and FR-9 (gist on arrival) until macOS 26. This Mac now runs
macOS 27 with Apple Intelligence on, and the SDK has Foundation Models.

**Decision.** `OnDeviceTriage` (HushMac) is both the `AttentionClassifier` and the `GistWriter`: one call per mail
returns ambient or gentle, whether it's sure, and a one-line gist (the card shows the gist under the subject and
sender, so it names neither). Prompt, schema guidance and parsing are pure in `HushCore/MailTriage` (tested).
- **Only mail** reaches it; meetings and agents keep their levels in code. It can't ask for interrupt (the schema
  offers ambient or gentle only, and the engine caps models at gentle anyway, FR-5). "Sure" maps above the 0.7
  threshold, "unsure" below, so ADR-003 still reads the same.
- **On this Mac only:** `SystemLanguageModel.default`, never Private Cloud Compute. Sender, subject and a 400-character
  snippet. Greedy sampling, so the same mail gets the same answer.
- **Never waits:** a session is prewarmed at launch and after each call (cold ~5 s, warm ~1.3 s); over 4 s, a
  refusal, an unsupported language or the model going away → the rules answer and it's logged. The decision log
  records `on-device-1` or `rules-1`.
- **No macros:** the schema is a `DynamicGenerationSchema`, because `@Generable` needs Xcode's macro plugin and
  CLT-only Macs should still build (ADR-017).
- **Scrutable:** Settings ▸ Connections ▸ Apple Intelligence shows "On this Mac" with Turn off, or why it can't run
  (off in System Settings, getting ready, not available). Default on.

**Measured** (`swift run hush-eval --lane mail`, evals/mail.json, 24 mails written by us, so treat it as a smoke test):
23/24, 0 shown that could wait, p50 ~1.4 s. Tuning got the two real asks the first prompt missed ("are you joining
the 2pm? We're starting now", "call me when you can") and the calendar update; a casual "lunch?" now reads as an
unsure ambient (rules-only also missed it). An example phrase that copied an eval case was replaced so the score
isn't flattered. Add a case whenever a real mail is judged wrong. Idle cost unchanged: Hush 38 MB, <1 % CPU.

**Next.** Mail itself (MailKit, now possible with Xcode) feeds real mail into this. Later: the same model for the
quick lane, route check and digest summaries, which today use the user's Claude Code login (not shippable, ADR-012).

## ADR-019 · Hand it to Hush: rework what you copy, through the cheeks (2026-10-19)

**Context.** People rework copied text many times a day (simpler, shorter, bullets, fix, translate), usually by
switching to a chat app: copy, switch, paste, type the ask, wait, copy, switch back, paste. Hush already reacts to
copies (cheeks fill, ADR-007) and pastes (they blow out, ADR-008). Apple's on-device model can now do the rework
(ADR-018). Research pass (secondary, mostly Reddit snippets): proofread and tone rewrites are the most-used Writing
Tools, people dislike swapped text with no way back, and on-device clipboard transformers exist, so Hush's edge is
the character and the fewer steps, not the transform itself.

**Decision.** With full cheeks, a click on Hush opens a small card: **Simpler · Shorter · Bullets** (plus
**Original** after a rework, and Never mind, which pops the cheeks as before). Picking one: Hush **chews** (puff
pose, a squash loop on the HTML wrapper, capped at 25 s, ADR-011), hands over, and the result is on the clipboard
with a "Press ⌘V" bubble; the paste blows the cheeks out. Four steps, no app switch.
- **Reads more of your data, so it asks:** the clipboard's *text* is read only at that click (sensors still see only
  the change count). The first click shows a consent card; "Not now" turns it off. Settings ▸ Ask Hush ▸ Rework what
  I copy. Text is never logged, only lengths.
- **On this Mac:** `OnDeviceRewriter` (HushMac), `SystemLanguageModel(guardrails: .permissiveContentTransformations)`,
  greedy, a session prewarmed while you pick, 20 s cap. Verbs, limits, prompt and cleanup are pure in
  `HushCore/Pouch` (tested).
- **Never makes things worse:** code is recognised and left alone (a "shorter" function came back on one line);
  over 6,000 characters or with Apple Intelligence off, the card offers your assistant instead (the text is already
  on the clipboard, so only the instruction goes in the link); if you copy something else while Hush chews, the
  result is dropped; a rework always starts from the original, and **Original** puts it back.
- Delight only: nothing here is a decision, an appearance or part of the cap.

**Measured** (`swift run hush-eval --lane pouch`, evals/pouch.json, 12 snippets we wrote): 12/12 after two fixes
(a firmer "shorter"; code detection), every number and date kept, Spanish stayed Spanish, p50 ~2.2 s. End to end in
the app via the `pouch:<verb>` debug hook: 207 → 102 characters in 3.4 s, no self-triggered gulp.

**Next** (from the research): a **Fix** verb that shows what it changed before handing back; text from a copied
screenshot (image on the clipboard → OCR, permission-free); content-aware chips (Translate, To-dos).

## ADR-020 · Paste guessing knows ⌘Tab; hand it to Hush doesn't depend on the guess (2026-10-19)

**Context.** The user reported that Hush "doesn't capture" copies. The log showed every copy detected (the pasteboard
change count, buttons included), but the cheeks were emptied about a second later by a guessed paste: ADR-008's
fallback counts any ⌘ shortcut that doesn't change the clipboard within 0.3 s as a paste, and ⌘Tab right after a
copy is the common case. With hand it to Hush (ADR-019) a wrong guess hides the verb card.

**Decision.**
- `PasteGuess` (HushCore, tested) decides: clipboard changed → copy; another app came forward
  (`NSWorkspace.didActivateApplicationNotification`, no permission) since the shortcut → ⌘Tab, not a paste; ⌘ still
  held → wait (⌘Tab switches on release), giving up after 4 s; otherwise a paste 0.35 s after ⌘ comes up.
- For 2 minutes after a copy, a click on Hush offers the verb card even if a guess emptied the cheeks (they puff back).
- Each verb-card click logs the macOS pasteboard access behaviour (15.4+ privacy) and whether text could be read
  (lengths only). If macOS denies the read, the card says so instead of failing quietly.

**Limits.** ⌘W, ⌘S, ⌘F and other in-app shortcuts can still read as a paste; the 2-minute window covers them for the
verb card. Real-world accuracy not yet measured (a scripted check needs the user's keystrokes).

## ADR-021 · v1 scope: the feature spec, reconciled with Hush's principles (2026-10-19)

The v1 feature spec (agent watcher, meetings, mail, never-in-the-way, performance, first run, journal) is adopted
with these decisions, made for the user and for open source. Each was weighed against its strongest objection.
- **Kept:** agent watcher first (risk is judged by rules in code; the model only writes the one-liner), meetings at
  T-5/T-1 with one-click join links (the T-1 visit leaves once the mic turns on or 5 min after start), mail last and
  metadata-only by default (snippet opt-in), pause / dismiss / click-through, battery mode and stopping when locked,
  published CPU and memory numbers, "tell Hush what matters" (the model proposes rule sentences you edit; rules run
  in code), a 7-day local journal of what Hush saw (metadata, never snippets or model inputs, with Forget), hand it
  to Hush, perching (can be turned off).
- **Changed:** the mail digest comes at natural breaks (back from away, a call ending), at most hourly, gentle, not
  on a clock. The model may bring mail forward gently with a reason but never interrupts; VIPs and rules still do,
  and "Always show this sender" is one tap. Agent hooks forward the tool name and the first ~200 characters of the
  command over a local Unix socket, in memory only, never stored (replaces the spoofable distributed notification).
- **Off by default:** the Claude-backed lanes (Ask Hush quick and repo questions, Summarise, browser tasks), behind
  one opt-in that says it sends the question to Anthropic through your Claude Code. Quick answers and Summarise move
  on-device; hand-offs to your own assistant stay.
- **Dropped:** process-scraping fallback (no polling where an event source exists), paid cosmetics (every piece is
  free and in the repo), chat paper airplanes (no source).
- **Not v1:** Deep Work mode.
- **Defaults:** quiet hours stay 22:00–07:00. No Accessibility permission: "avoid the focused field" is approximated
  by ducking while typing and avoiding the cursor. Hush is "it".
- **Open source:** code Apache-2.0; the Hush character, name and logo reserved,
  so forks bring their own; wardrobe, props, effects and edge art CC BY-SA 4.0, open for contributions (ADR-023). From-source Homebrew formula now; a notarised cask once there's an Apple
  Developer account.
- **Art:** the spec's props (flags, door, pocket watch, satchel, bin, journal, blind) come from `docs/v1-art-brief.md`;
  behaviour ships first with existing props as placeholders.

## ADR-022 · Never in the way, and cheap: pause, the hush key, energy saver, off-screen means off (2026-10-19)

Milestone 1 of the v1 spec (ADR-021, features 4 and 5).
- **Pause** 15 minutes, 1 hour or until tomorrow (08:00; in the small hours, this morning) from the menu bar panel.
  `UserFocus.paused` hides Hush like a call does: things queue and show when the pause ends; a meeting that already
  started is dropped as stale. The end time survives a relaunch; the menu bar glyph sleeps and the panel says
  "Paused until 15:30". Pure parts (`PauseLength`, `PauseText`) are tested.
- **⌥⇧⌘H, the hush key:** puts away whatever Hush is showing (the appearance counts as ignored, not shooed, so it
  doesn't lower that sender); with nothing showing it pauses for an hour; paused, it brings Hush back. ⌘⇧H stays
  Ask Hush. `GlobalHotKey` now installs one Carbon handler for every hotkey (a second handler failed to install).
- **Locked or asleep** (`com.apple.screenIsLocked`, `screensDidSleep`, no polling) hides Hush; **off screen means
  off:** while paused, locked or in a call, the pointer timer and the play sensors (clipboard, windows, screenshots)
  stop and restart fresh.
- **Energy saver** in Low Power Mode or under 20 % battery: the renderer stays calm (no looping animation, no idle
  fidgets), pointer checks run at half rate. Alerts and reactions still play. Plain battery power doesn't trigger
  it: idle cost is already near the floor, and Hush shouldn't feel lifeless on every laptop away from a charger.
  This deviates from the spec's "on battery".
- **Tapping on the glass** knocks in two-knock bursts every 6 s instead of a constant loop (12.7 % → 5.8 % CPU).
- **Click-through:** near Hush, a global mouse-moved monitor (no permission) flips click-through on every move instead
  of at the next 5 Hz poll, so a click just beside Hush isn't swallowed; it's installed only while the cursor is
  within reach. Not measured with real clicks.
- Measured in docs/performance.md with `scripts/measure.sh`; the numbers were taken during use and are upper bounds.

**Not done from the spec's features 4 and 5:** configurable auto-retreat, a debug overlay for frame rate, and the
blind / sign / sleeping-cap art (docs/v1-art-brief.md, priority 1).

## ADR-023 · Hush is reserved; the art around it is open (2026-10-19)

Supersedes ADR-021's "character art CC BY-SA 4.0". Following Coucou's model (an open-source Mac agent companion
that keeps its character, name and icon reserved under an MIT codebase) and the PRD's own risk ("open source makes
copies easy → name and character art licensed separately"): the code stays Apache-2.0; **Hush itself** (body shapes,
face, expressions, poses, rig, animations, palettes as its look) and **the name, logo, icon and menu bar glyphs** are
reserved (`LICENSE-ASSETS.md`), so a fork can't ship Hush under another name. **Everything that isn't Hush's original
shape**, wardrobe pieces, props, effects, edge pieces (`assets/character/swag/`, `edge/`), is CC BY-SA 4.0 and open
for contributions, drawn to fit Hush's bodies without changing them. `TRADEMARKS.md` is folded into
`LICENSE-ASSETS.md`.

## ADR-024 · The agent watcher says what it's asking, flags risk by rules, and moves to a private socket (2026-10-19)

Milestone 2 of the v1 spec (ADR-021, feature 1).
- **What it asks:** Claude Code 2.1.303 has `PermissionRequest` (tool_name, tool_input) and `StopFailure` (error).
  hushctl forwards the tool and up to 200 characters of the relevant input (command, file path, URL, query;
  `AgentRequest.detail`, one cleaned line) for permission requests, and the error type for failures. Never the
  prompt, replies or other tool input. Hush keeps it in memory; it isn't logged or stored. hushctl still prints
  nothing: for PermissionRequest, silence means "no decision", so Hush can't approve anything.
- **One-liner by rules, not the model** (a deviation from the spec): "Claude wants to run rm -rf build" shows the
  exact command, instantly, and can't paraphrase a dangerous request into a harmless one.
- **Risk by rules in code** (`AgentRisk`, tested with positives and near-misses): deletes files, force-pushes,
  throws away changes, runs as admin, drops data, deletes every row, runs a downloaded script, changes
  infrastructure, publishes, erases a disk, opens up permissions, touches production, touches secrets. File tools
  only check production and secrets. Risky approvals: red "Look carefully" card, no "Not this kind again", and
  switching to the terminal doesn't clear them.
- **Errors:** `StopFailure` becomes a quiet card ("Claude stopped in hush · Hit a usage limit") unless you're watching.
- **Order and staying:** among equal levels, risky > needs you > finished > stopped. Approvals don't time out; they
  clear on the next tool call. The envelope adds "Also waiting: api (needs you), web (finished)". Going to the app a
  session runs in clears its cards only when it's the only waiting session in that app (Hush can't see which tab
  you're on). Open selects the exact Terminal or iTerm tab by tty (macOS asks once to allow the automation),
  otherwise brings the app forward (Ghostty, Warp, Cursor, VS Code).
- **Transport:** a Unix socket (`AgentChannel`, 0600 in Application Support) replaces the distributed notification,
  which any app could observe; the command detail must not be broadcast. Validation moved into HushCore and is
  tested; the receiver's dispatch handler is built outside the main actor (the first build trapped on Swift 6.4's
  isolation check on the first event).
- **Hooks update:** new events are added only through the existing diff-and-confirm installer: Settings ▸
  Connections shows Update for an older install, and a one-time tip says so. The install text now names the detail.

**Not done (spec feature 1):** the flag rail and its art (`docs/v1-art-brief.md` priority 2; the envelope's "Also
waiting" line stands in), a model one-liner, Codex error events (Codex has no StopFailure here), and verifying exact-
tab focus in a real Terminal and iTerm.

## ADR-025 · Meetings: T-5 and T-1, one-click join, stays until you're in (2026-10-19)

Milestone 3 of the v1 spec (ADR-021, feature 2).
- **Timing:** heads-up (gentle) 5 minutes before, come out (interrupt) 1 minute before, both configurable in
  Settings ▸ General. Settings saved with the old untouched defaults (10 / 2) migrate once; your own choices stay.
  The T-1 card replaces the T-5 one for the same meeting.
- **Join:** `MeetingLinks` (tested) finds the call in the event URL, then the location, then the notes, from known
  providers only (Zoom, Meet, Teams, Webex, Whereby, Around, FaceTime, Slack huddles, Jitsi, Gather), so a random
  link is never taken for the call. At T-1 a click on Hush opens it directly; the card says Join (or Open in Calendar
  without a link). Finding a link the regex misses with the model is not done: known providers cover the common case.
- **Stays until you're in:** the T-1 appearance has no timeout. It goes when you join (the mic turns on within 10
  minutes of the start), snooze ("1 more min", which brings it back after a minute), dismiss, or 5 minutes after the
  start (the late window). It counts toward the daily cap like any interrupt.
- **Context line:** at T-5, Apple's on-device model writes one line from the invite's notes (`MeetingContext`), after
  `MeetingLinks.trimNotes` drops links, dial-in numbers and passcodes. Title and notes only, never stored. The plain
  gist no longer shows "Someone: <title>" for meetings.
- **Skips:** declined, cancelled, all-day and "free" events. Hush is its own window, so Focus and Do Not Disturb don't
  hide it (the spec's acceptance criterion holds by construction).

**Not done:** the door and pocket watch art (`docs/v1-art-brief.md` priority 3; the clock and hurry poses stand in).

## ADR-026 · First run and the "What Hush saw" journal (2026-10-19)

Milestone 4 of the v1 spec (ADR-021, features 6 and 7). Most of first run already existed (ADR-015: character-led
journey, persona presets, one-click hooks with the diff, Calendar with a preview, mail deferred).
- **Journal:** the decision log gains a `title` column (added in place) so each entry reads as what it was. The menu
  bar's *What I saw* window lists the last 7 days by day: what it was, where from, what Hush did ("Showed it", "Held
  it back", "Waited until you were free", "Let it go") and why in plain words (`Journal`, tested: "On your VIP list,
  today's interrupts were used up"). Entries older than 7 days are deleted at launch and whenever the journal opens;
  Forget empties it (rules and shoo signals stay; they belong to What I've learned). Stored: the title (subject,
  meeting title or agent card), category, outcome and reasons. Never snippets, notes or model inputs.
- **Tell Hush what matters:** in What I've learned, text that isn't already a rule sentence goes to Apple's on-device
  model, constrained to RuleText's forms and to addresses, domains and projects you wrote (`RuleSuggestions`). Each
  sentence is parsed in code (with a tidy-up for "project folder" tails) and shown with Add and Skip. Measured with
  `swift run hush-eval --lane rules`: 4/5; the miss is Apple's guardrails refusing "hide the newsletters from shop.com"
  even with `permissiveContentTransformations`, which the card reports as "I couldn't make a rule from that".
- **First alert:** if nothing is waiting when setup ends, Hush holds up an envelope once, with a bubble saying it's how
  it shows things. Not logged, not counted.

**Not done:** the sniff and journal-cover art (`docs/v1-art-brief.md` priority 4).

## ADR-027 · Mail: the filter and digest are built; the source isn't (2026-10-19)

Milestone 5 of the v1 spec (ADR-021, feature 3), built against the engine with simulated mail.
- **Immediate:** VIPs and your rules, now including **words in the subject** (`UserRule.Match.subjectContains`,
  "always tap the glass for mail about outage"). An explicit "always" rule now wins over the bulk-mail filter
  (status alerts come from noreply@); "never" and unruled bulk mail are still dropped. The model may bring a mail
  forward gently with a reason, never interrupt (ADR-021), and the card offers **Always show them** (a sender rule,
  with the receipt).
- **Metadata only by default:** the triage prompt is sender and subject; the first 400 characters go in only with
  Settings ▸ Connections ▸ "Let Apple Intelligence read the first lines of each mail". Measured on evals/mail.json:
  22/24 (2 real asks missed, 0 shown that could wait) without, 23/24 with.
- **Digest at natural breaks** (`MailDigest`, tested): coming back from 10+ minutes away or a call ending, at most
  hourly, if 3 or more mails were held or dropped since the last one: "14 mails while you were busy · 2 might need you
  · 9 could wait · 3 newsletters", listing up to 3 that might need you. Gentle, computed in code; it's the journal's
  data, so it needs no extra storage. Quiet hours hold it like anything else.

**Not done: the mail source.** A MailKit extension is an app-extension target (Xcode project), sandboxed, so it
needs proper signing and an app group to reach Hush, and the user has to enable it in Mail ▸ Settings ▸ Extensions.
It can't be finished or verified unattended. Until then the Developer menu's simulated mail exercises all of the above.

## ADR-028 · README media recorded by Hush itself; simulations leave no trace (2026-10-20)

- **Recorder** (`MediaRecorder`, debug hooks only): Hush snapshots its own windows into a GIF, so no Screen Recording
  permission is needed and the GIFs show exactly what the app draws. Cards and bubbles come from AppKit's view cache;
  the character from `hush.snapshot()`, which serialises the live SVG with each part's on-screen transform
  (`getScreenCTM`, so hops and squashes survive), its opacity, and without anything the page's CSS hides. WebKit's
  own snapshot was tried first and drew stale, doubled poses. Windows are picked by `orderedIndex` (`orderedWindows`
  skips panels) and not by `alphaValue` (a bubble faded in through the animator reads 0 while visible). Recordings
  use the light appearance and the brand look (your look and rare finds are restored after).
- **`scripts/record-media.sh`** plays six scenarios through debug hooks and the real agent socket, saves and restores
  the clipboard, and ends by removing every simulated record (`forgetDemoData`: demo item ids, scripted session ids).
- **Lesson:** the first script reset scenes with "shoo", and shoos teach Hush to lower that kind of item; test runs
  had lowered real meeting reminders on this Mac. The 51 simulated decisions and 6 test shoos were removed (5 real
  entries kept, backup taken first). Resets now dismiss without a learning signal.
- Found while reviewing frames and fixed: card times were 12-hour without AM/PM (21:07 showed "09:07"; now the
  locale's short time), model text could contain an em dash (cleaned to a comma), the digest card repeated its title,
  and the Hand it to Hush card clipped "Bullets".

## ADR-029 · Open brings the session forward through Launch Services (2026-10-20)
- **Problem:** Open on an agent card did nothing. Hush is never the active app (its cards don't take focus), and since
  macOS 14 `NSRunningApplication.activate()` from a background app is ignored. The tracker also dropped a session's tty
  at SessionEnd, so a "finished" card had nowhere to go.
- **Decision:** `SessionInput.focus` tries the exact Terminal/iTerm tab by tty first (AppleScript, may ask for
  Automation once), then `SessionInput.bringForward`, which opens the host app through `NSWorkspace.openApplication`
  with `activates = true`. `AppController.sessionTTYs` keeps the tty after a session ends, for the envelope and digest.
  Every attempt is logged (`session focus:`). Debug hook `focus:<bundle>|<tty>`.
- **Verified:** from Finder, Open brought the Claude app forward, and Terminal forward on tab `/dev/ttys000`.

## ADR-030 · The v1 character art: variants, edge props, the flag rail (2026-10-20)

Art from `docs/v1-art-brief.md`, delivered as new files only (notes: `docs/v1-art-notes.md`).
- **Renderer:** `timing.json` sequences 11–29 load by name; frames may carry `wear` (rig piece or the extra nightcap and
  satchel files), `dx` (walk in or off) and `edge` (blind, door, flag, bin, drawn in `#slot-edge` with a rim; the blind
  goes between face and arms while the sign is clipped on). Words on cards, signs, flags and bins are drawn by the app
  as plain `<text>`, one element per line, so the README recorder's Core SVG rasteriser places them too.
- **Variants, not flags:** held states take a variant from the app (`CharacterVariant`, HushCore, tested), part of the
  base state in the one frame owner. The entrance plays once; the held pose is still. Idle fidgets only move the eyes
  while Hush holds something up, so it never puts the card down.
- **Where each plays:** approvals raise a hand (risky: worried, "Look carefully" card); errors shrug; meetings check the
  watch (T-5) then hold the door (T-1), ajar when late, with an occasional foot tap instead of knocks; snooze shows
  one finger; shoo and "Not this kind again" tumble out; pause pulls the blind (Hush hides 2.2 s later, off screen
  still means off); resume rolls it up; energy saver yawns once and keeps the nightcap on; a finished run behind
  something else is planted as a flag, a third within 15 minutes gets a cheer (at most hourly); rule suggestions put
  the glasses on; the mail digest walks in with a satchel sized by count and tosses what could wait into the bin;
  onboarding arrives walking in and holds up "Found Claude Code"; Hand it to Hush chews, then hands back a note.
  Mail urgent (hurry in, hold out the envelope) is wired for when real mail lands. All of it is delight: none of it
  interrupts or counts.
- **The flag rail** (`FlagRailController`, `FlagRail` in HushCore): agent sessions waiting behind the one Hush holds,
  newest nearest Hush, 64 pt apart, at most 5, then a "+N more" bundle. Its own borderless panel at Hush's home spot,
  click-through except over a flag (the pointer poll), hidden with Hush, left out of screen shares like every Hush
  window. A click moves that item to the front and opens its card. It replaces nothing: "Also waiting" stays on cards.
- **Menu bar:** a paused glyph while paused. **Journal:** the notebook cover in the empty state, words drawn by the app.
  Hush holds the notebook when the journal opens.
- **Liquid Glass** (`hushSurface`): on macOS 26 and later the envelope, answer, rules and held-back cards, the command
  box (interactive, faint lilac), the menu panel and the speech bubble use glass and drop the hairline and shadow;
  macOS 15 keeps material. The task pill is unchanged. README recordings fall back to material (`SurfaceStyle`): the
  recorder reads AppKit's view cache, which can't see glass.
- **App icon:** `assets/brand/Hush.icon` (Icon Composer: lilac fill, body and face groups). `bundle.sh` compiles it with
  `actool` when Xcode is present (Assets.car + a flattened `Hush.icns`) and falls back to the PNG iconset otherwise.
- **Licence:** poses, expressions and sequences of Hush are reserved with the character; edge props, the nightcap and
  satchels, and `assets/ui` are CC BY-SA 4.0 (ADR-023). The art notes' blanket CC BY-SA line is narrowed accordingly.
- **Verified:** every sequence played in the app with no renderer errors; snapshots checked for the card, sign, flag
  and door; the rail shown with two flags and opened from a flag; pause and resume run end to end; 180 tests pass.
  The nightcap is also a free head piece (46 wearables): its layer is in every rig file at opacity 0, so the app, the
  landing page and Rive read it like any other; in energy saver it takes the place of whatever hat you wear.

## ADR-031 · The website's tour video is recorded by Hush itself (2026-10-21)

- **How:** `scripts/record-video.sh` drives the running app through debug hooks, like the README GIFs (ADR-028), and
  `MediaRecorder` writes an MP4 as it goes (`VideoWriter`, H.264, 1280 × 720 from a 768 × 432 pt frame around Hush,
  about 28 fps). Titles are drawn on the frames (`caption:`), the desktop is drawn, and cards fall back to material
  because the recorder can't see glass.
- **Privacy by construction:** only Hush's own windows are ever captured, over a drawn wallpaper and blank windows.
  For perching, Hush opens a blank window of its own (`stage:open`, `StageWindow`); the recorder draws it as a generic
  window and `Wanderer.stage` lets Hush perch on it (debug only). The end-of-day card uses the README's example
  numbers (`heldback:` demo), never your counts. The journal, rules, menu panel and settings, which hold real data,
  are left out.
- **Truthful:** simulated meetings, mail and agent sessions use the demo ids `cleandemo` removes; the video says so at
  the end and under the player. Hand it to Hush (Apple's on-device model) and Ask Hush (one quick question through
  the Claude Code login) ran for real. Your clipboard, look, Hush's spot and settings are put back.
- **Website:** a "Watch the tour" button in the hero and a section after it (`site/media/hush-demo.mp4`, poster, no
  autoplay, `preload="none"`).
- **Deploys:** Vercel is connected to the GitHub repo and deploys `main`; the project's root directory is `site`
  (it was the repo root, which served the repository's files at the site's address for about two hours on
  2026-10-20; those deployments were deleted).

## ADR-032 · Playful videos are made with Remotion from the app's own pack (2026-10-21)

- **Why:** the tour (ADR-031) shows the app as it is; short social videos need camera moves, beats and big type,
  which a recording of the app can't give.
- **How:** `video/` is a small Remotion project. Hush is drawn by `site/hush.js` from `site/hush-data.js`, the
  same composer the website uses, so every pose, face, colour and wearable is the real pack; fonts and edge art are
  copied in by `npm run sync`. Each video renders in 16:9, 1:1 and 9:16 (`npm run render` → `video/out/`, ignored).
- **Truthful:** stories only show what Hush does today (the first, "The flood", is agent updates, not general
  notifications or mail); example numbers match the README's.
- **Supply chain:** `remotion`, `@remotion/cli` 4.0.533 and `react`, `react-dom` 19.3.0, pinned exactly, chosen
  weeks old; past 4.0.410 (CVE-2026-30120 and -30121 fixed); `npm audit` clean; `.npmrc` sets `ignore-scripts`.
  Remotion downloads Chrome Headless Shell on first render. Licence: free for individuals and companies of up to 3.
- **Publishing:** nothing goes on the website or anywhere else until it's been watched and approved.
