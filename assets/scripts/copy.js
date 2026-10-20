// Copy buttons on code blocks and click-to-copy heading anchors.
// Idempotent: safe to run more than once on the same page.
(() => {
  const copy = async (text) => {
    try {
      await navigator.clipboard.writeText(text);
    } catch {
      // Clipboard API needs a secure context; fall back to a hidden textarea.
      const t = Object.assign(document.createElement("textarea"), { value: text });
      t.style.cssText = "position:fixed;opacity:0";
      document.body.append(t);
      t.select();
      document.execCommand("copy");
      t.remove();
    }
  };

  // Flag an element as copied for a moment (CSS shows the feedback);
  // `label` temporarily replaces its text.
  const flash = (el, label) => {
    el._label ??= el.textContent;
    if (label) el.textContent = label;
    el.classList.add("is-copied");
    clearTimeout(el._copyTimer);
    el._copyTimer = setTimeout(() => {
      el.classList.remove("is-copied");
      el.textContent = el._label;
    }, 1500);
  };

  for (const btn of document.querySelectorAll(".code-copy")) {
    if (btn.dataset.bound) continue;
    btn.dataset.bound = "1";
    btn.hidden = false;
    btn.addEventListener("click", () => {
      // innerText turns the <br> line breaks of highlighted code into "\n".
      copy(btn.closest(".code-block").querySelector("pre").innerText);
      flash(btn, "Copied");
    });
  }

  // Anchors still navigate as plain links; the full URL is copied on top.
  for (const a of document.querySelectorAll(".heading-anchor")) {
    if (a.dataset.bound) continue;
    a.dataset.bound = "1";
    a.addEventListener("click", () => {
      copy(a.href);
      flash(a);
    });
  }
})();
