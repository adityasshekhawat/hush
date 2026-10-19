// Hush landing page: the interactive parts (hero, the six-step tutorial, the day strip, Make it yours, rare finds,
// the Hushverse waitlist). Behaviour follows the "Launch landing page" board on the Hush canvas.
(function () {
  // Links and facts that aren't known yet. Empty or "#" values stay inert; fill these in before launch.
  const CONFIG = {
    download: "#",          // a signed release, once there is one (the page links GitHub until then)
    github: "#",            // the repo
    changelog: "#",
    privacy: "#",
    requires: "Requires macOS 15 Sequoia or later",
    madeBy: "",             // "Made by …" in the footer; hidden while empty
    waitlistURL: "",        // POST {email} here; while empty the form says the list isn't open yet
  };

  const $ = (id) => document.getElementById(id);
  const reduced = matchMedia("(prefers-reduced-motion: reduce)").matches;
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

  // ---------- links ----------
  document.querySelectorAll("[data-link]").forEach((a) => {
    const href = CONFIG[a.dataset.link];
    a.setAttribute("href", href || "#");
    if (href && href !== "#" && /^https?:/.test(href)) { a.target = "_blank"; a.rel = "noopener"; }
  });
  document.querySelectorAll("[data-text]").forEach((n) => {
    const v = CONFIG[n.dataset.text];
    if (n.dataset.text === "madeBy") { if (v) n.textContent = "Made by " + v; else n.remove(); }
    else n.textContent = v;
  });

  // ---------- frame sequences ----------
  // play(track, frames, done): each frame {pose, expr, lx, ly, ms, status}; the last frame stays.
  const tracks = {};
  function play(track, frames, done) {
    const t = tracks[track] || (tracks[track] = { timers: [] });
    t.timers.forEach(clearTimeout);
    t.timers = [];
    let at = 0;
    frames.forEach((f, i) => {
      t.timers.push(setTimeout(() => {
        t.apply(f);
        if (i === frames.length - 1 && done) done();
      }, at));
      at += f.ms || 0;
    });
  }

  // ---------- hero ----------
  const hero = { pose: "peek", expr: "auto", lookx: 0, looky: 0 };
  const drawHero = () => Hush.draw($("hero-char"), Object.assign({ size: 320 }, hero));
  tracks.h = { timers: [], apply: (f) => { Object.assign(hero, { pose: f.pose, expr: f.expr || "auto", lookx: f.lx || 0, looky: f.ly || 0 }); drawHero(); } };
  drawHero();
  $("hero-desk").addEventListener("mousemove", (e) => {
    if (hero.pose !== "peek") return;
    const r = e.currentTarget.getBoundingClientRect();
    const cl = (v) => Math.max(-2.4, Math.min(2.4, Math.round(v * 4) / 2));
    const lx = cl(((e.clientX - (r.left + r.width / 2)) / (r.width / 2)) * 1.2);
    const ly = cl(((e.clientY - (r.top + r.height * 0.7)) / (r.height / 2)) * 1.2);
    if (lx !== hero.lookx || ly !== hero.looky) { hero.lookx = lx; hero.looky = ly; drawHero(); }
  });
  $("hero-hush").addEventListener("click", () => play("h", [
    { pose: "poked", ms: 160 }, { pose: "giggle", expr: "happy", ms: 600 }, { pose: "wiggleL", ms: 220 },
    { pose: "wiggleR", ms: 220 }, { pose: "peek", expr: "happy", ms: 900 }, { pose: "peek" }]));

  // ---------- tutorial ----------
  const STEPS = [
    { title: "Say hello.", body: "Click Hush. Go on." },
    { title: "Pick it up.", body: "Press on Hush and let go, like you would drag it across your screen." },
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

  const tut = { step: 0, pose: "stand", expr: "auto", lookx: 0, looky: 0, env: "none", askText: "", asked: "", receipt: "", status: "", learned: [] };
  let typing = false, idle = null;

  const route = (q) => {
    const t = (q || "").toLowerCase();
    if (/sheet|browser|book a|order|fill/.test(t)) return "web";
    if (/repo|code|function|bug|where do we|hush/.test(t)) return "repo";
    if (/write|draft|essay|letter|email|thoughtful/.test(t)) return "hand";
    return "quick";
  };

  function learn(key, text) {
    if (tut.learned.some((l) => l.key === key)) return;
    tut.learned.push({ key, text, crossed: false });
    renderNotebook();
    drawTut();
  }

  tracks.t = { timers: [], apply: (f) => {
    Object.assign(tut, { pose: f.pose, expr: f.expr || "auto", lookx: f.lx || 0, looky: f.ly || 0 });
    if (f.status !== undefined) { tut.status = f.status; renderStatus(); }
    drawTut();
  } };

  function drawTut() {
    const active = tut.learned.filter((l) => !l.crossed).length;
    const grow = Math.min(1.8, 1 + active * 0.12);
    Hush.draw($("tut-char"), { pose: tut.pose, expr: tut.expr, lookx: tut.lookx, looky: tut.looky, grow, size: tut.step === 3 || tut.step === 4 ? 200 : 240 });
    $("tut-hush").setAttribute("aria-label", { 0: "Poke Hush", 1: "Pick up Hush", 5: "Poke Hush" }[tut.step] || "Hush");
  }

  function renderStatus() {
    const s = $("tut-status");
    s.textContent = tut.status;
    s.hidden = !tut.status;
  }

  function renderNotebook() {
    const list = $("nb-list");
    list.replaceChildren();
    if (!tut.learned.length) { list.append(el("div", { class: "nb-empty" }, "Nothing yet. Say hello.")); return; }
    tut.learned.forEach((l) => list.append(el("button", {
      type: "button", class: "nb-item", "aria-pressed": String(l.crossed),
      "aria-label": (l.crossed ? "Restore: " : "Cross out: ") + l.text,
      onclick: () => {
        l.crossed = !l.crossed;
        renderNotebook();
        play("t", [{ pose: "listen", ms: 500 }, { pose: "stand", expr: "happy", ms: 700 }, { pose: "stand" }]);
      },
    }, l.text)));
  }

  function renderChips() {
    const box = $("tut-chips");
    box.replaceChildren(...STEPS.map((s, i) => el("button", {
      type: "button", role: "tab", class: "chip-btn", "aria-selected": String(i === tut.step), onclick: () => go(i),
    }, (i + 1) + " " + s.title.replace(".", ""))));
  }

  function renderSide() {
    $("tut-n").textContent = `Step ${tut.step + 1} of 6`;
    $("tut-title").textContent = STEPS[tut.step].title;
    $("tut-body").textContent = STEPS[tut.step].body;
    $("tut-fling").hidden = tut.step !== 1;
    $("tut-next").textContent = tut.step === 5 ? "Start over" : "Next";
  }

  // The overlay above Hush for each step: a document, an envelope, the ask box, an answer.
  function renderOverlay() {
    const box = $("tut-overlay");
    box.replaceChildren();
    if (tut.step === 2) {
      const area = el("textarea", { id: "hush-editor", rows: "4", placeholder: "Start typing anything…", oninput: typed });
      box.append(el("div", { class: "doc-field" }, el("label", { for: "hush-editor" }, "Your document"), area));
    }
    if (tut.step === 3 && tut.env !== "none") {
      const titles = { arrived: "Claude finished in hush", open: "Opening Terminal…", never: "Got it. I’ll hold these back.", later: "Saved for later." };
      const subs = { arrived: "Ran for 4m · Terminal", open: "Jumping to where it ran.", never: "“Agent finishes can wait.” · Undo", later: "It’ll be in the panel when you want it." };
      const card = el("div", { class: "card", style: "position: absolute; left: 20px; top: 20px; width: min(320px, 80%)" },
        el("div", { class: "ch" }, el("span", { class: "icon", style: "background: #DDF3E4; color: #1E7A3C" }, "✓"), el("span", {}, "Claude Code · hush"), el("span", { class: "ml" }, "16:02")),
        el("div", { class: "ct" }, titles[tut.env]),
        el("div", { class: "cs" }, subs[tut.env]));
      if (tut.env === "arrived") {
        card.append(el("div", { class: "ca" },
          el("button", { type: "button", class: "pl", onclick: envOpen }, "Open"),
          el("button", { type: "button", class: "pl s", onclick: envNever }, "Not this kind again"),
          el("button", { type: "button", class: "pl q ml", onclick: envLater }, "Later")));
      } else card.append(el("div", { style: "height: 12px" }));
      box.append(card);
    }
    if (tut.step === 4 && !tut.asked) {
      const chip = el("span", { class: "route-chip" });
      const setChip = () => { const c = CHIP[route(input.value)]; chip.textContent = c.label; chip.setAttribute("style", c.style); };
      const input = el("input", {
        id: "hush-ask", type: "text", autocomplete: "off", placeholder: "Ask Hush…", value: tut.askText,
        oninput: (e) => { tut.askText = e.target.value; setChip(); },
        onkeydown: (e) => { if (e.key === "Enter") { e.preventDefault(); ask(e.target.value); } },
      });
      setChip();
      box.append(el("div", { class: "ask-wrap" },
        el("div", { class: "card ask-box" }, el("label", { for: "hush-ask", class: "sr-only" }, "Ask Hush"), input, chip),
        el("div", { class: "row", style: "gap: 6px" }, SUGGEST.map((t) => el("button", { type: "button", class: "suggest", onclick: () => ask(t) }, t)))));
    }
    if (tut.step === 4 && tut.asked) {
      const a = ANSWERS[tut.asked];
      const card = el("div", { class: "card", style: "position: absolute; left: 20px; top: 18px; width: min(380px, 86%)" },
        el("div", { class: "ch" }, el("span", { class: "route-chip small", style: CHIP[tut.asked].style }, a.lane), el("span", {}, tut.asked === "web" ? "Plan ready" : "Done")),
        el("div", { style: "font-size: 12.5px; color: #6E6878; padding: 0 14px" }, tut.askText));
      if (a.mono) card.append(el("div", { class: "mono" }, a.body));
      else if (a.plan) card.append(el("div", { style: "padding: 6px 14px 0; display: flex; flex-direction: column; gap: 5px; font-size: 13px" },
        el("div", {}, "1 · Open sheets.google.com"), el("div", {}, "2 · Type 12, 40 and 7 into A1 to A3"),
        el("div", {}, "3 · Share it with Sam ", el("span", { class: "ask-tag" }, "asks first"))));
      else card.append(el("div", { style: "font-size: 13.5px; line-height: 1.5; padding: 8px 14px 0" }, a.body));
      card.append(el("div", { class: "ca" },
        el("button", { type: "button", class: "pl", onclick: () => { tut.receipt = a.rc; renderOverlay(); play("t", [{ pose: "wave", expr: "happy", ms: 1000 }, { pose: "sit", expr: "happy" }]); } }, a.act),
        el("button", { type: "button", class: "pl s", onclick: () => { tut.asked = ""; tut.receipt = ""; tut.askText = ""; renderOverlay(); play("t", [{ pose: "sitListen", ly: -2.2 }]); } }, a.act2)));
      if (tut.receipt) card.append(el("div", { class: "rc" }, "✓ " + tut.receipt));
      card.append(el("div", { class: "cf" }, a.foot));
      box.append(card);
    }
  }

  function go(i) {
    clearTimeout(idle); typing = false;
    Object.assign(tut, { step: i, env: "none", asked: "", receipt: "", status: "" });
    renderStatus(); renderChips(); renderSide(); renderOverlay();
    if (i === 3) play("t", [{ pose: "stand", ms: 700 }, { pose: "hurry", expr: "alert", ms: 800 }, { pose: "hold", expr: "happy" }], () => { tut.env = "arrived"; renderOverlay(); });
    else if (i === 4) play("t", [{ pose: "sitListen", ly: -2.2 }]);
    else if (i === 5) play("t", [{ pose: "proud", expr: "happy", ms: 1400 }, { pose: "stand", expr: "happy" }]);
    else play("t", [{ pose: "stand" }]);
    drawTut();
  }

  function ask(text) {
    const q = (text || "").trim();
    if (!q) return;
    const r = route(q);
    Object.assign(tut, { askText: q, asked: "", receipt: "" });
    play("t", [
      { pose: "sitThink", expr: "thinking", ms: 1100, status: r === "repo" ? "Reading the repo…" : "Thinking…" },
      { pose: r === "hand" ? "wave" : "handOver", expr: "happy", ms: 1200, status: "" },
      { pose: "sit", expr: "happy" }]);
    tracks.t.timers.push(setTimeout(() => { tut.asked = r; renderOverlay(); learn("ask-" + r, LEARN_ASK[r]); }, 1100));
  }

  function envOpen() { tut.env = "open"; renderOverlay(); play("t", [{ pose: "wave", expr: "happy", ms: 1200 }, { pose: "stand" }]); learn("env-open", "Wants to know when Claude is done."); }
  function envNever() { tut.env = "never"; renderOverlay(); play("t", [{ pose: "bow", expr: "happy", ms: 1200 }, { pose: "stand" }]); learn("env-never", "Agent finishes can wait."); }
  function envLater() { tut.env = "later"; renderOverlay(); play("t", [{ pose: "stand", expr: "happy", ms: 800 }, { pose: "stand" }]); learn("env-later", "Later is usually fine."); }

  function typed() {
    if (!typing) {
      typing = true;
      play("t", [{ pose: "notice", ms: 250 }, { pose: "dive", ms: 220 }, { pose: "hide" }]);
      learn("focus", "Hides when you type.");
    }
    clearTimeout(idle);
    idle = setTimeout(() => { typing = false; play("t", [{ pose: "peek", ms: 700 }, { pose: "stand", expr: "happy", ms: 800 }, { pose: "stand" }]); }, 1600);
  }

  const flingFrames = [{ pose: "swing", ms: 380 }, { pose: "land", ms: 220 }, { pose: "dizzy", ms: 1400 }, { pose: "shake", ms: 500 }, { pose: "stand", expr: "apologetic", ms: 1000 }, { pose: "stand" }];
  $("tut-hush").addEventListener("pointerdown", () => { if (tut.step === 1) play("t", [{ pose: "grab" }]); });
  $("tut-hush").addEventListener("click", () => {
    if (tut.step === 0 || tut.step === 5) {
      play("t", [{ pose: "poked", ms: 160 }, { pose: "giggle", ms: 600 }, { pose: "wiggleL", ms: 220 }, { pose: "wiggleR", ms: 220 }, { pose: "stand", expr: "happy", ms: 900 }, { pose: "stand" }]);
      learn("hi", "Likes to say hi.");
    } else if (tut.step === 1) {
      play("t", flingFrames);
      learn("fling", "Don't fling me. (Fine, maybe once.)");
    }
  });
  $("tut-fling").addEventListener("click", () => { play("t", [{ pose: "grab", ms: 400 }].concat(flingFrames)); learn("fling", "Don't fling me. (Fine, maybe once.)"); });
  $("tut-next").addEventListener("click", () => go(tut.step === 5 ? 0 : tut.step + 1));
  $("tut-back").addEventListener("click", () => go(Math.max(0, tut.step - 1)));
  go(0);

  // ---------- a day ----------
  const DAY = [
    { time: "08:40", pose: "stretch", title: "Morning stretch", body: "First unlock of the day. A yawn, a stretch, then quiet." },
    { time: "10:15", pose: "hide", title: "Out of the way", body: "You start typing. It ducks out of sight until you stop." },
    { time: "11:30", pose: "puff", expr: "puff", title: "Copy, paste", body: "Copy something and its cheeks puff up. Paste lets the air out." },
    { time: "14:50", pose: "clock", title: "Meeting in 10", body: "A clock, held up politely. At two minutes, it hurries." },
    { time: "16:02", pose: "hold", expr: "happy", title: "Claude finished", body: "An envelope: Claude finished in hush. Ran for 4 minutes." },
    { time: "17:20", pose: "perch", title: "Keeping you company", body: "Perched on your window, swinging its legs." },
    { time: "18:30", pose: "yawn", expr: "sleepy", title: "Tucks the day in", body: "You got 4 things from me today. I held back 63." },
  ];
  const strip = $("day-strip");
  const dayCards = DAY.map((d) => {
    const art = el("span");
    Hush.draw(art, { pose: d.pose, expr: d.expr || "auto", size: 130 });
    const card = el("div", { class: "day-card" },
      el("div", { class: "day-time" }, d.time), el("div", { class: "day-art" }, art),
      el("div", { class: "day-title" }, d.title), el("div", { class: "day-body" }, d.body));
    strip.append(card);
    return card;
  });
  let dayOn = 0;
  dayCards[0].classList.add("on");
  if (!reduced) setInterval(() => { dayCards[dayOn].classList.remove("on"); dayOn = (dayOn + 1) % 7; dayCards[dayOn].classList.add("on"); }, 2200);

  // ---------- make it yours ----------
  const GROUPS = [
    { key: "shape", label: "Body", opts: [["blob", "Round"], ["bean", "Tall"], ["square", "Square"]] },
    { key: "palette", label: "Colour", opts: [["oat", "Oat"], ["mint", "Mint"], ["lilac", "Lilac"], ["sky", "Sky"], ["rose", "Rose"], ["peach", "Peach"], ["matcha", "Matcha"], ["butter", "Butter"], ["berry", "Berry"]] },
    { key: "topper", label: "On top", opts: [["none", "Nothing"], ["leaf", "Sprout"], ["antenna", "Antenna"], ["ears", "Ears"]] },
    { key: "head", label: "Head", opts: [["none", "Nothing"], ["cap", "Cap"], ["beanie", "Beanie"], ["bucket", "Bucket hat"], ["headphones", "Headphones"], ["crown", "Crown"], ["frogHat", "Frog hat"], ["bunny", "Bunny ears"], ["straw", "Straw hat"], ["beret", "Beret"], ["wizard", "Wizard"], ["chef", "Chef"], ["hardHat", "Hard hat"]] },
    { key: "face", label: "Face", opts: [["none", "Nothing"], ["glasses", "Glasses"], ["shades", "Shades"], ["pixelShades", "Pixel shades"], ["starGlasses", "Star glasses"]] },
    { key: "neck", label: "Neck", opts: [["none", "Nothing"], ["scarf", "Scarf"], ["bandana", "Bandana"], ["bowtie", "Bow tie"], ["chain", "Chain"], ["tie", "Tie"], ["lanyard", "Lanyard"], ["cape", "Cape"]] },
    { key: "carry", label: "Beside it", opts: [["none", "Nothing"], ["satchel", "Satchel"], ["laptop", "Laptop"], ["coffee", "Coffee"], ["plant", "Plant"], ["books", "Books"]] },
  ];
  const sel = { shape: "blob", palette: "oat", eyes: "round", topper: "leaf", head: "none", face: "none", neck: "none", carry: "none", pose: "stand" };
  let name = "Hush";
  function renderYours() {
    Hush.draw($("yours-char"), Object.assign({ expr: "happy", size: 300 }, sel));
    Hush.draw($("close-char"), Object.assign({}, sel, { pose: "bow", size: 220 }));
    $("pet-name").textContent = name;
    document.querySelectorAll(".pet-name-inline").forEach((n) => { n.textContent = name; });
    document.querySelectorAll(".opt").forEach((b) => b.setAttribute("aria-pressed", String(sel[b.dataset.key] === b.dataset.val)));
  }
  $("yours-groups").append(...GROUPS.map((g) => el("div", { class: "group" },
    el("div", { class: "group-label" }, g.label),
    el("div", { class: "row", style: "gap: 6px" }, g.opts.map(([val, label]) => el("button", {
      type: "button", class: "opt", "data-key": g.key, "data-val": val, "aria-pressed": "false",
      onclick: () => { sel[g.key] = val; renderYours(); },
    }, label))))));
  $("hush-name").addEventListener("input", (e) => { name = e.target.value.trim() || "Hush"; renderYours(); });
  let hopTimer = null;
  $("surprise").addEventListener("click", () => {
    GROUPS.forEach((g) => { sel[g.key] = g.opts[Math.floor(Math.random() * g.opts.length)][0]; });
    sel.pose = "hop";
    renderYours();
    clearTimeout(hopTimer);
    hopTimer = setTimeout(() => { sel.pose = "stand"; renderYours(); }, 700);
  });
  renderYours();

  // ---------- rare finds ----------
  const RARE = [
    { name: "A little bird", hint: "On a quiet morning", shape: "blob", palette: "oat", topper: "leaf", buddy: "bird", pose: "stand", expr: "blissful" },
    { name: "Party hat", hint: "On Hush's birthday", shape: "bean", palette: "lilac", topper: "ears", head: "partyHat", carry: "balloon", pose: "cheer", expr: "happy" },
    { name: "Lantern", hint: "Late nights", shape: "square", palette: "sky", topper: "none", carry: "lantern", pose: "sit", expr: "sleepy" },
    { name: "Halo", hint: "A week with no interruptions", shape: "blob", palette: "rose", topper: "none", head: "halo", pose: "proud", expr: "blissful" },
    { name: "Snail friend", hint: "Slow afternoons", shape: "bean", palette: "mint", topper: "antenna", buddy: "snail", pose: "notice", expr: "surprised" },
    { name: "Flower crown", hint: "First day of spring", shape: "blob", palette: "matcha", topper: "none", head: "flowerCrown", pose: "stand", expr: "happy" },
  ];
  $("rare-grid").append(...RARE.map((r) => {
    const art = el("span");
    Hush.draw(art, Object.assign({ size: 124 }, r));
    return el("div", { class: "rare" }, el("div", { class: "rare-art" }, art), el("b", {}, r.name), el("span", {}, r.hint));
  }));

  // ---------- everything static ----------
  Hush.mountAll();

  // ---------- Hushverse waitlist ----------
  $("waitlist").addEventListener("submit", async (e) => {
    e.preventDefault();
    const email = $("verse-email").value.trim();
    const done = $("wait-done");
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) { $("verse-email").focus(); return; }
    if (!CONFIG.waitlistURL) {
      done.textContent = "The list isn't open yet. Star the repo to hear first.";
      done.hidden = false;
      return;
    }
    try {
      const res = await fetch(CONFIG.waitlistURL, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ email }) });
      if (!res.ok) throw new Error(String(res.status));
      $("waitlist").hidden = true;
      done.textContent = "✓ You're on the list. Your Hush will hear first.";
    } catch {
      done.textContent = "That didn't go through. Try again in a moment?";
    }
    done.hidden = false;
  });
})();
