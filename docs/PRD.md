# Desktop Companion — PRD

Oct 17, 2026

A silent, customizable cartoon character for macOS that surfaces mail, messages and meetings only when they've earned your attention, and learns what matters to you in ways you can see and edit.

## Problem and goal

Notifications treat every email and message as equally worth interrupting you, so the important ones drown and the rest break focus. The goal is a consumer-facing companion that doesn't force itself on you: it stays ambient by default and only steps forward when something has earned it.

- **Who it's for:** anyone on a Mac, as a free, open-source app. The builder is the first user.
- **Not a goal now:** monetization. The architecture keeps per-user cost at zero, so that stays a choice for later.
- **The bet:** a character's body language can carry information more gently than a notification banner, and a model can judge what deserves an appearance.
- **The anti-pattern to avoid:** Clippy, which failed because it had no judgment about when to show up.

## Product principles

Five principles decide every trade-off; when a feature conflicts with one, the principle wins.

1. **Silent.** No sound, no voice. Motion, posture and props are the whole language.
2. **Attention is earned.** Ambient by default; interrupting is rare and capped. When unsure, stay quiet.
3. **Respect focus.** Hide during calls, screen shares and full-screen work; queue instead.
4. **Scrutable.** Everything it learns about you is visible as plain sentences you can edit or delete.
5. **Local-first.** Mail, calendar and behavior data never leave the Mac by default; cloud models are opt-in and use the user's own account.

## Experience

The character lives at a peripheral home spot and moves through three attention levels: ambient, gentle and interrupt.

### Attention ladder

| Situation | Level | What the character does |
| --- | --- | --- |
| Nothing happening | Ambient | Peeks from the screen edge, blinks, occasionally dozes |
| Unread pile growing | Ambient | A stack of envelopes beside it grows taller |
| Something worth seeing | Gentle | Walks to a corner, sits holding one envelope, waits |
| Meeting in \~10 min | Gentle | Holds up a small clock, glances at you |
| Meeting in \~2 min, or a VIP message | Interrupt | Hurries in from the edge, taps the glass |
| You're in a call or full-screen | Hidden | Hides completely and queues items |
| You shoo it | — | Bows and backs off; three shoos of one type stop that type |

### Surfaces

1. **Character overlay.** A transparent, always-on-top window; clicks pass through everywhere except the character. About 95% of the experience.
2. **Envelope card.** Opens on click: sender, a one-line gist, and two actions, **Open** (in Mail or Calendar) and **Not this kind again**. Read-only in v1.
3. **Menu bar settings.** Character customization, home spot, VIP list, quiet hours, max interrupts per day (default 5).
4. **About you (v2).** The learned profile as plain sentences, each with evidence count, edit, delete, plus "forget everything".

In v2, the same card becomes a **quick-ask** surface: a hotkey or click opens it, you type, and the answer is written into the card. Long conversations hand off to the official ChatGPT or Claude app.

## Delight

The wow comes from awareness with restraint: every delight is either tiny or invited, and nothing playful ever interrupts.

| Feature | What happens | Release |
| --- | --- | --- |
| Cursor-following eyes | The character's eyes track your cursor | v1 |
| Window perching | Sits on the active window's top edge, slides off when it's dragged, falls when it closes, peeks from behind windows | v1 |
| Held-back count | At day's end it tucks itself in: "You got 4 things from me today. I held back 63." The signature feature | v1 |
| Meeting context card | The 2-minute run-in shows who's in the meeting and your last email thread with them | v2 |
| Mirrors your state | Headphones when you go full-screen, a "shh" sign before ducking out of calls, a small dance at inbox zero | v2 |
| File drop | Drag a PDF onto it; it holds up a one-line gist | v2 |
| Rock paper scissors | You invite a game; camera hand-pose detection on-device; it sometimes loses dramatically and sulks | v2 |
| Break invitations | After long focus, only when you go idle, it stretches or holds up a ball; ignored, it puts it away | v2 |
| Pats | Click and hold; it leans into it | v2 |

**Hard requirements:**

