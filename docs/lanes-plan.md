# Lanes: models as settings, and the "do it" lane

2026-10-19 · Follows docs/positioning.md § Model-native: Hush owns the doorway (context, timing, routing, review);
models supply the skill, so every model upgrade makes Hush better without a rewrite.

## Decisions (R0)

- Browser runtime for "do it": **Claude in Chrome**, in your real Chrome (logged-in sessions, improves with models).
- Approval: **once per run (plan card), plus a pause before anything irreversible** (send, buy, delete, submit).
- Model names are **aliases** (`haiku`, `sonnet`, `opus`), which the Claude CLI maps to the newest model of each
  tier. A full model id can be pinned per lane if an upgrade regresses.

## L1 · Lane registry (built)

One entry per lane in `HushCore/Lanes.swift` (`LaneRegistry`): job, model, turn/spend/time caps, approval.
Defaults in code; the model is overridable per lane from the menu bar (Agent ▸ Models), stored in UserDefaults
(`laneModel.<lane>`). Callers build runner options from the spec (`Options.apply(_:)`), so nothing else hard-codes a
model.

| Lane | Job | Default model | Caps (turns · $ · s) | Approval |
| --- | --- | --- | --- | --- |
| quick | One-shot answer, shaped card | haiku | 2 · 0.05 · 40 | none |
| repo | Read-only code question | sonnet | 15 · 0.30 · 150 | none (read-only tools) |
| summarise | Digest summary of one session | haiku | 2 · 0.05 · 40 | none (opt-in feature) |
| do (L3) | Browser task | sonnet | 30 · 1.00 · 600 | plan + irreversible steps |

Hand-off lanes stay links: they use the model you already pay for.

## L2 · Eval (built)

- `evals/asks.json`: 31 asks, each with expected lane, and for quick ones an expected shape and a cheap check
  (e.g. the XLOOKUP ask must return text containing `XLOOKUP(`). Add a case whenever a real ask goes wrong.
- Routing half runs in `swift test` (free, `AskEvalTests`). Model half runs on demand:
  `swift run hush-eval [--model sonnet] [--limit N] [--filter git]`, or `--lane repo --repo <path>` for code
  questions (finish + cost only). Results land in `evals/results/` (git-ignored).
- Runs use `LaneOptions` (HushMac), the same builder Ask Hush uses, so the eval measures what ships.
- A lane's default changes only when the eval says it's better.

First baseline (2026-10-19, quick lane, 19 asks, after fixing one bad check): Haiku and Sonnet both answered every
ask correctly; Sonnet cost ~20× more ($0.006 vs $0.0003 per ask) at similar speed (p50 ~3 s). **Haiku stays the
default.** The set is too easy to separate models yet: add harder asks as real ones fail.

## L3 · "Do it" lane (browser only, behind a setting)

### What the spikes proved (2026-10-19)
- `claude -p --chrome` loads the Claude in Chrome tools (`mcp__claude-in-chrome__*`) under Hush's lean profile
  (`--strict-mcp-config --setting-sources project`). Allow them with the server-level rule `mcp__claude-in-chrome`
  (the `__*` wildcard left a permission-denial record). Needs Chrome running with the extension connected.
- **A hard gate in code works:** with the default permission mode, `--permission-prompts host
  --permission-prompt-tool mcp__<server>__<tool>`, every tool call not on the allowlist goes to our MCP tool with
  `{tool_name, input, tool_use_id}`; it answers `{"behavior":"allow","updatedInput":…}` or
  `{"behavior":"deny","message":…}` (as JSON text content), and both are honoured. Allowlisted tools skip it.
- The plan call (no tools, `TaskPlan` schema) returns sensible steps and hosts, leaves sign-in to the user, and
  marks sends as irreversible. ~$0.025 on Sonnet.

### What code can and can't enforce
The gate sees the tool name and input only. **Hard, in code** (`BrowserGate`, tested): looking is allowed; code,
uploads, saved shortcuts, other tabs' traffic and browser switching are denied; unknown tools are denied;
navigation stays on the plan's sites (others ask; non-web URLs are denied). **Not possible in code:** telling a
"Send" click from a "Next" click. So clicks and typing follow a `ClickPolicy`:
- `askEvery`: every click, keypress and form fill waits for a tap (truly hard, but chatty), or
- `allowAfterApproval`: approve the plan once; the model is told to stop before steps it marked irreversible
  (soft for clicks, hard for everything else). Card copy must say it's *told* to ask, not "nothing irreversible
  without your tap".
