// Export a built post as Markdown for Zhihu, which takes neither Typst nor
// SVG. Works from the page in public/, where components are already expanded
// and every formula carries its LaTeX (`data-latex`, templates/latex.typ).
//
//   node scripts/zhihu-export.mjs <slug | content/posts/...typ> --lang <zh|en> [options]
//
//   --lang <zh|en>       language of the post (required): sets the language
//                        of the added lines (source link, notes heading)
//   --out <dir>         output directory (default: zhihu/<slug>)
//   --image-base <url>   prefix image paths with a URL instead of images/
//   --math <style>       "dollar" (default): $...$ and $$...$$
//                        "image": Zhihu equation images (zhihu.com/equation)
//
// Writes <out>/<slug>.md and <out>/images/*.png. Figures (inline SVG) are
// rendered by rsvg-convert at 2x on white; raster images are converted to
// PNG by sips (macOS) or magick. Run `tola build` first: the script reads
// public/ as it is and warns when the source is newer.
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { basename, dirname, join, relative } from "node:path";

const site = "public"; // build.publish-dir in tola.toml
const content = "content"; // build.content-dir
const origin = "https://blog.kkkzoz.top"; // site.origin

const fail = (message) => {
  console.error(message);
  process.exit(1);
};

// ============================================================================
// Arguments
// ============================================================================

const args = process.argv.slice(2);
const opts = { lang: null, out: null, imageBase: null, math: "dollar" };
let target = null;
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a === "--lang") opts.lang = args[++i];
  else if (a === "--out") opts.out = args[++i];
  else if (a === "--image-base") opts.imageBase = args[++i]?.replace(/\/$/, "");
  else if (a === "--math") opts.math = args[++i];
  else if (a.startsWith("--")) fail(`Unknown option ${a}`);
  else target = a;
}
if (!target) fail("Usage: node scripts/zhihu-export.mjs <slug | content/posts/...typ> --lang zh|en [--out dir] [--image-base url] [--math dollar|image]");
if (!["zh", "en"].includes(opts.lang)) fail(`--lang takes "zh" or "en" (the language the post is written in)${opts.lang ? `, not "${opts.lang}"` : ""}`);
if (!["dollar", "image"].includes(opts.math)) fail(`--math takes "dollar" or "image", not "${opts.math}"`);

/// The built page for a slug or a source path.
const findPage = (t) => {
  if (t.endsWith(".typ")) {
    const rel = relative(content, t).replace(/\.typ$/, "");
    const page = join(site, rel, "index.html");
    if (!existsSync(page)) fail(`${page} not found: build the site first (tola build).`);
    return page;
  }
  const hits = readdirSync(join(site, "posts"), { recursive: true })
    .filter((p) => basename(dirname(p)) === t && basename(p) === "index.html")
    .map((p) => join(site, "posts", p));
  if (hits.length === 0) fail(`No built post named "${t}" under ${site}/posts: build the site first (tola build).`);
  if (hits.length > 1) fail(`"${t}" matches several posts; pass the .typ path instead:\n  ${hits.join("\n  ")}`);
  return hits[0];
};

const pagePath = findPage(target);
const slug = basename(dirname(pagePath));
const outDir = opts.out ?? join("zhihu", slug);
const imgDir = join(outDir, "images");

// Warn when the post or its figures changed after the page was built.
{
  const built = statSync(pagePath).mtimeMs;
  const rel = relative(join(site), dirname(pagePath));
  for (const src of [join(content, `${rel}.typ`), join("figures", `${slug}.typ`)]) {
    if (existsSync(src) && statSync(src).mtimeMs > built) {
      console.warn(`warning: ${src} is newer than ${pagePath}; run \`tola build\` for an up-to-date export.`);
    }
  }
}

// ============================================================================
// HTML parsing
// ============================================================================

// Tola's output is well-formed, so a small tree builder is enough. Each node
// keeps its source span, so an SVG can be cut out of the page verbatim.

const VOID = new Set(["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"]);
const RAW = new Set(["script", "style"]);

const decode = (s) =>
  s.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (m, e) => {
    if (e[0] === "#") return String.fromCodePoint(e[1] === "x" || e[1] === "X" ? parseInt(e.slice(2), 16) : +e.slice(1));
    return { lt: "<", gt: ">", amp: "&", quot: '"', apos: "'", nbsp: "\u00a0" }[e.toLowerCase()] ?? m;
  });

