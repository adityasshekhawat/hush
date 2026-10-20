import React, { useEffect, useState } from "react";
import { continueRender, delayRender, staticFile } from "remotion";

// The website's palette and type (site/style.css), so the videos and the page feel like one thing.
export const C = {
  oat: "#F4D9A6", coral: "#E8876A", lilac: "#C9BBEC", mint: "#C6E8D2", ink: "#16141B", cream: "#F7F3EC",
  paper: "#FFFDF7", outline: "#2D2A35", coralText: "#A64B30", muted: "#4F4858", lilacInk: "#5B47A8",
};
export const DISPLAY = '"Bricolage Grotesque", Figtree, system-ui, sans-serif';
export const BODY = 'Figtree, system-ui, -apple-system, sans-serif';
export const MAC = '-apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif';

const FONTS: [string, string, string][] = [
  ["Bricolage Grotesque", "fonts/bricolage-grotesque-latin.woff2", "600 800"],
  ["Figtree", "fonts/figtree-latin.woff2", "400 700"],
];

/** Holds the render until the brand fonts are in, so no frame is drawn in a fallback face. */
export const Fonts: React.FC = () => {
  const [handle] = useState(() => delayRender("brand fonts"));
  useEffect(() => {
    Promise.all(FONTS.map(([family, file, weight]) => {
      const f = new FontFace(family, `url(${staticFile(file)}) format("woff2")`, { weight });
      document.fonts.add(f);
      return f.load();
    })).then(() => continueRender(handle), () => continueRender(handle));
  }, [handle]);
  return null;
};
