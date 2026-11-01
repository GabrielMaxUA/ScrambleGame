// LearnScrumble website — small helpers shared by every page.
// Everything works without JavaScript too; this only adds conveniences.

document.addEventListener("DOMContentLoaded", () => {
  // Footer year: "© 2026 …" stays current without editing every page.
  document.querySelectorAll("[data-year]").forEach((el) => {
    el.textContent = new Date().getFullYear();
  });

  // Phone-width menu: the "Menu" button opens and closes the navigation.
  const toggle = document.querySelector(".nav-toggle");
  const nav = document.querySelector(".site-nav");
  if (toggle && nav) {
    const setOpen = (open) => {
      nav.classList.toggle("open", open);
      toggle.setAttribute("aria-expanded", String(open));
    };
    toggle.addEventListener("click", (event) => {
      event.stopPropagation();
      setOpen(!nav.classList.contains("open"));
    });
    // Close it again: tapping a link, tapping anywhere else, or pressing Escape.
    nav.addEventListener("click", (event) => {
      if (event.target.closest("a")) setOpen(false);
    });
    document.addEventListener("click", (event) => {
      if (!nav.contains(event.target)) setOpen(false);
    });
    document.addEventListener("keydown", (event) => {
      if (event.key === "Escape") setOpen(false);
    });
  }

  // Support page: "Copy" puts the support address on the clipboard
  // (handy when the device has no mail app set up).
  document.querySelectorAll("[data-copy]").forEach((button) => {
    button.addEventListener("click", async () => {
      const status = document.querySelector(button.dataset.status);
      try {
        await navigator.clipboard.writeText(button.dataset.copy);
        if (status) status.textContent = pageLang === "fr" ? "Copié !" : "Copied!";
      } catch {
        if (status) status.textContent = button.dataset.copy;
      }
    });
  });

  // Language (EN | FR switch in the header). The pages exist in English (/) and French (/fr/); the other version of
  // the current page is the <link rel="alternate" hreflang> in its <head>.
  //   - a tap on EN / FR remembers the choice (localStorage "lang");
  //   - a page opened in the other language than the remembered one (e.g. the app's link) switches to it;
  //   - a French browser with no choice yet sees a one-line hint on English pages (no automatic redirect).
  const pageLang = (document.documentElement.lang || "en").slice(0, 2);
  const otherLang = pageLang === "fr" ? "en" : "fr";
  const other = document.querySelector(`link[rel="alternate"][hreflang="${otherLang}"]`);
  let saved = null;
  try { saved = localStorage.getItem("lang"); } catch {}
  const remember = (lang) => { try { localStorage.setItem("lang", lang); } catch {} };
  document.querySelectorAll("[data-set-lang]").forEach((link) => {
    link.addEventListener("click", () => remember(link.dataset.setLang));
  });
  if (other && saved === otherLang) {
    location.replace(other.href + location.hash);
    return;
  }
  const browserFrench = (navigator.languages || [navigator.language]).some((l) => (l || "").toLowerCase().startsWith("fr"));
  if (other && !saved && pageLang === "en" && browserFrench) {
    const hint = document.createElement("div");
    hint.className = "lang-hint";
    hint.lang = "fr";
    hint.innerHTML = `<span>Ce site existe aussi en français.</span> <a href="${other.href}">Version française</a>`;
    const close = document.createElement("button");
    close.setAttribute("aria-label", "Fermer");
    close.textContent = "×";
    close.addEventListener("click", () => { remember("en"); hint.remove(); });
    hint.append(close);
    hint.querySelector("a").addEventListener("click", () => remember("fr"));
    document.querySelector(".site-header")?.after(hint);
  }

  // FAQ links like support.html#reminders open that question directly.
  if (location.hash) {
    const target = document.querySelector(location.hash);
    if (target && target.tagName === "DETAILS") target.open = true;
  }
});
