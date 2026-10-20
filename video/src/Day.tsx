import React from "react";
import { AbsoluteFill, Easing, interpolate, interpolateColors, random, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { BODY, C, DISPLAY, Fonts, MAC } from "./lib/brand";
import { Card } from "./lib/Card";
import { Hush, Look } from "./lib/Hush";
import { Caption, Edge, Key, Logo, Win } from "./lib/ui";

// "A day with Hush" (about 90 s): a drone shot over a crowd of Hushes swoops down onto one, which walks through its
// day along one long desktop while the camera glides with it, then the drone pulls back out. Everything shown is
// what Hush does today; mail, which isn't connected yet, says "coming soon". App icons are the real ones from this
// Mac (scripts/app-icons.swift), shown as the apps Hush works with.

type K = { W: number; H: number; u: number; floor: number; cx: number; hs: number; tall: boolean; wide: boolean; px: number };
type HushState = Look & { dx?: number; dy?: number; rot?: number; opacity?: number; floorY?: number };
type Scene = { id: string; dur: number; bg: string; floor: string; light?: boolean;
               caps: { at: [number, number]; lines: [string, string?] }[];
               draw: (t: number, k: K) => { node: React.ReactNode; hush: HushState } };

const ease = (t: number, a: number, b: number) => interpolate(t, [a, b], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.inOut(Easing.cubic) });
const pop = (t: number, at: number, fps = 30, damping = 12) => (t < at ? 0 : spring({ frame: t - at, fps, config: { damping } }));
const alt = (t: number, every: number, a: string, b: string) => (Math.floor(t / every) % 2 ? b : a);

// ---------- the scenes, left to right along the desktop ----------

const home: Scene = {
  id: "home", dur: 150, bg: "#F7F3EC", floor: C.oat,
  caps: [{ at: [10, 140], lines: ["Meet Hush.", "A small, silent friend at the bottom of your Mac"] }],
  draw: (t, k) => {
    const apps = ["terminal", "claude", "calendar", "zoom", "notes", "excel", "music", "safari", "mail", "slack"];
    const size = Math.min(84 * k.u, (k.W - 120 * k.u) / apps.length - 16 * k.u);
    return {
      node: (
        <div style={{ position: "absolute", left: 0, top: k.floor - k.hs - 230 * k.u, width: k.W, textAlign: "center" }}>
          <div style={{ display: "inline-flex", gap: 16 * k.u, padding: `${14 * k.u}px ${18 * k.u}px`, borderRadius: 26 * k.u,
                        background: "rgba(255,255,255,.55)", boxShadow: `0 ${10 * k.u}px ${30 * k.u}px rgba(22,20,27,.10)` }}>
            {apps.map((a, i) => {
              const p = pop(t, 30 + i * 4);
              return <div key={a} style={{ transform: `translateY(${(1 - p) * 60 * k.u + Math.sin((t + i * 7) / 9) * 3 * k.u}px) scale(${p})` }}><Logo app={a} size={size} /></div>;
            })}
          </div>
          <div style={{ fontFamily: BODY, fontWeight: 600, fontSize: 24 * k.u, color: C.muted, marginTop: 14 * k.u, opacity: pop(t, 70) }}>
            Works with the apps you already use
          </div>
        </div>
      ),
      hush: t < 40 ? { pose: "peek" } : t < 72 ? { pose: "stretch", expr: "squint" } : t < 120 ? { pose: "wave", expr: "happy" } : { pose: "stand", expr: "happy" },
    };
  },
};

const UPDATES: [string, string][] = [
  ["Claude finished in web", "Ran for 12s"], ["Codex finished in api", "Tests passed"], ["Claude is working in docs", "Editing 3 files"],
  ["Claude finished in site", "Ran for 40s"], ["Codex finished in cli", "Build succeeded"], ["Claude finished in app", "Ran for 15s"],
  ["Claude is working in api", "Running npm test"], ["Codex finished in docs", "Ran for 1m"],
];

