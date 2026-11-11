/* ==========================================================================
   Module: Partner Applications (P0)
   Review, approve or reject restaurant and cafe applications. Approving an
   application creates the venue record and a partner account invite, which is
   the manual activation flow the MVP relies on.
   ========================================================================== */
import { state, commit, money, displayDate, relativeTime, planName } from "../store.js";
import { icon, esc, avatar, statusBadge, openDrawer, closeDrawer, openModal, toast, pager, matches } from "../ui.js";
import { searchField, selectField } from "./shared.js";

const PER_PAGE = 5;
const filters = { q: "", status: "open", plan: "all", sort: "newest", page: 1 };
const selected = [];

const REJECT_REASONS = [
  "Documents incomplete or unreadable",
  "Venue could not be verified by phone",
  "Licence or registration expired",
  "Does not fit the platform guidelines",
  "Partner withdrew the request",
];

function visible() {
  let rows = state.applications.filter((item) => {
    if (filters.status === "open") {
      if (!["pending", "in_review"].includes(item.status)) return false;
    } else if (filters.status !== "all" && item.status !== filters.status) return false;
    if (filters.plan !== "all" && item.plan !== filters.plan) return false;
    if (
      filters.q &&
      !matches(`${item.restaurant} ${item.contact} ${item.email} ${item.area} ${item.id}`, filters.q)
    )
      return false;
    return true;
  });
  rows = rows.sort((a, b) => {
    if (filters.sort === "oldest") return new Date(a.submitted) - new Date(b.submitted);
    if (filters.sort === "name") return a.restaurant.localeCompare(b.restaurant);
    return new Date(b.submitted) - new Date(a.submitted);
  });
  return rows;
}

function pageRows() {
  const rows = visible();
  const start = (filters.page - 1) * PER_PAGE;
  return rows.slice(start, start + PER_PAGE);
}

function card(row) {
  const docsReady = row.documents.length >= 3;
  return `<article class="review-card">
    <div>
      <div class="review-card__head">
        ${avatar(row.restaurant, "lg")}
        <div>
          <h3>${esc(row.restaurant)}</h3>
          <p>${esc(row.contact)} · ${esc(row.email)} · ${esc(row.phone)}</p>
        </div>
      </div>
      <div class="review-card__meta">
        ${statusBadge(row.status)}
        <span class="chip">${icon("pin")}${esc(row.area)}</span>
        <span class="chip">${icon("card")}${esc(planName(row.plan))}</span>
        <span class="chip">${icon("users")}${row.seats} seats</span>
        <span class="chip ${docsReady ? "" : "chip--orange"}">${icon("list")}${row.documents.length} document${row.documents.length === 1 ? "" : "s"}</span>
        <span class="chip chip--quiet">${icon("clock")}${esc(relativeTime(row.submitted))}</span>
      </div>
      <p style="margin-top:10px;font-size:.82rem;color:var(--ink-soft);max-width:620px">${esc(row.note)}</p>
    </div>
    <div class="review-card__actions">
      <button class="btn btn--outline btn--sm" type="button" data-action="open" data-id="${row.id}">${icon("eye")} Review</button>
      ${
        row.status === "approved"
          ? `<span class="badge badge--success">${icon("check")} Approved</span>`
          : `<button class="btn btn--primary btn--sm" type="button" data-action="approve" data-id="${row.id}">${icon("check")} Approve</button>`
      }
      ${
        row.status === "rejected"
          ? `<span class="badge badge--danger">${icon("x")} Rejected</span>`
          : `<button class="btn btn--danger-ghost btn--sm" type="button" data-action="reject" data-id="${row.id}">${icon("x")} Reject</button>`
      }
    </div>
  </article>`;
}

function region() {
  const rows = pageRows();
  const total = visible().length;
  const bulk = selected.length
    ? `<div class="bulkbar">
        <b>${selected.length}</b> selected
        <button class="btn btn--sm btn--outline" type="button" data-action="bulkApprove">${icon("check")} Approve selected</button>
        <button class="btn btn--sm btn--danger-ghost" type="button" data-action="bulkReject">${icon("x")} Reject selected</button>
        <button class="btn btn--sm btn--ghost" type="button" data-action="clearSelection">Clear</button>
      </div>`
    : "";
  return `${bulk}
    <div>${rows.length ? rows.map(card).join("") : `<p class="note" style="margin:18px">${icon("search")}No applications match this filter.</p>`}</div>
    <div class="panel__foot">
      ${pager(total, filters.page, PER_PAGE, "apps")}
      <span>${state.applications.filter((a) => ["pending", "in_review"].includes(a.status)).length} awaiting a decision</span>
    </div>`;
}

