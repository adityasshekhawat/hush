import React from "react";
import { C, MAC } from "./brand";

/** A Hush-style agent update (the app's envelope card): who, where, and one line. */
export const Card: React.FC<{ title: string; line: string; tone?: "plain" | "careful"; width: number; style?: React.CSSProperties }> = ({
  title, line, tone = "plain", width, style,
}) => {
  const s = width / 320;
  const careful = tone === "careful";
  return (
    <div style={{
      position: "absolute", width, padding: `${12 * s}px ${14 * s}px`, borderRadius: 14 * s, background: C.paper,
      boxShadow: careful ? `0 0 0 ${3 * s}px ${C.coral}, 0 ${14 * s}px ${34 * s}px rgba(22,20,27,.25)` : `0 ${8 * s}px ${22 * s}px rgba(22,20,27,.16), 0 0 0 ${0.5 * s}px rgba(22,20,27,.12)`,
      fontFamily: MAC, color: "#1D1B22", ...style,
    }}>
      <div style={{ display: "flex", alignItems: "center", gap: 7 * s, fontSize: 11 * s, color: "#6E6878", marginBottom: 4 * s }}>
        <span style={{ width: 16 * s, height: 16 * s, borderRadius: 4 * s, background: careful ? C.coral : C.ink, color: C.cream,
                       display: "inline-flex", alignItems: "center", justifyContent: "center", fontSize: 9 * s, fontWeight: 700 }}>{careful ? "!" : "›_"}</span>
        {title.startsWith("Codex") ? "Codex" : "Claude Code"} · just now
      </div>
      <div style={{ fontSize: 15 * s, fontWeight: 600, lineHeight: 1.25 }}>{title}</div>
      <div style={{ fontSize: 12.5 * s, color: "#5D5866", marginTop: 3 * s, lineHeight: 1.3 }}>{line}</div>
    </div>
  );
};
