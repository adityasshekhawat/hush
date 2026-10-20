// renderer/life.js: a fragment, not a standalone script. Swift (Assets.rendererPage) concatenates
// setup.js, compose.js, life.js and reactions.js inside one closure, so they share state.
// Overlays (cheeks, zzz), gaze and blinking, motion primitives, the sequence player and idle fidgets.

// ---------- overlays that ride on top of whatever frame is showing ----------
let cheekPop = false;
function applyOverlays() {
  const face = $("pose-root").querySelector("#face");
  const pal = D.palettes[s.palette] || D.palettes.oat;
  // Full cheeks stay on through every frame until the paste.
  let bulge = face && face.querySelector("#cheek-bulge");
  // The puff expression draws its own cheeks; the drawn bulge is only a fallback for faces without them.
  if (live.full && face && !bulge && !face.querySelector("#cheeks-puffed")) {
    bulge = document.createElementNS(NS, "g");
    bulge.id = "cheek-bulge";
    const cheek = x => `<ellipse cx="${x}" cy="10" rx="10" ry="8.5" fill="${pal.body}" stroke="${INK}" stroke-width="2.2"/>` +
                       `<ellipse cx="${x}" cy="11" rx="5.5" ry="3.4" fill="${pal.cheek}" opacity=".75"/>` +
                       `<circle cx="${x - Math.sign(x) * 3}" cy="6.5" r="1.6" fill="#FFFFFF" opacity=".8"/>`;
    bulge.innerHTML = cheek(-23) + cheek(23);
    face.insertBefore(bulge, face.querySelector("#eyes"));
    bulge.style.transformBox = "fill-box"; bulge.style.transformOrigin = "center";
    if (cheekPop && !reduced) bulge.animate([{ transform: "scale(.4)" }, { transform: "scale(1.12)", offset: .7 }, { transform: "scale(1)" }], { duration: 320 });
    cheekPop = false;
  } else if (!live.full && bulge && !bulge.dataset.leaving) bulge.remove();
  const mouth = face && face.querySelector("#mouth");
  if (mouth) { mouth.style.transformBox = "fill-box"; mouth.style.transformOrigin = "center"; mouth.style.transform = live.full && !face.querySelector("#cheeks-puffed") ? "scale(.6)" : ""; }
  if (live.patting || live.full) face?.querySelector("#blush")?.setAttribute("opacity", ".9");
  // zzz while napping under the cursor or tucking in (if the pose doesn't already have them)
  const wantZ = (live.handNap || live.tucked) && !svg.querySelector("#slot-fx-back [id='fx-zzz']:not([opacity='0'])");
  const ov = $("slot-overlay");
  if (wantZ && !ov.querySelector("[id='fx-zzz']")) {
    const z = getRig().querySelector("#fx-zzz").cloneNode(true);
    z.removeAttribute("opacity"); if (s.dark) z.setAttribute("stroke", PAPER);
    ov.appendChild(imp(z));
  } else if (!wantZ) ov.querySelector("[id='fx-zzz']")?.remove();
}

// ---------- eyes: gaze with a little lag, blinking ----------
const gz = { x: 0, y: 0, tx: 0, ty: 0, settle: null };
function eyesEl() { return $("pose-root").querySelector("#eyes-open"); }
function gazeTarget() {
  const e = eyesEl(); if (!e) return;
  let dx, dy, k = 2.2;
  if (live.gazeOverride) { ({ dx, dy } = live.gazeOverride); }
  else if (live.pointer) {
    const r = e.getBoundingClientRect();
    dx = live.pointer.x - (r.left + r.width / 2); dy = live.pointer.y - (r.top + r.height / 2);
    const dist = Math.hypot(dx, dy);
    // Beyond reach the eyes drift back to the middle (and the app stops sending updates).
    k = dist > 420 ? 0 : Math.min(1, dist / 160) * 2.2;
  } else return;
  const d = Math.hypot(dx, dy) || 1;
  gz.tx = dx / d * k; gz.ty = dy / d * k * .8;
  // Ease part of the way on each update (the "short lag"), rather than a per-frame loop that repaints at 60–120 Hz.
  const lag = live.gazeOverride ? 1 : .5;
  const nx = gz.x + (gz.tx - gz.x) * lag, ny = gz.y + (gz.ty - gz.y) * lag;
  if (Math.abs(nx - gz.x) + Math.abs(ny - gz.y) < .03) return;
  gz.x = nx; gz.y = ny;
  e.setAttribute("transform", `translate(${gz.x.toFixed(2)} ${gz.y.toFixed(2)})`);
  // One follow-up step so it settles after the cursor stops.
  clearTimeout(gz.settle); gz.settle = setTimeout(gazeTarget, 90);
}
function gazeNow() { const e = eyesEl(); if (e) e.setAttribute("transform", `translate(${gz.x.toFixed(2)} ${gz.y.toFixed(2)})`); gazeTarget(); }

function blinkLoop() {
  setTimeout(() => {
    const e = eyesEl();
    if (e && !reduced && !el.classList.contains("hidden")) {
      e.style.transformBox = "fill-box"; e.style.transformOrigin = "center";
      const once = () => eyesEl()?.animate([{ transform: "scaleY(1)" }, { transform: "scaleY(.08)", offset: .45 }, { transform: "scaleY(1)" }], { duration: 150 });
      once();
      if (Math.random() < .22) setTimeout(once, 230);
    }
    blinkLoop();
  }, rnd(2200, 5800));
}