- **Camera is opt-in per session.** It turns on only when you start a game, the system camera light is on, and frames are processed on-device and never stored or sent.
- **No delight interrupts.** Playful behavior appears only when invited or when you're idle, and never counts toward or bypasses the interrupt cap.

## Access and distribution

Hush ships as a free, open-source Mac app that reads mail and calendars through the apps already on the Mac, so it needs no Google review, no server and no per-user cost.

| Decision | Choice | Why |
| --- | --- | --- |
| Platform | macOS first; core kept portable for Windows later | Native Swift and Apple's free on-device model |
| AI cost | On-device by default; the user's own ChatGPT or Claude account is optional | Zero cost per user; data stays on the Mac |
| License | Open source | Trust for an app that reads mail; open-source apps can use Sign in with ChatGPT plan usage without OpenAI's approval |
| Data access | Borrow the Mac's own accounts | Avoids Google's restricted-scope review |

### How Hush reads mail and calendar

| Option | How it works | Google review | Verdict |
| --- | --- | --- | --- |
| Calendar app (EventKit) | Reads events from every account in the Calendar app, including Google; gets change notifications instead of polling | None | v1 |
| Apple Mail extension (MailKit) | Mail hands each newly downloaded message (sender, subject, headers) to Hush's extension; works for Gmail, Outlook, iCloud and Exchange | None | v1 |
| Browser extension for web Gmail | Reads the Gmail tab's inbox in Chrome and passes new items to Hush; only while the tab is open, and breaks if Gmail changes its page | None | v2, for people who don't use Apple Mail |
| Gmail API | Hush signs in to Google directly | Restricted scope: verification, plus a yearly security assessment if data touches a server | Later, only if needed |
| IMAP with app password | Classic mail protocol | None, but needs 2-Step Verification, and Google is moving away from app passwords | Not planned |
| Driving a browser (browser-use) | An agent opens Gmail and reads it | None | Rejected: slow, costly, breaks often |

**The trade-off:** users add their Google account to the Mac (System Settings → Internet Accounts), enable Hush in Mail's extension settings, and keep Mail running in the background. Onboarding walks them through it. Whether the extension still receives mail while Mail is hidden or closed needs a build spike.

### Requirements

- macOS 26 or later. On-device AI needs Apple silicon (M1 or newer) with Apple Intelligence turned on.
- Macs without Apple Intelligence run in rules-only mode, or with the user's own ChatGPT or Claude account.

### Distribution

- Notarized direct download with automatic updates (Sparkle), plus Homebrew. Signing needs an Apple Developer Program membership.
- Mac App Store later; its sandbox may limit focus detection and window perching.
- Code and releases on GitHub. No backend holds user data; crash reports are opt-in.

### Built to extend

- Sources, models and characters each sit behind one interface, so new mail providers, models or character packs need no core changes.
- The decision engine is a separate package with no UI code, and the character is a Rive file, which Rive's other runtimes can play, so a Windows app can reuse both.

## Scope by release

v1 is a public, read-only, silent notifier for the Mac's Calendar and Mail apps; chat, learning and web Gmail arrive in v2.

| Area | v1 (public) | v2 | Later |
| --- | --- | --- | --- |
| Sources | Calendar app (EventKit), Apple Mail extension (MailKit) | Browser extension for web Gmail; iMessage (local, Full Disk Access); Slack | Gmail API or Outlook API, only if demand needs it (WhatsApp skipped: no clean way in) |
| Behavior | Attention ladder, focus hiding, shoo, daily interrupt cap | Learned timing windows | — |
| Learning | Raw signal log, "Not this kind again" | Patterns, suggested rules, About you screen, decay, occasional borderline item | — |
| AI | On-device model; rules-only mode on Macs without Apple Intelligence | Quick-ask chat: on-device default, ChatGPT via Sign in with ChatGPT, Claude via API key | Optional Jev for higher accuracy |
| Agent reactions | — | — | React to Claude Code / Codex sessions (thinking, done, needs approval) |
| Actions | Open in Mail or Calendar | — | Reply or send (out of scope until trust is proven) |
| Platform | macOS 26+, open source, notarized download | Mac App Store | Windows |

