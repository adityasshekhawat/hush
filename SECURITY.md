# Security

Hush runs on your Mac with your user's permissions. It has no server and no telemetry. The README's
"What leaves your Mac" table lists every time anything is sent anywhere.

## What it reads and sends
- **Calendar:** read through macOS (EventKit) after you allow it.
- **Claude Code / Codex sessions:** hooks you approve send Hush the event, session id, folder, host app and terminal
  device; when an agent asks permission, the tool and up to 200 characters of its input (a command, a file path, an
  address); when a run fails, the error type. Nothing else, never your prompts or the agent's replies. Hush keeps it in
  memory only. Transcripts in `~/.claude/projects` are read only if you turn on the digest.
- **Model calls:** mail judging and "hand it to Hush" run on Apple's on-device model. Ask Hush answers, routing
  checks, Summarise and browser tasks run through your own Claude Code login, and only when you ask.
- **Clipboard:** read only when you click Hush to rework what you copied, after you've agreed once. Otherwise Hush
  sees only that the clipboard changed, never what's on it.

## Local trust model (worth knowing)
- **Agent status events** arrive over a Unix socket in Hush's Application Support folder (0600), so only your user's
  processes can send one and nothing is broadcast to other apps. Hush validates every field and rate-limits them, but
  they aren't authenticated beyond that: another program running as you could post a fake "Claude finished" or
  "needs you" card. The channel can't start a task or run anything.
- **Browser tasks** ask Hush's permission gate over a Unix socket only your user can open (0600), with a fresh token
  per run. What code enforces (tools, sites) and what the model is only told (asking before sending, buying,
  deleting) is spelled out in `docs/lanes-plan.md`.
- **Debug hooks** (`defaults write dev.hush.Hush HushDebugHooks -bool YES`) let any local process drive Hush,
  including approving browser tasks. They're off by default; turn them off again and relaunch after use.
- **Sending a message to a session** types into a Terminal or iTerm tab only when you press Send, after macOS asks
  you to allow it once per app.

## Reporting a problem
Please don't open a public issue for a security bug. Use **Report a vulnerability** on the repository's
[Security tab](../../security/advisories/new) (GitHub's private vulnerability reporting): only you and the maintainers
see it. Include steps to reproduce. You'll get a reply within a week.
