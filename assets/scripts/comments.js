// giscus comments (templates/comments.typ). Loads the client with the
// settings on .giscus-mount and the site's current theme, then follows the
// day / night toggle (theme.js sets data-theme on <html>).
(() => {
  const mount = document.querySelector(".giscus-mount");
  if (!mount) return;
  const root = document.documentElement;
  const giscusTheme = () => (root.dataset.theme === "dark" ? "dark" : "light");

  const script = document.createElement("script");
  script.src = "https://giscus.app/client.js";
  script.async = true;
  script.crossOrigin = "anonymous";
  const settings = {
    ...mount.dataset,
    strict: "0",
    reactionsEnabled: "1",
    emitMetadata: "0",
    inputPosition: "top",
    lang: "en",
    loading: "lazy",
    theme: giscusTheme(),
  };
  for (const [key, value] of Object.entries(settings)) script.dataset[key] = value;
  mount.after(script);

  new MutationObserver(() => {
    const frame = document.querySelector("iframe.giscus-frame");
    frame?.contentWindow.postMessage({ giscus: { setConfig: { theme: giscusTheme() } } }, "https://giscus.app");
  }).observe(root, { attributes: true, attributeFilter: ["data-theme"] });
})();
