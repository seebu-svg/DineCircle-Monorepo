/* ==========================================================================
   Module: Host Management (P0)
   Professional hosts are diner accounts promoted to account_type
   "professional" so they can run Host Studio, host experiences and collaborate
   with venues. Access, status and guest reports are reviewed here.
   ========================================================================== */
import { state, commit, displayDate, relativeTime, counts } from "../store.js";
import { icon, esc, avatar, statusBadge, openDrawer, closeDrawer, openModal, toast, pager, matches } from "../ui.js";
import { dataTable, searchField, selectField } from "./shared.js";
import { metrics } from "../data.js";
import { navigate } from "../router.js";

const PER_PAGE = 8;
const filters = { q: "", status: "all", type: "all", sort: "experiences", page: 1 };

const HOST_TYPES = ["Dining host", "Food creator", "Lifestyle creator", "Community host"];

function visible() {
  return state.hosts
    .filter((row) => {
      if (filters.status !== "all" && row.status !== filters.status) return false;
      if (filters.type !== "all" && row.type !== filters.type) return false;
      if (filters.q && !matches(`${row.name} ${row.email} ${row.type} ${row.city} ${row.id}`, filters.q)) return false;
      return true;
    })
    .sort((a, b) => {
      if (filters.sort === "rating") return b.rating - a.rating;
      if (filters.sort === "reports") return b.reports - a.reports;
      if (filters.sort === "name") return a.name.localeCompare(b.name);
      if (filters.sort === "guests") return b.guests - a.guests;
      return b.experiences - a.experiences;
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
  const rows = state.hosts.filter((row) => ids.includes(row.id));
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
  toast(`${rows.length} host${rows.length === 1 ? "" : "s"} set to ${status}`);
}

function hostExperiences(row) {
  return state.experiences.filter((exp) => exp.host === row.name);
}

function hostReports(row) {
  return state.reports.filter((rep) => rep.subjectId === row.id || rep.subject === row.name);
}

function askSuspend(ids) {
  const rows = state.hosts.filter((row) => ids.includes(row.id));
  if (!rows.length) return;
  openModal({
    title: rows.length === 1 ? `Suspend ${rows[0].name}?` : `Suspend ${rows.length} hosts?`,
    body: `<p style="margin-top:6px;color:var(--muted);font-size:.84rem">Host Studio access is revoked and upcoming experiences are marked for review, so guests are not left with a booked event that cannot run.</p>
      <div class="field" style="margin-top:14px"><label for="hReason">Reason for the audit log</label>
        <select class="select" id="hReason">
          <option>Experience cancelled without notice</option>
          <option>Advertised content not delivered</option>
          <option>Repeated late starts</option>
          <option>Guest safety concern</option>
          <option>Unverified venue collaboration</option>
        </select>
      </div>
      <div class="field"><label for="hDays">Suspension length</label>
        <select class="select" id="hDays">
          <option value="7">7 days</option>
          <option value="30">30 days</option>
          <option value="0">Until reviewed by trust and safety</option>
        </select>
      </div>`,
    confirmLabel: "Suspend host",
    tone: "danger",
    onConfirm() {
      const reason = document.getElementById("hReason").value;
      const days = Number(document.getElementById("hDays").value);
      const label = days === 0 ? "indefinite" : `${days} days`;
      setStatus(ids, "suspended", `Suspended host: ${reason} (${label})`, "danger", { issueNote: `${reason}. Suspension: ${label}.` });
      closeDrawer();
    },
  });
}

function drawer(row) {
  const experiences = hostExperiences(row);
  const reports = hostReports(row);
  const open = reports.filter((rep) => ["open", "in_review"].includes(rep.status));
  openDrawer({
    title: row.name,
    subtitle: `${row.id} · ${row.type}`,
    tone: row.status === "suspended" ? "danger" : "orange",
    body: `
      <div class="person-head" style="margin-bottom:18px">
        ${avatar(row.name, "lg")}
        <div><h2>${esc(row.name)}</h2><p>${esc(row.email)} · ${esc(row.city)}</p></div>
        <span style="margin-left:auto">${statusBadge(row.status)}</span>
      </div>
      ${row.issueNote ? `<div class="note" style="margin-bottom:16px">${icon("alert")}<span><strong>Latest issue</strong> ${esc(row.issueNote)}</span></div>` : ""}
      <dl class="detail-grid">
        <div><dt>Account type</dt><dd>professional</dd></div>
        <div><dt>Host since</dt><dd>${esc(displayDate(row.joined))}</dd></div>
        <div><dt>Experiences created</dt><dd>${experiences.length || row.experiences}</dd></div>
        <div><dt>Guests hosted</dt><dd>${row.guests}</dd></div>
        <div><dt>Average rating</dt><dd>${row.rating ? `${row.rating} / 5` : "Not rated"}</dd></div>
        <div><dt>Open reports</dt><dd>${open.length}</dd></div>
        <div><dt>Payouts</dt><dd>Handled by venues, outside DineCircle</dd></div>
        <div><dt>Host Studio</dt><dd>${row.status === "suspended" ? "Revoked" : "Enabled"}</dd></div>
      </dl>
      <hr class="divider">
      <h3 style="margin-bottom:8px">Experiences by this host</h3>
      ${
        experiences.length
          ? `<ul class="list" style="margin:0 -22px">${experiences
              .map(
                (exp) => `<li class="list__item list__item--link" data-action="openExperience" data-id="${exp.id}">
                  <div><strong>${esc(exp.title)}</strong><p>${esc(exp.venue)} · ${exp.booked}/${exp.seats} seats</p></div>
                  <div class="list__side">${statusBadge(exp.status)}</div>
                </li>`
              )
              .join("")}</ul>`
          : `<p style="font-size:.82rem;color:var(--muted)">This host has not published an experience yet.</p>`
      }
      <hr class="divider">
      <h3 style="margin-bottom:8px">Reports mentioning this host</h3>
      ${
        reports.length
          ? reports
              .map(
                (rep) => `<div class="issue">
                  <b>${esc(rep.reason)}</b>
                  <span>${esc(rep.id)} · ${esc(relativeTime(rep.created))} · ${esc(rep.status.replace(/_/g, " "))}</span>
                  <p>${esc(rep.detail)}</p>
                </div>`
              )
              .join("")
          : `<p style="font-size:.82rem;color:var(--muted)">No guest reports reference this host.</p>`
      }`,
    foot: `${
      open.length ? `<button class="btn btn--outline" type="button" data-action="goReports">${icon("shield")} Open reports</button>` : ""
    }
      ${
        row.status === "suspended"
          ? `<button class="btn btn--primary" type="button" data-action="reinstate" data-id="${row.id}">${icon("play")} Reinstate host</button>`
          : row.status === "paused"
            ? `<button class="btn btn--primary" type="button" data-action="activateHost" data-id="${row.id}">${icon("play")} Make active</button>`
            : `<button class="btn btn--outline" type="button" data-action="pauseHost" data-id="${row.id}">${icon("pause")} Pause</button>
               <button class="btn btn--danger-ghost" type="button" data-action="suspendHost" data-id="${row.id}">${icon("alert")} Suspend</button>`
      }`,
  });
}

function regionHtml() {
  return `${dataTable({
    rowAction: "open",
    emptyTitle: "No hosts match",
    emptyText: "Change the filters to see other professional hosts.",
    emptyIcon: "host",
    columns: [
      {
        label: "Host",
        render: (row) => `<div class="table__who">${avatar(row.name)}<div><strong>${esc(row.name)}</strong><span>${esc(row.email)}</span></div></div>`,
      },
      { label: "Type", render: (row) => `<span class="role-tag">${esc(row.type)}</span>` },
      { label: "City", render: (row) => esc(row.city) },
      { label: "Experiences", cls: "cell-num", render: (row) => hostExperiences(row).length || row.experiences },
      { label: "Guests", cls: "cell-num", render: (row) => row.guests },
      { label: "Rating", cls: "cell-num", render: (row) => (row.rating ? row.rating.toFixed(1) : "–") },
      {
        label: "Reports",
        cls: "cell-num",
        render: (row) => (row.reports ? `<span class="badge ${row.reports > 1 ? "badge--danger" : "badge--warn"}">${row.reports} open</span>` : `<span class="badge badge--quiet">0</span>`),
      },
      { label: "Status", render: (row) => statusBadge(row.status) },
    ],
    rows: pageRows(),
  })}
  <div class="panel__foot">
    ${pager(visible().length, filters.page, PER_PAGE, "hosts")}
    <span>${metrics.hosts.total} professional hosts platform wide</span>
  </div>`;
}

export default {
  title: "Host Management",
  eyebrow: "Community",
  description: "Professional hosts and creators who run dining experiences. Review their status and act on guest reports.",

  render() {
    const count = (status) => state.hosts.filter((row) => row.status === status).length;
    const badgeCounts = counts();
    const actions = `<a class="btn btn--outline" href="#/experiences">${icon("calendar")} Experiences</a>
      <button class="btn btn--primary" type="button" data-action="invite">${icon("plus")} Promote a host</button>`;
    return {
      actions,
      body: `<div class="grid grid--kpi">
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Professional hosts</span><span class="kpi__icon">${icon("host")}</span></div><p class="kpi__value">${metrics.hosts.total}</p><span class="kpi__delta is-up"><b>${icon("arrowUp")}${metrics.hosts.delta}%</b> vs last month</span></div>
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Active in this slice</span><span class="kpi__icon">${icon("checkCircle")}</span></div><p class="kpi__value">${count("active")}</p><span class="kpi__delta is-flat"><b>Host Studio enabled</b></span></div>
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Reported hosts</span><span class="kpi__icon">${icon("alert")}</span></div><p class="kpi__value">${badgeCounts.flaggedHosts}</p><span class="kpi__delta is-flat"><b>Awaiting a decision</b></span></div>
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Suspended</span><span class="kpi__icon">${icon("lock")}</span></div><p class="kpi__value">${count("suspended")}</p><span class="kpi__delta is-flat"><b>Access revoked</b></span></div>
      </div>
      <section class="panel">
        <div class="toolbar">
          ${searchField("h-q", "Search host, email or city", filters.q)}
          ${selectField(
            "h-status",
            [
              { value: "all", label: "All statuses" },
              { value: "active", label: "Active" },
              { value: "paused", label: "Paused" },
              { value: "suspended", label: "Suspended" },
            ],
            filters.status
          )}
          ${selectField("h-type", [{ value: "all", label: "All host types" }, ...HOST_TYPES.map((type) => ({ value: type, label: type }))], filters.type)}
          ${selectField(
            "h-sort",
            [
              { value: "experiences", label: "Most experiences" },
              { value: "guests", label: "Most guests" },
              { value: "rating", label: "Highest rating" },
              { value: "reports", label: "Most reports" },
              { value: "name", label: "Name A to Z" },
            ],
            filters.sort
          )}
        </div>
        <div id="region">${regionHtml()}</div>
      </section>`,
      mount(page) {
        page.querySelectorAll("[data-filter]").forEach((el) => {
          const key = el.dataset.filter.replace("h-", "");
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
      const row = state.hosts.find((host) => host.id === id);
      if (row) drawer(row);
    },
    pauseHost(id) {
      setStatus([id], "paused", "Paused host account", "warn");
      closeDrawer();
    },
    activateHost(id) {
      setStatus([id], "active", "Activated host account", "success");
      closeDrawer();
    },
    suspendHost(id) {
      askSuspend([id]);
    },
    reinstate(id) {
      setStatus([id], "active", "Reinstated host account", "success", { issueNote: "", reports: 0 });
      closeDrawer();
    },
    openExperience(id) {
      navigate("experiences");
      window.setTimeout(() => {
        document.querySelector(`[data-action="open"][data-id="${id}"]`)?.click();
      }, 40);
    },
    goReports() {
      closeDrawer();
      navigate("reports");
    },
    invite() {
      openModal({
        title: "Promote a diner to professional host",
        body: `<p style="margin-top:6px;color:var(--muted);font-size:.84rem">This sets <strong>account_type</strong> to professional, which is what unlocks Host Studio. Access is not granted by session role alone.</p>
          <div class="field" style="margin-top:14px"><label for="hpName">Full name</label><input class="input" id="hpName" placeholder="e.g. Zarah Nawaz"></div>
          <div class="field"><label for="hpEmail">Email</label><input class="input" id="hpEmail" type="email" placeholder="host@gmail.com"></div>
          <div class="field"><label for="hpType">Host type</label><select class="select" id="hpType">${HOST_TYPES.map((type) => `<option value="${type}">${type}</option>`).join("")}</select></div>
          <div class="field"><label for="hpCity">City</label><input class="input" id="hpCity" value="Karachi"></div>`,
        confirmLabel: "Grant Host Studio",
        onConfirm() {
          const name = document.getElementById("hpName").value.trim();
          const email = document.getElementById("hpEmail").value.trim();
          if (!name || !email) {
            toast("Name and email are required", "danger");
            return false;
          }
          const record = {
            id: `HST-${509 + state.hosts.length}`,
            name,
            email,
            type: document.getElementById("hpType").value,
            city: document.getElementById("hpCity").value.trim() || "Karachi",
            experiences: 0,
            guests: 0,
            rating: 0,
            status: "active",
            reports: 0,
            joined: new Date().toISOString(),
          };
          commit({
            action: "Promoted diner to professional host",
            target: `${name} (${record.id})`,
            kind: "success",
            apply: (draft) => draft.hosts.unshift(record),
          });
          toast(`${name} can now use Host Studio`);
        },
      });
    },
  },
};