const agents: Scene = {
  id: "agents", dur: 330, bg: "#EEE8F8", floor: C.oat,
  caps: [{ at: [10, 160], lines: ["It watches your agents.", "Claude Code and Codex, through hooks you approve"] },
         { at: [172, 320], lines: ["It only taps the glass when one needs you.", "The rest wait as flags"] }],
  draw: (t, k) => {
    const lines = ["> claude", "Reading the repo", "Editing src/app.ts", "Editing src/api.ts", "Running npm test", "  42 passing"];
    const winW = Math.min(560 * k.u, k.W / 2 - 210 * k.u), winH = 300 * k.u;
    const winY = k.floor - winH - 40 * k.u;
    const cardW = Math.min(400 * k.u, k.W - 120 * k.u);
    const held = Math.min(UPDATES.length, Math.max(0, Math.floor((t - 60) / 13)));
    const flagScale = k.hs / 146;
    return {
      node: (
        <>
          <Win x={40 * k.u} y={winY} w={winW} h={winH} app="terminal" title="web — claude" u={k.u} dark>
            <div style={{ padding: 18 * k.u, fontFamily: "ui-monospace, Menlo, monospace", fontSize: 19 * k.u, lineHeight: 1.6, color: "#CFE8D6" }}>
              {lines.slice(0, Math.max(1, Math.floor(t / 22) + 1)).map((l, i) => <div key={i} style={{ color: i === 0 ? "#C9BBEC" : undefined }}>{l}</div>)}
            </div>
          </Win>
          {UPDATES.map(([title, line], i) => {
            const at = 60 + i * 13;
            if (t < at) return null;
            const p = pop(t, at, 30, 14);
            // Each lands on the stack above Hush, then gets tucked away up into the count.
            const gone = ease(t, at + 30, at + 44);
            const x = k.cx - cardW / 2, y = k.floor - k.hs - 190 * k.u - i * 8 * k.u - gone * (k.floor - k.hs - 190 * k.u - (k.tall ? 360 : 230) * k.u);
            return <Card key={i} title={title} line={line} width={cardW} app={title.startsWith("Claude") ? "claude" : undefined}
                         style={{ left: x, top: y + (1 - p) * -120 * k.u, opacity: (1 - gone) * p, transform: `scale(${1 - gone * 0.6}) rotate(${(i % 3 - 1) * 2}deg)`, zIndex: 10 + i }} />;
          })}
          {t >= 60 && t < 175 && (
            <div style={{ position: "absolute", left: 0, width: k.W, top: (k.tall ? 360 : 235) * k.u, textAlign: "center", fontFamily: DISPLAY, color: C.lilacInk,
                          transform: `scale(${pop(t, 60)})`, opacity: 1 - ease(t, 165, 175) }}>
              <span style={{ fontWeight: 800, fontSize: 96 * k.u, letterSpacing: "-0.05em" }}>{held}</span>
              <span style={{ fontWeight: 700, fontSize: 34 * k.u, marginLeft: 14 * k.u }}>held back</span>
            </div>
          )}
          {t >= 172 && (
            <Card title="Claude needs you in api" line="Wants to run rm -rf build · look carefully" tone="careful" app="claude" width={Math.min(440 * k.u, k.W - 120 * k.u)}
                  style={{ left: k.cx - Math.min(440 * k.u, k.W - 120 * k.u) / 2, top: k.floor - k.hs - 190 * k.u - (1 - pop(t, 172, 30, 11)) * 200 * k.u, zIndex: 50 }} />
          )}
          {["web", "site", "docs"].map((name, j) => {
            const p = pop(t, 250 + j * 10, 30, 9);
            return <Edge key={name} name={j === 0 ? "flag-needs" : "flag-done"} label={name} x={k.cx - 130 * k.u - (2 - j) * 64 * flagScale * 1.4}
                         y={k.floor} scale={flagScale * 1.1} style={{ transform: `scaleY(${p})`, transformOrigin: "50% 100%" }} />;
          })}
        </>
      ),
      hush: t < 60 ? { pose: "sitThink", expr: "thinking" } : t < 172 ? { pose: "stand", expr: "alert", lookx: 3 }
        : t < 202 ? { pose: alt(t, 5, "knockUp", "knock") } : t < 250 ? { pose: "raiseHand" } : { pose: "holdCardBoth", expr: "worried" },
    };
  },
};

const meeting: Scene = {
  id: "meeting", dur: 270, bg: "#E4F3EA", floor: C.oat,
  caps: [{ at: [10, 135], lines: ["It gets you to meetings.", "A heads-up 5 minutes before, then it holds the door"] },
         { at: [148, 262], lines: ["One click joins.", "Then it gets out of the way"] }],
  draw: (t, k) => {
    const cardW = Math.min(420 * k.u, k.W - 120 * k.u);
    const scale = k.hs / 146;
    const joinedAt = 205;
    return {
      node: (
        <>
          {t < 150 && (
            <Card title="Design review" line="In 5 minutes · Priya, Sam and 3 others" app="calendar" source="Calendar" width={cardW}
                  style={{ left: k.cx - cardW / 2, top: k.floor - k.hs - 150 * k.u, opacity: pop(t, 20) * (1 - ease(t, 135, 150)),
                           transform: `translateY(${(1 - pop(t, 20)) * -80 * k.u}px)` }} />
          )}
          {t >= 130 && t < joinedAt + 10 && <Edge name={t > 190 ? "door-ajar" : "door-open"} x={k.cx - 150 * k.u} y={k.floor} scale={scale * 1.15}
                                                   style={{ opacity: pop(t, 130) * (1 - ease(t, joinedAt, joinedAt + 10)) }} />}
          {t >= 150 && t < joinedAt + 12 && (
            <Card title="Design review · starting now" line="Join with one click" app="zoom" source="Calendar · Zoom link" width={cardW}
                  style={{ left: k.cx - cardW / 2, top: k.floor - k.hs - 190 * k.u, opacity: pop(t, 150) * (1 - ease(t, joinedAt, joinedAt + 12)) }}>
              <div style={{ marginTop: 10 * k.u, display: "inline-flex", alignItems: "center", gap: 8 * k.u, padding: `${6 * k.u}px ${14 * k.u}px`, borderRadius: 16 * k.u,
                            background: t > 192 && t < 198 ? C.lilacInk : C.ink, color: C.cream, fontFamily: MAC, fontWeight: 600, fontSize: 14 * k.u }}>
                <Logo app="zoom" size={18 * k.u} /> Join
              </div>
            </Card>
          )}
          {t >= joinedAt && (
            <Win x={k.cx - Math.min(420 * k.u, k.W / 2 - 40 * k.u)} y={k.floor - 330 * k.u} w={Math.min(840 * k.u, k.W - 80 * k.u)} h={280 * k.u} app="zoom" title="Design review" u={k.u} dark
                 style={{ opacity: pop(t, joinedAt), transform: `scale(${0.9 + 0.1 * pop(t, joinedAt)})` }}>
              <div style={{ display: "flex", gap: 14 * k.u, padding: 16 * k.u, height: "100%", boxSizing: "border-box" }}>
                {["#A7CBEE", "#F4B9B3", "#C6E8D2", "#F4D9A6"].map((c, i) => (
                  <div key={i} style={{ flex: 1, borderRadius: 10 * k.u, background: "#2E2B36", display: "flex", alignItems: "center", justifyContent: "center", height: 190 * k.u }}>
                    <div style={{ width: 64 * k.u, height: 64 * k.u, borderRadius: 32 * k.u, background: c }} />
                  </div>
                ))}
              </div>
            </Win>
          )}
        </>
      ),
      hush: t < 130 ? { pose: alt(t, 18, "checkWatch", "checkWatchTap") } : t < 192 ? { pose: alt(t, 12, "holdDoor", "holdDoor2"), dy: 0 }
        : t < joinedAt ? { pose: "handOver", expr: "happy" } : { pose: "hide", opacity: 1 - ease(t, joinedAt, joinedAt + 8) },
    };
  },
};

