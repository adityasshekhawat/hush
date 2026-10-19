// renderer/compose.js: a fragment, not a standalone script. Swift (Assets.rendererPage) concatenates
// setup.js, compose.js, life.js and reactions.js inside one closure, so they share state.
// Sequences from timing.json, the SVG skeleton, composition (pose + face + rig parts + palette,
// cached), and the single frame owner + refresh().

// ---------- sequences from timing.json ----------
const SEQ = {};
const SEQ_NAMES = { "01": "command", "02": "drag", "03": "grumpy", "04": "poke", "05": "inboxZero",
                    "06": "perch", "07": "walk", "08": "morning", "09": "focus", "10": "eyes" };
for (const a of D.timing) {
  const folder = a.folder.split("/").pop();
  // The keyframe files are blob-only; rebuild each frame from its pose + expression so it works on every body.
  SEQ[SEQ_NAMES[folder.slice(0, 2)] || folder] = a.frames.map(f => {
    const frameKey = f.file.replace(/\.svg$/, "");
    const box = folder.startsWith("01-") && D.commandFrames && /prop-command-box"[^>]*>\s*<rect/.test(D.commandFrames[frameKey] || "") ? frameKey : null;
    return { pose: f.pose, expr: f.expr, ms: f.ms, caption: f.caption, box };
  });
}
// Short custom sequences built from poses (pose, expression, ms).
const F = (pose, expr, ms, extra) => Object.assign({ pose, expr, ms }, extra || {});

// ---------- skeleton ----------
const svg = document.createElementNS(NS, "svg");
svg.setAttribute("viewBox", "0 0 160 146");
svg.innerHTML = `
  <defs><clipPath id="hush-clip"><rect id="clip-rect" x="0" y="0" width="160" height="112"/></clipPath></defs>
  <g id="slot-fx-back"></g><g id="slot-props"></g>
  <g id="clipper" clip-path="url(#hush-clip)"><g id="character">
    <g id="lean"><g id="groove"><g id="puff"><g id="rise"><g id="breath"><g id="life">
      <g id="rim"></g><g id="pose-root"></g>
    </g></g></g></g></g></g>
  </g></g>
  <g id="slot-hands"></g><g id="slot-overlay"></g><g id="slot-box"></g>`;
const groovewrap = document.createElement("div"), breathwrap = document.createElement("div");
groovewrap.id = "groovewrap"; breathwrap.id = "breathwrap";
breathwrap.appendChild(svg); groovewrap.appendChild(breathwrap); el.appendChild(groovewrap);
const $ = id => svg.querySelector("#" + id);
const clipRect = $("clip-rect"), character = $("character"), life = $("life"), rimSlot = $("rim");

// ---------- composition (cached per pose + face + look) ----------
const poseDocs = {}, rigDocs = {}, faceDocs = {}, cache = new Map();
const bodyPoses = () => D.poses[s.body] || D.poses.blob;
const bodyFaces = () => D.expressions[s.body] || D.expressions.blob;
const getPose = n => { const k = s.body + "/" + n; return poseDocs[k] || (poseDocs[k] = parse(bodyPoses()[n] || bodyPoses().stand)); };
const getRig = () => { const k = s.body + "/" + s.eyes; return rigDocs[k] || (rigDocs[k] = parse((D.rigs[s.body] || D.rigs.blob)[s.eyes])); };
const getFace = n => { const k = s.body + "/" + n; return faceDocs[k] || (faceDocs[k] = parse(bodyFaces()[n]).querySelector("#face")); };
const boxDocs = {};
const getBox = k => boxDocs[k] || (boxDocs[k] = parse(D.commandFrames[k]).querySelector("#prop-command-box"));
const lookKey = () => [s.body, s.palette, s.eyes, s.topper, (s.wear || []).join("+"), s.dark].join(",");
// Wearables (docs/design-guide.md §6a): face pieces ride on the face, the cape's back layer goes behind
// everything, the rest sit in #accessory. Ground pieces stay off edge and perch poses (no ground there).
const FACE_WEAR = /^(accessory-glasses|face-shades|rare-heart-glasses|rare-monocle|pack-face-)/;
const GROUND_WEAR = /^(pack-carry-|rare-carry-cocoa|rare-carry-lantern|buddy-snail)/;
const EDGE_POSES = new Set(["peek", "hide", "dive"]);
const EYE = { round: [5.2, 5.2], oval: [4.2, 6.4], pebble: [6.2, 4.3] };

