function updateFCAmount() {
  if (userEditedFC) return; // Don't overwrite manual input
  document.getElementById('fcCash').value = getDefaultFC();
}

fmOnReady(function () {
  document.getElementById('premiumPass').addEventListener('change', function () {
    updateFCAmount();
    trackFmEvent('fm_pass_selection', {
      pass_type: 'premium',
      selected: this.checked,
    });
  });

  document.getElementById('elitePass').addEventListener('change', function () {
    updateFCAmount();
    trackFmEvent('fm_pass_selection', {
      pass_type: 'elite',
      selected: this.checked,
    });
  });

  // Track Edgar offers changes
  document.getElementById('edgarOffers').addEventListener('change', function () {
    trackFmEvent('fm_edgar_offers_change', {
      offers_count: parseInt(this.value) || 0,
      total_fc_bonus: (parseInt(this.value) || 0) * 35,
    });
  });

  // Track barrier selection changes
  document.getElementById('barrier').addEventListener('change', function () {
    trackFmEvent('fm_barrier_change', {
      barrier: this.value,
      barrier_text: this.options[this.selectedIndex].text,
    });
  });

  document.getElementById('calcForm').addEventListener('submit', function (e) {
    e.preventDefault();

    if (!validateForm()) {
      return;
    }

    const data = {
      current_barrier: document.getElementById('barrier').value.trim(),
      current_fc_cash: parseInt(document.getElementById('fcCash').value) || 0,
      use_default_fc: document.getElementById('useDefault').checked,
      custom_fc_needed: parseInt(document.getElementById('customAmount').value) || 0,
      premium_pass: document.getElementById('premiumPass').checked,
      elite_pass: document.getElementById('elitePass').checked,
      edgar_offers: parseInt(document.getElementById('edgarOffers').value) || 0,
    };

    // Track calculation start
    trackFmEvent('fm_calculation_submit', {
      barrier: data.current_barrier,
      fc_cash: data.current_fc_cash,
      premium_pass: data.premium_pass,
      elite_pass: data.elite_pass,
      edgar_offers: data.edgar_offers,
    });

    // Show loading state
    document.getElementById('results').innerHTML =
      '<div class="text-center"><div class="spinner-border text-primary" role="status"><span class="visually-hidden">Loading...</span></div></div>';

    fetch(FM_CALCULATE_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
      },
      body: JSON.stringify(data),
    })
      .then((response) => {
        if (!response.ok) {
          return response
            .json()
            .then(function (payload) {
              throw new Error(payload.error || 'Network response was not ok');
            })
            .catch(function () {
              throw new Error('Network response was not ok');
            });
        }
        return response.json();
      })
      .then((result) => {
        if (result.success) {
          showResults(result.result);

          // Track successful calculation
          trackFmEvent('fm_calculation_result', {
            barrier: data.current_barrier,
            furthest_barrier: result.result.furthest_barrier,
            remaining_fc: result.result.remaining_fc,
          });
        } else {
          document.getElementById('results').innerHTML =
            '<div class="alert alert-danger">❌ Error: ' + escapeHtml(result.error) + '</div>';

          // Track calculation error
          trackFmEvent('fm_calculation_error', {
            error: result.error,
          });
        }
      })
      .catch((error) => {
        document.getElementById('results').innerHTML =
          '<div class="alert alert-danger">❌ Network error: ' +
          escapeHtml(error.message) +
          '</div>';

        // Track network error
        trackFmEvent('fm_network_error', {
          error: error.message,
        });
      });
  });
});

