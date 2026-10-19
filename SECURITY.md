# Security

Hush runs on your Mac with your user's permissions. It has no server and no telemetry.

## What it reads and sends
- **Calendar:** read through macOS (EventKit) after you allow it.
- **Claude Code / Codex sessions:** hooks you approve send Hush four fields per event (event, session id, folder,
  host app) plus the terminal device. Transcripts in `~/.claude/projects` are read only if you turn on the digest.
- **Model calls** (Ask Hush, summaries, routing checks, browser tasks) run through your own Claude Code login. A
  question leaves your Mac only when you ask one.

## Local trust model (worth knowing)
- **Agent status events** arrive over a macOS distributed notification. Any app on your Mac could post one. Hush
  validates every field and rate-limits them, but they aren't authenticated: the worst case is a fake "Claude
  finished" envelope.
- **Browser tasks** ask Hush's permission gate over a Unix socket only your user can open (0600), with a fresh token
  per run. What code enforces (tools, sites) and what the model is only told (asking before sending, buying,
  deleting) is spelled out in `docs/lanes-plan.md`.
- **Debug hooks** (`defaults write dev.hush.Hush HushDebugHooks -bool YES`) let any local process drive Hush,
  including approving browser tasks. They're off by default; turn them off again and relaunch after use.
- **Sending a message to a session** types into a Terminal or iTerm tab only when you press Send, after macOS asks
  you to allow it once per app.

## Reporting a problem
Please don't open a public issue for a security bug. Email the maintainer (address in the repository profile) or use
GitHub's private vulnerability reporting, with steps to reproduce. You'll get a reply within a week.
