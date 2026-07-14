/**
 * Options tab — text size selector and future app settings.
 * Scales the root font-size which proportionally resizes everything using rem,
 * and adjusts card grid columns so fewer/more cards fit per row.
 */
(function () {
  var STORAGE_KEY = 'imhTextSize';
  var DEFAULT_SIZE = '100';
  var VALID_SIZES = ['87.5', '100', '115', '130', '150'];

  // Apply saved text size immediately so there is no flash
  var saved = (function () {
    try {
      var v = localStorage.getItem(STORAGE_KEY);
      if (!v) return DEFAULT_SIZE;
      if (VALID_SIZES.indexOf(v) === -1) {
        localStorage.removeItem(STORAGE_KEY);
        return DEFAULT_SIZE;
      }
      return v;
    } catch (e) {
      return DEFAULT_SIZE;
    }
  })();
  if (saved !== DEFAULT_SIZE) applyTextSize(saved);

  function applyTextSize(pct) {
    document.documentElement.style.fontSize = pct + '%';
    // Remove any previous text-size class, add new one (skip for default)
    var root = document.documentElement;
    root.className = root.className.replace(/\bts-\d+\b/g, '').trim();
    if (pct !== DEFAULT_SIZE) root.classList.add('ts-' + pct.replace('.', ''));
  }

  function trackOptionsEvent(type, data) {
    if (typeof trackEvent === 'function') trackEvent(type, data || null);
  }

  var inited = false;
  function optionsInit() {
    if (inited) return;
    inited = true;
    var container = document.getElementById('textSizeOptions');
    if (!container) return;

    // Restore active button state from saved value
    container.querySelectorAll('.text-size-btn').forEach(function (btn) {
      var size = btn.getAttribute('data-size');
      if (size === saved) btn.classList.add('active');
      else btn.classList.remove('active');

      btn.addEventListener('click', function () {
        container.querySelectorAll('.text-size-btn').forEach(function (b) {
          b.classList.remove('active');
        });
        btn.classList.add('active');
        applyTextSize(size);
        try {
          localStorage.setItem(STORAGE_KEY, size);
        } catch (e) {}
        trackOptionsEvent('options_text_size', { size: size });
      });
    });
  }

  // Lazy-load Options on tab click
  var optionsTab = document.getElementById('options-tab');
  if (optionsTab) {
    optionsTab.addEventListener('shown.bs.tab', function () {
      optionsInit();
      trackOptionsEvent('options_tab_view');
    });
  }
})();
