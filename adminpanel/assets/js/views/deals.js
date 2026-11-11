/* ==========================================================================
   Module: Deals & Content (P1)
   Two review queues in one place: promotional offers that partners publish to
   the customer app, and the user generated content (reviews, photos, menu
   copy) that needs a guideline decision.
   ========================================================================== */
import { state, commit, displayDate, relativeTime } from "../store.js";
import { icon, esc, avatar, statusBadge, openDrawer, closeDrawer, openModal, toast, pager, matches } from "../ui.js";
import { dataTable, searchField, selectField } from "./shared.js";
import { navigate, refreshApp } from "../router.js";

const PER_PAGE = 8;
const filters = { tab: "deals", q: "", status: "all", kind: "all", page: 1 };

function dealRows() {
  return state.deals.filter((row) => {
    if (filters.status !== "all" && row.status !== filters.status) return false;
    if (filters.q && !matches(`${row.title} ${row.restaurant} ${row.type} ${row.id}`, filters.q)) return false;
    return true;
  });
}

function contentRows() {
  return state.contentItems.filter((row) => {
    if (filters.status !== "all" && row.status !== filters.status) return false;
    if (filters.kind !== "all" && row.kind !== filters.kind) return false;
    if (filters.q && !matches(`${row.excerpt} ${row.target} ${row.author} ${row.kind} ${row.id}`, filters.q)) return false;
    return true;
  });
}

function pageRows() {
  const rows = filters.tab === "deals" ? dealRows() : contentRows();
  const start = (filters.page - 1) * PER_PAGE;
  return rows.slice(start, start + PER_PAGE);
}

function redraw() {
  const region = document.getElementById("region");
  if (region) region.innerHTML = regionHtml();
}

function setDeal(ids, patch, action, kind) {
  const rows = state.deals.filter((row) => ids.includes(row.id));
  if (!rows.length) return;
  commit({
    action,
    target: rows.map((row) => `${row.title} (${row.id})`).join(", "),
    kind,
    apply: () => rows.forEach((row) => Object.assign(row, patch)),
  });
  toast(`${rows.length} deal${rows.length === 1 ? "" : "s"} updated`);
}

function setContent(ids, patch, action, kind) {
  const rows = state.contentItems.filter((row) => ids.includes(row.id));
  if (!rows.length) return;
  commit({
    action,
    target: rows.map((row) => `${row.kind} on ${row.target} (${row.id})`).join(", "),
    kind,
    apply: () => rows.forEach((row) => Object.assign(row, patch)),
  });
  toast(`${rows.length} item${rows.length === 1 ? "" : "s"} updated`);
}

function dealDrawer(row) {
  const venue = state.restaurants.find((item) => item.name === row.restaurant);
  openDrawer({
    title: row.title,
    subtitle: `${row.id} · ${row.restaurant}`,
    tone: row.status === "flagged" ? "danger" : "orange",
    body: `
      <div class="person-head" style="margin-bottom:18px">
        ${avatar(row.restaurant, "lg")}
        <div><h2>${esc(row.restaurant)}</h2><p>${esc(venue?.area || "Venue record not found")}</p></div>
        <span style="margin-left:auto">${statusBadge(row.status)}</span>
      </div>
      ${row.note ? `<div class="note" style="margin-bottom:16px">${icon("alert")}<span>${esc(row.note)}</span></div>` : ""}
      <dl class="detail-grid">
        <div><dt>Deal type</dt><dd>${esc(row.type)}</dd></div>
        <div><dt>Offer value</dt><dd>${esc(row.value)}</dd></div>
        <div><dt>Valid until</dt><dd>${esc(displayDate(row.expires))}</dd></div>
        <div><dt>Redemptions</dt><dd>${row.redemptions}</dd></div>
        <div><dt>Guest reports</dt><dd>${row.reports}</dd></div>
        <div><dt>Venue status</dt><dd>${venue ? esc(venue.status) : "Unknown"}</dd></div>
      </dl>
      <hr class="divider">
      <h3 style="margin-bottom:8px">How guests use this deal</h3>
      <ul style="display:flex;flex-direction:column;gap:6px;font-size:.82rem;color:var(--ink-soft)">
        <li style="display:flex;gap:8px">${icon("check")} The guest shows the deal code in the customer app at the venue.</li>
        <li style="display:flex;gap:8px">${icon("check")} Payment is settled at the restaurant. DineCircle takes no commission.</li>
        <li style="display:flex;gap:8px">${icon("check")} Repeated refusals are treated as a venue issue, not a guest issue.</li>
      </ul>`,
    foot: `${venue ? `<button class="btn btn--outline" type="button" data-action="openVenue" data-id="${venue.id}">${icon("store")} Venue</button>` : ""}
      ${
        row.status === "live"
          ? `<button class="btn btn--outline" type="button" data-action="pauseDeal" data-id="${row.id}">${icon("pause")} Pause</button>
             <button class="btn btn--danger-ghost" type="button" data-action="removeDeal" data-id="${row.id}">${icon("trash")} Remove</button>`
          : row.status === "paused"
            ? `<button class="btn btn--primary" type="button" data-action="resumeDeal" data-id="${row.id}">${icon("play")} Publish again</button>`
            : `<button class="btn btn--danger-ghost" type="button" data-action="removeDeal" data-id="${row.id}">${icon("trash")} Remove</button>
               <button class="btn btn--primary" type="button" data-action="approveDeal" data-id="${row.id}">${icon("check")} Approve and publish</button>`
      }`,
  });
}

