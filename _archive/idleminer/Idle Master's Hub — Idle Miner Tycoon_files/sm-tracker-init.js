function smLoadData(url, onSuccess, onError) {
  fetch(url)
    .then(function (r) {
      return r.json();
    })
    .then(onSuccess)
    .catch(function () {
      // Fallback for file:// protocol (fetch blocked, XHR may work in Safari)
      try {
        var xhr = new XMLHttpRequest();
        xhr.open('GET', url, true);
        xhr.onload = function () {
          if (xhr.status === 0 || xhr.status === 200) {
            try {
              onSuccess(JSON.parse(xhr.responseText));
            } catch (e) {
              onError(e);
            }
          } else {
            onError(new Error('HTTP ' + xhr.status));
          }
        };
        xhr.onerror = onError;
        xhr.send();
      } catch (e) {
        onError(e);
      }
    });
}

function smInit() {
  if (smLoaded) return;
  if (typeof window !== 'undefined' && window.SHARE_VIEW && window.SHARE_VIEW.id) {
    smShareLoadView(window.SHARE_VIEW.id);
    smWireFilterListeners();
    return;
  }
  smLoaded = true;
  smLoadState();
  smLoadActivesShowPercent();
  var sortSel = document.getElementById('smSort');
  if (sortSel) sortSel.value = smLoadSortOrder();
  function loadPromise(url) {
    return new Promise(function (resolve, reject) {
      smLoadData(url, resolve, reject);
    });
  }
  // Render the grid as soon as the small (~7 KB gzipped) roster file arrives.
  // Actives (~46 KB gzipped) and passive tables (~4 KB gzipped) stream in
  // independently — they're only needed for expanded details / promoted
  // passive numbers, so blocking first paint on them is ~1 s of wasted time.
  loadPromise(SM_DATA_URL)
    .then(function (data) {
      smDefaultData = data;
      smDataById = {};
      smDefaultData.forEach(function (sm) {
        smDataById[sm.id] = sm;
      });
      smSanitizeState();
      if (smBootstrapFreshState()) smSanitizeState();
      smRenderGrid();
    })
    .catch(function () {
      var msg = 'Failed to load SM data';
      if (location.protocol === 'file:') {
        msg =
          "Can\u0027t load data over file:// \u2014 run: node scripts/local-dev.mjs 8000<br>then open <a href='http://127.0.0.1:8000/pages/index.html'>http://127.0.0.1:8000/pages/index.html</a>";
      }
      document.getElementById('smGrid').innerHTML =
        '<div class="col-12 text-center text-danger py-4">' + msg + '</div>';
    });

  loadPromise(SM_ACTIVES_URL)
    .then(function (data) {
      if (data) smActivesData = data;
    })
    .catch(function () {});

  loadPromise(SM_PASSIVE_TABLES_URL)
    .then(function (data) {
      if (!data) return;
      smPassiveTables = data;
      window.dispatchEvent(new CustomEvent('sm-passive-tables-loaded'));
      // Re-render so promoted passive numbers fill in without user action.
      if (smDefaultData) smRenderGrid();
    })
    .catch(function () {});

  smWireFilterListeners();

  var toggleBtn = document.getElementById('smToggleBtn');
  if (toggleBtn) toggleBtn.addEventListener('click', smToggleUnlockAll);
  var maxAllBtn = document.getElementById('smMaxAllBtn');
  if (maxAllBtn) maxAllBtn.addEventListener('click', smToggleMaxAll);

  // % increase tickbox in the active table modal — global setting, persists across modal opens.
  var pctBox = document.getElementById('smActivesShowPercent');
  if (pctBox) {
    pctBox.checked = smActivesShowPercent;
    pctBox.addEventListener('change', function () {
      smActivesShowPercent = !!this.checked;
      smSaveActivesShowPercent();
      if (smActiveModalCurrentId) smShowActiveTable(smActiveModalCurrentId, { trackView: false });
      if (typeof trackEvent === 'function') {
        trackEvent('sm_actives_show_percent_toggle', { on: smActivesShowPercent });
      }
    });
  }

  // Element selector in the active table modal — a Bootstrap dropdown (not a
  // native <select>, whose popup is unreliable inside a focus-trapped modal).
  // Session-only (not persisted); reset to neutral when the modal closes, so each
  // open starts neutral. Rescales the displayed multipliers by the chosen
  // element's effectiveness, evaluated per rank column.
  var elemBtn = document.getElementById('smActiveElementSelect');
  var elemMenu = document.getElementById('smActiveElementMenu');
  if (elemBtn && elemMenu) {
    // Populate once (the "Neutral" item is inline in the HTML).
    if (typeof SM_COMP_ALL_ELEMENTS !== 'undefined' && elemMenu.children.length <= 1) {
      SM_COMP_ALL_ELEMENTS.forEach(function (el) {
        var li = document.createElement('li');
        var b = document.createElement('button');
        b.className = 'dropdown-item';
        b.type = 'button';
        b.setAttribute('data-sm-element', el);
        b.textContent = el.charAt(0).toUpperCase() + el.slice(1);
        li.appendChild(b);
        elemMenu.appendChild(li);
      });
    }
    // Reflect the persisted element on the button label + the active item.
    var smSyncElementPicker = function () {
      var items = elemMenu.querySelectorAll('.dropdown-item');
      for (var i = 0; i < items.length; i++) {
        var on = (items[i].getAttribute('data-sm-element') || '') === smActiveModalElement;
        items[i].classList.toggle('active', on);
        if (on) elemBtn.textContent = items[i].textContent.trim();
      }
    };
    smSyncElementPicker();
    elemMenu.addEventListener('click', function (e) {
      var item = e.target.closest ? e.target.closest('.dropdown-item') : null;
      if (!item) return;
      smActiveModalElement = item.getAttribute('data-sm-element') || '';
      smSyncElementPicker();
      if (smActiveModalCurrentId) smShowActiveTable(smActiveModalCurrentId, { trackView: false });
      if (typeof trackEvent === 'function') {
        trackEvent('sm_active_table_element', {
          id: smActiveModalCurrentId,
          element: smActiveModalElement || 'none',
        });
      }
    });
  }
  var modal = document.getElementById('smActiveModal');
  if (modal)
    modal.addEventListener('hidden.bs.modal', function () {
      smActiveModalCurrentId = null;
      // Element view is session-only — drop it so the next open starts neutral.
      smActiveModalElement = '';
      if (typeof smSyncElementPicker === 'function') smSyncElementPicker();
    });

  // Export/Import
  var exportBtn = document.getElementById('smExportBtn');
  if (exportBtn) exportBtn.addEventListener('click', smExport);
  var importFile = document.getElementById('smImportFile');
  if (importFile)
    importFile.addEventListener('change', function () {
      if (this.files[0]) smImport(this.files[0]);
      this.value = '';
    });

  // Flush any debounced state write before the page is hidden or unloaded so a
  // rapid edit-then-close never loses the last <400 ms of changes. pagehide +
  // visibilitychange cover mobile browsers that don't reliably fire unload.
  if (typeof window !== 'undefined' && window.addEventListener) {
    window.addEventListener('beforeunload', smFlushSaveState);
    window.addEventListener('pagehide', smFlushSaveState);
  }
  if (typeof document !== 'undefined' && document.addEventListener) {
    document.addEventListener('visibilitychange', function () {
      if (document.visibilityState === 'hidden') smFlushSaveState();
    });
  }

  // Share Link
  smShareWireModalOnce();
}

