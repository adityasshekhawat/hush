# Where Hush stands apart

2026-10-18 · From a scan of current companion and assistant products (sources at the end; most are vendor pages,
so feature claims are self-reported).

## The landscape in six groups

| Group | Examples | What they do | What they don't |
| --- | --- | --- | --- |
| **Desktop pets** | Shimeji, Desktop Goose, Desktop Mate (topped Steam "Trending Free", 2025) | Delight, presence, customisation | No utility, no judgment |
| **AI desktop pets / companions** | PetOS, PetClaw, Clawster, AI Desktop Pet, AikoMate, Miru, Clippy-as-LLM | A character you chat or talk with; some see your screen and start conversations when you're idle; reminders, memory | Talk *at* you; no notion of an attention budget; engagement is the goal |
| **Phone AI companions** | Replika, Character.ai (220M+ companion-app downloads, mid-2025) | Emotional relationship, conversation | Not about work; heavy use correlates with loneliness in some research |
| **Platform assistants** | Copilot (Mico avatar, Vision sees your screen), ChatGPT for Mac (agent mode), Claude (Cowork, computer use), Apple Intelligence (notification summaries) | Powerful: do tasks, control the computer, summarise notifications | You summon them. They don't decide *when* something deserves you. Apple's summaries were pulled for errors and returned with disclaimers |
| **Coding-agent monitors** | OpenAgentPeek, Nudge, AgentNotch, Claude Island, ClaudeCodeMonitor, Omnara, **Agent Pet Companion** (a desktop pet that reacts to Codex, Claude Code and others) | Show every agent's state; ping when one needs input; some show every tool call and cost | Display everything; one source only; no cap, no learning, nothing outside coding |
| **Focus tools** | macOS Focus modes, app blockers | Silence by schedule or app | Blunt: all or nothing, no judgment about *which* message matters |

**The honest read:** a cute character that reacts to coding agents is no longer unique (Agent Pet Companion does
it, MIT, small). "Watch my agents" is a crowded menu-bar category. Big assistants already chat, see the screen and do
tasks. Hush can't win on any of those alone.

## What only Hush does

Status tags: **[built]** works today, **[planned]** is on the roadmap. A planned differentiator is a goal, not a fact.

1. **It judges, and it proves its restraint.** [built] Every interrupt (meetings and agents today, mail later) goes
   through one decision engine with a **daily interrupt cap** (default 5), quiet hours and call/full-screen hiding.
   At bedtime it says what it **held back** ("You got 4 things from me today. I held back 63."). Others show
   everything or nothing; none of the products we scanned advertise a count of what they spared you. This is the
   PRD's founding idea: Clippy failed because it had no judgment about when to show up.
2. **One attention budget across your whole day,** not per app. [built for meetings + agents; mail planned] Agent
   monitors see only agents, Apple sees only notifications, pets see nothing. Hush weighs a finished Claude run
   against a meeting in 2 minutes, and once mail lands, against a VIP mail too.
3. **Silent by design.** [built] Body language at the edge of the screen; words only on cards you open. AI pets and
   companions talk, chat or speak; Mico is an avatar *for* voice. Hush is the opposite of a chatbot persona, so it
   can't become a substitute conversation partner or an engagement trap.
4. **Rules in code, learning you can read.** [rules + shoo built; editable learned sentences planned, PRD v2]
   Preferences become rules that run in code, not prompts. Others' memory is opaque.
5. **A router, not a rival.** [built, R0] Quick answers in place, then hands off to *your* ChatGPT, Claude or Perplexity, and
   sends results into Excel, Warp, Cursor, Notion, Obsidian. It works with Cowork and ChatGPT rather than
   competing with them.
6. **Local by default, open, no account.** [built] No Hush server; calendar through the Mac's own store;
   transcripts read only on opt-in; the digest is built on the Mac. Model calls (Ask Hush, Summarise) are opt-in,
   named on screen, and today run on your own Claude Code login.

## Positioning statement

> **For** people who spend the day on a Mac with AI tools,
> **Hush is** a playful buddy that lives on your screen and helps when it counts.
> **It isn't** another chat app. It sits on top of the models you already use, so it gets more capable each time
> they do. The character, the timing and the taste stay Hush's own.

**One line (draft):** *A playful buddy that gets smarter as the models do.*
Alternative, for the restraint angle: *The companion that knows when not to.*

## Model-native: what Hush owns, what it borrows

Hush is a thin, durable layer on top of fast-improving models. Every model upgrade should make Hush better
without a rewrite.

| Hush owns (stays ours, in code) | Hush borrows (from the best model available) |
| --- | --- |
| The character, its play and moods | Understanding a question, answering, writing |
| When to show up: the engine, the cap, focus and call hiding | Summarising sessions, mail, meetings |
| Context about you: calendar, focus, the app you're in, your agent sessions | Coding (Claude Code), research (ChatGPT, Perplexity) |
| Where the result goes: the app router and hand-offs | Browser and desktop navigation (computer use) |
| Trust: permissions, review before acting, the held-back ledger | Whatever new skill the next model ships |

Rules that follow from this:
- **Never hand-build a skill a model call can do.** Hush builds the doorway (context, routing, the card, the review
  step), not the skill.
- **Models are settings, not code.** Each lane names its model and provider. An upgrade is a config change, checked
  against a small eval of real asks.
- **Capabilities switch on as models gain them.** New lanes (e.g. "do it in the browser") turn on when the runtime
  supports them, behind the same review step.
