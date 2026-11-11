/* ==========================================================================
   Module: Experience Management (P0)
   Partner-created, host-led dinners. Guests join for free and pay the venue
   directly, so the admin job here is monitoring and moderation: approve new
   listings, and cancel or remove anything that breaks the guidelines.
   ========================================================================== */
import { state, commit, money, displayDate, relativeTime } from "../store.js";
import { icon, esc, avatar, statusBadge, openDrawer, closeDrawer, openModal, toast, pager, matches } from "../ui.js";
import { dataTable, searchField, selectField } from "./shared.js";
import { metrics } from "../data.js";
import { navigate } from "../router.js";

const PER_PAGE = 8;
const filters = { q: "", status: "all", venue: "all", page: 1 };

function visible() {
  return state.experiences
    .filter((row) => {
      if (filters.status !== "all" && row.status !== filters.status) return false;
      if (filters.venue !== "all" && row.venue !== filters.venue) return false;
      if (filters.q && !matches(`${row.title} ${row.venue} ${row.host} ${row.id}`, filters.q)) return false;
      return true;
    })
    .sort((a, b) => new Date(a.date) - new Date(b.date));
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

function seatsPct(row) {
  return Math.min(Math.round((row.booked / row.seats) * 100), 100);
}

function pastDate(row) {
  return new Date(row.date).getTime() < Date.now();
}

function setStatus(ids, status, action, kind, extra = {}) {
  const rows = state.experiences.filter((row) => ids.includes(row.id));
  if (!rows.length) return;
  commit({
    action,
    target: rows.map((row) => `${row.title} (${row.id})`).join(", "),
    kind,
    apply: () =>
      rows.forEach((row) => {
        row.status = status;
        Object.assign(row, extra);
      }),
  });
  toast(`${rows.length} experience${rows.length === 1 ? "" : "s"} updated`);
}

function askCancel(ids) {
  const rows = state.experiences.filter((row) => ids.includes(row.id));
  if (!rows.length) return;
  const guests = rows.reduce((sum, row) => sum + row.booked, 0);
  openModal({
    title: rows.length === 1 ? `Cancel ${rows[0].title}?` : `Cancel ${rows.length} experiences?`,
    body: `<p style="margin-top:6px;color:var(--muted);font-size:.84rem">${guests} booked guest${guests === 1 ? "" : "s"} receive an in-app notification and an email. Guests paid the venue directly, so any refund is settled by the restaurant, not by DineCircle.</p>
      <div class="field" style="margin-top:14px"><label for="cancelReason">Reason</label>
        <select class="select" id="cancelReason">
          <option>Venue closed on the date</option>
          <option>Advertised content cannot be delivered</option>
          <option>Host suspended</option>
          <option>Not enough guests booked</option>
          <option>Safety concern at the venue</option>
        </select>
      </div>
      <div class="field"><label for="cancelMsg">Message to guests</label><textarea class="textarea" id="cancelMsg" placeholder="We are sorry, the venue can no longer host this experience.">The venue can no longer host this experience. You have not been charged by DineCircle, and you can book another experience any time.</textarea></div>`,
    confirmLabel: "Cancel and notify guests",
    tone: "danger",
    onConfirm() {
      const reason = document.getElementById("cancelReason").value;
      setStatus(ids, "cancelled", `Cancelled experience: ${reason}`, "danger", { cancelledAt: new Date().toISOString() });
      closeDrawer();
    },
  });
}

function drawer(row) {
  const venue = state.restaurants.find((item) => item.name === row.venue);
  const host = state.hosts.find((item) => item.name === row.host);
  const reports = state.reports.filter((rep) => rep.subjectId === row.id || rep.subject === row.title);
  const waitlist = Math.max(row.booked - row.seats, 0);
  openDrawer({
    title: row.title,
    subtitle: `${row.id} · ${row.venue}`,
    tone: row.status === "cancelled" || row.status === "flagged" ? "danger" : "orange",
    body: `
      <div class="person-head" style="margin-bottom:18px">
        ${avatar(row.title, "lg")}
        <div><h2>${esc(row.title)}</h2><p>${esc(displayDate(row.date, true))} · ${esc(relativeTime(row.date))}</p></div>
        <span style="margin-left:auto">${statusBadge(row.status)}</span>
      </div>
      <p style="font-size:.84rem;color:var(--ink-soft)">${esc(row.note)}</p>
      <hr class="divider">
      <dl class="detail-grid">
        <div><dt>Venue</dt><dd>${esc(row.venue)}</dd></div>
        <div><dt>Host</dt><dd>${esc(row.host)}</dd></div>
        <div><dt>Seats</dt><dd>${row.booked} of ${row.seats}</dd></div>
        <div><dt>Guest price</dt><dd>${esc(money(row.price))} paid at the venue</dd></div>
        <div><dt>Commission</dt><dd>0% to DineCircle</dd></div>
        <div><dt>Waiting list</dt><dd>${waitlist}</dd></div>
        <div><dt>Venue status</dt><dd>${venue ? esc(venue.status) : "Unknown"}</dd></div>
        <div><dt>Host status</dt><dd>${host ? esc(host.status) : "Unknown"}</dd></div>
      </dl>
      <hr class="divider">
      <h3 style="margin-bottom:8px">Seat fill</h3>
      <div class="progress ${seatsPct(row) >= 100 ? "progress--success" : ""}"><span style="width:${seatsPct(row)}%"></span></div>
      <div class="row" style="justify-content:space-between;margin-top:6px;font-size:.75rem;color:var(--muted)">
        <span>${row.booked} guests joined</span><span>${seatsPct(row)}% full</span>
      </div>
      <hr class="divider">
      <h3 style="margin-bottom:8px">Simulated RSVP sample</h3>
      <ul class="list" style="margin:0 -22px">
        ${state.customers
          .slice(0, 3)
          .map(
            (customer) => `<li class="list__item">
              ${avatar(customer.name)}
              <div><strong>${esc(customer.name)}</strong><p>${esc(customer.email)}</p></div>
              <div class="list__side"><span class="badge badge--success">Joined</span></div>
            </li>`
          )
          .join("")}
      </ul>
      <hr class="divider">
      <h3 style="margin-bottom:8px">Reports on this experience</h3>
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
          : `<p style="font-size:.82rem;color:var(--muted)">No reports reference this listing.</p>`
      }`,
    foot: `${venue ? `<button class="btn btn--outline" type="button" data-action="openVenue" data-id="${venue.name}">${icon("store")} Venue</button>` : ""}
      ${host ? `<button class="btn btn--outline" type="button" data-action="openHost" data-id="${host.id}">${icon("host")} Host</button>` : ""}
      ${
        row.status === "pending_review"
          ? `<button class="btn btn--primary" type="button" data-action="approve" data-id="${row.id}">${icon("check")} Approve and publish</button>`
          : row.status === "cancelled"
            ? `<button class="btn btn--outline" type="button" data-action="republish" data-id="${row.id}">${icon("refresh")} Republish after review</button>`
            : `<button class="btn btn--outline" type="button" data-action="flag" data-id="${row.id}">${icon("flag")} Flag</button>
               <button class="btn btn--danger-ghost" type="button" data-action="cancel" data-id="${row.id}">${icon("x")} Cancel</button>`
      }`,
  });
}

function regionHtml() {
  return `${dataTable({
    rowAction: "open",
    emptyTitle: "No experiences match",
    emptyText: "Try another venue or status filter.",
    emptyIcon: "calendar",
    columns: [
      {
        label: "Experience",
        render: (row) => `<div class="table__who">${avatar(row.title)}<div><strong>${esc(row.title)}</strong><span>${esc(row.venue)} · ${esc(row.host)}</span></div></div>`,
      },
      {
        label: "Date",
        render: (row) => `${esc(displayDate(row.date, true))}<span class="cell-sub">${esc(relativeTime(row.date))}${pastDate(row) ? " · finished" : ""}</span>`,
      },
      {
        label: "Seats",
        render: (row) => `<div><span>${row.booked}/${row.seats}</span><div class="progress" style="width:110px;margin-top:4px"><span style="width:${seatsPct(row)}%"></span></div></div>`,
      },
      { label: "Guest price", cls: "cell-num", render: (row) => esc(money(row.price)) },
      {
        label: "Reports",
        cls: "cell-num",
        render: (row) => (row.reports ? `<span class="badge badge--danger">${row.reports}</span>` : `<span class="badge badge--quiet">0</span>`),
      },
      { label: "Status", render: (row) => statusBadge(row.status) },
    ],
    rows: pageRows(),
  })}
  <div class="panel__foot">
    ${pager(visible().length, filters.page, PER_PAGE, "experiences")}
    <span>${metrics.experiences.total} experiences platform wide · ${metrics.experiences.seats} seats sold this month</span>
  </div>`;
}

export default {
  title: "Experience Management",
  eyebrow: "Community",
  description: "Monitor hosted dinners, approve new listings and cancel or remove anything that violates the community guidelines.",

  render() {
    const count = (status) => state.experiences.filter((row) => row.status === status).length;
    const booked = state.experiences.reduce((sum, row) => sum + row.booked, 0);
    const actions = `<a class="btn btn--outline" href="#/hosts">${icon("host")} Hosts</a>
      <button class="btn btn--primary" type="button" data-action="create">${icon("plus")} Schedule from a venue</button>`;
    return {
      actions,
      body: `<div class="grid grid--kpi">
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Live experiences</span><span class="kpi__icon">${icon("calendar")}</span></div><p class="kpi__value">${count("live")}</p><span class="kpi__delta is-up"><b>${icon("arrowUp")}${metrics.experiences.delta}%</b> vs last month</span></div>
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Awaiting review</span><span class="kpi__icon">${icon("clock")}</span></div><p class="kpi__value">${count("pending_review")}</p><span class="kpi__delta is-flat"><b>Check venue and menu</b></span></div>
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Flagged or cancelled</span><span class="kpi__icon">${icon("alert")}</span></div><p class="kpi__value">${count("flagged") + count("cancelled")}</p><span class="kpi__delta is-flat"><b>Guests already notified</b></span></div>
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Guest seats in this slice</span><span class="kpi__icon">${icon("users")}</span></div><p class="kpi__value">${booked}</p><span class="kpi__delta is-flat"><b>Paid at the venue, 0% fee</b></span></div>
      </div>
      <section class="panel">
        <div class="toolbar">
          ${searchField("e-q", "Search experience, venue or host", filters.q)}
          ${selectField(
            "e-status",
            [
              { value: "all", label: "All statuses" },
              { value: "live", label: "Live" },
              { value: "pending_review", label: "Pending review" },
              { value: "flagged", label: "Flagged" },
              { value: "cancelled", label: "Cancelled" },
            ],
            filters.status
          )}
          ${selectField(
            "e-venue",
            [{ value: "all", label: "All venues" }, ...[...new Set(state.experiences.map((row) => row.venue))].map((venue) => ({ value: venue, label: venue }))],
            filters.venue
          )}
        </div>
        <div id="region">${regionHtml()}</div>
      </section>`,
      mount(page) {
        page.querySelectorAll("[data-filter]").forEach((el) => {
          const key = el.dataset.filter.replace("e-", "");
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
      const row = state.experiences.find((exp) => exp.id === id);
      if (row) drawer(row);
    },
    approve(id) {
      setStatus([id], "live", "Approved and published experience", "success");
      closeDrawer();
    },
    flag(id) {
      const row = state.experiences.find((exp) => exp.id === id);
      if (!row) return;
      commit({
        action: "Flagged experience for content review",
        target: `${row.title} (${row.id})`,
        kind: "warn",
        apply: () => {
          row.status = "flagged";
          row.reports = (row.reports || 0) + 1;
        },
      });
      drawer(row);
    },
    cancel(id) {
      askCancel([id]);
    },
    republish(id) {
      setStatus([id], "pending_review", "Sent experience back to review", "info");
      closeDrawer();
    },
    remove(id) {
      const row = state.experiences.find((exp) => exp.id === id);
      if (!row) return;
      openModal({
        title: `Remove ${row.title}?`,
        body: `<p style="margin-top:6px;color:var(--muted);font-size:.84rem">Removal is used for guideline violations. Booked guests are cancelled first so they receive a notification instead of an empty listing.</p>`,
        confirmLabel: "Remove listing",
        tone: "danger",
        onConfirm() {
          commit({
            action: "Removed violating experience",
            target: `${row.title} (${row.id})`,
            kind: "danger",
            apply: (draft) => { draft.experiences = draft.experiences.filter((exp) => exp.id !== id); },
          });
          closeDrawer();
          toast("Listing removed");
        },
      });
    },
    openVenue(name) {
      closeDrawer();
      navigate("restaurants");
      window.setTimeout(() => {
        document.querySelector(`[data-action="open"][data-id="${state.restaurants.find((row) => row.name === name)?.id}"]`)?.click();
      }, 60);
    },
    openHost(id) {
      closeDrawer();
      navigate("hosts");
      window.setTimeout(() => {
        document.querySelector(`[data-action="open"][data-id="${id}"]`)?.click();
      }, 60);
    },
    create() {
      const venues = state.restaurants
        .filter((row) => row.status === "active")
        .map((row) => `<option value="${esc(row.name)}">${esc(row.name)}</option>`)
        .join("");
      const hosts = state.hosts
        .filter((row) => row.status === "active")
        .map((row) => `<option value="${esc(row.name)}">${esc(row.name)}</option>`)
        .join("");
      openModal({
        title: "Schedule an experience for a venue",
        body: `<p style="margin-top:6px;color:var(--muted);font-size:.84rem">Normally partners create experiences in the partner app and they land here for review. Use this when a venue or host books through sales instead.</p>
          <div class="field" style="margin-top:14px"><label for="nTitle">Experience title</label><input class="input" id="nTitle" placeholder="e.g. seaside tasting dinner"></div>
          <div class="field"><label for="nVenue">Venue</label><select class="select" id="nVenue">${venues}</select></div>
          <div class="field"><label for="nHost">Host</label><select class="select" id="nHost">${hosts}</select></div>
          <div class="field"><label for="nSeats">Seats</label><input class="input" id="nSeats" type="number" value="20"></div>
          <div class="field"><label for="nPrice">Guest price in PKR</label><input class="input" id="nPrice" type="number" value="4500"></div>`,
        confirmLabel: "Create for review",
        onConfirm() {
          const title = document.getElementById("nTitle").value.trim();
          if (!title) {
            toast("Title is required", "danger");
            return false;
          }
          const record = {
            id: `EXP-${309 + state.experiences.length}`,
            title,
            venue: document.getElementById("nVenue").value,
            host: document.getElementById("nHost").value,
            date: new Date(Date.now() + 14 * 86400000).toISOString(),
            seats: Number(document.getElementById("nSeats").value) || 20,
            booked: 0,
            price: Number(document.getElementById("nPrice").value) || 4500,
            status: "pending_review",
            reports: 0,
            note: "Scheduled by an admin from a sales enquiry. Awaiting content review.",
          };
          commit({
            action: "Scheduled experience for review",
            target: `${title} (${record.id})`,
            kind: "info",
            apply: (draft) => draft.experiences.unshift(record),
          });
          filters.status = "pending_review";
          filters.page = 1;
          toast("Experience created and queued for review");
        },
      });
    },
  },
};