function contentDrawer(row) {
  openDrawer({
    title: `${row.kind} on ${row.target}`,
    subtitle: `${row.id} · submitted by ${row.author}`,
    tone: row.status === "flagged" ? "danger" : "orange",
    body: `
      <div class="issue" style="background:var(--cream)">
        <b>${esc(row.reason)}</b>
        <span>${esc(relativeTime(row.at))} · ${row.reports} guest report${row.reports === 1 ? "" : "s"}</span>
        <p>${esc(row.excerpt)}</p>
      </div>
      <hr class="divider">
      <dl class="detail-grid">
        <div><dt>Content type</dt><dd>${esc(row.kind)}</dd></div>
        <div><dt>Attached to</dt><dd>${esc(row.target)}</dd></div>
        <div><dt>Author</dt><dd>${esc(row.author)}</dd></div>
        <div><dt>Published</dt><dd>${esc(displayDate(row.at, true))}</dd></div>
        <div><dt>Current decision</dt><dd>${esc(row.status.replace(/_/g, " "))}</dd></div>
        <div><dt>Guideline</dt><dd>Respect, honesty, no promotion</dd></div>
      </dl>
      <hr class="divider">
      <h3 style="margin-bottom:8px">Guideline checklist</h3>
      <ul style="display:flex;flex-direction:column;gap:6px;font-size:.82rem;color:var(--ink-soft)">
        <li style="display:flex;gap:8px">${icon("check")} Reviews must describe a real visit and stay free of abuse.</li>
        <li style="display:flex;gap:8px">${icon("check")} No promotional links for other businesses.</li>
        <li style="display:flex;gap:8px">${icon("check")} Photos and menu prices must match what the guest receives.</li>
      </ul>`,
    foot: `<button class="btn btn--outline" type="button" data-action="contentKeep" data-id="${row.id}">${icon("check")} Keep as published</button>
      <button class="btn btn--outline" type="button" data-action="contentEdit" data-id="${row.id}">${icon("edit")} Request an edit</button>
      <button class="btn btn--danger-ghost" type="button" data-action="contentRemove" data-id="${row.id}">${icon("trash")} Remove content</button>`,
  });
}

function dealsTable() {
  return `${dataTable({
    rowAction: "openDeal",
    emptyTitle: "No deals match",
    emptyText: "Clear the filters to review every published offer.",
    emptyIcon: "tag",
    columns: [
      {
        label: "Deal",
        render: (row) => `<div class="table__who">${avatar(row.restaurant)}<div><strong>${esc(row.title)}</strong><span>${esc(row.restaurant)}</span></div></div>`,
      },
      { label: "Type", render: (row) => esc(row.type) },
      { label: "Offer", render: (row) => esc(row.value) },
      { label: "Redemptions", cls: "cell-num", render: (row) => row.redemptions },
      {
        label: "Reports",
        cls: "cell-num",
        render: (row) => (row.reports ? `<span class="badge badge--danger">${row.reports}</span>` : `<span class="badge badge--quiet">0</span>`),
      },
      { label: "Valid until", render: (row) => esc(displayDate(row.expires)) },
      { label: "Status", render: (row) => statusBadge(row.status) },
    ],
    rows: pageRows(),
  })}
  <div class="panel__foot">
    ${pager(dealRows().length, filters.page, PER_PAGE, "deals")}
    <span>${state.deals.filter((row) => row.status === "live").length} offers live in the customer app</span>
  </div>`;
}