var smFilterListenersWired = false;
// Debounced grid render for the search box. The search input fires `input` on
// every keystroke, and re-rendering 100+ cards per keystroke is what made
// typing feel laggy. Selects/checkboxes fire `change` once per interaction, so
// they stay immediate. (Distinct from the 1000 ms search-tracking debounce
// below — different timer, do not merge.)
var searchRenderTimer = null;
function smRenderGridDebounced() {
  clearTimeout(searchRenderTimer);
  searchRenderTimer = setTimeout(smRenderGrid, 150);
}
function smWireFilterListeners() {
  if (smFilterListenersWired) return;
  smFilterListenersWired = true;
  [
    'smSearch',
    'smFilterArea',
    'smFilterRarity',
    'smFilterElement',
    'smFilterStatus',
    'smFilterIncome',
    'smFilterMSUCR',
    'smFilterPassive',
    'smSort',
  ].forEach(function (id) {
    var el = document.getElementById(id);
    if (!el) return;
    var evt = el.tagName === 'INPUT' ? 'input' : 'change';
    el.addEventListener(evt, id === 'smSearch' ? smRenderGridDebounced : smRenderGrid);
  });
  var sortSaveEl = document.getElementById('smSort');
  if (sortSaveEl)
    sortSaveEl.addEventListener('change', function () {
      smSaveSortOrder(sortSaveEl.value);
    });
  var searchEl = document.getElementById('smSearch');
  var clearBtn = document.getElementById('smSearchClear');
  if (searchEl && clearBtn) {
    searchEl.addEventListener('input', function () {
      clearBtn.style.display = searchEl.value ? '' : 'none';
    });
    clearBtn.addEventListener('click', function () {
      var hadQuery = !!searchEl.value;
      searchEl.value = '';
      clearBtn.style.display = 'none';
      smRenderGrid();
      if (typeof trackEvent === 'function') {
        trackEvent('sm_search_clear', { hadQuery: hadQuery });
      }
    });
  }
  if (typeof trackEvent === 'function') {
    var searchTimer = null;
    if (searchEl)
      searchEl.addEventListener('input', function () {
        clearTimeout(searchTimer);
        searchTimer = setTimeout(function () {
          trackEvent('sm_search', { q: searchEl.value });
        }, 1000);
      });
    [
      'smFilterArea',
      'smFilterRarity',
      'smFilterElement',
      'smFilterStatus',
      'smFilterPassive',
    ].forEach(function (id) {
      var el = document.getElementById(id);
      if (el)
        el.addEventListener('change', function () {
          trackEvent('sm_filter', { filter: id, value: el.value });
        });
    });
    ['smFilterIncome', 'smFilterMSUCR'].forEach(function (id) {
      var el = document.getElementById(id);
      if (el)
        el.addEventListener('change', function () {
          trackEvent('sm_filter', { filter: id, value: el.checked });
        });
    });
    var sortEl = document.getElementById('smSort');
    if (sortEl)
      sortEl.addEventListener('change', function () {
        trackEvent('sm_sort', { value: sortEl.value });
      });
  }
}