function generateProgressionTable(data, hasPremium, hasElite) {
  if (!data.progression_table) return '';

  // Only show columns if user has the passes
  const showPremium = hasPremium;
  const showElite = hasElite;

  let headers = '<tr><th>Barrier</th><th>FC Cost</th><th class="text-success">Base FC</th>';
  if (showPremium) headers += '<th class="text-primary">Premium</th>';
  if (showElite) headers += '<th class="text-warning">Elite</th>';
  headers += '<th class="text-info">Total FC</th><th>Remaining FC</th></tr>';

  const rows = data.progression_table
    .map((row) => {
      const isFurthestReachable = row.is_furthest_reachable && !data.can_complete_all;
      const rowClass = isFurthestReachable ? 'furthest-barrier-row' : '';

      let rowHtml = `<tr class="${rowClass}">`;
      rowHtml += `<td>${escapeHtml(row.barrier)}</td>`;
      rowHtml += `<td>${row.fc_cost.toLocaleString()}</td>`;
      rowHtml += `<td class="${row.base_fc_reward > 0 ? 'text-success fw-bold' : 'text-muted'}">${row.base_fc_reward > 0 ? '+' + row.base_fc_reward.toLocaleString() : '-'}</td>`;

      if (showPremium) {
        if (hasPremium) {
          rowHtml += `<td class="${row.premium_fc_reward > 0 ? 'text-primary fw-bold' : 'text-muted'}">${row.premium_fc_reward > 0 ? '+' + row.premium_fc_reward.toLocaleString() : '-'}</td>`;
        } else {
          rowHtml += `<td class="text-muted">${row.premium_fc_available > 0 ? '+' + row.premium_fc_available.toLocaleString() : '-'}</td>`;
        }
      }

      if (showElite) {
        if (hasElite) {
          rowHtml += `<td class="${row.elite_fc_reward > 0 ? 'text-warning fw-bold' : 'text-muted'}">${row.elite_fc_reward > 0 ? '+' + row.elite_fc_reward.toLocaleString() : '-'}</td>`;
        } else {
          rowHtml += `<td class="text-muted">${row.elite_fc_available > 0 ? '+' + row.elite_fc_available.toLocaleString() : '-'}</td>`;
        }
      }

      rowHtml += `<td class="${row.total_fc_reward > 0 ? 'text-info fw-bold' : 'text-muted'}">${row.total_fc_reward > 0 ? '+' + row.total_fc_reward.toLocaleString() : '-'}</td>`;
      rowHtml += `<td class="${row.remaining_fc < 0 ? 'text-danger fw-bold' : 'text-success'}">${row.remaining_fc.toLocaleString()}</td>`;
      rowHtml += '</tr>';

      return rowHtml;
    })
    .join('');

  return `<div class="mt-3">
              <h6>📋 ${data.can_complete_all ? 'Complete Progression' : 'Progression Table'}:</h6>
              <div class="table-responsive">
                  <table class="table table-sm">
                      <thead>${headers}</thead>
                      <tbody>${rows}</tbody>
                  </table>
              </div>
          </div>`;
}