## Functional requirements

Requirements are tagged by release; v1 items must all ship for the self-test to start.

| ID | Requirement | Release |
| --- | --- | --- |
| FR-1 | Onboarding requests Calendar access, guides the user to enable the Hush Mail extension, and shows how to add Google or other accounts to the Mac | v1 |
| FR-2 | React to Calendar change notifications and Mail extension callbacks; no polling | v1 |
| FR-3 | Drop bulk mail using headers (List-Unsubscribe, Precedence: bulk) and user rules before any model call | v1 |
| FR-4 | Classify each remaining item into ambient / gentle / interrupt with a confidence value, on-device | v1 |
| FR-5 | Low confidence resolves to gentle, never interrupt; only VIP senders or user rules can trigger interrupt | v1 |
| FR-6 | Compute meeting reminders in code from event start times (10 min gentle, 2 min interrupt) | v1 |
| FR-7 | Detect focus (frontmost video-call app, full-screen, active typing) and hide while queueing | v1 |
| FR-8 | Enforce a configurable max interrupts per day (default 5) and quiet hours | v1 |
| FR-9 | Pre-generate a one-line gist on-device when an item arrives so the envelope card opens instantly | v1 |
| FR-10 | Envelope card with Open (in Mail or Calendar) and Not this kind again; message content never leaves the Mac | v1 |
| FR-11 | Shoo gesture; three shoos for one type lowers that type | v1 |
| FR-12 | Log every appearance locally: item type, level, confidence, model version, user response | v1 |
| FR-13 | Character customization: body, palette, eyes, topper, accessory, home spot | v1 |
| FR-14 | Rules-only mode on Macs without Apple Intelligence, with a clear notice | v1 |
| FR-15 | Automatic updates and opt-in crash reports; no user data on any server | v1 |
| FR-16 | Derive patterns from the signal log and propose rules for one-tap confirmation | v2 |
| FR-17 | About you screen with edit, delete and forget-everything | v2 |
| FR-18 | Quick-ask card with streaming answers and model picker; hand-off to official apps | v2 |
| FR-19 | Optional Sign in with ChatGPT (plan usage) and Claude API key | v2 |
| FR-20 | Browser extension for web Gmail that passes new inbox items to the app | v2 |

## Learning and user profile

The companion learns through one loop: signals become visible patterns, and only patterns you confirm become rules that run in code.

| Layer | Example | Where it lives | Visible to user |
| --- | --- | --- | --- |
| Raw signals | Opened mail from Priya in 40 s | Local SQLite, never leaves the Mac | On request |
| Patterns | You usually open mail from your manager within 2 min | About you list | Yes, each with on/off |
| Rules | Always run in for your manager | Settings | Yes, created only after you confirm |

**Signals collected (inside the companion only):**

| Signal | Meaning |
| --- | --- |
| Opens an envelope quickly | This sender or type matters |
| Ignores until timeout, while it was visible | Reachable but not interested |
| Shoos it | Lower this type |
| Not this kind again | Hard rule |
| Replies to something it never surfaced | A miss |
| Drags the character | Preferred home spot |
| Active vs idle hours | When appearances get acted on |

**Mechanics:**

- **Confirm before rule.** After about five consistent signals, the character holds up a card proposing a rule; yes creates it, no discards the pattern.
- **Rules run in code, not in a prompt.** Research shows agents act on at most two-thirds of preferences they remember, so confirmed rules bypass the model.
- **Personal thresholds.** "Opened quickly" adapts to your own pace, not a fixed cutoff.
- **Decay.** Patterns without fresh evidence for a few weeks weaken and drop out.
- **Exploration.** Occasionally let one borderline item through, labeled as uncertain, so it can learn what it would otherwise never show.
- **Disclose at learning time.** Say what it learned when it learns it; surprise discovery later erodes trust.
- **Frame as guesses.** Every line is editable in one tap; people otherwise defer to the algorithm.

