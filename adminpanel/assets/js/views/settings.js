/* ==========================================================================
   Module: Platform Settings (P1)
   Subscription plan pricing, admin roles and the small set of switches that
   change how the platform behaves. Manual subscription activation is a
   deliberate MVP decision, so pricing here only affects what partners are
   billed outside the apps.
   ========================================================================== */
import { state, commit, session, resetAll, money, displayDate, relativeTime, persist, emit } from "../store.js";
import { icon, esc, avatar, openDrawer, openModal, toast } from "../ui.js";

const TOGGLES = [
  { key: "autoApproveVenues", label: "Auto approve new venue profiles", note: "Off for the MVP pilot. Every application is reviewed by an admin." },
  { key: "requireReceipt", label: "Require a payment receipt before activation", note: "Partners pay by bank transfer, JazzCash or Easypaisa and upload proof." },
  { key: "emailOnNewApplication", label: "Email admins when a partner applies", note: "Sends to the operations admin group address." },
  { key: "emailOnPaymentUpload", label: "Email finance when a receipt is uploaded", note: "Keeps the verification queue moving." },
  { key: "weeklyDigest", label: "Weekly platform digest", note: "Growth, revenue and safety summary every Monday." },
  { key: "maintenanceMode", label: "Maintenance mode", note: "Shows a holding screen in the customer and partner apps. Use only for outages." },
];

const ROLE_CHOICES = ["Super admin", "Operations admin", "Trust and safety", "Finance admin", "Support admin"];

function toggleRow(setting) {
  const on = Boolean(state.settings[setting.key]);
  return `<div class="setting-row">
    <div><strong>${esc(setting.label)}</strong><p>${esc(setting.note)}</p></div>
    <button class="switch" type="button" role="switch" aria-checked="${on}" data-action="toggle" data-id="${setting.key}" aria-label="${esc(setting.label)}"></button>
  </div>`;
}

function planCard(plan, featured) {
  const subs = state.subscriptions.filter((row) => row.plan === plan.id);
  return `<div class="plan-card ${featured ? "plan-card--featured" : ""}">
    <h3>${esc(plan.name)} ${featured ? `<span class="badge badge--orange">Most popular</span>` : ""}</h3>
    <p style="font-size:.79rem;color:var(--muted)">Billed manually per ${esc(plan.cycle)}. No card details are stored anywhere in DineCircle.</p>
    <p class="plan-price">${esc(money(plan.price))} <small>/ ${esc(plan.cycle)}</small></p>
    <ul>
      <li>${icon("check")} Digital menu with unlimited items and categories</li>
      <li>${icon("check")} QR code menus and scan statistics</li>
      <li>${icon("check")} Deals, packages and reservations</li>
      <li>${icon("check")} Experience publishing with a host collaboration</li>
      <li>${icon("check")} 0% commission on every booking</li>
    </ul>
    <div class="row" style="margin-top:16px;justify-content:space-between">
      <span class="chip">${subs.length} subscribed</span>
      <button class="btn btn--outline btn--sm" type="button" data-action="editPlan" data-id="${plan.id}">${icon("edit")} Edit price</button>
    </div>
  </div>`;
}

function adminsTable() {
  const me = session.get();
  return `<div class="table-wrap"><table class="table table--compact">
    <thead><tr><th>Admin</th><th>Role</th><th>Access scope</th><th>Last active</th><th style="text-align:right">Actions</th></tr></thead>
    <tbody>
      ${state.admins
        .map(
          (admin) => `<tr>
            <td><div class="table__who">${avatar(admin.name)}<div><strong>${esc(admin.name)}</strong><span>${esc(admin.email)}</span></div></div></td>
            <td><span class="role-tag ${admin.role === "Super admin" ? "role-tag--owner" : admin.role === "Support admin" ? "role-tag--support" : ""}">${esc(admin.role)}</span></td>
            <td>${esc(admin.scope)}</td>
            <td>${esc(relativeTime(admin.lastActive))}</td>
            <td>
              <div class="cell-actions" style="justify-content:flex-end">
                ${admin.email === me?.email ? `<span class="badge badge--success">You</span>` : ""}
                <button class="btn btn--outline btn--sm" type="button" data-action="changeRole" data-id="${admin.id}">${icon("edit")} Role</button>
                ${admin.role !== "Super admin" ? `<button class="btn btn--danger-ghost btn--sm" type="button" data-action="revokeAdmin" data-id="${admin.id}">${icon("lock")} Revoke</button>` : ""}
              </div>
            </td>
          </tr>`
        )
        .join("")}
    </tbody>
  </table></div>`;
}

