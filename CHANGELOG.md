# Changelog

Hush is pre-alpha and built from source. Notable changes, newest first. Decisions behind them are in
[`docs/decisions.md`](docs/decisions.md).

## Unreleased

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
