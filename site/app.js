// Hush landing page, the loud version. Behaviour follows the design handoff's motion spec: six sections, the
// scroll-driven flood, a pinned small Hush, and every dynamic element with its Reduce Motion version.
// Every Hush on the page is drawn by hush.js from the app's own character pack. One requestAnimationFrame loop
// (frame()) does the scroll, pointer and drawing work; timers only change state and ask for a frame.
// No analytics, no cookies, no third-party requests.
(function () {
  // Links. The waitlist stays inert (no request is made) until waitlistURL is set.
  const REPO = "https://github.com/adityasshekhawat/hush";
  const CONFIG = {
    github: REPO,
    changelog: REPO + "/blob/main/CHANGELOG.md",
    stars: REPO + "/stargazers",
    showAndTell: REPO + "/discussions/categories/show-and-tell",
    privacy: REPO + "#what-leaves-your-mac",
    waitlistURL: "",
    install: "git clone " + REPO + ".git && cd hush && ./scripts/bundle.sh",
    update: "cd hush && git pull --ff-only && ./scripts/bundle.sh",
  };

  const $ = (id) => document.getElementById(id);
  const el = (tag, props, ...kids) => {
    const n = document.createElement(tag);
    for (const [k, v] of Object.entries(props || {})) {
      if (k === "style") n.setAttribute("style", v);
      else if (k.startsWith("on")) n.addEventListener(k.slice(2), v);
      else if (v !== undefined && v !== null && v !== false) n.setAttribute(k, v === true ? "" : v);
    }
    for (const kid of kids.flat()) if (kid != null) n.append(kid.nodeType ? kid : document.createTextNode(kid));
    return n;
  };
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const mq = matchMedia("(prefers-reduced-motion: reduce)");
  let reduced = mq.matches;
  const pad = (n) => (n < 10 ? "0" : "") + n;
  const hhmm = (minAgo) => { const d = new Date(Date.now() - minAgo * 60000); return pad(d.getHours()) + ":" + pad(d.getMinutes()); };

  // ---------- links and copy targets ----------
  document.querySelectorAll("[data-link]").forEach((a) => {
    a.setAttribute("href", CONFIG[a.dataset.link] || "#");
    a.rel = "noopener";
  });
  document.querySelectorAll("[data-install]").forEach((c) => { c.textContent = CONFIG[c.dataset.install || "install"]; });

  // ---------- page state ----------
  const SEL_KEYS = ["shape", "palette", "topper", "head", "face", "neck", "carry"];
  const S = {
    customized: false, name: "",
    sel: { shape: "blob", palette: "oat", topper: "leaf", head: "none", face: "none", neck: "none", carry: "none" },
    learned: [], puff: false, dozing: false, blink: false, glance: null, typing: false, fast: false,
    sec: "hero", past: false, rare: null, tuned: false,
  };
  const T = {}; // named timers
  const later = (name, ms, fn) => { clearTimeout(T[name]); T[name] = setTimeout(fn, ms); };

  // ---------- dimensions ----------
  const D = { W: 1440, H: 900, VH: 900, phone: false };
  function measure() {
    D.W = document.documentElement.clientWidth || innerWidth;
    D.H = innerHeight;
    D.phone = D.W < 700;
    D.VH = Math.min(D.H, D.phone ? 844 : 900);
    document.documentElement.style.setProperty("--vh", D.VH + "px");
  }
  measure();
  const peekDrop = (size) => Math.round(size * 34 / 146);
  const EDGE = new Set(["peek", "hide", "dive"]);

  // ---------- the loop ----------
  let rafId = 0, scrollDirty = true, lookDirty = false;
  const invalidate = () => { if (!rafId) rafId = requestAnimationFrame(frame); };

  // ---------- Hush actors ----------
  // An actor is one Hush on the page: its base pose (from the section's state), a frame sequence that overrides it
  // for a moment, where the eyes look, and how it leans or is dragged.
  const actors = {};
  class Actor {
    constructor(key, opts) {
      this.key = key;
      this.wrap = document.querySelector(`[data-actor="${key}"]`);
      this.char = this.wrap.querySelector(".hchar");
      this.o = opts;
      this.ov = null;     // sequence override {pose, expr, lx, ly}
      this.timers = [];
      this.look = null;   // {x, y, lean}
      this.drag = null;   // {dx, dy, rot}
      actors[key] = this;
    }
    play(frames, done) {
      this.timers.forEach(clearTimeout);
      this.timers = [];
      let at = 0;
      frames.forEach((f, i) => {
        this.timers.push(setTimeout(() => {
          this.ov = f.pose ? { pose: f.pose, expr: f.expr || "auto", lx: f.lx, ly: f.ly } : null;
          if (f.status !== undefined && this.o.onStatus) this.o.onStatus(f.status);
          invalidate();
          if (i === frames.length - 1 && done) done();
        }, at));
        at += f.ms || 0;
      });
    }
    props() {
      const base = this.o.base();
      const outfit = Object.assign({}, S.sel, this.o.outfit ? this.o.outfit() : {});
      let pose = this.ov ? this.ov.pose : base.pose;
      let expr = this.ov ? this.ov.expr : (base.expr || "auto");
      const L = this.look, g = S.glance;
      let lx = this.ov && this.ov.lx !== undefined ? this.ov.lx : (L ? L.x : (g ? g.x : 0));
      let ly = this.ov && this.ov.ly !== undefined ? this.ov.ly : (base.ly !== undefined && !this.ov ? base.ly : (L ? L.y : (g ? g.y : 0)));
      if (S.puff && this.o.puffs) { pose = "puff"; expr = "puff"; }
      if (S.dozing && !this.ov && this.o.dozes !== false) {
        if (base.pose === "peek" || this.key === "hero") expr = "sleepy";
        else { pose = "doze"; expr = "sleepy"; }
      }
      if (S.blink && !S.dozing && (expr === "auto" || expr === "neutral") && ["stand", "peek", "sit", "hold", "perk", "bow"].includes(pose)) expr = "sleepy";
      if (this.o.force) Object.assign(outfit, this.o.force(pose) || {});
      if (outfit.pose) pose = outfit.pose;
      return Object.assign(outfit, { pose, expr, lookx: lx, looky: ly, size: this.o.size(), grow: this.o.grow ? this.o.grow() : 1 });
    }
    render() {
      const p = this.props();
      Hush.draw(this.char, p);
      if (this.o.place) {
        const css = this.o.place(p);
        if (css !== this._place) { this.wrap.style.cssText = css; this._place = css; }
      }
      const lean = reduced || !this.look ? 0 : this.look.lean;
      const dr = this.drag;
      const tr = dr ? `translate(${Math.round(dr.dx)}px, ${Math.round(dr.dy)}px) rotate(${dr.rot}deg)` : `rotate(${lean}deg)`;
      this.wrap.style.transition = dr ? "none" : "transform .5s cubic-bezier(.34,1.56,.64,1), bottom .6s cubic-bezier(.2,.8,.2,1)";
      this.wrap.style.transform = tr;
    }
  }
  const growNow = () => Math.min(1.8, 1 + S.learned.filter((l) => !l.crossed).length * 0.12);
  const centred = (size) => `margin-left: ${Math.round(-size * 0.548)}px; left: 50%;`;

  // ---------- 1 hero ----------
  const heroSize = () => Math.round(D.phone ? D.W * 0.98 : Math.min(D.VH * 0.98, D.W * 0.56, 860));
  new Actor("hero", {
    base: () => ({ pose: "peek" }),
    outfit: () => ({ shape: "blob", palette: "oat", topper: "leaf", head: "none", face: "none", neck: "none", carry: "none" }),
    size: heroSize, puffs: true,
    place: (p) => `position: absolute; z-index: 1; bottom: ${EDGE.has(p.pose) ? -peekDrop(p.size) : 0}px; ` + (D.phone ? centred(p.size) : `right: ${Math.round(D.W * 0.03)}px;`),
  });

  const h1 = $("hero-h1");
  ["The", "companion", "that", "knows", "when", "not", "to."].forEach((w, i) => {
    const s = el("span", { "aria-hidden": "true", class: reduced ? "" : "w", style: reduced ? "" : `animation-delay: ${i * 85}ms` }, w);
    h1.append(s, i < 6 ? " " : "");
  });

  // ---------- 2 the flood ----------
  const NOISE = [
    ["Slack", "#4A154B", "#", "#random", "Ana: who took the last oat milk"],
    ["Mail", "#2F7BF6", "✉", "Notion", "What’s new in Notion this week"],
    ["Calendar", "#FFFFFF", "17", "Invite: Q4 offsite sync", "Thu 15:00 · from Rahul"],
    ["GitHub", "#24292F", "GH", "You were mentioned in #482", "Can you take a look before Friday?"],
    ["Mail", "#2F7BF6", "✉", "Figma", "Your Config recap is here"],
    ["Slack", "#4A154B", "#", "#design", "Sam: new icon round is in the file"],
    ["Messages", "#34C759", "…", "Weekend plans", "Leo: who’s in for Saturday"],
    ["Linear", "#5E6AD2", "L", "3 issues assigned to you", "Cycle 42 ends tomorrow"],
    ["LinkedIn", "#0A66C2", "in", "12 people viewed your profile", "See who’s looking"],
    ["App Store", "#1C8CF6", "A", "4 updates available", "Update now or tonight"],
    ["Mail", "#FF6719", "S", "The Sunday read", "Five long reads for your week"],
    ["Slack", "#4A154B", "#", "#general", "Reminder: fill in the survey"],
    ["Calendar", "#FFFFFF", "17", "Updated: design crit", "Moved to Wednesday 11:00"],
    ["Mail", "#111111", "U", "Your receipt from Uber", "Thanks for riding"],
    ["Spotify", "#1DB954", "♪", "New episode", "From a show you follow"],
    ["GitHub", "#24292F", "GH", "CI passed on main", "All checks have passed"],
    ["Slack", "#4A154B", "#", "Jon", "quick q when you have a sec"],
    ["Mail", "#E8876A", "%", "48 hours left", "30% off everything"],
    ["Notion", "#FFFFFF", "N", "Ana commented on Roadmap", "“Should this move to Q1?”"],
    ["Zoom", "#2D8CFF", "Z", "Recording is ready", "Weekly sync · 42 min"],
    ["Mail", "#111111", "M", "Weekly digest", "Stories picked for you"],
    ["Slack", "#4A154B", "#", "#random", "Leo shared a gif"],
    ["Calendar", "#FFFFFF", "17", "Reminder: dentist", "Next Tuesday 09:30"],
    ["GitHub", "#24292F", "GH", "dependabot opened 3 PRs", "Bump 3 packages"],
    ["Mail", "#2F7BF6", "✉", "Out for delivery", "Your package arrives today"],
    ["Slack", "#4A154B", "#", "#eng", "Deploy freeze starts Friday"],
    ["Duolingo", "#58CC02", "D", "Your streak misses you", "Five minutes today?"],
    ["Mail", "#2F7BF6", "✉", "Webinar invitation", "Growth loops that work"],
    ["Slack", "#4A154B", "#", "8 new replies", "In a thread you follow"],
    ["Figma", "#1E1E1E", "F", "Sam invited you", "Hush icons v3"],
    ["Calendar", "#FFFFFF", "17", "Rahul is out of office", "Back on Monday"],
    ["GitHub", "#24292F", "GH", "New star on hush", "Someone starred your repo"],
    ["Slack", "#4A154B", "#", "Poll", "Lunch at 1?"],
    ["Mail", "#E8876A", "%", "Your trial ends in 3 days", "Keep your plan"],
    ["Mail", "#FF6719", "S", "New post", "Notes on quiet software"],
    ["Slack", "#4A154B", "#", "#random", "Who’s bringing cake"],
  ];
  const ENV = [
    ["Calendar", "#FFFFFF", "17", "Standup in 2 minutes", "Room 3 · Priya, Sam, Rahul", "a meeting in 2 minutes"],
    ["Mail", "#2F7BF6", "✉", "Priya · Q3 budget", "Needs your sign-off by Friday", "Priya is a VIP"],
    ["Claude Code", "#FFEBD1", "!", "Claude needs you in site", "Waiting for a permission prompt", "Claude needs you"],
    ["Claude Code", "#DDF3E4", "✓", "Claude finished in hush", "Ran for 4 min · Terminal", "Claude finished"],
  ];
  const TICKER = ["Newsletter from Notion", "#random", "Promo from Figma", "LinkedIn", "App Store updates", "Duolingo", "#general survey", "The Sunday read", "dependabot", "Uber receipt", "Webinar invitation", "8 replies in a thread"];
  const iconStyle = (app, bg) => `background: ${bg}; color: ${bg === "#FFFFFF" ? (app === "Calendar" ? "#E5484D" : "#16141B") : (bg === "#FFEBD1" || bg === "#DDF3E4" ? "#1D1B22" : "#FFFFFF")}`;
  const rnd = (i, k) => { const x = Math.sin(i * 127.1 + k * 311.7) * 43758.5453; return x - Math.floor(x); };

  const F = { tS: 2, tN: 20, tM: 4, floodP: 0, autoT0: null, autoP: null, flung: {}, cd: null, why: -1, cards: [], envs: [], count: -1, fallen: 0, pose: "peek" };
  const fSize = () => Math.round(D.phone ? Math.min(D.VH * 0.42, D.W * 0.78) : Math.min(D.VH * 0.5, 440));
  const held = () => 3 + 16 * F.tS + F.tN + 2 * F.tM;
  const shownN = () => Math.min(8, 2 + Math.ceil(F.tM / 2));
  const floodP = () => {
    let p = F.autoP !== null ? F.autoP : F.floodP;
    if (reduced && F.floodP > 0.05) p = 1;
    return p;
  };

  new Actor("flood", {
    base: () => {
      const p = floodP();
      if (p >= 0.5) return { pose: "hold", expr: p >= 0.8 ? "happy" : "auto" };
      if (p >= 0.45) return { pose: "stand", expr: "alert" };
      if (p > 0.08) return { pose: "peek", expr: p > 0.3 ? "surprised" : "auto", ly: -2 };
      return { pose: "peek" };
    },
    outfit: () => (S.customized ? {} : { palette: "oat" }),
    size: fSize,
    place: (p) => `position: absolute; z-index: 5; ${centred(p.size)} bottom: ${p.pose === "peek" ? -peekDrop(p.size) + 40 : 40}px;`,
  });

  function buildFlood() {
    const cat = (n) => (n[0] === "Slack" ? "slack" : (n[0] === "Calendar" || n[0] === "Zoom") ? "meet" : n[0] === "Mail" ? "news" : "other");
    const pool = NOISE.filter((n) => { const c = cat(n); return !((c === "slack" && F.tS === 0) || (c === "news" && F.tN === 0) || (c === "meet" && F.tM === 0)); });
    const N = Math.min(D.phone ? 22 : 36, pool.length);
    const box = $("f-cards");
    box.replaceChildren();
    F.flung = {}; F.count = -1;
    F.cards = pool.slice(0, N).map((n, i) => {
      const node = el("div", { class: "ncw", "aria-hidden": "true" },
        el("div", { class: "nc" },
          el("div", { class: "nch" }, el("span", { class: "nci", style: iconStyle(n[0], n[1]) }, n[2]), el("span", {}, n[0]), el("span", { class: "nct" }, hhmm(N - i + 3))),
          el("div", { class: "ncti" }, n[3]), el("div", { class: "ncb" }, n[4])));
      node.addEventListener("pointerdown", (e) => { e.preventDefault(); F.cd = { i, x: e.clientX, y: e.clientY, dx: 0, dy: 0 }; node.classList.add("drag"); });
      box.append(node);
      return { node, i, N, a: 0.06 + 0.36 * Math.sqrt(i / N), f: 0.5 + 0.28 * Math.pow(i / N, 0.7), t: (rnd(i, 3) - 0.5) * 22, last: "" };
    });
    const row = $("env-row");
    row.replaceChildren();
    const list = ENV.filter((e, j) => !(j === 0 && F.tM === 0)).slice(0, shownN());
    F.envs = list.map((e, j) => {
      const slot = el("div", { class: "env-slot" });
      row.append(slot);
      return { slot, e, j, on: false, btn: null };
    });
    F.more = el("div", { class: "more", hidden: true }, "");
    row.append(F.more);
    document.querySelectorAll("[data-shown]").forEach((n) => { n.textContent = shownN(); });
    document.querySelectorAll("[data-held]").forEach((n) => { n.textContent = held(); });
    $("tuned").hidden = !S.tuned;
  }

  function envButton(env) {
    const [app, bg, glyph, title, body, why] = env.e;
    const open = F.why === env.j;
    const btn = el("button", { type: "button", class: "settle", "aria-expanded": String(open), onclick: () => { F.why = F.why === env.j ? -1 : env.j; F.envs.forEach(refreshEnv); } },
      el("span", { class: "nc" },
        el("span", { class: "nch" }, el("span", { class: "nci", style: iconStyle(app, bg) }, glyph), el("span", {}, app), el("span", { class: "nct" }, hhmm(env.j))),
        el("span", { class: "ncti" }, title), el("span", { class: "ncb" }, body),
        el("span", { class: "why", hidden: !open }, "Got through: " + why)));
    return btn;
  }
  function refreshEnv(env) {
    if (!env.btn) return;
    const open = F.why === env.j;
    env.btn.setAttribute("aria-expanded", String(open));
    env.btn.querySelector(".why").hidden = !open;
  }

  function renderFlood() {
    const p = floodP();
    const W = D.W, VH = D.VH, cardW = D.phone ? 230 : 300, fs = fSize();
    const hushX = W / 2, hushY = VH - fs * 0.45;
    let fallen = 0;
    for (const c of F.cards) {
      const { i, N } = c;
      const x = 16 + rnd(i, 1) * (W - cardW - 32);
      const y = 40 + (1 - i / N) * VH * 0.5 + rnd(i, 2) * VH * 0.16;
      const fl = F.flung[i];
      const gone = p >= c.f || !!fl;
      if (gone) fallen++;
      let tr, op = 1, trn = "transform .55s cubic-bezier(.2,.8,.2,1), opacity .4s ease";
      if (fl) { tr = `translate(${Math.round(x + fl.dx)}px, ${Math.round(y + fl.dy)}px) rotate(${Math.round(c.t + fl.dx / 12)}deg)`; op = 0; }
      else if (p < c.a) { tr = `translate(${Math.round(x)}px, ${Math.round(y - 50)}px) rotate(${c.t}deg) scale(.9)`; op = 0; }
      else if (gone) { tr = `translate(${Math.round(hushX - cardW / 2)}px, ${Math.round(hushY)}px) rotate(0deg) scale(.22)`; op = 0; }
      else if (F.cd && F.cd.i === i) { tr = `translate(${Math.round(x + F.cd.dx)}px, ${Math.round(y + F.cd.dy)}px) rotate(${Math.round(c.t + F.cd.dx / 14)}deg)`; trn = "none"; }
      else tr = `translate(${Math.round(x)}px, ${Math.round(y)}px) rotate(${c.t}deg)`;
      if (reduced && !(F.cd && F.cd.i === i)) trn = "opacity .15s linear";
      const live = op === 1;
      const css = `width: ${cardW}px; z-index: ${gone ? 1 : 10 + i}; opacity: ${op}; transform: ${tr}; transition: ${trn}; pointer-events: ${live ? "auto" : "none"}`;
      if (css !== c.last) { c.node.style.cssText = css; c.last = css; }
    }
    // The counter climbs with the cards that fall behind Hush (flung ones count too) and lands on the total.
    const count = Math.round(held() * fallen / Math.max(1, F.cards.length));
    if (count !== F.count) {
      const n = $("counter");
      n.textContent = count;
      if (!reduced && F.count >= 0) { n.classList.remove("bumpA", "bumpB"); n.classList.add(count % 2 ? "bumpA" : "bumpB"); }
      F.count = count;
    }
    F.envs.forEach((env) => {
      const on = p >= 0.8 + env.j * 0.03;
      if (on && !env.btn) { env.btn = envButton(env); env.slot.append(env.btn); }
      if (!on && env.btn) { env.btn.remove(); env.btn = null; }
    });
    const more = shownN() - F.envs.length;
    F.more.textContent = "+" + more + " more that mattered";
    F.more.hidden = !(more > 0 && p >= 0.9);
    $("env-row").style.top = Math.round(VH * (D.phone ? 0.47 : 0.4)) + "px";
    $("f-intro").classList.toggle("off", p >= 0.42);
    $("f-tune").classList.toggle("off", p >= 0.06);
    $("f-counter").classList.toggle("off", p < 0.48);
    $("f-line").classList.toggle("off", p < 0.92);
    $("f-end").classList.toggle("off", p < 0.96);
    $("f-play").classList.toggle("off", p >= 0.96);
    $("f-play").textContent = F.autoP !== null ? "Replay the flood" : "Play it for me";
  }

  // Steppers: "how loud is your day?"
  const TUNE = [["tS", "Slack or Teams workspaces", 1, 6], ["tN", "Newsletters and promos a day", 5, 80], ["tM", "Meetings a day", 1, 12]];
  function renderTune() {
    $("tune-rows").replaceChildren(...TUNE.map(([k, label, step, max]) => {
      const set = (v) => { F[k] = clamp(v, 0, max); S.tuned = true; F.autoP = null; F.autoT0 = null; F.why = -1; buildFlood(); renderTune(); invalidate(); };
      return el("div", { class: "trow" }, el("span", {}, label),
        el("div", { class: "stepper" },
          el("button", { type: "button", class: "btn", "aria-label": "Fewer: " + label, onclick: () => set(F[k] - step) }, "−"),
          el("span", { class: "big", "aria-live": "polite" }, String(F[k])),
          el("button", { type: "button", class: "btn", "aria-label": "More: " + label, onclick: () => set(F[k] + step) }, "+")));
    }));
  }
  function playFlood() {
    F.flung = {}; F.why = -1;
    F.envs.forEach((e) => { if (e.btn) { e.btn.remove(); e.btn = null; } });
    if (reduced) { F.autoP = 1; F.autoT0 = null; invalidate(); return; }
    F.autoT0 = performance.now(); F.autoP = 0;
    invalidate();
  }
  document.querySelectorAll("[data-play]").forEach((b) => b.addEventListener("click", playFlood));
  $("retune").addEventListener("click", () => {
    F.autoP = null; F.autoT0 = null; F.flung = {};
    const sec = $("flood");
    scrollTo({ top: scrollY + sec.getBoundingClientRect().top, behavior: reduced ? "auto" : "smooth" });
    invalidate();
  });
  $("ticker").append(...TICKER.concat(TICKER).map((t) => el("span", {}, t + " · ", el("b", {}, "held"))));
  $("now-label").textContent = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][new Date().getDay()] + " " + hhmm(0);

  // ---------- 3 try it ----------
  const STEPS = [
    { title: "Say hello.", body: "Click Hush. Go on. Press and hold for a pat, or click it a lot and see what happens." },
    { title: "Pick it up.", body: "Press on Hush and drag, like you would across your screen." },
    { title: "Get to work.", body: "Type anything in the document. Watch what Hush does, then stop typing." },
    { title: "Something arrives.", body: "Claude finished a job while you were busy. Hush holds up an envelope. Open it, save it for later, or teach Hush not to bother you with these." },
    { title: "Ask it anything.", body: "In the app this is ⌘⇧H. Type, and watch the chip pick a route. Try one of the examples." },
    { title: "See what it learned.", body: "Every line here is something Hush picked up from you. Click one to cross it out, and Hush forgets it." },
  ];
  const CHIP = {
    quick: { label: "⚡ answer here", style: "background: #F1ECFB; color: #5B47A8" },
    repo: { label: "‹/› ask about hush", style: "background: #ECEAF0; color: #2D2A35" },
    hand: { label: "↗ open in Claude", style: "background: #FBE1D8; color: #9A3E22" },
    web: { label: "🧭 plan it", style: "background: #E1ECFD; color: #1F5FBF" },
  };
  const ANSWERS = {
    quick: { lane: "⚡ Quick", mono: true, body: '=SUMIF(B:B,"Paid",C:C)', act: "Paste in Excel", act2: "Copy", foot: "From Excel", rc: "Copied. Press ⌘V in Excel." },
    repo: { lane: "‹/› hush", body: "CardPlacement.swift works it out from Hush’s frame: a 14 pt gap, 16 pt of headroom and room for the hover rise, then it keeps the card on screen.", act: "Ask Cursor", act2: "Copy", foot: "Read-only · nothing changed", rc: "Opened in Cursor. Review the prompt there." },
    hand: { lane: "↗ Claude", body: "Opened in Claude with your question filled in. Pick it up there.", act: "Copy question", act2: "Close", foot: "Your question is waiting there", rc: "Copied." },
    web: { lane: "🧭 Browser task", plan: true, act: "Run it ⌘⏎", act2: "Cancel", foot: "Runs in Comet · beta", rc: "Running in Comet. I’ll ask before sharing." },
  };
  const LEARN_ASK = { quick: "Answers in Excel come as formulas.", repo: "Code questions go to my repo.", hand: "Long writing goes to Claude.", web: "Browser tasks show me a plan first." };
  const SUGGEST = ["sum of column C where B is Paid", "where do we place cards in hush", "help me write a thoughtful note to my landlord", "make a google sheet of 12, 40, 7"];
  const tut = { step: 0, env: "none", askText: "", asked: "", receipt: "", status: "" };
  let tutTyping = false;

  const tutSize = () => Math.round((D.phone ? Math.min(D.W * 0.62, 300) : Math.min(D.VH * 0.5, 420)) * (tut.step === 3 || tut.step === 4 ? 0.8 : 1));
  new Actor("tut", {
    base: () => ({ pose: "stand" }),
    size: tutSize, grow: growNow,
    place: (p) => `position: absolute; bottom: ${EDGE.has(p.pose) ? -peekDrop(p.size) : 0}px; ${centred(p.size)}`,
    onStatus: (s) => { tut.status = s; $("tut-status").textContent = s; $("tut-status").hidden = !s; },
  });

  const route = (q) => {
    const t = (q || "").toLowerCase();
    if (/sheet|browser|book a|order|fill/.test(t)) return "web";
    if (/repo|code|function|bug|where do we|hush/.test(t)) return "repo";
    if (/write|draft|essay|letter|email|thoughtful/.test(t)) return "hand";
    return "quick";
  };
  function learn(key, text) {
    if (S.learned.some((l) => l.key === key)) return;
    S.learned.push({ key, text, crossed: false });
    renderNotebook(); invalidate();
  }
  function renderNotebook() {
    const list = $("nb-list");
    list.replaceChildren();
    if (!S.learned.length) { list.append(el("div", { class: "nb-empty" }, "Nothing yet. Say hello.")); return; }
    S.learned.forEach((l) => list.append(el("button", {
      type: "button", class: "nb-item", "aria-pressed": String(l.crossed), "aria-label": (l.crossed ? "Restore: " : "Cross out: ") + l.text,
      onclick: () => { l.crossed = !l.crossed; renderNotebook(); actors.tut.play([{ pose: "listen", ms: 500 }, { pose: "stand", expr: "happy", ms: 700 }, { pose: "stand" }]); invalidate(); },
    }, l.text)));
  }
  function renderTutSide() {
    $("tut-chips").replaceChildren(...STEPS.map((s, i) => el("button", {
      type: "button", role: "tab", class: "pill", "aria-selected": String(i === tut.step), onclick: () => go(i),
    }, (i + 1) + " " + s.title.replace(".", ""))));
    $("tut-n").textContent = `Step ${tut.step + 1} of 6`;
    $("tut-title").textContent = STEPS[tut.step].title;
    $("tut-body").textContent = STEPS[tut.step].body;
    $("tut-fling").hidden = tut.step !== 1;
    $("tut-next").textContent = tut.step === 5 ? "Start over" : "Next";
    $("tut-btn").setAttribute("aria-label", { 0: "Poke Hush", 1: "Pick up Hush", 5: "Poke Hush" }[tut.step] || "Hush");
  }
  function renderOverlay() {
    const box = $("tut-overlay");
    box.replaceChildren();
    if (tut.step === 2) {
      const area = el("textarea", { id: "hush-editor", rows: "4", placeholder: "Start typing anything…", oninput: typed });
      box.append(el("div", { class: "ov doc-field" }, el("label", { for: "hush-editor" }, "Your document"), area));
    }
    if (tut.step === 3 && tut.env !== "none") {
      const titles = { arrived: "Claude finished in hush", open: "Opening Terminal…", never: "Got it. I’ll hold these back.", later: "Saved for later." };
      const subs = { arrived: "Ran for 4m · Terminal", open: "Jumping to where it ran.", never: "“Agent finishes can wait.” · Undo", later: "It’ll be in the panel when you want it." };
      const card = el("div", { class: "card ov", style: "width: min(340px, 80%)" },
        el("div", { class: "ch" }, el("span", { class: "icon", style: "background: #DDF3E4; color: #1E7A3C" }, "✓"), el("span", {}, "Claude Code · hush"), el("span", { class: "ml" }, "16:02")),
        el("div", { class: "ct" }, titles[tut.env]), el("div", { class: "cs" }, subs[tut.env]));
      if (tut.env === "arrived") card.append(el("div", { class: "ca" },
        el("button", { type: "button", class: "pl", onclick: () => envAct("open") }, "Open"),
        el("button", { type: "button", class: "pl s", onclick: () => envAct("never") }, "Not this kind again"),
        el("button", { type: "button", class: "pl q ml", onclick: () => envAct("later") }, "Later")));
      else card.append(el("div", { style: "height: 12px" }));
      box.append(card);
    }
    if (tut.step === 4 && !tut.asked) {
      const chip = el("span", { class: "route-chip" });
      const input = el("input", {
        id: "hush-ask", type: "text", autocomplete: "off", placeholder: "Ask Hush…", value: tut.askText,
        oninput: (e) => { tut.askText = e.target.value; setChip(); },
        onkeydown: (e) => { if (e.key === "Enter") { e.preventDefault(); ask(e.target.value); } },
      });
      const setChip = () => { const c = CHIP[route(input.value)]; chip.textContent = c.label; chip.setAttribute("style", c.style); };
      setChip();
      box.append(el("div", { class: "ov ask-wrap" },
        el("div", { class: "card ask-box" }, el("label", { for: "hush-ask", class: "sr-only" }, "Ask Hush"), input, chip),
        el("div", { class: "row", style: "gap: 6px" }, SUGGEST.map((t) => el("button", { type: "button", class: "suggest", onclick: () => ask(t) }, t)))));
    }
    if (tut.step === 4 && tut.asked) {
      const a = ANSWERS[tut.asked];
      const card = el("div", { class: "card ov", style: "width: min(400px, 86%)" },
        el("div", { class: "ch" }, el("span", { class: "route-chip small", style: CHIP[tut.asked].style }, a.lane), el("span", {}, tut.asked === "web" ? "Plan ready" : "Done")),
        el("div", { style: "font-size: 12.5px; color: #6E6878; padding: 0 14px" }, tut.askText));
      if (a.mono) card.append(el("div", { class: "mono" }, a.body));
      else if (a.plan) card.append(el("div", { style: "padding: 6px 14px 0; display: flex; flex-direction: column; gap: 5px; font-size: 13px" },
        el("div", {}, "1 · Open sheets.google.com"), el("div", {}, "2 · Type 12, 40 and 7 into A1 to A3"),
        el("div", {}, "3 · Share it with Sam ", el("span", { class: "ask-tag" }, "asks first"))));
      else card.append(el("div", { style: "font-size: 13.5px; line-height: 1.5; padding: 8px 14px 0" }, a.body));
      card.append(el("div", { class: "ca" },
        el("button", { type: "button", class: "pl", onclick: () => { tut.receipt = a.rc; renderOverlay(); actors.tut.play([{ pose: "wave", expr: "happy", ms: 1000 }, { pose: "sit", expr: "happy" }]); } }, a.act),
        el("button", { type: "button", class: "pl s", onclick: () => { tut.asked = ""; tut.receipt = ""; tut.askText = ""; renderOverlay(); actors.tut.play([{ pose: "sitListen", ly: -2.2 }]); } }, a.act2)));
      if (tut.receipt) card.append(el("div", { class: "rc" }, "✓ " + tut.receipt));
      card.append(el("div", { class: "cf" }, a.foot));
      box.append(card);
    }
  }
  function go(i) {
    clearTimeout(T.tutIdle); clearTimeout(T.ask); tutTyping = false;
    Object.assign(tut, { step: i, env: "none", asked: "", receipt: "", askText: "" });
    actors.tut.o.onStatus("");
    renderTutSide(); renderOverlay();
    const t = actors.tut;
    if (i === 3) t.play([{ pose: "stand", ms: 700 }, { pose: "hurry", expr: "alert", ms: 800 }, { pose: "hold", expr: "happy" }], () => { tut.env = "arrived"; renderOverlay(); });
    else if (i === 4) t.play([{ pose: "sitListen", ly: -2.2 }]);
    else if (i === 5) t.play([{ pose: "proud", expr: "happy", ms: 1400 }, { pose: "stand", expr: "happy" }]);
    else t.play([{ pose: "stand" }]);
    invalidate();
  }
  function ask(text) {
    const q = (text || "").trim();
    if (!q) return;
    const r = route(q);
    Object.assign(tut, { askText: q, asked: "", receipt: "" });
    actors.tut.play([
      { pose: "sitThink", expr: "thinking", ms: 1100, status: r === "repo" ? "Reading the repo…" : "Thinking…" },
      { pose: r === "hand" ? "wave" : "handOver", expr: "happy", ms: 1200, status: "" },
      { pose: "sit", expr: "happy" }]);
    later("ask", 1100, () => { tut.asked = r; renderOverlay(); learn("ask-" + r, LEARN_ASK[r]); });
  }
  function envAct(kind) {
    tut.env = kind; renderOverlay();
    const t = actors.tut;
    if (kind === "open") { t.play([{ pose: "wave", expr: "happy", ms: 1200 }, { pose: "stand" }]); learn("env-open", "Wants to know when Claude is done."); }
    if (kind === "never") { t.play([{ pose: "bow", expr: "happy", ms: 1200 }, { pose: "stand" }]); learn("env-never", "Agent finishes can wait."); }
    if (kind === "later") { t.play([{ pose: "stand", expr: "happy", ms: 800 }, { pose: "stand" }]); learn("env-later", "Later is usually fine."); }
  }
  function typed() {
    if (!tutTyping) {
      tutTyping = true;
      actors.tut.play([{ pose: "notice", ms: 250 }, { pose: "dive", ms: 220 }, { pose: "hide" }]);
      learn("focus", "Hides when you type.");
    }
    later("tutIdle", 1600, () => { tutTyping = false; actors.tut.play([{ pose: "peek", ms: 700 }, { pose: "stand", expr: "happy", ms: 800 }, { pose: "stand" }]); });
  }
  $("tut-fling").addEventListener("click", () => {
    actors.tut.play([{ pose: "grab", ms: 400 }, { pose: "swing", ms: 380 }, { pose: "land", ms: 220 }, { pose: "dizzy", ms: 1400 }, { pose: "shake", ms: 500 }, { pose: "stand", expr: "apologetic", ms: 1000 }, { pose: "stand" }]);
    learn("fling", "Don't fling me. (Fine, maybe once.)");
  });
  $("tut-next").addEventListener("click", () => go(tut.step === 5 ? 0 : tut.step + 1));
  $("tut-back").addEventListener("click", () => go(Math.max(0, tut.step - 1)));

  // ---------- poke, hold, drag (hero and tutorial) ----------
  let pd = null, pokes = [];
  function poke(key) {
    const a = actors[key], base = key === "hero" ? "" : "stand";
    const now = Date.now();
    pokes = pokes.filter((t) => now - t < 2000).concat([now]);
    if (pokes.length >= 4) {
      pokes = [];
      a.play([{ pose: "dizzy", expr: "dizzy", ms: 1400 }, { pose: "tapfoot", expr: "grumpy", ms: 1300 }, { pose: base }]);
      return;
    }
    a.play([{ pose: "poked", ms: 160 }, { pose: "giggle", expr: "happy", ms: 600 }, { pose: "wiggleL", ms: 220 }, { pose: "wiggleR", ms: 220 }, { pose: base, expr: "happy", ms: 800 }, { pose: base }]);
    if (key === "hero" && !reduced) { const h = $("top"); h.classList.add("squash"); later("squash", 170, () => h.classList.remove("squash")); }
    if (key === "tut" && (tut.step === 0 || tut.step === 5)) learn("hi", "Likes to say hi.");
  }
  function grabbable(key) {
    const btn = actors[key].wrap.querySelector(".hbtn");
    btn.addEventListener("pointerdown", (e) => {
      if (e.button > 0) return;
      pd = { key, x: e.clientX, y: e.clientY, lx: e.clientX, moved: false, held: false };
      later("hold", 450, () => { if (pd && !pd.moved) { pd.held = true; actors[key].play([{ pose: "pat", expr: "blissful" }]); } });
    });
    btn.addEventListener("click", (e) => { if (e.detail === 0) poke(key); }); // keyboard
  }
  grabbable("hero"); grabbable("tut");
  function dragMove(e) {
    if (!pd) return;
    const a = actors[pd.key];
    const dx = e.clientX - pd.x, dy = e.clientY - pd.y;
    if (!pd.moved && Math.hypot(dx, dy) > 10) { pd.moved = true; clearTimeout(T.hold); a.play([{ pose: "grab", expr: "surprised" }]); }
    if (pd.moved) {
      const vx = e.clientX - pd.lx; pd.lx = e.clientX;
      if (Math.abs(vx) > 14) a.play([{ pose: "swing", expr: "squint" }]);
      if (!reduced) a.drag = { dx, dy: Math.min(40, dy), rot: clamp(vx, -14, 14) };
      invalidate();
    }
  }
  function dragEnd(cancel) {
    const p = pd; pd = null; clearTimeout(T.hold);
    if (!p) return;
    const a = actors[p.key], base = p.key === "hero" ? "" : "stand";
    a.drag = null;
    if (cancel) { a.play([{ pose: base }]); invalidate(); return; }
    if (p.moved) {
      a.play([{ pose: "land", expr: "squint", ms: 240 }, { pose: "shake", expr: "squint", ms: 420 }, { pose: base }]);
      if (p.key === "tut") learn("fling", "Don't fling me. (Fine, maybe once.)");
    } else if (p.held) a.play([{ pose: base, expr: "happy", ms: 600 }, { pose: base }]);
    else poke(p.key);
    invalidate();
  }

  // ---------- 4 builders ----------
  new Actor("build", {
    base: () => ({ pose: "perk", expr: "alert" }),
    outfit: () => (S.customized ? {} : { palette: "lilac" }),
    size: () => (D.phone ? 200 : 280),
  });
  const MOMENTS = [
    { tag: "Typing", text: "You type. Hush ducks out of sight.", pose: "hide" },
    { tag: "Finished", text: "A Claude run finishes. Hush holds up an envelope.", pose: "hold", expr: "happy",
      card: ["background: #DDF3E4; color: #1E7A3C", "✓", "Claude Code · hush", "Claude finished in hush", "Ran for 4m · Terminal"] },
    { tag: "18:30", text: "Hush tucks the day in.", pose: "yawn", expr: "sleepy",
      card: ["background: #F1ECFB; color: #5B47A8", "☾", "Good evening", "You got 4 things from me today.", "I held back 63."] },
  ];
  let moment = 1;
  const frameSize = () => { const h = $("frame-screen").clientHeight || 300; return Math.round(h * 0.5); };
  new Actor("frame", {
    base: () => ({ pose: MOMENTS[moment].pose, expr: MOMENTS[moment].expr }),
    outfit: () => (S.customized ? {} : { palette: "oat" }),
    size: frameSize, dozes: false,
    place: (p) => `position: absolute; right: 12%; bottom: ${EDGE.has(p.pose) ? -peekDrop(p.size) : 0}px;`,
  });
  function renderMoments() {
    $("moments").replaceChildren(...MOMENTS.map((m, i) => el("button", {
      type: "button", role: "tab", class: "moment", "aria-selected": String(i === moment),
      onclick: () => { moment = i; renderMoments(); invalidate(); },
    }, el("b", {}, m.tag), " · " + m.text)));
    const m = MOMENTS[moment], card = $("frame-card");
    card.classList.toggle("off", !m.card);
    if (m.card) card.replaceChildren(
      el("div", { class: "ch" }, el("span", { class: "icon", style: m.card[0] }, m.card[1]), el("span", {}, m.card[2])),
      el("div", { class: "ct" }, m.card[3]), el("div", { class: "cs", style: "padding-bottom: 12px" }, m.card[4]));
  }

  // ---------- 5 make it yours ----------
  const GROUPS = [
    { key: "palette", label: "Colour", opts: [["oat", "Oat"], ["mint", "Mint"], ["lilac", "Lilac"], ["sky", "Sky"], ["rose", "Rose"], ["peach", "Peach"], ["matcha", "Matcha"], ["butter", "Butter"], ["berry", "Berry"]] },
    { key: "shape", label: "Body", opts: [["blob", "Round"], ["bean", "Tall"], ["square", "Square"]] },
    { key: "topper", label: "On top", opts: [["none", "Nothing"], ["leaf", "Sprout"], ["antenna", "Antenna"], ["ears", "Ears"]] },
    { key: "head", label: "Head", opts: [["none", "Nothing"], ["cap", "Cap"], ["capBack", "Backwards cap"], ["beanie", "Beanie"], ["bucket", "Bucket hat"], ["headphones", "Headphones"], ["crown", "Crown"], ["sweatband", "Sweatband"], ["hardHat", "Hard hat"], ["frogHat", "Frog hat"], ["bunny", "Bunny ears"], ["beret", "Beret"], ["flowerClip", "Flower clip"], ["wizard", "Wizard hat"], ["chef", "Chef's hat"], ["straw", "Straw hat"]] },
    { key: "face", label: "Face", opts: [["none", "Nothing"], ["glasses", "Glasses"], ["shades", "Shades"], ["pixelShades", "Pixel shades"], ["starGlasses", "Star glasses"]] },
    { key: "neck", label: "Neck", opts: [["none", "Nothing"], ["scarf", "Scarf"], ["bandana", "Bandana"], ["bowtie", "Bow tie"], ["chain", "Chain"], ["tie", "Tie"], ["lanyard", "Lanyard"], ["cape", "Cape"]] },
    { key: "carry", label: "Beside it", opts: [["none", "Nothing"], ["satchel", "Satchel"], ["laptop", "Laptop"], ["coffee", "Coffee"], ["plant", "Plant"], ["books", "Books"]] },
  ];
  const GBY = {}; GROUPS.forEach((g) => { GBY[g.key] = g; });
  const SWHEX = { oat: "#F4D9A6", mint: "#A8DBC4", lilac: "#C9BBEC", sky: "#A7CBEE", rose: "#F4B9B3", peach: "#F7C6A3", matcha: "#CFDDA6", butter: "#F6E39A", berry: "#DDB0D6" };
  const BGFOR = { oat: "#F4D9A6", butter: "#F4D9A6", rose: "#E8876A", peach: "#E8876A", mint: "#C6E8D2", matcha: "#C6E8D2", lilac: "#C9BBEC", berry: "#C9BBEC", sky: "#C9BBEC" };
  // Hints are the app's own (Sources/HushCore/RareFinds.swift).
  const RARE = [
    { hint: "Quiet mornings", shape: "blob", topper: "leaf", buddy: "bird", pose: "stand" },
    { hint: "A special day", shape: "bean", topper: "ears", head: "partyHat", carry: "balloon", pose: "cheer" },
    { hint: "Late nights", shape: "square", topper: "none", carry: "lantern", pose: "sit" },
    { hint: "A very quiet week", shape: "blob", topper: "none", head: "halo", pose: "proud" },
    { hint: "After lunch", shape: "bean", topper: "antenna", buddy: "snail", pose: "notice" },
    { hint: "The first warm day", shape: "blob", topper: "none", head: "flowerCrown", pose: "stand" },
    { hint: "8 more, still hidden", shape: "blob", topper: "leaf", pose: "hide" },
  ];
  let wtab = "palette";
  const petName = () => S.name.trim() || "Hush";
  const valLabel = (k) => { const o = GBY[k].opts.find((x) => x[0] === S.sel[k]); return o ? o[1] : ""; };
  const yoursSize = () => Math.round(D.phone ? Math.min(D.W * 0.78, 330) : Math.min(D.VH * 0.55, 480));
  new Actor("yours", { base: () => ({ pose: "stand", expr: "happy" }), size: yoursSize, grow: growNow });

  function renderTabs() {
    $("w-tabs").replaceChildren(...GROUPS.map((g) => g.key).concat(["secret"]).map((k) => el("button", {
      type: "button", role: "tab", class: "tab", "aria-selected": String(k === wtab), onclick: () => { wtab = k; renderTabs(); renderPanel(); },
    }, el("b", {}, k === "secret" ? "Secret" : GBY[k].label), el("small", {}, k === "secret" ? "14 hidden" : valLabel(k)))));
  }
  function pick(k, v) {
    S.sel[k] = v; S.customized = true;
    actors.yours.play([{ pose: "bob", expr: "happy", ms: 420 }, { pose: "stand", expr: "happy" }]);
    outfitChanged();
  }
  function renderPanel() {
    const panel = $("w-panel");
    panel.setAttribute("aria-label", wtab === "secret" ? "Secret pieces" : GBY[wtab].label);
    if (wtab === "palette") {
      panel.replaceChildren(el("div", { class: "swatches" }, GBY.palette.opts.map(([v, label]) => el("button", {
        type: "button", class: "sw", "aria-label": label, "aria-pressed": String(S.sel.palette === v), style: "background: " + SWHEX[v], onclick: () => pick("palette", v),
      }))));
    } else if (wtab === "secret") {
      panel.replaceChildren(el("div", { class: "secret" },
        el("div", {}, "14 pieces you can't pick. Hush finds them on its own. Hover one for a hint. Found one? Post it with #HushFound."),
        el("div", { class: "rare-grid" }, RARE.map((r) => {
          const art = el("span", { class: "rfs" });
          const s = el("span");
          art.append(s);
          Hush.draw(s, Object.assign({ palette: "oat", size: 92, expr: "auto" }, r));
          return el("button", { type: "button", class: "rf", "aria-label": "Secret piece. Hint: " + r.hint }, art, el("span", { class: "rfh" }, r.hint));
        }))));
    } else {
      panel.replaceChildren(el("div", { class: "opts" }, GBY[wtab].opts.map(([v, label]) => el("button", {
        type: "button", class: "pill", "aria-pressed": String(S.sel[wtab] === v), onclick: () => pick(wtab, v),
      }, label))));
    }
  }
  const shareLink = () => location.href.split("#")[0] + "#hush=" + encodeURIComponent(petName()) + "~" + SEL_KEYS.map((k) => S.sel[k]).join(".");
  const outfitLine = () => SEL_KEYS.map((k) => (S.sel[k] === "none" ? "" : valLabel(k))).filter(Boolean).join(" · ");
  function outfitChanged() {
    const name = petName();
    document.querySelectorAll("[data-pet]").forEach((n) => { n.textContent = name; });
    $("adopt").textContent = "Adopt " + name;
    $("join-btn").textContent = "Save " + name + " a spot";
    const bg = S.customized ? BGFOR[S.sel.palette] : "#E8876A";
    $("yours").style.backgroundColor = bg;
    const spot = document.querySelector(".spot"), ys = yoursSize();
    spot.style.cssText = `width: ${Math.round(ys * 1.15)}px; height: ${Math.round(ys * 0.32)}px; margin-left: ${Math.round(-ys * 0.575)}px;`;
    if (S.customized) {
      try { localStorage.setItem("hush-visitor", JSON.stringify(Object.assign({ name: S.name }, S.sel))); } catch (e) { /* storage off */ }
    }
    if (!$("adopt-card").hidden) renderAdoptCard();
    if (wtab !== "secret") renderPanel();
    renderTabs();
    invalidate();
  }
  function renderAdoptCard() {
    document.querySelector(".badge").style.background = S.customized ? BGFOR[S.sel.palette] : "#E8876A";
    Hush.draw($("card-char"), Object.assign({}, S.sel, { pose: "stand", expr: "happy", grow: growNow(), size: D.phone ? 128 : 200 }));
    $("outfit-line").textContent = outfitLine();
    $("hush-link").value = shareLink();
  }
  $("hush-name").addEventListener("input", (e) => { S.name = e.target.value; S.customized = true; outfitChanged(); });
  let flick = 0;
  $("surprise").addEventListener("click", () => {
    const pickAll = () => GROUPS.forEach((g) => { S.sel[g.key] = g.opts[Math.floor(Math.random() * g.opts.length)][0]; });
    const land = () => { pickAll(); S.customized = true; outfitChanged(); actors.yours.play([{ pose: "hop", expr: "happy", ms: 700 }, { pose: "stand", expr: "happy" }]); };
    clearInterval(flick);
    if (reduced) { land(); return; }
    let n = 0;
    flick = setInterval(() => { n++; pickAll(); invalidate(); if (n >= 8) { clearInterval(flick); land(); } }, 70);
  });
  let adoptNo = "";
  $("adopt").addEventListener("click", () => {
    adoptNo = adoptNo || String(1000 + Math.floor(Math.random() * 9000));
    S.customized = true;
    const now = new Date();
    $("adopt-no").textContent = adoptNo;
    $("adopt-date").textContent = now.getDate() + " " + ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][now.getMonth()] + " " + now.getFullYear();
    const wrap = $("adopt-card"), card = $("adopt-card-inner");
    const first = wrap.hidden;
    wrap.hidden = false;
    if (first) { card.classList.remove("settle"); void card.offsetWidth; card.classList.add("settle"); }
    outfitChanged();
    actors.yours.play([{ pose: "cheer", expr: "happy", ms: 1000 }, { pose: "stand", expr: "happy" }]);
    later("adoptScroll", 120, () => wrap.scrollIntoView({ behavior: reduced ? "auto" : "smooth", block: "center" }));
  });
  function puffNow() { S.puff = true; later("puff", 6000, () => { S.puff = false; invalidate(); }); invalidate(); }
  async function copyText(text) {
    try { await navigator.clipboard.writeText(text); return true; } catch (e) { return false; }
  }
  $("copy-link").addEventListener("click", async () => {
    const ok = await copyText(shareLink());
    $("copy-link").textContent = ok ? "Copied" : "Select and copy";
    if (ok) puffNow();
    later("copyLink", 2000, () => { $("copy-link").textContent = "Copy link"; });
  });
  document.querySelectorAll("[data-copy-install]").forEach((b) => b.addEventListener("click", async () => {
    const ok = await copyText(b.parentElement.querySelector("code").textContent);
    b.textContent = ok ? "Copied" : "Select it";
    if (ok) puffNow();
    setTimeout(() => { b.textContent = "Copy"; }, 2000);
  }));
  // The adoption card as a 1200 × 720 PNG, drawn on a canvas in the browser. Nothing is uploaded.
  $("download").addEventListener("click", async () => {
    const status = $("dl-status");
    try {
      await Promise.all([document.fonts.load('800 120px "Bricolage Grotesque"'), document.fonts.load("600 30px Figtree")]).catch(() => {});
      const markup = Hush.svg(Object.assign({}, S.sel, { pose: "stand", expr: "happy" })).replace("<svg", '<svg width="320" height="292"');
      const img = new Image();
      await new Promise((ok, bad) => { img.onload = ok; img.onerror = bad; img.src = "data:image/svg+xml;charset=utf-8," + encodeURIComponent(markup); });
      const c = document.createElement("canvas"); c.width = 1200; c.height = 720;
      const g = c.getContext("2d");
      const rr = (x, y, w, h, r) => { g.beginPath(); g.moveTo(x + r, y); g.arcTo(x + w, y, x + w, y + h, r); g.arcTo(x + w, y + h, x, y + h, r); g.arcTo(x, y + h, x, y, r); g.arcTo(x, y, x + w, y, r); g.closePath(); };
      const name = petName();
      g.fillStyle = "#F7F3EC"; g.fillRect(0, 0, 1200, 720);
      rr(40, 40, 1120, 640, 48); g.fillStyle = "#FFFDF7"; g.fill(); g.lineWidth = 5; g.strokeStyle = "#16141B"; g.stroke();
      g.save(); g.beginPath(); g.arc(330, 360, 230, 0, Math.PI * 2); g.fillStyle = S.customized ? BGFOR[S.sel.palette] : "#E8876A"; g.fill(); g.clip();
      const hs = 430, hw = hs * 160 / 146; g.drawImage(img, 330 - hw / 2, 590 - hs, hw, hs);
      g.restore(); g.beginPath(); g.arc(330, 360, 230, 0, Math.PI * 2); g.lineWidth = 5; g.stroke();
      g.fillStyle = "#A64B30"; g.font = "800 24px Figtree, sans-serif"; g.fillText("ADOPTION CARD · NO. " + adoptNo, 610, 230);
      g.fillStyle = "#16141B"; let fs = 120; g.font = `800 ${fs}px "Bricolage Grotesque", sans-serif`;
      while (g.measureText(name).width > 500 && fs > 50) { fs -= 6; g.font = `800 ${fs}px "Bricolage Grotesque", sans-serif`; }
      g.fillText(name, 604, 230 + fs);
      g.font = "600 30px Figtree, sans-serif"; g.fillText("Adopted " + $("adopt-date").textContent, 610, 300 + fs);
      g.fillStyle = "#4F4858"; g.font = "500 24px Figtree, sans-serif"; g.fillText(outfitLine().slice(0, 60), 610, 344 + fs);
      g.fillStyle = "#16141B"; g.font = '800 30px "Bricolage Grotesque", sans-serif'; g.fillText("hush", 610, 620);
      g.fillStyle = "#6B6374"; g.font = "500 22px Figtree, sans-serif"; g.fillText("· quiet company for your Mac", 690, 620);
      g.save(); g.translate(1010, 110); g.rotate(0.15); rr(-120, -30, 240, 60, 12); g.fillStyle = "#E8876A"; g.fill(); g.fillStyle = "#16141B"; g.font = '800 22px "Bricolage Grotesque", sans-serif'; g.textAlign = "center"; g.fillText("Never makes a sound.", 0, 8); g.restore();
      const blob = await new Promise((ok) => c.toBlob(ok, "image/png"));
      if (!blob) throw new Error("no blob");
      const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || "hush";
      const a = el("a", { href: URL.createObjectURL(blob), download: slug + "-adoption-card.png" });
      document.body.append(a); a.click(); a.remove();
      setTimeout(() => URL.revokeObjectURL(a.href), 4000);
      status.textContent = "Saved to your downloads.";
    } catch (e) {
      status.textContent = "Your browser blocked it. Right-click the card to save it.";
    }
  });
  // Hushverse spot: no request is made unless CONFIG.waitlistURL is set.
  $("join").addEventListener("submit", async (e) => {
    e.preventDefault();
    const input = $("hush-join"), done = $("join-done");
    const email = input.value.trim();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) { input.focus(); return; }
    if (!CONFIG.waitlistURL) { done.textContent = "The list isn't open yet. Star the repo on GitHub to hear first."; done.hidden = false; return; }
    try {
      const res = await fetch(CONFIG.waitlistURL, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ email }) });
      if (!res.ok) throw new Error(String(res.status));
      $("join").hidden = true;
      done.textContent = "✓ " + petName() + " is on the list. You'll hear first.";
    } catch (err) {
      done.textContent = "That didn't go through. Try again in a moment?";
    }
    done.hidden = false;
  });

  // ---------- 6 close ----------
  new Actor("close", {
    base: () => ({ pose: "bow" }),
    size: () => Math.round(D.phone ? Math.min(D.W * 0.8, 340) : Math.min(D.VH * 0.58, 520)),
    grow: growNow,
  });

  // ---------- scroll ----------
  const SECS = ["hero", "flood", "try", "build", "yours", "close"].map((k) => [k, document.querySelector(`[data-sec="${k}"]`)]);
  let lastY = null, lastT = 0, atEnd = false;
  function onScrollFrame() {
    const now = performance.now(), y = scrollY;
    const v = lastY === null ? 0 : Math.abs(y - lastY) / Math.max(1, now - lastT);
    lastY = y; lastT = now;
    if (v > 2.2 && !S.fast) S.fast = true;
    later("fast", 200, () => { S.fast = false; invalidate(); });
    const fl = $("flood").getBoundingClientRect();
    F.floodP = clamp(-fl.top / Math.max(1, fl.height - D.VH), 0, 1);
    if (F.autoP !== null && F.autoT0 === null && v > 0.3) F.autoP = null;
    if (F.autoT0 !== null && v > 0.3) { F.autoT0 = null; F.autoP = null; }
    const mid = innerHeight * 0.5;
    let sec = S.sec;
    for (const [k, node] of SECS) { const r = node.getBoundingClientRect(); if (r.top <= mid && r.bottom > mid) sec = k; }
    if (sec !== S.sec) S.sec = sec;
    S.past = SECS[0][1].getBoundingClientRect().bottom < innerHeight * 0.55;
    const end = y + innerHeight >= document.documentElement.scrollHeight - 4;
    if (end && !atEnd) actors.close.play([{ pose: "cheer", expr: "happy", ms: 1100 }, { pose: "bow" }]);
    atEnd = end;
  }

  // ---------- cursor tracking ----------
  let lastPoint = null;
  function computeLooks() {
    if (!lastPoint) return;
    const q = (v) => Math.round(v * 2) / 2;
    for (const a of Object.values(actors)) {
      const r = a.char.getBoundingClientRect();
      if (r.bottom < 0 || r.top > innerHeight || r.width === 0) continue;
      const cx = r.left + r.width / 2, cy = r.top + r.height * 0.42;
      const dx = lastPoint.x - cx, dy = lastPoint.y - cy;
      a.look = {
        x: q(clamp(dx / 220, -2.2, 2.2)), y: q(clamp(dy / 200, -2.2, 2.2)),
        lean: Math.hypot(dx, dy) < Math.max(260, r.width * 0.6) ? Math.round(clamp(dx / 50, -5, 5)) : 0,
      };
    }
    S.glance = null;
  }

  // ---------- idle life ----------
  let lastInput = Date.now();
  function wake() {
    lastInput = Date.now();
    if (S.dozing) {
      S.dozing = false;
      if (!reduced) {
        actors.hero.play([{ pose: "notice", expr: "surprised", ms: 320 }, { pose: "" }]);
      }
      invalidate();
    }
  }
  setInterval(() => {
    const idle = Date.now() - lastInput;
    if (idle > 20000 && !S.dozing) { S.dozing = true; invalidate(); }
    if (idle > 5000 && idle < 20000 && !reduced && Math.random() < 0.18) {
      const G = [[-2, -1], [2, -1.5], [0, -2], [1.5, 0.5], [-1.5, 0]];
      const gl = G[Math.floor(Math.random() * G.length)];
      S.glance = { x: gl[0], y: gl[1] };
      for (const a of Object.values(actors)) a.look = null;
      invalidate();
    }
  }, 1000);
  function scheduleBlink() {
    if (reduced) return;
    later("blink", 3800 + Math.random() * 3400, () => {
      S.blink = true; invalidate();
      later("blink2", 140, () => { S.blink = false; invalidate(); scheduleBlink(); });
    });
  }
  scheduleBlink();

  // ---------- events ----------
  addEventListener("pointermove", (e) => {
    lastPoint = { x: e.clientX, y: e.clientY };
    wake(); lookDirty = true;
    dragMove(e);
    if (F.cd) { F.cd.dx = e.clientX - F.cd.x; F.cd.dy = e.clientY - F.cd.y; }
    invalidate();
  }, { passive: true });
  addEventListener("pointerdown", (e) => { lastPoint = { x: e.clientX, y: e.clientY }; wake(); lookDirty = true; invalidate(); }, { passive: true });
  addEventListener("pointerup", () => {
    dragEnd(false);
    const cd = F.cd; F.cd = null;
    if (cd) {
      F.cards[cd.i] && F.cards[cd.i].node.classList.remove("drag");
      if (Math.hypot(cd.dx, cd.dy) > 70) {
        F.flung[cd.i] = { dx: cd.dx * 4, dy: cd.dy * 4 };
        actors.flood.play([{ pose: "wave", expr: "happy", ms: 900 }, { pose: "" }]);
      }
      invalidate();
    }
  });
  addEventListener("pointercancel", () => {
    dragEnd(true);
    if (F.cd) { F.cards[F.cd.i] && F.cards[F.cd.i].node.classList.remove("drag"); F.cd = null; invalidate(); }
  });
  addEventListener("scroll", () => { lastInput = Date.now(); scrollDirty = true; lookDirty = true; invalidate(); }, { passive: true });
  addEventListener("keydown", wake);
  addEventListener("resize", () => { measure(); buildFlood(); outfitChanged(); scrollDirty = true; for (const a of Object.values(actors)) a._place = null; invalidate(); });
  document.addEventListener("input", (e) => {
    const tg = e.target && e.target.tagName;
    if (tg !== "INPUT" && tg !== "TEXTAREA") return;
    wake();
    S.typing = true; invalidate();
    later("typing", 2000, () => { S.typing = false; invalidate(); });
  }, true);
  document.addEventListener("copy", puffNow, true);
  document.addEventListener("paste", () => {
    if (!S.puff) return;
    S.puff = false; clearTimeout(T.puff);
    actors.hero.play([{ pose: "bob", expr: "happy", ms: 700 }, { pose: "" }]);
  }, true);
  let awayAt = 0;
  document.addEventListener("visibilitychange", () => {
    if (document.hidden) { awayAt = Date.now(); return; }
    if (!awayAt) return;
    const away = Date.now() - awayAt; awayAt = 0;
    if (away > 1000) actors.hero.play([{ pose: "wave", expr: "happy", ms: 1200 }, { pose: "" }]);
  });
  mq.addEventListener("change", (e) => {
    reduced = e.matches;
    clearTimeout(T.blink); clearTimeout(T.blink2); S.blink = false; S.glance = null;
    scheduleBlink(); invalidate();
  });

  // ---------- one frame ----------
  function frame(now) {
    rafId = 0;
    if (scrollDirty) { scrollDirty = false; onScrollFrame(); }
    if (F.autoT0 !== null) {
      F.autoP = Math.min(1, (now - F.autoT0) / 9000);
      if (F.autoP >= 1) F.autoT0 = null;
      else invalidate();
    }
    if (lookDirty) { lookDirty = false; computeLooks(); }
    renderFlood();
    for (const a of Object.values(actors)) a.render();
  }

  // ---------- start ----------
  // The visitor's Hush comes back from this browser (localStorage) or from a shared link (#hush=name~outfit).
  function restore(v) {
    if (!v || typeof v !== "object") return;
    for (const k of SEL_KEYS) if (typeof v[k] === "string" && GBY[k].opts.some((o) => o[0] === v[k])) S.sel[k] = v[k];
    if (typeof v.name === "string") S.name = v.name.slice(0, 18);
    S.customized = true;
  }
  try { restore(JSON.parse(localStorage.getItem("hush-visitor") || "null")); } catch (e) { /* storage off */ }
  const m = /#hush=([^~]*)~([\w.]+)/.exec(location.hash);
  if (m) {
    const vals = m[2].split(".");
    const v = { name: decodeURIComponent(m[1]) };
    SEL_KEYS.forEach((k, i) => { v[k] = vals[i]; });
    restore(v);
    history.replaceState(null, "", location.pathname + location.search + "#yours");
  }
  $("hush-name").value = S.name;

  buildFlood(); renderTune(); renderNotebook(); go(0); renderMoments(); renderTabs(); renderPanel(); outfitChanged();

  // Time of day: before 10:00 a yawn and a stretch; Friday evening, one small dance.
  const now = new Date(), hr = now.getHours();
  if (!reduced) {
    if (hr < 10) actors.hero.play([{ pose: "yawn", expr: "yawn", ms: 1000 }, { pose: "stretch", expr: "squint", ms: 900 }, { pose: "" }]);
    else if (now.getDay() === 5 && hr >= 18) actors.hero.play([{ pose: "dance", expr: "happy", ms: 1800 }, { pose: "" }]);
  }
  invalidate();
})();
