// renderer/setup.js: a fragment, not a standalone script. Swift (Assets.rendererPage) concatenates
// setup.js, compose.js, life.js and reactions.js inside one closure, so they share state.
// Constants, look state (s) and live interaction state (live).

const D = window.HUSH_DATA;
const NS = "http://www.w3.org/2000/svg";
const INK = "#2D2A35", PAPER = "#FFFDF7";
const post = msg => { try { window.webkit.messageHandlers.hush.postMessage(msg); } catch (e) {} };
// Script errors are invisible inside the overlay; send them to the app's diagnostics log.
window.addEventListener("error", e => post({ type: "error", message: e.message + " @" + e.lineno + ":" + e.colno }));
const el = document.getElementById("hush");
const reduced = matchMedia("(prefers-reduced-motion: reduce)").matches;
const rnd = (a, b) => a + Math.random() * (b - a);
const pick = a => a[Math.floor(Math.random() * a.length)];
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const now = () => performance.now();
const parser = new DOMParser();
const parse = src => parser.parseFromString(src, "image/svg+xml").documentElement;

// look + app state
const s = { body: "blob", palette: "oat", eyes: "round", topper: "leaf", wear: [],
            state: "01-peek", variant: "", duck: false, dark: false, height: 104 };
const live = {
  hovered: false, pressed: false, patting: false, lifted: false, swingFast: false, near: false,
  pointer: null, pointerMovedAt: 0, clicks: [], lock: null, gazeOverride: null,
  modes: new Set(), full: false, asking: false, handNap: false, risen: false,
  seq: null, mode: null, modeFrame: 0, perchDoze: false, mood: 0, boxPose: null,
  // Words the app gives the art: card, flag, sign, bin, more (v1 art; the art never bakes text in).
  labels: { sign: "Do not disturb" },
};
