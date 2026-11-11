/* ==========================================================================
   Module: Partner Accounts (P0)
   Staff logins for the partner app: who owns which restaurant, what role they
   hold, and access control (invites, password resets, 2FA, suspension).
   ========================================================================== */
import { state, commit, relativeTime } from "../store.js";
import { icon, esc, avatar, statusBadge, openDrawer, closeDrawer, openModal, toast, pager, matches } from "../ui.js";
import { dataTable, searchField, selectField } from "./shared.js";

const PER_PAGE = 8;
const filters = { q: "", role: "all", status: "all", page: 1 };

const ROLES = [
  { value: "Partner owner", label: "Partner owner", note: "Full access including subscription and team" },
  { value: "Venue manager", label: "Venue manager", note: "Menu, deals, reservations, experiences" },
  { value: "Reservations staff", label: "Reservations staff", note: "Reservation inbox only" },
  { value: "Content editor", label: "Content editor", note: "Menu and deal publishing only" },
];

function roleTone(role) {
  if (role === "Partner owner") return "role-tag role-tag--owner";
  if (role === "Reservations staff") return "role-tag role-tag--support";
  return "role-tag";
}

function visible() {
  return state.partnerAccounts.filter((row) => {
    if (filters.role !== "all" && row.role !== filters.role) return false;
    if (filters.status !== "all" && row.status !== filters.status) return false;
    if (filters.q && !matches(`${row.name} ${row.email} ${row.restaurants.join(" ")} ${row.id}`, filters.q)) return false;
    return true;
  });
}

function pageRows() {
  const rows = visible();
  const start = (filters.page - 1) * PER_PAGE;
  return rows.slice(start, start + PER_PAGE);
}

function redraw() {
  const region = document.getElementById("region");
  if (region) region.innerHTML = regionHtml();
}

function venueOptions(forAccount) {
  return state.restaurants.map(
    (venue) => `<label style="display:flex;gap:9px;align-items:center;padding:7px 0;font-size:.82rem">
      <input type="checkbox" value="${esc(venue.name)}" data-venue-scope ${forAccount?.restaurants.includes(venue.name) ? "checked" : ""}>
      ${esc(venue.name)} <span style="color:var(--muted);font-size:.75rem">· ${esc(venue.area)}</span>
    </label>`
  ).join("");
}

function updateStatus(ids, status, action, kind) {
  const rows = state.partnerAccounts.filter((row) => ids.includes(row.id));
  if (!rows.length) return;
  commit({
    action,
    target: rows.map((row) => `${row.name} (${row.email})`).join(", "),
    kind,
    apply: () => rows.forEach((row) => { row.status = status; }),
  });
  toast(`${rows.length} account${rows.length === 1 ? "" : "s"} ${status}`);
}

