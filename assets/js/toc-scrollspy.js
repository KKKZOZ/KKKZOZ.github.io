(() => {
  const toc = document.querySelector(".post-single > .toc");
  const content = document.querySelector(".post-single > .post-content");

  if (!toc || !content) {
    return;
  }

  const tocInner = toc.querySelector(".inner");
  const links = Array.from(toc.querySelectorAll('.inner a[href^="#"]'));
  const linksById = new Map();

  for (const link of links) {
    try {
      linksById.set(decodeURIComponent(link.hash.slice(1)), link);
    } catch {
      // Ignore malformed fragments instead of disabling the whole scrollspy.
    }
  }

  const headings = Array.from(
    content.querySelectorAll("h1[id], h2[id], h3[id], h4[id], h5[id], h6[id]")
  ).filter((heading) => linksById.has(heading.id));

  if (!tocInner || headings.length === 0) {
    return;
  }

  const wideLayout = window.matchMedia("(min-width: 1260px)");
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
  let activeId = "";
  let framePending = false;

  function keepLinkVisible(link) {
    if (!wideLayout.matches || tocInner.scrollHeight <= tocInner.clientHeight) {
      return;
    }

    const containerRect = tocInner.getBoundingClientRect();
    const linkRect = link.getBoundingClientRect();
    const edgePadding = 16;
    const isVisible =
      linkRect.top >= containerRect.top + edgePadding &&
      linkRect.bottom <= containerRect.bottom - edgePadding;

    if (isVisible) {
      return;
    }

    const top =
      tocInner.scrollTop +
      linkRect.top -
      containerRect.top -
      tocInner.clientHeight / 2 +
      linkRect.height / 2;

    tocInner.scrollTo({
      top,
      behavior: reducedMotion.matches ? "auto" : "smooth",
    });
  }

  function setActive(id) {
    if (!id || id === activeId) {
      return;
    }

    const activeLink = linksById.get(id);
    if (!activeLink) {
      return;
    }

    for (const link of links) {
      const isActive = link === activeLink;
      link.classList.toggle("is-active", isActive);
      if (isActive) {
        link.setAttribute("aria-current", "location");
      } else {
        link.removeAttribute("aria-current");
      }
    }

    activeId = id;
    keepLinkVisible(activeLink);
  }

  function updateActiveHeading() {
    framePending = false;
    const marker = Math.max(96, window.innerHeight * 0.2);
    let current = headings[0];

    for (const heading of headings) {
      if (heading.getBoundingClientRect().top > marker) {
        break;
      }
      current = heading;
    }

    setActive(current.id);
  }

  function scheduleUpdate() {
    if (!framePending) {
      framePending = true;
      window.requestAnimationFrame(updateActiveHeading);
    }
  }

  const observer = new IntersectionObserver(scheduleUpdate, {
    rootMargin: "-20% 0px -75% 0px",
  });

  for (const heading of headings) {
    observer.observe(heading);
  }

  window.addEventListener("scroll", scheduleUpdate, { passive: true });
  window.addEventListener("resize", scheduleUpdate, { passive: true });
  window.addEventListener("hashchange", scheduleUpdate);
  scheduleUpdate();
})();
