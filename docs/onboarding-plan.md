# Getting Hush and the first five minutes (plan)

Status: **O1 built** (in-app journey); O2–O4 waiting on a repo, Apple Developer membership and a domain · 2026-10-18 · PRD FR-1 (onboarding), FR-15 (updates), § Distribution.

## Part 1: getting Hush onto a Mac

### The hard constraint: signing

| Fact | Consequence |
| --- | --- |
| Hush is ad-hoc signed today (no Developer ID, no notarization) | It runs on this Mac only |
| macOS 15 removed the right-click → Open bypass for unsigned apps; the only route is System Settings → Privacy & Security → **Open Anyway** | A terrible first impression for anyone who downloads it |
| Homebrew 5 deprecated `--no-quarantine`, and since **1 Sept 2026** casks that fail Gatekeeper are dropped from the official tap | No `brew install --cask hush` without notarization |
| Notarization needs the **Apple Developer Program** ($99/year) and a Developer ID certificate | Required before any public release (the PRD already assumes it) |

### Three ways in (landing page order)

1. **Download for Mac** (primary button): a notarized, stapled `.dmg` from GitHub Releases. The page detects the
   architecture and states the requirements (macOS 15+, Apple silicon for on-device AI later).
2. **Homebrew** (copy button): `brew install --cask hush`. It starts in our own tap
   (`brew install --cask <owner>/hush/hush`) until the official cask is accepted. `auto_updates true`, since Sparkle updates the app.
3. **One-line install** for developers (copy button), shown as *download → review → run*, not piped blind:
   `curl -fsSL https://<site>/install.sh -o install.sh && less install.sh && sh install.sh`
   The script downloads the release zip, **verifies the SHA-256 and the code signature** (`codesign --verify`,
   `spctl --assess`), moves Hush to `/Applications`, offers to link the `hush` CLI, and opens the app.
   It never disables Gatekeeper or strips quarantine.

### After install

- **Updates:** Sparkle 2 with an EdDSA-signed appcast (PRD). Brew installs defer to Sparkle.
- **A small `hush` CLI** (grows out of `hushctl`) for developers: `hush status`, `hush hooks install|remove`,
  `hush ask "…"`, `hush open`. It's the natural CLI entry point after `brew install`.
- **Release pipeline:** a script that builds a universal release, signs with Developer ID, notarizes
  (`notarytool`), staples, makes the zip and dmg, writes checksums, updates the appcast and the tap, and drafts
  the GitHub release.

## Part 2: the onboarding journey

### Principles

1. **Hush is the guide.** No wizard window. The character walks you through with body language; plain UI cards carry
   the words (Hush itself stays silent, Principle 1).
2. **Delight before asks.** Customising the character comes before any permission. The first permission is never in
   the first 30 seconds.
3. **One question, not a form:** "What do you mostly do on your Mac?" (docs/personas.md). It picks a preset; everything stays editable.
4. **Permissions just in time, with a preview.** Each ask shows what you get first (a meeting reminder preview before
   Calendar, the watching pose before Claude Code hooks). Then the system prompt. Saying no is fine and remembered, never nagged.
5. **Learn by doing.** Gestures and ⌘⇧H are taught by having you do them, with a check as each one lands.
6. **Short and skippable.** About 2 minutes end to end, every step skippable, resumable, replayable from the menu.
   "Skip setup" lands on safe defaults.
7. **Quiet from the end.** The last step promises restraint and sets the interrupt cap, because that's the product.

### The journey

| # | Step | What you see | What it sets | Permission |
| --- | --- | --- | --- | --- |
| 0 | **Arrival** | Hush hurries in from the edge, waves. Card: "Hi, I'm Hush. I live down here and stay quiet unless something matters." **Let's go** · Skip setup | — | — |
| 1 | **Make it yours** | Body, colour, topper and accessory chips that change the real Hush live; **Surprise me** | Look | — |
| 2 | **One question** | "What do you mostly do on your Mac?" I build software · I build with AI · I manage work and messages · I just want company (pick any) | Persona preset: which features are on, how forward Hush is, perching, moods | — |
| 3 | **Say hi** (play) | Three tiny tasks with checks: hover me (it pops up) · hold to pat (it leans in) · drag me where you'd like me to live | Home spot | — |
| 4 | **Connect** (per preset) | **Calendar:** preview of the clock pose for "Design review in 10 min", then Allow · **Claude Code** (if installed): the watching pose and the exact hook diff, then Add hooks · **Ask Hush:** "Press ⌘⇧H now", with a sample question to try · **Mail:** shown only on macOS 26 (later) | Sources | Calendar; hooks file write (with diff) |
| 5 | **Quiet promise** | "How many times a day may I tap the glass?" slider (default 5) · quiet hours toggle | Cap, quiet hours | — |
| 6 | **Goodbye** | Hush walks to its home spot. Card: "I'll stay out of your way. Tonight I'll tell you what I held back." Points at the menu bar icon | — | — |

### The first week (progressive, once each)

Small one-time cards the first time something happens: the first meeting reminder ("I held up the clock: meeting in
10 minutes"), the first envelope, the first typing duck ("I duck while you type"), the first agent finishing, the first
night's tuck-in. Each has **Got it** and **Don't explain things**.

### Re-entry

Menu → **Setup checklist** (what's left: Calendar not connected, ⌘⇧H never used…) and **Replay the intro**.

### What to measure (local only; opt-in sharing later)

Onboarding completed or skipped (and at which step) · time to first delight (first hover or pat) · permissions
granted per preset · ⌘⇧H used in the first week · still running on day 1 and day 7 (PRD success metric).

## Build phases

| Phase | What | Needs |
| --- | --- | --- |
| **O1** | In-app onboarding: steps 0–6, preset logic (HushCore, tested), first-week tips, checklist, replay | Nothing (buildable now) |
| **O2** | `hush` CLI, `install.sh` (verify + install), release script (zip, dmg, checksums), own Homebrew tap | A GitHub repo for Hush (public for open source) |
| **O3** | Developer ID signing, notarization, stapling, Sparkle appcast | **Apple Developer Program membership** |
| **O4** | Landing page: hero with the character, three install paths, requirements, privacy promise | A domain (and the open trademark question on "Hush") |