function drawer(row) {
  const docList = ["CNIC", "NTN certificate", "Lease agreement", "Food licence"]
    .map((doc) => {
      const has = row.documents.includes(doc);
      return `<li style="display:flex;gap:8px;align-items:center;font-size:.82rem;padding:6px 0;border-bottom:1px solid var(--line)">
        <span style="color:${has ? "var(--success)" : "var(--muted-light)"}">${icon(has ? "checkCircle" : "x")}</span>
        ${esc(doc)}
        <span class="badge badge--${has ? "success" : "quiet"} badge--plain" style="margin-left:auto">${has ? "Uploaded" : "Missing"}</span>
      </li>`;
    })
    .join("");
  openDrawer({
    title: row.restaurant,
    subtitle: `Application ${row.id} · submitted ${displayDate(row.submitted, true)}`,
    body: `
      <div class="person-head" style="margin-bottom:18px">
        ${avatar(row.restaurant, "lg")}
        <div>
          <h2>${esc(row.contact)}</h2>
          <p>${esc(row.email)} · ${esc(row.phone)}</p>
        </div>
        <span style="margin-left:auto">${statusBadge(row.status)}</span>
      </div>
      <dl class="detail-grid">
        <div><dt>Area</dt><dd>${esc(row.area)}</dd></div>
        <div><dt>Cuisines</dt><dd>${esc(row.cuisines.join(", "))}</dd></div>
        <div><dt>Seating capacity</dt><dd>${row.seats} covers</dd></div>
        <div><dt>Requested plan</dt><dd>${esc(planName(row.plan))} · ${esc(money(row.plan === "pro-annual" ? 50000 : 5000))}</dd></div>
      </dl>
      <hr class="divider">
      <h3 style="margin-bottom:8px">Partner note</h3>
      <p style="font-size:.84rem;color:var(--ink-soft)">${esc(row.note)}</p>
      <hr class="divider">
      <h3 style="margin-bottom:8px">Verification documents</h3>
      <ul>${docList}</ul>
      <hr class="divider">
      <h3 style="margin-bottom:8px">On approval</h3>
      <ul class="check-list" style="display:flex;flex-direction:column;gap:6px;font-size:.82rem;color:var(--ink-soft)">
        <li style="display:flex;gap:8px">${icon("check")} Restaurant profile created in pending state</li>
        <li style="display:flex;gap:8px">${icon("check")} Partner account invite sent to ${esc(row.email)}</li>
        <li style="display:flex;gap:8px">${icon("check")} First ${esc(planName(row.plan))} subscription started after payment is verified</li>
      </ul>
      ${row.status === "rejected" ? `<div class="note" style="margin-top:16px">${icon("alert")}<span><strong>Rejected</strong> ${esc(row.rejectionReason || "")} · ${esc(displayDate(row.rejectedAt || row.submitted))}</span></div>` : ""}`,
    foot:
      row.status === "approved"
        ? `<button class="btn btn--outline" type="button" data-close-overlay>Close</button>`
        : `<button class="btn btn--danger-ghost" type="button" data-action="reject" data-id="${row.id}">${icon("x")} Reject</button>
           <button class="btn btn--outline" type="button" data-action="markReview" data-id="${row.id}">${icon("edit")} Mark in review</button>
           <button class="btn btn--primary" type="button" data-action="approve" data-id="${row.id}">${icon("check")} Approve application</button>`,
  });
}