**Not built:** mood, stress or personality inference (keyboard-based stress detection reached only 76% accuracy across 3 levels), keystroke content logging, or monitoring other apps beyond which app is in front.

## AI model strategy

Two separate model layers: an on-device cascade that decides when the character appears, and an optional user-connected model for chat.

### System cascade (when to appear)

| Step | Runs on | Handles | Latency |
| --- | --- | --- | --- |
| 1. Rules | Plain code | VIP list, confirmed rules, bulk-mail headers, meeting times | Instant |
| 2. Decide | Apple's on-device model, structured output | Attention level with a confidence value | Target under 1 s; to measure |
| 3. Write | Apple's on-device model | One-line gist, generated on arrival | Background |

**Why on-device:** it's free per user, works offline, and keeps mail on the Mac, which is what lets Hush skip Google's review and a backend. Its 4,096-token context is ample for a sender, subject and short snippet.

**Confidence:** Apple's model returns structured answers, but as far as we know it doesn't expose answer probabilities; confirm in the build spike. If confidence is needed, the openjev approach reads answer probabilities from a small open model (e.g. Gemma 4 on MLX), still on the Mac.

**Jev:** now optional and off by default. It runs only on TypeSafe's servers, so turning it on sends snippets off the Mac; it suits users who want higher accuracy and accept that.

### User-connected models (chat, v2)

| Provider | Connection | Status |
| --- | --- | --- |
| Apple on-device | Built in, no account | Default and free |
| ChatGPT | Sign in with ChatGPT; uses the user's Plus/Pro plan | Optional; open-source apps qualify without OpenAI's approval |
| Claude | User's Anthropic API key (Haiku 5.5 for speed, Sonnet 5.5 for harder asks) | Optional |
| Claude subscription login | — | Not allowed: Anthropic's terms prohibit third-party apps using Free/Pro/Max credentials |

Personal-use note: invoking your own unmodified Claude Code (`claude -p`) locally is tolerated for experimentation, but is not a shippable path.

## Architecture

Every item passes through code rules first; only what rules can't settle reaches the on-device model, and your responses feed back into new rules.

&#91;embedded content: decision cascade · 3 steps and a learning loop\]

The writer runs in the background on arrival, so the gist is ready before you click. If the on-device model is unavailable, rules alone still drive the character.

## Tech stack and non-functional requirements

The app is native Swift, because Apple's Foundation Models framework puts on-device, private-cloud, open (MLX) and server-side models behind one interface.

| Layer | Choice | Why |
| --- | --- | --- |
| App shell | Swift, SwiftUI/AppKit floating panel | Native overlay; one code path for all model backends |
| Core engine | Separate Swift package with no UI code | Testable; portable to Windows later |
| Animation | Rive state machine | Reacts to inputs (level, hasEnvelope); Lottie only plays fixed clips |
| Character design | Claude Design → Figma (layer cleanup) → Rive | Layered, swappable parts |
| Data | EventKit (Calendar app), MailKit extension (Apple Mail) | Any account the Mac already has; no Google review |
| Models | Apple Foundation Models; optional ChatGPT or Claude account | Free, private default |
| Storage | SQLite on the Mac | Queue, signal log, rules, decision log |
| Distribution | Notarized download, Sparkle updates, Homebrew | No App Store sandbox limits at launch |
| Code | Open source on GitHub | Trust, contributions, Sign in with ChatGPT eligibility |

### Latency

- The character never waits on a model; Rive runs locally and can show an anticipation pose.
- Gists are generated on arrival, so the card opens with no wait.
- On-device prompts stay short and structured: sender, subject and snippet only.
- Chat replies stream into the card (v2).

### Reliability

- Pin model versions; log version, probabilities and confidence per decision.
- Fallback chain: on-device model → rules only. Macs without Apple Intelligence run on rules, or on the user's own account.
- Retry with backoff when an optional cloud model is rate-limited.
- Replay the last week's mail against any new threshold or model version before switching.

### Privacy

- By default nothing is sent to any server. With an optional cloud account, only sender, subject and snippet are sent.
- Signal log and profile stay local.
- No keystroke content, mood inference or cross-app monitoring; camera only during user-started games, processed on-device.