const pouch: Scene = {
  id: "pouch", dur: 240, bg: "#FBF0DC", floor: C.oat,
  caps: [{ at: [8, 140], lines: ["Hand it to Hush.", "Copy text, click Hush, pick Simpler, Shorter or Bullets"] },
         { at: [150, 232], lines: ["It rewrites on your Mac.", "With Apple Intelligence"] }],
  draw: (t, k) => {
    const winW = Math.min(520 * k.u, k.W / 2 - 190 * k.u), winH = 300 * k.u, winY = k.floor - winH - 40 * k.u;
    const before = "Pursuant to our previous correspondence, the remittance for invoice 4471 has not been received and is now 14 days past due.";
    const after = "We haven't received payment for invoice 4471. It's now 14 days late.";
    const verbs = ["Simpler", "Shorter", "Bullets"];
    return {
      node: (
        <>
          <Win x={40 * k.u} y={winY} w={winW} h={winH} app="notes" title="Notes" u={k.u}>
            <div style={{ padding: 20 * k.u, fontFamily: MAC, fontSize: 20 * k.u, lineHeight: 1.45, color: "#2A2731" }}>
              <span style={{ background: t > 18 && t < 200 ? "rgba(201,187,236,.6)" : "transparent", borderRadius: 4 * k.u }}>{t < 200 ? before : after}</span>
            </div>
          </Win>
          <div style={{ position: "absolute", left: k.cx + 120 * k.u, top: k.floor - k.hs - 90 * k.u, opacity: t > 24 && t < 70 ? 1 : 0 }}>
            <Key label="⌘" at={34} u={k.u} /><Key label="C" at={36} u={k.u} />
          </div>
          <div style={{ position: "absolute", left: k.cx + 120 * k.u, top: k.floor - k.hs - 90 * k.u, opacity: t > 190 && t < 225 ? 1 : 0 }}>
            <Key label="⌘" at={196} u={k.u} /><Key label="V" at={198} u={k.u} />
          </div>
          {t >= 78 && t < 112 && (
            <div style={{ position: "absolute", left: k.cx - 230 * k.u, top: k.floor - k.hs - 150 * k.u, width: 460 * k.u, padding: 16 * k.u, borderRadius: 16 * k.u,
                          background: C.paper, boxShadow: `0 ${12 * k.u}px ${32 * k.u}px rgba(22,20,27,.18)`, fontFamily: MAC, transform: `scale(${pop(t, 78)})`, boxSizing: "border-box" }}>
              <div style={{ fontSize: 15 * k.u, color: "#6E6878", marginBottom: 10 * k.u }}>What should I do with it?</div>
              <div style={{ display: "flex", gap: 10 * k.u }}>
                {verbs.map((v) => <span key={v} style={{ padding: `${8 * k.u}px ${16 * k.u}px`, borderRadius: 18 * k.u, fontSize: 17 * k.u, fontWeight: 600,
                                                        background: v === "Simpler" && t > 100 ? C.ink : "#EFEBF3", color: v === "Simpler" && t > 100 ? C.cream : "#2A2731" }}>{v}</span>)}
              </div>
            </div>
          )}
          {t >= 182 && (
            <div style={{ position: "absolute", left: k.cx - 190 * k.u, top: k.floor - k.hs - 110 * k.u, width: 380 * k.u, textAlign: "center", padding: `${12 * k.u}px 0`,
                          borderRadius: 16 * k.u, background: "rgba(255,253,247,.95)", fontFamily: MAC, fontWeight: 600, fontSize: 18 * k.u, color: "#2A2731",
                          boxShadow: `0 ${8 * k.u}px ${22 * k.u}px rgba(22,20,27,.14)`, transform: `scale(${pop(t, 182)})` }}>Simpler version ready. Press ⌘V.</div>
          )}
        </>
      ),
      hush: t < 40 ? { pose: "stand" } : t < 112 ? { pose: "stand", expr: "puff" } : t < 182 ? { pose: alt(t, 7, "chewOpen", "chewClosed") }
        : t < 205 ? { pose: "spitOut" } : { pose: "stand", expr: "happy" },
    };
  },
};

