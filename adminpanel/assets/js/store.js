/* ==========================================================================
   DineCircle Admin — prototype store
   Holds the mock dataset, a signed-in session and the audit trail. State is
   persisted to localStorage so demo actions survive a refresh. Replace
   `commit` with API calls when this moves beyond prototype.
   ========================================================================== */

import { seedState, plans as planSeed } from "./data.js";

const STATE_KEY = "dinecircle.admin.state.v1";
const SESSION_KEY = "dinecircle.admin.session.v1";

const listeners = new Set();

function read(key) {
  try {
    const raw = localStorage.getItem(key);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

function write(key, value) {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch {
    /* storage unavailable: the prototype keeps running in memory */
  }
}

function hydrate() {
  const stored = read(STATE_KEY);
  if (!stored) return seedState();
  // Merge missing top-level keys so older demo state keeps working after the
  // fixture list grows.
  return { ...seedState(), ...stored, plans: stored.plans?.length ? stored.plans : planSeed };
}

export const state = hydrate();

export function subscribe(fn) {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

export function emit() {
  listeners.forEach((fn) => fn(state));
}

export function persist() {
  write(STATE_KEY, state);
}

export const session = {
  get() {
    return read(SESSION_KEY);
  },
  start(admin) {
    write(SESSION_KEY, admin);
  },
  end() {
    try {
      localStorage.removeItem(SESSION_KEY);
    } catch {
      /* ignore */
    }
  },
};

const ROLE_META = {
  "Super admin": { name: "Ayesha Siddiqui", email: "ayesha@dinecircle.app", scope: "Full platform" },
  "Operations admin": { name: "Bilal Ahmed", email: "bilal@dinecircle.app", scope: "Partners and venues" },
  "Trust and safety": { name: "Hira Malik", email: "hira@dinecircle.app", scope: "Reports, content, hosts" },
  "Finance admin": { name: "Danish Qureshi", email: "danish@dinecircle.app", scope: "Subscriptions and receipts" },
  "Support admin": { name: "Zara Iqbal", email: "zara@dinecircle.app", scope: "Customers and hosts" },
};

export function signIn(role) {
  const meta = ROLE_META[role] || ROLE_META["Super admin"];
  const admin = { ...meta, role, initials: initialsOf(meta.name) };
  session.start(admin);
  return admin;
}

export function initialsOf(name = "") {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0].toUpperCase())
    .join("");
}

export function displayDate(iso, withTime = false) {
  if (!iso) return "Not set";
  const date = new Date(iso);
  const opts = withTime
    ? { day: "numeric", month: "short", year: "numeric", hour: "numeric", minute: "2-digit" }
    : { day: "numeric", month: "short", year: "numeric" };
  return new Intl.DateTimeFormat("en-GB", { ...opts, timeZone: "Asia/Karachi" }).format(date);
}

export function relativeTime(iso) {
  if (!iso) return "never";
  const diff = Date.now() - new Date(iso).getTime();
  const future = diff < 0;
  const abs = Math.abs(diff);
  const minutes = Math.round(abs / 60000);
  if (minutes < 1) return "just now";
  if (minutes < 60) return future ? `in ${minutes} min` : `${minutes} min ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return future ? `in ${hours} hr` : `${hours} hr ago`;
  const days = Math.round(hours / 24);
  if (days < 30) return future ? `in ${days} days` : `${days} days ago`;
  const months = Math.round(days / 30);
  return future ? `in ${months} months` : `${months} months ago`;
}

export function daysUntil(iso) {
  if (!iso) return null;
  return Math.ceil((new Date(iso).getTime() - Date.now()) / 86400000);
}

export function money(value) {
  return `Rs. ${Number(value).toLocaleString("en-PK")}`;
}

export function counts() {
  return {
    pendingApplications: state.applications.filter((a) => a.status === "pending" || a.status === "in_review").length,
    pendingReceipts: state.subscriptions.filter((s) => s.status === "awaiting_verification").length,
    openReports: state.reports.filter((r) => r.status === "open" || r.status === "in_review").length,
    pendingExperiences: state.experiences.filter((e) => e.status === "pending_review").length,
    flaggedDeals: state.deals.filter((d) => d.status === "flagged").length,
    flaggedHosts: state.hosts.filter((h) => h.reports > 0 && h.status !== "suspended").length,
  };
}

export function addAudit(action, target, kind = "orange") {
  const who = session.get()?.name || "Admin";
  state.auditLog.unshift({
    id: `AUD-${3400 + Math.floor(Math.random() * 500)}`,
    actor: who,
    action,
    target,
    kind,
    at: new Date().toISOString(),
  });
  state.auditLog = state.auditLog.slice(0, 60);
}

/**
 * Apply an in-place mutation, append an audit entry and persist.
 * Views call this instead of touching nested objects directly.
 */
export function commit({ action, target, kind = "orange", apply }) {
  if (typeof apply === "function") apply(state);
  addAudit(action, target, kind);
  persist();
  emit();
}

export function resetAll() {
  const fresh = seedState();
  Object.keys(state).forEach((key) => delete state[key]);
  Object.assign(state, fresh);
  persist();
  emit();
}

export function nextExpiry(planId, from = new Date()) {
  const plan = state.plans.find((p) => p.id === planId) || state.plans[0];
  const date = new Date(from);
  if (plan.cycle === "year") date.setFullYear(date.getFullYear() + 1);
  else date.setMonth(date.getMonth() + 1);
  return date.toISOString();
}

export function planName(planId) {
  return state.plans.find((p) => p.id === planId)?.name || "Partner Pro";
}

export function planPrice(planId) {
  return state.plans.find((p) => p.id === planId)?.price || 5000;
}

export function planCycle(planId) {
  return state.plans.find((p) => p.id === planId)?.cycle || "month";
}
