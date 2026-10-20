// renderer/reactions.js: a fragment, not a standalone script. Swift (Assets.rendererPage) concatenates
// setup.js, compose.js, life.js and reactions.js inside one closure, so they share state.
// Reactions to the app (hover, press, pat, poke, drag, antics, moods, calm mode) and the window.hush API.

// ---------- reactions ----------
function setHover(on) {
  if (on === live.hovered) return;
  live.hovered = on;
  if (isEdgeState() && !live.lifted && !live.seq && !live.mode) {
    live.risen = on;
    if (on) setTimeout(() => { if (live.risen) wave(2); }, 380);
    setTimeout(reportBox, 400);
  } else if (on && !live.pressed && !live.lifted && !live.seq) {
    /doze/.test(frame().pose) ? (hop(9, 420), shiver()) : hop(6, 460);
  }
  refresh();
}

let patTimer = null;
function press(on) {
  live.pressed = on;
  if (on) anim(life, [{ transform: "scale(1, 1)" }, { transform: "scale(1.07, .92)" }], { duration: 120, fill: "forwards" });
  else { life.getAnimations().filter(a => !(a instanceof CSSAnimation)).forEach(a => a.cancel()); if (live.patting) pat(false); }
}
function pat(on) {
  live.patting = on;
  clearInterval(patTimer);
  if (on) {
    const side = live.pointer && live.pointer.x < el.clientWidth / 2 ? -1 : 1;
    let k = 0; setLean(side * 7);
    patTimer = setInterval(() => setLean(side * 7 + Math.sin(k++ / 2) * 3), 140);
  } else setLean(0);
  refresh();
}

// Poke: the designer's squish → giggle → wiggle; the fifth poke in a row gets the grumpy face instead.
function poke() {
  const t = now();
  live.clicks = live.clicks.filter(c => t - c < 2500).concat(t);
  if (live.clicks.length >= 5) {
    live.clicks = [];
    play([F("poked", "squint", 150), F("cross", "grumpy", 1100), F("stand", "grumpy", 500)]);
  } else play(SEQ.poke);
}

function lift() {
  cancelSeq();
  live.lifted = true; live.risen = false; live.swingFast = false;
  el.classList.add("lifted");
  refresh();
}
let swingTimer = null;
function swing(vx) {
  if (!live.lifted) return;
  setLean(clamp(-vx * .9, -28, 28));
  const fast = Math.abs(vx) > 14;
  if (fast) { clearTimeout(swingTimer); swingTimer = setTimeout(() => { live.swingFast = false; refresh(); }, 250); }
  if (fast !== live.swingFast && fast) { live.swingFast = true; refresh(); }
}
// Dropped: squash; if it was shaken hard, dizzy (longer the harder), shake it off, sheepish.
function land(intensity) {
  live.lifted = false; live.swingFast = false;
  el.classList.remove("lifted"); setLean(0);
  const k = clamp(intensity || 0, 0, 1);
  const frames = [F("land", "squint", 220)];
  if (k > .45) frames.push(F("dizzy", "dizzy", 600 + 1400 * k), F("shake", "squint", 500), F("stand", "apologetic", 900));
  else frames.push(F("stand", "happy", 500));
  play(frames);
}

function setMode(name, on) {
  if (name === "walk" || name === "perch") {
    clearInterval(live.modeTimer);
    live.mode = on ? name : (live.mode === name ? null : live.mode);
    live.modeFrame = 0; if (name === "perch" && !on) live.perchDoze = false;
    if (on) live.modeTimer = setInterval(() => { live.modeFrame++; refresh(); }, name === "walk" ? 140 : 900);
    refresh({ settle: true });
    setTimeout(reportBox, 50);
    return;
  }
  on ? live.modes.add(name) : live.modes.delete(name);
  el.classList.toggle(name, on);
}