function contentTable() {
  return `${dataTable({
    rowAction: "openContent",
    emptyTitle: "Content queue is clear",
    emptyText: "Nothing is waiting for a guideline decision.",
    emptyIcon: "shield",
    columns: [
      {
        label: "Content",
        render: (row) => `<div><strong>${esc(row.excerpt.slice(0, 68))}${row.excerpt.length > 68 ? "..." : ""}</strong><span class="cell-sub">${esc(row.kind)} on ${esc(row.target)}</span></div>`,
      },
      { label: "Author", render: (row) => esc(row.author) },
      { label: "Flag reason", render: (row) => esc(row.reason) },
      {
        label: "Reports",
        cls: "cell-num",
        render: (row) => (row.reports ? `<span class="badge ${row.reports > 1 ? "badge--danger" : "badge--warn"}">${row.reports}</span>` : `<span class="badge badge--quiet">0</span>`),
      },
      { label: "Raised", render: (row) => esc(relativeTime(row.at)) },
      { label: "Decision", render: (row) => statusBadge(row.status) },
    ],
    rows: pageRows(),
  })}
  <div class="panel__foot">
    ${pager(contentRows().length, filters.page, PER_PAGE, "content")}
    <span>${state.contentItems.filter((row) => ["flagged", "pending_review"].includes(row.status)).length} items need a decision</span>
  </div>`;
}

function regionHtml() {
  return filters.tab === "deals" ? dealsTable() : contentTable();
}