const ask: Scene = {
  id: "ask", dur: 240, bg: "#F7F3EC", floor: C.oat,
  caps: [{ at: [8, 130], lines: ["Ask anything. ⌘⇧H", "One quick answer, shaped to the question"] },
         { at: [140, 232], lines: ["Answers go where you work.", "Excel, your terminal, Notion, Cursor"] }],
  draw: (t, k) => {
    const q = "average of column B";
    const typed = q.slice(0, Math.max(0, Math.floor((t - 34) / 2)));
    const boxW = Math.min(560 * k.u, k.W - 120 * k.u);
    const xlW = Math.min(420 * k.u, k.W / 2 - 170 * k.u);
    return {
      node: (
        <>
          <div style={{ position: "absolute", left: k.cx - 110 * k.u, top: k.floor - k.hs - 330 * k.u, opacity: t > 6 && t < 34 ? 1 : 0 }}>
            <Key label="⌘" at={14} u={k.u} /><Key label="⇧" at={16} u={k.u} /><Key label="H" at={18} u={k.u} />
          </div>
          {t >= 26 && t < 100 && (
            <div style={{ position: "absolute", left: k.cx - boxW / 2, top: k.floor - k.hs - 120 * k.u, width: boxW, display: "flex", alignItems: "center", gap: 12 * k.u,
                          padding: `${16 * k.u}px ${20 * k.u}px`, borderRadius: 16 * k.u, background: C.paper, boxSizing: "border-box",
                          boxShadow: `0 ${12 * k.u}px ${32 * k.u}px rgba(22,20,27,.18)`, fontFamily: MAC, fontSize: 22 * k.u, transform: `scale(${pop(t, 26)})` }}>
              <span style={{ color: "#8B8594" }}>⌕</span><span style={{ flex: 1 }}>{typed}<span style={{ opacity: t % 20 < 10 ? 1 : 0 }}>|</span></span>
              <span style={{ fontSize: 15 * k.u, color: C.lilacInk, background: "#F1ECFB", padding: `${5 * k.u}px ${12 * k.u}px`, borderRadius: 14 * k.u }}>⚡ answer here</span>
            </div>
          )}
          {t >= 100 && (
            <div style={{ position: "absolute", left: k.cx - boxW / 2, top: k.floor - k.hs - 230 * k.u, width: boxW, padding: 20 * k.u, borderRadius: 16 * k.u, boxSizing: "border-box",
                          background: C.paper, boxShadow: `0 ${12 * k.u}px ${32 * k.u}px rgba(22,20,27,.18)`, fontFamily: MAC, transform: `scale(${pop(t, 100)})`, zIndex: 20 }}>
              <div style={{ fontSize: 14 * k.u, color: "#8B8594" }}>{q}</div>
              <div style={{ fontFamily: "ui-monospace, Menlo, monospace", fontSize: 30 * k.u, fontWeight: 700, margin: `${8 * k.u}px 0 ${14 * k.u}px`, color: "#1D1B22" }}>=AVERAGE(B2:B200)</div>
              <div style={{ display: "flex", gap: 10 * k.u }}>
                <span style={{ display: "inline-flex", alignItems: "center", gap: 8 * k.u, padding: `${7 * k.u}px ${14 * k.u}px`, borderRadius: 16 * k.u, fontSize: 15 * k.u, fontWeight: 600,
                               background: t > 150 && t < 158 ? C.lilacInk : C.ink, color: C.cream }}><Logo app="excel" size={18 * k.u} /> Paste in Excel</span>
                <span style={{ padding: `${7 * k.u}px ${14 * k.u}px`, borderRadius: 16 * k.u, fontSize: 15 * k.u, fontWeight: 600, background: "#EFEBF3" }}>Copy</span>
              </div>
            </div>
          )}
          {t >= 160 && (
            <Win x={k.W - xlW - 40 * k.u} y={k.floor - 300 * k.u} w={xlW} h={260 * k.u} app="excel" title="Sales.xlsx" u={k.u}
                 style={{ opacity: pop(t, 160), transform: `translateY(${(1 - pop(t, 160)) * 40 * k.u}px)` }}>
              <div style={{ fontFamily: MAC, fontSize: 16 * k.u }}>
                {["Q1", "Q2", "Q3", "Avg"].map((r, i) => (
                  <div key={r} style={{ display: "flex", borderBottom: `${k.u}px solid #E7E4EC` }}>
                    <span style={{ width: 70 * k.u, padding: 8 * k.u, color: "#8B8594" }}>{r}</span>
                    <span style={{ flex: 1, padding: 8 * k.u, background: i === 3 ? "#E3F2E8" : undefined, fontWeight: i === 3 ? 700 : 400 }}>
                      {i === 3 ? (t > 175 ? "1,284" : "=AVERAGE(B2:B200)") : ["1,140", "1,302", "1,410"][i]}
                    </span>
                  </div>
                ))}
              </div>
            </Win>
          )}
        </>
      ),
      hush: t < 26 ? { pose: "stand" } : t < 82 ? { pose: "listen" } : t < 100 ? { pose: "think", expr: "thinking" } : t < 160 ? { pose: "handOver", expr: "happy" } : { pose: "stand", expr: "happy" },
    };
  },
};

const focus: Scene = {
  id: "focus", dur: 210, bg: "#E6EEF8", floor: C.oat,
  caps: [{ at: [8, 130], lines: ["It stays out of your way.", "Ducks while you type, gone during calls"] },
         { at: [138, 204], lines: ["Need quiet? Pause it.", "15 minutes, an hour or until tomorrow"] }],
  draw: (t, k) => {
    const keys = ["H", "E", "L", "L", "O", "W", "O", "R", "L", "D"];
    const scale = k.hs / 146;
    const blind = t < 150 ? null : t < 160 ? "blind-half" : t < 170 ? "blind-low" : "blind-down";
    return {
      node: (
        <>
          {t < 80 && (
            <div style={{ position: "absolute", left: 0, width: k.W, textAlign: "center", top: k.floor - k.hs - 140 * k.u }}>
              {keys.map((c, i) => <Key key={i} label={c} at={8 + i * 6} u={k.u} size={52} />)}
            </div>
          )}
          {t >= 80 && t < 140 && (
            <Win x={k.cx - Math.min(400 * k.u, k.W / 2 - 40 * k.u)} y={k.floor - 320 * k.u} w={Math.min(800 * k.u, k.W - 80 * k.u)} h={270 * k.u} app="facetime" title="FaceTime" u={k.u} dark
                 style={{ opacity: pop(t, 80) * (1 - ease(t, 130, 140)) }}>
              <div style={{ display: "flex", gap: 14 * k.u, padding: 16 * k.u }}>
                {["#F4B9B3", "#A7CBEE"].map((c, i) => (
                  <div key={i} style={{ flex: 1, height: 190 * k.u, borderRadius: 10 * k.u, background: "#2E2B36", display: "flex", alignItems: "center", justifyContent: "center" }}>
                    <div style={{ width: 70 * k.u, height: 70 * k.u, borderRadius: 35 * k.u, background: c }} />
                  </div>
                ))}
              </div>
            </Win>
          )}
          {blind && <Edge name={blind} x={k.cx} y={k.floor} scale={scale} label={blind === "blind-down" ? "Do not disturb" : undefined} style={{ zIndex: 300 }} />}
        </>
      ),
      hush: t < 80 ? { pose: "peek", dy: 40 * k.u } : t < 92 ? { pose: "dive", expr: "squint" } : t < 140 ? { pose: "hide", opacity: 0 }
        : t < 150 ? { pose: "peek" } : t < 170 ? { pose: t < 160 ? "pullBlind" : "hangSign" } : { pose: "hide", opacity: 0 },
    };
  },
};