function faceFor(expr) {
  if (expr === "blow") {
    // Neutral face, mouth swapped for the rig's small "o".
    const f = getFace("neutral").cloneNode(true);
    const mouth = f.querySelector("#mouth"), rigMouth = getRig().querySelector("#mouth").cloneNode(true);
    rigMouth.querySelectorAll("[id^='mouth-']").forEach(m => m.setAttribute("opacity", m.id === "mouth-small-o" ? "1" : "0"));
    mouth && mouth.replaceWith(rigMouth);
    return f;
  }
  return bodyFaces()[expr] ? getFace(expr).cloneNode(true) : null;
}

// Light outline under the character so it reads on dark desktops (v2 shipped one; v3 doesn't).
function makeRim(src) {
  const r = src.cloneNode(true);
  r.removeAttribute("id");  // keep the transform: the outline must rotate/scale with the pose
  r.querySelectorAll("[opacity='0'], #face, [id^='fx-']").forEach(n => n.remove());
  for (const n of [r, ...r.querySelectorAll("*")]) {
    n.removeAttribute("id");
    const f = n.getAttribute("fill");
    if (f && f !== "none") n.setAttribute("fill", PAPER);
    if (n.hasAttribute("stroke") && n.getAttribute("stroke") !== "none") n.setAttribute("stroke", PAPER);
    const sw = parseFloat(n.getAttribute("stroke-width"));
    if (sw) n.setAttribute("stroke-width", sw + 5);
    else if (/^(path|ellipse|circle|rect)$/.test(n.tagName) && f && f !== "none") {
      n.setAttribute("stroke", PAPER); n.setAttribute("stroke-width", 5);
    }
  }
  return r;
}

function recolor(root) {
  const pal = D.palettes[s.palette] || D.palettes.oat;
  const map = { "#F4D9A6": pal.body, "#FFF5E1": pal.belly, "#E8876A": pal.accent };
  for (const n of root.querySelectorAll("*")) {
    for (const a of ["fill", "stroke"]) { const v = (n.getAttribute(a) || "").toUpperCase(); if (map[v]) n.setAttribute(a, map[v]); }
  }
  root.querySelectorAll("#blush").forEach(n => n.setAttribute("fill", pal.cheek));
  if (s.dark) root.querySelectorAll("[id^='fx-']").forEach(n => { if ((n.getAttribute("stroke") || "").toUpperCase() === INK) n.setAttribute("stroke", PAPER); });
}