export default {
  title: "Deals & Content",
  eyebrow: "Trust & content",
  description: "Review published offers and guest generated content, then pause, correct or remove anything that misleads diners.",

  render() {
    const flaggedDeals = state.deals.filter((row) => row.status === "flagged").length;
    const flaggedContent = state.contentItems.filter((row) => row.status === "flagged").length;
    const actions = `<a class="btn btn--outline" href="#/reports">${icon("shield")} Safety reports</a>
      <button class="btn btn--primary" type="button" data-action="export">${icon("download")} Export moderation log</button>`;
    const filterControls =
      filters.tab === "deals"
        ? selectField(
            "d-status",
            [
              { value: "all", label: "All statuses" },
              { value: "live", label: "Live" },
              { value: "paused", label: "Paused" },
              { value: "flagged", label: "Flagged" },
              { value: "expired", label: "Expired" },
            ],
            filters.status
          )
        : `${selectField(
            "d-status",
            [
              { value: "all", label: "All decisions" },
              { value: "flagged", label: "Flagged" },
              { value: "pending_review", label: "Pending review" },
              { value: "approved", label: "Kept" },
            ],
            filters.status
          )}
          ${selectField(
            "d-kind",
            [{ value: "all", label: "All content types" }, ...[...new Set(state.contentItems.map((row) => row.kind))].map((kind) => ({ value: kind, label: kind }))],
            filters.kind
          )}`;
    return {
      actions,
      body: `<div class="grid grid--kpi">
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Live deals</span><span class="kpi__icon">${icon("tag")}</span></div><p class="kpi__value">${state.deals.filter((row) => row.status === "live").length}</p><span class="kpi__delta is-flat"><b>${state.deals.reduce((sum, row) => sum + row.redemptions, 0).toLocaleString()} redemptions logged</b></span></div>
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Flagged offers</span><span class="kpi__icon">${icon("alert")}</span></div><p class="kpi__value">${flaggedDeals}</p><span class="kpi__delta is-flat"><b>Honoured incorrectly</b></span></div>
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Content to review</span><span class="kpi__icon">${icon("list")}</span></div><p class="kpi__value">${flaggedContent + state.contentItems.filter((row) => row.status === "pending_review").length}</p><span class="kpi__delta is-flat"><b>Reviews, photos, menu copy</b></span></div>
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Decisions this week</span><span class="kpi__icon">${icon("checkCircle")}</span></div><p class="kpi__value">${state.auditLog.filter((row) => /removed|kept|edit|flag/i.test(row.action)).length}</p><span class="kpi__delta is-flat"><b>Recorded in the audit log</b></span></div>
      </div>
      <section class="panel">
        <div class="toolbar">
          <div class="segmented" role="tablist" aria-label="Content area" style="flex-wrap:wrap">
            <button type="button" role="tab" data-action="tab" data-id="deals" aria-pressed="${filters.tab === "deals"}">Deals</button>
            <button type="button" role="tab" data-action="tab" data-id="content" aria-pressed="${filters.tab === "content"}">Restaurant content</button>
          </div>
          ${searchField("d-q", filters.tab === "deals" ? "Search deal or restaurant" : "Search content, venue or author", filters.q)}
          ${filterControls}
        </div>
        <div id="region">${regionHtml()}</div>
      </section>`,
      mount(page) {
        page.querySelectorAll("[data-filter]").forEach((el) => {
          const key = el.dataset.filter.replace("d-", "");
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
    tab(value) {
      filters.tab = value;
      filters.status = "all";
      filters.q = "";
      filters.page = 1;
      refreshApp();
    },
    openDeal(id) {
      const row = state.deals.find((deal) => deal.id === id);
      if (row) dealDrawer(row);
    },
    openContent(id) {
      const row = state.contentItems.find((item) => item.id === id);
      if (row) contentDrawer(row);
    },
    pauseDeal(id) {
      setDeal([id], { status: "paused" }, "Paused deal publication", "warn");
      closeDrawer();
    },
    resumeDeal(id) {
      setDeal([id], { status: "live" }, "Published deal again", "success");
      closeDrawer();
    },
    approveDeal(id) {
      setDeal([id], { status: "live", reports: 0 }, "Approved deal after review", "success");
      closeDrawer();
    },
    removeDeal(id) {
      const row = state.deals.find((deal) => deal.id === id);
      if (!row) return;
      openModal({
        title: `Remove ${row.title}?`,
        body: `<p style="margin-top:6px;color:var(--muted);font-size:.84rem">The offer disappears from the customer app immediately. Partners can publish a corrected deal later.</p>
          <div class="field" style="margin-top:14px"><label for="dealWhy">Reason</label>
            <select class="select" id="dealWhy">
              <option>Discount refused at the venue</option>
              <option>Menu item no longer available</option>
              <option>Misleading price or imagery</option>
              <option>Expired outside the validity window</option>
              <option>Guideline violation</option>
            </select>
          </div>`,
        confirmLabel: "Remove deal",
        tone: "danger",
        onConfirm() {
          const reason = document.getElementById("dealWhy").value;
          commit({
            action: `Removed deal: ${reason}`,
            target: `${row.title} (${row.id})`,
            kind: "danger",
            apply: (draft) => { draft.deals = draft.deals.filter((deal) => deal.id !== id); },
          });
          closeDrawer();
          toast("Deal removed from the customer app");
        },
      });
    },
    contentKeep(id) {
      setContent([id], { status: "approved" }, "Kept content as published", "success");
      closeDrawer();
    },
    contentEdit(id) {
      const row = state.contentItems.find((item) => item.id === id);
      if (!row) return;
      openModal({
        title: "Request an edit",
        body: `<p style="margin-top:6px;color:var(--muted);font-size:.84rem">The author or partner receives the request in the app and the item stays hidden until it is resubmitted.</p>
          <div class="field" style="margin-top:14px"><label for="editAsk">What needs to change?</label><textarea class="textarea" id="editAsk" placeholder="For example: update the price to match the printed menu."></textarea></div>`,
        confirmLabel: "Send request",
        onConfirm() {
          const ask = document.getElementById("editAsk").value.trim();
          if (!ask) {
            toast("Describe the change needed", "danger");
            return false;
          }
          setContent([id], { status: "pending_review", editRequested: ask }, "Requested content edit", "warn");
          closeDrawer();
        },
      });
    },
    contentRemove(id) {
      const row = state.contentItems.find((item) => item.id === id);
      if (!row) return;
      openModal({
        title: `Remove this ${row.kind.toLowerCase()}?`,
        body: `<p style="margin-top:6px;color:var(--muted);font-size:.84rem">Removed content is deleted from the venue profile and the author is notified with the guideline reference.</p>`,
        confirmLabel: "Remove content",
        tone: "danger",
        onConfirm() {
          commit({
            action: `Removed ${row.kind.toLowerCase()} content`,
            target: `${row.target} (${row.id})`,
            kind: "danger",
            apply: (draft) => { draft.contentItems = draft.contentItems.filter((item) => item.id !== id); },
          });
          closeDrawer();
          toast("Content removed");
        },
      });
    },
    openVenue(id) {
      closeDrawer();
      navigate("restaurants");
      window.setTimeout(() => {
        document.querySelector(`[data-action="open"][data-id="${id}"]`)?.click();
      }, 60);
    },
    export() {
      const header = ["Time", "Admin", "Action", "Target"];
      const lines = [header, ...state.auditLog.map((row) => [new Date(row.at).toISOString(), row.actor, row.action, row.target])]
        .map((cells) => cells.map((cell) => `"${String(cell).replace(/"/g, '""')}"`).join(","))
        .join("\n");
      const blob = new Blob([lines], { type: "text/csv" });
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = "dinecircle-moderation-log.csv";
      link.click();
      URL.revokeObjectURL(url);
      toast("Moderation log exported");
    },
  },
};