const parseAttrs = (s) => {
  const attrs = {};
  for (const m of s.matchAll(/([^\s=/>]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/g)) {
    attrs[m[1].toLowerCase()] = decode(m[2] ?? m[3] ?? m[4] ?? "");
  }
  return attrs;
};

const parse = (html) => {
  const root = { tag: "#root", attrs: {}, children: [], start: 0, end: html.length };
  const stack = [root];
  const token = /<!--[\s\S]*?-->|<!doctype[^>]*>|<\/([a-zA-Z][\w:-]*)\s*>|<([a-zA-Z][\w:-]*)((?:\s+[^\s=/>]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+))?)*)\s*(\/?)>|[^<]+|</gi;
  let m;
  while ((m = token.exec(html))) {
    const top = stack.at(-1);
    if (m[2]) {
      const tag = m[2].toLowerCase();
      const node = { tag, attrs: parseAttrs(m[3]), children: [], parent: top, start: m.index, end: token.lastIndex };
      top.children.push(node);
      if (RAW.has(tag)) {
        const close = html.indexOf(`</${tag}`, token.lastIndex);
        token.lastIndex = html.indexOf(">", close) + 1;
        node.end = token.lastIndex;
      } else if (!m[4] && !VOID.has(tag)) stack.push(node);
    } else if (m[1]) {
      const tag = m[1].toLowerCase();
      const at = stack.findLastIndex((n) => n.tag === tag);
      if (at > 0) {
        stack[at].end = token.lastIndex;
        stack.length = at;
      }
    } else if (m[0][0] !== "<" || m[0] === "<") {
      top.children.push({ tag: "#text", text: decode(m[0]), parent: top });
    }
  }
  return root;
};

const classes = (n) => new Set((n.attrs?.class ?? "").split(/\s+/).filter(Boolean));
const hasClass = (n, c) => classes(n).has(c);
const walk = function* (n) {
  yield n;
  for (const c of n.children ?? []) yield* walk(c);
};
const find = (n, pred) => {
  for (const x of walk(n)) if (x !== n && pred(x)) return x;
  return null;
};
const findAll = (n, pred) => [...walk(n)].filter((x) => x !== n && pred(x));
const textOf = (n) => (n.tag === "#text" ? n.text : (n.children ?? []).map(textOf).join(""));

// ============================================================================
// Page
// ============================================================================

const html = readFileSync(pagePath, "utf8");
const doc = parse(html);
const body = find(doc, (n) => n.attrs?.id === "post-content");
if (!body) fail(`${pagePath} has no #post-content.`);
const title = textOf(find(doc, (n) => hasClass(n, "post-title")) ?? { tag: "#text", text: slug }).trim();
const pageUrl = `${origin}/${relative(site, dirname(pagePath)).split("\\").join("/")}/`;

const t = opts.lang === "zh"
  ? { source: `本文首发于我的博客：[${title}](${pageUrl})`, notes: "注释" }
  : { source: `Originally published on my blog: [${title}](${pageUrl})`, notes: "Notes" };

// Glyph outlines are `<symbol>`s that any SVG on the page may `<use>`
// (scripts/dedupe-svg-glyphs.py), so a figure cut out alone needs them back.
const symbols = new Map();
for (const m of html.matchAll(/<symbol id="([^"]+)"[^>]*>[\s\S]*?<\/symbol>/g)) {
  if (!symbols.has(m[1])) symbols.set(m[1], m[0]);
}

const warnings = [];
const warn = (msg) => warnings.push(msg);

// ============================================================================
// Images
// ============================================================================

mkdirSync(imgDir, { recursive: true });
let figureCount = 0;
let imageCount = 0;
const imageRef = (file) => (opts.imageBase ? `${opts.imageBase}/${file}` : `images/${file}`);
const pad = (n) => String(n).padStart(2, "0");

const run = (cmd, argv) => {
  try {
    execFileSync(cmd, argv, { stdio: ["ignore", "ignore", "pipe"] });
    return true;
  } catch (e) {
    if (e.code !== "ENOENT") warn(`${cmd} failed: ${e.stderr?.toString().trim() || e.message}`);
    return false;
  }
};