var currentChart = null;
function renderFCChart(data) {
  if (!data.progression_table || data.progression_table.length === 0) return;
  var canvas = document.getElementById('fcChart');
  if (!canvas) return;
  if (typeof window.Chart === 'undefined') {
    window
      .ensureChartJs()
      .then(function () {
        renderFCChart(data);
      })
      .catch(function () {});
    return;
  }
  if (currentChart) {
    currentChart.destroy();
    currentChart = null;
  }

  var table = data.progression_table;
  var labels = table.map(function (r) {
    return r.barrier.replace(/^FM\\s*/, '').replace(/\\s+/, '-');
  });
  var furthestIdx = -1;
  for (var i = 0; i < table.length; i++) {
    if (table[i].is_furthest_reachable) {
      furthestIdx = i;
      break;
    }
  }

  var startingFc = data.starting_fc || 0;
  var afterCost = table.map(function (r) {
    return r.remaining_fc - r.total_fc_reward;
  });
  var afterReward = table.map(function (r) {
    return r.remaining_fc;
  });

  // Build zigzag: start point, then for each barrier: after-cost, after-reward
  var zigLabels = ['Start'];
  var zigData = [startingFc];
  var zigMeta = [{ type: 'start', idx: -1 }];

  for (var i = 0; i < table.length; i++) {
    zigLabels.push(labels[i] + ' (cost)');
    zigData.push(afterCost[i]);
    zigMeta.push({ type: 'cost', idx: i });

    zigLabels.push(labels[i]);
    zigData.push(afterReward[i]);
    zigMeta.push({ type: 'reward', idx: i });
  }

  var ptRadius = zigMeta.map(function (m) {
    if (m.idx === furthestIdx && m.type === 'reward') return 7;
    return m.type === 'start' ? 4 : 3;
  });
  var ptBg = zigMeta.map(function (m, j) {
    if (m.idx === furthestIdx && m.type === 'reward') return '#ffc107';
    return zigData[j] >= 0 ? '#198754' : '#dc3545';
  });
  var ptBorder = zigMeta.map(function (m, j) {
    if (m.idx === furthestIdx && m.type === 'reward') return '#b8860b';
    return zigData[j] >= 0 ? '#198754' : '#dc3545';
  });

  currentChart = new Chart(canvas, {
    type: 'line',
    data: {
      labels: zigLabels,
      datasets: [
        {
          label: 'FC Balance',
          data: zigData,
          fill: false,
          borderWidth: 2,
          pointRadius: ptRadius,
          pointBackgroundColor: ptBg,
          pointBorderColor: ptBorder,
          pointBorderWidth: 1,
          tension: 0,
          segment: {
            borderColor: function (ctx) {
              var toMeta = zigMeta[ctx.p1DataIndex];
              if (toMeta.type === 'cost') return '#dc3545';
              if (toMeta.type === 'reward') return '#198754';
              return '#6c757d';
            },
          },
        },
        {
          label: 'Zero Line',
          data: new Array(zigLabels.length).fill(0),
          borderColor: 'rgba(220, 53, 69, 0.4)',
          borderDash: [6, 4],
          borderWidth: 1,
          pointRadius: 0,
          fill: false,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
        tooltip: {
          filter: function (item) {
            return item.datasetIndex === 0;
          },
          callbacks: {
            title: function (items) {
              var di = items[0].dataIndex;
              var m = zigMeta[di];
              if (m.type === 'start') return 'Starting Balance';
              return (
                table[m.idx].barrier + (m.type === 'cost' ? ' (after cost)' : ' (after reward)')
              );
            },
            label: function (item) {
              var di = item.dataIndex;
              var m = zigMeta[di];
              if (m.type === 'start') return 'Balance: ' + startingFc.toLocaleString();
              var r = table[m.idx];
              var lines = [];
              if (m.type === 'cost') {
                lines.push('Cost paid: -' + r.fc_cost.toLocaleString());
              } else {
                if (r.total_fc_reward > 0)
                  lines.push('Reward: +' + r.total_fc_reward.toLocaleString());
              }
              lines.push('Balance: ' + zigData[di].toLocaleString());
              return lines;
            },
          },
        },
      },
      scales: {
        x: {
          ticks: {
            maxRotation: 60,
            autoSkip: false,
            callback: function (value, index) {
              if (index === 0) return 'Start';
              if (index % 2 === 0) return zigLabels[index];
              return '';
            },
            font: { size: 10 },
          },
          grid: { display: false },
        },
        y: {
          ticks: {
            callback: function (v) {
              if (Math.abs(v) >= 1000) return (v / 1000).toFixed(0) + 'k';
              return v;
            },
            font: { size: 10 },
          },
        },
      },
    },
  });
}

function formatWaitTime(seconds) {
  if (seconds <= 0) return '0min';
  var h = Math.floor(seconds / 3600);
  var m = Math.round((seconds % 3600) / 60);
  if (h > 0 && m > 0) return h + 'h ' + m + 'min';
  if (h > 0) return h + 'h';
  return m + 'min';
}

function generateWaitToRushCard(wtr) {
  if (!wtr) return '';
  var rows = wtr.breakdown
    .map(function (b) {
      var waitText = formatWaitTime(b.wait_seconds);
      if (b.is_partial && b.full_time_seconds) {
        waitText += ' of ' + formatWaitTime(b.full_time_seconds) + ' \u26A1';
      }
      var costCell;
      if (b.fc_cost_actual === 0) {
        costCell = '<s class="text-muted">' + b.fc_cost_original.toLocaleString() + '</s> 0';
      } else if (b.fc_cost_actual < b.fc_cost_original) {
        costCell =
          '<s class="text-muted">' +
          b.fc_cost_original.toLocaleString() +
          '</s> ' +
          b.fc_cost_actual.toLocaleString();
      } else {
        costCell = b.fc_cost_original.toLocaleString();
      }
      var reward = b.fc_reward > 0 ? '+' + b.fc_reward.toLocaleString() : '-';
      return (
        '<tr><td>' +
        escapeHtml(b.barrier) +
        '</td><td>' +
        waitText +
        '</td><td>' +
        costCell +
        '</td><td>' +
        reward +
        '</td></tr>'
      );
    })
    .join('');
  var totalReward = wtr.breakdown.reduce(function (s, b) {
    return s + b.fc_reward;
  }, 0);
  var totalCost = wtr.breakdown.reduce(function (s, b) {
    return s + b.fc_cost_actual;
  }, 0);
  rows +=
    '<tr class="fw-bold"><td>Total</td><td>' +
    formatWaitTime(wtr.total_wait_seconds) +
    '</td><td>' +
    totalCost.toLocaleString() +
    '</td><td>' +
    (totalReward > 0 ? '+' + totalReward.toLocaleString() : '-') +
    '</td></tr>';
  return (
    '<div style="background:rgba(23,162,184,0.08);border-left:4px solid var(--accent-info);border-radius:10px;padding:12px;margin:8px 0;">' +
    '<h6 style="color:var(--accent-info);margin-bottom:6px;">\u23F1\uFE0F How long until you can rush to the end? <span style="background:#ffc107;color:#000;font-size:0.65em;padding:2px 6px;border-radius:4px;vertical-align:middle;">BETA</span></h6>' +
    '<p style="margin-bottom:4px;"><strong>Wait ~' +
    formatWaitTime(wtr.total_wait_seconds) +
    ', then rush from ' +
    escapeHtml(wtr.rush_from_barrier) +
    '</strong></p>' +
    '<p style="margin-bottom:8px;font-size:0.9em;color:var(--content-text-muted);">Wait through ' +
    wtr.barriers_waited +
    ' barrier' +
    (wtr.barriers_waited !== 1 ? 's' : '') +
    ' to earn enough FC, then instantly skip the rest.</p>' +
    '<details><summary style="cursor:pointer;color:var(--accent-info);font-size:0.9em;">View wait breakdown</summary>' +
    '<div class="table-responsive mt-2"><table class="table table-sm mb-0"><thead><tr><th>Barrier</th><th>Wait</th><th>FC Cost</th><th>FC Reward</th></tr></thead>' +
    '<tbody>' +
    rows +
    '</tbody></table></div></details></div>'
  );
}

function showResults(data) {
  // Get current pass states
  const hasPremium = document.getElementById('premiumPass').checked;
  const hasElite = document.getElementById('elitePass').checked;

  // Check if user cannot afford any barriers
  if (data.furthest_barrier === null) {
    const html = `
                  <div class="alert alert-warning text-center">
                      <h5><i class="bi bi-exclamation-triangle-fill"></i> ⚠️ Insufficient FC</h5>
                      <p><strong>You cannot pass any barriers with your current FC amount.</strong></p>
                      <hr>
                      <div class="row text-start">
                          <div class="col-md-6">
                              <div class="result-item">
                                  <div><strong>FC needed for current barrier:</strong></div>
                                  <div class="result-value">${data.fc_needed_next.toLocaleString()}</div>
                              </div>
                          </div>
                          <div class="col-md-6">
                              <div class="result-item">
                                  <div><strong>FC to Complete FM VII 25:</strong></div>
                                  <div class="result-value">${data.fc_needed_all.toLocaleString()}</div>
                              </div>
                          </div>
                      </div>
                  </div>
                  ${generateWaitToRushCard(data.wait_to_rush)}
                  <div id="fcChartContainer"><canvas id="fcChart"></canvas></div>
                  ${generateProgressionTable(data, hasPremium, hasElite)}
              `;
    document.getElementById('results').innerHTML = html;
    renderFCChart(data);
    return;
  }

  // Check if user can complete all barriers
  if (data.can_complete_all) {
    const html = `
                  <div class="alert alert-success text-center">
                      <h5><i class="bi bi-check-circle-fill"></i></h5>
                      <p><strong>🎉 You can open ALL barriers and complete the entire FM!</strong></p>
                      <hr>
                      <div class="row text-start">
                          <div class="col-md-6">
                              <div class="result-item">
                                  <div><strong>FC remaining after completion:</strong></div>
                                  <div class="result-value">${data.remaining_fc.toLocaleString()}</div>
                              </div>
                          </div>
                          <div class="col-md-6">
                              <div class="result-item">
                                  <div><strong>Silver Mystery Boost Tickets:</strong></div>
                                  <div class="result-value">${data.boost_tickets.toLocaleString()} tickets</div>
                                  <small class="text-muted">Each 600 FC = 1 ticket (min. 1)</small>
                              </div>
                          </div>
                      </div>
                  </div>
                  <div id="fcChartContainer"><canvas id="fcChart"></canvas></div>
                  ${generateProgressionTable(data, hasPremium, hasElite)}
              `;
    document.getElementById('results').innerHTML = html;
    renderFCChart(data);
    return;
  }

  // Normal case - user can afford at least one barrier but not all
  const html = `
              <div class="result-item">
                  <div><strong>Furthest Barrier you can break through:</strong></div>
                  <div class="result-value">${escapeHtml(data.furthest_barrier)}</div>
              </div>
              <div class="result-item">
                  <div><strong>Remaining FC after upgrading to this barrier:</strong></div>
                  <div class="result-value">${data.remaining_fc.toLocaleString()}</div>
              </div>
              <div class="result-item">
                  <div><strong>Additional FC needed for Next Barrier:</strong></div>
                  <div class="result-value">${data.fc_needed_next.toLocaleString()}</div>
              </div>
              <div class="result-item">
                  <div><strong>Additional FC to Complete FM VII 25:</strong></div>
                  <div><small class="text-muted">Includes breaking through FM VII 25 itself • Accounts for FC rewards earned along the way</small></div>
                  <div class="result-value">${data.fc_needed_all.toLocaleString()}</div>
              </div>
              ${generateWaitToRushCard(data.wait_to_rush)}
              <div id="fcChartContainer"><canvas id="fcChart"></canvas></div>
              ${generateProgressionTable(data, hasPremium, hasElite)}
          `;
  document.getElementById('results').innerHTML = html;
  renderFCChart(data);
}
// Make .pass-checkbox containers fully clickable
fmOnReady(function () {
  document.querySelectorAll('.pass-checkbox').forEach(function (container) {
    container.addEventListener('click', function (e) {
      if (e.target.tagName !== 'INPUT') {
        var checkbox = container.querySelector('input[type="checkbox"]');
        checkbox.checked = !checkbox.checked;
        checkbox.dispatchEvent(new Event('change'));
      }
    });
  });
});

function renderMethodologyChart() {
  if (methodologyChartRendered) return;
  var canvas = document.getElementById('methodologyChart');
  if (!canvas) return;

  if (typeof window.Chart === 'undefined') {
    window
      .ensureChartJs()
      .then(function () {
        renderMethodologyChart();
      })
      .catch(function () {});
    return;
  }

  loadMethodologyData()
    .then(function (data) {
      methodologyChartData = data;
      methodologyChartRendered = true;
      var fmColors = {
        'FM I': '#28a745',
        'FM II': '#17a2b8',
        'FM III': '#6f42c1',
        'FM IV': '#fd7e14',
        'FM V': '#dc3545',
        'FM VI': '#0d6efd',
        'FM VII': '#e83e8c',
      };
      var groups = {};
      var groupOrder = ['FM I', 'FM II', 'FM III', 'FM IV', 'FM V', 'FM VI', 'FM VII'];
      var skipPoints = [];
      var steps = 30;

      groupOrder.forEach(function (group) {
        groups[group] = [];
      });

      methodologyChartData.forEach(function (barrier) {
        var points = groups[barrier.fm_group];
        for (var step = 0; step <= steps; step++) {
          var time = barrier.t_before - (barrier.t_before - barrier.t_after) * (step / steps);
          if (time <= 0) continue;
          var fc = barrier.c * Math.pow(time, barrier.p);
          points.push({ x: time / 3600, y: Math.round(fc) });
        }
        skipPoints.push({ x: barrier.t_after / 3600, y: barrier.fc_after, name: barrier.name });
      });

      var datasets = groupOrder.map(function (group) {
        return {
          label: group,
          data: groups[group],
          borderColor: fmColors[group],
          backgroundColor: fmColors[group],
          borderWidth: 2,
          pointRadius: 0,
          fill: false,
          tension: 0,
        };
      });

      datasets.push({
        label: 'Headpiece Skip',
        data: skipPoints.map(function (point) {
          return { x: point.x, y: point.y };
        }),
        type: 'scatter',
        pointRadius: 4,
        pointBackgroundColor: '#ffc107',
        pointBorderColor: '#b8860b',
        pointBorderWidth: 1,
        showLine: false,
      });

      methodologyChartInstance = new Chart(canvas, {
        type: 'line',
        data: { datasets: datasets },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          interaction: { mode: 'nearest', intersect: false },
          plugins: {
            legend: {},
            tooltip: {
              callbacks: {
                title: function (items) {
                  var item = items[0];
                  if (item.dataset.label === 'Headpiece Skip') {
                    return skipPoints[item.dataIndex].name;
                  }
                  return item.dataset.label;
                },
                label: function (item) {
                  var hours = item.parsed.x.toFixed(1);
                  return 'Time: ' + hours + 'h - FC: ' + item.parsed.y.toLocaleString();
                },
              },
            },
          },
          scales: {
            x: {
              type: 'linear',
              title: { display: true, text: 'Remaining Time (hours)' },
              ticks: {
                callback: function (value) {
                  return value + 'h';
                },
              },
            },
            y: {
              title: { display: true, text: 'FC Cost' },
              ticks: {
                callback: function (value) {
                  if (Math.abs(value) >= 1000) return (value / 1000).toFixed(0) + 'k';
                  return value;
                },
              },
            },
          },
        },
      });
    })
    .catch(function (error) {
      methodologyChartRendered = false;
      var container = document.getElementById('methodologyChartContainer');
      if (container) {
        container.innerHTML =
          '<div class="alert alert-danger mb-0">❌ ' + escapeHtml(error.message) + '</div>';
      }
    });
}