function compose(pose, expr) {
  const key = pose + "|" + (expr || "") + "|" + lookKey();
  let c = cache.get(key);
  if (c) return c;
  const doc = getPose(pose).cloneNode(true);
  // The real desktop provides these.
  doc.querySelectorAll("#screen-edge, #prop-cursor, #prop-window").forEach(n => n.remove());
  const rig = getRig();
  const root = doc.querySelector("#pose-root");
  const topper = root.querySelector("#topper");
  if (topper) {
    topper.replaceChildren();
    const t = s.topper !== "none" && rig.querySelector("#topper-" + s.topper);
    if (t) { const n = t.cloneNode(true); n.removeAttribute("opacity"); topper.appendChild(n); }
  }
  const acc = root.querySelector("#accessory");
  if (acc) acc.replaceChildren();
  let face = root.querySelector("#face");
  const nf = expr && faceFor(expr);
  if (nf && face) { face.replaceWith(nf); face = nf; }
  if (face) {
    const [rx, ry] = EYE[s.eyes] || EYE.round;
    face.querySelectorAll("#eyes-open > ellipse").forEach(e => {
      const k = parseFloat(e.getAttribute("rx")) / 5.2;
      if (k > .3 && Math.abs(parseFloat(e.getAttribute("rx")) - parseFloat(e.getAttribute("ry"))) < .01) {
        e.setAttribute("rx", (rx * k).toFixed(2)); e.setAttribute("ry", (ry * k).toFixed(2));
      }
    });
  }
  const grounded = !EDGE_POSES.has(pose) && !/perch/i.test(pose);
  for (const id of s.wear || []) {
    const part = rig.querySelector("#" + id);
    if (!part || (GROUND_WEAR.test(id) && !grounded)) continue;
    const n = part.cloneNode(true); n.removeAttribute("opacity");
    if (id === "pack-cape-back") root.insertBefore(n, root.firstChild);
    else if (FACE_WEAR.test(id)) { if (face) face.insertBefore(n, face.querySelector("#mouth")); }
    else if (acc) acc.appendChild(n);
  }
  ["prop-clock", "prop-envelope"].forEach(id => {
    const p = root.querySelector("#" + id);
    if (p) { const g = doc.ownerDocument.createElementNS(NS, "g"); g.setAttribute("class", "anim"); while (p.firstChild) g.appendChild(p.firstChild); p.appendChild(g); }
  });
  recolor(doc);
  const hands = doc.querySelector("#hands-on-edge");
  const handsHas = hands && hands.children.length;
  const base = pose;
  c = {
    pose, base,
    charT: doc.querySelector("#character")?.getAttribute("transform") || "translate(20 2)",
    root, rim: makeRim(root),
    fxBack: doc.querySelector("#fx-back"),
    hands: handsHas ? hands : null, handsRim: handsHas ? makeRim(hands) : null,
    box: doc.querySelector("#prop-command-box"),
    // Anything else at the top level (e.g. the envelope stack beside "pile") rides along behind the character.
    props: [...doc.children].filter(n => !/^(title|defs)$/.test(n.tagName) && !n.hasAttribute("clip-path") &&
      !["fx-back", "hands-on-edge", "prop-command-box", "screen-edge"].includes(n.id) && !n.querySelector("#character")),
    edge: !!doc.querySelector("[clip-path]"),
    perch: /perch/i.test(pose),
  };
  cache.set(key, c);
  if (cache.size > 300) cache.delete(cache.keys().next().value);
  return c;
}
const imp = n => document.importNode(n, true);

// ---------- who decides the frame ----------
const STATE_POSE = { "10-think": "sitThink", "11-notice": "notice", "12-stand": "stand",
                     "01-peek": "peek", "02-doze": "doze", "03-pile": "pile", "04-hold": "hold", "05-clock": "clock",
                     "06-hurry": "hurry", "07-tap": "tap", "08-bow": "bow", "09-hide": "hide" };
const isEdgeState = () => s.state === "01-peek" || (s.state === "09-hide" && s.duck);

function frame() {
  if (live.lifted) return live.swingFast ? { pose: "swing", expr: "squint" } : { pose: "grab", expr: "surprised" };
  if (live.seq) return live.seq.cur;
  if (live.mode === "walk") return { pose: "walk" + (1 + live.modeFrame % 4), expr: "" };
  if (live.mode === "perch") return { pose: live.perchDoze ? "perchDoze" : (live.modeFrame % 2 ? "perch2" : "perch"), expr: "" };
  if (live.mood && s.state === "04-hold") return [null, F("tapfoot", "grumpy"), F("cross", "pout"), F("huff", "hmph"), F("huff", "hmph")][live.mood];
  if (live.patting && !isEdgeState()) return { pose: "pat", expr: "blissful" };
  if (live.boxPose) return { pose: live.boxPose, expr: live.boxPose === "sitThink" ? "thinking" : "" };
  if (live.risen && isEdgeState()) return { pose: "stand", expr: "", risen: true };
  if (s.state === "09-hide" && s.duck) return { pose: "peek", expr: "", duck: true };
  if (s.state === "12-stand" && live.modes.has("groove")) return { pose: "bob", expr: "happy" };
  if (s.state === "12-stand" && live.modes.has("droopy")) return { pose: "droopy", expr: "droopy" };
  return { pose: STATE_POSE[s.state] || "peek", expr: "" };
}

