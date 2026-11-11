/* ==========================================================================
   DineCircle Admin — application shell
   Sign in, persistent sidebar, topbar, hash router, command palette and the
   shared action dispatcher every module plugs into.
   ========================================================================== */

import { state, session, signIn, counts, subscribe, resetAll, initialsOf } from "./store.js";
import { navigate, currentRoute, setRefresh } from "./router.js";
import { icon, esc, avatar, openDrawer, closeDrawer, toast, openModal } from "./ui.js";
import { notificationItems } from "./data.js";

import dashboardView from "./views/dashboard.js";
import applicationsView from "./views/applications.js";
import restaurantsView from "./views/restaurants.js";
import accountsView from "./views/accounts.js";
import subscriptionsView from "./views/subscriptions.js";
import customersView from "./views/customers.js";
import hostsView from "./views/hosts.js";
import experiencesView from "./views/experiences.js";
import dealsView from "./views/deals.js";
import reportsView from "./views/reports.js";
import analyticsView from "./views/analytics.js";
import settingsView from "./views/settings.js";

const views = {
  dashboard: dashboardView,
  applications: applicationsView,
  restaurants: restaurantsView,
  accounts: accountsView,
  subscriptions: subscriptionsView,
  customers: customersView,
  hosts: hostsView,
  experiences: experiencesView,
  deals: dealsView,
  reports: reportsView,
  analytics: analyticsView,
  settings: settingsView,
};

const NAV_GROUPS = [
  {
    label: "Overview",
    items: [
      { key: "dashboard", label: "Dashboard", icon: "dashboard" },
      { key: "analytics", label: "Basic Analytics", icon: "chart" },
    ],
  },
  {
    label: "Partners",
    items: [
      { key: "applications", label: "Partner Applications", icon: "inbox", count: "pendingApplications" },
      { key: "restaurants", label: "Restaurant Management", icon: "store" },
      { key: "accounts", label: "Partner Accounts", icon: "users" },
      { key: "subscriptions", label: "Subscriptions & Payments", icon: "card", count: "pendingReceipts" },
    ],
  },
  {
    label: "Community",
    items: [
      { key: "customers", label: "Customer Management", icon: "user" },
      { key: "hosts", label: "Host Management", icon: "host", count: "flaggedHosts" },
      { key: "experiences", label: "Experience Management", icon: "calendar", count: "pendingExperiences" },
    ],
  },
  {
    label: "Trust & content",
    items: [
      { key: "deals", label: "Deals & Content", icon: "tag", count: "flaggedDeals" },
      { key: "reports", label: "Reports & Safety", icon: "shield", count: "openReports" },
    ],
  },
  {
    label: "System",
    items: [{ key: "settings", label: "Platform Settings", icon: "settings" }],
  },
];

const appRoot = document.getElementById("app");
let routeCleanups = [];

/* --------------------------------------------------------------------------
   Brand / shell fragments
   -------------------------------------------------------------------------- */
function brandMark() {
  return `<span class="brand-mark" aria-hidden="true">
    <svg viewBox="0 0 48 48" focusable="false">
      <defs>
        <linearGradient id="dcAdminArc" x1="8" y1="4" x2="40" y2="44" gradientUnits="userSpaceOnUse">
          <stop offset="0" stop-color="#FDBA74"></stop>
          <stop offset="1" stop-color="#F97316"></stop>
        </linearGradient>
      </defs>
      <path d="M24 6a18 18 0 1 0 18 18" fill="none" stroke="url(#dcAdminArc)" stroke-width="5" stroke-linecap="round"></path>
      <path class="brand-fork" d="M20 15v5a4 4 0 0 0 8 0v-5M24 15v5.5M24 24v9" fill="none" stroke-width="2.4" stroke-linecap="round"></path>
    </svg>
  </span>`;
}

function navMarkup() {
  const badge = counts();
  return NAV_GROUPS.map((group) => {
    const links = group.items
      .map((item) => {
        const count = item.count ? badge[item.count] : 0;
        return `<li><a class="nav__link" href="#/${item.key}" data-nav="${item.key}" data-navlink>
          ${icon(item.icon)}
          <span>${esc(item.label)}</span>
          ${count ? `<span class="nav__count">${count}</span>` : ""}
        </a></li>`;
      })
      .join("");
    return `<div class="nav__group">
      <p class="nav__label">${esc(group.label)}</p>
      <ul>${links}</ul>
    </div>`;
  }).join("");
}