/** The pointer: an arrow, a closed hand while dragging, an open hand for a pat. */
const Pointer: React.FC<{ x: number; y: number; mode: "arrow" | "grab" | "pat"; u: number }> = ({ x, y, mode, u }) => mode === "arrow" ? (
  <svg width={34 * u} height={48 * u} viewBox="0 0 17 24" style={{ position: "absolute", left: x, top: y, zIndex: 400, overflow: "visible" }}>
    <path d="M1 1 L1 19 L5.5 14.8 L8.6 22 L11.6 20.7 L8.6 13.6 L14.6 13.6 Z" fill="#111" stroke="#fff" strokeWidth={1.4} strokeLinejoin="round" />
  </svg>
) : (
  <div style={{ position: "absolute", left: x - 26 * u, top: y - 30 * u, fontSize: 54 * u, zIndex: 400, filter: "drop-shadow(0 2px 2px rgba(0,0,0,.25))" }}>
    {mode === "grab" ? "✊" : "🖐️"}
  </div>
);

const play: Scene = {
  id: "play", dur: 420, bg: "#F9E8E6", floor: C.oat,
  caps: [{ at: [8, 140], lines: ["Drag it anywhere.", "Drop it on a window and it perches there"] },
         { at: [150, 292], lines: ["Fling it around,", "and it gets dizzy"] },
         { at: [302, 412], lines: ["It plays when you're idle.", "Bobs to your music, leans into a pat. Play never interrupts you"] }],
  draw: (t, k) => {
    const winW = Math.min(500 * k.u, k.W * 0.44), winH = 230 * k.u;
    const winX = k.wide ? k.cx - 120 * k.u - winW : k.cx - winW / 2;
    const winTop = k.floor - (k.tall ? 560 : 390) * k.u;
    const perchDx = winX + winW / 2 - k.cx;
    const head = k.hs * 0.86;                  // from Hush's feet to where the hand holds it
    const c = (v: number) => ({ extrapolateLeft: "clamp" as const, extrapolateRight: "clamp" as const, easing: Easing.inOut(Easing.sin) });
    // Where Hush is (offset from the middle, and its feet), frame by frame.
    let dx = 0, feet = k.floor, pose = "stand", expr = "auto", rot = 0, ptr: "arrow" | "grab" | "pat" | null = null;
    if (t < 14) { expr = "alert"; ptr = "arrow"; }
    else if (t < 22) { pose = "grab"; expr = "surprised"; feet = k.floor - ease(t, 14, 22) * 40 * k.u; ptr = "grab"; }
    else if (t < 70) {
      const q = ease(t, 22, 70);
      dx = q * perchDx; feet = interpolate(q, [0, 0.5, 1], [k.floor - 40 * k.u, winTop - 160 * k.u, winTop - 30 * k.u]);
      pose = "swing"; expr = "squint"; rot = Math.sin(q * Math.PI) * (perchDx < 0 ? 14 : -14); ptr = "grab";
    } else if (t < 76) { dx = perchDx; feet = winTop; pose = "land"; expr = "squint"; }
    else if (t < 140) { dx = perchDx; feet = winTop; pose = alt(t, 14, "perch", "perch2"); expr = "happy"; ptr = t > 128 ? "arrow" : null; }
    else if (t < 156) { dx = perchDx; feet = winTop - ease(t, 146, 156) * 30 * k.u; pose = "grab"; expr = "surprised"; ptr = "grab"; }
    else if (t < 228) {
      // a fast zigzag across the screen
      const q = (t - 156) / 72;
      const span = Math.min(k.W * 0.34, 520 * k.u);
      dx = interpolate(q, [0, 1], [perchDx, 0]) + Math.sin(q * Math.PI * 5) * span * (1 - q * 0.6);
      feet = interpolate(q, [0, 1], [winTop - 30 * k.u, k.floor - 60 * k.u]) - Math.abs(Math.sin(q * Math.PI * 4)) * 160 * k.u;
      pose = "swing"; expr = "squint"; rot = Math.cos(q * Math.PI * 5) * 26; ptr = "grab";
    } else if (t < 238) { feet = k.floor; pose = "land"; expr = "squint"; }
    else if (t < 276) { pose = "dizzy"; expr = "dizzy"; rot = Math.sin((t - 238) / 3) * 8; }
    else if (t < 290) { pose = "shake"; expr = "squint"; }
    else if (t < 310) { pose = "stand"; expr = "apologetic"; }
    else if (t < 362) { pose = "bob"; expr = "happy"; }
    else { pose = "pat"; expr = "blissful"; ptr = "pat"; }
    const px = k.cx + dx, py = feet - head;
    const arrowAt = t < 14 ? { x: interpolate(t, [0, 14], [k.cx + 360 * k.u, px], c(0)), y: interpolate(t, [0, 14], [py - 120 * k.u, py], c(0)) }
      : t >= 128 && t < 140 ? { x: interpolate(t, [128, 140], [px + 220 * k.u, px], c(0)), y: interpolate(t, [128, 140], [py + 80 * k.u, py], c(0)) } : { x: px, y: py };
    return {
      node: (
        <>
          <Win x={winX} y={winTop} w={winW} h={winH} app="safari" title="Safari" u={k.u}>
            <div style={{ padding: 20 * k.u }}>
              {[0.8, 0.6, 0.7, 0.5].map((w, i) => <div key={i} style={{ height: 14 * k.u, width: `${w * 100}%`, borderRadius: 7 * k.u, background: "#EEEBF2", marginBottom: 16 * k.u }} />)}
            </div>
          </Win>
          {t >= 310 && t < 362 && (
            <div style={{ position: "absolute", left: k.cx + 140 * k.u, top: k.floor - k.hs - 30 * k.u, display: "flex", alignItems: "center", gap: 12 * k.u }}>
              <Logo app="music" size={70 * k.u} style={{ transform: `scale(${pop(t, 310)})` }} />
              {[0, 1, 2].map((i) => <span key={i} style={{ fontSize: 44 * k.u, color: C.lilacInk, transform: `translateY(${Math.sin((t + i * 8) / 5) * 10 * k.u}px)` }}>♪</span>)}
            </div>
          )}
          {ptr === "arrow" && <Pointer x={arrowAt.x} y={arrowAt.y} mode="arrow" u={k.u} />}
          {ptr === "grab" && <Pointer x={px} y={py} mode="grab" u={k.u} />}
          {ptr === "pat" && <Pointer x={k.cx + 10 * k.u} y={k.floor - k.hs * 0.95 + Math.sin(t / 3) * 6 * k.u} mode="pat" u={k.u} />}
        </>
      ),
      hush: { pose, expr, dx, floorY: feet, rot, dy: pose === "bob" ? Math.abs(Math.sin(t / 4)) * -10 * k.u : 0 },
    };
  },
};

