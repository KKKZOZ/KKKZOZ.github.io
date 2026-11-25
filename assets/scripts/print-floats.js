// Page floats for printing a post. A browser moves a figure that does not fit
// at the foot of a page to the next page whole and leaves the rest of the page
// empty. Here, just before printing, the text after such a figure is moved up
// to fill that space, so the figure starts the next page instead, as LaTeX
// places floats. All moves are undone once the print dialog closes.
//
// Where the pages break comes from the browser itself: for the measurement,
// the print styles are switched on for the screen and <body> is laid out as
// columns the size of the printed page area, which fragment as pages do. An
// element's column is its page.
//
// Registered after the theme's print.js (head-extra in site.typ loads this
// after the theme's scripts), so folds are already open when it measures.
(() => {
  if (document._printFloatsBound) return;
  document._printFloatsBound = true;

  // The page area: A4 (`@page { size: A4 }` in blog.css) less the theme's
  // print margins (16mm 22mm 18mm), in CSS px.
  const MM = 96 / 25.4;
  const PAGE_W = (210 - 22 - 22) * MM;
  const PAGE_H = (297 - 16 - 18) * MM;
  // A gap under this share of the page is left as it is.
  const MIN_GAP = 0.08;
  // A figure taller than this share of the page is scaled down to it.
  const MAX_FIGURE = 0.96;
  // A figure may be drawn down to this share of its size to fit a gap.
  const MIN_SCALE = 0.85;

  let undo = [];

  // The `@media print` rules of the page's own stylesheets.
  const printRules = () => {
    const out = [];
    const walk = (rules) => {
      for (const r of rules) {
        if (r instanceof CSSMediaRule && r.media.mediaText === "print") out.push(r);
        else if (r.cssRules) walk(r.cssRules);
      }
    };
    for (const sheet of document.styleSheets) {
      try { walk(sheet.cssRules); } catch { /* another origin's sheet */ }
    }
    return out;
  };

  // Lays the page out as printed pages on screen; returns a function that
  // puts the screen layout back.
  const paged = () => {
    const rules = printRules();
    for (const r of rules) r.media.mediaText = "all";
    const body = document.body;
    const style = body.getAttribute("style");
    const { scrollX, scrollY } = window;
    const zoom = parseFloat(getComputedStyle(body).zoom) || 1;
    const w = PAGE_W / zoom, h = PAGE_H / zoom;
    body.style.cssText += `;width:${w}px;height:${h}px;margin:0;padding:0;`
      + `columns:${w}px auto;column-gap:0;column-fill:auto;overflow:visible`;
    return () => {
      if (style === null) body.removeAttribute("style");
      else body.setAttribute("style", style);
      for (const r of rules) r.media.mediaText = "print";
      window.scrollTo(scrollX, scrollY);
    };
  };

  // Page index and top of an element's first fragment, the top as a share
  // of the page height.
  const place = (el) => {
    const b = document.body.getBoundingClientRect();
    const r = el.getClientRects()[0] ?? el.getBoundingClientRect();
    return { page: Math.floor((r.left - b.left + 1) / b.width), top: (r.top - b.top) / b.height };
  };

  // Total height of an element over all its fragments, as a share of a page.
  const height = (el) => {
    const b = document.body.getBoundingClientRect();
    return [...el.getClientRects()].reduce((s, r) => s + r.height, 0) / b.height;
  };

  const isHeading = (el) => /^H[1-6]$/.test(el.tagName);
  const avoids = (el) => getComputedStyle(el).breakInside.startsWith("avoid");

  const markers = new WeakSet();

  const move = (node, before) => {
    // Where it goes back: before its next sibling that is not a marker,
    // since markers are gone by then.
    const parent = node.parentNode;
    let next = node.nextSibling;
    while (next && markers.has(next)) next = next.nextSibling;
    before.parentNode.insertBefore(node, before);
    undo.push(() => parent.insertBefore(node, next));
  };

  const setStyle = (el, prop, value) => {
    const old = el.getAttribute("style");
    el.style.setProperty(prop, value);
    undo.push(() => old === null ? el.removeAttribute("style") : el.setAttribute("style", old));
  };

  // A zero-height marker: where the text before a block ends.
  const marker = () => {
    const m = document.createElement("div");
    m.style.cssText = "height:0;margin:0;padding:0;border:0";
    markers.add(m);
    return m;
  };

  // The space a block leaves empty at the foot of the page before it, as a
  // share of the page: 0 when nothing before it is on an earlier page.
  const gapBefore = (mark, block) => {
    const m = place(mark), b = place(block);
    return m.page < b.page ? 1 - m.top : 0;
  };

  // A figure with the headings and anchor that stay with it: the first
  // element of that group, and the place text moved up goes (after the
  // headings, so it stays in its section).
  const group = (fig) => {
    let start = fig;
    for (let p = fig.previousElementSibling; p && (isHeading(p) || p.matches(".figure-anchor")); p = p.previousElementSibling) start = p;
    const anchor = fig.previousElementSibling;
    return { start, insert: anchor?.matches(".figure-anchor") ? anchor : fig };
  };

  // Where a marker lands, in pages from the top of the first one.
  const depth = (mark) => { const p = place(mark); return p.page + p.top; };

  const isFigure = (el) => el.tagName === "FIGURE" || el.matches(".figure-anchor");

  const settleFigure = (fig) => {
    const { start, insert } = group(fig);
    const mark = marker(), end = marker();
    start.before(mark);
    if (gapBefore(mark, start) < MIN_GAP) { mark.remove(); return; }

    const page = place(fig).page;
    let moved = 0;
    // Blocks after the figure, up to the next heading, move up one at a time;
    // later figures stay where they are, as LaTeX keeps floats in order.
    for (let n = fig.nextElementSibling; n && !isHeading(n) && !n.querySelector("figure");) {
      const next = n.nextElementSibling;
      if (isFigure(n)) { n = next; continue; }
      // A move is kept when the content up to where the block was takes
      // fewer pages than before: the same content, so less empty space. It
      // is taken back when it does not, or when the figure goes on to a
      // later page.
      n.after(end);
      const before = depth(end);
      move(n, insert);
      insert.before(mark);
      if (place(fig).page > page || depth(end) > before - 0.005) {
        undo.pop()();
        if (!moved) start.before(mark);
        break;
      }
      moved++;
      if (gapBefore(mark, fig) < MIN_GAP) break;
      n = next;
    }
    end.remove();
    const gap = gapBefore(mark, moved ? fig : start);
    mark.remove();
    if (gap < MIN_GAP) return;

    // Nothing left to fill the gap with. A table may break between its rows;
    // a figure that fits the gap at a little under its size is drawn so.
    if (fig.querySelector("table")) { setStyle(fig, "break-inside", "auto"); return; }
    const from = moved ? fig : start;
    const above = place(fig).top - place(from).top;
    const h = height(fig);
    const scale = (gap - above - 0.01) / h;
    if (scale < MIN_SCALE || scale >= 1) return;
    const at = place(fig).page;
    const zoom = parseFloat(fig.style.zoom) || 1;
    setStyle(fig, "zoom", String(zoom * scale));
    if (place(fig).page >= at) undo.pop()();
  };

  // A callout or other block kept whole that leaves a gap may break instead.
  const settleBlock = (el) => {
    const mark = marker();
    let start = el;
    for (let p = el.previousElementSibling; p && isHeading(p); p = p.previousElementSibling) start = p;
    start.before(mark);
    if (gapBefore(mark, start) >= MIN_GAP) setStyle(el, "break-inside", "auto");
    mark.remove();
  };

  const paginate = () => {
    const prose = document.querySelector("article.post .prose");
    if (!prose) return;
    const restore = paged();
    try {
      // A copy: the loop moves children around.
      const blocks = [...prose.children];
      for (const fig of blocks.filter((el) => el.tagName === "FIGURE")) {
        const h = height(fig);
        if (h > MAX_FIGURE) setStyle(fig, "zoom", String(MAX_FIGURE / h));
      }
      for (const el of blocks) {
        if (el.tagName === "FIGURE") settleFigure(el);
        else if (!el.matches(".figure-anchor") && avoids(el)) settleBlock(el);
      }
    } finally {
      restore();
    }
  };

  const unpaginate = () => {
    while (undo.length) undo.pop()();
  };

  addEventListener("beforeprint", () => {
    unpaginate();
    try { paginate(); } catch (e) { unpaginate(); console.error(e); }
  });
  addEventListener("afterprint", unpaginate);
})();