function shellMarkup(admin) {
  const badge = counts();
  return `<div class="shell">
    <aside class="sidebar" id="sidebar" aria-label="Admin sections">
      <div class="sidebar__top">
        <a class="brand" href="#/dashboard" aria-label="DineCircle Admin home">
          ${brandMark()}
          <span class="brand-word">Dine<span>Circle</span><small>Admin console</small></span>
        </a>
        <button class="icon-btn sidebar__close" type="button" data-sidebar-close aria-label="Close navigation">${icon("x")}</button>
      </div>
      <nav class="nav" id="nav">${navMarkup()}</nav>
      <div class="sidebar__foot">
        <button class="sidebar__user" type="button" data-account>
          ${avatar(admin.name, "sm")}
          <span>
            <strong>${esc(admin.name)}</strong>
            <span>${esc(admin.role)}</span>
          </span>
          ${icon("chevron")}
        </button>
      </div>
    </aside>

    <div class="main">
      <header class="topbar">
        <button class="icon-btn topbar__menu" type="button" data-sidebar-open aria-label="Open navigation">${icon("menu")}</button>
        <button class="topbar__search" type="button" data-palette aria-label="Search the admin panel">
          ${icon("search")}<span>Search venues, partners, reports</span><kbd>Ctrl K</kbd>
        </button>
        <div class="topbar__right">
          <span class="topbar__proto">Prototype data</span>
          <button class="icon-btn" type="button" data-notifications aria-label="Notifications${badge.openReports ? `, ${badge.openReports} open reports` : ""}">
            ${icon("bell")}<span class="icon-btn__dot"></span>
          </button>
          <button class="icon-btn" type="button" data-account aria-label="Account menu">${icon("user")}</button>
        </div>
      </header>
      <main class="page" id="view" tabindex="-1"></main>
    </div>
  </div>`;
}

/* --------------------------------------------------------------------------
   Sign in
   -------------------------------------------------------------------------- */
const ROLES = ["Super admin", "Operations admin", "Trust and safety", "Finance admin", "Support admin"];
let selectedRole = "Super admin";

function renderLogin() {
  document.title = "Sign in · DineCircle Admin";
  appRoot.className = "auth";
  appRoot.innerHTML = `
    <section class="auth__aside">
      <a class="auth__brand brand" href="#/dashboard">${brandMark()}
        <span class="brand-word">Dine<span>Circle</span><small>Admin console</small></span>
      </a>
      <div class="auth__headline">
        <span class="eyebrow">Karachi pilot · operations</span>
        <h2>One console for every dining partner.</h2>
        <p>Review restaurant applications, activate Partner Pro subscriptions, moderate experiences and keep the customer app trustworthy. This prototype is front-end only and uses sample data.</p>
      </div>
      <div class="auth__facts">
        <span class="auth__fact">${icon("store")} 128 restaurants</span>
        <span class="auth__fact">${icon("users")} 96 active partners</span>
        <span class="auth__fact">${icon("shield")} 0% booking commission</span>
      </div>
    </section>
    <section class="auth__panel">
      <form class="auth__form" id="signinForm" novalidate>
        <span class="eyebrow">Admin access</span>
        <h1>Sign in</h1>
        <p>Use your DineCircle admin account to continue.</p>
        <div class="field">
          <label for="adminEmail">Email address</label>
          <input class="input" id="adminEmail" name="email" type="email" value="ayesha@dinecircle.app" autocomplete="username" required>
        </div>
        <div class="field">
          <label for="adminPassword">Password</label>
          <input class="input" id="adminPassword" name="password" type="password" value="dinecircle" autocomplete="current-password" required>
        </div>
        <div class="field">
          <span class="field__label">Sign in as</span>
          <div class="auth__role" role="group" aria-label="Admin role">
            ${ROLES.map(
              (role) => `<button type="button" data-role="${role}" aria-pressed="${role === selectedRole}">
                ${esc(role)}<span>${esc(roleScope(role))}</span>
              </button>`
            ).join("")}
          </div>
        </div>
        <button class="btn btn--primary btn--block" type="submit" style="margin-top:20px">Sign in to admin</button>
        <p class="auth__note"><strong>Prototype:</strong> no credentials are checked and nothing leaves this browser. Choose a role to preview how access scope is described.</p>
      </form>
    </section>`;

  appRoot.querySelectorAll("[data-role]").forEach((button) => {
    button.addEventListener("click", () => {
      selectedRole = button.dataset.role;
      appRoot.querySelectorAll("[data-role]").forEach((other) => {
        other.setAttribute("aria-pressed", String(other === button));
      });
    });
  });

  appRoot.querySelector("#signinForm").addEventListener("submit", (event) => {
    event.preventDefault();
    const email = appRoot.querySelector("#adminEmail").value.trim();
    if (!email) {
      toast("Enter an admin email address", "danger");
      return;
    }
    const admin = signIn(selectedRole);
    admin.email = email;
    session.start(admin);
    renderApp();
    toast(`Signed in as ${admin.name}`);
  });
}