// Copy: cheeks fill up. Copy again while full: gulp, and they fill right back up.
function cheeks() {
  if (live.full) {
    anim(life, [{ transform: "scale(1, 1)" }, { transform: "scale(.94, 1.06) translateY(2px)", offset: .35 },
                { transform: "scale(1.04, .97)", offset: .7 }, { transform: "scale(1, 1)" }], { duration: 420 });
    return;
  }
  live.full = true; cheekPop = true;
  el.classList.add("full");
  refresh(); hop(4, 380);
}
// Hand it to Hush (ADR-019): chews (v1 art: chewOpen / chewClosed) while the on-device model works, never longer than
// 25 s, then hands back a folded note when it worked. Pose swaps only, no running animation in the SVG (ADR-011).
let chewStop = null;
function chew(on) {
  clearTimeout(chewStop);
  if (!on) {
    if (!live.chewing) return;
    live.chewing = false; cancelSeq(); refresh({ settle: true });
    return;
  }
  live.chewing = true;
  markActive("chew");
  const frames = [];
  for (let i = 0; i < 55; i++) frames.push(...SEQ.handIt.slice(0, 2));
  play(frames);
  chewStop = setTimeout(() => chew(false), 25000);
}
// Paste: cheeks deflate through the small "o" while puffs stream out, then a little recoil.
function blow() {
  if (!live.full) return;
  live.full = false;
  el.classList.remove("full");
  const bulge = $("pose-root").querySelector("#cheek-bulge");
  live.lock = { face: "blow", until: now() + 900 };
  if (bulge && !reduced) {
    bulge.dataset.leaving = "1";
    const a = bulge.animate([{ transform: "scale(1)" }, { transform: "scale(1.1, .9)", offset: .3 }, { transform: "scale(.2)", opacity: .2 }],
                            { duration: 380, easing: "ease-in", fill: "forwards" });
    a.onfinish = () => bulge.remove();
  }
  refresh();
  setTimeout(refresh, 920);
  const face = $("pose-root").querySelector("#face");
  if (face && !reduced) {
    const dir = Math.random() < .5 ? -1 : 1;
    for (let i = 0; i < 5; i++) {
      const c = document.createElementNS(NS, "circle");
      c.setAttribute("cx", dir * 3); c.setAttribute("cy", 12); c.setAttribute("r", 4.2 - i * .6);
      c.setAttribute("fill", s.dark ? "rgba(255,253,247,.18)" : "rgba(255,255,255,.7)");
      c.setAttribute("stroke", s.dark ? PAPER : INK); c.setAttribute("stroke-width", "1.7");
      face.appendChild(c);
      const dx = dir * (26 + i * 12), dy = -6 - i * 4 + (i % 2 ? 3 : -3);
      const p = c.animate([{ transform: "translate(0, 0) scale(.4)", opacity: 0 },
                           { transform: `translate(${dx * .3}px, ${dy * .3}px) scale(1)`, opacity: 1, offset: .25 },
                           { transform: `translate(${dx}px, ${dy}px) scale(1.25)`, opacity: 0 }],
                          { duration: 900, delay: 60 + i * 80, easing: "ease-out", fill: "forwards" });
      p.onfinish = () => c.remove();
    }
  }
  anim(life, [{ transform: "scale(1.06, .96)" }, { transform: "translateX(-3px) scale(.95, 1.04)", offset: .4 }, { transform: "scale(1, 1)" }],
       { duration: 650, delay: 120 });
}

// Pat request: stands and tilts its head hopefully, swaying. Thanked → giggle; ignored → sheepish.
function askPat(state) {
  if (state === "start") {
    live.asking = true; el.classList.add("asking");
    play([F("listen", "happy", 15000)]);
    return;
  }
  live.asking = false; el.classList.remove("asking");
  if (state === "thanked") play([F("giggle", "happy", 700), F("wiggleL", "happy", 220), F("wiggleR", "happy", 220), F("stand", "happy", 500)]);
  else play([F("stand", "apologetic", 1400)]);
}

function flash() {
  if (!reduced) svg.animate([{ filter: "brightness(2.2)" }, { filter: "brightness(1)" }], { duration: 260, easing: "ease-out" });
  lockFace("squint", 750); shiver();
}
const woozy = () => play([F("dizzy", "dizzy", 1300), F("shake", "squint", 450)]);
function flinch(dx) {
  const away = dx > 0 ? 1 : -1;
  play([F("flinch", "surprised", 650)]);
  anim(life, [{ transform: "translateX(0)" }, { transform: `translateX(${away * 9}px) rotate(${away * 6}deg)`, offset: .25 },
              { transform: `translateX(${away * 5}px)`, offset: .6 }, { transform: "translateX(0)" }], { duration: 700 });
}
const perk = () => play([F("perk", "happy", 1300)]);
const morning = () => play(SEQ.morning);
const dance = () => play([F("crouch", "happy", 200), F("dance", "happy", 700), F("wiggleL", "happy", 220), F("dance", "happy", 700),
                          F("wiggleR", "happy", 220), F("proud", "happy", 900)]);
