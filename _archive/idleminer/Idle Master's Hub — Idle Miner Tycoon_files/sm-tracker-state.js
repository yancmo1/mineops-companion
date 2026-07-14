/* Super Manager Tracker
   Shared by the standalone Pages frontend.
   Configurable globals (override BEFORE loading this script):
     SM_DATA_URL, ELEMENT_IMG_BASE, SM_SPRITE_BASE */

// --- Configurable paths (override before loading) ---
if (typeof SM_DATA_URL === 'undefined') var SM_DATA_URL = '/sm-data';
if (typeof ELEMENT_IMG_BASE === 'undefined') var ELEMENT_IMG_BASE = '/static/elements/';
if (typeof SM_SPRITE_BASE === 'undefined') var SM_SPRITE_BASE = '/static/sprites/';
if (typeof SM_FACE_BASE === 'undefined') var SM_FACE_BASE = '/static/faces/';

// Shared SM image URL builders (single home for the rarity-folder + .webp logic
// that was duplicated across ~10 render sites). smSpriteUrl -> full body (main
// cards, tier list); smFaceUrl -> head portrait (small circular thumbnails).
function smRarityFolder(sm) {
  return sm && sm.rarity ? sm.rarity.charAt(0).toUpperCase() + sm.rarity.slice(1) : '';
}
function smSpriteUrl(sm, fallback) {
  return SM_SPRITE_BASE + smRarityFolder(sm) + '/' + (sm.sprite || fallback || sm.name) + '.webp';
}
function smFaceUrl(sm, fallback) {
  return SM_FACE_BASE + smRarityFolder(sm) + '/' + (sm.sprite || fallback || sm.name) + '.webp';
}
if (typeof SM_PASSIVE_TABLES_URL === 'undefined')
  var SM_PASSIVE_TABLES_URL = '/static/data/sm_passive_tables.json';
var smPassiveTables = null;
if (typeof SM_ACTIVES_URL === 'undefined') var SM_ACTIVES_URL = '/static/data/sm_actives.json';

// --- Keyboard activation for interactive spans (WCAG 2.1 AA) ---
if (typeof document !== 'undefined' && document.addEventListener) {
  document.addEventListener('keydown', function (e) {
    if ((e.key === 'Enter' || e.key === ' ') && e.target.getAttribute('role') === 'button') {
      e.preventDefault();
      e.target.click();
    }
    // ESC closes the expanded SM card edit panel. Skip when a Bootstrap modal
    // is open — body.modal-open persists through the fade-out, so this layers
    // ESC presses (first ESC closes modal, second ESC closes the panel).
    if (e.key === 'Escape' && smExpandedId && !document.body.classList.contains('modal-open')) {
      smToggleEdit(smExpandedId);
    }
  });
}