const mail: Scene = {
  id: "mail", dur: 160, bg: "#FAF2D9", floor: C.oat,
  caps: [{ at: [8, 152], lines: ["Mail is next.", "A digest at natural breaks, never a ping per mail"] }],
  draw: (t, k) => {
    const cardW = Math.min(420 * k.u, k.W - 120 * k.u);
    return {
      node: (
        <>
          {t >= 60 && <Edge name="bin-full" label="12" x={k.cx - 200 * k.u} y={k.floor} scale={(k.hs / 146) * 1.2} style={{ transform: `scale(${pop(t, 60)})`, transformOrigin: "50% 100%" }} />}
          {t >= 95 && (
            <Card title="14 mails while you were busy" line="2 might need you · 12 could wait" app="mail" source="Mail · held back" width={cardW}
                  style={{ left: k.cx - cardW / 2, top: k.floor - k.hs - 190 * k.u, transform: `scale(${pop(t, 95)})` }}>
              <span style={{ display: "inline-block", marginTop: 10 * k.u, padding: `${4 * k.u}px ${10 * k.u}px`, borderRadius: 10 * k.u, background: C.coral,
                             color: C.ink, fontFamily: BODY, fontWeight: 800, fontSize: 12 * k.u, letterSpacing: ".08em" }}>COMING SOON</span>
            </Card>
          )}
        </>
      ),
      hush: t < 40 ? { pose: "stand", carry: "satchel" } : t < 70 ? { pose: "pullOut" } : t < 100 ? { pose: "toss" } : { pose: "hold", expr: "happy" },
    };
  },
};

const evening: Scene = {
  id: "evening", dur: 210, bg: "#2B2540", floor: "#463C63", light: true,
  caps: [{ at: [8, 110], lines: ["At the end of the day,", "it tells you what it spared you"] },
         { at: [118, 204], lines: ["You got 4 things from me today.", "I held back 63."] }],
  draw: (t, k) => {
    const cardW = Math.min(380 * k.u, k.W - 120 * k.u);
    return {
      node: (
        <>
          {[...Array(18)].map((_, i) => (
            <div key={i} style={{ position: "absolute", left: random(`sx${i}`) * k.W, top: random(`sy${i}`) * (k.floor - k.hs - 80 * k.u), width: 4 * k.u, height: 4 * k.u,
                                  borderRadius: 2 * k.u, background: C.cream, opacity: 0.3 + 0.5 * Math.abs(Math.sin((t + i * 13) / 17)) }} />
          ))}
          {t >= 30 && (
            <div style={{ position: "absolute", left: k.cx - cardW / 2, top: k.floor - k.hs - 190 * k.u, width: cardW, padding: 18 * k.u, borderRadius: 16 * k.u,
                          background: C.paper, fontFamily: MAC, boxSizing: "border-box", transform: `scale(${pop(t, 30)})`, boxShadow: `0 ${12 * k.u}px ${32 * k.u}px rgba(0,0,0,.35)` }}>
              <div style={{ fontSize: 14 * k.u, color: "#8B8594" }}>☾ Tonight</div>
              <div style={{ display: "flex", alignItems: "baseline", gap: 10 * k.u, margin: `${8 * k.u}px 0` }}>
                <span style={{ fontSize: 40 * k.u, fontWeight: 700 }}>4</span><span style={{ fontSize: 15 * k.u, color: "#6E6878" }}>shown</span>
                <span style={{ fontSize: 40 * k.u, fontWeight: 700, color: C.lilacInk, marginLeft: 14 * k.u }}>63</span><span style={{ fontSize: 15 * k.u, color: "#6E6878" }}>held back</span>
              </div>
              <div style={{ fontSize: 14 * k.u, color: "#6E6878" }}>Nothing from your VIPs waited.</div>
            </div>
          )}
        </>
      ),
      hush: t < 50 ? { pose: "yawn", expr: "yawn", head: "nightcap" } : t < 130 ? { pose: "stand", expr: "sleepy", head: "nightcap" } : { pose: "doze", expr: "sleepy", head: "nightcap" },
    };
  },
};

