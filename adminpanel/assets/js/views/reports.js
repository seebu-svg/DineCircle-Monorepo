/* ==========================================================================
   Module: Reports & Safety (P0)
   Every guest and partner report lands here. The admin triages the case,
   applies a moderation action against the subject and closes it. All actions
   write to the same audit log the dashboard shows.
   ========================================================================== */
import { state, commit, displayDate, relativeTime, counts } from "../store.js";
import { icon, esc, avatar, statusBadge, openDrawer, closeDrawer, openModal, toast, pager, matches } from "../ui.js";
import { dataTable, searchField, selectField } from "./shared.js";
import { navigate, refreshApp } from "../router.js";

const PER_PAGE = 8;
const TABS = [
  { value: "open", label: "Open" },
  { value: "in_review", label: "In review" },
  { value: "resolved", label: "Resolved" },
  { value: "dismissed", label: "Dismissed" },
  { value: "all", label: "All cases" },
];
const filters = { q: "", tab: "open", type: "all", severity: "all", page: 1 };

const ACTIONS = {
  Venue: [
    { action: "modVenueSuspend", label: "Suspend the venue", tone: "danger", icon: "pause" },
    { action: "modDealReview", label: "Review venue deals", tone: "outline", icon: "tag" },
    { action: "modWarn", label: "Issue a warning", tone: "outline", icon: "alert" },
  ],
  Host: [
    { action: "modHostSuspend", label: "Suspend the host", tone: "danger", icon: "pause" },
    { action: "modExperienceReview", label: "Review hosted experiences", tone: "outline", icon: "calendar" },
    { action: "modWarn", label: "Issue a warning", tone: "outline", icon: "alert" },
  ],
  Customer: [
    { action: "modCustomerSuspend", label: "Suspend the diner account", tone: "danger", icon: "lock" },
    { action: "modWarn", label: "Issue a warning", tone: "outline", icon: "alert" },
  ],
  Review: [
    { action: "modContentRemove", label: "Remove the review", tone: "danger", icon: "trash" },
    { action: "modWarn", label: "Warn the reviewer", tone: "outline", icon: "alert" },
  ],
  Deal: [
    { action: "modDealRemove", label: "Remove the deal", tone: "danger", icon: "trash" },
    { action: "modVenueSuspend", label: "Suspend the venue", tone: "outline", icon: "pause" },
  ],
  Experience: [
    { action: "modExperienceCancel", label: "Cancel the experience", tone: "danger", icon: "x" },
    { action: "modExperienceReview", label: "Send experience back to review", tone: "outline", icon: "eye" },
  ],
};