function roleScope(role) {
  return {
    "Super admin": "Full platform",
    "Operations admin": "Partners and venues",
    "Trust and safety": "Reports, content, hosts",
    "Finance admin": "Subscriptions and receipts",
    "Support admin": "Customers and hosts",
  }[role] || "";
}

/* --------------------------------------------------------------------------
   App shell
   -------------------------------------------------------------------------- */
function renderApp() {
  const admin = session.get();
  if (!admin) {
    renderLogin();
    return;
  }
  appRoot.className = "";
  appRoot.innerHTML = shellMarkup(admin);
  bindShell();
  renderRoute();
}

function bindShell() {
  const sidebar = appRoot.querySelector("#sidebar");
  appRoot.querySelector("[data-sidebar-open]")?.addEventListener("click", () => sidebar.classList.add("is-open"));
  appRoot.querySelector("[data-sidebar-close]")?.addEventListener("click", () => sidebar.classList.remove("is-open"));
  appRoot.querySelector("[data-palette]")?.addEventListener("click", openPalette);
  appRoot.querySelector("[data-notifications]")?.addEventListener("click", openNotifications);
  appRoot.querySelectorAll("[data-account]").forEach((button) => button.addEventListener("click", openAccount));
  appRoot.querySelectorAll("[data-navlink]").forEach((link) =>
    link.addEventListener("click", () => sidebar.classList.remove("is-open"))
  );
}

function refreshChrome() {
  const admin = session.get();
  if (!admin) return;
  const nav = appRoot.querySelector("#nav");
  if (nav) nav.innerHTML = navMarkup();
  document.querySelectorAll("[data-navlink]").forEach((link) => {
    link.setAttribute("aria-current", link.dataset.nav === currentRoute() ? "page" : "false");
    if (link.dataset.nav !== currentRoute()) link.removeAttribute("aria-current");
  });
  const userButton = appRoot.querySelector(".sidebar__user");
  if (userButton) {
    userButton.innerHTML = `${avatar(admin.name, "sm")}<span><strong>${esc(admin.name)}</strong><span>${esc(admin.role)}</span></span>${icon("chevron")}`;
  }
}

export function refresh() {
  refreshChrome();
  renderRoute();
}

function renderRoute() {
  const admin = session.get();
  if (!admin) return;
  routeCleanups.forEach((fn) => {
    try {
      fn();
    } catch {
      /* ignore */
    }
  });
  routeCleanups = [];

  const key = views[currentRoute()] ? currentRoute() : "dashboard";
  const view = views[key];
  const page = appRoot.querySelector("#view");
  if (!page) return;

  const result = view.render({ go: navigate, refresh }) || {};
  document.title = `${result.title || view.title} · DineCircle Admin`;
  page.innerHTML = `
    <header class="page__head">
      <div class="page__head-text">
        <span class="eyebrow">${esc(result.eyebrow || view.eyebrow || "")}</span>
        <h1>${esc(result.title || view.title)}</h1>
        ${result.description ? `<p>${esc(result.description)}</p>` : ""}
      </div>
      ${result.actions ? `<div class="page__actions">${result.actions}</div>` : ""}
    </header>
    <div class="stack">${result.body || ""}</div>`;

  const activeNav = appRoot.querySelector(`[data-navlink][data-nav="${key}"]`);
  if (activeNav) activeNav.setAttribute("aria-current", "page");
  if (typeof result.mount === "function") result.mount(page);
  window.scrollTo({ top: 0, behavior: "instant" in window ? "instant" : "auto" });
}

