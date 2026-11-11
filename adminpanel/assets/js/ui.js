/* ==========================================================================
   DineCircle Admin — UI primitives
   Icons, status badges, charts, pagination, drawer/modal/toast overlays.
   No dependencies: inline SVG and plain DOM, matching the website's approach.
   ========================================================================== */

export const iconPaths = {
  dashboard: '<rect x="3.5" y="3.5" width="7" height="7" rx="2" fill="none" stroke="currentColor" stroke-width="1.7"/><rect x="13.5" y="3.5" width="7" height="7" rx="2" fill="none" stroke="currentColor" stroke-width="1.7"/><rect x="3.5" y="13.5" width="7" height="7" rx="2" fill="none" stroke="currentColor" stroke-width="1.7"/><rect x="13.5" y="13.5" width="7" height="7" rx="2" fill="none" stroke="currentColor" stroke-width="1.7"/>',
  store: '<path d="M4 9.5V19a1.5 1.5 0 0 0 1.5 1.5h13A1.5 1.5 0 0 0 20 19V9.5" fill="none" stroke="currentColor" stroke-width="1.7"/><path d="M3.2 8.2 5 4.5h14l1.8 3.7a2.6 2.6 0 0 1-4.7 1.3 2.6 2.6 0 0 1-4.1 0 2.6 2.6 0 0 1-4.1 0 2.6 2.6 0 0 1-4.7-1.3Z" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="M9.5 20.5v-5h5v5" fill="none" stroke="currentColor" stroke-width="1.7"/>',
  users: '<path d="M15.5 20v-1.4a4.1 4.1 0 0 0-4.1-4.1H7.6A4.1 4.1 0 0 0 3.5 18.6V20" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/><circle cx="9.5" cy="7.5" r="3" fill="none" stroke="currentColor" stroke-width="1.7"/><path d="M16.5 4.7a3 3 0 0 1 0 5.6M20.5 20v-1.4a4.1 4.1 0 0 0-2.8-3.9" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/>',
  user: '<circle cx="12" cy="8" r="3.4" fill="none" stroke="currentColor" stroke-width="1.7"/><path d="M5.5 20.5v-1.2a5 5 0 0 1 5-5h3a5 5 0 0 1 5 5v1.2" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/>',
  host: '<circle cx="12" cy="8" r="3.2" fill="none" stroke="currentColor" stroke-width="1.7"/><path d="M4.5 20.2c0-3.4 3.4-5.7 7.5-5.7s7.5 2.3 7.5 5.7" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/><path d="m18.4 4.2 1 1.9 2.1.3-1.5 1.5.3 2.1-1.9-1-1.9 1 .3-2.1L15.3 6.4l2.1-.3Z" fill="currentColor"/>',
  calendar: '<rect x="4" y="5.5" width="16" height="14.5" rx="2.5" fill="none" stroke="currentColor" stroke-width="1.7"/><path d="M8 3.5v3.5M16 3.5v3.5M4 10h16" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/>',
  card: '<rect x="3" y="5.5" width="18" height="13" rx="2.5" fill="none" stroke="currentColor" stroke-width="1.7"/><path d="M3 10h18" stroke="currentColor" stroke-width="1.7"/><path d="M6.5 15h4" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/>',
  receipt: '<path d="M6 3.5h12v17l-3-2-3 2-3-2-3 2Z" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="M9 8h6M9 11.5h6M9 15h3.5" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>',
  tag: '<path d="M4 11.2V4.8A.8.8 0 0 1 4.8 4h6.4a2 2 0 0 1 1.4.6l7 7a2 2 0 0 1 0 2.8l-5.2 5.2a2 2 0 0 1-2.8 0l-7-7A2 2 0 0 1 4 11.2Z" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><circle cx="9" cy="9" r="1.4" fill="currentColor"/>',
  shield: '<path d="M12 3.2 19 6v5.1c0 4.4-2.9 7.9-7 9.7-4.1-1.8-7-5.3-7-9.7V6l7-2.8Z" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="m8.8 12.1 2.1 2.1 4.3-4.4" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>',
  flag: '<path d="M5 21V4" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/><path d="M5 4.8h11.5l-1.8 4 1.8 4H5" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/>',
  chart: '<path d="M4 20h16" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/><rect x="5.5" y="11" width="3.2" height="6" rx="1" fill="none" stroke="currentColor" stroke-width="1.7"/><rect x="10.4" y="6.5" width="3.2" height="10.5" rx="1" fill="none" stroke="currentColor" stroke-width="1.7"/><rect x="15.3" y="9" width="3.2" height="8" rx="1" fill="none" stroke="currentColor" stroke-width="1.7"/>',
  settings: '<circle cx="12" cy="12" r="3" fill="none" stroke="currentColor" stroke-width="1.7"/><path d="M19.4 14.2a1.6 1.6 0 0 0 .3 1.8l.1.1a1.9 1.9 0 1 1-2.7 2.7l-.1-.1a1.6 1.6 0 0 0-2.7 1.1v.3a1.9 1.9 0 1 1-3.8 0v-.2a1.6 1.6 0 0 0-2.7-1.2l-.1.1a1.9 1.9 0 1 1-2.7-2.7l.1-.1a1.6 1.6 0 0 0-1.1-2.7h-.3a1.9 1.9 0 1 1 0-3.8h.2a1.6 1.6 0 0 0 1.2-2.7l-.1-.1a1.9 1.9 0 1 1 2.7-2.7l.1.1a1.6 1.6 0 0 0 1.8.3h.1a1.6 1.6 0 0 0 1-1.4v-.3a1.9 1.9 0 1 1 3.8 0v.2a1.6 1.6 0 0 0 2.7 1.2l.1-.1a1.9 1.9 0 1 1 2.7 2.7l-.1.1a1.6 1.6 0 0 0 1.1 2.7h.3a1.9 1.9 0 1 1 0 3.8h-.2a1.6 1.6 0 0 0-1.4 1Z" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/>',
  search: '<circle cx="11" cy="11" r="6.5" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="m16 16 4.5 4.5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>',
  bell: '<path d="M18 9a6 6 0 1 0-12 0c0 5-2 6-2 6h16s-2-1-2-6Z" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="M10 19.5a2.2 2.2 0 0 0 4 0" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/>',
  chevron: '<path d="m7 10 5 5 5-5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>',
  chevronRight: '<path d="m10 7 5 5-5 5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>',
  chevronLeft: '<path d="m14 7-5 5 5 5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>',
  check: '<path d="m5 12.5 4.3 4.3L19 7" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
  checkCircle: '<circle cx="12" cy="12" r="8.5" fill="none" stroke="currentColor" stroke-width="1.7"/><path d="m8 12.2 2.7 2.7L16.2 9" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>',
  x: '<path d="m6 6 12 12M18 6 6 18" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>',
  plus: '<path d="M12 5v14M5 12h14" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>',
  filter: '<path d="M4 6.5h16M7 12h10M10 17.5h4" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>',
  download: '<path d="M12 4v11m0 0 4-4m-4 4-4-4" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/><path d="M4.5 17.5V19a1.5 1.5 0 0 0 1.5 1.5h12a1.5 1.5 0 0 0 1.5-1.5v-1.5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>',
  logout: '<path d="M14 4.5h4.5A1.5 1.5 0 0 1 20 6v12a1.5 1.5 0 0 1-1.5 1.5H14" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/><path d="M10 8.5 13.5 12 10 15.5M13 12H4" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>',
  menu: '<path d="M4 7h16M4 12h16M4 17h16" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>',
  clock: '<circle cx="12" cy="12" r="8" fill="none" stroke="currentColor" stroke-width="1.7"/><path d="M12 7.5V12l3 2" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/>',
  alert: '<path d="M12 4.2 21 19.5H3Z" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="M12 9.5V14" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/><circle cx="12" cy="16.6" r="1" fill="currentColor"/>',
  arrowUp: '<path d="M12 19V5m0 0-6 6m6-6 6 6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
  arrowDown: '<path d="M12 5v14m0 0 6-6m-6 6-6-6" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>',
  arrowRight: '<path d="M4.5 12h14m-5.5-5.5L18.5 12 13 17.5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>',
  mail: '<rect x="3.5" y="5.5" width="17" height="13" rx="2.5" fill="none" stroke="currentColor" stroke-width="1.7"/><path d="m4.5 7 7.5 5.5L19.5 7" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>',
  phone: '<path d="M6.2 4h3l1.5 4-2 1.3a11 11 0 0 0 5 5L15 12.3l4 1.5v3A2.2 2.2 0 0 1 16.8 19C10.3 18.5 5.5 13.7 5 7.2A2.2 2.2 0 0 1 6.2 4Z" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/>',
  pin: '<path d="M12 21s7-5.1 7-11a7 7 0 1 0-14 0c0 5.9 7 11 7 11Z" fill="none" stroke="currentColor" stroke-width="1.7"/><circle cx="12" cy="10" r="2.5" fill="none" stroke="currentColor" stroke-width="1.7"/>',
  edit: '<path d="M4.5 19.5h4L20 8a2.1 2.1 0 0 0-3-3L5.5 16.5Z" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="m14.5 6.5 3 3" stroke="currentColor" stroke-width="1.7"/>',
  trash: '<path d="M4.5 7h15M9.5 7V4.8h5V7M6.5 7l.8 12a1.5 1.5 0 0 0 1.5 1.4h6.4a1.5 1.5 0 0 0 1.5-1.4L17.5 7" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/><path d="M10.3 10.5v6M13.7 10.5v6" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>',
  pause: '<rect x="7" y="5" width="3.5" height="14" rx="1.2" fill="currentColor"/><rect x="13.5" y="5" width="3.5" height="14" rx="1.2" fill="currentColor"/>',
  play: '<path d="M8 5.8v12.4a1 1 0 0 0 1.5.9l9.5-6.2a1 1 0 0 0 0-1.8L9.5 4.9A1 1 0 0 0 8 5.8Z" fill="currentColor"/>',
  eye: '<path d="M2.8 12S6 6.2 12 6.2 21.2 12 21.2 12 18 17.8 12 17.8 2.8 12 2.8 12Z" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><circle cx="12" cy="12" r="2.8" fill="none" stroke="currentColor" stroke-width="1.7"/>',
  upload: '<path d="M12 16V5m0 0-4 4m4-4 4 4" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/><path d="M4.5 17.5V19a1.5 1.5 0 0 0 1.5 1.5h12a1.5 1.5 0 0 0 1.5-1.5v-1.5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>',
  more: '<circle cx="6" cy="12" r="1.4" fill="currentColor"/><circle cx="12" cy="12" r="1.4" fill="currentColor"/><circle cx="18" cy="12" r="1.4" fill="currentColor"/>',
  sparkles: '<path d="m12 3 1.9 5.1L19 10l-5.1 1.9L12 17l-1.9-5.1L5 10l5.1-1.9Z" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/><path d="m18.5 15 .9 2.2 2.1.8-2.1.8-.9 2.2-.9-2.2-2.1-.8 2.1-.8Z" fill="currentColor"/>',
  wallet: '<path d="M4 7.5A2.5 2.5 0 0 1 6.5 5H18a2 2 0 0 1 2 2v10a2.5 2.5 0 0 1-2.5 2.5h-11A2.5 2.5 0 0 1 4 17Z" fill="none" stroke="currentColor" stroke-width="1.7"/><path d="M4 9h13a2 2 0 0 1 2 2 2 2 0 0 1-2 2H4" fill="none" stroke="currentColor" stroke-width="1.7"/><circle cx="16.5" cy="11" r=".9" fill="currentColor"/>',
  list: '<path d="M8 6.5h12M8 12h12M8 17.5h12" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/><circle cx="4.3" cy="6.5" r="1.2" fill="currentColor"/><circle cx="4.3" cy="12" r="1.2" fill="currentColor"/><circle cx="4.3" cy="17.5" r="1.2" fill="currentColor"/>',
  inbox: '<path d="M4 13.5 6.1 5.7A1.5 1.5 0 0 1 7.5 4.6h9a1.5 1.5 0 0 1 1.4 1.1L20 13.5v4A1.5 1.5 0 0 1 18.5 19h-13A1.5 1.5 0 0 1 4 17.5Z" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/><path d="M4 13.5h4.2a3.9 3.9 0 0 0 7.6 0H20" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/>',
  lock: '<rect x="5" y="10.5" width="14" height="9.5" rx="2" fill="none" stroke="currentColor" stroke-width="1.7"/><path d="M8.5 10.5V8a3.5 3.5 0 0 1 7 0v2.5" fill="none" stroke="currentColor" stroke-width="1.7"/>',
  refresh: '<path d="M19.5 12a7.5 7.5 0 1 1-2.4-5.5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/><path d="M19.8 4.5V9h-4.5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>',
  building: '<path d="M4.5 20.5V6.2a1.5 1.5 0 0 1 1.5-1.5h7a1.5 1.5 0 0 1 1.5 1.5V20.5" fill="none" stroke="currentColor" stroke-width="1.7"/><path d="M14.5 10.5h4a1.5 1.5 0 0 1 1.5 1.5v8.5M3 20.5h18" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/><path d="M7.5 8.5h3M7.5 12h3M7.5 15.5h3" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>',
};