// ---------- motion primitives on #life ----------
function anim(target, frames, opts) {
  const n = typeof target === "string" ? $(target) : target;
  if (!n || reduced) return null;
  return n.animate(frames, Object.assign({ duration: 500, easing: "ease-out" }, opts));
}
const hop = (h = 10, d = 520) => anim(life, [
  { transform: "translateY(0) scale(1, 1)" }, { transform: "translateY(0) scale(1.08, .9)", offset: .15 },
  { transform: `translateY(${-h}px) scale(.94, 1.08)`, offset: .45 }, { transform: "translateY(0) scale(1.1, .88)", offset: .78 },
  { transform: "translateY(0) scale(1, 1)" }], { duration: d });
const shiver = () => anim(life, [{ transform: "translateX(0)" }, { transform: "translateX(-1.5px)" }, { transform: "translateX(1.5px)" },
                                 { transform: "translateX(-1px)" }, { transform: "translateX(0)" }], { duration: 260 });
function setLean(deg) { live.leanDeg = deg; $("lean").style.transform = deg ? `rotate(${deg.toFixed(1)}deg)` : ""; }
function wave(times = 3) {
  const lines = [...$("pose-root").querySelectorAll("#arm-r line")];
  if (!lines.length || live.waving || reduced) return false;
  live.waving = true;
  const root = $("pose-root"), orig = lines.map(n => [n.getAttribute("x2"), n.getAttribute("y2")]);
  let i = 0;
  const tick = () => {
    if ($("pose-root") !== root || i >= times * 2) {
      if ($("pose-root") === root) lines.forEach((n, k) => { n.setAttribute("x2", orig[k][0]); n.setAttribute("y2", orig[k][1]); });
      live.waving = false; return;
    }
    const [x, y] = [[110, 82], [116, 90]][i % 2];
    lines.forEach(n => { n.setAttribute("x2", x); n.setAttribute("y2", y); });
    i++; setTimeout(tick, 150);
  };
  tick();
  return true;
}
function lockFace(face, ms) { live.lock = { face, until: now() + ms }; refresh(); setTimeout(refresh, ms + 20); }

// ---------- sequence player ----------
let seqTimer = null;
function play(frames, opts) {
  opts = opts || {};
  markActive("sequence");
  if (live.lifted) return Promise.resolve();
  clearTimeout(seqTimer);
  if (live.seq) live.seq.done?.();
  return new Promise(done => {
    // `hold`: the last frame stays until something cancels it (the pause blind, until the window is put away).
    live.seq = { frames: frames.slice(), i: 0, cur: null, done, name: opts.name, hold: opts.hold };
    const step = () => {
      const q = live.seq;
      if (!q) return;
      if (q.i >= q.frames.length) {
        if (q.hold) return;
        live.seq = null; refresh({ settle: true }); done(); return;
      }
      q.cur = q.frames[q.i++];
      refresh();
      q.cur.fx && q.cur.fx();
      seqTimer = setTimeout(step, q.cur.ms);
    };
    step();
  });
}
function cancelSeq() { clearTimeout(seqTimer); const q = live.seq; live.seq = null; q?.done?.(); }

// ---------- idle life ----------
function lookAround() {
  const spots = [{ dx: -1, dy: .1 }, { dx: 1, dy: .2 }, { dx: .2, dy: -1 }, { dx: -.6, dy: .6 }];
  let i = 0;
  const step = () => {
    if (i >= 3 || live.hovered || live.pressed) { live.gazeOverride = null; gazeTarget(); return; }
    live.gazeOverride = pick(spots); gazeTarget(); i++;
    setTimeout(step, rnd(500, 900));
  };
  step();
}
function fidgetLoop() {
  setTimeout(() => {
    const quiet = !live.hovered && !live.pressed && !live.lifted && !live.seq && !live.mode && !live.saver && now() - live.pointerMovedAt > 2500
      && !el.classList.contains("hidden");
    if (quiet && !reduced) {
      const yawny = live.modes.has("late") || live.modes.has("droopy");
      const f = frame(), holding = !!VARIANT[s.state + ":" + s.variant];
      if (yawny && !holding && Math.random() < .5) lockFace("yawn", 1300);
      else if (f.pose === "doze") { if (Math.random() < .35) lockFace("yawn", 1100); }
      else if (s.duck) anim(life, [{ transform: "translateY(0)" }, { transform: "translateY(-7px)", offset: .3 },
                                   { transform: "translateY(-7px)", offset: .7 }, { transform: "translateY(0)" }], { duration: 1100, easing: "ease-in-out" });
      else if (isEdgeState()) pick([lookAround, () => hop(5, 600), lookAround, () => anim(life, [{ transform: "translateY(0)" },
                                   { transform: "translateY(-3px)" }, { transform: "translateY(0)" }], { duration: 2400, easing: "ease-in-out" })])();
      // Holding something up (a card, the door, a raised hand): only the eyes wander, so it never puts it down.
      else if (holding) lookAround();
      else pick([lookAround, () => wave(2), () => hop(6, 560), lookAround])();
    }
    fidgetLoop();
  }, rnd(6000, 14000));
}