**Open decision for the user.**

### Decision (2026-10-19): option B
Approve the plan once; clicks and typing run on the plan's sites; the model asks (via `confirm`) before steps it
recognises as irreversible. Everything else in the gate is code. The card says exactly that.

### Built (2026-10-19), behind Agent ▸ Browser tasks (beta), off by default
- Core (HushCore, tested): `DoIntent`, `TaskPlan` (+ schema, plan prompt, run prompt), `BrowserGate`,
  `GateRequest`/`GateReply`, `AskLane.browser` (router: `@do`, or a browser task when the setting is on).
- `hushctl gate <socket> <token> <plan>`: MCP server with `approve` (permission prompt → BrowserGate) and `confirm`
  (model asks you). Asks Hush over the socket; any failure = no.
- `GateServer` (HushMac): unix socket `~/Library/Application Support/Hush/gate.sock`, 0600, started at the first
  approved run; one fresh token per run; wrong or missing token = no.
- `BrowserTaskController` (app): plan (no tools) → plan card → Run it → Claude Code with `--chrome`, allowlist
  `mcp__hush__confirm` only, everything else through the gate; run files (plan, MCP config) are 0600 and deleted
  after. Steps stream onto the card; questions appear on it ("Before I do this" / "This needs your OK");
  Stop answers no. Done goes through the engine as a gentle item if the card is closed.
- Card pieces: `BrowserTaskViews` (`PlanBody`, `BrowserProgress`, `PillButton`).

### Verified
- Plan card renders from a real plan; Approve starts a run; the gate chain (`claude` → `hushctl gate` → socket)
  returns yes/no correctly; a non-browser tool is refused in code without asking; the app's socket refuses a
  wrong token; a `confirm` during a real run shows on the card and the tap returns to the gate.
- A `confirm` answered after 120 s still reaches the model (the gate waits up to 300 s; the card clears an
  unanswered question at 290 s and counts it as no).
- **Not yet verified: a task actually running in a browser.** This Mac has Comet, not Google Chrome, and the
  Claude extension reports no connected browser.
- `tabs_context_mcp {createIfEmpty: true}` never reaches the gate; without a connected extension Claude Code's
  Chrome integration records it as a permission denial anyway. Hush logs denials and keeps them off the card.

### Other browsers (Comet, 2026-10-19)
- Any Chromium browser with the Claude extension works in principle. Claude Code installs the extension's connection
  manifest (`com.anthropic.claude_code_browser_extension.json`, pointing at `~/.claude/chrome/chrome-native-host`)
  for Chrome, Arc, Brave, Edge, Vivaldi, Opera, Chromium and Atlas, **not Comet**.
- Hush (`TaskBrowsers`, HushMac) finds browsers with the extension, picks one (Agent ▸ Run browser tasks in:
  automatic = a running one with the extension), launches it, names it on the card, and on Approve copies the
  manifest into the browser's `NativeMessagingHosts` if missing. It only copies Claude Code's own manifest (checked
  host name and allowed origin).
- Comet's manifest was added by hand on 2026-10-19 with the user's OK. Comet isn't an officially supported browser;
  the extension must reconnect (click it once, or restart Comet) after the manifest appears.

### Limits to keep honest
- Site checks cover addresses the model asks to open (`navigate`, also inside `browser_batch`). Links it clicks
  aren't checked. `tabs_create_mcp` opens an empty tab (no URL).
- "Asks before sending, buying, deleting" and "never types passwords" are instructions to the model (option B).
- Gate decisions are logged as `gate:` lines in diagnostics.log (tool, verdict, reason, host; never page content).
- Debug hooks `approve` / `answer:yes|no` can approve from any local process: dev-only, and only while
  `HushDebugHooks` is on (off by default; relaunch after turning it off).

## L4 · Desktop control (later, opt-in)

Needs Accessibility + Screen Recording. Off by default (Accessibility was declined for ⌘V); offered only when a
task needs it, with the same plan card and pauses.

## Later runtimes

The registry has room for other places a model runs: an Anthropic API key (needed for release, Phase 5), Apple's
on-device model on macOS 26 (free, private triage and short summaries), other providers if wanted.
