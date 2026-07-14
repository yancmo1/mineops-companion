function smRenderStats() {
  if (!smDefaultData) return;
  var total = smDefaultData.length;
  var unlocked = 0,
    totalStars = 0;
  smDefaultData.forEach(function (sm) {
    var st = smGetState(sm.id);
    if (st.unlocked) {
      unlocked++;
      totalStars += st.rank || 0;
    }
  });
  document.getElementById('smStats').innerHTML =
    'Unlocked: <strong>' +
    unlocked +
    '/' +
    total +
    '</strong> &middot; Stars: <strong>' +
    totalStars +
    '/' +
    total * 5 +
    '</strong>';
  var toggleBtn = document.getElementById('smToggleBtn');
  if (toggleBtn)
    toggleBtn.textContent = unlocked === total && total > 0 ? 'Lock All' : 'Unlock All';
  // Update Max All button based on visible SMs
  var maxAllBtn = document.getElementById('smMaxAllBtn');
  if (maxAllBtn) {
    var visibleIds = smGetVisibleIds();
    var allMaxed =
      visibleIds.length > 0 &&
      visibleIds.every(function (id) {
        var s = smGetState(id);
        var sm = smDataById[id];
        var maxLvl = sm && sm.maxLevel ? sm.maxLevel : 50;
        return s.unlocked && s.rank === 5 && s.level === maxLvl;
      });
    maxAllBtn.textContent = allMaxed ? 'Unmax All' : 'Max All';
  }
}

// --- Active value helpers ---
var SM_RANK_MAX_LEVEL = [20, 20, 30, 40, 50, 50]; // R0-R5

function smFormatPrimary(val, effectType) {
  if (val == null) return '';
  return effectType === 3 ? '-' + val + '%' : effectType === 2 ? val + '%' : '\u00d7' + val;
}

function smFormatUnit(val, unit) {
  if (val == null) return '';
  if (unit === 'x') return '\u00d7' + val;
  if (unit === '%') return val + '%';
  if (unit === '-%') return '-' + val + '%';
  if (unit === 's') return val + 's';
  return '' + val;
}

// Numeric primary value at (rank, level). Element-adjusted (bonus-scaled) when an
// element is selected in the modal AND the active is a standard multiplier
// (type 0); the neutral grid value otherwise. Both the cell display and the
// "% increase from current" suffix read through this, so they stay consistent.
function smActivePrimaryValue(smId, rank, level) {
  if (!smActivesData || !smActivesData[smId]) return null;
  var entry = smActivesData[smId];
  var row = entry.values[level - 1];
  if (!row) return null;
  var val = row[rank];
  if (val == null) return null;
  if (
    smActiveModalElement &&
    typeof smCompGetEffectivenessAtRank === 'function' &&
    typeof adjustActiveForEff === 'function'
  ) {
    var sm = smDataById && smDataById[smId];
    var eff = smCompGetEffectivenessAtRank(sm, smActiveModalElement, rank);
    if (eff) {
      // Scale the RAW (unfloored) base so PE's ×0.6 floors to the in-game cent;
      // fall back to the floor2 grid value when the raw curve isn't available
      // (type 2/3 % SMs, which scale flat/fraction-based off the grid anyway).
      var raw =
        typeof smActiveRawNeutral === 'function' ? smActiveRawNeutral(entry, level, rank) : null;
      if (raw == null) raw = val;
      val = adjustActiveForEff(raw, eff, smActiveScaleType(entry), entry.type);
      // A capped percentage primary (Remedy's cooldown reduction, max 80%) can't
      // be pushed past its cap by SE. Only type-2 primaries cap this way.
      if (entry.type === 2 && typeof smActivePrimaryCap === 'function') {
        var cap = smActivePrimaryCap(entry);
        if (cap != null && val > cap) val = cap;
      }
    }
  }
  return val;
}

function smFormatActive(smId, rank, level) {
  var val = smActivePrimaryValue(smId, rank, level);
  if (val == null) return '';
  return smFormatPrimary(val, smActivesData[smId].type);
}

function smGetPlaceholderValue(entry, placeholder, rank, level, format) {
  var val;
  if (placeholder.source === 'constant') {
    val = placeholder.value;
  } else if (!placeholder.values) {
    return '';
  } else {
    var row = placeholder.values[level - 1];
    if (!row) return '';
    val = row[rank];
  }
  if (val == null) return '';
  // In description substitution (format === 'inline'), drop the "s" suffix
  // for seconds because the surrounding template text already says "seconds".
  if (format === 'inline' && placeholder.unit === 's') return '' + val;
  return smFormatUnit(val, placeholder.unit);
}

function smActiveColorClass(index) {
  // index 0 = primary, 1+ = secondary placeholders. Colors match the description
  // spans so the user can trace a single value's progression down the column.
  return 'sm-active-color-' + Math.min(index, 4);
}