function faceOverride(f) {
  // Copied something: the puffed face stays on through every frame until the paste (design guide §6).
  if (live.full && !live.lifted && !(live.lock && live.lock.until > now())) return "puff";
  if (live.seq && f.expr) return f.expr;
  if (live.lock && live.lock.until > now()) return live.lock.face;
  if (live.lifted) return f.expr;
  if (live.patting) return "blissful";
  if (live.handNap) return "sleepy";
  if (live.asking) return "happy";
  if (live.hovered) return /doze|perchDoze/.test(f.pose) ? "surprised" : "happy";
  if (live.near && /peek|stand|hold|clock|pile|perch$|perch2/.test(f.pose)) return "alert";
  return f.expr || "";
}

let shown = { key: null, pose: null };
function refresh(opts) {
  opts = opts || {};
  const f = frame();
  const expr = faceOverride(f);
  const c = compose(f.pose, expr);
  const edge = f.risen || f.duck || c.edge || EDGE_POSES.has(f.pose);
  const key = f.pose + "|" + expr + "|" + lookKey() + "|" + (f.risen ? "r" : f.duck ? "d" : "") + "|" + (f.box || "");
  if (key !== shown.key) {
    const nextPose = f.pose + (f.risen ? "-risen" : "");
    // Pose changes blend over 0.18 s (design guide §3); walk and perch cycles, drags and Reduce Motion swap.
    if (shown.pose && shown.pose !== nextPose && !reduced && !live.mode && !live.lifted) crossFade();
    character.setAttribute("transform", c.charT);
    $("pose-root").replaceWith(imp(c.root));
    rimSlot.replaceChildren(imp(c.rim));
    $("slot-fx-back").replaceChildren(...(c.fxBack ? [...c.fxBack.childNodes].map(imp) : []));
    const showHands = c.hands && !f.risen;
    $("slot-hands").replaceChildren(...(showHands ? [imp(c.handsRim), ...[...c.hands.childNodes].map(imp)] : []));
    const box = f.box ? getBox(f.box) : c.box;
    $("slot-box").replaceChildren(...(box ? [imp(box)] : []));
    $("slot-props").replaceChildren(...c.props.map(imp));
    clipRect.setAttribute("y", edge ? "0" : "-400"); clipRect.setAttribute("height", edge ? "112" : "800");
    // Anchor: edge poses put y=112 on the floor, perches put the window line (116) on the window's top, the rest stand at 138.
    const anchor = edge ? 112 : c.perch ? 116 : 138;
    const h = s.height * 146 / 100;
    svg.style.height = h + "px";
    el.classList.toggle("settle", !!opts.settle && !live.seq);
    el.style.bottom = ((anchor - 112) / 146 * h) + "px";
    const poseClass = f.duck ? "duck" : f.risen ? "risen" : (c.base || "");
    for (const cl of [...el.classList]) if (cl.startsWith("st-")) el.classList.remove(cl);
    if (poseClass && !live.seq) el.classList.add("st-" + poseClass);
    el.classList.toggle("breathe", !edge && !live.seq && !live.lifted);
    if (f.risen && shown.pose !== "stand-risen") { el.classList.add("rising"); void el.offsetWidth; el.classList.remove("rising"); }
    const poseChanged = shown.pose !== (f.pose + (f.risen ? "-risen" : ""));
    shown = { key, pose: f.pose + (f.risen ? "-risen" : "") };
    applyOverlays();
    gazeNow();
    if (poseChanged) requestAnimationFrame(reportBox);
  } else {
    applyOverlays();
  }
}

function crossFade() {
  const ghost = character.cloneNode(true);
  ghost.removeAttribute("id");
  ghost.querySelectorAll("[id]").forEach(n => n.removeAttribute("id"));
  ghost.style.pointerEvents = "none";
  character.after(ghost);
  ghost.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 180, easing: "ease-out" }).onfinish = () => ghost.remove();
}

function reportBox() {
  const r = character.getBoundingClientRect();
  // Edge poses: only the part above the screen edge (y=112) is visible / hittable.
  const sr = svg.getBoundingClientRect();
  const edgeY = sr.top + 112 * sr.height / 146;
  const bottom = clipRect.getAttribute("height") === "112" ? Math.min(r.bottom, edgeY) : r.bottom;
  post({ type: "bbox", x: r.left, y: r.top, w: r.width, h: Math.max(0, bottom - r.top) });
}