## Success metrics and test plan

v1 succeeds if, after a 1–2 week self-test, the companion is still switched on and its appearances are mostly worth it.

| Metric | Target | How measured |
| --- | --- | --- |
| Appearances marked worth it (gentle + interrupt) | ≥ 80% | Decision log + yes/no tag per appearance |
| Interrupts per day | ≤ 5 | Decision log |
| Appearances during calls or screen share | 0 | Decision log vs focus state |
| Ambient state readable at a glance | Yes | Can you tell if a meeting is coming without clicking |
| Still switched on after 7 days | Yes | Self-report |

- [ ] Ship all v1 functional requirements
- [ ] Run the self-test for 1–2 weeks, tagging each appearance
- [ ] Review the decision log; tune thresholds via replay
- [ ] Decide go / no-go on v2

## Risks and open questions

The biggest risk is that the character reads as annoying rather than charming; the daily cap and quiet-by-default rules exist to contain it.

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Character feels like Clippy | Product fails its core promise | Interrupt cap, low-confidence → gentle, shoo learning |
| Users don't use Apple Mail | No mail alerts for them | Browser extension for web Gmail in v2; calendar still works |
| Mail extension needs Mail running | Missed mail when Mail is quit | Onboarding sets Mail to open hidden at login; spike to confirm behavior |
| Macs without Apple Intelligence | No on-device AI | Rules-only mode; optional user account |
| On-device model accuracy, no confidence scores | Wrong appearances | Rules first, low confidence → gentle, replay testing; openjev-style scoring if needed |
| Web Gmail extension breaks when Gmail changes its page | Web Gmail users lose alerts | Maintained library; fail quietly to calendar-only |
| Open source makes copies easy | Clones of the app | Name and character art licensed separately from the code |
| Scope creep into chat and agents | v1 never ships | v1 is notifier only; chat is v2 |

**Open questions:**

- [ ] Spike: does the Mail extension receive new mail while Mail is hidden or closed?
- [ ] Spike: on-device classification accuracy and speed on a week of real mail
- [ ] Licenses for the code (e.g. Apache-2.0) and for the Hush name and art
- [ ] Trademark search for the name Hush
- [ ] Final character design and default home spot
- [ ] Exact focus signals: which apps count as "in a call"?

## Appendix: character design prompt

Paste this into Claude Design; the layered output is then cleaned in Figma and rigged in Rive.

```text
Design an original, cute desktop companion character for a silent macOS app. It lives at the edges of the user's screen and delivers emails, messages, and meeting reminders through body language only — no voice, no text from the character itself.

Personality: gentle, polite, slightly shy, never pushy. It should feel like it respects your attention — the opposite of an attention-seeking mascot.

Style: flat vector, soft rounded shapes, 2–3 colors plus an outline, readable at very small sizes (48–96 px tall on screen). Simple expressive eyes carry most of the emotion. Avoid resemblance to any existing mascot or brand character.

Customization system — design it as swappable parts on separate, clearly named layers:
- Body shape: 3 options (round blob, tall bean, small square-ish)
- Color palette: 5 presets (body, belly, accent)
- Eyes: 3 styles
- Head topper: none, antenna, small ears, leaf sprout
- Accessory: none, scarf, tiny cap, round glasses
Show a grid of 6 example combinations.

Character sheet of states (one pose each, same design):
1. Idle, peeking from the bottom edge of the screen, only head and hands visible
2. Dozing (clear calendar)
3. Sitting beside a small stack of envelopes (unread pile)
4. Sitting, holding one envelope up politely, waiting
5. Holding a small clock, glancing toward the viewer (meeting soon)
6. Hurrying in from the side, mid-stride, holding an envelope (urgent)
7. Gently tapping on the "glass" toward the viewer
8. Bowing and backing away (dismissed)
9. Hiding, only the top of the head visible (user is busy)

Also show 5 facial expressions: neutral, happy, sleepy, apologetic, alert.

Deliver on a transparent background, with layer structure suitable for export as SVG and later rigging in Rive (separate layers for body, eyes, mouth, arms, legs, topper, accessory, props).
```