function smFormatCellHtml(smId, rank, level) {
  if (!smActivesData || !smActivesData[smId]) return '';
  var entry = smActivesData[smId];
  var st = smGetState(smId);
  var curLv = st && st.level >= 1 ? st.level : null;
  var curRk = st && st.rank >= 0 ? st.rank : null;
  // Reachable upgrade target: rank and level can only go up. Skip the current
  // cell itself (it's the baseline, +0% would be noise).
  var showPct =
    smActivesShowPercent &&
    curLv != null &&
    curRk != null &&
    rank >= curRk &&
    level >= curLv &&
    !(rank === curRk && level === curLv);

  var parts = [];
  var primary = smFormatActive(smId, rank, level);
  if (primary) {
    var primarySuffix = '';
    if (showPct && entry.values) {
      // Element-adjusted values (the same numbers shown in the cells) so the
      // "% increase from current" is computed on what the user sees.
      var basePrim = smActivePrimaryValue(smId, curRk, curLv);
      var thisPrim = smActivePrimaryValue(smId, rank, level);
      primarySuffix = smFormatPercentSuffix(basePrim, thisPrim, entry.type);
    }
    parts.push(
      '<span class="' +
        smActiveColorClass(0) +
        '">' +
        escapeHtml(primary) +
        escapeHtml(primarySuffix) +
        '</span>'
    );
  }
  if (entry.placeholders) {
    entry.placeholders.forEach(function (p) {
      // Skip constants — they don't change with level/rank, so showing them
      // in every cell is redundant. They still appear in the description above.
      if (p.source === 'constant') return;
      var v = smGetPlaceholderValue(entry, p, rank, level);
      if (!v) return;
      var phSuffix = '';
      if (showPct && p.values) {
        var basePh = p.values[curLv - 1] && p.values[curLv - 1][curRk];
        var thisPh = p.values[level - 1] && p.values[level - 1][rank];
        phSuffix = smFormatPercentSuffix(basePh, thisPh, entry.type);
      }
      parts.push(
        '<span class="' +
          smActiveColorClass(p.index) +
          '">' +
          escapeHtml(v) +
          escapeHtml(phSuffix) +
          '</span>'
      );
    });
  }
  return parts.join(' <span class="sm-active-cell-sep">|</span> ');
}

function smFormatPercentSuffix(base, val, effectType) {
  if (typeof base !== 'number' || typeof val !== 'number') return '';
  if (!isFinite(base) || !isFinite(val) || base <= 0) return '';
  if (val === base) return ' (+0%)';
  var pct;
  if (effectType === 3) {
    // Cost-reduction ("needs") active: value is a reduction % on a 0–100 scale.
    // Real gain = ratio of remaining fractions, since throughput ∝ 1/remaining.
    if (100 - val <= 0) return ''; // over-cap / div-by-zero safety
    pct = ((100 - base) / (100 - val) - 1) * 100;
  } else {
    pct = ((val - base) / base) * 100;
  }
  if (!isFinite(pct) || pct < 0) return '';
  return ' (+' + smFormatPercentNumber(pct) + '%)';
}

// Max 3 significant-position digits, trailing zeros stripped:
//   9.512 -> "9.51", 10.534 -> "10.5", 120 -> "120",
//   5.50 -> "5.5", 5.00 -> "5", 0.05 -> "0.05".
function smFormatPercentNumber(p) {
  var abs = Math.abs(p);
  var decimals;
  if (abs >= 100) decimals = 0;
  else if (abs >= 10) decimals = 1;
  else decimals = 2;
  var s = p.toFixed(decimals);
  if (s.indexOf('.') !== -1) {
    s = s.replace(/0+$/, '').replace(/\.$/, '');
  }
  return s;
}

function smFormatDescription(sm, smId, rank, level) {
  if (!sm || !sm.descriptionLong) return '';
  var text = escapeHtml(sm.descriptionLong);
  var entry = smActivesData ? smActivesData[smId] : null;

  // Substitute {0} with the current primary value, color-coded to match the
  // {0}-column in the grid so the user can trace the same value across both.
  var primaryStr = entry ? smFormatActive(smId, rank, level) : '';
  if (primaryStr) {
    text = text.replace(
      /\{0\}/g,
      '<span class="sm-active-desc-primary ' +
        smActiveColorClass(0) +
        '">' +
        escapeHtml(primaryStr) +
        '</span>'
    );
  }

  // Substitute each known placeholder. Constants render as plain bold text
  // (they don't scale with level/rank); level-scaling values get the same
  // color as their column in the grid.
  if (entry && entry.placeholders) {
    entry.placeholders.forEach(function (p) {
      var val = smGetPlaceholderValue(entry, p, rank, level, 'inline');
      if (!val) return;
      var re = new RegExp('\\{' + p.index + '\\}', 'g');
      var cls;
      if (p.source === 'constant') {
        cls = 'sm-active-desc-constant';
      } else {
        cls = 'sm-active-desc-secondary ' + smActiveColorClass(p.index);
      }
      text = text.replace(re, '<span class="' + cls + '">' + escapeHtml(val) + '</span>');
    });
  }

  // Any remaining {N} placeholders — we don't have a recipe for them yet.
  text = text.replace(/\{(\d+)\}/g, '<span class="sm-active-desc-placeholder">{$1}</span>');
  return text;
}

function smFormatSeconds(seconds) {
  if (seconds == null) return '';
  var s = Math.round(seconds);
  if (s < 60) return s + 's';
  var m = Math.floor(s / 60);
  var rem = s % 60;
  if (m < 60) return rem ? m + 'm ' + rem + 's' : m + 'm';
  var h = Math.floor(m / 60);
  var mr = m % 60;
  return mr ? h + 'h ' + mr + 'm' : h + 'h';
}