/* --------------------------------------------------------------------------
   Global clicks: [data-action], pager, overlay close
   -------------------------------------------------------------------------- */
document.addEventListener("click", (event) => {
  const closer = event.target.closest("[data-close-overlay]");
  if (closer) {
    closeDrawer();
    return;
  }

  const pageButton = event.target.closest("[data-page]");
  if (pageButton) {
    const view = views[currentRoute()];
    const page = Number(pageButton.dataset.page);
    if (!pageButton.disabled && typeof view?.setPage === "function") {
      view.setPage(page, pageButton.dataset.pageGroup);
      refresh();
    }
    return;
  }

  const actionEl = event.target.closest("[data-action]");
  if (!actionEl) return;
  const name = actionEl.dataset.action;
  const id = actionEl.dataset.id;
  const view = views[currentRoute()];
  const handler = view?.actions?.[name];
  if (!handler) {
    if (name === "noop") event.preventDefault();
    return;
  }
  if (actionEl.tagName === "A" && !actionEl.getAttribute("href")) event.preventDefault();
  if (actionEl.tagName === "BUTTON") event.preventDefault();
  handler(id, actionEl, event);
});

document.addEventListener("keydown", (event) => {
  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "k") {
    event.preventDefault();
    if (session.get()) openPalette();
  }
});

window.addEventListener("hashchange", () => {
  if (session.get()) refresh();
});

subscribe(() => {
  if (session.get()) refreshChrome();
});

/* --------------------------------------------------------------------------
   Notifications, account, command palette
   -------------------------------------------------------------------------- */
function openNotifications() {
  const items = notificationItems
    .map(
      (item) => `<li class="list__item">
        <span class="avatar avatar--sm avatar--orange">${icon(item.kind === "danger" ? "alert" : item.kind === "warn" ? "clock" : "bell")}</span>
        <div><strong>${esc(item.title)}</strong><p>${esc(item.detail)}</p></div>
        <div class="list__side"><span class="badge badge--${item.kind === "danger" ? "danger" : item.kind === "warn" ? "warn" : item.kind === "info" ? "info" : "orange"}">${esc(item.kind === "danger" ? "Urgent" : item.kind === "warn" ? "Due" : "New")}</span></div>
      </li>`
    )
    .join("");
  openDrawer({
    title: "Notifications",
    subtitle: "Operational items raised in the last 24 hours",
    body: `<ul class="list" style="margin:0 -22px">${items}</ul>
      <div class="note" style="margin-top:18px">${icon("bell")}<span>Notifications are sample data. Wiring this to the server would use the existing <strong>/api/partner/notifications</strong> pattern with an admin channel.</span></div>`,
    foot: `<button class="btn btn--outline" type="button" data-close-overlay>Close</button>
      <button class="btn btn--primary" type="button" data-close-overlay>Mark all as read</button>`,
  });
}

function openAccount() {
  const admin = session.get();
  if (!admin) return;
  openDrawer({
    title: admin.name,
    subtitle: `${admin.role} · ${admin.scope}`,
    body: `
      <div class="person-head" style="margin-bottom:18px">
        ${avatar(admin.name, "lg")}
        <div><h2>${esc(admin.name)}</h2><p>${esc(admin.email)}</p></div>
      </div>
      <dl class="detail-grid">
        <div><dt>Role</dt><dd>${esc(admin.role)}</dd></div>
        <div><dt>Access scope</dt><dd>${esc(admin.scope)}</dd></div>
        <div><dt>Environment</dt><dd>Prototype · sample data</dd></div>
        <div><dt>Signed in</dt><dd>This browser</dd></div>
      </dl>
      <hr class="divider">
      <h3 style="margin-bottom:8px">Session</h3>
      <p style="font-size:.8rem;color:var(--muted)">Signing out clears this browser session. Demo data stays available for the next sign in.</p>`,
    foot: `<button class="btn btn--outline" type="button" data-close-overlay>Cancel</button>
      <button class="btn btn--primary" type="button" id="signOutBtn">${icon("logout")} Sign out</button>`,
  });
  document.getElementById("signOutBtn")?.addEventListener("click", () => {
    session.end();
    closeDrawer();
    const boot = document.getElementById("app");
    boot.innerHTML = "";
    renderLogin();
    toast("Signed out of the admin console");
  });
}