export function icon(name, cls = "icon") {
  const path = iconPaths[name] || iconPaths.sparkles;
  return `<svg class="${cls}" viewBox="0 0 24 24" aria-hidden="true" focusable="false">${path}</svg>`;
}

export function esc(value = "") {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

export function initials(name = "") {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0].toUpperCase())
    .join("");
}

export function avatar(name, size = "") {
  return `<span class="avatar ${size ? `avatar--${size}` : ""}" aria-hidden="true">${esc(initials(name))}</span>`;
}

const STATUS = {
  active: ["Active", "success"],
  live: ["Live", "success"],
  approved: ["Approved", "success"],
  verified: ["Verified", "success"],
  resolved: ["Resolved", "success"],
  paid: ["Paid", "success"],
  pending: ["Pending", "warn"],
  pending_review: ["Pending review", "warn"],
  pending_verification: ["Awaiting verification", "warn"],
  awaiting_verification: ["Awaiting verification", "warn"],
  expiring: ["Expiring soon", "warn"],
  in_review: ["In review", "info"],
  invited: ["Invited", "info"],
  draft: ["Draft", "quiet"],
  paused: ["Paused", "quiet"],
  completed: ["Completed", "quiet"],
  expired: ["Expired", "danger"],
  rejected: ["Rejected", "danger"],
  suspended: ["Suspended", "danger"],
  cancelled: ["Cancelled", "danger"],
  flagged: ["Flagged", "danger"],
  open: ["Open", "orange"],
  dismissed: ["Dismissed", "quiet"],
  high: ["High", "danger"],
  medium: ["Medium", "warn"],
  low: ["Low", "quiet"],
  user: ["Diner", "info"],
  host: ["Host", "violet"],
  professional: ["Professional", "violet"],
};