function approve(ids) {
  const list = state.applications.filter((item) => ids.includes(item.id) && item.status !== "approved");
  if (!list.length) {
    toast("Nothing left to approve");
    return;
  }
  commit({
    action: `Approved ${list.length} partner application${list.length === 1 ? "" : "s"}`,
    target: list.map((item) => item.restaurant).join(", "),
    kind: "success",
    apply: (draft) => {
      list.forEach((item) => {
        item.status = "approved";
        item.decidedAt = new Date().toISOString();
        if (!draft.restaurants.some((venue) => venue.name === item.restaurant)) {
          draft.restaurants.unshift({
            id: `RST-${115 + draft.restaurants.length}`,
            name: item.restaurant,
            owner: item.contact,
            ownerEmail: item.email,
            area: item.area,
            cuisines: item.cuisines,
            status: "pending",
            verified: false,
            plan: item.plan,
            joined: new Date().toISOString(),
            views: 0,
            bookings: 0,
            rating: 0,
            contact: item.phone,
            note: `Created from approved application ${item.id}.`,
          });
        }
        if (!draft.partnerAccounts.some((account) => account.email === item.email)) {
          draft.partnerAccounts.unshift({
            id: `PA-${211 + draft.partnerAccounts.length}`,
            name: item.contact,
            email: item.email,
            role: "Partner owner",
            restaurants: [item.restaurant],
            status: "invited",
            lastActive: null,
            twoFactor: false,
          });
        }
        if (!draft.subscriptions.some((sub) => sub.partner === item.restaurant)) {
          draft.subscriptions.unshift({
            id: `SUB-${9053 + draft.subscriptions.length}`,
            partner: item.restaurant,
            account: item.contact,
            plan: item.plan,
            amount: item.plan === "pro-annual" ? 50000 : 5000,
            method: "Not recorded",
            reference: "Awaiting payment",
            status: "awaiting_verification",
            started: null,
            expires: null,
            receipt: null,
          });
        }
      });
    },
  });
  selected.length = 0;
  toast(`${list.length} application${list.length === 1 ? "" : "s"} approved. Venue and partner invite created.`);
}

function askReject(ids) {
  const list = state.applications.filter((item) => ids.includes(item.id));
  if (!list.length) return;
  openModal({
    title: list.length === 1 ? `Reject ${list[0].restaurant}?` : `Reject ${list.length} applications?`,
    body: `
      <p style="color:var(--muted);font-size:.84rem;margin-top:6px">The partner is notified by email and can submit a new application with corrected documents.</p>
      <div class="field" style="margin-top:16px">
        <label for="rejectReason">Rejection reason</label>
        <select class="select" id="rejectReason">
          ${REJECT_REASONS.map((reason) => `<option value="${esc(reason)}">${esc(reason)}</option>`).join("")}
        </select>
      </div>
      <div class="field">
        <label for="rejectNote">Note to partner (optional)</label>
        <textarea class="textarea" id="rejectNote" placeholder="What exactly needs to be fixed before re-applying?"></textarea>
      </div>`,
    confirmLabel: "Reject application",
    tone: "danger",
    onConfirm() {
      const reason = document.getElementById("rejectReason").value;
      const note = document.getElementById("rejectNote").value.trim();
      commit({
        action: `Rejected ${list.length} partner application${list.length === 1 ? "" : "s"}`,
        target: list.map((item) => item.restaurant).join(", "),
        kind: "danger",
        apply: (draft) => {
          list.forEach((item) => {
            item.status = "rejected";
            item.rejectionReason = note ? `${reason}: ${note}` : reason;
            item.decidedAt = new Date().toISOString();
          });
        },
      });
      selected.length = 0;
      toast("Application rejected and partner notified", "danger");
    },
  });
}

