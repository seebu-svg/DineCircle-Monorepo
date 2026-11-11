/* ==========================================================================
   Module: Dashboard (P0)
   Platform totals, subscription revenue, the pending-action queue and the
   newest partner activity. Everything here is derived from the prototype
   store so approvals and suspensions move the numbers immediately.
   ========================================================================== */
import { state, money, displayDate, relativeTime, daysUntil, counts } from "../store.js";
import { icon, esc, lineChart, avatar, statusBadge, openDrawer } from "../ui.js";
import { metrics, revenueSeries, activityFeed } from "../data.js";
import { dataTable, twoColumn } from "./shared.js";
import { navigate, refreshApp } from "../router.js";

let period = 6;

function kpi({ label, value, note, icon: iconName, delta, accent, href }) {
  const inner = `
    <div class="kpi__top">
      <span class="kpi__label">${esc(label)}</span>
      <span class="kpi__icon">${icon(iconName)}</span>
    </div>
    <p class="kpi__value">${value}${note ? ` <small>${esc(note)}</small>` : ""}</p>
    ${delta === undefined ? "" : `<span class="kpi__delta ${delta > 0 ? "is-up" : delta < 0 ? "is-down" : "is-flat"}"><b>${icon(delta > 0 ? "arrowUp" : delta < 0 ? "arrowDown" : "arrowRight")}${Math.abs(delta)}%</b> vs last month</span>`}`;
  return href
    ? `<a class="kpi ${accent ? "kpi--accent" : ""}" href="${href}">${inner}</a>`
    : `<div class="kpi ${accent ? "kpi--accent" : ""}">${inner}</div>`;
}

function queue() {
  const badge = counts();
  const items = [
    { label: "Partner applications to review", value: badge.pendingApplications, route: "applications", icon: "flag", tone: badge.pendingApplications ? "orange" : "quiet" },
    { label: "Payment receipts to verify", value: badge.pendingReceipts, route: "subscriptions", icon: "receipt", tone: badge.pendingReceipts ? "orange" : "quiet" },
    { label: "Open safety reports", value: badge.openReports, route: "reports", icon: "shield", tone: badge.openReports ? "danger" : "quiet" },
    { label: "Experiences awaiting review", value: badge.pendingExperiences, route: "experiences", icon: "calendar", tone: badge.pendingExperiences ? "warn" : "quiet" },
    { label: "Flagged deals and content", value: badge.flaggedDeals, route: "deals", icon: "tag", tone: badge.flaggedDeals ? "danger" : "quiet" },
    { label: "Venues pending verification", value: state.restaurants.filter((r) => r.status === "pending").length, route: "restaurants", icon: "store", tone: "info" },
  ];
  return items
    .map(
      (item) => `<li class="list__item list__item--link" data-action="goto" data-id="${item.route}">
        <span class="avatar avatar--sm ${item.tone === "danger" ? "" : "avatar--orange"}">${icon(item.icon)}</span>
        <div><strong>${esc(item.label)}</strong><p>${item.value ? `${item.value} waiting in the queue` : "Queue is clear"}</p></div>
        <div class="list__side">${icon("chevronRight")}</div>
      </li>`
    )
    .join("");
}

function expiring() {
  const rows = state.subscriptions
    .filter((sub) => ["active", "expiring"].includes(sub.status))
    .map((sub) => ({ ...sub, left: daysUntil(sub.expires) }))
    .filter((sub) => sub.left !== null && sub.left <= 30)
    .sort((a, b) => a.left - b.left)
    .slice(0, 5);
  if (!rows.length) return `<p class="note" style="margin:0">${icon("checkCircle")} No subscription expires in the next 30 days.</p>`;
  return `<ul class="list">${rows
    .map(
      (sub) => `<li class="list__item" data-action="goto" data-id="subscriptions">
        <div><strong>${esc(sub.partner)}</strong><p>${esc(sub.method)} · ${esc(money(sub.amount))}</p></div>
        <div class="list__side">
          <strong>${sub.left <= 0 ? "Expired" : `${sub.left} days`}</strong>
          <p>${esc(displayDate(sub.expires))}</p>
        </div>
      </li>`
    )
    .join("")}</ul>`;
}