export function statusBadge(status) {
  const [label, tone] = STATUS[status] || [String(status).replace(/_/g, " "), "quiet"];
  return `<span class="badge badge--${tone}">${esc(label)}</span>`;
}

export function chip(text, tone = "", iconName = "") {
  return `<span class="chip ${tone ? `chip--${tone}` : ""}">${iconName ? icon(iconName) : ""}${esc(text)}</span>`;
}

export function delta(value, note = "vs last month") {
  const up = value > 0;
  const flat = value === 0;
  const cls = flat ? "is-flat" : up ? "is-up" : "is-down";
  const arrow = flat ? "arrowRight" : up ? "arrowUp" : "arrowDown";
  return `<span class="kpi__delta ${cls}"><b>${icon(arrow)}${Math.abs(value)}%</b> ${esc(note)}</span>`;
}

export function emptyState(title, text, iconName = "search") {
  return `<div class="empty">${icon(iconName)}<h3>${esc(title)}</h3><p>${esc(text)}</p></div>`;
}

/* --------------------------------------------------------------------------
   Charts — hand-drawn SVG so the prototype stays dependency free
   -------------------------------------------------------------------------- */
let chartSeq = 0;

export function lineChart(series, { color = "#f97316", height = 190, label = "value" } = {}) {
  if (!series.length) return emptyState("No data yet", "Charts fill in as activity is recorded.", "chart");
  const id = `chart-${++chartSeq}`;
  const width = 620;
  const padX = 34;
  const padTop = 14;
  const padBottom = 26;
  const plotH = height - padTop - padBottom;
  const values = series.map((point) => point.value);
  const max = Math.max(...values);
  const min = Math.min(...values);
  const span = max - min || 1;
  const stepX = (width - padX * 2) / Math.max(series.length - 1, 1);
  const x = (i) => padX + i * stepX;
  const y = (value) => padTop + plotH - ((value - min) / span) * (plotH - 8) - 4;
  const points = series.map((point, i) => `${x(i).toFixed(1)},${y(point.value).toFixed(1)}`);
  const area = `M${x(0)},${padTop + plotH} L${points.join(" L")} L${x(series.length - 1)},${padTop + plotH} Z`;
  const grid = [0, 1, 2, 3]
    .map((i) => {
      const gy = padTop + (plotH / 3) * i;
      return `<line x1="${padX}" y1="${gy}" x2="${width - padX}" y2="${gy}"/>`;
    })
    .join("");
  const labels = series
    .map((point, i) => `<text x="${x(i)}" y="${height - 6}" text-anchor="middle">${esc(point.label)}</text>`)
    .join("");
  const dots = series
    .map((point, i) => `<circle class="chart__dot" cx="${x(i)}" cy="${y(point.value)}" r="3.4" fill="${color}"><title>${esc(point.label)}: ${point.value.toLocaleString()}</title></circle>`)
    .join("");
  return `<div class="chart"><svg viewBox="0 0 ${width} ${height}" role="img" aria-label="${esc(label)} trend">
    <defs>
      <linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="${color}" stop-opacity=".34"/>
        <stop offset="1" stop-color="${color}" stop-opacity="0"/>
      </linearGradient>
    </defs>
    <g class="chart__grid">${grid}</g>
    <path class="chart__area" d="${area}" fill="url(#${id})"/>
    <polyline class="chart__line" points="${points.join(" ")}" stroke="${color}"/>
    ${dots}
    <g class="chart__axis">${labels}</g>
  </svg></div>`;
}