function visible() {
  return state.reports
    .filter((row) => {
      if (filters.tab !== "all" && row.status !== filters.tab) return false;
      if (filters.type !== "all" && row.type !== filters.type) return false;
      if (filters.severity !== "all" && row.severity !== filters.severity) return false;
      if (filters.q && !matches(`${row.subject} ${row.reason} ${row.reporter} ${row.id} ${row.detail}`, filters.q)) return false;
      return true;
    })
    .sort((a, b) => {
      const weight = { high: 0, medium: 1, low: 2 };
      return weight[a.severity] - weight[b.severity] || new Date(b.created) - new Date(a.created);
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

function patch(ids, changes, action, kind) {
  const rows = state.reports.filter((row) => ids.includes(row.id));
  if (!rows.length) return;
  commit({
    action,
    target: rows.map((row) => `${row.subject} (${row.id})`).join(", "),
    kind,
    apply: () => rows.forEach((row) => Object.assign(row, changes)),
  });
  toast(`${rows.length} case${rows.length === 1 ? "" : "s"} updated`);
}

function findSubject(row) {
  if (row.type === "Venue") return state.restaurants.find((item) => item.id === row.subjectId || item.name === row.subject);
  if (row.type === "Host") return state.hosts.find((item) => item.id === row.subjectId || item.name === row.subject);
  if (row.type === "Customer") return state.customers.find((item) => item.id === row.subjectId || item.name === row.subject);
  if (row.type === "Deal") return state.deals.find((item) => item.id === row.subjectId);
  if (row.type === "Experience") return state.experiences.find((item) => item.id === row.subjectId);
  return state.contentItems.find((item) => item.id === row.subjectId);
}

function drawer(row) {
  const subject = findSubject(row);
  const menu = ACTIONS[row.type] || [{ action: "modWarn", label: "Issue a warning", tone: "outline", icon: "alert" }];
  const open = row.status === "open" || row.status === "in_review";
  openDrawer({
    title: row.subject,
    subtitle: `${row.id} · ${row.type} report`,
    tone: row.severity === "high" && open ? "danger" : "orange",
    body: `
      <div class="row" style="gap:8px;margin-bottom:14px">
        <span class="badge badge--${row.severity === "high" ? "danger" : row.severity === "medium" ? "warn" : "quiet"}">${esc(row.severity)} severity</span>
        ${statusBadge(row.status)}
        <span class="chip">${icon("clock")}raised ${esc(relativeTime(row.created))}</span>
      </div>
      <div class="issue" style="background:var(--cream)">
        <b>${esc(row.reason)}</b>
        <span>Reported by ${esc(row.reporter)}</span>
        <p>${esc(row.detail)}</p>
      </div>
      <hr class="divider">
      <dl class="detail-grid">
        <div><dt>Subject type</dt><dd>${esc(row.type)}</dd></div>
        <div><dt>Subject record</dt><dd>${esc(row.subjectId)}</dd></div>
        <div><dt>Current status</dt><dd>${subject ? esc(subject.status) : "Not found"}</dd></div>
        <div><dt>First raised</dt><dd>${esc(displayDate(row.created, true))}</dd></div>
        <div><dt>SLA</dt><dd>${row.severity === "high" ? "Respond within 24 hours" : "Respond within 72 hours"}</dd></div>
        <div><dt>Decisions logged</dt><dd>${subject ? (subject.decisions || []).length : 0}</dd></div>
      </dl>
      <hr class="divider">
      <h3 style="margin-bottom:8px">Moderation actions</h3>
      <div class="row" style="gap:8px">
        ${menu
          .map(
            (item) => `<button class="btn btn--${item.tone === "danger" ? "danger-ghost" : "outline"} btn--sm" type="button" data-action="${item.action}" data-id="${row.id}">${icon(item.icon)} ${esc(item.label)}</button>`
          )
          .join("")}
      </div>
      <hr class="divider">
      <h3 style="margin-bottom:8px">Case history</h3>
      <div class="timeline">
        <div class="timeline__item timeline__item--orange">
          <strong>Report received</strong>
          <p>${esc(row.detail.slice(0, 90))}</p>
          <time>${esc(displayDate(row.created, true))}</time>
        </div>
        ${(row.history || [])
          .map(
            (step) => `<div class="timeline__item timeline__item--${step.kind}">
              <strong>${esc(step.label)}</strong>
              <p>${esc(step.note || "")}</p>
              <time>${esc(displayDate(step.at, true))}</time>
            </div>`
          )
          .join("")}
        ${row.closedAt ? `<div class="timeline__item timeline__item--success"><strong>Case closed</strong><p>${esc(row.resolution || "")}</p><time>${esc(displayDate(row.closedAt, true))}</time></div>` : ""}
      </div>`,
    foot: `${open ? `<button class="btn btn--outline" type="button" data-action="startReview" data-id="${row.id}">${icon("eye")} Start review</button>
      <button class="btn btn--danger-ghost" type="button" data-action="dismiss" data-id="${row.id}">${icon("x")} Dismiss</button>
      <button class="btn btn--primary" type="button" data-action="resolve" data-id="${row.id}">${icon("check")} Resolve case</button>` : `<button class="btn btn--outline" type="button" data-action="reopen" data-id="${row.id}">${icon("refresh")} Reopen case</button>`}`,
  });
}

function regionHtml() {
  const rows = pageRows();
  return `${dataTable({
    rowAction: "open",
    emptyTitle: "No cases in this queue",
    emptyText: "Switch the tab or clear the filters to see other reports.",
    emptyIcon: "shield",
    columns: [
      { label: "Case", render: (row) => `<span class="cell-main">${esc(row.id)}</span>` },
      { label: "Type", render: (row) => `<span class="chip">${esc(row.type)}</span>` },
      {
        label: "Subject",
        render: (row) => `<div class="table__who">${avatar(row.subject)}<div><strong>${esc(row.subject)}</strong><span>${esc(row.subjectId)}</span></div></div>`,
      },
      { label: "Reason", render: (row) => `${esc(row.reason)}<span class="cell-sub">by ${esc(row.reporter)}</span>` },
      {
        label: "Severity",
        render: (row) => `<span class="badge badge--${row.severity === "high" ? "danger" : row.severity === "medium" ? "warn" : "quiet"}">${esc(row.severity)}</span>`,
      },
      { label: "Raised", render: (row) => esc(relativeTime(row.created)) },
      { label: "Status", render: (row) => statusBadge(row.status) },
    ],
    rows,
  })}
  <div class="panel__foot">
    ${pager(visible().length, filters.page, PER_PAGE, "reports")}
    <span>${counts().openReports} cases need attention</span>
  </div>`;
}

export default {
  title: "Reports & Safety",
  eyebrow: "Trust & content",
  description: "Triage guest and partner reports, act on the subject and keep a complete audit trail of every moderation decision.",

  render() {
    const badge = counts();
    const high = state.reports.filter((row) => row.severity === "high" && ["open", "in_review"].includes(row.status)).length;
    const resolved = state.reports.filter((row) => row.status === "resolved").length;
    const dismissed = state.reports.filter((row) => row.status === "dismissed").length;
    const actions = `<a class="btn btn--outline" href="#/deals">${icon("tag")} Content queue</a>
      <button class="btn btn--primary" type="button" data-action="exportAudit">${icon("download")} Export audit log</button>`;
    return {
      actions,
      body: `<div class="grid grid--kpi">
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Open cases</span><span class="kpi__icon">${icon("shield")}</span></div><p class="kpi__value">${badge.openReports}</p><span class="kpi__delta is-flat"><b>Sorted by severity</b></span></div>
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">High severity</span><span class="kpi__icon">${icon("alert")}</span></div><p class="kpi__value">${high}</p><span class="kpi__delta is-flat"><b>24 hour response target</b></span></div>
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Resolved</span><span class="kpi__icon">${icon("checkCircle")}</span></div><p class="kpi__value">${resolved}</p><span class="kpi__delta is-flat"><b>Action taken</b></span></div>
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Dismissed</span><span class="kpi__icon">${icon("x")}</span></div><p class="kpi__value">${dismissed}</p><span class="kpi__delta is-flat"><b>No violation found</b></span></div>
      </div>
      <section class="panel">
        <div class="toolbar">
          <div class="segmented" role="tablist" aria-label="Case queue" style="flex-wrap:wrap">
            ${TABS.map((tab) => `<button type="button" role="tab" data-action="tab" data-id="${tab.value}" aria-pressed="${filters.tab === tab.value}">${esc(tab.label)}</button>`).join("")}
          </div>
          ${searchField("r-q", "Search subject, reason or case ID", filters.q)}
          ${selectField(
            "r-type",
            [{ value: "all", label: "All subject types" }, ...[...new Set(state.reports.map((row) => row.type))].map((type) => ({ value: type, label: type }))],
            filters.type
          )}
          ${selectField(
            "r-sev",
            [
              { value: "all", label: "Any severity" },
              { value: "high", label: "High" },
              { value: "medium", label: "Medium" },
              { value: "low", label: "Low" },
            ],
            filters.severity
          )}
        </div>
        <div id="region">${regionHtml()}</div>
      </section>
      <div class="grid grid--2">
        <section class="panel">
          <div class="panel__head"><div style="flex:1"><h2>Audit log</h2><p>Every admin decision, newest first</p></div></div>
          <div class="timeline" style="padding:18px 18px 18px 40px">
            ${state.auditLog
              .slice(0, 7)
              .map(
                (entry) => `<div class="timeline__item timeline__item--${entry.kind}">
                  <strong>${esc(entry.action)}</strong>
                  <p>${esc(entry.target)} · ${esc(entry.actor)}</p>
                  <time>${esc(displayDate(entry.at, true))}</time>
                </div>`
              )
              .join("")}
          </div>
        </section>
        <section class="panel">
          <div class="panel__head"><div style="flex:1"><h2>Safety playbook</h2><p>Standing rules applied by trust and safety</p></div></div>
          <div class="panel__body">
            <div class="stat-row"><span>Deal refused twice by the same venue</span><b>Remove deal, warn venue</b></div>
            <div class="stat-row"><span>Three no shows in 30 days</span><b>Suspend diner booking rights</b></div>
            <div class="stat-row"><span>Abusive language in a review</span><b>Remove review, warn author</b></div>
            <div class="stat-row"><span>Experience cancelled without notice</span><b>Pause host, notify guests</b></div>
            <div class="stat-row"><span>Price differs from the printed menu</span><b>Hide menu item until corrected</b></div>
            <div class="note" style="margin-top:16px">${icon("shield")}<span>Guidelines are published to diners and partners at <strong>community-guidelines</strong> on the marketing site, so every action here maps to a rule the account already agreed to.</span></div>
          </div>
        </section>
      </div>`,
      mount(page) {
        page.querySelectorAll("[data-filter]").forEach((el) => {
          const key = el.dataset.filter.replace("r-", "");
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
      const row = state.reports.find((report) => report.id === id);
      if (row) drawer(row);
    },
    tab(value) {
      filters.tab = value;
      filters.page = 1;
      refreshApp();
    },
    startReview(id) {
      patch([id], { status: "in_review" }, "Started report review", "info");
      const row = state.reports.find((report) => report.id === id);
      if (row) drawer(row);
    },
    resolve(id) {
      const row = state.reports.find((report) => report.id === id);
      if (!row) return;
      openModal({
        title: `Resolve ${row.id}`,
        body: `<p style="margin-top:6px;color:var(--muted);font-size:.84rem">The reporter is notified with the outcome. Anything actioned against the subject is already recorded separately in the audit log.</p>
          <div class="field" style="margin-top:14px"><label for="resOut">Outcome</label>
            <select class="select" id="resOut">
              <option>Action taken against the subject</option>
              <option>Subject corrected the issue</option>
              <option>Warned, no further action</option>
              <option>No violation found</option>
            </select>
          </div>
          <div class="field"><label for="resNote">Note for the case history</label><textarea class="textarea" id="resNote" placeholder="What was done and when?"></textarea></div>`,
        confirmLabel: "Resolve case",
        onConfirm() {
          const outcome = document.getElementById("resOut").value;
          const note = document.getElementById("resNote").value.trim();
          commit({
            action: `Resolved report: ${outcome}`,
            target: `${row.subject} (${row.id})`,
            kind: "success",
            apply: () => {
              row.status = "resolved";
              row.resolution = note ? `${outcome}. ${note}` : outcome;
              row.closedAt = new Date().toISOString();
              row.history = [...(row.history || []), { label: outcome, note, kind: "success", at: new Date().toISOString() }];
            },
          });
          closeDrawer();
          toast("Case resolved and reporter notified");
        },
      });
    },
    dismiss(id) {
      const row = state.reports.find((report) => report.id === id);
      if (!row) return;
      openModal({
        title: `Dismiss ${row.id}?`,
        body: `<p style="margin-top:6px;color:var(--muted);font-size:.84rem">Use this when the report does not violate the community guidelines. The reporter sees the reason.</p>
          <div class="field" style="margin-top:14px"><label for="dismissWhy">Reason</label>
            <select class="select" id="dismissWhy">
              <option>Honest feedback is allowed</option>
              <option>Evidence does not support the claim</option>
              <option>Duplicate of an existing case</option>
              <option>Handled directly by the venue</option>
            </select>
          </div>`,
        confirmLabel: "Dismiss report",
        tone: "danger",
        onConfirm() {
          const reason = document.getElementById("dismissWhy").value;
          commit({
            action: `Dismissed report: ${reason}`,
            target: `${row.subject} (${row.id})`,
            kind: "warn",
            apply: () => {
              row.status = "dismissed";
              row.resolution = reason;
              row.closedAt = new Date().toISOString();
              row.history = [...(row.history || []), { label: reason, kind: "warn", at: new Date().toISOString() }];
            },
          });
          closeDrawer();
          toast("Report dismissed", "danger");
        },
      });
    },
    reopen(id) {
      patch([id], { status: "in_review", closedAt: null }, "Reopened report case", "warn");
      const row = state.reports.find((report) => report.id === id);
      if (row) drawer(row);
    },
    modVenueSuspend(id) {
      const row = state.reports.find((report) => report.id === id);
      const venue = row && state.restaurants.find((item) => item.id === row.subjectId || item.name === row.subject);
      if (!venue) {
        toast("No venue record attached to this case", "danger");
        return;
      }
      openModal({
        title: `Suspend ${venue.name}?`,
        body: `<p style="margin-top:6px;color:var(--muted);font-size:.84rem">The venue is hidden from the customer app and the case history records the action.</p>`,
        confirmLabel: "Suspend and log",
        tone: "danger",
        onConfirm() {
          commit({
            action: `Suspended restaurant from safety case ${row.id}`,
            target: `${venue.name} (${venue.id})`,
            kind: "danger",
            apply: () => {
              venue.status = "suspended";
              venue.suspendReason = row.reason;
              row.history = [...(row.history || []), { label: "Venue suspended", note: row.reason, kind: "danger", at: new Date().toISOString() }];
              row.status = "in_review";
            },
          });
          drawer(row);
          toast(`${venue.name} suspended and hidden from discovery`);
        },
      });
    },
    modHostSuspend(id) {
      const row = state.reports.find((report) => report.id === id);
      const host = row && state.hosts.find((item) => item.id === row.subjectId || item.name === row.subject);
      if (!host) {
        toast("No host record attached to this case", "danger");
        return;
      }
      commit({
        action: `Suspended host from safety case ${row.id}`,
        target: `${host.name} (${host.id})`,
        kind: "danger",
        apply: () => {
          host.status = "suspended";
          host.issueNote = row.reason;
          row.history = [...(row.history || []), { label: "Host suspended", note: row.reason, kind: "danger", at: new Date().toISOString() }];
          row.status = "in_review";
        },
      });
      drawer(row);
      toast(`${host.name} suspended from Host Studio`);
    },
    modCustomerSuspend(id) {
      const row = state.reports.find((report) => report.id === id);
      const customer = row && state.customers.find((item) => item.id === row.subjectId || item.name === row.subject);
      if (!customer) {
        toast("No customer record attached to this case", "danger");
        return;
      }
      commit({
        action: `Suspended customer from safety case ${row.id}`,
        target: `${customer.name} (${customer.id})`,
        kind: "danger",
        apply: () => {
          customer.status = "suspended";
          customer.issueNote = row.reason;
          row.history = [...(row.history || []), { label: "Diner suspended", note: row.reason, kind: "danger", at: new Date().toISOString() }];
          row.status = "in_review";
        },
      });
      drawer(row);
      toast(`${customer.name} cannot book until reinstated`);
    },
    modWarn(id) {
      const row = state.reports.find((report) => report.id === id);
      if (!row) return;
      commit({
        action: `Issued guideline warning from case ${row.id}`,
        target: row.subject,
        kind: "warn",
        apply: () => {
          row.history = [...(row.history || []), { label: "Warning issued", note: row.reason, kind: "orange", at: new Date().toISOString() }];
          row.status = "in_review";
        },
      });
      drawer(row);
      toast("Warning issued to the subject account");
    },
    modContentRemove(id) {
      const row = state.reports.find((report) => report.id === id);
      if (!row) return;
      commit({
        action: `Removed reported review from case ${row.id}`,
        target: row.subject,
        kind: "danger",
        apply: (draft) => {
          draft.contentItems = draft.contentItems.filter((item) => item.id !== row.subjectId);
          row.history = [...(row.history || []), { label: "Review removed", note: row.reason, kind: "danger", at: new Date().toISOString() }];
          row.status = "resolved";
          row.closedAt = new Date().toISOString();
        },
      });
      drawer(row);
      toast("Review removed from the venue profile");
    },
    modDealRemove(id) {
      const row = state.reports.find((report) => report.id === id);
      const deal = row && state.deals.find((item) => item.id === row.subjectId);
      if (!deal) {
        navigate("deals");
        return;
      }
      commit({
        action: `Removed reported deal from case ${row.id}`,
        target: `${deal.title} (${deal.id})`,
        kind: "danger",
        apply: (draft) => {
          draft.deals = draft.deals.filter((item) => item.id !== deal.id);
          row.history = [...(row.history || []), { label: "Deal removed", note: row.reason, kind: "danger", at: new Date().toISOString() }];
          row.status = "in_review";
        },
      });
      drawer(row);
      toast("Deal removed from the customer app");
    },
    modDealReview() {
      closeDrawer();
      navigate("deals");
    },
    modExperienceReview() {
      closeDrawer();
      navigate("experiences");
    },
    modExperienceCancel(id) {
      const row = state.reports.find((report) => report.id === id);
      const experience = row && state.experiences.find((item) => item.id === row.subjectId);
      if (!experience) {
        navigate("experiences");
        return;
      }
      commit({
        action: `Cancelled experience from safety case ${row.id}`,
        target: `${experience.title} (${experience.id})`,
        kind: "danger",
        apply: () => {
          experience.status = "cancelled";
          experience.note = `${experience.note} Cancelled by trust and safety: ${row.reason}`;
          row.history = [...(row.history || []), { label: "Experience cancelled", note: row.reason, kind: "danger", at: new Date().toISOString() }];
          row.status = "in_review";
        },
      });
      drawer(row);
      toast("Experience cancelled and guests flagged for notification");
    },
    exportAudit() {
      const header = ["Time", "Admin", "Action", "Target", "Severity"];
      const lines = [
        header,
        ...state.auditLog.map((entry) => [new Date(entry.at).toISOString(), entry.actor, entry.action, entry.target, entry.kind]),
        ...state.reports.map((report) => [report.created, report.reporter, `Report ${report.status}`, `${report.subject} (${report.id})`, report.severity]),
      ]
        .map((cells) => cells.map((cell) => `"${String(cell).replace(/"/g, '""')}"`).join(","))
        .join("\n");
      const blob = new Blob([lines], { type: "text/csv" });
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = "dinecircle-audit-log.csv";
      link.click();
      URL.revokeObjectURL(url);
      toast("Audit log exported");
    },
  },
};
