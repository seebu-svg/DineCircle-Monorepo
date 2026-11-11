/* ==========================================================================
   Module: Basic Analytics (P1)
   Only metrics the platform actually records: partner growth, subscription
   revenue, reservations and experience participation. No forecasting.
   ========================================================================== */
import { state, money, displayDate, counts } from "../store.js";
import { icon, esc, avatar, lineChart, barChart, donut, toast } from "../ui.js";
import { navigate, refreshApp } from "../router.js";
import {
  metrics,
  revenueSeries,
  partnerGrowthSeries,
  reservationsSeries,
  experienceSeries,
  planSplit,
  citySplit,
} from "../data.js";

let range = 6;

const RANGES = [3, 6];

function slice(series) {
  return series.slice(range === 3 ? -3 : 0);
}

function statCard({ label, value, note, iconName, delta }) {
  return `<div class="kpi">
    <div class="kpi__top"><span class="kpi__label">${esc(label)}</span><span class="kpi__icon">${icon(iconName)}</span></div>
    <p class="kpi__value">${esc(value)}</p>
    <span class="kpi__delta ${delta > 0 ? "is-up" : delta < 0 ? "is-down" : "is-flat"}"><b>${icon(delta > 0 ? "arrowUp" : delta < 0 ? "arrowDown" : "arrowRight")}${Math.abs(delta)}%</b> ${esc(note)}</span>
  </div>`;
}

function funnel() {
  const applied = state.applications.length;
  const approved = state.applications.filter((row) => row.status === "approved").length;
  const venues = state.restaurants.filter((row) => row.status !== "draft").length;
  const paying = state.subscriptions.filter((row) => ["active", "expiring"].includes(row.status)).length;
  const steps = [
    { label: "Applications received", value: applied, note: "Partner signup and sales signed" },
    { label: "Applications approved", value: approved, note: "Documents verified" },
    { label: "Venues created", value: venues, note: "Profile with menu or deals" },
    { label: "Paying partners", value: paying, note: "Subscription verified by an admin" },
  ];
  const max = Math.max(...steps.map((step) => step.value), 1);
  return steps
    .map(
      (step) => `<div style="padding:12px 0;border-bottom:1px solid var(--line)">
        <div class="row" style="justify-content:space-between"><strong style="font-size:.84rem">${esc(step.label)}</strong><b>${step.value}</b></div>
        <div class="progress" style="margin-top:8px"><span style="width:${Math.round((step.value / max) * 100)}%"></span></div>
        <p style="margin-top:6px;font-size:.72rem;color:var(--muted)">${esc(step.note)}</p>
      </div>`
    )
    .join("");
}

function topVenues() {
  const rows = [...state.restaurants]
    .sort((a, b) => b.bookings - a.bookings || b.views - a.views)
    .slice(0, 6);
  const max = Math.max(...rows.map((row) => row.bookings), 1);
  return `<ul class="list" style="margin:0 -18px">
    ${rows
      .map(
        (row) => `<li class="list__item list__item--link" data-action="openVenue" data-id="${row.id}">
          ${avatar(row.name)}
          <div style="flex:1">
            <strong>${esc(row.name)}</strong>
            <p>${esc(row.area)} · ${row.views.toLocaleString()} profile views</p>
            <div class="progress" style="margin-top:7px"><span style="width:${Math.round((row.bookings / max) * 100)}%"></span></div>
          </div>
          <div class="list__side"><strong>${row.bookings}</strong><p>reservations</p></div>
        </li>`
      )
      .join("")}
  </ul>`;
}