var smShareModalWired = false;
function smShareWireModalOnce() {
  if (smShareModalWired) return;
  smShareModalWired = true;
  var shareBtn = document.getElementById('smShareBtn');
  if (shareBtn) shareBtn.addEventListener('click', smShareOpenModal);
  var generateBtn = document.getElementById('smShareGenerateBtn');
  if (generateBtn) generateBtn.addEventListener('click', smShareGenerate);
  var copyBtn = document.getElementById('smShareCopyBtn');
  if (copyBtn) copyBtn.addEventListener('click', smShareCopyLink);
  // Track the share name field and essence toggle as discrete interactions.
  // `change` (not per-keystroke `input`) keeps this write-safe; we record only
  // hasName + length, never the raw text the user typed.
  var shareNameInput = document.getElementById('smShareName');
  if (shareNameInput)
    shareNameInput.addEventListener('change', function () {
      var v = String(shareNameInput.value || '').trim();
      if (typeof trackEvent === 'function') {
        trackEvent('sm_share_name_edited', { hasName: !!v, length: v.length });
      }
    });
  var shareEssenceToggle = document.getElementById('smShareEssenceToggle');
  if (shareEssenceToggle)
    shareEssenceToggle.addEventListener('change', function () {
      if (typeof trackEvent === 'function') {
        trackEvent('sm_share_essence_toggle', { enabled: !!shareEssenceToggle.checked });
      }
    });
  var modalEl = document.getElementById('smShareModal');
  if (modalEl) {
    modalEl.addEventListener('hidden.bs.modal', function () {
      if (typeof trackEvent === 'function') {
        trackEvent('sm_share_modal_dismiss', { shared: smShareSessionDidShare });
      }
    });
  }
}

// Lazy-load SM data on tab click
(function () {
  function smInitAfterPartials() {
    var ready =
      typeof window !== 'undefined' && window.partialsReady
        ? window.partialsReady
        : Promise.resolve();
    return ready.then(function () {
      smInit();
    });
  }

  var smTab = document.getElementById('sm-tab');
  if (smTab)
    smTab.addEventListener('shown.bs.tab', function () {
      smInitAfterPartials().then(function () {
        if (typeof trackEvent === 'function') trackEvent('sm_tab_view');
      });
    });
  if (smTab && smTab.classList.contains('active')) smInitAfterPartials();
})();