function drawer(row) {
  openDrawer({
    title: row.name,
    subtitle: `${row.id} · ${row.role}`,
    tone: row.status === "suspended" ? "danger" : "orange",
    body: `
      <div class="person-head" style="margin-bottom:18px">
        ${avatar(row.name, "lg")}
        <div><h2>${esc(row.name)}</h2><p>${esc(row.email)}</p></div>
        <span style="margin-left:auto">${statusBadge(row.status)}</span>
      </div>
      <dl class="detail-grid">
        <div><dt>Role</dt><dd><span class="${roleTone(row.role)}">${esc(row.role)}</span></dd></div>
        <div><dt>Venues</dt><dd>${row.restaurants.length}</dd></div>
        <div><dt>Last active</dt><dd>${esc(relativeTime(row.lastActive))}</dd></div>
        <div><dt>Two factor</dt><dd>${row.twoFactor ? "Enabled" : "Not enabled"}</dd></div>
        <div><dt>Invited</dt><dd>${row.status === "invited" ? "Awaiting first sign in" : "Accepted"}</dd></div>
        <div><dt>App sessions</dt><dd>${row.status === "suspended" ? 0 : row.restaurants.length > 1 ? 3 : 2}</dd></div>
      </dl>
      <hr class="divider">
      <h3 style="margin-bottom:8px">Assigned restaurants</h3>
      <ul class="list" style="margin:0 -22px">
        ${row.restaurants
          .map((venue) => {
            const record = state.restaurants.find((item) => item.name === venue);
            return `<li class="list__item">
              ${avatar(venue)}
              <div><strong>${esc(venue)}</strong><p>${esc(record?.area || "Venue record not found")}</p></div>
              <div class="list__side">${record ? statusBadge(record.status) : `<span class="badge badge--danger">Missing</span>`}</div>
            </li>`;
          })
          .join("")}
      </ul>
      <hr class="divider">
      <h3 style="margin-bottom:8px">What this role can do</h3>
      <ul style="display:flex;flex-direction:column;gap:6px;font-size:.82rem;color:var(--ink-soft)">
        <li style="display:flex;gap:8px">${icon("check")} ${esc(ROLES.find((role) => role.value === row.role)?.note || "Menu, deals and reservation management")}</li>
        <li style="display:flex;gap:8px">${icon("check")} Cannot change the subscription plan or billing details unless a partner owner.</li>
        <li style="display:flex;gap:8px">${icon("check")} Cannot create new staff logins unless a partner owner.</li>
      </ul>
      <hr class="divider">
      <div class="row" style="gap:8px">
        <button class="btn btn--outline btn--sm" type="button" data-action="toggleTwoFactor" data-id="${row.id}">${icon("shield")} ${row.twoFactor ? "Require re enrolment" : "Require two factor"}</button>
        ${row.status === "invited" ? `<button class="btn btn--outline btn--sm" type="button" data-action="resendInvite" data-id="${row.id}">${icon("mail")} Resend invite</button>` : ""}
        <span class="spacer"></span>
        <button class="btn btn--danger-ghost btn--sm" type="button" data-action="remove" data-id="${row.id}">${icon("trash")} Delete login</button>
      </div>`,
    foot: `<button class="btn btn--outline" type="button" data-action="assign" data-id="${row.id}">${icon("building")} Assign venues</button>
      <button class="btn btn--outline" type="button" data-action="resetPassword" data-id="${row.id}">${icon("lock")} Reset password</button>
      ${
        row.status === "suspended"
          ? `<button class="btn btn--primary" type="button" data-action="restore" data-id="${row.id}">${icon("play")} Restore access</button>`
          : `<button class="btn btn--danger-ghost" type="button" data-action="suspendAccount" data-id="${row.id}">${icon("pause")} Revoke access</button>`
      }`,
  });
}

function regionHtml() {
  return `${dataTable({
    rowAction: "open",
    emptyTitle: "No accounts match",
    emptyText: "Try a different role or status filter.",
    columns: [
      {
        label: "Account",
        render: (row) => `<div class="table__who">${avatar(row.name)}<div><strong>${esc(row.name)}</strong><span>${esc(row.email)}</span></div></div>`,
      },
      { label: "Role", render: (row) => `<span class="${roleTone(row.role)}">${esc(row.role)}</span>` },
      { label: "Restaurants", render: (row) => `${esc(row.restaurants.join(", "))}<span class="cell-sub">${row.restaurants.length} venue${row.restaurants.length === 1 ? "" : "s"}</span>` },
      { label: "Status", render: (row) => statusBadge(row.status) },
      { label: "2FA", render: (row) => (row.twoFactor ? `<span class="badge badge--success">${icon("shield")} On</span>` : `<span class="badge badge--warn">Off</span>`) },
      { label: "Last active", render: (row) => esc(relativeTime(row.lastActive)) },
    ],
    rows: pageRows(),
  })}
  <div class="panel__foot">
    ${pager(visible().length, filters.page, PER_PAGE, "accounts")}
    <span>${state.partnerAccounts.filter((row) => row.status === "active").length} active logins</span>
  </div>`;
}