// --- escapeHtml ---
function escapeHtml(text) {
  var div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// --- SM globals ---
var smDefaultData = null;
var smDataById = {};
var smActivesData = null;
var smUserState = {};
var smHasSavedState = false;
var smLoaded = false;
var smExpandedId = null;
var smActivesShowPercent = false;
var smActiveModalCurrentId = null;
var smActiveModalElement = ''; // '' = neutral; session-only, reset on modal close
var q = '\x27'; // single quote helper for inline handlers

var ELEMENT_ABBR = {
  flame: 'Fi',
  frost: 'Fr',
  nature: 'Na',
  wind: 'Wi',
  water: 'Wa',
  dark: 'Da',
  light: 'Li',
  sand: 'Sa',
  order: 'Or',
  chaos: 'Ch',
};
// Values are CSS var() references so element colors follow the active theme
// (light/dark). The browser resolves var() at element render time on inline
// style attributes, so a theme switch repaints these without any JS work.
// chaos uses --el-chaos-text instead of --el-chaos because the latter is
// intentionally kept dark in dark mode for use as a panel background.
var ELEMENT_COLORS = {
  flame: 'var(--el-flame)',
  frost: 'var(--el-frost)',
  nature: 'var(--el-nature)',
  wind: 'var(--el-wind)',
  water: 'var(--el-water)',
  dark: 'var(--el-dark)',
  light: 'var(--el-light)',
  sand: 'var(--el-sand)',
  order: 'var(--el-order)',
  chaos: 'var(--el-chaos-text)',
};
var PASSIVE_NAMES = {
  MIF: 'Mine Income Factor',
  CIF: 'Continent Income',
  CR: 'Upgrade Cost',
  MSUCR: 'Mineshaft Unlock Cost',
  EMSB: 'Movement Speed Boost',
  GWSB: 'Walking Speed Boost',
  MSB: 'Mining Speed Boost',
  MLSB: 'Loading & Movement Speed Boost',
  WMSB: 'Mining & Walking Speed Boost',
  WWLSB: 'Warehouse worker walking and loading speed',
  LMSB: 'Loading & Movement Speed Boost',
  IC: 'Idle Cash',
  BUCR: 'Barrier Unlock Cost',
  EBEAM: 'Elevator Beam',
  MSBEAM: 'Mineshaft Beam',
  BEAM: 'Beam Resources',
};
var PASSIVE_DISPLAY_EPSILON = 1e-9;

function isBeamPassiveType(type) {
  return type === 'EBEAM' || type === 'MSBEAM' || type === 'BEAM';
}

function isScaledMultiplierPassiveType(type) {
  return (
    type === 'MIF' ||
    type === 'CIF' ||
    type === 'IC' ||
    type === 'EMSB' ||
    type === 'MSB' ||
    type === 'MLSB' ||
    type === 'WMSB' ||
    type === 'WWLSB' ||
    type === 'LMSB' ||
    type === 'GWSB'
  );
}

function snapPassiveDelta(delta, decimals, towardBaseline) {
  var factor = Math.pow(10, decimals);
  var scaled = delta * factor;
  if (towardBaseline) {
    return delta >= 0
      ? Math.floor(scaled + PASSIVE_DISPLAY_EPSILON) / factor
      : Math.ceil(scaled - PASSIVE_DISPLAY_EPSILON) / factor;
  }
  return delta >= 0
    ? Math.ceil(scaled - PASSIVE_DISPLAY_EPSILON) / factor
    : Math.floor(scaled + PASSIVE_DISPLAY_EPSILON) / factor;
}

function snapPassiveDisplayValue(value, baseline, decimals, towardBaseline) {
  return baseline + snapPassiveDelta(value - baseline, decimals, towardBaseline);
}

// Format a precise passive value for display: truncate to `dp` decimals and
// strip trailing zeros (and a trailing decimal point). Used for SM tracker
// cards, chrono chips/labels, and the chrono breakdown modal.
function formatPassiveValue(val, dp) {
  if (val == null || isNaN(val)) return '?';
  var factor = Math.pow(10, dp);
  var sign = val < 0 ? -1 : 1;
  var truncated = (sign * Math.floor(Math.abs(val) * factor + PASSIVE_DISPLAY_EPSILON)) / factor;
  var s = truncated.toFixed(dp);
  if (s.indexOf('.') >= 0) {
    s = s.replace(/0+$/, '').replace(/\.$/, '');
  }
  return s;
}

function smCreateState(unlocked) {
  return {
    unlocked: !!unlocked,
    rank: 0,
    level: 1,
    promoted: 0,
    fragments: 0,
    chronoExcluded: false,
    tierlistExcluded: false,
  };
}

function smEnsureState(id, unlocked) {
  if (!smUserState[id]) smUserState[id] = smCreateState(unlocked);
  return smUserState[id];
}

function smGetState(id) {
  return smUserState[id] || smCreateState(false);
}

function smEffectivePromoted(id) {
  return smGetState(id).promoted || 0;
}

// Element-effectiveness scaling for a percent cost-reduction passive (CR,
// MSUCR, BUCR). The game treats the reduction as a remaining-cost multiplier
// and scales the *efficiency gain* (1/m − 1) by the element factor, then
// converts back to a displayed percentage — same shape as the multiplier rule.
// Verified against in-game readings (MSUCR epic+legendary, CR epic).
function adjustReductionSE(v) {
  var m = 1 - v / 100; // remaining-cost multiplier
  if (m <= 0) return v;
  return 100 * (1 - 1 / (1 + (1 / m - 1) * 1.2));
}

function adjustPassiveForEff(p, eff, resolvedValue) {
  var v = resolvedValue != null ? resolvedValue : p.value;
  if (v == null) return null;
  if (isBeamPassiveType(p.type)) {
    return v;
  }
  if (isScaledMultiplierPassiveType(p.type)) {
    if (eff === 'SE') return v * 1.2;
    if (eff === 'PE') return Math.max(1, 1 + (v - 1) * 0.4);
    return Math.max(1, 1 + (v - 1) * 0.1); // NVE
  }
  // Percent cost-reduction passives (CR, MSUCR, BUCR, generic fallback): SE
  // scales the efficiency gain; PE/NVE are flat fractions of the raw percent.
  if (eff === 'SE') return adjustReductionSE(v);
  if (eff === 'PE') return v * 0.4;
  return v * 0.1; // NVE
}

function displayPassiveForEff(p, eff, resolvedValue) {
  var adjusted = adjustPassiveForEff(p, eff, resolvedValue);
  if (adjusted == null) return null;
  if (!isScaledMultiplierPassiveType(p.type)) return adjusted;
  if (eff === 'SE') return snapPassiveDisplayValue(adjusted, 1, 2, false);
  if (eff === 'PE' || eff === 'NVE') return snapPassiveDisplayValue(adjusted, 1, 2, true);
  return adjusted;
}

// Look up passive value from tables; returns null if not available
function smLookupPassiveValue(sm, passive, rank, promoted) {
  if (!smPassiveTables || promoted < 1) return null;
  var table = smPassiveTables.passives[passive.type];
  if (!table) return null; // IC has no table
  var rarityTable = table.tables[sm.rarity];
  if (!rarityTable) return null;
  var rankRow = rarityTable['R' + rank];
  if (!rankRow) return null;
  var maxP = maxPromoForRank(rank);
  var promoIdx = Math.min(promoted, maxP) - 1;
  if (promoIdx < 0 || promoIdx >= rankRow.length) return null;
  return rankRow[promoIdx];
}

// Get the effective passive value for display/calculation
function smGetPassiveValue(sm, passive) {
  var st = smGetState(sm.id);
  var rank = st.rank || 0;
  var promoted = st.promoted || 0;
  // P50 passives can only be unlocked at R5/50p — always show that fixed value
  if (passive.promoReq === 5) {
    var looked = smLookupPassiveValue(sm, passive, 5, 5);
    return looked != null ? looked : passive.value;
  }
  // When no promotions yet, show value at minimum unlock point
  var effPromo = promoted || passive.promoReq;
  var effRank = promoted ? rank : Math.max(rank, minRankForPromo(passive.promoReq));
  var looked = smLookupPassiveValue(sm, passive, effRank, effPromo);
  return looked != null ? looked : passive.value;
}

function smIsReadOnly() {
  return !!(typeof window !== 'undefined' && window.SM_READ_ONLY);
}

function smSaveStateNow() {
  if (smSaveStateTimer) {
    clearTimeout(smSaveStateTimer);
    smSaveStateTimer = null;
  }
  if (smIsReadOnly()) return;
  try {
    localStorage.setItem('smUserState', JSON.stringify(smUserState));
  } catch (e) {}
}

// Coalesce rapid edits (level/rank typing, Max-All, Unlock-All) into a single
// write instead of JSON.stringify-ing the whole state on every change.
// smFlushSaveState() — wired to beforeunload + visibilitychange in smInit —
// guarantees a pending write is never lost. One-time init paths call
// smSaveStateNow() directly so their write is deterministic.
var smSaveStateTimer = null;
function smSaveState() {
  if (smIsReadOnly()) return;
  if (smSaveStateTimer) clearTimeout(smSaveStateTimer);
  smSaveStateTimer = setTimeout(smSaveStateNow, 400);
}

function smFlushSaveState() {
  if (smSaveStateTimer) smSaveStateNow();
}

function smLoadState() {
  try {
    var s = localStorage.getItem('smUserState');
    smHasSavedState = s !== null;
    if (s) smUserState = JSON.parse(s);
    else smUserState = {};
  } catch (e) {
    smUserState = {};
  }
}

function smLoadActivesShowPercent() {
  try {
    smActivesShowPercent = localStorage.getItem('smActivesShowPercent') === 'true';
  } catch (e) {}
}

function smSaveActivesShowPercent() {
  try {
    localStorage.setItem('smActivesShowPercent', smActivesShowPercent ? 'true' : 'false');
  } catch (e) {}
}

// Element picked in the active-values modal is session-only: held in
// smActiveModalElement (declared above) for the life of one modal session and
// reset to neutral when the modal closes. Deliberately NOT persisted to
// localStorage — each view starts neutral.

function smLoadSortOrder() {
  try {
    return localStorage.getItem('smSortOrder') || '';
  } catch (e) {
    return '';
  }
}

function smSaveSortOrder(val) {
  try {
    localStorage.setItem('smSortOrder', val || '');
  } catch (e) {}
}

var SM_FRAG_NEXT = [15, 30, 50, 80, 120]; // fragments needed: R0→R1, R1→R2, ..., R4→R5
var SM_FRAG_UNLOCK = 30;
var SM_FRAG_INPUT_MAX = 500;

function smFragTarget(unlocked, rank) {
  if (!unlocked) return SM_FRAG_UNLOCK;
  if (rank >= 5) return 0;
  return SM_FRAG_NEXT[rank];
}

// Game rules: rank↔level↔promotion constraints
function maxLevelForRank(rank) {
  if (rank <= 1) return 20;
  if (rank === 2) return 30;
  if (rank === 3) return 40;
  return 50; // R4, R5
}
function minRankForLevel(level) {
  if (level <= 20) return 0;
  if (level <= 30) return 2;
  if (level <= 40) return 3;
  return 4; // 41-50
}
function maxPromoForRank(rank) {
  if (rank <= 1) return 1; // R0/R1 can only get p1
  return rank; // R2→p2, R3→p3, R4→p4, R5→p5
}
function minRankForPromo(promo) {
  if (promo <= 1) return 0; // p1 at any rank
  return promo; // p2→R2, p3→R3, etc.
}
function minPromoForLevel(level) {
  // L1-10→p0, L11-20→p1, L21-30→p2, L31-40→p3, L41-50→p4
  return Math.max(0, Math.ceil(level / 10) - 1);
}

// In-game tiebreaker chain (verified 33-of-33 against a real save):
// rarity ↓ → rank ↓ → level ↓ → gameId ↓. Promotion is not a sort key.
// Lifted to module scope so the Tier List unranked pool can reuse it.
var SM_RARITY_ORDER = { legendary: 4, epic: 3, rare: 2, common: 1 };
function smInGameRarityCmp(a, b, sa, sb) {
  var rarityDelta = (SM_RARITY_ORDER[b.rarity] || 0) - (SM_RARITY_ORDER[a.rarity] || 0);
  if (rarityDelta) return rarityDelta;
  if (sb.rank !== sa.rank) return sb.rank - sa.rank;
  if (sb.level !== sa.level) return sb.level - sa.level;
  return (b.gameId || 0) - (a.gameId || 0);
}

// Default stable order: rarity ↓ → name A→Z. Reads no mutable state
// (level/rank/promo), so editing a level never re-orders the grid.
function smStableRarityCmp(a, b) {
  var rarityDelta = (SM_RARITY_ORDER[b.rarity] || 0) - (SM_RARITY_ORDER[a.rarity] || 0);
  if (rarityDelta) return rarityDelta;
  return (a.name || '').localeCompare(b.name || '');
}

function smAutoAdjust(st, field, id) {
  var sm = smDataById[id];
  if (sm && sm.rental) return;

  if (field === 'level') {
    var needed = minRankForLevel(st.level);
    if (st.rank < needed) st.rank = needed;
    var neededP = minPromoForLevel(st.level);
    if (st.promoted < neededP) st.promoted = neededP;
  }
  if (field === 'promoted') {
    var neededR = minRankForPromo(st.promoted);
    if (st.rank < neededR) st.rank = neededR;
    var neededLvl = st.promoted * 10;
    if (neededLvl > 0 && st.level < neededLvl) st.level = neededLvl;
    var needed2 = minRankForLevel(st.level);
    if (st.rank < needed2) st.rank = needed2;
  }
  if (field === 'rank') {
    if (st.rank > 0) st.unlocked = true;
  }
}

function smClampFields(st, id) {
  var sm = smDataById[id];
  var maxLvl = sm && sm.maxLevel ? sm.maxLevel : 50;
  st.rank = Math.max(0, Math.min(5, Math.floor(+st.rank) || 0));
  var rankMaxLvl = maxLevelForRank(st.rank);
  st.level = Math.max(1, Math.min(Math.min(maxLvl, rankMaxLvl), Math.floor(+st.level) || 1));
  var maxP = Math.min(Math.floor(st.level / 10), maxPromoForRank(st.rank));
  var minP = minPromoForLevel(st.level);
  st.promoted = Math.max(minP, Math.min(maxP, Math.floor(+st.promoted) || 0));
  st.fragments = Math.max(0, Math.min(SM_FRAG_INPUT_MAX, Math.floor(+st.fragments) || 0));
  st.unlocked = !!st.unlocked;
  st.chronoExcluded = !!st.chronoExcluded;
  st.tierlistExcluded = !!st.tierlistExcluded;
  if (st.recruitedAt != null && (typeof st.recruitedAt !== 'number' || !isFinite(st.recruitedAt))) {
    delete st.recruitedAt;
  }
  if (
    st.lastAssignedAt != null &&
    (typeof st.lastAssignedAt !== 'number' || !isFinite(st.lastAssignedAt))
  ) {
    delete st.lastAssignedAt;
  }
  // Rentals are always either locked or maxed in-game (you rent them
  // pre-maxed). Once unlocked, force rank/level/promoted to the SM's
  // hard cap so the unlock-checkbox click can't leave them at L1.
  if (sm && sm.rental && st.unlocked) {
    st.rank = 5;
    st.level = maxLvl;
    st.fragments = 0;
    st.promoted = Math.min(5, Math.floor(maxLvl / 10));
  }
}

// Fill in any SM in the roster that doesn't yet have a state entry.
// On a first-ever visit (no stored smUserState key) this preserves the
// current "unlock the whole roster" behavior. For a returning user, newly
// released SMs are added locked-by-default so missing entries read as new
// work rather than retroactively unlocked progress.
function smBootstrapFreshState() {
  if (!smDefaultData) return false;
  var added = false;
  var defaultUnlocked = !smHasSavedState;
  smDefaultData.forEach(function (sm) {
    if (!smUserState[sm.id]) {
      smUserState[sm.id] = smCreateState(defaultUnlocked);
      added = true;
    }
  });
  if (added) smSaveStateNow();
  return added;
}

function smStateHasSavedProgress(st) {
  return (
    !!st.unlocked ||
    (+st.rank || 0) > 0 ||
    (+st.level || 1) > 1 ||
    (+st.promoted || 0) > 0 ||
    (+st.fragments || 0) > 0 ||
    !!st.chronoExcluded ||
    !!st.tierlistExcluded ||
    st.recruitedAt != null ||
    st.lastAssignedAt != null
  );
}

function smSanitizeState() {
  var validIds = {};
  if (smDefaultData)
    smDefaultData.forEach(function (sm) {
      validIds[sm.id] = true;
    });
  for (var id in smUserState) {
    var st = smUserState[id];
    if (typeof st !== 'object' || st === null) {
      delete smUserState[id];
      continue;
    }
    smClampFields(st, id);
    if (smDefaultData && !validIds[id] && !smStateHasSavedProgress(st)) {
      delete smUserState[id];
    }
  }
  smSaveStateNow();
}
