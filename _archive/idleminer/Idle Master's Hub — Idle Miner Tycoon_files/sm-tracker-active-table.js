function smShowActiveTable(smId, options) {
  if (!smActivesData || !smActivesData[smId]) return;
  options = options || {};
  smActiveModalCurrentId = smId;
  var entry = smActivesData[smId];
  var sm = smDataById[smId];
  var st = smGetState(smId);
  var currentRank = st.rank || 0;
  var currentLevel = st.level || 1;
  var maxLvl = sm && sm.maxLevel ? sm.maxLevel : 50;
  // Element scaling now applies to every active type — multiplier (0), percentage
  // (2, Belle/Drethos) and cost-reduction (3, Goodman) — via adjustActiveForEff's
  // per-scaleType branches (decoded in #179). Enable the selector for all SMs.
  var elemBtn = document.getElementById('smActiveElementSelect');
  if (elemBtn) elemBtn.disabled = false;

  // "% increase from current" only has cells to show ABOVE the current rank/level.
  // A fully-maxed SM (R5 + max level) has none, so the toggle is useless there —
  // disable it (greyed, not clickable) and relabel it to say why.
  var maxed = currentRank === 5 && currentLevel === maxLvl;
  var pctBox = document.getElementById('smActivesShowPercent');
  var pctText = document.getElementById('smPctToggleText');
  if (pctBox) pctBox.disabled = maxed;
  if (pctText) {
    pctText.textContent = maxed
      ? 'This SM is maxed, % increase unavailable'
      : 'Show % increase from current';
  }
  var pctLabel = pctBox ? pctBox.closest('label') : null;
  if (pctLabel) {
    pctLabel.style.opacity = maxed ? '0.5' : '';
    pctLabel.style.cursor = maxed ? 'not-allowed' : 'pointer';
  }

  var html = '';

  // In-game description template with all known placeholders substituted.
  var descHtml = smFormatDescription(sm, smId, currentRank, currentLevel);
  var timingHtml = '';
  if (sm && (sm.duration != null || sm.cooldown != null)) {
    var parts = [];
    if (sm.duration != null)
      parts.push(
        '<span class="sm-active-desc-timing-item"><span class="sm-active-desc-timing-label">Active</span> ' +
          smFormatSeconds(sm.duration) +
          '</span>'
      );
    if (sm.cooldown != null)
      parts.push(
        '<span class="sm-active-desc-timing-item"><span class="sm-active-desc-timing-label">Cooldown</span> ' +
          smFormatSeconds(sm.cooldown) +
          '</span>'
      );
    timingHtml = '<div class="sm-active-desc-timing">' + parts.join('') + '</div>';
  }
  if (descHtml || timingHtml) {
    html +=
      '<div class="sm-active-desc">' +
      (descHtml ? '<div class="sm-active-desc-text">' + descHtml + '</div>' : '') +
      timingHtml +
      '<div class="sm-active-desc-hint">Showing Level ' +
      currentLevel +
      ', Rank ' +
      currentRank +
      '</div>' +
      '</div>';
  }

  html +=
    '<div class="sm-active-table-scroll"><table class="sm-active-table"><thead><tr><th>Lv</th>';
  // Per-rank effectiveness badge on each R column: an element can be PE at low
  // ranks and SE once its rankReq is met, so the badge can differ per column.
  var elemActive = !!smActiveModalElement;
  for (var r = 0; r <= 5; r++) {
    var th = 'R' + r;
    if (elemActive && typeof smCompGetEffectivenessAtRank === 'function') {
      var heff = smCompGetEffectivenessAtRank(sm, smActiveModalElement, r);
      if (heff) th += ' <span class="sm-comp-eff sm-comp-eff-' + heff + '">' + heff + '</span>';
    }
    html += '<th>' + th + '</th>';
  }
  html += '</tr></thead><tbody>';

  for (var lv = 1; lv <= maxLvl; lv++) {
    var row = entry.values[lv - 1];
    if (!row) continue;
    html += '<tr>';
    html += '<td class="sm-active-lv">' + lv + '</td>';
    for (var rk = 0; rk <= 5; rk++) {
      var reachable = lv <= SM_RANK_MAX_LEVEL[rk];
      var isCurrent = rk === currentRank && lv === currentLevel;
      var cls = isCurrent
        ? 'sm-active-cell current'
        : reachable
          ? 'sm-active-cell'
          : 'sm-active-cell disabled';
      if (reachable) {
        html += '<td class="' + cls + '">' + smFormatCellHtml(smId, rk, lv) + '</td>';
      } else {
        html += '<td class="' + cls + '"></td>';
      }
    }
    html += '</tr>';
  }

  html += '</tbody></table></div>';

  document.getElementById('smActiveModalTitle').textContent =
    (sm ? sm.name : smId) + ' \u2014 Active Values';
  document.getElementById('smActiveModalBody').innerHTML = html;
  // getOrCreateInstance avoids stacking backdrops when the toggle re-renders
  // an already-open modal (each new Modal() leaks an extra .modal-backdrop).
  bootstrap.Modal.getOrCreateInstance(document.getElementById('smActiveModal')).show();
  if (options.trackView !== false && typeof trackEvent === 'function')
    trackEvent('sm_active_table_view', { id: smId });
}