/// Renders an inline SVG node to PNG; returns the file name.
const rasterSvg = (svg) => {
  const file = `figure-${pad(++figureCount)}.png`;
  // Typst frames draw right up to (and with `overflow: visible`, past) their
  // edges, so the viewBox gets a margin.
  const margin = 12; // pt
  let src = html.slice(svg.start, svg.end).replace(/^<svg[^>]*>/, (open) => {
    const [x, y, w, h] = (svg.attrs.viewbox ?? "").split(/[\s,]+/).map(Number);
    if ([x, y, w, h].some(Number.isNaN)) return open.replace(/\sstyle="[^"]*"/, "");
    return open
      .replace(/\sstyle="[^"]*"/, "")
      .replace(/\sviewBox="[^"]*"/, ` viewBox="${x - margin} ${y - margin} ${w + 2 * margin} ${h + 2 * margin}"`)
      .replace(/\swidth="[^"]*"/, ` width="${w + 2 * margin}pt"`)
      .replace(/\sheight="[^"]*"/, ` height="${h + 2 * margin}pt"`);
  });
  const own = new Set([...src.matchAll(/<symbol id="([^"]+)"/g)].map((m) => m[1]));
  const used = new Set([...src.matchAll(/href="#([^"]+)"/g)].map((m) => m[1]));
  const defs = [...used].filter((id) => !own.has(id) && symbols.has(id)).map((id) => symbols.get(id));
  if (defs.length) src = src.replace(/^<svg[^>]*>/, (open) => `${open}<defs>${defs.join("")}</defs>`);
  const tmp = join(imgDir, `${file}.svg`);
  writeFileSync(tmp, src);
  if (!run("rsvg-convert", ["-z", "2", "-b", "white", "-o", join(imgDir, file), tmp])) {
    fail("rsvg-convert is needed to render figures: brew install librsvg");
  }
  rmSync(tmp);
  return file;
};

/// Converts a built image (webp) to PNG; returns the file name.
const rasterImg = (img) => {
  const file = `image-${pad(++imageCount)}.png`;
  const src = join(site, decodeURI(img.attrs.src.split("?")[0]));
  const out = join(imgDir, file);
  if (!existsSync(src)) {
    warn(`image ${img.attrs.src} not found in ${site}/`);
    return file;
  }
  if (!run("sips", ["-s", "format", "png", src, "--out", out]) && !run("magick", [src, out])) {
    fail("sips (macOS) or magick (ImageMagick) is needed to convert images to PNG.");
  }
  return file;
};

// ============================================================================
// Markdown
// ============================================================================

const BLOCK = new Set([
  "address", "article", "aside", "blockquote", "dd", "details", "div", "dl", "dt", "fieldset", "figcaption", "figure",
  "footer", "h1", "h2", "h3", "h4", "h5", "h6", "header", "hr", "nav", "ol", "p", "pre", "section", "table", "ul",
]);
const SKIP = new Set(["button", "script", "style", "nav", "template"]);

const escape = (s) => s.replace(/([\\`*_[\]$<])/g, "\\$1");
const codeSpan = (s) => {
  const ticks = "`".repeat(Math.max(0, ...[...s.matchAll(/`+/g)].map((m) => m[0].length)) + 1);
  const pad = s.startsWith("`") || s.endsWith("`") ? " " : "";
  return `${ticks}${pad}${s}${pad}${ticks}`;
};
const wrap = (mark, inner) => {
  const s = inner.trim();
  if (!s) return inner;
  const lead = inner.match(/^\s*/)[0];
  const trail = inner.match(/\s*$/)[0];
  return `${lead}${mark}${s}${mark}${trail}`;
};
const absolute = (href) => (href.startsWith("/") ? origin + href : href);

const latexOf = (n) => {
  const latex = n.attrs["data-latex"] ?? "";
  const issues = n.attrs["data-latex-issues"];
  if (issues || latex.includes("[unsupported formula]")) {
    warn(`formula without LaTeX (${issues ?? "unsupported"}): fix it in the post or write it by hand`);
  }
  return latex;
};
const mathInline = (latex) =>
  opts.math === "image"
    ? `![${latex.replace(/[[\]]/g, "")}](https://www.zhihu.com/equation?tex=${encodeURIComponent(latex)})`
    : `$${latex}$`;
const mathBlock = (latex) =>
  opts.math === "image"
    ? `![${latex.replace(/[[\]]/g, "")}](https://www.zhihu.com/equation?tex=${encodeURIComponent(latex + "\\\\")})`
    : `$$\n${latex}\n$$`;

const isBlock = (n) =>
  n.tag !== "#text" &&
  (BLOCK.has(n.tag) || hasClass(n, "term-credit") || (n.tag === "svg" && n.parent && hasClass(n.parent, "cetz")));

/// Inline Markdown for a node. `ctx.cell` is set inside table cells.
const inline = (n, ctx = {}) => {
  if (n.tag === "#text") return escape(n.text.replace(/\s+/g, " "));
  if (SKIP.has(n.tag)) return "";
  const kids = () => n.children.map((c) => inline(c, ctx)).join("");
  const c = classes(n);
  switch (n.tag) {
    case "strong":
    case "b":
      return wrap("**", kids());
    case "em":
    case "i":
      return wrap("*", kids());
    case "code":
      return codeSpan(textOf(n).replace(/\s+/g, " "));
    case "br":
      return ctx.cell ? "<br>" : "  \n";
    case "img":
      return `![${escape(n.attrs.alt ?? "")}](${imageRef(rasterImg(n))})`;
    case "svg":
      warn("an inline SVG that is not a formula was dropped");
      return "";
    case "sup":
      if (c.has("fnref")) return `[${textOf(n).trim()}]`;
      return kids();
    case "a": {
      const href = n.attrs.href ?? "";
      if (c.has("heading-anchor") || c.has("fn-back") || href.startsWith("#fnref")) return "";
      if (c.has("term-ref") || href.startsWith("#") || href.startsWith("javascript:")) return kids();
      const text = kids();
      return text.trim() ? `[${text}](${absolute(href)})` : "";
    }
    case "span":
      if (c.has("math-inline")) return mathInline(latexOf(n));
      return kids();
    default:
      if (n.attrs?.role === "math") return mathInline(latexOf(n));
      return kids();
  }
};

/// Markdown blocks for a mixed list of children: inline runs become
/// paragraphs, block children render on their own.
const flow = (children, ctx = {}) => {
  const out = [];
  let buf = "";
  const flush = () => {
    const p = buf.replace(/[ \t]+\n/g, (m) => (m.endsWith("  \n") ? m : "\n")).trim();
    if (p) out.push(p);
    buf = "";
  };
  for (const child of children) {
    if (isBlock(child)) {
      flush();
      out.push(...block(child, ctx));
    } else buf += inline(child, ctx);
  }
  flush();
  return out;
};

const quote = (blocks) =>
  blocks.length
    ? [blocks.join("\n\n").split("\n").map((l) => (l ? `> ${l}` : ">")).join("\n")]
    : [];
const indent = (s, by) => s.split("\n").map((l, i) => (i === 0 || !l ? l : by + l)).join("\n");

const list = (n, ctx) => {
  const ordered = n.tag === "ol";
  let num = +(n.attrs.start ?? 1);
  const items = n.children.filter((c) => c.tag === "li").map((li) => {
    const marker = ordered ? `${num++}.` : "-";
    const blocks = flow(li.children, ctx);
    let s = blocks[0] ?? "";
    for (let i = 1; i < blocks.length; i++) {
      const tight = /^(\s*)([-*+]|\d+\.)\s/.test(blocks[i]);
      s += (tight ? "\n" : "\n\n") + blocks[i];
    }
    return `${marker} ${indent(s, " ".repeat(marker.length + 1))}`;
  });
  return items.length ? [items.join("\n")] : [];
};

const table = (n) => {
  const rows = findAll(n, (x) => x.tag === "tr").map((tr) =>
    tr.children
      .filter((c) => c.tag === "td" || c.tag === "th")
      .map((cell) => {
        if (cell.attrs.colspan || cell.attrs.rowspan) warn("a table cell spans several columns or rows; Markdown cannot, check the table");
        return flow(cell.children, { cell: true }).join("<br>").replace(/\n/g, " ").replace(/\|/g, "\\|") || " ";
      }),
  );
  if (!rows.length) return [];
  const width = Math.max(...rows.map((r) => r.length));
  const line = (r) => `| ${[...r, ...Array(width - r.length).fill(" ")].join(" | ")} |`;
  return [[line(rows[0]), `|${" --- |".repeat(width)}`, ...rows.slice(1).map(line)].join("\n")];
};

const codeBlock = (pre) => {
  const code = find(pre, (x) => x.tag === "code") ?? pre;
  let lang = code.attrs?.["data-lang"] ?? "";
  if (lang === "text") lang = "";
  const text = textOf(code).replace(/\n$/, "");
  const fence = "`".repeat(Math.max(3, ...[...text.matchAll(/`{3,}/g)].map((m) => m[0].length + 1)));
  return [`${fence}${lang}\n${text}\n${fence}`];
};

/// Markdown blocks for a block-level node.
const block = (n, ctx = {}) => {
  if (SKIP.has(n.tag)) return [];
  const c = classes(n);
  const kids = () => flow(n.children, ctx);
  switch (n.tag) {
    case "p":
      return kids();
    case "h1":
    case "h2":
    case "h3":
    case "h4":
    case "h5":
    case "h6": {
      const num = find(n, (x) => hasClass(x, "heading-num"));
      const text = n.children.filter((x) => x !== num).map((x) => inline(x, ctx)).join("").trim();
      const level = Math.min(+n.tag[1], 4);
      return [`${"#".repeat(level)} ${num ? `${textOf(num)} ` : ""}${text}`];
    }
    case "ul":
    case "ol":
      return list(n, ctx);
    case "pre":
      return codeBlock(n);
    case "blockquote":
      return quote(kids());
    case "hr":
      return ["---"];
    case "table":
      return table(n);
    case "figcaption":
      return kids().map((p) => `*${p}*`);
    case "svg": {
      const num = n.parent?.parent?.tag === "figure" ? find(n.parent.parent, (x) => hasClass(x, "figure-num")) : null;
      return [`![${num ? textOf(num) : "figure"}](${imageRef(rasterSvg(n))})`];
    }
    case "details": {
      const summary = n.children.find((x) => x.tag === "summary");
      const head = summary ? [`**${summary.children.map((x) => inline(x, ctx)).join("").trim()}**`] : [];
      return [...head, ...flow(n.children.filter((x) => x !== summary), ctx)];
    }
    case "dl":
      return kids(); // dt/dd, possibly wrapped in a <div> per pair
    case "dt": {
      const s = n.children.map((x) => inline(x, ctx)).join("").trim();
      return s ? [`**${s}**`] : [];
    }
    case "dd":
      return kids();
    case "span": // term-credit: the site shows it on a line of its own
      return kids().map((p) => `*${p}*`);
    case "aside":
      if (c.has("callout")) {
        const head = find(n, (x) => hasClass(x, "callout-head"));
        const label = head?.children.find((x) => x.tag === "span");
        const bodyNode = find(n, (x) => hasClass(x, "callout-body"));
        const title = label ? `**${label.children.map((x) => inline(x, ctx)).join("").trim()}**` : null;
        return quote([...(title ? [title] : []), ...(bodyNode ? flow(bodyNode.children, ctx) : [])]);
      }
      if (c.has("hint")) {
        const bodyNode = find(n, (x) => hasClass(x, "hint-body"));
        return quote(bodyNode ? flow(bodyNode.children, ctx) : []);
      }
      return kids();
    case "section":
      if (c.has("footnotes")) {
        const notes = findAll(n, (x) => x.tag === "li").map((li) => {
          const num = (li.attrs.id ?? "").replace(/^fn-/, "");
          return `[${num}] ${flow(li.children, ctx).join(" ")}`;
        });
        return [`## ${t.notes}`, ...notes];
      }
      if (c.has("endnotes")) {
        const label = n.children.find((x) => hasClass(x, "label"));
        return [`## ${label ? textOf(label).trim() : "Terms"}`, ...flow(n.children.filter((x) => x !== label), ctx)];
      }
      return kids();
    case "div":
      if (c.has("math-block") || n.attrs.role === "math") return [mathBlock(latexOf(n))];
      if (c.has("code-block")) {
        const pre = find(n, (x) => x.tag === "pre");
        return pre ? codeBlock(pre) : [];
      }
      if (c.has("label")) {
        const s = kids().join(" ");
        return s ? [`**${s}**`] : [];
      }
      if (c.has("img") || c.has("term-img")) {
        const img = find(n, (x) => x.tag === "img");
        const num = n.parent?.tag === "figure" ? find(n.parent, (x) => hasClass(x, "figure-num")) : null;
        return img ? [`![${escape(num ? textOf(num) : img.attrs.alt ?? "")}](${imageRef(rasterImg(img))})`] : [];
      }
      if (c.has("cetz") || c.has("svg-frame")) {
        const svg = n.children.find((x) => x.tag === "svg");
        return svg ? block(svg, ctx) : kids();
      }
      if (c.has("giscus-mount")) return [];
      return kids();
    default:
      return kids();
  }
};

// ============================================================================
// Output
// ============================================================================

const blocks = [`# ${title}`, `> ${t.source}`, ...flow(body.children)];
const md = blocks.join("\n\n").replace(/\n{3,}/g, "\n\n") + "\n";
const mdPath = join(outDir, `${slug}.md`);
writeFileSync(mdPath, md);
if (figureCount + imageCount === 0) rmSync(imgDir, { recursive: true });

console.log(`${mdPath}`);
console.log(`  title    ${title}`);
console.log(`  figures  ${figureCount} rendered, ${imageCount} images converted${figureCount + imageCount ? ` (${imgDir}/)` : ""}`);
for (const w of new Set(warnings)) {
  const n = warnings.filter((x) => x === w).length;
  console.warn(`warning: ${w}${n > 1 ? ` (×${n})` : ""}`);
}
