/**
 * Client-side initialization for Idle Master's Hub
 * Batches events and flushes every 30s or on page unload via sendBeacon.
 * Includes domain check, auth heartbeat, and tamper resistance.
 */

// --- One-time cross-origin data migration claim (apex) ---
// After the domain move (idle-masters-hub.pages.dev -> idle-miners.com), a
// visitor arriving from the legacy origin carries ?__mig=<id> pointing at the
// localStorage stashed by the migration page. Claim it once, restore the keys
// (without clobbering any data already on the apex), then reload cleanly so
// every module initialises with the data present.
(function () {
  try {
    var migParams = new URLSearchParams(location.search);
    var migId = migParams.get('__mig');
    if (!migId) return;
    function stripMigParam(reload) {
      migParams.delete('__mig');
      var qs = migParams.toString();
      var clean = location.pathname + (qs ? '?' + qs : '') + location.hash;
      if (reload) location.replace(clean);
      else if (window.history && history.replaceState) history.replaceState(null, '', clean);
    }
    if (localStorage.getItem('imt_migrated_in')) {
      stripMigParam(false);
      return;
    }
    fetch('/api/migrate/claim?id=' + encodeURIComponent(migId))
      .then(function (r) {
        return r.ok ? r.json() : null;
      })
      .then(function (j) {
        if (!j || !j.ok || !j.ls) return;
        Object.keys(j.ls).forEach(function (k) {
          if (localStorage.getItem(k) === null) {
            try {
              localStorage.setItem(k, j.ls[k]);
            } catch (e) {
              /* quota / private mode */
            }
          }
        });
        try {
          localStorage.setItem('imt_migrated_in', '1');
        } catch (e) {
          /* ignore */
        }
        stripMigParam(true); // reload so modules pick up restored data
      })
      .catch(function () {
        /* leave ?__mig= in place so a manual refresh retries within the TTL */
      });
  } catch (e) {
    /* ignore */
  }
})();

