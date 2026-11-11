/* ==========================================================================
   Shared table helpers used by every admin module.
   ========================================================================== */
import { emptyState } from "../ui.js";

/**
 * Render a data table.
 * columns: [{ label, cls, render(row) }]
 * rowAction: action name dispatched through app.js when a row is clicked.
 */
export function dataTable({
  columns,
  rows,
  rowId = (row) => row.id,
  rowAction = "open",
  selectable = false,
  selected = [],
  emptyTitle = "Nothing to review",
  emptyText = "New items will appear here as they arrive.",
  emptyIcon = "search",
  className = "",
}) {
  const head = `<tr>
    ${selectable ? `<th class="col-check"><input type="checkbox" data-action="select-all" aria-label="Select all rows"></th>` : ""}
    ${columns.map((col) => `<th class="${col.cls || ""}">${col.label}</th>`).join("")}
  </tr>`;
  const body = rows.length
    ? rows
        .map((row, index) => {
          const id = rowId(row);
          const isSelected = selected.includes(id);
          return `<tr class="is-selectable ${isSelected ? "is-selected" : ""}" data-action="${rowAction}" data-id="${id}" data-row-index="${index}">
            ${
              selectable
                ? `<td class="col-check"><input type="checkbox" data-action="select" data-id="${id}" ${isSelected ? "checked" : ""} aria-label="Select ${id}"></td>`
                : ""
            }
            ${columns.map((col) => `<td class="${col.cls || ""}">${col.render(row)}</td>`).join("")}
          </tr>`;
        })
        .join("")
    : `<tr><td colspan="${columns.length + (selectable ? 1 : 0)}">${emptyState(emptyTitle, emptyText, emptyIcon)}</td></tr>`;
  return `<div class="table-wrap"><table class="table ${className}" aria-label="${emptyTitle}">
    <thead>${head}</thead><tbody>${body}</tbody>
  </table></div>`;
}

export function searchField(id, placeholder, value = "") {
  return `<div class="search-wrap">
    <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="11" cy="11" r="6.5" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="m16 16 4.5 4.5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>
    <input class="input" type="search" id="${id}" data-filter="${id}" value="${value}" placeholder="${placeholder}" autocomplete="off">
  </div>`;
}

export function selectField(id, options, value) {
  return `<select class="select" id="${id}" data-filter="${id}" aria-label="${id}">
    ${options.map((opt) => `<option value="${opt.value}" ${opt.value === value ? "selected" : ""}>${opt.label}</option>`).join("")}
  </select>`;
}

export function twoColumn(primary, secondary) {
  return `<div class="grid grid--main">${primary}${secondary}</div>`;
}

export function detailRow(label, value) {
  return `<div><dt>${label}</dt><dd>${value}</dd></div>`;
}

export function countBy(list, key, value) {
  return list.filter((item) => item[key] === value).length;
}