// Apply a deep-linked FM sub-view (#fm/data, #fm/methodology) queued by the
// router before the FM module finished loading. 'calculator' is already the
// bootstrap default below, so only non-default targets need switching.
// Sync the URL here (no syncUrl:false): on a cold/slow load the tab's
// shown.bs.tab → syncRouteFromState already fired while fmGetActiveView was
// undefined and rewrote the hash to #fm/calculator. Letting setActiveFmView
// dispatch fm:viewchange re-runs syncRouteFromState now that fmGetActiveView
// exists, restoring the deep-linked #fm/data | #fm/methodology hash.
function fmApplyPendingView() {
  var pending = window.__fmPendingView;
  window.__fmPendingView = null;
  if (pending && pending !== 'calculator') {
    window.fmSetActiveView(pending);
  }
}

// FM is now a lazy tab module (see LAZY_MODULES in init.js). fmInit() runs the
// one-time bootstrap on first FM-tab activation instead of eagerly on page load,
// keeping the FM JS off the first-load critical path. The 'fm_tab_view' event is
// emitted once by the lazy loader's `track` entry, matching every other tab.
var fmInitDone = false;
function fmInit() {
  if (fmInitDone) return;
  fmInitDone = true;
  fmOnReady(function () {
    window.fmSetActiveView = function (viewName, options) {
      return setActiveFmView(viewName, options || {});
    };

    window.fmGetActiveView = function () {
      var activePanel = document.querySelector('[data-fm-view].active');
      return activePanel ? activePanel.getAttribute('data-fm-view') : 'calculator';
    };

    document.querySelectorAll('[data-fm-view-target]').forEach(function (button) {
      button.addEventListener('click', function () {
        var target = button.getAttribute('data-fm-view-target');
        window.fmSetActiveView(target);
      });
    });

    // Methodology accordion open/close. `toggle` does not bubble, so bind each
    // <details> directly (once). Low-frequency → no extra flush pressure.
    document.querySelectorAll('#fmcalculator details').forEach(function (details) {
      details.addEventListener('toggle', function () {
        var summary = details.querySelector('summary');
        trackFmEvent('fm_methodology_section_toggle', {
          open: !!details.open,
          section: summary ? (summary.textContent || '').trim().slice(0, 60) : '',
        });
      });
    });

    initTooltips();
    populateBarrierOptions();
    window.fmSetActiveView('calculator', { syncUrl: false });
    fmApplyPendingView();
  });
}
window.fmInit = fmInit;
