// Hush, drawn from the app's own character pack (site/hush-data.js, built by scripts/build-site.py).
// Same composition as the app (assets/renderer/compose.js): the pose's SVG, the expression's face, the rig's topper
// and wearables (face pieces inside #face, the cape's back layer behind everything, the rest in #accessory),
// then the palette. Usage:
//   Hush.svg({ shape, palette, topper, pose, expr, head, face, neck, carry, buddy, lookx, looky })  → SVG string
//   <span data-hush="pose:peek;size:320"></span> + Hush.mountAll()
(function () {
  const D = window.HUSH_DATA;
  const parser = new DOMParser();
  const serializer = new XMLSerializer();
  const INK = "#2D2A35";
  const FACE_WEAR = /^(accessory-glasses|face-shades|rare-heart-glasses|rare-monocle|pack-face-)/;
  const GROUND_WEAR = /^(pack-carry-|rare-carry-cocoa|rare-carry-lantern|buddy-snail)/;
  const EDGE_POSES = new Set(["peek", "hide", "dive"]);
  const parse = (src) => parser.parseFromString(src, "image/svg+xml").documentElement;
  const rigs = {};
  const cache = new Map();

  function rig(body) {
    return rigs[body] || (rigs[body] = parse(D.rigs[body] || D.rigs.blob));
  }

  function recolor(root, palette) {
    const pal = D.palettes[palette] || D.palettes.oat;
    const map = { "#F4D9A6": pal.body, "#FFF5E1": pal.belly, "#E8876A": pal.accent };
    for (const n of root.querySelectorAll("*")) {
      for (const a of ["fill", "stroke"]) {
        const v = (n.getAttribute(a) || "").toUpperCase();
        if (map[v]) n.setAttribute(a, map[v]);
      }
    }
    root.querySelectorAll("#blush").forEach((n) => n.setAttribute("fill", pal.cheek));
  }

  /** The composed SVG markup for one look and frame. */
  function svg(o) {
    // The canvas's default Hush: an oat blob with round eyes and a sprout.
    o = Object.assign({ shape: "blob", palette: "oat", topper: "leaf", expr: "auto" }, o);
    const body = D.poses[o.shape] ? o.shape : "blob";
    const poses = D.poses[body];
    const pose = poses[o.pose] ? o.pose : "stand";
    const key = JSON.stringify([body, pose, o.expr, o.palette, o.topper, o.head, o.face, o.neck, o.carry, o.buddy, o.lookx, o.looky]);
    if (cache.has(key)) return cache.get(key);

    const doc = parse(poses[pose]);
    // The real desktop draws these; on the page they'd be props floating in space.
    doc.querySelectorAll("#screen-edge, #prop-cursor, #prop-window, #prop-command-box").forEach((n) => n.remove());
    const r = rig(body);
    const root = doc.querySelector("#pose-root");

    const topper = root && root.querySelector("#topper");
    if (topper) {
      topper.replaceChildren();
      const t = o.topper && o.topper !== "none" && r.querySelector("#topper-" + o.topper);
      if (t) { const n = t.cloneNode(true); n.removeAttribute("opacity"); topper.appendChild(n); }
    }

    let face = root && root.querySelector("#face");
    const faces = D.expressions[body];
    if (o.expr && o.expr !== "auto" && faces[o.expr] && face) {
      const nf = parse(faces[o.expr]).querySelector("#face");
      if (nf) { face.replaceWith(nf); face = nf; }
    }

    const acc = root && root.querySelector("#accessory");
    if (acc) acc.replaceChildren();
    const grounded = !EDGE_POSES.has(pose) && !/perch/i.test(pose);
    for (const slot of ["head", "face", "neck", "carry", "buddy"]) {
      const piece = D.wear[o[slot]];
      if (!piece) continue;
      for (const id of piece.layers) {
        const part = r.querySelector("#" + id);
        if (!part || (GROUND_WEAR.test(id) && !grounded)) continue;
        const n = part.cloneNode(true); n.removeAttribute("opacity");
        if (id === "pack-cape-back") root.insertBefore(n, root.firstChild);
        else if (FACE_WEAR.test(id)) { if (face) face.insertBefore(n, face.querySelector("#mouth")); }
        else if (acc) acc.appendChild(n);
      }
    }

    // Gaze: the eyes follow (lookx, looky), a few view units at most.
    const eyes = face && face.querySelector("#eyes");
    if (eyes && (o.lookx || o.looky)) eyes.setAttribute("transform", `translate(${+o.lookx || 0} ${+o.looky || 0})`);

    recolor(doc, o.palette || "oat");
    doc.removeAttribute("width");
    doc.removeAttribute("height");
    doc.setAttribute("aria-hidden", "true");
    doc.querySelectorAll("title").forEach((t) => t.remove());
    const out = serializer.serializeToString(doc);
    cache.set(key, out);
    if (cache.size > 400) cache.delete(cache.keys().next().value);
    return out;
  }

  /** Draw (or redraw) Hush into an element. `size` is the height in px; `grow` scales from the floor. */
  function draw(el, o) {
    const size = +o.size || 120;
    el.style.display = "inline-block";
    el.style.width = Math.round(size * 160 / 146) + "px";
    el.style.height = size + "px";
    el.style.lineHeight = "0";
    const grow = +o.grow || 1;
    el.style.transformOrigin = "50% 100%";
    el.style.transition = "transform .45s cubic-bezier(.34,1.4,.64,1)";
    el.style.transform = grow === 1 ? "" : `scale(${grow})`;
    const markup = svg(o);
    if (el._hush !== markup) { el.innerHTML = markup; el._hush = markup; }
    const s = el.firstElementChild;
    if (s) { s.style.width = "100%"; s.style.height = "100%"; s.style.overflow = "visible"; }
  }

  function readSpec(el) {
    const o = {};
    for (const part of (el.getAttribute("data-hush") || "").split(";")) {
      const [k, v] = part.split(":").map((x) => x && x.trim());
      if (k) o[k] = v;
    }
    return o;
  }

  function mountAll(scope) {
    (scope || document).querySelectorAll("[data-hush]").forEach((el) => draw(el, readSpec(el)));
  }

  window.Hush = { svg, draw, mountAll, readSpec, wear: D.wear };
})();