- **Ask Hush is a doorway, not a chat app.** One ask, one answer card, then act or hand off. Long conversations
  belong in ChatGPT or Claude, and Hush sends you there with context.
- **Judgment about interrupting stays in code.** Models get smarter at *what*; the user's rules decide *when*.

## Where Hush is behind (and what to do)

| Gap | Who's ahead | Response |
| --- | --- | --- |
| Mail isn't connected yet (MailKit needs macOS 26 + Xcode) | Apple summaries, Copilot | Highest priority once unblocked: the judgment story is weakest without mail |
| Can't control the computer | Cowork, Copilot Vision, ChatGPT agent | Don't race them; route tasks to them (hand-off), add opt-in browser actions later with approval |
| Claude Code and Codex only (2026-10-19) | OpenAgentPeek, Agent Pet Companion (OpenCode, more) | Antigravity next once it can be tested (Gemini CLI was replaced by it); the moat is the judgment, not the adapter count |
| Presenting without a call isn't detected | — | Hush's windows are excluded from shares, recordings and screenshots (built), so viewers never see it; it may still show on your own screen |
| No voice, no chat persona | AI pets, Mico | Intentional; don't add one |
| Unsigned; build-from-source only | Everyone signed | Apple Developer membership before any public launch |
| Agent features run on your Claude Code login (builder-only) | — | API-key backend (Phase 5) before release |

## Proof we should own (measured, local)

- **Worth-it rate** of appearances ≥ 80% (PRD) · **interrupts/day** ≤ 5 · **held-back ratio** (e.g. "4 shown, 63 held back")
- **Zero** appearances during calls (built) and in anything you share or record (windows excluded from capture, built)
- Still running on day 7

The held-back count is both the signature delight and the evidence. Make it visible: tuck-in card, menu bar, weekly card.

## What this means for the roadmap

- **Double down:** one budget across every source (agents + mail + calendar + answers), the held-back ledger, scrutable rules.
- **Keep and grow:** the character and its play. It is the product, not decoration: a buddy first, a helper second.
- **Don't build:** a chat persona, voice, engagement mechanics.
- **Browser and desktop automation:** borrow it, don't build it. Use the model's computer use (Claude in Chrome,
  computer use, or the user's own agent) as a lane; Hush supplies the context, the approval step and the character's
  reactions while it works. Capability rises with each model release.
- **Cheap wins vs. monitors:** Codex hooks (built), Antigravity next; "agent needs you" goes through the same cap.

## Sources

- [desktop-pet GitHub topic](https://github.com/topics/desktop-pet?l=python) · [Agent Pet Companion](https://github.com/xjxtree/agent-pet-companion) · [PetOS](https://www.petos.one/) · [PetClaw](https://petclaw.ai/) · [Clawster](https://clawster.pet/) · [AI Desktop Pet (Steam)](https://store.steampowered.com/app/4227700/AI_Desktop_Pet/) · [AikoMate (Steam)](https://store.steampowered.com/app/4426320/AikoMate/) · [Living with Lapu](https://lapu.ai/blog/ai-desktop-companion) · [Personal AI assistants for Mac (Vellum)](https://www.vellum.ai/blog/best-personal-ai-assistants-for-mac)
- [Mico, "the new Clippy" (BleepingComputer)](https://www.bleepingcomputer.com/news/microsoft/meet-the-new-clippy-microsoft-unveils-copilots-mico-avatar) · [Copilot avatar (Windows Central)](https://windowscentral.com/microsoft/copilot-avatar-virtual-face-announcement-2025) · [Copilot Vision and Voice (AlternativeTo)](https://alternativeto.net/news/2024/10/microsoft-unveils-its-major-copilot-update-with-vision-and-voice-features-across-platforms)
- [ChatGPT macOS release notes](https://help.openai.com/en/articles/9703738-chatgpt-macos-app-release-notes) · [Agent mode on the Mac app (CO/AI)](https://getcoai.com/news/openai-adds-agent-mode-to-chatgpt-mac-app-for-plus-users/)
- [Claude Cowork for macOS](https://letsdatascience.com/news/anthropic-releases-claude-cowork-for-macos-34214e61) · [Claude desktop control expands](https://letsdatascience.com/news/claude-extends-desktop-control-across-macos-and-windows-0e32c092) · [Cowork research preview](https://howaiworks.ai/blog/claude-cowork-research-preview)
- [Apple brings back notification summaries (9to5Mac)](https://9to5mac.com/2025/10/27/ios-26-brought-back-a-controversial-ai-feature-heres-whats-new/) · [Apple pulls AI notification feature (ACS)](https://ia.acs.org.au/article/2025/apple-pulls-ai-notification-feature-over-errors.html)
- [Agent monitors: Claude Island alternatives](https://alternativeto.net/software/claude-island) · [Nudge](https://www.producthunt.com/products/nudge-30) · [OpenAgentPeek](https://awesome.ecosyste.ms/projects/github.com%2Fzuoxu3310%2Fopenagentpeek) · [ClaudeCodeMonitor](https://alternativeto.net/software/claudecodemonitor/about) · [AgentNotch](https://feedbagel.com/post/agentnotch-macos-menu-bar-app-for-real-time-ai-coding-assistant-monitoring)
- [Clippy as a local LLM interface (Tom's Hardware)](https://tomshardware.com/tech-industry/artificial-intelligence/clippy-resurrected-as-ai-assistant-project-turns-infamous-microsoft-mascot-into-llm-interface)
- Earlier research: docs/personas.md, docs/ask-design.md