export default {
  title: "Platform Settings",
  eyebrow: "System",
  description: "Subscription plans, admin roles and the switches that control partner onboarding, payments and notifications.",

  render() {
    const actions = `<button class="btn btn--outline" type="button" data-action="exportConfig">${icon("download")} Export config</button>
      <button class="btn btn--primary" type="button" data-action="saveConfig">${icon("check")} Save changes</button>`;
    return {
      actions,
      body: `<div class="stack">
        <section class="panel">
          <div class="panel__head">
            <div style="flex:1"><h2>Subscription plans</h2><p>Partners pay DineCircle directly. The apps never charge a diner.</p></div>
            <span class="chip chip--orange">${icon("wallet")} ${esc(money(5000))} / month · ${esc(money(50000))} / year</span>
          </div>
          <div class="panel__body">
            <div class="grid grid--2">${state.plans.map((plan, index) => planCard(plan, index === 1)).join("")}</div>
            <div class="note" style="margin-top:16px">${icon("alert")}<span><strong>Manual activation only.</strong> There is no payment gateway and no wallet. Changing a price here updates what the finance admin checks receipts against; it does not create a charge.</span></div>
          </div>
        </section>

        <section class="panel">
          <div class="panel__head">
            <div style="flex:1">
              <h2>Admin roles and access</h2>
              <p>Five roles cover onboarding, payments, safety and support for the pilot.</p>
            </div>
            <button class="btn btn--primary btn--sm" type="button" data-action="inviteAdmin">${icon("plus")} Add admin</button>
          </div>
          ${adminsTable()}
        </section>

        <section class="panel">
          <div class="panel__head"><div style="flex:1"><h2>Platform configuration</h2><p>Core identity and launch controls</p></div></div>
          <div class="panel__body">
            <div class="grid grid--3">
              <div class="field"><label for="cfgName">Platform name</label><input class="input" id="cfgName" value="${esc(state.settings.platformName)}"></div>
              <div class="field"><label for="cfgEmail">Support email</label><input class="input" id="cfgEmail" value="${esc(state.settings.supportEmail)}"></div>
              <div class="field"><label for="cfgCurrency">Display currency</label><input class="input" id="cfgCurrency" value="${esc(state.settings.currency)}"></div>
              <div class="field"><label for="cfgTz">Timezone</label><input class="input" id="cfgTz" value="${esc(state.settings.timezone)}"></div>
              <div class="field"><label for="cfgCity">Launch city</label><input class="input" id="cfgCity" value="${esc(state.settings.city)}"></div>
              <div class="field"><label for="cfgRisk">Automatic flag threshold</label>
                <select class="select" id="cfgRisk">
                  ${[1, 2, 3, 5].map((n) => `<option value="${n}" ${Number(state.settings.riskFlagThreshold) === n ? "selected" : ""}>${n} report${n === 1 ? "" : "s"} per item</option>`).join("")}
                </select>
              </div>
            </div>
          </div>
        </section>

        <section class="panel">
          <div class="panel__head"><div style="flex:1"><h2>Behaviour switches</h2><p>Changes apply to this prototype immediately</p></div></div>
          <div class="panel__body" style="padding-top:4px">${TOGGLES.map((setting) => toggleRow(setting)).join("")}</div>
        </section>

        <div class="danger-zone">
          <h3>${icon("alert")} Prototype data</h3>
          <p>This console runs entirely on sample data stored in your browser. Nothing here touches the DineCircle API or database.</p>
          <div class="row">
            <button class="btn btn--outline" type="button" data-action="viewSession">${icon("eye")} Inspect stored state</button>
            <button class="btn btn--danger-ghost" type="button" data-action="clearAudit">${icon("trash")} Clear audit log</button>
            <button class="btn btn--danger" type="button" data-action="reset">${icon("refresh")} Reset demo data</button>
          </div>
        </div>

        <div class="note">${icon("users")}<span>Signed in as <strong>${esc(session.get()?.name || "admin")}</strong> · ${esc(session.get()?.role || "Super admin")} · session started ${esc(displayDate(new Date().toISOString(), true))}.</span></div>
      </div>`,
    };
  },

  actions: {
    toggle(key) {
      state.settings[key] = !state.settings[key];
      persist();
      emit();
      const labels = TOGGLES.find((setting) => setting.key === key);
      toast(`${labels?.label || key} ${state.settings[key] ? "enabled" : "disabled"}`, key === "maintenanceMode" && state.settings[key] ? "danger" : "success");
    },
    saveConfig() {
      commit({
        action: "Updated platform configuration",
        target: "Platform settings",
        kind: "info",
        apply: () => {
          state.settings.platformName = document.getElementById("cfgName").value.trim() || "DineCircle";
          state.settings.supportEmail = document.getElementById("cfgEmail").value.trim() || state.settings.supportEmail;
          state.settings.currency = document.getElementById("cfgCurrency").value.trim() || "PKR";
          state.settings.timezone = document.getElementById("cfgTz").value.trim() || "Asia/Karachi";
          state.settings.city = document.getElementById("cfgCity").value.trim() || "Karachi";
          state.settings.riskFlagThreshold = Number(document.getElementById("cfgRisk").value) || 2;
        },
      });
      toast("Configuration saved");
    },
    editPlan(id) {
      const plan = state.plans.find((item) => item.id === id);
      if (!plan) return;
      openModal({
        title: `Edit ${plan.name}`,
        body: `<p style="margin-top:6px;color:var(--muted);font-size:.84rem">Prices are reference values for the manual payment check. Partners are never charged inside the apps.</p>
          <div class="field" style="margin-top:14px"><label for="planPrice">Price in PKR</label><input class="input" id="planPrice" type="number" value="${plan.price}"></div>
          <div class="field"><label for="planName">Display name</label><input class="input" id="planName" value="${esc(plan.name)}"></div>`,
        confirmLabel: "Save plan",
        onConfirm() {
          const price = Number(document.getElementById("planPrice").value);
          const name = document.getElementById("planName").value.trim();
          if (!price || price < 500) {
            toast("Enter a realistic price", "danger");
            return false;
          }
          commit({
            action: "Updated subscription pricing",
            target: `${name}: ${money(price)} per ${plan.cycle}`,
            kind: "orange",
            apply: () => {
              plan.price = price;
              plan.name = name || plan.name;
              state.subscriptions.forEach((sub) => {
                if (sub.plan === plan.id && sub.status !== "active") sub.amount = price;
              });
            },
          });
          toast("Plan pricing updated");
        },
      });
    },
    inviteAdmin() {
      openModal({
        title: "Add an admin",
        body: `<p style="margin-top:6px;color:var(--muted);font-size:.84rem">Admins sign in with the same identity system as partners. Only a super admin can grant the super admin role.</p>
          <div class="field" style="margin-top:14px"><label for="admName">Full name</label><input class="input" id="admName" placeholder="e.g. Laiba Riaz"></div>
          <div class="field"><label for="admEmail">Work email</label><input class="input" id="admEmail" type="email" placeholder="name@dinecircle.app"></div>
          <div class="field"><label for="admRole">Role</label><select class="select" id="admRole">${ROLE_CHOICES.map((role) => `<option value="${role}">${role}</option>`).join("")}</select></div>
          <div class="field"><label for="admScope">Access scope</label><input class="input" id="admScope" value="Partners and venues"></div>`,
        confirmLabel: "Send admin invite",
        onConfirm() {
          const name = document.getElementById("admName").value.trim();
          const email = document.getElementById("admEmail").value.trim();
          if (!name || !email) {
            toast("Name and email are required", "danger");
            return false;
          }
          const record = {
            id: `adm-${6 + state.admins.length}`,
            name,
            email,
            role: document.getElementById("admRole").value,
            scope: document.getElementById("admScope").value.trim() || "Limited",
            lastActive: null,
            invited: true,
          };
          commit({
            action: "Invited a new admin",
            target: `${name} (${record.role})`,
            kind: "success",
            apply: (draft) => draft.admins.push(record),
          });
          toast(`Invite sent to ${email}`);
        },
      });
    },
    changeRole(id) {
      const admin = state.admins.find((row) => row.id === id);
      if (!admin) return;
      openModal({
        title: `Change role for ${admin.name}`,
        body: `<div class="field" style="margin-top:14px"><label for="newRole">Role</label>
          <select class="select" id="newRole">${ROLE_CHOICES.map((role) => `<option value="${role}" ${admin.role === role ? "selected" : ""}>${role}</option>`).join("")}</select></div>
          <div class="field"><label for="newScope">Scope</label><input class="input" id="newScope" value="${esc(admin.scope)}"></div>`,
        confirmLabel: "Apply role",
        onConfirm() {
          const role = document.getElementById("newRole").value;
          const scope = document.getElementById("newScope").value.trim();
          commit({
            action: "Changed admin role",
            target: `${admin.name}: ${role}`,
            kind: "orange",
            apply: () => {
              admin.role = role;
              admin.scope = scope;
            },
          });
          toast(`${admin.name} is now ${role}`);
        },
      });
    },
    revokeAdmin(id) {
      const admin = state.admins.find((row) => row.id === id);
      if (!admin) return;
      openModal({
        title: `Revoke access for ${admin.name}?`,
        body: `<p style="margin-top:6px;color:var(--muted);font-size:.84rem">Their console sessions end immediately. The audit history they created stays intact.</p>`,
        confirmLabel: "Revoke access",
        tone: "danger",
        onConfirm() {
          commit({
            action: "Revoked admin access",
            target: `${admin.name} (${admin.email})`,
            kind: "danger",
            apply: (draft) => { draft.admins = draft.admins.filter((row) => row.id !== id); },
          });
          toast("Admin access revoked");
        },
      });
    },
    viewSession() {
      const summary = `
        <dl class="detail-grid">
          <div><dt>Applications</dt><dd>${state.applications.length}</dd></div>
          <div><dt>Restaurants</dt><dd>${state.restaurants.length}</dd></div>
          <div><dt>Partner accounts</dt><dd>${state.partnerAccounts.length}</dd></div>
          <div><dt>Subscriptions</dt><dd>${state.subscriptions.length}</dd></div>
          <div><dt>Customers</dt><dd>${state.customers.length}</dd></div>
          <div><dt>Hosts</dt><dd>${state.hosts.length}</dd></div>
          <div><dt>Experiences</dt><dd>${state.experiences.length}</dd></div>
          <div><dt>Deals</dt><dd>${state.deals.length}</dd></div>
          <div><dt>Reports</dt><dd>${state.reports.length}</dd></div>
          <div><dt>Content items</dt><dd>${state.contentItems.length}</dd></div>
          <div><dt>Audit entries</dt><dd>${state.auditLog.length}</dd></div>
          <div><dt>Storage key</dt><dd>dinecircle.admin.state.v1</dd></div>
        </dl>
        <pre style="margin-top:16px;padding:14px;border-radius:10px;background:#202124;color:#f5f5f5;font-size:.7rem;line-height:1.5;overflow:auto;max-height:320px">${esc(
          JSON.stringify({ settings: state.settings, plans: state.plans }, null, 2)
        )}</pre>`;
      openDrawer({
        title: "Stored prototype state",
        subtitle: "What this browser has recorded since the demo was seeded",
        body: summary,
        foot: `<button class="btn btn--outline" type="button" data-close-overlay>Close</button>`,
      });
    },
    clearAudit() {
      openModal({
        title: "Clear the audit log?",
        body: `<p style="margin-top:6px;color:var(--muted);font-size:.84rem">A production console would never delete an audit trail. This button exists so the prototype can be demonstrated from a clean slate.</p>`,
        confirmLabel: "Clear log",
        tone: "danger",
        onConfirm() {
          commit({
            action: "Cleared prototype audit log",
            target: `${state.auditLog.length} entries removed`,
            kind: "warn",
            apply: (draft) => { draft.auditLog = []; },
          });
          toast("Audit log cleared", "danger");
        },
      });
    },
    reset() {
      openModal({
        title: "Reset all demo data?",
        body: `<p style="margin-top:6px;color:var(--muted);font-size:.84rem">Every approval, suspension and payment decision you made in this prototype is discarded and the sample dataset is restored. Your sign in stays active.</p>`,
        confirmLabel: "Reset demo data",
        tone: "danger",
        onConfirm() {
          resetAll();
          toast("Demo data restored");
        },
      });
    },
    exportConfig() {
      const lines = Object.entries(state.settings)
        .map(([key, value]) => `${key},${value}`)
        .join("\n");
      const blob = new Blob([`key,value\n${lines}`], { type: "text/csv" });
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = "dinecircle-platform-config.csv";
      link.click();
      URL.revokeObjectURL(url);
      toast("Configuration exported");
    },
  },
};