export function barChart(series, { color = "#f97316", height = 190, label = "value" } = {}) {
  if (!series.length) return emptyState("No data yet", "Charts fill in as activity is recorded.", "chart");
  const width = 620;
  const padX = 34;
  const padTop = 16;
  const padBottom = 26;
  const plotH = height - padTop - padBottom;
  const max = Math.max(...series.map((p) => p.value)) || 1;
  const slot = (width - padX * 2) / series.length;
  const barW = Math.min(slot * 0.5, 42);
  const bars = series
    .map((point, i) => {
      const h = Math.max((point.value / max) * plotH, 3);
      const bx = padX + slot * i + (slot - barW) / 2;
      const by = padTop + plotH - h;
      return `<rect class="chart__bar" x="${bx}" y="${by}" width="${barW}" height="${h}" rx="6" fill="${color}"><title>${esc(point.label)}: ${point.value.toLocaleString()}</title></rect>
        <text x="${bx + barW / 2}" y="${height - 6}" text-anchor="middle" fill="#9aa0aa" font-size="10" font-weight="500">${esc(point.label)}</text>`;
    })
    .join("");
  const grid = [0, 1, 2]
    .map((i) => {
      const gy = padTop + (plotH / 2) * i;
      return `<line x1="${padX}" y1="${gy}" x2="${width - padX}" y2="${gy}" stroke="#efe9e2"/>`;
    })
    .join("");
  return `<div class="chart"><svg viewBox="0 0 ${width} ${height}" role="img" aria-label="${esc(label)} chart">${grid}${bars}</svg></div>`;
}

