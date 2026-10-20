import React from "react";
import { Img, spring, staticFile, useCurrentFrame, useVideoConfig, interpolate } from "remotion";
import { BODY, C, DISPLAY, MAC } from "./brand";
import { EDGE } from "../generated/edge";

/** A real app's icon, from this Mac (scripts/app-icons.swift). */
export const Logo: React.FC<{ app: string; size: number; style?: React.CSSProperties }> = ({ app, size, style }) => (
  <Img src={staticFile(`logos/${app}.png`)} style={{ width: size, height: size, display: "block", ...style }} />
);

/** A plain Mac window: traffic lights, the app's icon and a title. */
export const Win: React.FC<{ x: number; y: number; w: number; h: number; app?: string; title?: string; u: number;
                             dark?: boolean; children?: React.ReactNode; style?: React.CSSProperties }> = ({ x, y, w, h, app, title, u, dark, children, style }) => (
  <div style={{ position: "absolute", left: x, top: y, width: w, height: h, borderRadius: 14 * u, overflow: "hidden",
                background: dark ? "#1E1C24" : "#FFFFFF", boxShadow: `0 ${18 * u}px ${48 * u}px rgba(22,20,27,.22), 0 0 0 ${u}px rgba(22,20,27,.10)`, ...style }}>
    <div style={{ height: 40 * u, display: "flex", alignItems: "center", gap: 8 * u, padding: `0 ${14 * u}px`,
                  background: dark ? "#2A2731" : "#F2F0F5", borderBottom: `${u}px solid rgba(22,20,27,.08)` }}>
      {["#FF5F57", "#FEBC2E", "#28C840"].map((c) => <span key={c} style={{ width: 12 * u, height: 12 * u, borderRadius: 6 * u, background: c }} />)}
      {app && <Logo app={app} size={22 * u} style={{ marginLeft: 10 * u }} />}
      {title && <span style={{ fontFamily: MAC, fontSize: 15 * u, fontWeight: 600, color: dark ? "#DAD5E3" : "#3A3642" }}>{title}</span>}
    </div>
    <div style={{ position: "relative", width: "100%", height: h - 40 * u }}>{children}</div>
  </div>
);

/** A keycap that presses down at `at`. */
export const Key: React.FC<{ label: string; at: number; u: number; size?: number }> = ({ label, at, u, size = 64 }) => {
  const frame = useCurrentFrame();
  const down = frame >= at && frame < at + 6 ? 1 : 0;
  return (
    <span style={{ display: "inline-flex", alignItems: "center", justifyContent: "center", minWidth: size * u, height: size * u,
                   padding: `0 ${12 * u}px`, marginRight: 10 * u, borderRadius: 12 * u, background: C.paper, color: C.ink,
                   fontFamily: MAC, fontWeight: 600, fontSize: size * 0.42 * u, boxSizing: "border-box",
                   boxShadow: down ? `0 ${2 * u}px 0 #CFC8D8` : `0 ${7 * u}px 0 #CFC8D8, 0 0 0 ${1.5 * u}px #CFC8D8`,
                   transform: `translateY(${down ? 5 * u : 0}px)` }}>{label}</span>
  );
};

/** A two-line caption that springs in word by word: a big line and a quieter one. */
export const Caption: React.FC<{ lines: [string, string?]; from: number; to: number; u: number; top: number; light?: boolean }> = ({ lines, from, to, u, top, light }) => {
  const frame = useCurrentFrame();
  const { fps, width } = useVideoConfig();
  if (frame < from || frame > to + 10) return null;
  const out = interpolate(frame, [to, to + 10], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const ink = light ? C.cream : C.ink;
  const big = Math.min(96 * u, width / 13);
  return (
    <div style={{ position: "absolute", top, left: 0, width, textAlign: "center", opacity: out, padding: `0 ${60 * u}px`, boxSizing: "border-box", zIndex: 500 }}>
      <div style={{ fontFamily: DISPLAY, fontWeight: 800, fontSize: big, letterSpacing: "-0.045em", lineHeight: 0.95, color: ink }}>
        {lines[0].split(" ").map((w, i) => {
          const p = spring({ frame: frame - from - i * 2.5, fps, config: { damping: 11, stiffness: 170 } });
          return <span key={i} style={{ display: "inline-block", marginRight: big * 0.24, opacity: p,
                                        transform: `translateY(${(1 - p) * big * 0.5}px) scale(${0.75 + 0.25 * p})` }}>{w}</span>;
        })}
      </div>
      {lines[1] && (() => {
        const p = spring({ frame: frame - from - 12, fps, config: { damping: 14 } });
        return <div style={{ fontFamily: BODY, fontWeight: 600, fontSize: big * 0.36, marginTop: 14 * u, color: ink, opacity: p * 0.75,
                             transform: `translateY(${(1 - p) * 20 * u}px)` }}>{lines[1]}</div>;
      })()}
    </div>
  );
};

/** An edge piece (flag, door, blind, bin) standing with its anchor at (x, y), words drawn by us. */
export const Edge: React.FC<{ name: string; x: number; y: number; scale: number; label?: string; style?: React.CSSProperties }> = ({ name, x, y, scale, label, style }) => {
  const src = EDGE[name];
  if (!src) return null;
  const vb = (src.match(/viewBox="([^"]+)"/)?.[1] ?? "0 0 100 100").split(/\s+/).map(Number);
  const [vx, vy, vw, vh] = vb;
  const spots: Record<string, [number, number, number, number, number]> = {
    flag: [5, -67, 38, 12, 8], "flag-bundle": [11, -14, 22, 10, 7], bin: [-8, -21, 16, 9, 7], "blind-down": [-10, -32, 38, 22, 7.5],
  };
  const key = name.startsWith("flag-") && name !== "flag-bundle" ? "flag" : name.startsWith("bin") ? "bin" : name;
  const spot = spots[key];
  const inner = src.replace(/<\?xml[^>]*>/, "").replace("<svg", `<svg width="${vw * scale}" height="${vh * scale}" style="overflow:visible;display:block"`);
  return (
    <div style={{ position: "absolute", left: x + vx * scale, top: y + vy * scale, width: vw * scale, height: vh * scale, ...style }}>
      <div dangerouslySetInnerHTML={{ __html: inner }} />
      {label && spot && (
        <div style={{ position: "absolute", left: (spot[0] - vx) * scale, top: (spot[1] - vy) * scale, width: spot[2] * scale, height: spot[3] * scale,
                      display: "flex", alignItems: "center", justifyContent: "center", textAlign: "center", fontFamily: MAC, fontWeight: 700,
                      fontSize: spot[4] * scale, lineHeight: 1.05, color: C.outline }}>{label}</div>
      )}
    </div>
  );
};
