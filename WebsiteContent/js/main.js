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
    toggle.addEventListener("click", () => {
      const open = nav.classList.toggle("open");
      toggle.setAttribute("aria-expanded", String(open));
    });
  }

  // Support page: "Copy" puts the support address on the clipboard
  // (handy when the device has no mail app set up).
  document.querySelectorAll("[data-copy]").forEach((button) => {
    button.addEventListener("click", async () => {
      const status = document.querySelector(button.dataset.status);
      try {
        await navigator.clipboard.writeText(button.dataset.copy);
        if (status) status.textContent = "Copied!";
      } catch {
        if (status) status.textContent = button.dataset.copy;
      }
    });
  });

  // FAQ links like support.html#reminders open that question directly.
  if (location.hash) {
    const target = document.querySelector(location.hash);
    if (target && target.tagName === "DETAILS") target.open = true;
  }
});