export default {
  title: "Partner Applications",
  eyebrow: "Partners",
  description: "Every restaurant and cafe that applied to join DineCircle. Approving creates the venue, the partner invite and a subscription record.",

  render() {
    const open = state.applications.filter((a) => ["pending", "in_review"].includes(a.status)).length;
    const actions = `<a class="btn btn--outline" href="#/restaurants">${icon("store")} Restaurants</a>
      <button class="btn btn--primary" type="button" data-action="manual">${icon("plus")} Log offline application</button>`;
    return {
      actions,
      body: `<section class="panel">
        <div class="toolbar">
          ${searchField("apps-q", "Search restaurant, contact or ID", filters.q)}
          ${selectField(
            "apps-status",
            [
              { value: "open", label: "Awaiting decision" },
              { value: "pending", label: "Pending" },
              { value: "in_review", label: "In review" },
              { value: "approved", label: "Approved" },
              { value: "rejected", label: "Rejected" },
              { value: "all", label: "All statuses" },
            ],
            filters.status
          )}
          ${selectField(
            "apps-plan",
            [
              { value: "all", label: "Any plan" },
              { value: "pro-monthly", label: "Pro Monthly" },
              { value: "pro-annual", label: "Pro Annual" },
            ],
            filters.plan
          )}
          ${selectField(
            "apps-sort",
            [
              { value: "newest", label: "Newest first" },
              { value: "oldest", label: "Oldest first" },
              { value: "name", label: "Restaurant A to Z" },
            ],
            filters.sort
          )}
          <span class="spacer"></span>
          <span class="chip chip--orange">${icon("clock")} ${open} awaiting decision</span>
        </div>
        <div id="region">${region()}</div>
      </section>`,
      mount(page) {
        page.querySelectorAll("[data-filter]").forEach((el) => {
          const key = el.dataset.filter.replace("apps-", "");
          el.addEventListener("input", () => {
            filters[key] = el.value;
            filters.page = 1;
            document.getElementById("region").innerHTML = region();
          });
          el.addEventListener("change", () => {
            filters[key] = el.value;
            filters.page = 1;
            document.getElementById("region").innerHTML = region();
          });
        });
      },
    };
  },

  setPage(page) {
    filters.page = Math.max(1, page);
  },

  actions: {
    open(id) {
      const row = state.applications.find((item) => item.id === id);
      if (row) drawer(row);
    },
    approve(id) {
      approve([id]);
      closeDrawer();
    },
    reject(id) {
      askReject([id]);
    },
    markReview(id) {
      const row = state.applications.find((item) => item.id === id);
      if (!row) return;
      commit({
        action: "Moved application to in review",
        target: `${row.restaurant} (${row.id})`,
        kind: "info",
        apply: () => {
          row.status = "in_review";
        },
      });
      drawer(row);
      toast("Marked as in review");
    },
    select(id) {
      const index = selected.indexOf(id);
      if (index > -1) selected.splice(index, 1);
      else selected.push(id);
      document.getElementById("region").innerHTML = region();
    },
    selectAll(value, node) {
      const ids = pageRows().map((row) => row.id);
      if (node.checked) ids.forEach((id) => !selected.includes(id) && selected.push(id));
      else selected.splice(0, selected.length, ...selected.filter((id) => !ids.includes(id)));
      document.getElementById("region").innerHTML = region();
    },
    clearSelection() {
      selected.length = 0;
      document.getElementById("region").innerHTML = region();
    },
    bulkApprove() {
      approve([...selected]);
    },
    bulkReject() {
      askReject([...selected]);
    },
    manual() {
      openModal({
        title: "Log an offline application",
        body: `<p style="margin-top:6px;color:var(--muted);font-size:.84rem">Use this when a restaurant applies by phone, email or through a sales visit. The record appears in the queue for a decision.</p>
          <div class="field" style="margin-top:14px"><label for="mName">Restaurant name</label><input class="input" id="mName" placeholder="e.g. Habibi Grill"></div>
          <div class="field"><label for="mContact">Owner contact</label><input class="input" id="mContact" placeholder="Name and mobile number"></div>
          <div class="field"><label for="mArea">Area</label><input class="input" id="mArea" placeholder="Clifton, Karachi"></div>`,
        confirmLabel: "Add to queue",
        onConfirm() {
          const name = document.getElementById("mName").value.trim();
          const contact = document.getElementById("mContact").value.trim();
          const area = document.getElementById("mArea").value.trim() || "Karachi";
          if (!name) {
            toast("Restaurant name is required", "danger");
            return false;
          }
          const record = {
            id: `APP-${1085 + state.applications.length}`,
            restaurant: name,
            contact: contact || "Not recorded",
            email: contact.includes("@") ? contact : "not-recorded@dinecircle.app",
            phone: contact,
            area,
            cuisines: ["Pakistani"],
            submitted: new Date().toISOString(),
            status: "pending",
            plan: "pro-monthly",
            documents: ["CNIC"],
            seats: 0,
            note: "Logged by an admin from an offline enquiry. Documents still to be collected.",
          };
          commit({
            action: "Logged offline partner application",
            target: `${name} (${record.id})`,
            kind: "info",
            apply: (draft) => draft.applications.unshift(record),
          });
          filters.status = "open";
          filters.page = 1;
          toast("Application added to the queue");
        },
      });
    },
  },
};