export function donut(segments) {
  const total = segments.reduce((sum, seg) => sum + seg.value, 0) || 1;
  const radius = 54;
  const circumference = 2 * Math.PI * radius;
  let offset = 0;
  const rings = segments
    .map((seg) => {
      const length = (seg.value / total) * circumference;
      const ring = `<circle cx="70" cy="70" r="${radius}" fill="none" stroke="${seg.color}" stroke-width="18"
        stroke-dasharray="${length.toFixed(2)} ${(circumference - length).toFixed(2)}"
        stroke-dashoffset="${(-offset).toFixed(2)}" transform="rotate(-90 70 70)"><title>${esc(seg.label)}: ${seg.value}</title></circle>`;
      offset += length;
      return ring;
    })
    .join("");
  const legend = segments
    .map(
      (seg) => `<span><i style="background:${seg.color}"></i>${esc(seg.label)}<b>${seg.value}</b></span>`
    )
    .join("");
  return `<div class="donut">
    <svg viewBox="0 0 140 140" role="img" aria-label="Plan mix">
      <circle cx="70" cy="70" r="${radius}" fill="none" stroke="#fdf1e7" stroke-width="18"/>
      ${rings}
      <text x="70" y="66" text-anchor="middle" font-size="20" font-weight="600" fill="#202124">${total}</text>
      <text x="70" y="83" text-anchor="middle" font-size="9" font-weight="600" fill="#6b7280" letter-spacing="1">ACCOUNTS</text>
    </svg>
    <div class="donut__legend">${legend}</div>
  </div>`;
}