function paletteItems() {
  const navItems = NAV_GROUPS.flatMap((group) =>
    group.items.map((item) => ({ group: group.label, label: item.label, icon: item.icon, key: item.key }))
  );
  const records = [
    ...state.applications.slice(0, 6).map((item) => ({ group: "Applications", label: `${item.restaurant} · ${item.id}`, icon: "flag", key: "applications" })),
    ...state.restaurants.slice(0, 8).map((item) => ({ group: "Restaurants", label: item.name, icon: "store", key: "restaurants" })),
    ...state.reports.slice(0, 5).map((item) => ({ group: "Reports", label: `${item.subject} · ${item.id}`, icon: "shield", key: "reports" })),
  ];
  return [...navItems, ...records];
}

function openPalette() {
  if (document.querySelector(".palette")) return;
  const items = paletteItems();
  let filtered = items;
  let active = 0;
  const overlay = document.createElement("div");
  overlay.className = "palette";
  overlay.innerHTML = `<div class="palette__card" role="dialog" aria-modal="true" aria-label="Search admin">
    <input class="palette__input" type="search" placeholder="Search pages, venues, partners or reports" aria-label="Search" autocomplete="off">
    <div class="palette__list" role="listbox"></div>
  </div>`;
  document.body.append(overlay);
  const input = overlay.querySelector("input");
  const list = overlay.querySelector(".palette__list");

  const draw = () => {
    const groups = [...new Set(filtered.map((item) => item.group))];
    if (!filtered.length) {
      list.innerHTML = `<p class="palette__empty">No matches. Try a venue, partner or report number.</p>`;
      return;
    }
    let index = 0;
    list.innerHTML = groups
      .map((group) => {
        const rows = filtered
          .filter((item) => item.group === group)
          .map((item) => {
            const current = index++;
            return `<button class="palette__item ${current === active ? "is-active" : ""}" type="button" role="option" data-index="${current}">
              ${icon(item.icon)}${esc(item.label)}<span>${esc(group)}</span></button>`;
          })
          .join("");
        return `<p class="palette__group">${esc(group)}</p>${rows}`;
      })
      .join("");
    list.querySelectorAll("[data-index]").forEach((button) => {
      button.addEventListener("click", () => choose(Number(button.dataset.index)));
    });
  };

  const choose = (index) => {
    const item = filtered[index];
    if (!item) return;
    close();
    const same = currentRoute() === item.key;
    navigate(item.key);
    // Already on the route: no hashchange fires, so repaint by hand.
    if (same) renderRoute();
  };

  const close = () => {
    overlay.remove();
    document.removeEventListener("keydown", onKey);
  };

  const onKey = (event) => {
    if (event.key === "Escape") close();
    if (event.key === "ArrowDown") {
      event.preventDefault();
      active = Math.min(active + 1, filtered.length - 1);
      draw();
    }
    if (event.key === "ArrowUp") {
      event.preventDefault();
      active = Math.max(active - 1, 0);
      draw();
    }
    if (event.key === "Enter") {
      event.preventDefault();
      choose(active);
    }
  };

  input.addEventListener("input", () => {
    const query = input.value.trim().toLowerCase();
    filtered = query
      ? items.filter((item) => item.label.toLowerCase().includes(query) || item.group.toLowerCase().includes(query))
      : items;
    active = 0;
    draw();
  });
  overlay.addEventListener("click", (event) => {
    if (event.target === overlay) close();
  });
  document.addEventListener("keydown", onKey);
  draw();
  input.focus();
}

/* --------------------------------------------------------------------------
   Boot
   -------------------------------------------------------------------------- */
if (!location.hash) location.hash = "#/dashboard";
setRefresh(refresh);
renderApp();

// Expose a couple of helpers for the prototype console only.
window.dinecircleAdmin = {
  reset: () => {
    resetAll();
    toast("Demo data restored");
    refresh();
  },
  openModal,
  initialsOf,
};