export default {
  title: "Basic Analytics",
  eyebrow: "Overview",
  description: "Growth, revenue, reservations and experience participation. Every number here comes from data the platform already records.",

  render() {
    const badge = counts();
    const actions = `<div class="segmented" role="group" aria-label="Reporting range" style="margin-right:6px">
        ${RANGES.map((value) => `<button type="button" data-action="range" data-id="${value}" aria-pressed="${range === value}">${value} months</button>`).join("")}
      </div>
      <button class="btn btn--outline" type="button" data-action="export">${icon("download")} Export CSV</button>`;
    return {
      actions,
      body: `<div class="grid grid--kpi">
        ${statCard({ label: "Partners onboarded", value: metrics.partners.total, note: "vs last month", iconName: "users", delta: metrics.partners.delta })}
        ${statCard({ label: "Subscription revenue", value: money(revenueSeries[revenueSeries.length - 1].value), note: "this month", iconName: "wallet", delta: 7.2 })}
        ${statCard({ label: "Reservations", value: metrics.reservations.month.toLocaleString(), note: "vs last month", iconName: "calendar", delta: metrics.reservations.delta })}
        ${statCard({ label: "Experience seats", value: metrics.experiences.seats, note: "joined this month", iconName: "host", delta: metrics.experiences.delta })}
      </div>

      <div class="grid grid--2">
        <section class="panel">
          <div class="panel__head"><div style="flex:1"><h2>Partner growth</h2><p>Restaurants and cafes with a live subscription</p></div></div>
          <div class="chart__headline"><b>${partnerGrowthSeries[partnerGrowthSeries.length - 1].value}</b><span>paying partners · ${metrics.partners.total} platform wide</span></div>
          <div style="padding:0 12px 16px">${lineChart(slice(partnerGrowthSeries), { label: "Partner growth" })}</div>
        </section>
        <section class="panel">
          <div class="panel__head"><div style="flex:1"><h2>Subscription revenue</h2><p>Partner Pro fees collected per month</p></div></div>
          <div class="chart__headline"><b>${esc(money(metrics.revenue.ytd))}</b><span>year to date</span></div>
          <div style="padding:0 12px 16px">${barChart(slice(revenueSeries), { label: "Subscription revenue" })}</div>
        </section>
      </div>

      <div class="grid grid--2">
        <section class="panel">
          <div class="panel__head"><div style="flex:1"><h2>Reservations</h2><p>Tables booked through the customer app. Commission stays 0%.</p></div></div>
          <div class="chart__headline"><b>${metrics.reservations.month.toLocaleString()}</b><span>reservations this month</span></div>
          <div style="padding:0 12px 16px">${lineChart(slice(reservationsSeries), { color: "#c2410c", label: "Reservations" })}</div>
        </section>
        <section class="panel">
          <div class="panel__head"><div style="flex:1"><h2>Experiences</h2><p>Hosted dinners published by partners</p></div></div>
          <div class="chart__headline"><b>${metrics.experiences.total}</b><span>experiences live or completed · ${badge.pendingExperiences} awaiting review</span></div>
          <div style="padding:0 12px 16px">${barChart(slice(experienceSeries), { color: "#6d28d9", label: "Experiences" })}</div>
        </section>
      </div>

      <div class="grid grid--2">
        <section class="panel">
          <div class="panel__head"><div style="flex:1"><h2>Plan mix</h2><p>How paying partners are subscribed</p></div></div>
          <div class="panel__body">${donut(planSplit)}</div>
        </section>
        <section class="panel">
          <div class="panel__head"><div style="flex:1"><h2>Conversion funnel</h2><p>From application to a verified subscription</p></div></div>
          <div class="panel__body" style="padding-top:4px">${funnel()}</div>
        </section>
      </div>

      <div class="grid grid--2">
        <section class="panel">
          <div class="panel__head"><div style="flex:1"><h2>Top venues by reservations</h2><p>Limited to what the platform tracks today</p></div></div>
          <div style="padding:8px 18px 14px">${topVenues()}</div>
        </section>
        <section class="panel">
          <div class="panel__head"><div style="flex:1"><h2>Coverage by city</h2><p>Karachi first, then Lahore and Islamabad after validation</p></div></div>
          <div class="panel__body">
            ${citySplit
              .map((city) => {
                const max = Math.max(...citySplit.map((item) => item.value));
                const share = Math.round((city.value / max) * 100);
                return `<div style="padding:9px 0;border-bottom:1px solid var(--line)">
                  <div class="row" style="justify-content:space-between"><strong style="font-size:.83rem">${esc(city.label)}</strong><b>${city.value}</b></div>
                  <div class="progress" style="margin-top:7px"><span style="width:${share}%"></span></div>
                </div>`;
              })
              .join("")}
            <div class="note" style="margin-top:14px">${icon("pin")}<span><strong>Lahore and Islamabad</strong> accounts exist but the websites and apps still describe them as "soon". Launch gating stays in Platform Settings.</span></div>
          </div>
        </section>
      </div>

      <section class="panel">
        <div class="panel__head"><div style="flex:1"><h2>Reported period</h2><p>Snapshot taken ${esc(displayDate(new Date().toISOString(), true))} (Asia/Karachi)</p></div>
          <span class="chip chip--orange">${icon("sparkles")} Prototype metrics</span></div>
        <div class="panel__body">
          <div class="detail-grid">
            <div><dt>Venues live</dt><dd>${metrics.restaurants.active} of ${metrics.restaurants.total}</dd></div>
            <div><dt>Suspension cases</dt><dd>${state.restaurants.filter((row) => row.status === "suspended").length}</dd></div>
            <div><dt>Open safety reports</dt><dd>${badge.openReports}</dd></div>
            <div><dt>Receipts to verify</dt><dd>${badge.pendingReceipts}</dd></div>
          </div>
          <p style="margin-top:14px;font-size:.78rem;color:var(--muted)">Analytics deliberately excludes anything the platform does not measure yet, such as repeat guest retention, average order value or delivery activity. Those need server-side tracking before they can appear here.</p>
        </div>
      </section>`,
    };
  },

  actions: {
    range(value) {
      range = Number(value);
      refreshApp();
    },
    openVenue(id) {
      navigate("restaurants");
      window.setTimeout(() => {
        document.querySelector(`[data-action="open"][data-id="${id}"]`)?.click();
      }, 60);
    },
    export() {
      const header = ["Month", "Paying partners", "Revenue PKR", "Reservations", "Experiences"];
      const lines = [
        header,
        ...revenueSeries.map((point, index) => [
          point.label,
          partnerGrowthSeries[index].value,
          point.value,
          reservationsSeries[index].value,
          experienceSeries[index].value,
        ]),
      ]
        .map((cells) => cells.join(","))
        .join("\n");
      const blob = new Blob([lines], { type: "text/csv" });
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = "dinecircle-analytics.csv";
      link.click();
      URL.revokeObjectURL(url);
      toast("Analytics exported");
    },
  },
};
