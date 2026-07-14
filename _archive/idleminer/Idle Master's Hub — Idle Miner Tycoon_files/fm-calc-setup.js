/**
 * FM Calculator frontend for the Pages app.
 * Extracted from the Flask SPA and adapted to use Worker APIs.
 */
var FM_DATA_API_URL = '/api/fm-data';
var FM_CALCULATE_API_URL = '/api/calculate';
var fmTableResponse = null;
var methodologyChartData = null;
var methodologyChartInstance = null;
var methodologyChartRendered = false;
var currentChart = null;

function fmOnReady(fn) {
  var ready =
    typeof window !== 'undefined' && window.partialsReady
      ? window.partialsReady
      : Promise.resolve();
  ready.then(fn).catch(fn);
}

function getStaticPath(path) {
  var trimmed = String(path || '').replace(/^\/+/, '');
  if (typeof prefix === 'string') return prefix + trimmed;
  return '/' + trimmed;
}

function trackFmEvent(type, data) {
  if (typeof trackEvent === 'function') trackEvent(type, data || null);
}

function normalizeFmView(viewName) {
  var value = String(viewName || '').toLowerCase();
  if (value === 'skip' || value === 'calculator' || value === 'calc') return 'calculator';
  if (value === 'data' || value === 'barrier-data' || value === 'barriers') return 'data';
  if (value === 'methodology' || value === 'how-it-works' || value === 'how') return 'methodology';
  return 'calculator';
}

function setActiveFmView(viewName, options) {
  viewName = normalizeFmView(viewName);
  options = options || {};
  document.querySelectorAll('[data-fm-view-target]').forEach(function (button) {
    var isActive = button.getAttribute('data-fm-view-target') === viewName;
    button.classList.toggle('active', isActive);
    button.setAttribute('aria-selected', isActive ? 'true' : 'false');
  });

  document.querySelectorAll('[data-fm-view]').forEach(function (panel) {
    panel.classList.toggle('active', panel.getAttribute('data-fm-view') === viewName);
  });

  if (viewName === 'data') {
    trackFmEvent('fm_data_panel_open');
    loadDataTable();
  } else if (viewName === 'methodology') {
    trackFmEvent('fm_methodology_open');
    renderMethodologyChart();
  } else {
    trackFmEvent('fm_calculator_view_open');
  }

  if (options.syncUrl !== false) {
    document.dispatchEvent(new CustomEvent('fm:viewchange', { detail: { view: viewName } }));
  }

  return viewName;
}

function initTooltips() {
  if (typeof bootstrap === 'undefined' || !bootstrap.Tooltip) return;
  var nodes = document.querySelectorAll('#fmcalculator [data-bs-toggle="tooltip"]');
  nodes.forEach(function (node) {
    if (!bootstrap.Tooltip.getInstance(node)) new bootstrap.Tooltip(node);
  });
}

function fetchFmTableData() {
  if (fmTableResponse) return Promise.resolve(fmTableResponse);
  return fetch(FM_DATA_API_URL)
    .then(function (response) {
      if (!response.ok) throw new Error('Network response was not ok');
      return response.json();
    })
    .then(function (result) {
      if (!result.success) throw new Error(result.error || 'Failed to load FM data');
      fmTableResponse = result;
      return result;
    });
}

function loadMethodologyData() {
  if (methodologyChartData) return Promise.resolve(methodologyChartData);
  return fetch(getStaticPath('static/data/fm_methodology.json'))
    .then(function (response) {
      if (!response.ok) throw new Error('Failed to load methodology data');
      return response.json();
    })
    .then(function (data) {
      methodologyChartData = data;
      return data;
    });
}

function populateBarrierOptions() {
  var select = document.getElementById('barrier');
  if (!select) return Promise.resolve();
  return fetchFmTableData()
    .then(function (result) {
      var currentValue = select.value;
      select.innerHTML = result.data
        .map(function (row, index) {
          var selected = currentValue ? row.Name === currentValue : index === 0;
          return (
            '<option value="' +
            escapeHtml(row.Name) +
            '"' +
            (selected ? ' selected' : '') +
            '>' +
            escapeHtml(row.Name) +
            '</option>'
          );
        })
        .join('');
    })
    .catch(function (error) {
      select.innerHTML = '<option value="">Unable to load barriers</option>';
      trackFmEvent('fm_data_load_error', {
        source: 'barrier_options',
        error: String((error && error.message) || error || 'unknown'),
      });
      var results = document.getElementById('results');
      if (results)
        results.innerHTML =
          '<div class="alert alert-danger">❌ ' + escapeHtml(error.message) + '</div>';
    });
}

function validateForm() {
  const barrier = document.getElementById('barrier').value;
  const fcCash = document.getElementById('fcCash').value;
  const customAmount = document.getElementById('customAmount').value;
  const useDefault = document.getElementById('useDefault').checked;
  const edgarOffers = document.getElementById('edgarOffers').value;

  if (!barrier.trim()) {
    alert('Please select a barrier');
    return false;
  }

  if (!fcCash || isNaN(fcCash) || fcCash < 0 || fcCash > 50000) {
    alert('Please enter a valid FC cash amount (0-50,000)');
    return false;
  }

  if (
    !useDefault &&
    (!customAmount || isNaN(customAmount) || customAmount < 0 || customAmount > 50000)
  ) {
    alert('Please enter a valid custom FC amount (0-50,000)');
    return false;
  }

  if (isNaN(edgarOffers) || edgarOffers < 0 || edgarOffers > 100) {
    alert('Please enter a valid Edgar offers amount (0-100)');
    return false;
  }

  return true;
}

function loadDataTable() {
  var statusElement = document.getElementById('dataStatus');
  if (!statusElement) return;
  statusElement.textContent = 'Loading...';
  statusElement.className = 'badge bg-warning text-dark';

  trackFmEvent('fm_data_table_view');

  fetchFmTableData()
    .then(function (result) {
      displayDataTable(result.data, result.columns);
      statusElement.textContent = result.data.length + ' barriers loaded';
      statusElement.className = 'badge bg-success';
    })
    .catch(function (error) {
      document.getElementById('dataTableBody').innerHTML =
        '<tr><td colspan="100%" class="text-center text-danger">❌ ' +
        escapeHtml(error.message) +
        '</td></tr>';
      statusElement.textContent = 'Error';
      statusElement.className = 'badge bg-danger';
      trackFmEvent('fm_data_load_error', {
        source: 'data_table',
        error: String((error && error.message) || error || 'unknown'),
      });
    });
}