/* --------------------------------------------------------------------------
   Pagination
   -------------------------------------------------------------------------- */
export function pager(total, page, perPage, idPrefix = "page") {
  const pages = Math.max(Math.ceil(total / perPage), 1);
  const start = total === 0 ? 0 : (page - 1) * perPage + 1;
  const end = Math.min(page * perPage, total);
  const numbers = [];
  for (let i = 1; i <= pages; i += 1) {
    if (pages > 6 && i > 2 && i < pages - 1 && Math.abs(i - page) > 1) {
      if (numbers[numbers.length - 1] !== "…") numbers.push("…");
      continue;
    }
    numbers.push(i);
  }
  const buttons = numbers
    .map((n) =>
      n === "…"
        ? `<button type="button" disabled>…</button>`
        : `<button type="button" data-page="${n}" data-page-group="${idPrefix}" ${n === page ? 'aria-current="true"' : ""}>${n}</button>`
    )
    .join("");
  return `<span>Showing ${start}–${end} of ${total}</span>
    <div class="pagination">
      <button type="button" data-page="${page - 1}" data-page-group="${idPrefix}" ${page <= 1 ? "disabled" : ""} aria-label="Previous page">${icon("chevronLeft", "icon")}</button>
      ${buttons}
      <button type="button" data-page="${page + 1}" data-page-group="${idPrefix}" ${page >= pages ? "disabled" : ""} aria-label="Next page">${icon("chevronRight")}</button>
    </div>`;
}

export function matches(haystack, query) {
  return String(haystack || "").toLowerCase().includes(String(query || "").toLowerCase());
}

/* --------------------------------------------------------------------------
   Overlays
   -------------------------------------------------------------------------- */
let activeOverlay = null;

function closeOverlay() {
  if (!activeOverlay) return;
  const { node, scrim, restoreFocus } = activeOverlay;
  activeOverlay = null;
  scrim.classList.remove("is-open");
  if (node) node.classList.remove("is-open");
  const teardown = () => {
    scrim.remove();
    node?.remove();
  };
  setTimeout(teardown, 260);
  if (restoreFocus && document.contains(restoreFocus)) restoreFocus.focus();
  document.removeEventListener("keydown", onOverlayKey);
}

