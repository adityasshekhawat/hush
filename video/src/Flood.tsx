import React from "react";
import { AbsoluteFill, Easing, interpolate, random, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { BODY, C, DISPLAY, Fonts } from "./lib/brand";
import { Card } from "./lib/Card";
import { Hush } from "./lib/Hush";

// "The flood" (15 s): your agents talk a lot; Hush listens to all of it, holds back what can wait, and only taps
// the glass for the one that needs you. Every card is the kind of update Hush really handles today (Claude Code and
// Codex hooks); the count is an example, like the README's.

const UPDATES: [string, string][] = [
  ["Claude finished in web", "Ran for 12s"], ["Codex finished in api", "Tests passed"], ["Claude is working in docs", "Editing 3 files"],
  ["Claude finished in site", "Ran for 40s"], ["Codex finished in cli", "Build succeeded"], ["Claude finished in web", "Ran for 8s"],
  ["Claude is working in api", "Running npm test"], ["Codex finished in docs", "Ran for 1m"], ["Claude finished in infra", "Ran for 20s"],
  ["Claude finished in app", "Ran for 15s"], ["Codex is working in web", "Reading the repo"], ["Claude finished in api", "Ran for 31s"],
];
const N = 26;
const RAIN_FROM = 34, RAIN_EVERY = 4;
const SWAT_FROM = 214, SWAT_EVERY = 2;
const NEEDS_FROM = 292;
const END_FROM = 382;

const Title: React.FC<{ text: string; from: number; to: number; size: number; y: number; color?: string }> = ({ text, from, to, size, y, color = C.ink }) => {
  const frame = useCurrentFrame();
  const { fps, width } = useVideoConfig();
  if (frame < from || frame > to + 8) return null;
  const words = text.split(" ");
  const out = interpolate(frame, [to, to + 8], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  return (
    <div style={{ position: "absolute", top: y, left: 0, width, textAlign: "center", fontFamily: DISPLAY, fontWeight: 800,
                  fontSize: size, letterSpacing: "-0.04em", lineHeight: 0.95, color, opacity: out, padding: `0 ${size * 0.6}px`, boxSizing: "border-box" }}>
      {words.map((w, i) => {
        const p = spring({ frame: frame - from - i * 3, fps, config: { damping: 11, stiffness: 170 } });
        return (
          <span key={i} style={{ display: "inline-block", marginRight: size * 0.24, transform: `translateY(${(1 - p) * size * 0.6}px) scale(${0.7 + 0.3 * p})`, opacity: p }}>{w}</span>
        );
      })}
    </div>
  );
};

export const Flood: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps, width: W, height: H } = useVideoConfig();
  const u = Math.min(W, H) / 1080;
  const tall = H > W * 1.2, wide = W > H * 1.2;
  const floor = H - (tall ? 260 : 120) * u;
  const hushSize = 340 * u;
  const cx = W / 2;
  const cardW = 420 * u;
  // Cards land below the titles and above Hush.
  const zoneTop = (tall ? 560 : wide ? 250 : 330) * u;

  // Hush: rises in, looks up at the rain, gets busy swatting, then holds up the one that matters.
  const rise = spring({ frame: frame - 4, fps, config: { damping: 12 } });
  const swatting = frame >= SWAT_FROM && frame < NEEDS_FROM;
  const swatBeat = Math.floor((frame - SWAT_FROM) / 6) % 2;
  let pose = "stand", expr = "auto";
  if (frame >= RAIN_FROM && frame < SWAT_FROM) { pose = frame < 110 ? "notice" : "stand"; expr = frame < 110 ? "surprised" : "squint"; }
  if (swatting) { pose = swatBeat ? "crouch" : "cheer"; expr = "happy"; }
  if (frame >= NEEDS_FROM && frame < NEEDS_FROM + 30) { pose = "raiseHand"; expr = "auto"; }
  if (frame >= NEEDS_FROM + 30 && frame < END_FROM) { pose = "holdCardBoth"; expr = "worried"; }
  if (frame >= END_FROM) { pose = "wave"; expr = "happy"; }
  const lookx = frame >= RAIN_FROM && frame < SWAT_FROM ? Math.sin(frame / 9) * 3 : 0;
  const looky = frame >= RAIN_FROM && frame < SWAT_FROM ? -3 : 0;
  const squash = swatting ? 1 + 0.06 * Math.sin((frame - SWAT_FROM) * 1.05) : 1;

  // Camera: a small shake while swatting, a punch-in on the catch, back out for the end.
  const punch = interpolate(frame, [NEEDS_FROM + 20, NEEDS_FROM + 40, END_FROM - 6, END_FROM + 6], [1, 1.16, 1.16, 1],
                            { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.inOut(Easing.cubic) });
  const shake = swatting ? (random(`s${frame}`) - 0.5) * 8 * u : 0;

  // Held-back counter: ticks up as cards fly away.
  const gone = swatting || frame >= NEEDS_FROM ? Math.min(N, Math.floor((frame - SWAT_FROM) / SWAT_EVERY) + 1) : 0;
  const held = Math.round((gone / N) * 63);
  const counterIn = spring({ frame: frame - SWAT_FROM, fps, config: { damping: 10 } });
  const bump = gone > 0 && gone < N ? 1 + 0.08 * Math.max(0, 1 - ((frame - SWAT_FROM) % SWAT_EVERY)) : 1;

  const bg = frame >= END_FROM ? C.lilac : C.cream;
  const endIn = spring({ frame: frame - END_FROM, fps, config: { damping: 14 } });

  return (
    <AbsoluteFill style={{ background: bg, overflow: "hidden", fontFamily: BODY }}>
      <Fonts />
      <AbsoluteFill style={{ transform: `translate(${shake}px, ${shake * 0.6}px) scale(${punch})`, transformOrigin: `${cx}px ${floor}px` }}>
        {/* the floor Hush stands on */}
        <div style={{ position: "absolute", left: 0, top: floor, width: W, height: H - floor, background: frame >= END_FROM ? "#B9A8E4" : C.oat }} />

        {/* the rain of agent updates */}
        {frame < NEEDS_FROM + 4 && Array.from({ length: N }, (_, i) => {
          const start = RAIN_FROM + i * RAIN_EVERY;
          if (frame < start) return null;
          const [title, line] = UPDATES[i % UPDATES.length];
          const lx = (random(`x${i}`) * (W - cardW - 80 * u)) + 40 * u;
          const ly = zoneTop + random(`y${i}`) * Math.max(0, floor - hushSize * 0.95 - zoneTop - 90 * u);
          const rot = (random(`r${i}`) - 0.5) * 18;
          const fall = spring({ frame: frame - start, fps, config: { damping: 9, stiffness: 120, mass: 0.7 } });
          let x = lx, y = interpolate(fall, [0, 1], [-260 * u, ly]), r = rot * fall, o = 1;
          const flyAt = SWAT_FROM + i * SWAT_EVERY;
          if (frame >= flyAt) {
            const t = (frame - flyAt) / 14;
            const dir = random(`d${i}`) < 0.5 ? -1 : 1;
            x = lx + dir * t * t * W * 0.9;
            y = ly - Math.sin(Math.min(t, 1) * Math.PI) * 120 * u + t * t * 200 * u;
            r = rot + dir * t * 160;
            o = Math.max(0, 1 - t * 0.8);
          }
          return <Card key={i} title={title} line={line} width={cardW}
                       style={{ left: x, top: y, transform: `rotate(${r}deg)`, opacity: o, zIndex: i }} />;
        })}

        {/* the one that needs you */}
        {frame >= NEEDS_FROM && frame < END_FROM && (() => {
          const p = spring({ frame: frame - NEEDS_FROM, fps, config: { damping: 12, stiffness: 90 } });
          const x = cx - (cardW * 1.25) / 2, y = interpolate(p, [0, 1], [-300 * u, floor - hushSize - 230 * u]);
          return <Card title="Claude needs you in api" line="Wants to run rm -rf build · look carefully" tone="careful" width={cardW * 1.25}
                       style={{ left: x, top: y, transform: `rotate(${(1 - p) * -8}deg)`, zIndex: 100 }} />;
        })()}

        <Hush x={cx} floor={floor} size={hushSize} pose={pose} expr={expr} lookx={lookx} looky={looky}
              style={{ transform: `translateY(${(1 - rise) * hushSize}px) scale(${squash}, ${2 - squash})`, zIndex: 200 }} />

      </AbsoluteFill>

      {/* titles and the count stay put while the camera moves */}
        <Title text="Your agents talk a lot." from={6} to={112} size={(wide ? 92 : 104) * u} y={(tall ? 170 : 70) * u} />
        <Title text="Hush listens to all of it" from={118} to={206} size={(wide ? 92 : 104) * u} y={(tall ? 170 : 70) * u} />
        <Title text="and holds back what can wait." from={212} to={286} size={(wide ? 88 : 96) * u} y={(tall ? 170 : 70) * u} />
        <Title text="It taps the glass for the one that needs you." from={296} to={374} size={(wide ? 74 : 80) * u} y={(tall ? 150 : 56) * u} />

        {/* the held-back count */}
        {frame >= SWAT_FROM && frame < END_FROM && (
          <div style={{ position: "absolute", right: 56 * u, top: floor - hushSize * 1.05 - (tall ? 60 : 0) * u, textAlign: "right",
                        transform: `scale(${counterIn * bump})`, transformOrigin: "100% 50%", zIndex: 150 }}>
            <div style={{ fontFamily: DISPLAY, fontWeight: 800, fontSize: 170 * u, lineHeight: 0.85, color: C.lilacInk, letterSpacing: "-0.05em" }}>{held}</div>
            <div style={{ fontFamily: DISPLAY, fontWeight: 700, fontSize: 40 * u, color: C.lilacInk }}>held back</div>
          </div>
        )}

      {/* end card */}
      {frame >= END_FROM && (
        <div style={{ position: "absolute", top: (tall ? 300 : 110) * u, width: W, textAlign: "center", transform: `scale(${0.85 + 0.15 * endIn})`, opacity: endIn }}>
          <div style={{ fontFamily: DISPLAY, fontWeight: 800, fontSize: 230 * u, letterSpacing: "-0.06em", lineHeight: 0.8, color: C.ink }}>hush</div>
          <div style={{ fontFamily: DISPLAY, fontWeight: 700, fontSize: 52 * u, marginTop: 26 * u, color: C.ink, letterSpacing: "-0.02em" }}>
            The companion that knows when not to.
          </div>
          <div style={{ fontFamily: BODY, fontWeight: 600, fontSize: 28 * u, marginTop: 18 * u, color: C.muted }}>
            Free and open source · for your Mac
          </div>
        </div>
      )}
    </AbsoluteFill>
  );
};
