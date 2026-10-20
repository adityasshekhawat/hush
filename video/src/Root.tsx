import React from "react";
import { Composition } from "remotion";
import { Flood } from "./Flood";

// Every video in three shapes: 16:9 (website, YouTube, X), 1:1 (feeds) and 9:16 (Reels, TikTok, Shorts).
const SHAPES = [["16x9", 1920, 1080], ["1x1", 1080, 1080], ["9x16", 1080, 1920]] as const;
const VIDEOS = [{ id: "Flood", component: Flood, seconds: 15 }];

export const Root: React.FC = () => (
  <>
    {VIDEOS.flatMap((v) => SHAPES.map(([shape, width, height]) => (
      <Composition key={v.id + shape} id={`${v.id}-${shape}`} component={v.component}
                   durationInFrames={v.seconds * 30} fps={30} width={width} height={height} />
    )))}
  </>
);