function tuckIn() {
  live.tucked = true;
  play([F("yawn", "yawn", 900), F("doze", "sleepy", 8200)]).then(() => { live.tucked = false; refresh(); });
}
const inboxZero = () => play(SEQ.inboxZero);
const jump = () => play([F("crouch", "happy", 160), F("cheer", "happy", 600)]);
// Ask Hush: off it goes (hand-off), here you are (answer), sorry (failed).
const waveOff = () => play([F("wave", "happy", 1200), F("stand", "happy", 300)]);
const handOver = () => play([F("handOver", "happy", 1100), F("stand", "happy", 400)]);
const sorry = () => play([F("sorry", "apologetic", 1400)]);
// Dropped onto a window edge: let go of the lift and settle straight into the perch with a little squash.
function perchLand() {
  live.lifted = false; live.swingFast = false;
  el.classList.remove("lifted"); setLean(0);
  setMode("perch", true);
  anim(life, [{ transform: "scale(1.12, .86)" }, { transform: "scale(.96, 1.05)", offset: .5 }, { transform: "scale(1, 1)" }], { duration: 420 });
}
const commandWindow = () => play(SEQ.command);
// Calls / screen share: leave fast with no flourish (the app removes the window ~0.8 s later).
// Frames 2–3 of the designer's sequence (notice, dive): the first is just the idle frame.
const focusDive = () => play(SEQ.focus.slice(1, 3).map(f => Object.assign({}, f, { ms: Math.min(f.ms, 300) })));

// Ignored-and-getting-grumpy (opt-in Moods): stage 0 none, 1 tap foot, 2 arms crossed, 3 one stomp then huff.
function setMood(stage) {
  const prev = live.mood;
  live.mood = stage;
  if (stage === 3 && prev < 3) { play([F("stomp", "angry", 500)]).then(() => { live.mood = 4; refresh(); }); return; }
  refresh({ settle: true });
}

// Calm mode: the cursor hasn't been near Hush for a while and nothing's going on.
const CALM_AFTER = 15000, NEAR_PX = 250;
live.nearAt = now();
function markActive(why) {
  live.nearAt = now();
  if (el.classList.contains("calm")) { el.classList.remove("calm"); post({ type: "log", message: "calm false: " + (why || "?") }); }
}
// One slow housekeeping tick: calm mode, and dozing off under a resting cursor.
setInterval(() => {
  const busy = live.hovered || live.pressed || live.lifted || live.seq || live.mode || live.asking;
  if (busy) live.nearAt = now();
  const calm = live.alwaysCalm || (!busy && !live.neverCalm && now() - live.nearAt > CALM_AFTER);
  if (calm !== el.classList.contains("calm")) post({ type: "log", message: "calm " + calm + " (state " + s.state + (s.duck ? " duck" : "") + ")" });
  el.classList.toggle("calm", calm);
  if (!live.handNap && live.hovered && !live.pressed && !live.lifted && !live.seq && now() - live.pointerMovedAt > 20000) {
    live.handNap = true; refresh();
  }
}, 2000);
// Tapping on the glass (ADR-022): a two-knock burst every 6 s while the state lasts, still in between.
let knockTimer = null;
function knockBursts() {
  clearTimeout(knockTimer);
  if (s.state !== "07-tap") { el.classList.remove("knock"); return; }
  // Holding the door for a meeting: an occasional tap of the foot, not knocks on the glass. Running late: beckons only.
  if (s.variant === "door" || s.variant === "late") {
    el.classList.remove("knock");
    if (s.variant === "door" && !live.seq && !live.lifted) play([SEQ.meetingNow[3]]);
    knockTimer = setTimeout(knockBursts, 9000);
    return;
  }
  el.classList.remove("knock"); void el.offsetWidth;   // restart the two-iteration animation
  el.classList.add("knock");
  knockTimer = setTimeout(knockBursts, 6000);
}
function wakeFromHandNap() { if (!live.handNap) return; live.handNap = false; lockFace("surprised", 600); shiver(); }

