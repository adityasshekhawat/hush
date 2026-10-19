# Talking to Hush: a background agent for developers (plan)

Status: **planned, decisions made, not started** · 2026-10-18 · see also PRD § Scope (v2 quick-ask, "Later: agent reactions"), ADR-012.

## Decisions (2026-10-18)

- **Backend:** Claude Code CLI under a builder-only flag. API-key backend (Phase 5) before anyone else gets Hush.
- **First slice:** Phase 0 (spikes) + Phase 1 (Hush watches your Claude Code sessions).
- **Hooks:** merge into `~/.claude/settings.json` next to the existing RTK hook; show the diff and get an OK before
  writing; one-click uninstall.
- **Command-box hotkey:** ⌘⇧H (Phase 0 checks it isn't swallowed by the frontmost app; some apps use it for "Home").

## Goal

You type to Hush (it never talks back out loud), and a background agent does small developer tasks for you. While it
works, Hush shows what's happening through posture: listen while you type, think while it works, hold up an envelope when
it's done, a polite "needs you" when it wants approval. Start with tiny, safe wins and grow from there.

## What doesn't change

| Rule | What it means for the agent |
| --- | --- |
| **Silent** (Principle 1) | Input is typed; macOS dictation works in any text field, so voice *input* comes free. Answers appear as plain UI text in the card. The designer's command-window note: "the box shows your words, never Hush's; Hush only reacts with posture." |
| **Attention is earned** (Principle 2) | Agent events become `InboxItem`s and go through the `DecisionEngine`: the daily cap, focus queue and quiet hours apply. "Done" and "needs approval" are **gentle at most**; they only interrupt if you write a rule saying so. |
| **Respect focus** (Principle 3) | During calls, results queue like mail. |
| **Scrutable** (Principle 4) | Every task, its prompt, the tools it used and its result are in a local task log you can read and delete. |
| **Local-first** (Principle 5) | Code is sent to a model only for repos you've explicitly allowed (a list in settings). Nothing else leaves the Mac. |
| **Resource budget** (ADR-011) | "Thinking" for minutes must not bring back continuous SVG animation. Long-running states use still poses or composited loops; calm mode still applies. |

## The backend question (decide before shipping)

| Backend | Works today? | Shippable? | Cost |
| --- | --- | --- | --- |
| **Claude Code CLI** (`claude -p --output-format stream-json`) on your own login | Yes (2.1.302 installed) | **No.** PRD: Anthropic's terms prohibit third-party apps using Free/Pro/Max credentials; invoking your own unmodified `claude -p` locally is "tolerated for experimentation, not shippable". Re-check the PRD's source (code.claude.com/docs/en/legal-and-compliance) before anything ships. | Your subscription |
| **Anthropic API, your own key** (Messages API over HTTP from Swift; no official Swift SDK) | Needs a key (none set) | Yes | Per token. Current models: Opus 5.5 ($4/$20 per MTok, default), Sonnet 5.5 ($2/$10), Haiku 5.5 ($0.10/$0.50) |
| **Claude Agent SDK** (Claude Code as a library, TS/Python) with your key | Needs a key + a Node/Python runtime | Yes | Per token. Dependency advisory check required before adding |
| **On-device** (Foundation Models, macOS 26) | No (this Mac is on 15) | Yes | Free; only for tiny tasks |

**Plan:** build against an `AgentBackend` protocol. Use the CLI backend under a builder-only flag for Phases 0–3, then
add the API-key backend (Phase 5) before any public release. Note: the PRD's "Haiku 5.5" is correct; my earlier notes
saying Haiku 4.5 was current were stale.

## Phase 0 results (2026-10-18)

| Spike | Result |
| --- | --- |
| Hook payloads | Captured from a real run: every event has `session_id`, `cwd`, `hook_event_name`; `UserPromptSubmit` carries the prompt and `Stop` carries `last_assistant_message`, so `hushctl` reads only the three ids and drops the rest. |
| CLI stream + cancel | `ClaudeCodeRunner` (HushMac). From inside the app, a read-only question: started 2.6 s, Grep + Read, first text 7.6 s, done 8.5 s, $0.006. Cancel mid-run: stopped at 5.1 s, no orphan process. `--max-turns` works though it's not in `--help`. |
| ⌘⇧H hotkey | Registered (Carbon, no Accessibility). **Real key press not yet tested** (needs you). |
| Typing panel | Opens with keyboard focus, remembers the previous app, closes on Enter/Escape/click-away/app switch, hands focus back. Scripted opens can be refused focus by macOS (only real input may activate an app), so it closes itself instead of lingering. **Real typing not yet tested.** |

## Phases

Each phase ends with a **real-use acceptance check** (no more "built, untested" like the card buttons).

### Phase 0: spikes (about a day)

1. **Global hotkey without permissions.** Carbon `RegisterEventHotKey` (no Accessibility, which you declined). Accept:
   pressing it from any app opens the box.
2. **A panel that can take typing.** The overlay panel can never become key (by design). The command box needs its own
   activating panel that returns focus to your app afterwards. This also lets us verify the envelope card's buttons with
   real clicks. Accept: type, Enter, Escape, and focus goes back to where it was.
3. **CLI streaming and cancel.** Spawn `claude -p --output-format stream-json --include-partial-messages` off the main
   actor, parse events, cancel cleanly, with time and turn budgets. Accept: a question answered and a run cancelled
   mid-stream, both logged.
4. **Hook payloads.** Confirm Claude Code's hook event names and which fields carry the session id, cwd and message
   (verify against the docs and a captured payload; don't assume).

## Phase 2 results (2026-10-18)

Built: ⌘⇧H box with a repo picker (allowed repos only; "Add folder…"), read-only run (`ReadOnlyProfile`: Read, Grep,
Glob, read-only git/gh), lean context profile, answer streams into a non-activating card (inline Markdown, Stop, Copy),
Hush thinks while it runs, "Answer ready" envelope through the engine if you closed the card, local history
(Agent → Show history / Forget history).

Acceptance (Sonnet, 7 real questions, hush + a second app repo): all answered in 2–9 s at $0.020–0.047 each, 10–33K context
tokens per run. The edit request was refused, README untouched. Stop cancels cleanly with no orphan process.
Found and fixed: Claude used `git -C <path> log`, which the `git log` allowlist pattern doesn't match; the instructions
now say to run plain `git …` from the repo (allowing `git -C` generally would also allow write commands). Permission
denials are logged.

Cost note: Sonnet is ~$0.04/question. Haiku was ~$0.002–0.006 in the spikes; a per-question model switch is an option.

### Phase 1: Hush watches your Claude Code sessions (no talking yet)

The PRD's "Agent reactions" item. It needs no model calls and has no auth question, and you live in Claude Code, so it's
an immediate win.

- Small hooks (`UserPromptSubmit` / `PreToolUse`, `Notification`, `Stop`) run a tiny bundled `hushctl` that sends a
  **status event** to Hush over a new, narrow channel. It accepts status only (session id, cwd, event kind), is validated,
  and can never start a task: any local process can post distributed notifications, so the channel must not be a command
  path. It is separate from the debug hooks.
- **Many sessions at once** (including the one building Hush): events are keyed by session id. "Done" and "needs approval"
  surface only when that terminal isn't frontmost, or the run took longer than a few minutes; otherwise they stay ambient.
- Hush shows **think** while a session works, a **gentle envelope** when a long run finishes ("Claude finished in hush,
  6 min"), and a polite **needs-you** pose when it's waiting on a permission prompt. Card actions: open the terminal, or
  not this kind again.
- **Installing the hooks edits `~/.claude/settings.json`**, which already has your RTK `PreToolUse` hook. Merge, never
  overwrite, show the diff, and get your OK first. One-click uninstall.
- Accept: a real Claude Code run in another terminal produces think → envelope, with no envelope for quick runs you're
  watching.

### Phase 2: Ask Hush (read-only)

- Hotkey → the command box unfolds above Hush (the designer's command-window sequence: pop up, look up, head tilt while
  you type, think, hand back the answer). The answer streams into the card as plain text.
- **Which repo:** the most recent Phase-1 session's cwd, or a picker of allowed repos (window titles are hidden without
  Screen Recording permission, so we can't read "the repo you're looking at").
- **Read-only tools only:** `Read`, `Grep`, `Glob`, and an allowlist of `Bash` commands (`git log/diff/status/show`,
  `gh pr view/list/checks`). Passed through `--settings` / `--allowedTools` per run, so your global setup is untouched.
- **Starter tasks:** explain this diff, draft a commit message, draft a PR description, why did this test fail (paste or
  point at output), what changed since yesterday, where is X defined.
- Accept: five real questions on real repos answered, each logged with its prompt, tools and cost.

### Phase 3: background tasks that change code (isolated)

- Every task runs in its own **`git worktree`** on a new branch. Your working copy is never touched.
- **One task at a time**, with turn, time and spend budgets. While it runs Hush is ambient (no pose that animates for
  minutes); when it finishes, an envelope with a diff summary and **Apply · Discard · Open diff · Open PR**. Nothing is
  pushed or opened as a PR without an explicit click.
- **Approvals:** tool calls outside the task's allowlist pause the run and surface as a gentle "needs you" card
  (Approve / Deny), via `--permission-prompts host`.
- **Starter tasks:** write tests for a function, fix lint/type errors in a file, update a README section, rename a symbol,
  bump one dependency (with the dependency advisory check).
- Accept: three real tasks applied, one discarded, one approval round-trip, zero changes to the working copy.

### Phase 4: proactive suggestions (opt-in, capped)

- Signals that suggest a task, offered as a gentle card ("CI failed on #123. Want me to look?"): CI failure on your PR, a
  review requested, merge conflict on your branch. Counts toward the interrupt cap; three dismissals of a kind stop it.
- A day summary in the tuck-in card (what your agents did, what you merged).

### Phase 5: shippable backend

- The API-key backend from Swift (raw HTTP to the Messages API; streaming; adaptive thinking; effort tuned per task),
  key in Keychain, model picker, spend shown per task. If we use the Agent SDK or any package instead, run the
  dependency advisory check first.

## Where the code goes

| Piece | Target |
| --- | --- |
| `AgentTask` (id, repo, prompt, status: queued/running/needsApproval/done/failed, transcript ref, result, cost), queue policy (one at a time, budgets), mapping agent events → `InboxItem` / attention level | `HushCore`, with tests |
| Task log | the existing SQLite store (new table) |
| CLI backend (process spawn, stream-JSON parsing, cancel), worktree manager, hook-event receiver | `HushMac`, off the main actor |
| Command box panel, hotkey, streaming answer card, approval card, repo allowlist settings | `Hush` |
| `hushctl` (status events from hooks) | new tiny executable target |

## Risks

| Risk | Mitigation |
| --- | --- |
| **Scope creep.** The PRD's own risk table says "scope creep into chat and agents → v1 never ships"; mail (MailKit) still isn't built | ADR-012 records this as a deliberate reprioritisation. Phases are small and each stands alone. |
| Shipping on the CLI backend breaks the terms | Builder-only flag; Phase 5 before any release |
| Hush becomes noisy with many sessions | Keyed by session; frontmost-terminal and duration filters; everything through the cap |
| An agent damages a repo | Worktrees, read-only first, explicit Apply, never auto-push |
| Prompt injection from repo content | Read-only tools in Phase 2; allowlists and approvals in Phase 3; no network tools by default |
| CPU creep from long "thinking" states | Still or composited poses; measured against ADR-011 each phase |
