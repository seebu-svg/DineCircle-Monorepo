/* Route helpers kept separate so views can navigate without importing app.js. */
export function navigate(key) {
  const next = `#/${key}`;
  if (location.hash === next) return;
  location.hash = next;
}

export function currentRoute() {
  const match = location.hash.match(/^#\/([a-z-]+)/);
  return match ? match[1] : "dashboard";
}

/* app.js registers its refresh() here so a view can ask for a full page
   re-render (for example when a segmented control changes) without importing
   app.js and creating a circular dependency. */
let refreshHandler = () => {};

export function setRefresh(handler) {
  refreshHandler = handler;
}

export function refreshApp() {
  refreshHandler();
}
