import React from "react";
// The app's own character pack and composer, exactly as the website draws Hush (scripts/build-site.py).
import "../../../site/hush-data.js";
import "../../../site/hush.js";

declare global {
  interface Window { Hush: { svg: (o: Record<string, unknown>) => string } }
}

export type Look = {
  pose?: string; expr?: string; palette?: string; shape?: string; topper?: string;
  head?: string; face?: string; neck?: string; carry?: string; buddy?: string; lookx?: number; looky?: string | number;
};

/**
 * Hush standing on a floor line. `x`, `floor`: where its feet go (px from the left and from the top); `size`: its
 * height in px. Everything else is the look and pose (any pose or expression from the pack).
 */
export const Hush: React.FC<Look & { x: number; floor: number; size: number; style?: React.CSSProperties }> = ({
  x, floor, size, style, ...look
}) => {
  const markup = window.Hush.svg({ palette: "lilac", ...look });
  const w = (size * 160) / 146;
  // Standing poses touch the floor at y = 138 of the 146-unit canvas; edge poses (peek, hide, the blind) at 112;
  // perches sit on the window's top edge at 116.
  const edge = /^(peek|hide|dive|pullBlind|hangSign|tumble|tumbleGone)$/.test(look.pose ?? "");
  const perch = /^(perch|perch2|perchDoze)$/.test(look.pose ?? "");
  const top = floor - (size * (edge ? 112 : perch ? 116 : 138)) / 146;
  return (
    <div style={{ position: "absolute", left: x - w / 2, top, width: w, height: size, lineHeight: 0, transformOrigin: "50% 95%", ...style }}
         dangerouslySetInnerHTML={{ __html: markup.replace("<svg", '<svg width="100%" height="100%" style="overflow:visible"') }} />
  );
};