const SCENES = [home, agents, meeting, pouch, ask, focus, play, mail, evening];
const DRONE = 200, TRANS = 30, OUTRO = 210;
const starts = SCENES.reduce<number[]>((acc, s, i) => { acc.push(i === 0 ? DRONE : acc[i - 1] + SCENES[i - 1].dur + TRANS); return acc; }, []);
const END_SCENES = starts[starts.length - 1] + SCENES[SCENES.length - 1].dur;
export const DAY_FRAMES = END_SCENES + OUTRO;

// ---------- the drone shot: a field of Hushes, each dressed differently ----------

const PAL = ["oat", "mint", "lilac", "sky", "rose", "peach", "matcha", "butter", "berry"];
const HEADS = ["cap", "beanie", "bucket", "headphones", "crown", "frogHat", "bunny", "beret", "wizard", "chef", "straw", "propellerCap", "partyHat", "flowerCrown", "nightcap", "hardHat"];
const FACES = ["glasses", "shades", "pixelShades", "starGlasses", "heartGlasses", "monocle"];
const NECKS = ["scarf", "bandana", "bowtie", "chain", "tie", "cape", "lei"];
const CARRY = ["coffee", "books", "plant", "laptop", "balloon", "lantern"];
const pickOf = <T,>(arr: T[], seed: string) => arr[Math.floor(random(seed) * arr.length)];

