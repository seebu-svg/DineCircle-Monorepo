/* ==========================================================================
   Module: Restaurant Management (P0)
   Create, verify, activate and suspend restaurant profiles. Visibility in the
   customer app follows this status exactly: active plus verified venues are
   listed, pending or draft venues are hidden, and suspension removes a venue
   from discovery without deleting menus, deals or reservations.
   ========================================================================== */
import { state, commit, money, displayDate, planName, planPrice } from "../store.js";
import { icon, esc, avatar, statusBadge, openDrawer, closeDrawer, openModal, toast, pager, matches } from "../ui.js";
import { dataTable, searchField, selectField } from "./shared.js";
import { metrics } from "../data.js";

const PER_PAGE = 8;
const filters = { q: "", status: "all", plan: "all", sort: "views", page: 1 };
const selected = [];

function visible() {
  return state.restaurants
    .filter((row) => {
      if (filters.status !== "all" && row.status !== filters.status) return false;
      if (filters.plan !== "all" && row.plan !== filters.plan) return false;
      if (filters.q && !matches(`${row.name} ${row.owner} ${row.ownerEmail} ${row.area} ${(row.cuisines || []).join(" ")} ${row.id}`, filters.q)) return false;
      return true;
    })
    .sort((a, b) => {
      if (filters.sort === "name") return a.name.localeCompare(b.name);
      if (filters.sort === "newest") return new Date(b.joined) - new Date(a.joined);
      if (filters.sort === "rating") return b.rating - a.rating;
      return b.views - a.views;
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

function update(ids, apply, action, kind) {
  const rows = state.restaurants.filter((row) => ids.includes(row.id));
  if (!rows.length) {
    toast("Nothing to update", "danger");
    return;
  }
  commit({
    action,
    target: rows.map((row) => `${row.name} (${row.id})`).join(", "),
    kind,
    apply: () => rows.forEach(apply),
  });
  selected.length = 0;
  toast(`${rows.length} venue${rows.length === 1 ? "" : "s"} updated`);
}

function askSuspend(ids) {
  const rows = state.restaurants.filter((row) => ids.includes(row.id));
  if (!rows.length) return;
  openModal({
    title: rows.length === 1 ? `Suspend ${rows[0].name}?` : `Suspend ${rows.length} venues?`,
    body: `<p style="margin-top:6px;color:var(--muted);font-size:.84rem">The venue is hidden from the customer app. Partner logins keep working, so menus, deals and reservations survive and can be restored without a rebuild.</p>
      <div class="field" style="margin-top:14px"><label for="suspendReason">Reason for the audit log</label>
        <select class="select" id="suspendReason">
          <option>Payment receipt rejected</option>
          <option>Repeated guest complaints</option>
          <option>Deal honoured incorrectly</option>
          <option>Regulatory or licence issue</option>
          <option>Requested by the partner</option>
        </select>
      </div>`,
    confirmLabel: "Suspend venue",
    tone: "danger",
    onConfirm() {
      const reason = document.getElementById("suspendReason").value;
      update(
        ids,
        (row) => {
          row.status = "suspended";
          row.suspendReason = reason;
        },
        `Suspended restaurant: ${reason}`,
        "danger"
      );
      closeDrawer();
    },
  });
}

function profileFields(row) {
  const blank = { name: "", owner: "", ownerEmail: "", area: "", cuisines: [], plan: state.plans[0]?.id };
  const value = row || blank;
  return `
    <div class="field"><label for="eName">Restaurant name</label><input class="input" id="eName" value="${esc(value.name)}"></div>
    <div class="field"><label for="eOwner">Owner contact</label><input class="input" id="eOwner" value="${esc(value.owner)}"></div>
    <div class="field"><label for="eEmail">Owner email</label><input class="input" id="eEmail" type="email" value="${esc(value.ownerEmail)}"></div>
    <div class="field"><label for="eArea">Area</label><input class="input" id="eArea" value="${esc(value.area)}"></div>
    <div class="field"><label for="eCuisines">Cuisines, comma separated</label><input class="input" id="eCuisines" value="${esc((value.cuisines || []).join(", "))}"></div>
    <div class="field"><label for="ePlan">Subscription plan</label>
      <select class="select" id="ePlan">
        ${state.plans.map((plan) => `<option value="${plan.id}" ${value.plan === plan.id ? "selected" : ""}>${esc(plan.name)}</option>`).join("")}
      </select>
    </div>`;
}

function readProfileForm() {
  return {
    name: document.getElementById("eName").value.trim(),
    owner: document.getElementById("eOwner").value.trim() || "Unassigned",
    ownerEmail: document.getElementById("eEmail").value.trim() || "unassigned@dinecircle.app",
    area: document.getElementById("eArea").value.trim() || "Karachi",
    cuisines: document.getElementById("eCuisines").value.split(",").map((part) => part.trim()).filter(Boolean),
    plan: document.getElementById("ePlan").value,
  };
}

function drawer(row) {
  const deals = state.deals.filter((deal) => deal.restaurant === row.name);
  const experiences = state.experiences.filter((exp) => exp.venue === row.name);
  const subs = state.subscriptions.filter((sub) => sub.partner === row.name);
  const open = state.reports.filter((rep) => rep.subjectId === row.id || rep.subject === row.name).filter((rep) => ["open", "in_review"].includes(rep.status));
  openDrawer({
    title: row.name,
    subtitle: `${row.id} · ${row.area}`,
    tone: row.status === "suspended" ? "danger" : "orange",
    body: `
      <div class="person-head" style="margin-bottom:18px">
        ${avatar(row.name, "lg")}
        <div><h2>${esc(row.name)}</h2><p>${esc((row.cuisines || []).join(" · "))}</p></div>
        <span style="margin-left:auto">${statusBadge(row.status)}</span>
      </div>
      ${row.suspendReason ? `<div class="note" style="margin-bottom:16px">${icon("alert")}<span><strong>Suspension reason</strong> ${esc(row.suspendReason)}</span></div>` : ""}
      <dl class="detail-grid">
        <div><dt>Owner account</dt><dd>${esc(row.owner)}</dd></div>
        <div><dt>Contact email</dt><dd>${esc(row.ownerEmail)}</dd></div>
        <div><dt>Phone</dt><dd>${esc(row.contact)}</dd></div>
        <div><dt>Joined</dt><dd>${esc(displayDate(row.joined))}</dd></div>
        <div><dt>Plan</dt><dd>${esc(planName(row.plan))} · ${esc(money(planPrice(row.plan)))}</dd></div>
        <div><dt>Verification</dt><dd>${row.verified ? "Verified" : "Not verified"}</dd></div>
        <div><dt>Profile views</dt><dd>${row.views.toLocaleString()}</dd></div>
        <div><dt>Reservations</dt><dd>${row.bookings}</dd></div>
        <div><dt>Rating</dt><dd>${row.rating ? `${row.rating} / 5` : "Not rated"}</dd></div>
      </dl>
      <hr class="divider">
      <h3 style="margin-bottom:8px">Content on this profile</h3>
      <div class="stat-row"><span>Live deals</span><b>${deals.filter((d) => d.status === "live").length} of ${deals.length}</b></div>
      <div class="stat-row"><span>Experiences hosted</span><b>${experiences.length}</b></div>
      <div class="stat-row"><span>Subscription records</span><b>${subs.length}</b></div>
      <div class="stat-row"><span>Open safety reports</span><b>${open.length}</b></div>
      <hr class="divider">
      <h3 style="margin-bottom:8px">Visibility rules</h3>
      <ul style="display:flex;flex-direction:column;gap:6px;font-size:.82rem;color:var(--ink-soft)">
        <li style="display:flex;gap:8px">${icon("check")} Draft and pending stay hidden from the customer app.</li>
        <li style="display:flex;gap:8px">${icon("check")} Active plus verified is listed in search with menus and deals.</li>
        <li style="display:flex;gap:8px">${icon("check")} Suspended removes discovery but keeps all partner data.</li>
      </ul>`,
    foot: `<button class="btn btn--outline" type="button" data-action="editVenue" data-id="${row.id}">${icon("edit")} Edit</button>
      ${
        row.verified
          ? `<button class="btn btn--outline" type="button" data-action="unverify" data-id="${row.id}">${icon("x")} Unverify</button>`
          : `<button class="btn btn--outline" type="button" data-action="verify" data-id="${row.id}">${icon("shield")} Mark verified</button>`
      }
      ${
        row.status === "active"
          ? `<button class="btn btn--danger-ghost" type="button" data-action="suspend" data-id="${row.id}">${icon("pause")} Suspend</button>`
          : `<button class="btn btn--primary" type="button" data-action="activate" data-id="${row.id}">${icon("play")} Activate</button>`
      }`,
  });
}

function bulkBar() {
  if (!selected.length) return "";
  return `<div class="bulkbar">
    <b>${selected.length}</b> selected
    <button class="btn btn--sm btn--outline" type="button" data-action="bulkVerify">${icon("shield")} Verify</button>
    <button class="btn btn--sm btn--outline" type="button" data-action="bulkActivate">${icon("play")} Activate</button>
    <button class="btn btn--sm btn--danger-ghost" type="button" data-action="bulkSuspend">${icon("pause")} Suspend</button>
    <button class="btn btn--sm btn--ghost" type="button" data-action="clearSelection">Clear</button>
  </div>`;
}

function regionHtml() {
  return `${bulkBar()}
  ${dataTable({
    rowAction: "open",
    selectable: true,
    selected,
    emptyTitle: "No venues match",
    emptyText: "Adjust the filters or create a restaurant profile manually.",
    columns: [
      {
        label: "Restaurant",
        render: (row) => `<div class="table__who">${avatar(row.name)}<div><strong>${esc(row.name)}</strong><span>${esc(row.area)} · ${esc((row.cuisines || []).slice(0, 2).join(", "))}</span></div></div>`,
      },
      { label: "Owner", render: (row) => `<span>${esc(row.owner)}</span><span class="cell-sub">${esc(row.ownerEmail)}</span>` },
      { label: "Plan", render: (row) => esc(planName(row.plan).replace("Partner Pro ", "Pro ")) },
      { label: "Verification", render: (row) => (row.verified ? statusBadge("verified") : `<span class="badge badge--warn">Not verified</span>`) },
      { label: "Status", render: (row) => statusBadge(row.status) },
      { label: "Views", cls: "cell-num", render: (row) => row.views.toLocaleString() },
      { label: "Bookings", cls: "cell-num", render: (row) => row.bookings },
      { label: "Rating", cls: "cell-num", render: (row) => (row.rating ? row.rating.toFixed(1) : "–") },
    ],
    rows: pageRows(),
  })}
  <div class="panel__foot">
    ${pager(visible().length, filters.page, PER_PAGE, "venues")}
    <span>${metrics.restaurants.total} venues platform wide</span>
  </div>`;
}

export default {
  title: "Restaurant Management",
  eyebrow: "Partners",
  description: "Create, verify, activate and suspend restaurant and cafe profiles across the Karachi pilot.",

  render() {
    const count = (status) => state.restaurants.filter((row) => row.status === status).length;
    const actions = `<a class="btn btn--outline" href="#/applications">${icon("flag")} Application queue</a>
      <button class="btn btn--primary" type="button" data-action="create">${icon("plus")} New restaurant</button>`;
    return {
      actions,
      body: `<div class="grid grid--kpi">
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Platform venues</span><span class="kpi__icon">${icon("store")}</span></div><p class="kpi__value">${metrics.restaurants.total}</p><span class="kpi__delta is-up"><b>${icon("arrowUp")}6.4%</b> vs last month</span></div>
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Active and listed</span><span class="kpi__icon">${icon("checkCircle")}</span></div><p class="kpi__value">${count("active")}</p><span class="kpi__delta is-flat"><b>${metrics.restaurants.active}% of pilot slice</b> shown here</span></div>
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Pending verification</span><span class="kpi__icon">${icon("clock")}</span></div><p class="kpi__value">${count("pending") + count("draft")}</p><span class="kpi__delta is-flat"><b>Needs a site check</b></span></div>
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Suspended</span><span class="kpi__icon">${icon("alert")}</span></div><p class="kpi__value">${count("suspended")}</p><span class="kpi__delta is-flat"><b>Hidden from discovery</b></span></div>
      </div>
      <section class="panel">
        <div class="toolbar">
          ${searchField("v-q", "Search venue, owner, area or ID", filters.q)}
          ${selectField(
            "v-status",
            [
              { value: "all", label: "All statuses" },
              { value: "active", label: "Active" },
              { value: "pending", label: "Pending" },
              { value: "draft", label: "Draft" },
              { value: "suspended", label: "Suspended" },
            ],
            filters.status
          )}
          ${selectField(
            "v-plan",
            [{ value: "all", label: "Any plan" }, ...state.plans.map((plan) => ({ value: plan.id, label: plan.name.replace("Partner Pro ", "Pro ") }))],
            filters.plan
          )}
          ${selectField(
            "v-sort",
            [
              { value: "views", label: "Most viewed" },
              { value: "name", label: "Name A to Z" },
              { value: "newest", label: "Newest partners" },
              { value: "rating", label: "Highest rating" },
            ],
            filters.sort
          )}
        </div>
        <div id="region">${regionHtml()}</div>
      </section>`,
      mount(page) {
        page.querySelectorAll("[data-filter]").forEach((el) => {
          const key = el.dataset.filter.replace("v-", "");
          const updateFilter = () => {
            filters[key] = el.value;
            filters.page = 1;
            redraw();
          };
          el.addEventListener("input", updateFilter);
          el.addEventListener("change", updateFilter);
        });
      },
    };
  },

  setPage(page) {
    filters.page = Math.max(1, page);
  },

  actions: {
    open(id) {
      const row = state.restaurants.find((venue) => venue.id === id);
      if (row) drawer(row);
    },
    create() {
      openModal({
        title: "New restaurant profile",
        body: `<p style="margin-top:6px;color:var(--muted);font-size:.84rem">Use this for phone or sales signed partners. The venue is created as a draft and stays hidden until it is verified and activated.</p>
          <div style="margin-top:14px">${profileFields(null)}</div>`,
        confirmLabel: "Create venue",
        onConfirm() {
          const form = readProfileForm();
          if (!form.name) {
            toast("Restaurant name is required", "danger");
            return false;
          }
          const record = {
            id: `RST-${114 + state.restaurants.length}`,
            ...form,
            status: "draft",
            verified: false,
            joined: new Date().toISOString(),
            views: 0,
            bookings: 0,
            rating: 0,
            contact: "+92 21 0000 0000",
            note: "Created directly by an admin.",
          };
          commit({
            action: "Created restaurant profile",
            target: `${record.name} (${record.id})`,
            kind: "success",
            apply: (draft) => draft.restaurants.unshift(record),
          });
          filters.status = "all";
          filters.page = 1;
          toast(`${record.name} created as a draft`);
        },
      });
    },
    editVenue(id) {
      const row = state.restaurants.find((venue) => venue.id === id);
      if (!row) return;
      openModal({
        title: `Edit ${row.name}`,
        body: `<div style="margin-top:14px">${profileFields(row)}</div>`,
        confirmLabel: "Save changes",
        onConfirm() {
          const form = readProfileForm();
          if (!form.name) {
            toast("Restaurant name is required", "danger");
            return false;
          }
          commit({
            action: "Updated restaurant profile",
            target: `${row.name} (${row.id})`,
            kind: "info",
            apply: () => Object.assign(row, form),
          });
          toast("Profile updated");
        },
      });
    },
    verify(id) {
      update([id], (row) => { row.verified = true; }, "Verified restaurant", "success");
      closeDrawer();
    },
    unverify(id) {
      update([id], (row) => { row.verified = false; }, "Removed restaurant verification", "warn");
      closeDrawer();
    },
    activate(id) {
      const row = state.restaurants.find((venue) => venue.id === id);
      if (!row) return;
      if (!row.verified) {
        toast("Verify the venue before activating it", "danger");
        return;
      }
      update([id], (venue) => { venue.status = "active"; }, "Activated restaurant", "success");
      closeDrawer();
    },
    suspend(id) {
      askSuspend([id]);
    },
    bulkVerify() {
      update(selected, (row) => { row.verified = true; }, "Verified restaurants", "success");
    },
    bulkActivate() {
      const eligible = selected.filter((id) => state.restaurants.find((row) => row.id === id)?.verified);
      if (!eligible.length) {
        toast("Only verified venues can be activated", "danger");
        return;
      }
      update(eligible, (row) => { row.status = "active"; }, "Activated restaurants", "success");
    },
    bulkSuspend() {
      askSuspend([...selected]);
    },
    select(id) {
      const index = selected.indexOf(id);
      if (index > -1) selected.splice(index, 1);
      else selected.push(id);
      redraw();
    },
    selectAll(value, node) {
      const ids = pageRows().map((row) => row.id);
      if (node.checked) ids.forEach((id) => !selected.includes(id) && selected.push(id));
      else selected.splice(0, selected.length, ...selected.filter((id) => !ids.includes(id)));
      redraw();
    },
    clearSelection() {
      selected.length = 0;
      redraw();
    },
  },
};