export default {
  title: "Dashboard",
  eyebrow: "Overview",
  description: "Karachi pilot at a glance: partners, revenue, safety load and what needs a decision today.",

  render() {
    const series = revenueSeries.slice(period === 3 ? -3 : 0);
    const activeSubs = state.subscriptions.filter((sub) => ["active", "expiring"].includes(sub.status)).length;
    const liveExperiences = state.experiences.filter((exp) => exp.status === "live").length;
    const revenueThisMonth = state.subscriptions
      .filter((sub) => ["active", "expiring"].includes(sub.status))
      .reduce((sum, sub) => sum + (sub.plan === "pro-annual" ? Math.round(sub.amount / 12) : sub.amount), 0);

    const actions = `<a class="btn btn--outline" href="#/analytics">${icon("chart")} Full analytics</a>
      <a class="btn btn--primary" href="#/applications">${icon("flag")} Review queue</a>`;

    const body = `
      <div class="grid grid--kpi">
        ${kpi({ label: "Total restaurants", value: metrics.restaurants.total.toLocaleString(), note: `lists`, icon: "store", delta: metrics.restaurants.delta, href: "#/restaurants" })}
        ${kpi({ label: "Active partners", value: metrics.partners.total, note: "accounts", icon: "users", delta: metrics.partners.delta, href: "#/accounts" })}
        ${kpi({ label: "Customers", value: metrics.customers.total.toLocaleString(), note: "diners", icon: "user", delta: metrics.customers.delta, href: "#/customers" })}
        ${kpi({ label: "Professional hosts", value: metrics.hosts.total, note: "creators", icon: "host", delta: metrics.hosts.delta, href: "#/hosts" })}
        ${kpi({ label: "Live subscriptions", value: activeSubs, note: `of ${metrics.partners.total}`, icon: "card", delta: metrics.subscriptions.delta, href: "#/subscriptions" })}
        ${kpi({ label: "Subscription revenue", value: money(revenueThisMonth), note: "this month", icon: "wallet", delta: 7.2, accent: true, href: "#/subscriptions" })}
        ${kpi({ label: "Dining experiences", value: metrics.experiences.total, note: `live ${liveExperiences}`, icon: "calendar", delta: metrics.experiences.delta, href: "#/experiences" })}
      </div>

      ${twoColumn(
        `<section class="panel">
          <div class="panel__head">
            <div style="flex:1">
              <h2>Subscription revenue</h2>
              <p>Partner Pro fees only. Booking commission is 0% by design.</p>
            </div>
            <div class="segmented" role="group" aria-label="Chart period">
              <button type="button" data-action="period" data-id="3" aria-pressed="${period === 3}">3 months</button>
              <button type="button" data-action="period" data-id="6" aria-pressed="${period === 6}">6 months</button>
            </div>
          </div>
          <div class="chart__headline">
            <b>${esc(money(revenueSeries[revenueSeries.length - 1].value))}</b>
            <span>collected this month · ${esc(money(metrics.revenue.ytd))} year to date</span>
          </div>
          <div style="padding:0 12px 16px">${lineChart(series, { label: "Subscription revenue" })}</div>
        </section>`,
        `<section class="panel">
          <div class="panel__head"><div style="flex:1"><h2>Needs a decision</h2><p>Sorted by operational load</p></div></div>
          <ul class="list" style="margin:0 -18px">${queue()}</ul>
        </section>`
      )}

      <div class="grid grid--2">
        <section class="panel">
          <div class="panel__head">
            <div style="flex:1"><h2>Latest partner applications</h2><p>Newest restaurant and cafe submissions</p></div>
            <a class="btn btn--ghost btn--sm" href="#/applications">Open queue ${icon("chevronRight")}</a>
          </div>
          ${dataTable({
            rowAction: "openApplication",
            emptyTitle: "Queue is clear",
            emptyText: "No applications are waiting for a decision.",
            columns: [
              {
                label: "Restaurant",
                render: (row) => `<div class="table__who">${avatar(row.restaurant)}<div><strong>${esc(row.restaurant)}</strong><span>${esc(row.area)}</span></div></div>`,
              },
              { label: "Submitted", render: (row) => esc(relativeTime(row.submitted)) },
              { label: "Status", render: (row) => statusBadge(row.status) },
            ],
            rows: state.applications.slice(0, 4),
          })}
        </section>

        <section class="panel">
          <div class="panel__head"><div style="flex:1"><h2>Renewals due in 30 days</h2><p>Chase partners before their venue goes inactive</p></div></div>
          <div class="panel__body--tight" style="padding:0 18px 8px">${expiring()}</div>
        </section>
      </div>

      <div class="grid grid--2">
        <section class="panel">
          <div class="panel__head"><div style="flex:1"><h2>Partner activity</h2><p>Publishing and reservation events from the last 48 hours</p></div></div>
          <ul class="list" style="margin:0 -18px">
            ${activityFeed
              .map(
                (item) => `<li class="list__item">
                  ${avatar(item.who)}
                  <div><strong>${esc(item.who)}</strong><p>${esc(item.what)}</p></div>
                  <div class="list__side"><span class="badge badge--plain">${esc(relativeTime(item.at))}</span></div>
                </li>`
              )
              .join("")}
          </ul>
        </section>

        <section class="panel">
          <div class="panel__head">
            <div style="flex:1"><h2>Audit log</h2><p>Every admin action is recorded</p></div>
            <button class="btn btn--ghost btn--sm" type="button" data-action="openAudit">View all ${icon("chevronRight")}</button>
          </div>
          <ul class="list" style="margin:0 -18px">
            ${state.auditLog
              .slice(0, 5)
              .map(
                (entry) => `<li class="list__item">
                  <span class="avatar avatar--sm ${entry.kind === "danger" ? "avatar--ink" : "avatar--orange"}">${icon(entry.kind === "danger" ? "alert" : entry.kind === "success" ? "check" : "edit")}</span>
                  <div><strong>${esc(entry.action)}</strong><p>${esc(entry.target)} · ${esc(entry.actor)}</p></div>
                  <div class="list__side"><span class="badge badge--plain">${esc(relativeTime(entry.at))}</span></div>
                </li>`
              )
              .join("")}
          </ul>
        </section>
      </div>`;

    return { body, actions };
  },

  actions: {
    period(value) {
      period = Number(value);
      refreshApp();
    },
    goto(route) {
      navigate(route);
    },
    openApplication(id) {
      const row = state.applications.find((item) => item.id === id);
      if (!row) return;
      navigate("applications");
      window.setTimeout(() => {
        document.querySelector(`[data-action="open"][data-id="${id}"]`)?.click();
      }, 40);
    },
    openAudit() {
      openDrawer({
        title: "Audit log",
        subtitle: "Admin actions across the platform",
        body: `<div class="timeline">
          ${state.auditLog
            .map(
              (entry) => `<div class="timeline__item timeline__item--${entry.kind}">
                <strong>${esc(entry.action)}</strong>
                <p>${esc(entry.target)} · by ${esc(entry.actor)}</p>
                <time>${esc(displayDate(entry.at, true))}</time>
              </div>`
            )
            .join("")}
        </div>`,
        foot: `<button class="btn btn--outline" type="button" data-close-overlay>Close</button>`,
      });
    },
  },
};