const Crowd: React.FC<{ k: K; p: number; waving: boolean; t: number }> = ({ k, p, waving, t }) => {
  // A drone's view of a field of Hushes, drawn in 2D: far rows smaller and higher, near rows bigger and lower. p: 0 is
  // high above and wide; 1 is down at the hero's height (the plain lilac Hush in the middle of the nearest row), at the
  // size it has in the scenes, with everyone else gone.
  const rows = 6, heroR = rows - 1;
  const horizon = k.H * 0.2;
  const items: React.ReactNode[] = [];
  for (let r = 0; r < rows; r++) {
    const depth = r / (rows - 1);                       // 0 far .. 1 near
    const size = (60 + 120 * depth * depth) * k.u;
    const y = horizon + (k.floor - horizon) * (0.18 + 0.82 * Math.pow(depth, 1.4));
    const spacing = size * 1.35;
    const cols = Math.ceil(k.W / spacing) + 3;
    for (let c = -Math.floor(cols / 2); c <= Math.floor(cols / 2); c++) {
      const i = r * 100 + c + 50, hero = r === heroR && c === 0;
      // Rows alternate by half a step, except the hero's own, so it stands evenly between its neighbours.
      const x = k.cx + c * spacing + ((r - heroR) % 2 ? spacing / 2 : 0);
      const look: Look = hero ? { palette: "lilac", shape: "blob" } : {
        shape: pickOf(["blob", "bean", "square"], `b${i}`), palette: pickOf(PAL, `p${i}`),
        topper: random(`tp${i}`) < 0.6 ? "leaf" : pickOf(["antenna", "ears", "none"], `tq${i}`),
        head: random(`h${i}`) < 0.75 ? pickOf(HEADS, `hh${i}`) : undefined, face: random(`f${i}`) < 0.3 ? pickOf(FACES, `ff${i}`) : undefined,
        neck: random(`n${i}`) < 0.4 ? pickOf(NECKS, `nn${i}`) : undefined, carry: random(`c${i}`) < 0.3 ? pickOf(CARRY, `cc${i}`) : undefined,
      };
      const phase = Math.floor((t + i * 7) / 16) % 4;
      const pose = hero && p > 0.6 ? "stand" : waving ? (phase % 2 ? "wave" : "cheer") : ["stand", "wave", "hop", "stand"][(phase + i) % 4];
      const bob = Math.abs(Math.sin((t + i * 11) / 9)) * -6 * k.u * (0.4 + depth);
      items.push(<Hush key={i} x={x} floor={y} size={size} pose={pose} expr={waving || pose !== "stand" ? "happy" : "auto"} {...look}
                       style={{ transform: `translateY(${bob}px)`, opacity: hero ? 1 : 1 - ease(p, 0.5, 0.9), zIndex: r }} />);
    }
  }
  // The camera: wide and drifting while high, then down onto the hero, which ends at the scenes' size and spot.
  const heroSize = 180 * k.u;
  const zoom = interpolate(p, [0, 1], [1, k.hs / heroSize], { easing: Easing.inOut(Easing.cubic) });
  const drift = (1 - p) * Math.sin(t / 40) * 30 * k.u;
  const tilt = (1 - p) * -3;
  return (
    <AbsoluteFill>
      <AbsoluteFill style={{ background: `linear-gradient(180deg, #B9A8E4 0%, ${C.lilac} ${(horizon / k.H) * 100}%, #DCD2F4 100%)` }} />
      <AbsoluteFill style={{ transformOrigin: `${k.cx}px ${k.floor}px`, transform: `translateX(${drift}px) scale(${zoom}) rotate(${tilt}deg)` }}>
        {items}
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

// ---------- the film ----------

export const Day: React.FC = () => {
  const frame = useCurrentFrame();
  const { width: W, height: H } = useVideoConfig();
  const u = Math.min(W, H) / 1080;
  const tall = H > W * 1.2, wide = W > H * 1.2;
  const k: K = { W, H, u, tall, wide, floor: H - (tall ? 420 : 130) * u, cx: W / 2, hs: (tall ? 380 : 280) * u, px: 0 };
  const capTop = (tall ? 170 : 58) * u;

  // Where we are: the drone, a scene, a walk between two, or the drone out.
  let i = 0;
  for (let s = 0; s < SCENES.length; s++) if (frame >= starts[s]) i = s;
  const t = frame - starts[i];
  const walking = t >= SCENES[i].dur && i < SCENES.length - 1;
  const w = walking ? ease(t - SCENES[i].dur, 0, TRANS) : 0;
  const camX = (i + w) * W;

  const scene = SCENES[i].draw(Math.min(t, SCENES[i].dur), k);
  const hushState: HushState = frame < DRONE ? { pose: "peek" } : walking ? { pose: `walk${1 + Math.floor(frame / 4) % 4}` } : scene.hush;
  const inDrone = frame < DRONE + 12, inOutro = frame >= END_SCENES - 6;

  // Background: one long gradient through every scene's colour, so the walk between them is a blend.
  // The colour follows the camera: solid while a scene plays, blending into the next only while Hush walks there.
  const next = SCENES[Math.min(i + 1, SCENES.length - 1)];
  const bgNow = interpolateColors(w, [0, 1], [SCENES[i].bg, next.bg]);
  const floorNow = interpolateColors(w, [0, 1], [SCENES[i].floor, next.floor]);
  const light = SCENES[i].light && !walking;

  const droneP = ease(frame, 120, DRONE);
  const outroP = 1 - ease(frame, END_SCENES, END_SCENES + 70);
  const worldIn = interpolate(frame, [DRONE - 10, DRONE + 6], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const worldOut = 1 - interpolate(frame, [END_SCENES, END_SCENES + 16], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ background: C.lilac, overflow: "hidden", fontFamily: BODY }}>
      <Fonts />
      {/* the desktop Hush walks along */}
      <AbsoluteFill style={{ opacity: worldIn * worldOut }}>
        <div style={{ position: "absolute", left: -camX, top: 0, width: W * SCENES.length, height: H, background: bgNow }}>
          <div style={{ position: "absolute", left: 0, top: k.floor, width: "100%", height: H - k.floor, background: floorNow }} />
          {SCENES.map((s, j) => Math.abs(j - (i + w)) < 1.2 && (
            <div key={s.id} style={{ position: "absolute", left: j * W, top: 0, width: W, height: H }}>
              {s.draw(j === i ? Math.min(t, s.dur) : j < i ? s.dur : 0, k).node}
            </div>
          ))}
        </div>
        <Hush x={k.cx + (hushState.dx ?? 0)} floor={hushState.floorY ?? k.floor} size={k.hs} {...hushState}
              style={{ opacity: hushState.opacity ?? 1, transform: `translateY(${hushState.dy ?? 0}px) rotate(${hushState.rot ?? 0}deg)`, zIndex: 200 }} />
        {!walking && SCENES[i].caps.map((c, j) => (
          <Caption key={`${i}-${j}`} lines={c.lines} from={starts[i] + c.at[0]} to={starts[i] + c.at[1]} u={u} top={capTop} light={light} />
        ))}
      </AbsoluteFill>

      {/* the drone shot in, and back out */}
      {inDrone && (
        <AbsoluteFill style={{ opacity: 1 - interpolate(frame, [DRONE - 4, DRONE + 12], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }) }}>
          <Crowd k={k} p={droneP} waving={false} t={frame} />
          <Caption lines={["One for everyone.", "Three bodies, nine colours, 46 pieces to wear. All free."]} from={14} to={118} u={u} top={capTop} />
        </AbsoluteFill>
      )}
      {inOutro && (
        <AbsoluteFill style={{ opacity: interpolate(frame, [END_SCENES - 6, END_SCENES + 10], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }) }}>
          <Crowd k={k} p={outroP} waving t={frame} />
          {frame >= END_SCENES + 60 && (
            <div style={{ position: "absolute", top: (tall ? 230 : 70) * u, left: W / 2 - Math.min(1100 * u, W - 60 * u) / 2, width: Math.min(1100 * u, W - 60 * u),
                          padding: `${36 * u}px ${30 * u}px`, boxSizing: "border-box", borderRadius: 36 * u, background: "rgba(232,226,248,.88)",
                          boxShadow: `0 ${20 * u}px ${60 * u}px rgba(45,42,53,.18)`, textAlign: "center", opacity: ease(frame, END_SCENES + 60, END_SCENES + 80),
                          transform: `scale(${0.92 + 0.08 * ease(frame, END_SCENES + 60, END_SCENES + 80)})` }}>
              <div style={{ fontFamily: DISPLAY, fontWeight: 800, fontSize: 200 * u, letterSpacing: "-0.06em", lineHeight: 0.8, color: C.ink }}>hush</div>
              <div style={{ fontFamily: DISPLAY, fontWeight: 700, fontSize: 46 * u, marginTop: 22 * u, color: C.ink, letterSpacing: "-0.02em" }}>The companion that knows when not to.</div>
              <div style={{ fontFamily: BODY, fontWeight: 600, fontSize: 24 * u, marginTop: 14 * u, color: C.ink, opacity: 0.7 }}>Free and open source · for your Mac</div>
              <div style={{ fontFamily: BODY, fontSize: 15 * u, marginTop: 10 * u, color: C.ink, opacity: 0.55 }}>
                Independent project. Not affiliated with Anthropic, OpenAI, Apple, Microsoft or Zoom. App icons belong to their owners.
              </div>
            </div>
          )}
        </AbsoluteFill>
      )}
    </AbsoluteFill>
  );
};