## Sources

- [Legal and compliance – Claude Code Docs](https://code.claude.com/docs/en/legal-and-compliance)
- [Anthropic's third-party Claude crackdown – falcao.org](https://falcao.org/posts/anthropic-claude-access-crackdown-ecosystem-fallout/)
- [Sign in with ChatGPT quickstart – OpenAI Developers](https://developers.openai.com/siwc/quickstart)
- [Using your ChatGPT plan in other apps – OpenAI Help](https://help.openai.com/articles/20001542)
- [How to use your ChatGPT subscription in other apps – Flavio Copes](https://flaviocopes.com/sign-in-with-chatgpt.md)
- [Jev is Vercel's fastest-adopted AI model ever – TechCrunch](https://techcrunch.com/2026/10/16/jev-is-vercels-fastest-adopted-ai-model-ever/)
- [How to use Jev: a practical guide – DEV Community](https://dev.to/valyuai/how-to-use-jev-a-practical-guide-to-typesafes-system-one-model-g5e)
- [Jev (AI model) – Wikipedia](<https://en.wikipedia.org/wiki/Jev_(AI_model)>)
- [Apple's Foundation Models framework – Cult of Mac](https://www.cultofmac.com/news/apple-foundation-models-framework)
- [WWDC 2026 Platforms State of the Union – MacRumors](https://www.macrumors.com/2026/06/09/apple-outlines-major-ai-and-developer-tool-updates/)
- [MLX in Apple's Foundation Models framework – Medium](https://medium.com/@nuthalapativarun/mlx-is-now-a-first-class-citizen-in-apples-ai-stack-run-any-hugging-face-model-through-foundation-9dfb8dad2191)
- [Best small LLM for local deployment in 2026 – Ertas](https://www.ertas.ai/best/best-small-llm-for-local-deployment)
- [Reachable but not receptive – Turner et al., Cardiff](https://orca.cardiff.ac.uk/id/eprint/97910/)
- [PrefMiner – University of Birmingham](https://research.birmingham.ac.uk/en/publications/prefminer-mining-users-preferences-for-intelligent-mobile-notific)
- [Know It, Act on It: memory utilization in LLM personalization – arXiv](https://arxiv.org/pdf/2607.29433)
- [Natural language user profiles for scrutable recommendation – arXiv](https://arxiv.org/pdf/2205.09403)
- [Stress detection from keyboard and mouse dynamics – Politecnico di Torino](https://iris.polito.it/handle/11583/2855160)
- [Modeling dwell time to predict click-level satisfaction – Microsoft Research](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/KimWSDM2014.pdf)
- [The uncanny valley of digital personalization – Atticus Li](https://www.atticusli.com/blog/posts/paradox-of-personalization-creepy-vs-helpful/)
- [GitHub topic: ai-pet](https://github.com/topics/ai-pet)

* [Gmail restricted scopes: verification and CASA – Nylas](https://developer.nylas.com/docs/provider-guides/google/google-verification-security-assessment-guide/)
* [Restricted Gmail scope in a client-only app – Google Developer forums](https://discuss.google.dev/t/restricted-gmail-scope-in-a-client-only-app-is-a-security-assessment-required/404126)
* [MEMessageActionHandler – Apple Developer](https://developer.apple.com/documentation/mailkit/memessageactionhandler)
* [MEMessage – Apple Developer](https://developer.apple.com/documentation/mailkit/memessage)
* [Build Mail app extensions, WWDC21 – WWDC Notes](https://wwdcnotes.com/notes/wwdc21/10168)
* [EKEventStore – Apple Developer](https://developer.apple.com/documentation/eventkit/ekeventstore)
* [Apple Intelligence requirements – Osaurus docs](https://docs.osaurus.ai/models/apple-intelligence)
* [Gmail OAuth changes and app passwords – Mailbird](https://www.getmailbird.com/gmail-oauth-changes-app-password-phase-out/)
* [gmail.js – GitHub](https://github.com/pbamotra/gmail.js)
