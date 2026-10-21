# Changelog

Hush is pre-alpha and built from source. Notable changes, newest first. Decisions behind them are in
[`docs/decisions.md`](docs/decisions.md).

## 0.2.0 (2026-10-22)

- **Hush tells you when there's a new version:** choose Check for updates… in the menu bar panel's ··· menu, or say
  yes once to a daily check (Settings ▸ General). A new version shows in the panel with Update, which opens Terminal
  in the folder you built Hush from and runs `git pull --ff-only && ./scripts/bundle.sh`. Releases come from
  `./scripts/release.sh`.
- **Hush tells you about shorter runs:** a Claude Code or Codex run that finishes while you're in another app now gets
  an envelope from 45 seconds, not 2 minutes. Most answers take 1 to 2 minutes, so they used to finish in silence.
- **A new menu bar panel:** it answers "does anything need me?" first, with your own Hush's face in the header, then
  what waits with its one action (Open, Join), today's held-back count, and three places: Agents, While you were away
  and Ask Hush. Pause is one button with a menu, and an eye button shows or hides Hush in screenshots with one click.
  Connections and Ask Hush costs moved to Settings. Fixes "Pau se" and "Watchi ng" wrapping in the old panel.
- **Installs on Intel Macs:** `bundle.sh` failed its signature check there, because Intel's linker doesn't sign the
  `hushctl` helper. Found by the new install test, which installs Hush the README's way on six fresh Macs (Apple
  silicon and Intel, macOS 15 and 26, Xcode and Command Line Tools only) on every change and weekly. `bundle.sh` also
  says in plain words when macOS is too old or the Command Line Tools are missing.
- **Show me in screenshots:** a switch in the menu bar panel, so you can let Hush into a screenshot or a share and
  hide it again with one click (the same setting as Settings ▸ General).

## 0.1.0 (2026-10-21)

The first public version. Pre-alpha, built from source.

- **Builds on the macOS 26 SDKs again** (Command Line Tools 26.x failed on a renamed Apple Intelligence option), and
  CI now builds and tests on Xcode 16 and Xcode 26. **Updating** is in the README and on the website: `git pull`, then
  `./scripts/bundle.sh`.
- **A day with Hush:** a 96-second animated film on the website, made with Remotion from Hush's own art (a drone shot over
  a crowd of Hushes, then one Hush through its day). The recorded tour stays one click below it.

- **A tour video on the website:** under 3 minutes, recorded from the app itself (Hush draws every frame, so no real
  window, tab or desktop is in it). Agent sessions, meetings and mail are simulated; Hand it to Hush and Ask Hush ran
  for real. The landing page deploys from `site/` again.

- **New character art, wired in:** Hush raises its hand when an agent needs you, holds up a "Look carefully" card for
  risky requests, shrugs over a smoking laptop when a run stops, checks a pocket watch before a meeting and holds the
  door open when it starts, pulls down a blind with a "Do not disturb" sign when you pause it, wears a nightcap in
  energy saver, tumbles away when you flick it, chews properly and hands back a folded note, and carries a satchel for
  the mail digest. All of it is still poses, so it costs nothing while it waits.
- **The flag rail:** agent sessions waiting behind the one Hush holds stand as small flags on the bottom edge, with
  the project's name. Click one to open its card. Up to 5, then "+N more".
- **Nightcap** in the wardrobe (free, all bodies and colours). Speech bubbles are glass on macOS 26 too.
- **A paused glyph** in the menu bar, the notebook cover in What Hush saw, Liquid Glass cards on macOS 26 and later,
  and a layered app icon for macOS 26 (built with Xcode; the flat icon otherwise). README GIFs re-recorded.

- **README:** a new look with illustrated features, light and dark hero art, and a social preview image
  (`docs/readme`). Copy checked against the app: build from source, nine colours, 5 and 1 minute meeting nudges, what
  the hooks really send. It now lists every feature, including the journal, rule suggestions, the sessions lane,
  answers into your apps and rare finds, and `docs/features.md` covers the newer surfaces.

- **Open works again:** clicking Open on a card when a Claude session finishes or needs you brings that session forward,
  in Terminal or iTerm on its exact tab, or in the app it runs in (including the Claude app). It also works after the
  session has ended.

- **Fixes:** times on cards follow your Mac's clock format (an evening meeting no longer reads as morning); model-written
  lines never contain dashes; the mail digest card no longer repeats its title; the Hand it to Hush card fits all three
  verbs. The README shows each feature recorded from the app.

- **Mail, ready for a source:** rules for words in the subject ("always tap the glass for mail about outage"), which
  also win over the bulk-mail filter; judging by sender and subject only unless you allow the first lines (measured:
  22/24 vs 23/24); "Always show them" on a mail the model brought forward; and a digest at natural breaks instead of
  a visit per mail. Real mail still needs the Apple Mail extension.

- **What Hush saw:** a journal of everything Hush looked at this week, what it did and why, in plain words. On this
  Mac, kept 7 days, with Forget (menu bar ▸ What I saw).
- **Tell Hush what matters:** in What I've learned, type it your way ("tap the glass when boss@acme.com writes") and
  Apple's on-device model proposes rules for you to add one by one. Rules still run in code.
- **First run:** if nothing real is waiting when setup ends, Hush shows once what an alert looks like.

- **Meetings:** a heads-up 5 minutes before with one line about what it's for (written on your Mac), then Hush comes
  out a minute before and waits. One click on Hush joins the call (Zoom, Meet, Teams and more). "1 more min" snoozes;
  joining (your mic turning on) puts it away. Events marked "free" are skipped. Lead times in Settings.

- **The agent watcher says what your agent wants.** "Claude wants to run npm test", with risky requests (deleting
  files, force-pushing, production, secrets) flagged for a careful look by rules in code. Runs that stop on an error
  ("Hit a usage limit") get a quiet card. Open lands on the exact Terminal or iTerm tab. Approvals wait until you
  answer them, cards line up by priority with an "Also waiting" line, and switching to the session's terminal clears
  its card. Hook events now travel over a private socket instead of a system-wide broadcast. Existing installs get an
  Update button (Settings ▸ Connections) that shows the change first.

- **Never in the way:** pause for 15 minutes, an hour or until tomorrow from the menu bar; ⌥⇧⌘H puts away what Hush
  is showing, pauses it, or brings it back. Off screen means off: nothing runs while paused, locked or in a call.
  Energy saver in Low Power Mode or on low battery. Measured costs in `docs/performance.md`.
- **Hand it to Hush:** copy text, click Hush, pick Simpler, Shorter or Bullets. It chews and hands the result back
  on your clipboard. On this Mac, with Apple Intelligence.
- **Mail judging on this Mac:** Apple's on-device model decides whether a mail is worth showing and writes its
  one-line gist (real mail arrives with the Mail extension, next).
- **Copies and pastes:** ⌘Tab after copying no longer counts as a paste.
- Builds on macOS 27 with Xcode 27 or Command Line Tools.
- Open source: code under Apache-2.0. Hush's character, name and icon are reserved; wardrobe and prop art is
  CC BY-SA 4.0 and open for contributions.