(function () {
  // --- Shared asset/data paths for deployed and local pages/ usage ---
  var isDeployed = !location.pathname.includes('/pages/');
  var prefix = isDeployed ? '' : '../';
  if (typeof window.SM_DATA_URL === 'undefined') {
    var dataHost = String(location.hostname || '').toLowerCase();
    var usesWorkerSmData =
      location.protocol !== 'file:' &&
      (dataHost === 'idle-miners.com' ||
        dataHost === 'www.idle-miners.com' ||
        dataHost === 'idle-masters-hub.pages.dev' ||
        dataHost.endsWith('.idle-masters-hub.pages.dev') ||
        dataHost === 'localhost' ||
        dataHost === '127.0.0.1');
    window.SM_DATA_URL = usesWorkerSmData ? '/api/sm-data' : prefix + 'sm_default_data.json';
    window.ELEMENT_IMG_BASE = prefix + 'static/elements/';
    window.SM_SPRITE_BASE = prefix + 'static/sprites/';
    window.SM_FACE_BASE = prefix + 'static/faces/';
    window.SM_PASSIVE_TABLES_URL = prefix + 'static/data/sm_passive_tables.json';
    window.SM_ACTIVES_URL = usesWorkerSmData
      ? '/api/sm-actives'
      : prefix + 'static/data/sm_actives.json';
    window.CHRONO_SCHEDULE_URL = prefix + 'static/data/chrono_schedule.json';
  }

  // SM Tracker needs this persisted flag during the default tab's first render.
  // tierlist.js owns later updates when the Tier List tab is opened.
  if (typeof window.tierlistShowExclusions === 'undefined') {
    try {
      window.tierlistShowExclusions = localStorage.getItem('tierlistShowExclusions') === 'true';
    } catch (e) {
      window.tierlistShowExclusions = false;
    }
  }

  // --- Shareable snapshot view detection ---
  // Format: #share=<8 base62 chars>. Set early so SM tracker init can branch
  // into read-only mode before touching the visitor's localStorage.
  var SHARE_HASH_RE = /^share=([0-9A-Za-z]{8})$/;
  var initialShareMatch = String(location.hash || '')
    .replace(/^#/, '')
    .match(SHARE_HASH_RE);
  if (initialShareMatch) {
    window.SHARE_VIEW = { id: initialShareMatch[1] };
    try {
      // Tag <body> ASAP so the CSS that hides the tab nav doesn't flash. We
      // run before DOMContentLoaded, so document.body may be null — fall back
      // to documentElement which already exists at this point.
      var rootEl = document.body || document.documentElement;
      if (rootEl) rootEl.classList.add('sm-share-readonly');
    } catch (e) {
      /* ignore */
    }
  }

  // --- Lazy-load Chart.js on first use (fm methodology view, sm comparison).
  // Eager loading costs ~70 KB gzipped on every page — unacceptable on mobile.
  var chartJsPromise = null;
  window.ensureChartJs = function () {
    if (typeof window.Chart !== 'undefined') return Promise.resolve();
    if (chartJsPromise) return chartJsPromise;
    chartJsPromise = new Promise(function (resolve, reject) {
      var s = document.createElement('script');
      s.src = 'https://cdn.jsdelivr.net/npm/chart.js@4/dist/chart.umd.min.js';
      s.defer = true;
      s.onload = function () {
        resolve();
      };
      s.onerror = function () {
        chartJsPromise = null;
        reject(new Error('Chart.js load failed'));
      };
      document.head.appendChild(s);
    });
    return chartJsPromise;
  };

  // After first paint settles, warm Chart.js in the background so chart-using
  // tabs feel instant on click. Uses requestIdleCallback to avoid competing
  // with initial SM tab rendering; falls back to setTimeout on browsers that
  // don't support it (Safari).
  function warmChartJs() {
    // Defensive: in non-browser test VMs, document may be a partial mock.
    if (typeof document === 'undefined' || typeof document.createElement !== 'function') return;
    try {
      window.ensureChartJs();
    } catch (e) {
      /* swallow */
    }
  }
  if (typeof window.requestIdleCallback === 'function') {
    window.requestIdleCallback(warmChartJs, { timeout: 4000 });
  } else if (typeof setTimeout === 'function') {
    setTimeout(warmChartJs, 2500);
  }

  // --- Host check: keep the app usable on preview/custom hosts, but only
  // enable analytics on approved production/dev hostnames. ---
  var ALLOWED_HOSTS = [
    'idle-miners.com',
    'www.idle-miners.com',
    'idle-masters-hub.pages.dev',
    'localhost',
    '127.0.0.1',
  ];
  function isAllowedHost(hostname) {
    var host = String(hostname || '').toLowerCase();
    return ALLOWED_HOSTS.indexOf(host) !== -1 || host.endsWith('.idle-masters-hub.pages.dev');
  }

  function disableTracking() {
    window.trackEvent = function () {};
  }

  var isFileProtocol = location.protocol === 'file:';
  var trackingEnabled = !isFileProtocol && isAllowedHost(location.hostname);

  var TAB_ALIASES = {
    sm: 'supermanagers',
    supermanagers: 'supermanagers',
    'super-managers': 'supermanagers',
    progress: 'progresstracker',
    progresstracker: 'progresstracker',
    'progress-tracker': 'progresstracker',
    chrono: 'chronoplanner',
    chronoplanner: 'chronoplanner',
    'chrono-planner': 'chronoplanner',
    tierlist: 'tierlist',
    'tier-list': 'tierlist',
    crystal: 'crystalplanner',
    crystals: 'crystalplanner',
    crystalplanner: 'crystalplanner',
    'crystal-planner': 'crystalplanner',
    essence: 'essenceplanner',
    essenceplanner: 'essenceplanner',
    'essence-planner': 'essenceplanner',
    fm: 'fmcalculator',
    fmcalculator: 'fmcalculator',
    'fm-calculator': 'fmcalculator',
    frontiermine: 'fmcalculator',
    'frontier-mine': 'fmcalculator',
    smcomparison: 'smcomparison',
    'sm-comparison': 'smcomparison',
    'sm-compare': 'smcomparison',
    compare: 'smcomparison',
    stella: 'stellaelevator',
    stellaelevator: 'stellaelevator',
    'stella-elevator': 'stellaelevator',
    'lucky-elevator': 'stellaelevator',
    elevator: 'stellaelevator',
    guide: 'beginnerguide',
    beginnerguide: 'beginnerguide',
    'beginner-guide': 'beginnerguide',
    options: 'options',
    settings: 'options',
    events: 'events',
    'event-calendar': 'events',
    calendar: 'events',
    everdeep: 'everdeep',
    'everdeep-mines': 'everdeep',
    ed: 'everdeep',
  };
  var TAB_BUTTON_IDS = {
    supermanagers: 'sm-tab',
    progresstracker: 'progress-tab',
    chronoplanner: 'chrono-tab',
    tierlist: 'tierlist-tab',
    crystalplanner: 'crystal-tab',
    essenceplanner: 'essence-tab',
    fmcalculator: 'fm-tab',
    smcomparison: 'sm-comparison-tab',
    stellaelevator: 'stella-tab',
    beginnerguide: 'guide-tab',
    options: 'options-tab',
    events: 'events-tab',
    everdeep: 'everdeep-tab',
  };
  var TAB_HASH_NAMES = {
    supermanagers: 'sm',
    progresstracker: 'progress',
    chronoplanner: 'chrono',
    tierlist: 'tierlist',
    crystalplanner: 'crystals',
    essenceplanner: 'essence',
    fmcalculator: 'fm',
    smcomparison: 'sm-comparison',
    stellaelevator: 'stella',
    beginnerguide: 'guide',
    options: 'options',
    events: 'events',
    everdeep: 'everdeep',
  };
  var SHEET_ALIASES = {
    sm: { tab: 'supermanagers' },
    'super-managers': { tab: 'supermanagers' },
    progress: { tab: 'progresstracker' },
    'progress-tracker': { tab: 'progresstracker' },
    chrono: { tab: 'chronoplanner' },
    'chrono-planner': { tab: 'chronoplanner' },
    tierlist: { tab: 'tierlist' },
    'tier-list': { tab: 'tierlist' },
    crystals: { tab: 'crystalplanner' },
    crystal: { tab: 'crystalplanner' },
    'crystal-planner': { tab: 'crystalplanner' },
    essence: { tab: 'essenceplanner' },
    'essence-planner': { tab: 'essenceplanner' },
    fm: { tab: 'fmcalculator', view: 'calculator' },
    'fm-skip': { tab: 'fmcalculator', view: 'skip' },
    'fm-calculator': { tab: 'fmcalculator', view: 'calculator' },
    'fm-data': { tab: 'fmcalculator', view: 'data' },
    'fm-barrier-data': { tab: 'fmcalculator', view: 'data' },
    'fm-methodology': { tab: 'fmcalculator', view: 'methodology' },
    'fm-how-it-works': { tab: 'fmcalculator', view: 'methodology' },
    'sm-comparison': { tab: 'smcomparison' },
    'sm-compare': { tab: 'smcomparison' },
    compare: { tab: 'smcomparison' },
    stella: { tab: 'stellaelevator' },
    'stella-elevator': { tab: 'stellaelevator' },
    'lucky-elevator': { tab: 'stellaelevator' },
    guide: { tab: 'beginnerguide' },
    'beginner-guide': { tab: 'beginnerguide' },
    options: { tab: 'options' },
    settings: { tab: 'options' },
    events: { tab: 'events' },
    calendar: { tab: 'events' },
    'event-calendar': { tab: 'events' },
  };
  var isApplyingRoute = false;
  // Tabs rendered after startup can opt into the same URL routing without adding
  // their route names to this file.
  var routedTabsByHash = {};
  var routedTabsByTab = {};

  function normalizeTabName(value) {
    return TAB_ALIASES[String(value || '').toLowerCase()] || '';
  }

  function normalizeRouteSlug(value) {
    return String(value || '')
      .replace(/^#/, '')
      .trim();
  }

  function getSheetRoute(value) {
    return SHEET_ALIASES[String(value || '').toLowerCase()] || null;
  }

  function isGuideSectionHash(value) {
    return /^guide-[a-z0-9-]+$/.test(String(value || '').toLowerCase());
  }

  function scrollToRouteAnchor(anchorId) {
    if (!anchorId) return;
    var scroll = function () {
      var el = document.getElementById(anchorId);
      if (el && typeof el.scrollIntoView === 'function') {
        el.scrollIntoView({ block: 'start' });
      }
    };
    if (typeof requestAnimationFrame === 'function') {
      requestAnimationFrame(function () {
        setTimeout(scroll, 0);
      });
      return;
    }
    setTimeout(scroll, 0);
  }

  function parseLocationRoute() {
    var rawHash = String(location.hash || '')
      .replace(/^#/, '')
      .trim();
    var hashParts = rawHash ? rawHash.split('/') : [];
    if (hashParts.length === 1) {
      var hashValue = hashParts[0];
      var hashSheet = getSheetRoute(hashValue);
      if (hashSheet) return hashSheet;
      if (isGuideSectionHash(hashValue)) return { tab: 'beginnerguide', anchor: hashValue };
      if (routedTabsByHash[hashValue]) return { tab: routedTabsByHash[hashValue].tab };
    }

    var params = new URLSearchParams(location.search);
    var sheetValue = params.get('sheet');
    var sheet = getSheetRoute(sheetValue);
    if (sheet) return sheet;
    if (isGuideSectionHash(sheetValue)) return { tab: 'beginnerguide', anchor: sheetValue };

    var tab = normalizeTabName(hashParts[0] || params.get('tab'));
    var view = String(hashParts[1] || params.get('view') || '').trim();
    if (!tab) return null;
    if (tab === 'fmcalculator' && !view) view = 'calculator';
    return { tab: tab, view: view };
  }

  function getActiveTabName() {
    var active = document.querySelector('#mainTabs .nav-link.active');
    if (!active) return '';
    var target = (active.getAttribute('data-bs-target') || '').replace(/^#/, '');
    return normalizeTabName(target) || (routedTabsByTab[target] ? target : '');
  }

  function getActiveFmViewName() {
    if (typeof window.fmGetActiveView === 'function') return window.fmGetActiveView();
    return 'calculator';
  }

  function buildRouteHash(tabName, fmView) {
    var hash =
      TAB_HASH_NAMES[tabName] || (routedTabsByTab[tabName] && routedTabsByTab[tabName].hash);
    if (!hash) return '';
    if (tabName === 'fmcalculator') hash += '/' + (fmView || 'calculator');
    return '#' + hash;
  }

  function syncRouteFromState() {
    if (isApplyingRoute) return;
    // Share view keeps #share=<id> in the URL — never overwrite with a tab hash.
    if (typeof window !== 'undefined' && window.SHARE_VIEW) return;
    var activeTab = getActiveTabName();
    var hash = buildRouteHash(activeTab, getActiveFmViewName());
    if (!hash || location.hash === hash) return;
    var url = new URL(location.href);
    url.searchParams.delete('tab');
    url.searchParams.delete('view');
    url.searchParams.delete('sheet');
    url.hash = hash;
    history.replaceState(null, '', url.pathname + url.search + url.hash);
    // Emit a GA4-grade page_view per SPA tab so engagement reports resolve by
    // section. Guarded above by isApplyingRoute → never double-fires on load.
    // window.trackEvent is a safe no-op when tracking is disabled.
    if (typeof window.trackEvent === 'function') {
      window.trackEvent('page_view', { path: '/' + hash.slice(1), page_title: document.title });
    }
  }

  function showTab(tabName) {
    var buttonId =
      TAB_BUTTON_IDS[tabName] || (routedTabsByTab[tabName] && routedTabsByTab[tabName].buttonId);
    if (!buttonId) return false;
    var button = document.getElementById(buttonId);
    if (!button || typeof bootstrap === 'undefined' || !bootstrap.Tab) return false;
    bootstrap.Tab.getOrCreateInstance(button).show();
    return true;
  }

  function applyRouteFromLocation() {
    // Share view: SM tracker stays active by default; do nothing here.
    if (typeof window !== 'undefined' && window.SHARE_VIEW) return;
    var route = parseLocationRoute();
    if (!route) return;
    isApplyingRoute = true;
    try {
      showTab(route.tab);
      if (route.tab === 'fmcalculator') {
        if (typeof window.fmSetActiveView === 'function') {
          window.fmSetActiveView(route.view || 'calculator', { syncUrl: false });
        } else {
          // FM is a lazy module that hasn't loaded yet. Queue the requested view
          // and ensure the module loads; fmInit() applies the pending view once
          // the FM scripts finish. loadTabModule is idempotent (lazyLoaded guard).
          window.__fmPendingView = route.view || 'calculator';
          loadTabModule('fm-tab');
        }
      }
      if (route.anchor) scrollToRouteAnchor(route.anchor);
    } finally {
      isApplyingRoute = false;
    }
  }

  // --- Lazy load tab modules on first activation ---
  // Only SM tracker is eager (default tab + dependency of chrono/tierlist/sm-comparison).
  // FM calculator is lazy too (the 'fm-tab' entry below); it is warmed on idle by
  // scheduleWarmup, and its routing race is resolved via the __fmPendingView queue.
  // Options is eager so saved text-size applies immediately (no flash).
  var LAZY_MODULES = {
    'progress-tab': {
      // Engine first, then the preset stage array it references at runtime.
      src: ['static/js/progress-tracker.js', 'static/js/progress-tracker-stages.js'],
      init: 'progressInit',
      track: 'progress_tab_view',
    },
    'chrono-tab': {
      src: [
        'static/js/chrono-state.js',
        'static/js/chrono-render.js',
        'static/js/chrono-actions.js',
        'static/js/chrono-schedule-init.js',
      ],
      init: 'chronoInit',
      track: 'chrono_tab_view',
    },
    'tierlist-tab': {
      src: 'static/js/tierlist.js',
      init: 'tierlistInit',
      track: 'tierlist_tab_view',
    },
    'crystal-tab': {
      // Formatting helpers first; the planner closure aliases them at load.
      src: ['static/js/crystal-format.js', 'static/js/crystal-planner.js'],
      init: 'crystalInit',
      track: 'crystal_tab_view',
    },
    'essence-tab': {
      // Renderer first: essence-planner.js calls window.essenceRenderResult.
      src: ['static/js/essence-render.js', 'static/js/essence-planner.js'],
      init: 'essenceInit',
      track: 'essence_tab_view',
    },
    'sm-comparison-tab': {
      src: [
        'static/js/sm-comparison-config.js',
        'static/js/sm-comparison-calc.js',
        'static/js/sm-comparison-state.js',
        'static/js/sm-comparison-rows.js',
        'static/js/sm-comparison-render.js',
        'static/js/sm-comparison-bpe.js',
        'static/js/sm-comparison-ui.js',
      ],
      deps: [
        [
          'static/js/chrono-state.js',
          'static/js/chrono-render.js',
          'static/js/chrono-actions.js',
          'static/js/chrono-schedule-init.js',
        ],
      ],
      init: 'smCompInit',
      track: 'smcomp_tab_view',
    },
    'stella-tab': {
      src: [
        'static/js/stella-state.js',
        'static/js/stella-calc.js',
        'static/js/stella-decision.js',
        'static/js/stella-render.js',
        'static/js/stella-bomb.js',
        'static/js/stella-init.js',
      ],
      init: 'stellaInit',
      track: 'stella_tab_view',
    },
    'events-tab': {
      src: 'static/js/events.js',
      init: 'eventsInit',
      track: 'events_tab_view',
    },
    'everdeep-tab': {
      src: 'static/js/everdeep.js',
      init: 'everdeepInit',
      track: 'everdeep_tab_view',
    },
    'fm-tab': {
      src: [
        'static/js/fm-calc-setup.js',
        'static/js/fm-calc-logic.js',
        'static/js/fm-calc-chart-init.js',
      ],
      init: 'fmInit',
      track: 'fm_tab_view',
    },
  };
  var lazyLoaded = {};
  var lazyScriptPromises = {};
  var partialsReadyPromise =
    typeof window !== 'undefined' && window.partialsReady
      ? window.partialsReady.catch(function () {})
      : null;
  var partialsAreReady = !partialsReadyPromise;
  if (partialsReadyPromise) {
    partialsReadyPromise.then(function () {
      partialsAreReady = true;
    });
  }
  // Tabs that use Chart.js — kick the library download in parallel with the
  // tab module so neither blocks the other.
  var CHART_TABS = { 'sm-comparison-tab': true, 'fm-tab': true };
  function loadLazyScript(src) {
    var fullSrc = prefix + src;
    if (lazyScriptPromises[fullSrc]) return lazyScriptPromises[fullSrc];
    lazyScriptPromises[fullSrc] = new Promise(function (resolve, reject) {
      var s = document.createElement('script');
      s.src = fullSrc;
      s.defer = true;
      s.onload = function () {
        resolve();
      };
      s.onerror = function () {
        lazyScriptPromises[fullSrc] = null;
        reject(new Error('Failed to load ' + src));
      };
      document.head.appendChild(s);
    });
    return lazyScriptPromises[fullSrc];
  }

  function markLazyScriptLoaded(src) {
    Object.keys(LAZY_MODULES).forEach(function (id) {
      var moduleSrc = LAZY_MODULES[id].src;
      if (moduleSrc === src || (Array.isArray(moduleSrc) && moduleSrc.indexOf(src) !== -1)) {
        lazyLoaded[id] = true;
      }
    });
  }

  function loadLazyScriptsSequential(srcs) {
    var list = Array.isArray(srcs) ? srcs : [srcs];
    return list.reduce(function (promise, src) {
      return promise.then(function () {
        return loadLazyScript(src);
      });
    }, Promise.resolve());
  }

  function loadTabModule(tabId) {
    if (CHART_TABS[tabId] && typeof window.ensureChartJs === 'function') {
      window.ensureChartJs().catch(function () {});
    }
    var mod = LAZY_MODULES[tabId];
    if (!mod || lazyLoaded[tabId]) return;
    lazyLoaded[tabId] = true;
    var deps = mod.deps || [];
    (partialsReadyPromise || Promise.resolve())
      .then(function () {
        return Promise.all(
          deps.map(function (dep) {
            return loadLazyScriptsSequential(dep).then(function () {
              (Array.isArray(dep) ? dep : [dep]).forEach(markLazyScriptLoaded);
            });
          })
        );
      })
      .then(function () {
        return loadLazyScriptsSequential(mod.src);
      })
      .then(function () {
        var initFn = window[mod.init];
        if (typeof initFn === 'function') initFn();
        if (typeof window.trackEvent === 'function') window.trackEvent(mod.track);
      })
      .catch(function () {
        lazyLoaded[tabId] = false;
      });
  }

  // --- Idle-time warmup: after first paint, parse+compile the FM module so the
  // first switch to the FM tab is instant. FM became a lazy module (LAZY_MODULES
  // ['fm-tab']), so without this its first open would pay download+parse+compile;
  // warming during idle restores the old eager-load snappiness with none of the
  // first-load cost. warmModuleScripts only downloads+compiles — it does NOT call
  // the module's init (which would mount DOM / emit URL+tracking events) and does
  // NOT mark it loaded, so a real tab click still runs loadTabModule() to mount
  // exactly once (scripts resolve instantly from the lazyScriptPromises cache).
  // Only FM is warmed: other lazy modules self-register their own tab-activation
  // listeners on execute, which would double-mount/double-track if warmed early.
  function connectionAllowsWarmup() {
    var nav = typeof navigator !== 'undefined' ? navigator : null;
    if (!nav) return false;
    var c = nav.connection || nav.mozConnection || nav.webkitConnection;
    if (!c) return true; // unknown (desktop / Safari) — allow
    if (c.saveData) return false; // respect Save-Data
    var et = c.effectiveType || '';
    return et !== 'slow-2g' && et !== '2g';
  }

  function warmModuleScripts(tabId) {
    var mod = LAZY_MODULES[tabId];
    if (!mod || lazyLoaded[tabId]) return Promise.resolve();
    var deps = mod.deps || [];
    return (partialsReadyPromise || Promise.resolve())
      .then(function () {
        return deps.reduce(function (p, dep) {
          return p.then(function () {
            return loadLazyScriptsSequential(dep);
          });
        }, Promise.resolve());
      })
      .then(function () {
        return loadLazyScriptsSequential(mod.src);
      })
      .catch(function () {
        /* best-effort warmup */
      });
  }

  function scheduleWarmup() {
    // requestIdleCallback only: keeps warmup off the first-paint path, lets
    // non-rIC browsers fall back to the <link rel=prefetch> bytes already in the
    // HTML, and keeps test VMs (no rIC) from injecting warm scripts.
    if (typeof window === 'undefined' || typeof window.requestIdleCallback !== 'function') return;
    if (typeof document === 'undefined' || typeof document.createElement !== 'function') return;
    if (!connectionAllowsWarmup()) return;
    window.requestIdleCallback(
      function () {
        warmModuleScripts('fm-tab');
      },
      { timeout: 6000 }
    );
  }

  var tabListenersBound = false;
  var pendingPartialTabId = null;
  function showTabButton(tabId) {
    var button = document.getElementById(tabId);
    if (!button || typeof bootstrap === 'undefined' || !bootstrap.Tab) return false;
    bootstrap.Tab.getOrCreateInstance(button).show();
    return true;
  }

  function bindTabButton(button) {
    if (button.__routeTabBound) return;
    button.__routeTabBound = true;
    button.addEventListener(
      'click',
      function (event) {
        if (partialsAreReady) return;
        pendingPartialTabId = button.id;
        event.preventDefault();
        event.stopImmediatePropagation();
      },
      true
    );
    button.addEventListener('shown.bs.tab', syncRouteFromState);
    button.addEventListener('shown.bs.tab', function (e) {
      loadTabModule(e.target.id);
    });
  }

  function bindTabListeners() {
    if (tabListenersBound) return;
    tabListenersBound = true;
    document.querySelectorAll('#mainTabs [data-bs-toggle="tab"]').forEach(bindTabButton);
  }

  function applyRouteAfterPartialsReady() {
    (partialsReadyPromise || Promise.resolve()).then(applyRouteFromLocation);
  }

  window.registerRoutedTab = function (button, options) {
    if (!button || !button.id) return;
    var tab = normalizeRouteSlug(button.getAttribute('data-bs-target'));
    var hash = normalizeRouteSlug(options && options.hash ? options.hash : tab);
    if (!tab || !hash) return;
    var route = { tab: tab, hash: hash, buttonId: button.id };
    routedTabsByTab[tab] = route;
    routedTabsByHash[hash] = route;
    bindTabButton(button);
    applyRouteAfterPartialsReady();
  };
  window.applyRouteFromLocation = applyRouteFromLocation;
  window.showTab = showTab;

  document.addEventListener('DOMContentLoaded', function () {
    bindTabListeners();
    var boot = function () {
      document.addEventListener('fm:viewchange', syncRouteFromState);

      if (pendingPartialTabId) {
        var queuedTabId = pendingPartialTabId;
        pendingPartialTabId = null;
        if (!showTabButton(queuedTabId)) loadTabModule(queuedTabId);
      } else if (
        location.hash ||
        location.search.indexOf('tab=') !== -1 ||
        location.search.indexOf('view=') !== -1 ||
        location.search.indexOf('sheet=') !== -1
      ) {
        applyRouteFromLocation();
      }

      // ---- Theme: 'light' | 'dark' | 'auto'. Header pill toggles light↔dark.
      // Options tab also exposes 'auto' (live-follow OS prefers-color-scheme).
      var THEME_STORAGE_KEY = 'themePreference';
      var darkMq = window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)') : null;
      function readThemePref() {
        try {
          return localStorage.getItem(THEME_STORAGE_KEY) || 'auto';
        } catch (e) {
          return 'auto';
        }
      }
      function resolveTheme(pref) {
        if (pref === 'light' || pref === 'dark') return pref;
        return darkMq && darkMq.matches ? 'dark' : 'light';
      }
      function applyTheme(pref) {
        var resolved = resolveTheme(pref);
        var html = document.documentElement;
        if (html && html.setAttribute) {
          html.setAttribute('data-theme', resolved);
          html.setAttribute('data-bs-theme', resolved);
        }
        var toggleBtn = document.getElementById('themeToggle');
        if (toggleBtn) {
          toggleBtn.setAttribute('aria-checked', resolved === 'dark' ? 'true' : 'false');
          toggleBtn.setAttribute(
            'aria-label',
            resolved === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'
          );
        }
        document.querySelectorAll('.theme-mode-btn').forEach(function (btn) {
          var isActive = btn.getAttribute('data-theme-mode') === pref;
          btn.classList.toggle('active', isActive);
          btn.setAttribute('aria-checked', isActive ? 'true' : 'false');
        });
      }
      function setThemePref(pref) {
        try {
          if (pref === 'auto') localStorage.removeItem(THEME_STORAGE_KEY);
          else localStorage.setItem(THEME_STORAGE_KEY, pref);
        } catch (e) {
          /* private mode — preference will not persist, that's fine */
        }
        applyTheme(pref);
        if (typeof window.trackEvent === 'function') {
          window.trackEvent('theme_change', { mode: pref, applied: resolveTheme(pref) });
        }
      }
      applyTheme(readThemePref());

      var toggleBtn = document.getElementById('themeToggle');
      if (toggleBtn) {
        toggleBtn.addEventListener('click', function () {
          var resolved = resolveTheme(readThemePref());
          setThemePref(resolved === 'dark' ? 'light' : 'dark');
        });
      }
      document.querySelectorAll('.theme-mode-btn').forEach(function (btn) {
        btn.addEventListener('click', function () {
          setThemePref(btn.getAttribute('data-theme-mode'));
        });
      });
      if (darkMq) {
        var onSystemChange = function () {
          if (readThemePref() === 'auto') applyTheme('auto');
        };
        if (darkMq.addEventListener) darkMq.addEventListener('change', onSystemChange);
        else if (darkMq.addListener) darkMq.addListener(onSystemChange);
      }

      // First paint + routing + theme are settled — warm the FM module on idle.
      scheduleWarmup();
    };
    if (partialsReadyPromise) partialsReadyPromise.then(boot);
    else boot();
  });

  window.addEventListener('hashchange', function () {
    // Reload whenever the share-view state implied by the URL no longer matches
    // the currently rendered view. Covers both directions: leaving #share=… via
    // "Make your own", and entering #share=… via browser back/forward.
    var hash = String(location.hash || '').replace(/^#/, '');
    var hashIsShare = SHARE_HASH_RE.test(hash);
    if (!!window.SHARE_VIEW !== hashIsShare) {
      location.reload();
      return;
    }
    applyRouteFromLocation();
  });

  // Skip tracking on local file access or unrecognized hosts — no reliable
  // backend exists there, but the app should still render and route normally.
  if (!trackingEnabled) {
    disableTracking();
    return;
  }

  var queue = [];
  var FLUSH_INTERVAL = 60000;
  var MAX_QUEUE = 200;
  // Time of the previous tracked event. Each new event reports the gap since the
  // last one as engagement_time_msec (clamped 1..30min), giving GA4 a real
  // "average engagement time" instead of a hardcoded constant.
  var lastInteractionTs = Date.now();

  function trackEvent(type, data) {
    if (!type) return;
    var now = Date.now();
    var engage = now - lastInteractionTs;
    if (engage < 1) engage = 1;
    else if (engage > 1800000) engage = 1800000;
    lastInteractionTs = now;
    var d = data;
    if (d && typeof d === 'object') d.__engage = engage;
    else if (d == null) d = { __engage: engage };
    queue.push({ type: type, data: d, ts: now });
    if (queue.length >= MAX_QUEUE) flush();
  }

  // flush() drains in bounded chunks so a single POST never exceeds MAX_QUEUE
  // even if a periodic/unload flush accumulated more — keeps the Worker
  // subrequest budget safe (200 events = 8 GA4 fetches + 1 store write).
  function flush() {
    if (!queue.length) return;
    while (queue.length) {
      var batch = queue.splice(0, MAX_QUEUE);
      var payload = JSON.stringify(batch);
      try {
        if (navigator.sendBeacon) {
          navigator.sendBeacon('/api/sync', new Blob([payload], { type: 'application/json' }));
        } else {
          fetch('/api/sync', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: payload,
            keepalive: true,
          }).catch(function () {});
        }
      } catch (e) {
        /* swallow network errors silently */
      }
    }
  }

  // Flush periodically
  setInterval(flush, FLUSH_INTERVAL);

  // Flush on tab hidden or page unload
  document.addEventListener('visibilitychange', function () {
    if (document.visibilityState === 'hidden') flush();
  });
  window.addEventListener('beforeunload', flush);

  // Auto-track page view. Resolve the section from the URL so GA4 "Pages and
  // screens" sees the real route (#sm, #fm/calculator, …) rather than '/'. This
  // is a deferred script that runs before DOMContentLoaded, so
  // applyRouteFromLocation() has NOT switched tabs yet — reading the active tab
  // here would record the static default for every deep-link landing. Resolve
  // the route from location via parseLocationRoute() instead; fall back to the
  // active tab, then location.pathname.
  var initialRoute = parseLocationRoute();
  var initialRouteHash = initialRoute
    ? buildRouteHash(initialRoute.tab, initialRoute.view)
    : buildRouteHash(getActiveTabName(), getActiveFmViewName());
  trackEvent('page_view', {
    path: initialRouteHash ? '/' + initialRouteHash.slice(1) : location.pathname,
    page_title: document.title,
  });

  // Outbound / CTA / cross-link clicks. Delegated on document so it also covers
  // nodes injected later by partials.js, and scoped to known <a> targets only —
  // this is NOT a blanket button/input auto-tracker. Click-only, so events ride
  // the existing 60s batches and add no extra flush (KV-write) pressure.
  // Help-icon opens are tracked by the planners' own pin handlers
  // (crystal-/essence-planner.js): they know the real open transition, whereas a
  // listener here can only read current display, which hover has already flipped
  // visible on desktop — so it stayed blind for mouse users.
  document.addEventListener(
    'click',
    function (e) {
      var t = e.target;
      var a = t && t.closest ? t.closest('a') : null;
      if (!a) return;
      if (a.classList.contains('tip-btn')) {
        trackEvent('support_cta_click', { provider: 'buymeacoffee' });
      } else if (a.id === 'smSharePreviewLink') {
        trackEvent('sm_share_preview_open', null);
      } else if (a.classList.contains('guide-cross-link')) {
        trackEvent('guide_internal_link_click', {
          target: (a.getAttribute('href') || '').replace(/^#/, ''),
        });
      } else {
        var href = a.getAttribute('href') || '';
        if (/^https?:/i.test(href)) {
          var dest = /discord\./i.test(href)
            ? 'discord'
            : /facebook\./i.test(href)
              ? 'facebook'
              : /reddit\./i.test(href)
                ? 'reddit'
                : 'external';
          var pane = a.closest ? a.closest('.tab-pane') : null;
          trackEvent('outbound_link_click', {
            dest: dest,
            location: pane && pane.id ? pane.id : 'shell',
          });
        }
      }
    },
    true
  );

  // --- Expose globally with tamper resistance ---
  Object.defineProperty(window, 'trackEvent', {
    value: trackEvent,
    writable: false,
    configurable: false,
  });

  // Watchdog: re-register if somehow overridden (e.g. delete + redefine)
  setInterval(function () {
    if (window.trackEvent !== trackEvent) {
      try {
        Object.defineProperty(window, 'trackEvent', {
          value: trackEvent,
          writable: false,
          configurable: false,
        });
      } catch (e) {
        /* already locked */
      }
    }
  }, 5000);
})();