function onOverlayKey(event) {
  if (event.key === "Escape") {
    event.preventDefault();
    closeOverlay();
  }
}

export function closeDrawer() {
  closeOverlay();
}

export function openDrawer({ title, subtitle = "", body, foot = "", tone = "orange" }) {
  closeOverlay();
  const restoreFocus = document.activeElement;
  const scrim = document.createElement("div");
  scrim.className = "scrim";
  const drawer = document.createElement("aside");
  drawer.className = "drawer";
  drawer.setAttribute("role", "dialog");
  drawer.setAttribute("aria-modal", "true");
  drawer.setAttribute("aria-label", title);
  drawer.innerHTML = `
    <div class="drawer__head">
      <div style="flex:1">
        <span class="eyebrow" style="margin-bottom:4px">${esc(tone === "danger" ? "Moderation" : "Record detail")}</span>
        <h2>${esc(title)}</h2>
        ${subtitle ? `<p>${esc(subtitle)}</p>` : ""}
      </div>
      <button class="icon-btn" type="button" data-close-overlay aria-label="Close panel">${icon("x")}</button>
    </div>
    <div class="drawer__body">${body}</div>
    ${foot ? `<div class="drawer__foot">${foot}</div>` : ""}`;
  document.body.append(scrim, drawer);
  activeOverlay = { node: drawer, scrim, restoreFocus };
  requestAnimationFrame(() => {
    scrim.classList.add("is-open");
    drawer.classList.add("is-open");
  });
  drawer.querySelector("[data-close-overlay]")?.focus();
  document.addEventListener("keydown", onOverlayKey);
  return closeOverlay;
}

export function openModal({ title, body, confirmLabel = "Confirm", tone = "primary", onConfirm }) {
  const restoreFocus = document.activeElement;
  const modal = document.createElement("div");
  modal.className = "modal";
  modal.setAttribute("role", "dialog");
  modal.setAttribute("aria-modal", "true");
  modal.setAttribute("aria-label", title);
  modal.innerHTML = `
    <div class="modal__card">
      <h2>${esc(title)}</h2>
      <div>${body}</div>
      <div class="modal__actions">
        <button class="btn btn--outline" type="button" data-modal-cancel>Cancel</button>
        <button class="btn ${tone === "danger" ? "btn--danger" : "btn--primary"}" type="button" data-modal-confirm>${esc(confirmLabel)}</button>
      </div>
    </div>`;
  document.body.append(modal);
  const closer = () => {
    modal.remove();
    document.removeEventListener("keydown", onKey);
    restoreFocus?.focus?.();
  };
  const onKey = (event) => {
    if (event.key === "Escape") closer();
  };
  modal.addEventListener("click", (event) => {
    if (event.target === modal) closer();
  });
  modal.querySelector("[data-modal-cancel]").addEventListener("click", closer);
  modal.querySelector("[data-modal-confirm]").addEventListener("click", () => {
    const keepOpen = onConfirm?.() === false;
    if (!keepOpen) closer();
  });
  document.addEventListener("keydown", onKey);
  modal.querySelector("[data-modal-confirm]").focus();
}

let toastTimer = 0;

export function toast(message, tone = "success") {
  let stack = document.querySelector(".toast-stack");
  if (!stack) {
    stack = document.createElement("div");
    stack.className = "toast-stack";
    stack.setAttribute("role", "status");
    stack.setAttribute("aria-live", "polite");
    document.body.append(stack);
  }
  const node = document.createElement("div");
  node.className = `toast ${tone === "danger" ? "toast--danger" : ""}`;
  node.innerHTML = `${icon(tone === "danger" ? "alert" : "checkCircle")}<span>${esc(message)}</span>`;
  stack.append(node);
  window.clearTimeout(toastTimer);
  setTimeout(() => {
    node.style.opacity = "0";
    node.style.transform = "translateY(6px)";
    node.style.transition = "opacity .2s, transform .2s";
    setTimeout(() => node.remove(), 220);
  }, 3200);
}