window.hush = {
  setLook(o) { Object.assign(s, o); cache.clear(); shown.key = null; refresh(); },
  setState(k, o) {
    o = o || {};
    const prev = s.state, prevDuck = s.duck, prevVariant = s.variant;
    if (prev !== k) markActive("state " + k);
    s.state = k; s.duck = !!o.duck; s.variant = o.variant || "";
    if (o.labels) Object.assign(live.labels, o.labels);
    if ((prev !== k || prevVariant !== s.variant) && (k === "07-tap" || prev === "07-tap")) knockBursts();
    // Going away behind the pause blind: it stays down until the window is put away.
    if (k === "09-hide" && !s.duck && (prev !== k || prevDuck)) { if (live.seq?.name !== "pause") focusDive(); return; }
    if (!isEdgeState()) live.risen = false;
    const entrance = (prev !== k || prevVariant !== s.variant) && ENTRANCE[k + ":" + s.variant];
    if (entrance && !live.lifted && !reduced) { live.risen = false; play(entrance(), { name: "entrance" }); return; }
    if (live.lifted || live.seq) { if (live.seq?.name === "entrance" && !entrance) cancelSeq(); else return; }
    if (o && o.fromEdge && prev !== k) {
      el.classList.add("from-edge"); refresh();
      requestAnimationFrame(() => requestAnimationFrame(() => { el.classList.add("slide"); el.classList.remove("from-edge"); setTimeout(() => el.classList.remove("slide"), 600); }));
    } else refresh({ settle: true });
    if (prev !== k && !reduced) { el.classList.remove("enter"); void el.offsetWidth; el.classList.add("enter"); }
  },
  setDark(d) { if (s.dark !== d) { s.dark = d; cache.clear(); shown.key = null; refresh(); } },
  pointer(x, y) {
    if (!live.pointer || live.pointer.x !== x || live.pointer.y !== y) { live.pointerMovedAt = now(); wakeFromHandNap(); }
    live.pointer = { x, y };
    // Pointer within reach (in this page's coordinates, the character is near the middle) → not calm.
    if (Math.hypot(x - el.clientWidth / 2, y - el.clientHeight / 2) < NEAR_PX) markActive("pointer near");
    live.gazeOverride = null;
    if (!live.lifted && !live.mode) {
      const r = character.getBoundingClientRect();
      const cx = r.left + r.width / 2, cy = r.top + r.height / 2;
      const d = Math.hypot(x - cx, y - cy);
      const near = live.near ? d < 200 : d < 160;
      if (near !== live.near) { live.near = near; refresh(); }
      if (!live.patting) setLean(near && !live.hovered ? clamp((x - cx) / 30, -6, 6) : 0);
    }
    gazeTarget();
  },
  hover: setHover, press, pat, poke, lift, swing, land,
  cheeks, blow, chew, askPat, flash, woozy, flinch, perk, morning, dance, tuckIn, setMode, setMood,
  inboxZero, commandWindow, jump, perchLand, waveOff, handOver, sorry,
  handedBack: () => play([SEQ.handIt[SEQ.handIt.length - 1], F("stand", "", 300)]),
  proud: () => play([F("cheer", "happy", 500), F("proud", "happy", 1600)]),
  // First rare find: the bird gets a surprised look up, then bliss; birthday a cheer; halo pride; lei a wave.
  rareFirst(id) {
    const seq = {
      bird: [F("notice", "surprised", 900), F("stand", "blissful", 1400)],
      partyHat: [F("crouch", "happy", 200), F("cheer", "happy", 900)],
      balloon: [F("crouch", "happy", 200), F("cheer", "happy", 900)],
      halo: [F("proud", "happy", 1600)],
      lei: [F("wave", "happy", 1200)],
    }[id] || [F("notice", "surprised", 700), F("stand", "happy", 900)];
    play(seq);
  },
  boxPose(p) { if (p && live.seq) cancelSeq(); live.boxPose = p; refresh(); setTimeout(reportBox, 60); },
  perchDoze(on) { live.perchDoze = on; refresh(); },
  // Window ordered out (calls / screen share): stop everything until it's back.
  diag() {
    const anims = document.getAnimations().map(a => (a.animationName || a.constructor.name) + ":" + a.playState);
    post({ type: "log", message: "diag " + JSON.stringify({ calm: el.classList.contains("calm"), cls: el.className, state: s.state,
      hovered: live.hovered, pressed: live.pressed, lifted: live.lifted, seq: !!live.seq, mode: live.mode, asking: live.asking,
      neverCalm: !!live.neverCalm, sinceNear: Math.round(now() - live.nearAt), anims }) });
  },
  debugCalm(mode) {
    live.neverCalm = mode === "never"; live.alwaysCalm = mode === "always";
    if (live.neverCalm) markActive("debug");
    if (live.alwaysCalm) el.classList.add("calm");
  },
  setVisible(on) {
    el.classList.toggle("hidden", !on);
    if (on) { markActive(); if (live.seq?.name === "pause") { cancelSeq(); refresh(); } }
  },
  // A named designer sequence (timing.json 11–29) with the words it shows: {flag, card, bin, more}.
  sequence(name, labels) {
    // Small ones that aren't in timing.json: Hush shows you its notebook when the journal opens.
    const frames = SEQ[name] || { journal: [F("holdJournal", "happy", 1800)] }[name];
    if (!frames || live.lifted) return;
    if (labels) Object.assign(live.labels, labels);
    if (name === "pause") { play(frames, { name, hold: true }); return; }
    // The satchel's size says how much mail it carries (s 1–5, m 6–20, l 21+).
    const size = labels && labels.satchel;
    const seq = size ? frames.map(f => f.wear ? Object.assign({}, f, { wear: f.wear.map(w => w.replace(/^prop-satchel-.$/, "prop-satchel-" + size)) }) : f) : frames;
    if (reduced) return;
    play(seq, { name });
  },
  // README recordings (MediaRecorder): the character as it is right now, as standalone SVG. Each visible part gets its
  // live on-screen transform (every CSS and Web Animations transform, via getScreenCTM) and opacity baked in, and the
  // wrappers' own transforms are dropped, so hops and squashes survive outside the browser.
  snapshot() {
    if (el.classList.contains("hidden")) return JSON.stringify({ hidden: true });
    const clone = svg.cloneNode(true);
    // Whatever the page's CSS hides right now (display, visibility, opacity 0) must not appear in the copy, which has
    // no stylesheet. Elements pair up by document order before anything is moved.
    const live = [...svg.querySelectorAll("*")], copy = [...clone.querySelectorAll("*")];
    const twin = new Map(live.map((n, i) => [n, copy[i]]));
    const gone = [];
    live.forEach((n, i) => {
      const cs = getComputedStyle(n);
      if (cs.display === "none" || cs.visibility === "hidden" || parseFloat(cs.opacity) === 0) gone.push(copy[i]);
    });
    gone.forEach(n => n.remove());
    const inv = svg.getScreenCTM().inverse();
    const ids = ["life", "breath", "rise", "puff", "groove", "lean", "character", "clipper"];
    ids.forEach(id => clone.querySelector("#" + id)?.removeAttribute("transform"));
    const parts = [...svg.querySelector("#life").children, ...["slot-fx-back", "slot-props", "slot-edge", "slot-hands", "slot-overlay", "slot-labels", "slot-box"].map(id => svg.querySelector("#" + id))];
    parts.forEach((n) => {
      const c = n && twin.get(n);
      if (!c || !clone.contains(c)) return;   // hidden right now: already dropped
      const m = inv.multiply(n.getScreenCTM());
      c.setAttribute("transform", `matrix(${m.a} ${m.b} ${m.c} ${m.d} ${m.e} ${m.f})`);
      let o = 1;
      for (let p = n; p && p !== svg; p = p.parentNode) o *= parseFloat(getComputedStyle(p).opacity || "1");
      if (o < 0.999) c.setAttribute("opacity", o.toFixed(3));
    });
    // Parts inside #life are positioned in the svg's own space now; lift them out of the clipped, transformed chain.
    const root = clone.querySelector("#clipper");
    clone.querySelectorAll("#life > *").forEach(n => root.appendChild(n));
    const r = svg.getBoundingClientRect();
    return JSON.stringify({ svg: new XMLSerializer().serializeToString(clone), x: r.left, y: r.top, w: r.width, h: r.height,
                            o: parseFloat(getComputedStyle(el).opacity || "1") });
  },
  // Energy saver (ADR-022): always calm, no idle fidgets. Reactions and alerts still play.
  // The nightcap stays on while it lasts (v1 art); turning it on plays the yawn once.
  setSaver(on) {
    const was = !!live.saver;
    live.saver = on; live.alwaysCalm = on; if (on) el.classList.add("calm");
    cache.clear(); shown.key = null;
    if (on && !was && !reduced && !live.lifted && !el.classList.contains("hidden")) play(SEQ.battery, { name: "battery" }); else refresh();
    post({ type: "log", message: "saver " + on });
  },
};
refresh();
blinkLoop();
fidgetLoop();
post({ type: "ready" });
