# Who Hush is for: segments, personas and superpowers

2026-10-18 · Research pass from public data (sources at the end). Many numbers come from vendor reports or press
summaries rather than primary studies; each claim is marked **strong** (large primary survey), **indicative**
(vendor or secondary) or **weak** (anecdote or self-report).

## How to segment

Two questions separate Hush's users better than job titles:

1. **How do you relate to building software?** Pro developer → vibe coder (builds with AI, doesn't read the code) → doesn't build software at all.
2. **What do you want from something living on your screen?** Guard my attention · do work for me · keep me company.

Every persona below is one cell of that grid. The character stays the same for everyone; what changes is which
superpowers are on, how much Hush steps forward, and the "voice" of its body language.

| | Guard my attention | Do work for me | Keep me company |
| --- | --- | --- | --- |
| **Pro developer** | The Conductor (agents, CI, reviews) | The Conductor | n/a |
| **Vibe coder** | n/a | The Maker | n/a |
| **Doesn't code** | The Juggler · The Wanderer (ADHD) · The Learner | The Juggler (later) | The Solo · The Collector · The Performer |

## The personas

### 1. The Conductor: pro developer running AI agents
**Who:** Professional engineer who now spends much of the day *directing* agents (Claude Code, Codex, Cursor) instead
of typing code, often several sessions at once. **This is the builder.**

**What we know:**
- **Strong:** 90% of professional developers use an AI coding agent at work at least weekly, 68% daily; 39% use Claude Code at work (JetBrains 2026, 15k+ respondents).
- **Strong:** 84% use or plan to use AI tools, but 46% distrust the accuracy of the output. The top frustration (66%) is code that's "almost right"; 45% say debugging AI code takes longer (Stack Overflow 2025).
- **Indicative:** The workflow has become *prompt → wait → review → debug*: developers describe "babysitting" agents and constant context-switching. No tool in the search addressed "tell me when it's done" well.

**Pains:** Watching terminals for agents that finish or stall on a permission prompt. Losing focus while waiting. Reviewing almost-right output. Not knowing what the agents did while you were in a meeting.

**Hush's persona: "the stage manager."** Calm, competent, in the wings. Tracks every session and only steps on stage
when a cue is due: done, stuck, or needs a decision.

**Superpowers:**
| Superpower | Status |
| --- | --- |
| Session radar: thinks while agents work, envelope when a long run finishes, "needs you" on permission prompts | **Built (Phase 1)** |
| Ask the repo: read-only questions answered in a card | **Built (Phase 2)** |
| "While you were away" digest: what each agent did, what's waiting for review | Next: aggregate Phase 1 + 2 data |
| Background tasks in worktrees: tests, lint fixes, PR descriptions → Apply / Discard | Phase 3 |
| CI and review watcher: "CI failed on #123, want me to look?" (gentle, capped) | Phase 4 |
| Approval gate: approve or deny an agent's risky step from the card, without switching to the terminal | Phase 3 |
| Spend meter: what agents cost you today (already logged per task) | Small |

**Unlock:** *"I can walk away from my agents."* Attention moves from watching terminals to deciding when Hush taps.

---

### 2. The Maker: vibe coder / non-technical founder
**Who:** Builds real apps with Lovable, Replit, Bolt or Claude Code without reading the code. Often a founder or an
experienced professional from outside tech.

**What we know:**
- **Indicative:** ~4 in 5 Lovable users are non-technical; 45.7% call themselves founders; only 5.8% are engineers. Lovable reports 50M projects; Replit 50M users; Bolt 5M users (vendor figures via Redwerk / webhosting.today).
- **Weak:** The widely repeated "63% of vibe coders are non-developers" comes from a sample of Reddit comments, not a representative survey.
- **Indicative:** Real security failures come from trusting AI with things the builder didn't know mattered (Lovable row-level-security CVE-2025-48757).

**Pains:** Doesn't know what changed or whether it's safe. Gets stuck when the agent loops. Fear of breaking production. Jargon.

**Hush's persona: "the patient translator."** Never makes you feel dumb. Holds up plain-English cards instead of diffs.

**Superpowers:**
- **"What just changed?"** in plain English after every agent run (Phase 2 with a non-technical prompt preset).
- **Safety check before shipping:** exposed secrets, missing auth or row-level security, dependency advisories. Shown as a calm checklist card, never a scare.
- **Undo confidence:** checkpoints before each agent run ("go back to how it was at 3 pm").
- **Unstick the agent:** spots a loop (same error three times) and suggests a better prompt.
- **Deploy watcher:** the build failed or the site is down, as a gentle card in words a founder understands.

**Unlock:** *"I can ship without being scared of what I don't understand."*

---

### 3. The Juggler: knowledge worker drowning in pings
**Who:** PM, manager, consultant or ops lead. Lives in mail, chat and meetings. **The PRD's
original v1 user.**

**What we know:**
- **Indicative / strong:** Interrupted about every 2 minutes, up to 275 pings a day. An average of 153 Teams messages and 117 emails a day; 57% of meetings are ad hoc (Microsoft Work Trend Index 2025, 30k+ workers via press coverage; one source says the 275 figure applies to the heaviest 20%).
- **Indicative:** 47% say they spend more time directing AI than doing the task (BCG, 11.7k workers).
- **Strong (historical):** Clippy failed because it had no judgment about when to appear, couldn't be dismissed, and was "optimised for first use." This is the PRD's founding anti-pattern.

**Pains:** Everything interrupts equally. Real priorities drown. Walking into meetings unprepared. End-of-day guilt about what was missed.

**Hush's persona: "the butler."** Discreet, judges what's worth your attention, remembers everything, takes credit quietly ("I held back 63").

**Superpowers:**
| Superpower | Status |
| --- | --- |
| Mail and meeting triage through the attention ladder, VIPs, daily cap | Engine **built**; mail source blocked on MailKit (macOS 26 + Xcode) |
| Focus shield: hides in calls, queues while you type | **Built** |
| End-of-day held-back count | **Built** |
| Meeting context card: who's in it and your last thread with them | PRD v2 |
| "Ask Hush" about your inbox or calendar | Phase 2 pattern, new tools |
| Draft a reply, never sent without you | Later (PRD: out of scope until trust is proven) |

**Unlock:** *"Only the things that matter can reach me."*

---

### 4. The Wanderer: neurodivergent focus-seeker (ADHD)
**Who:** Developers, creatives and knowledge workers with ADHD or similar executive-function differences.

**What we know:**
- **Indicative:** About 6% of US adults had a current ADHD diagnosis in 2023, half of them diagnosed as adults (CDC via secondary summary).
- **Strong (meta-analysis):** Adults with ADHD judge brief time spans significantly worse ("time blindness", 55-study meta-analysis).
- **Weak/mixed:** Body doubling (working alongside someone) is popular (Focusmate, FLOWN), but there are no large randomized trials. One controlled study found no significant effect; the positive numbers are app-commissioned self-reports.

**Pains:** Losing track of time. Trouble starting tasks. Hyperfocus that skips meetings and meals. Notification spirals.

**Hush's persona: "the body double."** Just *there*, working alongside you. It reflects the time back to you without nagging.

**Superpowers:**
- **Visible time:** Hush's posture shifts as a meeting approaches (it already does at 10 and 2 minutes). Add an optional ambient "time passing" cue during long stretches.
- **Start ritual:** you tell Hush what you're starting; it sits beside you; it notices when you've drifted to another app for a while (app switches only, never content).
- **Hyperfocus breaks:** only when you go idle, never mid-flow (already a PRD rule).
- **"What was I doing?":** a click on Hush shows the last task you named and the apps you were in.

**Unlock:** *"Something keeps me company and keeps time for me, without judging."* **Caution:** no medical claims. Evidence is thin, so test with real users before building much.

---

### 5. The Solo: remote or solo worker who wants company
**Who:** Fully remote employees, freelancers, indie hackers. A silent presence instead of an empty desk.

**What we know:**
- **Strong:** 25% of fully remote employees report loneliness, against 16% on-site (Gallup State of the Global Workplace 2025).
- **Indicative:** AI companion apps passed 220M downloads by mid-2025, with downloads up 88% year on year (Appfigures via TechCrunch).
- **Weak (needs primary check):** Heavier chatbot-companion use correlates with *more* loneliness and dependence (OpenAI/MIT study, relayed second-hand).

**Pains:** Long silent days. Nobody to share small wins with. Forgetting to step outside.

**Hush's persona: "the desk buddy."** A small friend who's happy you're here. Silence is a feature: it can't become a substitute conversation partner.

**Superpowers:** morning wake-up and bedtime tuck-in (**built**), pats and pat requests (**built**), shared celebrations (inbox zero, merged PR, shipped feature), gentle "you've been in for 6 hours" nudges, and a weekly "your week with Hush" card.

**Unlock:** *"My desk feels less empty."* **Design stance:** nudge *toward* people and the outdoors; never optimise for time spent with Hush.

---

### 6. The Learner: student or bootcamp learner
**What we know (indicative):** school is the top reason young people use AI: 69% of teens, 49% of young adults (YPulse 2025). Most use it to explain concepts and summarise.

**Hush's persona: "the study buddy."** Superpowers: deadlines from the calendar as posture cues, a focus session where Hush studies too, quick-ask to explain a concept (Phase 2 pattern on course notes), and the end-of-day count of focused time.

**Caution:** Hush targets adults on a Mac; anything for teens needs extra care (camera, data, companionship).

---

### 7. The Collector: delight-seeker and customiser
**What we know:** Tamagotchi passed 100M units in August 2025, with adults driving the revival (Bandai, Globe and Mail; indicative). Desktop Mate topped Steam's "Trending Free" chart at launch in January 2025, with 89% positive reviews and a paid ~$20 character DLC (Notebookcheck). Shimeji-style desktop pets remain a durable niche.

**Hush's persona: "the pet."** Superpowers: bodies, palettes, toppers and accessories (**built**); seasonal outfits; growth over time (new accessories unlocked by days together, never by engagement metrics); character packs from artists.

**Unlock:** delight and identity. **This is also the cleanest monetisation path if it's ever wanted:** cosmetic packs, with the art licensed separately from the open-source code, as the PRD already plans.

---

### 8. The Performer: streamer or creator (niche)
**What we know (weak):** indie desktop-pet and VTuber-assistant tools target streamers (chat reactions, stream modes), and Streamlabs publishes desktop-pet tutorials. No usage data.

**Hush's persona: "the on-stream mascot."** Superpowers: stream-safe mode (screen-share detection already hides Hush; for streamers, invert it so Hush stays visible but never shows a notification card), plus reactions to follows and chat. **Low priority.**

## The superpowers, ranked by reach

The capabilities that serve the most personas form the platform. Persona-specific ones are presets on top.

| Capability | Conductor | Maker | Juggler | Wanderer | Solo | Learner | Collector | Performer | Status |
| --- | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | --- |
| **Attention judgment** (ladder, cap, focus hiding, queue) | ● | ● | ● | ● | ○ | ● | | ● | Built |
| **Body-language presence** (poses, life, reactions) | ○ | ○ | ○ | ● | ● | ○ | ● | ● | Built |
| **Ask Hush** (quick question → answer card) | ● | ● | ● | ○ | | ● | | | Built (code); more sources next |
| **Background agent tasks** (worktrees, Apply/Discard) | ● | ● | ○ | | | | | | Phase 3 |
| **Plain-English change and safety summaries** | ○ | ● | | | | ○ | | | New |
| **Time made visible** (meetings, focus sessions, breaks) | ○ | | ● | ● | ○ | ● | | | Partly built |
| **Daily rituals and celebrations** | ○ | ○ | ● | ○ | ● | ○ | ● | ○ | Partly built |
| **Customisation and collection** | | | | | ● | ○ | ● | ● | Built (art); packs later |
| **Scrutable memory** (what Hush learned, editable) | ● | ● | ● | ● | ○ | ○ | | | PRD v2 |

● core need · ○ nice to have

## Recommendation

1. **Wedge: the Conductor.** This is you, the tools exist (Phases 1–2), the pain is measurable, and nothing else on the
   Mac solves "tell me when my agents need me" with restraint. Finish Phases 3–4 and the "while you were away" digest.
2. **Second: the Maker.** Same agent runtime, different presets: plain-English summaries, safety checks and checkpoints.
   It's a big market (tens of millions of vibe-coding users) with acute trust pain.
3. **Keep the Juggler as the PRD's core** once MailKit unblocks (macOS 26). The engine is ready; only the mail source is missing.
4. **The emotional layer** (Solo, Wanderer, Collector) is why people *keep* Hush running after the novelty fades. It's
   mostly built already. Invest in rituals and customisation, and validate the ADHD features before building more.
5. **Onboarding becomes one question:** *"What do you mostly do on your Mac?"* (I build software · I build with AI ·
   I manage work and messages · I just want company). The answer picks a preset of superpowers and how forward Hush is.
   Everything stays editable.

## What to validate next (before building more)

- **5 Conductor interviews** (Mom Test, past behaviour): how do you find out an agent finished or got stuck today? What did that cost you last week?
- **5 Maker interviews:** the last time an AI change broke something, how did you find out, and what did you do?
- **Instrument the self-test** (PRD § Success metrics): per persona preset, count appearances marked "worth it", ignores, shoos and pats.
- **Primary-source check** before quoting externally: Microsoft WTI 2025, the OpenAI/MIT companion study, Buffer 2025, CDC ADHD.

## Sources

- [Stack Overflow 2025 Developer Survey (press release)](https://stackoverflow.co/company/press/archive/stack-overflow-2025-developer-survey/) · [InfoWorld summary](https://infoworld.com/article/4031673/ai-use-among-software-developers-grows-but-trust-remains-an-issue-stack-overflow-survey.html)
- [JetBrains: How much code do developers really let agents write? (2026)](https://blog.jetbrains.com/research/2026/08/how-much-code-do-developers-really-let-agents-write/) · [Stack Overflow 2026 AI agents data](https://survey.stackoverflow.co/2026/ai/data/ai-code-agent) · [Claude Code statistics 2026](https://www.gradually.ai/en/claude-code-statistics/)
- [From babysitting to managing coding agents (Medium)](https://medium.com/@georgethomasm_89397/from-babysitting-to-managing-why-openais-symphony-changes-how-we-work-with-coding-agents-a084815388d7) · [Context is AI coding's real bottleneck (The New Stack)](https://thenewstack.io/context-is-ai-codings-real-bottleneck-in-2026/)
- [Vibe Coding Report 2026 (Redwerk)](https://redwerk.com/blog/vibe-coding-report/) · [Lovable, Bolt and Replit project volumes (webhosting.today)](https://webhosting.today/2026/06/10/lovable-bolt-and-replit-are-generating-millions-of-projects-every-week-traditional-hosting-is-not-where-they-land/) · [Non-developer success rate: the real data](https://codingwithvibe.com/vibe-coding-success-rate-non-developer/) · [Who is building now (Museum of Vibe Coding)](https://museumofvibecoding.org/vibe-coding-and-the-democratization-of-software-who-is-actually-building-now-unbiased-research-2026/) · [Taskade: State of vibe coding](https://www.taskade.com/blog/state-of-vibe-coding) · [Hostinger vibe coding statistics](https://www.hostinger.com/blog/vibe-coding-statistics/)
- [Microsoft WTI 2025 "infinite workday" (Workplace Insight)](https://workplaceinsight.net/microsoft-research-lays-bare-the-rise-of-the-infinite-workday/) · [80% interrupted too often (Allwork)](https://allwork.space/2025/04/80-of-workers-are-interrupted-too-often-to-be-effective-new-microsoft-report-reveals/) · [Notification overload caveats (StealthAgents)](https://stealthagents.com/research/executive-notification-overload-statistics-2026)
- [AI at work statistics 2026 (Saner)](https://blog.saner.ai/ai-at-work-statistics/) · [Workers ready for AI agents (Allwork)](https://allwork.space/2026/02/workers-are-ready-for-ai-agents-but-organizations-arent-creating-ai-limbo/)
- [Lessons from Clippy (The New Stack)](https://thenewstack.io/humanity-vs-clippy-lessons-from-microsofts-failed-virtual-assistant/) · [What went wrong with Clippy (CIO)](https://www2.cio.co.nz/article/662045/what-went-wrong-clippy-virtual-assistant-pioneer-people-loved-hate/) · [Clippy lessons for Copilot (Windows Forum)](https://windowsforum.com/threads/clippy-lessons-for-microsoft-copilot-when-assistants-become-intrusive.411922/)
- [ADHD productivity statistics 2026 (Saner)](https://blog.saner.ai/adhd-productivity-statistics/) · [Time blindness (OccupationalTherapy.com)](https://occupationaltherapy.com/articles/time-blindness-critical-executive-function-5790) · [Body doubling evidence (Popular Science)](https://www.popsci.com/health/body-doubling-focus-benefits/) · [Body doubling in VR (arXiv)](https://arxiv.org/pdf/2509.12153) · [Drake controlled study (CCSC 2025)](https://www.ccsc.org/centralplains/2025/talks/talk-poster16/)
- [Remote work loneliness 2026 (StealthAgents, cites Gallup)](https://stealthagents.com/research/remote-work-loneliness-statistics-2026) · [Buffer on remote loneliness](https://buffer.com/resources/feeling-lonely-remote-work/)
- [AI companion apps statistics 2026 (Voxbooster)](https://voxbooster.com/blog/ai-companion-apps-statistics-2026) · [The AI companionship gap](https://paddo.dev/blog/ai-companionship-gap/)
- [Gen Z students using AI (YPulse)](https://www.ypulse.com/article/2025/10/02/how-many-gen-z-students-are-really-using-ai/)
- [Tamagotchi nostalgia (Globe and Mail)](https://www.theglobeandmail.com/life/article-tamagotchi-toy-nostalgia-club) · [Tamagotchi turns 30 (Malay Mail)](https://malaymail.com/news/life/2026/01/07/still-hungry-after-30-years-tamagotchi-proves-retro-pets-never-go-out-of-style/204577) · [Desktop Mate tops Steam (Notebookcheck)](https://www.notebookcheck.net/This-free-software-is-topping-the-Steam-charts-but-it-s-not-a-game.945113.0.html) · [Desktop mascot alternatives](https://alternativeto.net/feature/desktop-mascot)
- [Streamer desktop pets (Streamlabs tools)](https://streamlabs.com/content-hub/tools/other-tools) · [TomoNaka Desk](https://joycatdev.itch.io/tomonaka-desk)
- [Raycast review 2026](https://aiindigo.com/blog/raycast-review-2026-the-command-center-for-your-mac)
