/* ==========================================================================
   Module: Subscriptions & Payments (P0)
   Partner Pro is billed manually: the partner pays by bank transfer, JazzCash
   or Easypaisa, uploads a receipt, and an admin verifies then activates. There
   is no payment gateway in the apps, so this queue is the revenue path.
   ========================================================================== */
import { state, commit, session, money, displayDate, relativeTime, daysUntil, planName, planPrice, planCycle, nextExpiry } from "../store.js";
import { refreshApp } from "../router.js";
import { icon, esc, avatar, statusBadge, openDrawer, closeDrawer, openModal, toast, pager, matches } from "../ui.js";
import { dataTable, searchField, selectField } from "./shared.js";
import { metrics } from "../data.js";

const PER_PAGE = 8;
const TABS = [
  { value: "awaiting_verification", label: "Awaiting verification" },
  { value: "active", label: "Active" },
  { value: "expiring", label: "Expiring soon" },
  { value: "expired", label: "Expired" },
  { value: "rejected", label: "Rejected" },
  { value: "all", label: "All records" },
];
const filters = { q: "", tab: "awaiting_verification", plan: "all", page: 1 };

const METHODS = ["Bank transfer", "JazzCash", "Easypaisa"];

function visible() {
  return state.subscriptions.filter((row) => {
    if (filters.tab !== "all" && row.status !== filters.tab) return false;
    if (filters.plan !== "all" && row.plan !== filters.plan) return false;
    if (filters.q && !matches(`${row.partner} ${row.account} ${row.reference} ${row.id} ${row.method}`, filters.q)) return false;
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

function expiryCell(row) {
  const left = daysUntil(row.expires);
  if (left === null) return `<span class="badge badge--warn">Not started</span>`;
  if (left <= 0) return `<span class="badge badge--danger">Expired ${esc(relativeTime(row.expires))}</span>`;
  const tone = left <= 7 ? "danger" : left <= 30 ? "warn" : "success";
  const width = Math.max(Math.min((left / 365) * 100, 100), 6);
  return `<div>
      <strong style="font-size:.8rem;color:var(--${tone === "success" ? "ink" : tone})">${left} days left</strong>
      <div class="progress ${tone === "danger" ? "progress--danger" : ""}" style="margin-top:4px;width:110px"><span style="width:${width}%"></span></div>
      <span class="cell-sub">${esc(displayDate(row.expires))}</span>
    </div>`;
}

function activate(id, { renew = false } = {}) {
  const row = state.subscriptions.find((sub) => sub.id === id);
  if (!row) return;
  commit({
    action: renew ? "Renewed Partner Pro subscription" : "Verified receipt and activated Partner Pro",
    target: `${row.partner} (${row.id})`,
    kind: "success",
    apply: () => {
      row.status = "active";
      row.started = row.started || new Date().toISOString();
      row.expires = nextExpiry(row.plan, renew ? new Date(row.expires || Date.now()) : new Date());
      row.verifiedBy = session.get()?.name || "admin";
      row.verifiedAt = new Date().toISOString();
    },
  });
  closeDrawer();
  toast(`${row.partner} is live on ${planName(row.plan)} until ${displayDate(row.expires)}`);
}

function askReject(id) {
  const row = state.subscriptions.find((sub) => sub.id === id);
  if (!row) return;
  openModal({
    title: `Reject receipt ${row.reference}`,
    body: `<p style="margin-top:6px;color:var(--muted);font-size:.84rem">The partner is asked to upload a clearer receipt. The venue stays inactive while the status is rejected.</p>
      <div class="field" style="margin-top:14px"><label for="rejectWhy">Reason</label>
        <select class="select" id="rejectWhy">
          <option>Receipt image unreadable</option>
          <option>Amount does not match the plan</option>
          <option>Transaction reference not found in the bank statement</option>
          <option>Receipt date outside the billing period</option>
          <option>Duplicate submission</option>
        </select>
      </div>
      <div class="field"><label for="rejectMsg">Message to the partner</label><textarea class="textarea" id="rejectMsg" placeholder="What should they send instead?"></textarea></div>`,
    confirmLabel: "Reject receipt",
    tone: "danger",
    onConfirm() {
      const reason = document.getElementById("rejectWhy").value;
      commit({
        action: `Rejected payment receipt: ${reason}`,
        target: `${row.partner} (${row.id})`,
        kind: "danger",
        apply: () => {
          row.status = "rejected";
          row.rejectReason = reason;
        },
      });
      closeDrawer();
      toast("Receipt rejected and partner notified", "danger");
    },
  });
}

function drawer(row) {
  const venue = state.restaurants.find((item) => item.name === row.partner);
  const left = daysUntil(row.expires);
  openDrawer({
    title: row.partner,
    subtitle: `${row.id} · ${planName(row.plan)}`,
    tone: row.status === "rejected" || row.status === "expired" ? "danger" : "orange",
    body: `
      <div class="person-head" style="margin-bottom:18px">
        ${avatar(row.partner, "lg")}
        <div><h2>${esc(money(row.amount))}</h2><p>${esc(row.method)} · reference ${esc(row.reference)}</p></div>
        <span style="margin-left:auto">${statusBadge(row.status)}</span>
      </div>
      ${
        row.receipt
          ? `<div class="receipt" style="margin-bottom:16px">
              <span class="receipt__thumb">${icon("receipt")}</span>
              <div style="flex:1"><strong>${esc(row.receipt)}</strong><span>Uploaded with the payment claim · ${esc(row.method)}</span></div>
              <button class="btn btn--outline btn--sm" type="button" data-action="openReceipt" data-id="${row.id}">${icon("eye")} Open</button>
            </div>`
          : `<div class="note" style="margin-bottom:16px">${icon("alert")}<span>No receipt attached. Record the payment once the bank statement confirms it.</span></div>`
      }
      ${row.rejectReason ? `<div class="note" style="margin-bottom:16px">${icon("x")}<span><strong>Rejected</strong> ${esc(row.rejectReason)}</span></div>` : ""}
      <dl class="detail-grid">
        <div><dt>Partner account</dt><dd>${esc(row.account)}</dd></div>
        <div><dt>Billing cycle</dt><dd>Per ${esc(planCycle(row.plan))}</dd></div>
        <div><dt>Plan price</dt><dd>${esc(money(planPrice(row.plan)))}</dd></div>
        <div><dt>Started</dt><dd>${esc(displayDate(row.started))}</dd></div>
        <div><dt>Expires</dt><dd>${esc(displayDate(row.expires))}${left !== null && left > 0 ? ` (${left} days)` : ""}</dd></div>
        <div><dt>Venue status</dt><dd>${venue ? esc(venue.status) : "No venue record"}</dd></div>
        <div><dt>Verified by</dt><dd>${esc(row.verifiedBy || "Not yet verified")}</dd></div>
        <div><dt>Booking commission</dt><dd>0% by design</dd></div>
      </dl>
      <hr class="divider">
      <h3 style="margin-bottom:8px">Effect of this subscription</h3>
      <ul style="display:flex;flex-direction:column;gap:6px;font-size:.82rem;color:var(--ink-soft)">
        <li style="display:flex;gap:8px">${icon("check")} Active subscriptions unlock the partner app menu publishing and deal creation.</li>
        <li style="display:flex;gap:8px">${icon("check")} An expired subscription keeps data but blocks publishing in the partner app.</li>
        <li style="display:flex;gap:8px">${icon("check")} Diners never pay anything: no gateway, no wallet, no commission.</li>
      </ul>`,
    foot: `
      ${
        row.status === "awaiting_verification" || row.status === "rejected"
          ? `<button class="btn btn--danger-ghost" type="button" data-action="rejectReceipt" data-id="${row.id}">${icon("x")} Reject</button>
             <button class="btn btn--primary" type="button" data-action="verify" data-id="${row.id}">${icon("check")} Verify and activate</button>`
          : row.status === "expired"
            ? `<button class="btn btn--primary" type="button" data-action="verify" data-id="${row.id}">${icon("refresh")} Reactivate after payment</button>`
            : `<button class="btn btn--outline" type="button" data-action="markExpired" data-id="${row.id}">${icon("clock")} Mark expired</button>
               <button class="btn btn--primary" type="button" data-action="renew" data-id="${row.id}">${icon("refresh")} Renew now</button>`
      }`,
  });
}

function regionHtml() {
  const rows = pageRows();
  const total = visible().length;
  return `${dataTable({
    rowAction: "open",
    emptyTitle: "No payment records here",
    emptyText: "Switch the tab or clear the search to see other subscriptions.",
    emptyIcon: "card",
    columns: [
      {
        label: "Partner",
        render: (row) => `<div class="table__who">${avatar(row.partner)}<div><strong>${esc(row.partner)}</strong><span>${esc(row.account)}</span></div></div>`,
      },
      { label: "Plan", render: (row) => `${esc(planName(row.plan))}<span class="cell-sub">per ${esc(planCycle(row.plan))}</span>` },
      { label: "Amount", cls: "cell-num", render: (row) => esc(money(row.amount)) },
      { label: "Method", render: (row) => `${esc(row.method)}<span class="cell-sub">${esc(row.reference)}</span>` },
      { label: "Receipt", render: (row) => (row.receipt ? `<span class="badge badge--info">${icon("receipt")} Attached</span>` : `<span class="badge badge--quiet">None</span>`) },
      { label: "Status", render: (row) => statusBadge(row.status) },
      { label: "Expiry", render: expiryCell },
    ],
    rows,
  })}
  <div class="panel__foot">
    ${pager(total, filters.page, PER_PAGE, "subs")}
    <button class="btn btn--ghost btn--sm" type="button" data-action="recordPayment">${icon("plus")} Record a manual payment</button>
  </div>`;
}

export default {
  title: "Subscriptions & Payments",
  eyebrow: "Partners",
  description: "Verify Partner Pro receipts, activate or renew subscriptions and track expiry. Payments are collected outside the apps.",

  render() {
    const awaiting = state.subscriptions.filter((row) => row.status === "awaiting_verification").length;
    const activeRows = state.subscriptions.filter((row) => ["active", "expiring"].includes(row.status));
    const mrr = activeRows.reduce((sum, row) => sum + (row.plan === "pro-annual" ? Math.round(row.amount / 12) : row.amount), 0);
    const expiring = state.subscriptions.filter((row) => {
      const left = daysUntil(row.expires);
      return left !== null && left >= 0 && left <= 14;
    }).length;
    const actions = `<a class="btn btn--outline" href="#/analytics">${icon("chart")} Revenue analytics</a>
      <button class="btn btn--primary" type="button" data-action="recordPayment">${icon("receipt")} Record payment</button>`;
    return {
      actions,
      body: `<div class="grid grid--kpi">
        <div class="kpi kpi--accent"><div class="kpi__top"><span class="kpi__label">Monthly recurring revenue</span><span class="kpi__icon">${icon("wallet")}</span></div><p class="kpi__value">${esc(money(mrr))}</p><span class="kpi__delta is-up"><b>${icon("arrowUp")}7.2%</b> vs last month</span></div>
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Receipts to verify</span><span class="kpi__icon">${icon("receipt")}</span></div><p class="kpi__value">${awaiting}</p><span class="kpi__delta is-flat"><b>Manual activation flow</b></span></div>
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Expiring in 14 days</span><span class="kpi__icon">${icon("clock")}</span></div><p class="kpi__value">${expiring}</p><span class="kpi__delta is-flat"><b>Chase before renewal</b></span></div>
        <div class="kpi"><div class="kpi__top"><span class="kpi__label">Active subscriptions</span><span class="kpi__icon">${icon("checkCircle")}</span></div><p class="kpi__value">${activeRows.length}</p><span class="kpi__delta is-flat"><b>of ${metrics.subscriptions.active} platform wide</b></span></div>
      </div>
      <section class="panel">
        <div class="toolbar">
          <div class="segmented" role="tablist" aria-label="Subscription status" style="flex-wrap:wrap">
            ${TABS.map((tab) => `<button type="button" role="tab" data-action="tab" data-id="${tab.value}" aria-pressed="${filters.tab === tab.value}">${esc(tab.label)}</button>`).join("")}
          </div>
          <span class="spacer"></span>
          ${selectField(
            "s-plan",
            [{ value: "all", label: "Any plan" }, ...state.plans.map((plan) => ({ value: plan.id, label: plan.name.replace("Partner Pro ", "Pro ") }))],
            filters.plan
          )}
          ${searchField("s-q", "Search partner, reference or method", filters.q)}
        </div>
        <div id="region">${regionHtml()}</div>
      </section>
      <div class="note">${icon("shield")}<span><strong>Why this queue exists</strong> DineCircle takes no commission on reservations, deals or experiences. Partners pay ${esc(money(5000))} per month or ${esc(money(50000))} per year through an approved manual process, and an admin activates the subscription here.</span></div>`,
      mount(page) {
        page.querySelectorAll("[data-filter]").forEach((el) => {
          const key = el.dataset.filter.replace("s-", "");
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
      const row = state.subscriptions.find((sub) => sub.id === id);
      if (row) drawer(row);
    },
    tab(value) {
      filters.tab = value;
      filters.page = 1;
      refreshApp();
    },
    verify(id) {
      activate(id);
    },
    renew(id) {
      activate(id, { renew: true });
    },
    rejectReceipt(id) {
      askReject(id);
    },
    markExpired(id) {
      const row = state.subscriptions.find((sub) => sub.id === id);
      if (!row) return;
      commit({
        action: "Marked subscription expired",
        target: `${row.partner} (${row.id})`,
        kind: "warn",
        apply: () => {
          row.status = "expired";
        },
      });
      closeDrawer();
      toast("Subscription marked expired. Publishing is blocked in the partner app.");
    },
    openReceipt(id) {
      const row = state.subscriptions.find((sub) => sub.id === id);
      if (!row) return;
      openModal({
        title: `Receipt preview · ${row.receipt}`,
        body: `<div class="receipt" style="margin-top:14px">
            <span class="receipt__thumb">${icon("receipt")}</span>
            <div><strong>${esc(row.receipt)}</strong><span>${esc(row.method)} · ${esc(money(row.amount))} · reference ${esc(row.reference)}</span></div>
          </div>
          <p style="margin-top:14px;font-size:.78rem;color:var(--muted)">Prototype behaviour: real receipt files live outside this console. In production the admin panel would read the stored object from the venue upload pipeline and show it here with the claimed amount beside the bank statement row.</p>`,
        confirmLabel: "Looks correct",
        onConfirm() {
          toast("Receipt matched against the claimed amount");
        },
      });
    },
    recordPayment() {
      const options = state.restaurants
        .map((venue) => `<option value="${esc(venue.name)}">${esc(venue.name)}</option>`)
        .join("");
      openModal({
        title: "Record a manual payment",
        body: `<p style="margin-top:6px;color:var(--muted);font-size:.84rem">Use this when a partner pays and the receipt arrives by email or WhatsApp instead of the partner app.</p>
          <div class="field" style="margin-top:14px"><label for="pPartner">Restaurant</label><select class="select" id="pPartner">${options}</select></div>
          <div class="field"><label for="pPlan">Plan</label><select class="select" id="pPlan">${state.plans.map((plan) => `<option value="${plan.id}">${esc(plan.name)}</option>`).join("")}</select></div>
          <div class="field"><label for="pMethod">Payment method</label><select class="select" id="pMethod">${METHODS.map((method) => `<option value="${method}">${method}</option>`).join("")}</select></div>
          <div class="field"><label for="pRef">Transaction reference</label><input class="input" id="pRef" placeholder="HBL-8841209"></div>
          <div class="field"><label for="pAmount">Amount received (PKR)</label><input class="input" id="pAmount" type="number" value="${state.plans[0]?.price || 5000}"></div>`,
        confirmLabel: "Create and activate",
        onConfirm() {
          const partner = document.getElementById("pPartner").value;
          const plan = document.getElementById("pPlan").value;
          const method = document.getElementById("pMethod").value;
          const reference = document.getElementById("pRef").value.trim() || "MANUAL";
          const amount = Number(document.getElementById("pAmount").value) || planPrice(plan);
          if (amount < planPrice(plan)) {
            toast(`Amount is below the ${planName(plan)} price`, "danger");
            return false;
          }
          const record = {
            id: `SUB-${9053 + state.subscriptions.length}`,
            partner,
            account: state.partnerAccounts.find((account) => account.restaurants.includes(partner))?.name || "Partner owner",
            plan,
            amount,
            method,
            reference,
            status: "active",
            started: new Date().toISOString(),
            expires: nextExpiry(plan),
            receipt: `${reference.toLowerCase()}-admin-recorded.${method === "Bank transfer" ? "pdf" : "jpg"}`,
            verifiedBy: "Recorded by admin",
            verifiedAt: new Date().toISOString(),
          };
          commit({
            action: "Recorded manual payment and activated subscription",
            target: `${partner} (${record.id})`,
            kind: "success",
            apply: (draft) => draft.subscriptions.unshift(record),
          });
          filters.tab = "active";
          filters.page = 1;
          toast(`${partner} activated until ${displayDate(record.expires)}`);
        },
      });
    },
  },
};