export default {
  title: "Partner Accounts",
  eyebrow: "Partners",
  description: "Create partner logins, assign restaurant ownership and control who can access the partner app.",

  render() {
    const actions = `<a class="btn btn--outline" href="#/restaurants">${icon("store")} Venues</a>
      <button class="btn btn--primary" type="button" data-action="create">${icon("plus")} New account</button>`;
    return {
      actions,
      body: `<div class="grid grid--kpi">
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Partner logins</span><span class="kpi__icon">${icon("users")}</span></div><p class="kpi__value">${state.partnerAccounts.length}</p><span class="kpi__delta is-flat"><b>${new Set(state.partnerAccounts.flatMap((row) => row.restaurants)).size} venues covered</b></span></div>
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Pending invites</span><span class="kpi__icon">${icon("mail")}</span></div><p class="kpi__value">${state.partnerAccounts.filter((row) => row.status === "invited").length}</p><span class="kpi__delta is-flat"><b>Never signed in</b></span></div>
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Two factor enabled</span><span class="kpi__icon">${icon("shield")}</span></div><p class="kpi__value">${state.partnerAccounts.filter((row) => row.twoFactor).length}</p><span class="kpi__delta is-flat"><b>Recommended for owners</b></span></div>
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Access revoked</span><span class="kpi__icon">${icon("lock")}</span></div><p class="kpi__value">${state.partnerAccounts.filter((row) => row.status === "suspended").length}</p><span class="kpi__delta is-flat"><b>Sessions cleared</b></span></div>
      </div>
      <section class="panel">
        <div class="toolbar">
          ${searchField("a-q", "Search name, email or venue", filters.q)}
          ${selectField("a-role", [{ value: "all", label: "All roles" }, ...ROLES.map((role) => ({ value: role.value, label: role.label }))], filters.role)}
          ${selectField(
            "a-status",
            [
              { value: "all", label: "All statuses" },
              { value: "active", label: "Active" },
              { value: "invited", label: "Invited" },
              { value: "suspended", label: "Access revoked" },
            ],
            filters.status
          )}
        </div>
        <div id="region">${regionHtml()}</div>
      </section>`,
      mount(page) {
        page.querySelectorAll("[data-filter]").forEach((el) => {
          const key = el.dataset.filter.replace("a-", "");
          const apply = () => {
            filters[key] = el.value;
            filters.page = 1;
            redraw();
          };
          el.addEventListener("input", apply);
          el.addEventListener("change", apply);
        });
      },
    };
  },

  setPage(page) {
    filters.page = Math.max(1, page);
  },

  actions: {
    open(id) {
      const row = state.partnerAccounts.find((account) => account.id === id);
      if (row) drawer(row);
    },
    create() {
      openModal({
        title: "Create partner account",
        body: `<p style="margin-top:6px;color:var(--muted);font-size:.84rem">An invitation email is simulated in this prototype. The account cannot reach the partner app until it accepts the invite.</p>
          <div class="field" style="margin-top:14px"><label for="cName">Full name</label><input class="input" id="cName" placeholder="e.g. Nadia Hussain"></div>
          <div class="field"><label for="cEmail">Work email</label><input class="input" id="cEmail" type="email" placeholder="name@restaurant.pk"></div>
          <div class="field"><label for="cRole">Role</label><select class="select" id="cRole">${ROLES.map((role) => `<option value="${role.value}">${role.label}</option>`).join("")}</select></div>
          <div class="field"><span class="field__label">Restaurant access</span><div style="max-height:170px;overflow:auto;padding-right:6px">${venueOptions(null)}</div></div>`,
        confirmLabel: "Create and invite",
        onConfirm() {
          const name = document.getElementById("cName").value.trim();
          const email = document.getElementById("cEmail").value.trim();
          const venues = [...document.querySelectorAll("[data-venue-scope]:checked")].map((box) => box.value);
          if (!name || !email) {
            toast("Name and email are required", "danger");
            return false;
          }
          if (!venues.length) {
            toast("Assign at least one restaurant", "danger");
            return false;
          }
          const record = {
            id: `PA-${211 + state.partnerAccounts.length}`,
            name,
            email,
            role: document.getElementById("cRole").value,
            restaurants: venues,
            status: "invited",
            lastActive: null,
            twoFactor: false,
          };
          commit({
            action: "Created partner account and sent invite",
            target: `${name} (${email})`,
            kind: "success",
            apply: (draft) => draft.partnerAccounts.unshift(record),
          });
          filters.page = 1;
          toast(`Invite sent to ${email}`);
        },
      });
    },
    assign(id) {
      const row = state.partnerAccounts.find((account) => account.id === id);
      if (!row) return;
      openModal({
        title: `Assign restaurants to ${row.name}`,
        body: `<p style="margin-top:6px;color:var(--muted);font-size:.84rem">Access is scoped per venue. A staff member only sees the restaurants ticked here inside the partner app.</p>
          <div class="field" style="margin-top:14px"><span class="field__label">Venues</span><div style="max-height:220px;overflow:auto;padding-right:6px">${venueOptions(row)}</div></div>`,
        confirmLabel: "Save access",
        onConfirm() {
          const venues = [...document.querySelectorAll("[data-venue-scope]:checked")].map((box) => box.value);
          if (!venues.length) {
            toast("Keep at least one venue assigned", "danger");
            return false;
          }
          commit({
            action: "Updated venue access",
            target: `${row.name} (${row.email})`,
            kind: "info",
            apply: () => { row.restaurants = venues; },
          });
          closeDrawer();
          toast(`Venue access updated for ${row.name}`);
        },
      });
    },
    resetPassword(id) {
      const row = state.partnerAccounts.find((account) => account.id === id);
      if (!row) return;
      commit({
        action: "Sent password reset link",
        target: `${row.name} (${row.email})`,
        kind: "warn",
        apply: () => { row.resetSentAt = new Date().toISOString(); },
      });
      closeDrawer();
      toast("Password reset link sent");
    },
    toggleTwoFactor(id) {
      const row = state.partnerAccounts.find((account) => account.id === id);
      if (!row) return;
      commit({
        action: row.twoFactor ? "Required two factor re enrolment" : "Enabled two factor requirement",
        target: `${row.name} (${row.email})`,
        kind: "info",
        apply: () => { row.twoFactor = !row.twoFactor; },
      });
      drawer(row);
    },
    suspendAccount(id) {
      const row = state.partnerAccounts.find((account) => account.id === id);
      if (!row) return;
      openModal({
        title: `Revoke access for ${row.name}?`,
        body: `<p style="margin-top:6px;color:var(--muted);font-size:.84rem">All active partner app sessions for this login are signed out immediately. Venue data and reservations stay untouched.</p>`,
        confirmLabel: "Revoke access",
        tone: "danger",
        onConfirm() {
          updateStatus([id], "suspended", "Revoked partner app access", "danger");
          closeDrawer();
        },
      });
    },
    restore(id) {
      updateStatus([id], "active", "Restored partner app access", "success");
      closeDrawer();
    },
    resendInvite(id) {
      const row = state.partnerAccounts.find((account) => account.id === id);
      if (!row) return;
      commit({
        action: "Resend partner invite",
        target: `${row.name} (${row.email})`,
        kind: "info",
        apply: () => { row.invitedAt = new Date().toISOString(); },
      });
      toast(`Invite resent to ${row.email}`);
    },
    remove(id) {
      const row = state.partnerAccounts.find((account) => account.id === id);
      if (!row) return;
      openModal({
        title: `Delete ${row.name}?`,
        body: `<p style="margin-top:6px;color:var(--muted);font-size:.84rem">Deleting removes the login only. Restaurant records, menus and reservations created by this account stay in the platform.</p>`,
        confirmLabel: "Delete account",
        tone: "danger",
        onConfirm() {
          commit({
            action: "Deleted partner account",
            target: `${row.name} (${row.email})`,
            kind: "danger",
            apply: (draft) => { draft.partnerAccounts = draft.partnerAccounts.filter((item) => item.id !== id); },
          });
          closeDrawer();
          toast("Account deleted");
        },
      });
    },
  },
};
