/* ==========================================================================
   Module: Customer Management (P0)
   Diner accounts are free and carry no payment data. Support looks up an
   account, reads reported behaviour, and suspends or restores access.
   ========================================================================== */
import { state, commit, displayDate, relativeTime } from "../store.js";
import { icon, esc, avatar, statusBadge, openDrawer, closeDrawer, openModal, toast, pager, matches } from "../ui.js";
import { dataTable, searchField, selectField } from "./shared.js";
import { metrics } from "../data.js";

const PER_PAGE = 8;
const filters = { q: "", status: "all", city: "all", sort: "recent", page: 1 };
const selected = [];

const CITIES = ["all", "Karachi", "Lahore", "Islamabad"];

function visible() {
  return state.customers
    .filter((row) => {
      if (filters.status !== "all" && row.status !== filters.status) return false;
      if (filters.city !== "all" && row.city !== filters.city) return false;
      if (filters.q && !matches(`${row.name} ${row.email} ${row.city} ${row.id}`, filters.q)) return false;
      return true;
    })
    .sort((a, b) => {
      if (filters.sort === "issues") return b.issues - a.issues || b.bookings - a.bookings;
      if (filters.sort === "bookings") return b.bookings - a.bookings;
      if (filters.sort === "name") return a.name.localeCompare(b.name);
      return new Date(b.lastActive) - new Date(a.lastActive);
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

function setStatus(ids, status, action, kind, extra = {}) {
  const rows = state.customers.filter((row) => ids.includes(row.id));
  if (!rows.length) return;
  commit({
    action,
    target: rows.map((row) => `${row.name} (${row.id})`).join(", "),
    kind,
    apply: () =>
      rows.forEach((row) => {
        row.status = status;
        Object.assign(row, extra);
      }),
  });
  selected.length = 0;
  toast(`${rows.length} account${rows.length === 1 ? "" : "s"} updated`);
}

function askSuspend(ids) {
  const rows = state.customers.filter((row) => ids.includes(row.id));
  if (!rows.length) return;
  openModal({
    title: rows.length === 1 ? `Suspend ${rows[0].name}?` : `Suspend ${rows.length} accounts?`,
    body: `<p style="margin-top:6px;color:var(--muted);font-size:.84rem">The diner is signed out of the app and cannot make new reservations. Past reservations and reviews stay visible for the venues involved.</p>
      <div class="field" style="margin-top:14px"><label for="cReason">Reason for the audit log</label>
        <select class="select" id="cReason">
          <option>Repeated reservation no-shows</option>
          <option>Abusive reviews or language</option>
          <option>Spam or promotional links in reviews</option>
          <option>Experience cancellation abuse</option>
          <option>Suspicious account activity</option>
        </select>
      </div>
      <div class="field"><label for="cNote">Support note (optional)</label><textarea class="textarea" id="cNote" placeholder="What was communicated to the diner?"></textarea></div>`,
    confirmLabel: "Suspend account",
    tone: "danger",
    onConfirm() {
      const reason = document.getElementById("cReason").value;
      const note = document.getElementById("cNote").value.trim();
      setStatus(ids, "suspended", `Suspended customer: ${reason}`, "danger", { issueNote: note ? `${reason}. ${note}` : reason });
      closeDrawer();
    },
  });
}

function relatedReports(row) {
  return state.reports.filter((rep) => rep.subjectId === row.id || rep.reporter === row.name);
}

function drawer(row) {
  const reports = relatedReports(row);
  const reviews = row.reviews;
  openDrawer({
    title: row.name,
    subtitle: `${row.id} · ${row.city}`,
    tone: row.status === "suspended" ? "danger" : "orange",
    body: `
      <div class="person-head" style="margin-bottom:18px">
        ${avatar(row.name, "lg")}
        <div><h2>${esc(row.name)}</h2><p>${esc(row.email)}</p></div>
        <span style="margin-left:auto">${statusBadge(row.status)}</span>
      </div>
      ${row.issueNote ? `<div class="note" style="margin-bottom:16px">${icon("alert")}<span><strong>Account note</strong> ${esc(row.issueNote)}</span></div>` : ""}
      <dl class="detail-grid">
        <div><dt>Joined</dt><dd>${esc(displayDate(row.joined))}</dd></div>
        <div><dt>Last active</dt><dd>${esc(relativeTime(row.lastActive))}</dd></div>
        <div><dt>Reservations</dt><dd>${row.bookings}</dd></div>
        <div><dt>Reviews written</dt><dd>${reviews}</dd></div>
        <div><dt>Open issues</dt><dd>${row.issues}</dd></div>
        <div><dt>Payment data</dt><dd>None. The diner app is free.</dd></div>
      </dl>
      <hr class="divider">
      <h3 style="margin-bottom:8px">Account issues</h3>
      ${
        reports.length
          ? reports
              .map(
                (rep) => `<div class="issue">
                  <b>${esc(rep.reason)}</b>
                  <span>${esc(rep.id)} · ${esc(rep.type)} · ${esc(statusBadge(rep.status).replace(/<[^>]+>/g, "").trim())} · ${esc(relativeTime(rep.created))}</span>
                  <p>${esc(rep.detail)}</p>
                </div>`
              )
              .join("")
          : `<p style="font-size:.82rem;color:var(--muted)">No reports reference this account. Support can still open a case from the Reports module.</p>`
      }
      <hr class="divider">
      <h3 style="margin-bottom:8px">Simulated reservation history</h3>
      <div class="stat-row"><span>Confirmed tables</span><b>${Math.max(row.bookings - 1, 0)}</b></div>
      <div class="stat-row"><span>No shows recorded</span><b>${row.status === "suspended" ? 3 : row.issues ? 1 : 0}</b></div>
      <div class="stat-row"><span>Experience seats joined</span><b>${row.bookings > 10 ? 2 : row.bookings > 4 ? 1 : 0}</b></div>`,
    foot: `${row.status === "flagged" ? `<button class="btn btn--outline" type="button" data-action="clearFlag" data-id="${row.id}">${icon("check")} Clear flag</button>` : ""}
      ${
        row.status === "suspended"
          ? `<button class="btn btn--outline" type="button" data-action="emailCustomer" data-id="${row.id}">${icon("mail")} Contact</button>
             <button class="btn btn--primary" type="button" data-action="restore" data-id="${row.id}">${icon("play")} Restore access</button>`
          : `<button class="btn btn--outline" type="button" data-action="emailCustomer" data-id="${row.id}">${icon("mail")} Contact</button>
             <button class="btn btn--danger-ghost" type="button" data-action="suspendCustomer" data-id="${row.id}">${icon("pause")} Suspend</button>`
      }`,
  });
}

function bulkBar() {
  if (!selected.length) return "";
  return `<div class="bulkbar">
    <b>${selected.length}</b> selected
    <button class="btn btn--sm btn--outline" type="button" data-action="bulkFlag">${icon("flag")} Flag for review</button>
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
    emptyTitle: "No accounts match",
    emptyText: "Try another city, status or search term.",
    columns: [
      {
        label: "Customer",
        render: (row) => `<div class="table__who">${avatar(row.name)}<div><strong>${esc(row.name)}</strong><span>${esc(row.email)}</span></div></div>`,
      },
      { label: "City", render: (row) => esc(row.city) },
      { label: "Joined", render: (row) => `${esc(displayDate(row.joined))}<span class="cell-sub">${esc(relativeTime(row.joined))}</span>` },
      { label: "Reservations", cls: "cell-num", render: (row) => row.bookings },
      { label: "Reviews", cls: "cell-num", render: (row) => row.reviews },
      { label: "Issues", cls: "cell-num", render: (row) => (row.issues ? `<span class="badge badge--danger">${row.issues}</span>` : `<span class="badge badge--quiet">0</span>`) },
      { label: "Status", render: (row) => statusBadge(row.status) },
      { label: "Last active", render: (row) => esc(relativeTime(row.lastActive)) },
    ],
    rows: pageRows(),
  })}
  <div class="panel__foot">
    ${pager(visible().length, filters.page, PER_PAGE, "customers")}
    <span>${metrics.customers.total.toLocaleString()} diners platform wide</span>
  </div>`;
}

export default {
  title: "Customer Management",
  eyebrow: "Community",
  description: "Look up diner accounts, review reported behaviour, suspend or restore access. Customer accounts hold no payment data.",

  render() {
    const count = (status) => state.customers.filter((row) => row.status === status).length;
    const actions = `<a class="btn btn--outline" href="#/reports">${icon("shield")} Safety reports</a>
      <button class="btn btn--primary" type="button" data-action="exportList">${icon("download")} Export filtered list</button>`;
    return {
      actions,
      body: `<div class="grid grid--kpi">
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Customers</span><span class="kpi__icon">${icon("users")}</span></div><p class="kpi__value">${metrics.customers.total.toLocaleString()}</p><span class="kpi__delta is-up"><b>${icon("arrowUp")}${metrics.customers.delta}%</b> vs last month</span></div>
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Flagged for review</span><span class="kpi__icon">${icon("flag")}</span></div><p class="kpi__value">${count("flagged")}</p><span class="kpi__delta is-flat"><b>Support queue</b></span></div>
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Suspended</span><span class="kpi__icon">${icon("lock")}</span></div><p class="kpi__value">${count("suspended")}</p><span class="kpi__delta is-flat"><b>Cannot book</b></span></div>
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Accounts in this slice</span><span class="kpi__icon">${icon("user")}</span></div><p class="kpi__value">${state.customers.length}</p><span class="kpi__delta is-flat"><b>Most recent sign ups</b></span></div>
      </div>
      <section class="panel">
        <div class="toolbar">
          ${searchField("c-q", "Search name, email or account ID", filters.q)}
          ${selectField(
            "c-status",
            [
              { value: "all", label: "All statuses" },
              { value: "active", label: "Active" },
              { value: "flagged", label: "Flagged" },
              { value: "suspended", label: "Suspended" },
            ],
            filters.status
          )}
          ${selectField("c-city", CITIES.map((city) => ({ value: city, label: city === "all" ? "All cities" : city })), filters.city)}
          ${selectField(
            "c-sort",
            [
              { value: "recent", label: "Recently active" },
              { value: "issues", label: "Most issues" },
              { value: "bookings", label: "Most reservations" },
              { value: "name", label: "Name A to Z" },
            ],
            filters.sort
          )}
        </div>
        <div id="region">${regionHtml()}</div>
      </section>`,
      mount(page) {
        page.querySelectorAll("[data-filter]").forEach((el) => {
          const key = el.dataset.filter.replace("c-", "");
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
      const row = state.customers.find((customer) => customer.id === id);
      if (row) drawer(row);
    },
    suspendCustomer(id) {
      askSuspend([id]);
    },
    bulkSuspend() {
      askSuspend([...selected]);
    },
    restore(id) {
      setStatus([id], "active", "Restored customer access", "success", { issueNote: "" });
      closeDrawer();
    },
    clearFlag(id) {
      setStatus([id], "active", "Cleared customer flag", "info", { issues: 0 });
      closeDrawer();
    },
    bulkFlag() {
      const rows = state.customers.filter((row) => selected.includes(row.id));
      commit({
        action: "Flagged customers for review",
        target: rows.map((row) => row.name).join(", "),
        kind: "warn",
        apply: () =>
          rows.forEach((row) => {
            row.status = "flagged";
            row.issues = (row.issues || 0) + 1;
          }),
      });
      selected.length = 0;
      toast(`${rows.length} account${rows.length === 1 ? "" : "s"} flagged`);
    },
    emailCustomer(id) {
      const row = state.customers.find((customer) => customer.id === id);
      if (!row) return;
      openModal({
        title: `Contact ${row.name}`,
        body: `<div class="field" style="margin-top:14px"><label for="msgSubject">Subject</label><input class="input" id="msgSubject" value="Your DineCircle reservations"></div>
          <div class="field"><label for="msgBody">Message</label><textarea class="textarea" id="msgBody" style="min-height:130px">Hello ${esc(row.name.split(" ")[0])},

We are following up about your DineCircle account. Reply to this message and our support team will help you right away.

Thank you,
DineCircle Support</textarea></div>
          <p style="margin-top:12px;font-size:.76rem;color:var(--muted)">Prototype behaviour: nothing is sent. Production would post to the support email queue with the account ID attached.</p>`,
        confirmLabel: "Queue message",
        onConfirm() {
          commit({
            action: "Queued support message",
            target: `${row.name} (${row.id})`,
            kind: "info",
            apply: () => { row.contactedAt = new Date().toISOString(); },
          });
          toast("Support message queued");
        },
      });
    },
    exportList() {
      const header = ["Account", "Name", "Email", "City", "Status", "Reservations", "Issues"];
      const lines = [header, ...visible().map((row) => [row.id, row.name, row.email, row.city, row.status, row.bookings, row.issues])]
        .map((cells) => cells.join(","))
        .join("\n");
      const blob = new Blob([lines], { type: "text/csv" });
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = "dinecircle-customers.csv";
      link.click();
      URL.revokeObjectURL(url);
      toast(`${visible().length} rows exported`);
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
