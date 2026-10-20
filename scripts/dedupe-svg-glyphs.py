"""Drop repeated glyph definitions from Typst's inline SVGs.

Every `html.frame` SVG carries its own `<symbol id="g...">` outline for each
glyph it uses. The ids are content hashes, so the same glyph has the same id
in every frame, and `<use href="#g...">` resolves against the whole document.
Keeping the first definition of each id is enough; on a page with many cetz
figures this removes most of the SVG weight.

Run after `tola build`:  python3 scripts/dedupe-svg-glyphs.py [public]
"""

import pathlib
import re
import sys

SYMBOL = re.compile(r'<symbol id="([^"]+)"[^>]*>.*?</symbol>', re.S)


def dedupe(html):
    seen = {}

    def keep_first(m):
        sid = m.group(1)
        if sid not in seen:
            seen[sid] = m.group(0)
            return m.group(0)
        # Same id must mean the same outline; otherwise leave it alone.
        return "" if seen[sid] == m.group(0) else m.group(0)

    return SYMBOL.sub(keep_first, html)


def main(root):
    saved = 0
    for path in pathlib.Path(root).rglob("*.html"):
        html = path.read_text(encoding="utf-8")
        if "<symbol" not in html:
            continue
        out = dedupe(html)
        if len(out) < len(html):
            saved += len(html) - len(out)
            path.write_text(out, encoding="utf-8")
    print(f"dedupe-svg-glyphs: removed {saved / 1024:.0f} KB")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "public")
