/* ==========================================================================
   DineCircle: site behaviour
   Sticky header, mobile nav, city picker, app dialog, live dates and opening
   hours (Asia/Karachi), directory filters, copy-to-clipboard and contact form.
   No dependencies. Everything degrades to readable static HTML without JS.
   ========================================================================== */
(function () {
  "use strict";

  var KARACHI = "Asia/Karachi";
  var CONTACT_EMAIL = "hello@dinecircle.app";
  var CITY_KEY = "dc-city";

  function $(selector, root) {
    return (root || document).querySelector(selector);
  }

  function $$(selector, root) {
    return Array.prototype.slice.call((root || document).querySelectorAll(selector));
  }

  /* Strip accents and case so "cafe" matches "café". */
  function norm(value) {
    return String(value || "")
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase()
      .trim();
  }

  function debounce(fn, wait) {
    var timer;
    return function () {
      var args = arguments;
      var self = this;
      clearTimeout(timer);
      timer = setTimeout(function () {
        fn.apply(self, args);
      }, wait);
    };
  }

  /* Toast ------------------------------------------------------------------ */
  var toastTimer;
  function toast(message) {
    var el = document.getElementById("toast");
    if (!el) return;
    el.textContent = message;
    el.classList.add("is-visible");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () {
      el.classList.remove("is-visible");
    }, 2600);
  }

  /* Header + mobile nav ---------------------------------------------------- */
  function initHeader() {
    var header = $("[data-header]");
    if (header) {
      var onScroll = function () {
        header.classList.toggle("is-scrolled", window.scrollY > 6);
      };
      onScroll();
      window.addEventListener("scroll", onScroll, { passive: true });
    }

    var toggle = $("[data-nav-toggle]");
    var headerEl = $(".site-header");
    if (!toggle || !headerEl) return;

    var nav = document.getElementById(toggle.getAttribute("aria-controls"));

    function setNav(open) {
      headerEl.classList.toggle("nav-open", open);
      document.body.classList.toggle("nav-open", open);
      toggle.setAttribute("aria-expanded", String(open));
      toggle.setAttribute("aria-label", open ? "Close menu" : "Open menu");
    }

    toggle.addEventListener("click", function () {
      setNav(!headerEl.classList.contains("nav-open"));
    });

    if (nav) {
      nav.addEventListener("click", function (event) {
        if (event.target.closest("a")) setNav(false);
      });
    }

    document.addEventListener("keydown", function (event) {
      if (event.key === "Escape" && headerEl.classList.contains("nav-open")) {
        setNav(false);
        toggle.focus();
      }
    });

    window.addEventListener("resize", function () {
      if (window.innerWidth > 980) setNav(false);
    });
  }

  /* City picker ------------------------------------------------------------ */
  function initCityPicker() {
    var picker = $("[data-city-picker]");
    if (!picker) return;

    var button = $(".city-btn", picker);
    var menu = document.getElementById("cityMenu");
    var label = $("[data-city-label]", picker);
    var options = $$("[data-city]", menu);
    if (!button || !menu) return;

    var saved = null;
    try {
      saved = window.localStorage.getItem(CITY_KEY);
    } catch (err) {
      saved = null;
    }

    function select(city, announce) {
      if (label) label.textContent = city;
      options.forEach(function (option) {
        option.setAttribute("aria-selected", String(option.dataset.city === city));
      });
      try {
        window.localStorage.setItem(CITY_KEY, city);
      } catch (err) {
        /* Storage can be blocked; the label still updates. */
      }
      if (announce) toast(city + " is live. All listings on this site are in Karachi for now.");
    }

    function setOpen(open) {
      menu.hidden = !open;
      button.setAttribute("aria-expanded", String(open));
    }

    if (saved && options.some(function (o) { return o.dataset.city === saved; })) {
      select(saved, false);
    }

    button.addEventListener("click", function () {
      setOpen(menu.hidden);
    });

    options.forEach(function (option) {
      option.addEventListener("click", function () {
        if (option.getAttribute("aria-disabled") === "true") {
          setOpen(false);
          toast(option.dataset.city + " opens soon. Karachi is live today.");
          return;
        }
        select(option.dataset.city, true);
        setOpen(false);
        button.focus();
      });
      option.addEventListener("keydown", function (event) {
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault();
          option.click();
        }
      });
    });

    document.addEventListener("click", function (event) {
      if (!picker.contains(event.target)) setOpen(false);
    });

    document.addEventListener("keydown", function (event) {
      if (event.key === "Escape" && !menu.hidden) {
        setOpen(false);
        button.focus();
      }
    });
  }

  /* App dialog ------------------------------------------------------------- */
  function initAppDialog() {
    var dialog = document.getElementById("appDialog");
    if (!dialog) return;

    var lastFocus = null;

    document.addEventListener("click", function (event) {
      if (!event.target.closest("[data-app-cta]")) return;
      event.preventDefault();
      lastFocus = event.target.closest("[data-app-cta]");
      if (typeof dialog.showModal === "function") {
        if (!dialog.open) dialog.showModal();
      } else {
        dialog.setAttribute("open", "");
      }
    });

    $$("[data-close-dialog]", dialog).forEach(function (button) {
      button.addEventListener("click", function () {
        if (typeof dialog.close === "function") dialog.close();
        else dialog.removeAttribute("open");
      });
    });

    /* Click on the backdrop (the dialog box itself) closes the sheet. */
    dialog.addEventListener("click", function (event) {
      if (event.target !== dialog) return;
      if (typeof dialog.close === "function") dialog.close();
      else dialog.removeAttribute("open");
    });

    dialog.addEventListener("close", function () {
      if (lastFocus && document.contains(lastFocus)) lastFocus.focus();
    });
  }

  /* Dates ------------------------------------------------------------------ */
  var MS_DAY = 86400000;

  function karachiToday() {
    var parts = new Intl.DateTimeFormat("en-CA", {
      timeZone: KARACHI, year: "numeric", month: "2-digit", day: "2-digit"
    }).formatToParts(new Date());
    var map = {};
    parts.forEach(function (part) {
      map[part.type] = part.value;
    });
    return new Date(Date.UTC(Number(map.year), Number(map.month) - 1, Number(map.day)));
  }

  var TODAY = karachiToday();

  function eventDate(el) {
    var offset = parseInt(el.dataset.offset || "0", 10) || 0;
    return new Date(TODAY.getTime() + offset * MS_DAY);
  }

  function formatDate(date, options) {
    var settings = Object.assign({ timeZone: "UTC" }, options);
    return new Intl.DateTimeFormat("en-GB", settings).format(date);
  }

  function clock(hour, minute) {
    var suffix = hour < 12 ? "AM" : "PM";
    var h = hour % 12 || 12;
    return h + ":" + String(minute).padStart(2, "0") + " " + suffix;
  }

  function pad(value) {
    return String(value).padStart(2, "0");
  }

  function initDates() {
    $$("[data-date]").forEach(function (el) {
      var date = eventDate(el);
      var hour = parseInt(el.dataset.hour || "19", 10);
      var minute = parseInt(el.dataset.minute || "0", 10);
      var format = el.dataset.format || "short";
      var duration = parseInt(el.dataset.duration || "0", 10);

      el.setAttribute("datetime", date.toISOString().slice(0, 10) + "T" + pad(hour) + ":" + pad(minute));

      if (format === "badge") {
        var dow = $(".date-dow", el);
        var day = $(".date-day", el);
        if (dow) dow.textContent = formatDate(date, { weekday: "short" });
        if (day) day.textContent = formatDate(date, { day: "numeric", month: "short" });
        el.setAttribute("title", formatDate(date, { weekday: "long", day: "numeric", month: "long", year: "numeric" }));
        return;
      }

      if (format === "long") {
        el.textContent = formatDate(date, { weekday: "long", day: "numeric", month: "long", year: "numeric" });
        return;
      }

      if (format === "range") {
        var end = hour * 60 + minute + duration;
        var endHour = Math.floor(end / 60) % 24;
        var endMinute = end % 60;
        el.textContent = clock(hour, minute) + " – " + clock(endHour, endMinute);
        return;
      }

      el.textContent = formatDate(date, { weekday: "short", day: "numeric", month: "short" });
    });
  }

  /* Opening hours ---------------------------------------------------------- */
  var hourFormatter = new Intl.DateTimeFormat("en-US", {
    timeZone: KARACHI, weekday: "short", hour: "2-digit", minute: "2-digit", hour12: false
  });

  function karachiNow() {
    var parts = {};
    hourFormatter.formatToParts(new Date()).forEach(function (part) {
      parts[part.type] = part.value;
    });
    return {
      day: String(parts.weekday || "").toLowerCase().slice(0, 3),
      minutes: (Number(parts.hour) % 24) * 60 + Number(parts.minute)
    };
  }

  function toMinutes(value) {
    var bits = String(value || "0:0").split(":");
    return Number(bits[0]) * 60 + Number(bits[1] || 0);
  }

  function twelve(value) {
    var minutes = toMinutes(value);
    return clock(Math.floor(minutes / 60) % 24, minutes % 60);
  }

  function updateHours(el) {
    var now = karachiNow();
    var open = el.dataset.open;
    var close = el.dataset.close;
    if (!open || !close) return;

    var closedDays = (el.dataset.closed || "").split(",").filter(Boolean);
    var closedToday = closedDays.indexOf(now.day) !== -1;
    var opens = toMinutes(open);
    var closes = toMinutes(close);
    var overnight = closes <= opens;
    var isOpen = !closedToday && (overnight
      ? now.minutes >= opens || now.minutes < closes
      : now.minutes >= opens && now.minutes < closes);

    el.classList.toggle("is-open", isOpen);
    el.classList.toggle("is-closed", !isOpen);

    if (isOpen) {
      el.textContent = "Open now · until " + twelve(close);
    } else if (closedToday) {
      el.textContent = "Closed today";
    } else {
      el.textContent = "Closed · opens " + twelve(open);
    }
  }

  function initHours() {
    var pills = $$("[data-hours]");
    if (!pills.length) return;
    var refresh = function () {
      pills.forEach(updateHours);
    };
    refresh();
    setInterval(refresh, 60000);
    document.addEventListener("visibilitychange", function () {
      if (!document.hidden) refresh();
    });
  }

  /* Venue directory -------------------------------------------------------- */
  function initVenueFilters() {
    var grid = document.getElementById("venueGrid");
    if (!grid) return;

    var cards = $$("[data-venue-card]", grid);
    var search = $("[data-venue-search]");
    var chips = $$("[data-filter]");
    var priceSelect = $("[data-price-filter]");
    var sortSelect = $("[data-sort]");
    var count = $("[data-result-count]");
    var empty = $("[data-empty]");
    var clearSearch = $("[data-clear-search]");
    var clearAll = $("[data-clear-filters]");
    var total = cards.length;

    cards.forEach(function (card, index) {
      card.dataset.order = String(index);
    });

    var params = new URLSearchParams(window.location.search);
    var state = {
      q: params.get("q") || "",
      cuisine: params.get("cuisine") || "all",
      price: params.get("price") || "all",
      sort: params.get("sort") || "recommended"
    };

    function syncUrl() {
      var next = new URLSearchParams(window.location.search);
      ["q", "cuisine", "price", "sort"].forEach(function (key) {
        var value = state[key];
        if (!value || value === "all" || value === "recommended") next.delete(key);
        else next.set(key, value);
      });
      var query = next.toString();
      var url = window.location.pathname + (query ? "?" + query : "") + window.location.hash;
      window.history.replaceState(null, "", url);
    }

    function apply() {
      var needle = norm(state.q);
      var shown = 0;

      cards.forEach(function (card) {
        var cuisines = (card.dataset.cuisines || "").split(" ");
        var matchQuery = !needle || norm(card.dataset.search).indexOf(needle) !== -1;
        var matchCuisine = state.cuisine === "all" || cuisines.indexOf(state.cuisine) !== -1;
        var matchPrice = state.price === "all" || card.dataset.price === state.price;
        var visible = matchQuery && matchCuisine && matchPrice;
        card.hidden = !visible;
        if (visible) shown += 1;
      });

      var ordered = cards.slice().sort(function (a, b) {
        if (state.sort === "az") {
          return a.dataset.name.localeCompare(b.dataset.name);
        }
        if (state.sort === "price-low") {
          return Number(a.dataset.price) - Number(b.dataset.price) || Number(a.dataset.order) - Number(b.dataset.order);
        }
        if (state.sort === "price-high") {
          return Number(b.dataset.price) - Number(a.dataset.price) || Number(a.dataset.order) - Number(b.dataset.order);
        }
        return Number(a.dataset.order) - Number(b.dataset.order);
      });
      ordered.forEach(function (card) {
        grid.appendChild(card);
      });

      if (count) {
        var filtered = shown !== total;
        count.textContent = filtered
          ? "Showing " + shown + " of " + total + " places"
          : "Showing " + total + " places";
      }

      if (empty) empty.hidden = shown > 0;

      chips.forEach(function (chip) {
        var active = chip.dataset.filter === state.cuisine;
        chip.classList.toggle("is-active", active);
        chip.setAttribute("aria-pressed", String(active));
      });

      if (clearSearch && search) clearSearch.hidden = !search.value;
    }

    chips.forEach(function (chip) {
      chip.addEventListener("click", function () {
        state.cuisine = chip.dataset.filter || "all";
        apply();
        syncUrl();
      });
    });

    if (search) {
      search.value = state.q;
      search.addEventListener("input", debounce(function () {
        state.q = search.value.trim();
        apply();
        syncUrl();
      }, 140));
    }

    if (priceSelect) {
      priceSelect.value = state.price;
      priceSelect.addEventListener("change", function () {
        state.price = priceSelect.value;
        apply();
        syncUrl();
      });
    }

    if (sortSelect) {
      sortSelect.value = state.sort;
      sortSelect.addEventListener("change", function () {
        state.sort = sortSelect.value;
        apply();
        syncUrl();
      });
    }

    if (clearSearch) {
      clearSearch.addEventListener("click", function () {
        state.q = "";
        if (search) {
          search.value = "";
          search.focus();
        }
        apply();
        syncUrl();
      });
    }

    if (clearAll) {
      clearAll.addEventListener("click", function () {
        state.q = "";
        state.cuisine = "all";
        state.price = "all";
        state.sort = "recommended";
        if (search) search.value = "";
        if (priceSelect) priceSelect.value = "all";
        if (sortSelect) sortSelect.value = "recommended";
        apply();
        syncUrl();
      });
    }

    apply();
  }

  /* Deals directory -------------------------------------------------------- */
  function initDealFilters() {
    var grid = document.getElementById("dealGrid");
    if (!grid) return;

    var cards = $$("[data-deal-card]", grid);
    var search = $("[data-deal-search]");
    var chips = $$("[data-filter]");
    var count = $("[data-deal-count]");
    var empty = $("[data-empty]");
    var clearSearch = $("[data-clear-search]");
    var clearAll = $("[data-clear-filters]");
    var total = cards.length;
    var state = { q: "", cuisine: "all" };

    function apply() {
      var needle = norm(state.q);
      var shown = 0;

      cards.forEach(function (card) {
        var cuisines = (card.dataset.cuisines || "").split(" ");
        var matchQuery = !needle || norm(card.dataset.search).indexOf(needle) !== -1;
        var matchCuisine = state.cuisine === "all" || cuisines.indexOf(state.cuisine) !== -1;
        var visible = matchQuery && matchCuisine;
        card.hidden = !visible;
        if (visible) shown += 1;
      });

      if (count) {
        count.textContent = shown === 1 ? "1 offer" : shown + " offers";
        if (shown !== total) count.textContent += " of " + total;
      }

      if (empty) empty.hidden = shown > 0;

      chips.forEach(function (chip) {
        var active = chip.dataset.filter === state.cuisine;
        chip.classList.toggle("is-active", active);
        chip.setAttribute("aria-pressed", String(active));
      });

      if (clearSearch && search) clearSearch.hidden = !search.value;
    }

    chips.forEach(function (chip) {
      chip.addEventListener("click", function () {
        state.cuisine = chip.dataset.filter || "all";
        apply();
      });
    });

    if (search) {
      search.addEventListener("input", debounce(function () {
        state.q = search.value.trim();
        apply();
      }, 140));
    }

    if (clearSearch) {
      clearSearch.addEventListener("click", function () {
        state.q = "";
        if (search) {
          search.value = "";
          search.focus();
        }
        apply();
      });
    }

    if (clearAll) {
      clearAll.addEventListener("click", function () {
        state.q = "";
        state.cuisine = "all";
        if (search) search.value = "";
        apply();
      });
    }

    apply();
  }

  /* Experiences directory -------------------------------------------------- */
  function initExperienceFilters() {
    var grid = document.getElementById("expGrid");
    if (!grid) return;

    var cards = $$("[data-exp-card]", grid);
    var chips = $$("[data-exp-filter]");
    var count = $("[data-exp-count]");
    var empty = $("[data-exp-empty]");
    var clear = $("[data-clear-exp]");
    var total = cards.length;
    var state = { type: "all" };

    function apply() {
      var shown = 0;
      cards.forEach(function (card) {
        var visible = state.type === "all" || card.dataset.type === state.type;
        card.hidden = !visible;
        if (visible) shown += 1;
      });

      if (count) {
        if (!shown) count.textContent = "No upcoming tables";
        else count.textContent = shown + (shown === 1 ? " upcoming table" : " upcoming");
      }

      if (empty) empty.hidden = shown > 0;

      chips.forEach(function (chip) {
        var active = chip.dataset.expFilter === state.type;
        chip.classList.toggle("is-active", active);
        chip.setAttribute("aria-pressed", String(active));
      });
    }

    chips.forEach(function (chip) {
      chip.addEventListener("click", function () {
        state.type = chip.dataset.expFilter || "all";
        apply();
      });
    });

    if (clear) {
      clear.addEventListener("click", function () {
        state.type = "all";
        apply();
      });
    }

    apply();
  }

  /* Copy deal codes -------------------------------------------------------- */
  function legacyCopy(text) {
    var area = document.createElement("textarea");
    area.value = text;
    area.setAttribute("readonly", "");
    area.style.position = "fixed";
    area.style.top = "-100px";
    area.style.opacity = "0";
    document.body.appendChild(area);
    area.select();
    var ok = false;
    try {
      ok = document.execCommand("copy");
    } catch (err) {
      ok = false;
    }
    document.body.removeChild(area);
    return ok;
  }

  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text).then(function () {
        return true;
      }).catch(function () {
        return legacyCopy(text);
      });
    }
    return Promise.resolve(legacyCopy(text));
  }

  function initCopyCodes() {
    $$("[data-copy]").forEach(function (button) {
      button.addEventListener("click", function () {
        var code = button.dataset.copy;
        copyText(code).then(function (ok) {
          if (!ok) {
            toast("Copy failed. The code is " + code);
            return;
          }
          button.classList.add("is-copied");
          toast("Code " + code + " copied");
          setTimeout(function () {
            button.classList.remove("is-copied");
          }, 2200);
        });
      });
    });
  }

  /* Contact form ----------------------------------------------------------- */
  function initContactForm() {
    var form = $("[data-contact-form]");
    if (!form) return;

    form.addEventListener("submit", function (event) {
      event.preventDefault();
      if (!form.reportValidity()) return;

      var data = new FormData(form);
      var name = String(data.get("name") || "").trim();
      var email = String(data.get("email") || "").trim();
      var topic = String(data.get("topic") || "Website enquiry");
      var message = String(data.get("message") || "").trim();

      var subject = "[Website] " + topic + (name ? " (" + name + ")" : "");
      var body = [
        "Name: " + name,
        "Email: " + email,
        "Topic: " + topic,
        "",
        message,
        "",
        "Sent from the DineCircle website"
      ].join("\n");

      window.location.href = "mailto:" + CONTACT_EMAIL +
        "?subject=" + encodeURIComponent(subject) +
        "&body=" + encodeURIComponent(body);

      toast("Opening your email app with the message ready.");
    });
  }

  /* Newsletter -------------------------------------------------------------- */
  function initNewsletter() {
    var form = $("[data-newsletter]");
    if (!form) return;

    form.addEventListener("submit", function (event) {
      event.preventDefault();
      var field = $("input[type=email]", form);
      var email = field ? String(field.value || "").trim() : "";
      if (!email) {
        toast("Add an email address so we can write back.");
        if (field) field.focus();
        return;
      }

      var subject = "DineCircle newsletter signup";
      var body = [
        "Please add this address to the DineCircle newsletter:",
        email,
        "",
        "Sent from the DineCircle website"
      ].join("\n");

      window.location.href = "mailto:" + CONTACT_EMAIL +
        "?subject=" + encodeURIComponent(subject) +
        "&body=" + encodeURIComponent(body);

      toast("Opening your email app with the signup ready.");
    });
  }

  /* Boot ------------------------------------------------------------------- */
  function boot() {
    initHeader();
    initCityPicker();
    initAppDialog();
    initDates();
    initHours();
    initVenueFilters();
    initDealFilters();
    initExperienceFilters();
    initCopyCodes();
    initContactForm();
    initNewsletter();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();

/* Accessible homepage carousel. The first slide remains usable without JS. */
(function () {
  "use strict";
  var root = document.querySelector('[data-hero-carousel]');
  if (!root) return;
  var slides = Array.from(root.querySelectorAll('[data-hero-slide]'));
  var tabs = Array.from(root.querySelectorAll('[data-hero-goto]'));
  var pause = root.querySelector('[data-hero-pause]');
  var status = root.querySelector('[data-hero-status]');
  var motion = window.matchMedia('(prefers-reduced-motion: reduce)');
  var index = 0, timer, paused = motion.matches, hovering = false, focused = false;
  function schedule() {
    clearTimeout(timer);
    if (!paused && !hovering && !focused && !document.hidden) timer = setTimeout(function () { show(index + 1, false); }, 6500);
  }
  function show(next, announce) {
    index = (next + slides.length) % slides.length;
    slides.forEach(function (slide, i) {
      slide.hidden = i !== index;
      slide.inert = i !== index;
      slide.classList.toggle('is-active', i === index);
      tabs[i].setAttribute('aria-pressed', String(i === index));
    });
    if (announce) status.textContent = slides[index].getAttribute('aria-label');
    schedule();
  }
  function updatePause() {
    pause.setAttribute('aria-pressed', String(paused));
    pause.setAttribute('aria-label', paused ? 'Play slideshow' : 'Pause slideshow');
    pause.textContent = paused ? '▶' : 'Ⅱ';
    schedule();
  }
  tabs.forEach(function (tab, i) { tab.addEventListener('click', function () { show(i, true); }); });
  root.querySelector('[data-hero-prev]').addEventListener('click', function () { show(index - 1, true); });
  root.querySelector('[data-hero-next]').addEventListener('click', function () { show(index + 1, true); });
  pause.addEventListener('click', function () { paused = !paused; updatePause(); });
  root.addEventListener('keydown', function (event) {
    if (event.key === 'ArrowRight' || event.key === 'ArrowLeft') { event.preventDefault(); show(index + (event.key === 'ArrowRight' ? 1 : -1), true); }
  });
  root.addEventListener('mouseenter', function () { hovering = true; schedule(); });
  root.addEventListener('mouseleave', function () { hovering = false; schedule(); });
  root.addEventListener('focusin', function () { focused = true; schedule(); });
  root.addEventListener('focusout', function () { setTimeout(function () { focused = root.contains(document.activeElement); schedule(); }, 0); });
  document.addEventListener('visibilitychange', schedule);
  motion.addEventListener('change', function () { paused = motion.matches; updatePause(); });
  var startX, startY;
  root.addEventListener('touchstart', function (event) { startX = event.changedTouches[0].clientX; startY = event.changedTouches[0].clientY; }, {passive:true});
  root.addEventListener('touchend', function (event) {
    var dx = event.changedTouches[0].clientX - startX, dy = event.changedTouches[0].clientY - startY;
    if (Math.abs(dx) > 60 && Math.abs(dx) > Math.abs(dy)) show(index + (dx < 0 ? 1 : -1), true);
  }, {passive:true});
  updatePause();
})();
