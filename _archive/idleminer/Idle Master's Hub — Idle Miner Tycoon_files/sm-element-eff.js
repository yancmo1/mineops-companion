/* Shared element-effectiveness math for Super Manager actives.

   Eager (loaded with the SM tracker) so the active-values modal can scale its
   multipliers by element WITHOUT the lazily-loaded SM Comparison module. The
   comparison files (loaded later, on their own tab) reuse these same globals —
   this is the single source of truth for the element factors, the element list,
   the per-rank effectiveness scan, and the active bonus-scaling formula.

   Defines globals only (no top-level calls), so it is safe to load before
   smDataById / smActivesData exist. */

/* Per-element active-effectiveness modifiers, from the live `elementBalancing`
   config (activeSkillCorrelationValueMapping: buff/SE 1.5, weak/PE 0.6, super
   weak/NVE 0.2). The SHAPE they apply with depends on the effect type and on
   buff (SE, mod>=1) vs debuff (PE/NVE, mod<1) — see adjustActiveForEff. */
var SM_COMP_ELEMENT_FACTORS = { SE: 1.5, PE: 0.6, NVE: 0.2 };

/* `superManagerStrengthFactor` from elementBalancing (the `K` in the decremental
   buff formula). Currently 1 in live config. */
var SM_COMP_SM_STRENGTH_FACTOR = 1;

/* All 10 elements, ordered to match the element <select> dropdowns. */
var SM_COMP_ALL_ELEMENTS = [
  'flame',
  'frost',
  'nature',
  'wind',
  'water',
  'dark',
  'light',
  'sand',
  'order',
  'chaos',
];

/* Clamp a rank to the valid 0..5 range (floor + bound). */
/* Max cap on a percentage active's primary value, read from a '%' max placeholder
   (e.g. Remedy Rose's `_maxCooldownReduction` = 80 — "(max {3})" in her desc). The
   element-scaled primary can't exceed it: SE 60.75% → 91.12% clamps to 80. Only
   type-2 (percentage) primaries are capped this way; type-0 SMs with their own
   `max%` placeholders (Hatori/Cervina/Chance) cap a SECONDARY effect, not the
   shown multiplier, so callers must gate on type === 2. Returns the cap or null. */
function smActivePrimaryCap(entry) {
  var ph = entry && entry.placeholders;
  if (!ph) return null;
  for (var i = 0; i < ph.length; i++) {
    var f = (ph[i].field || '').toLowerCase();
    if (f.indexOf('max') !== -1 && ph[i].unit === '%' && typeof ph[i].value === 'number') {
      return ph[i].value;
    }
  }
  return null;
}

function smCompClampRank(v) {
  var n = Math.floor(Number(v));
  if (!isFinite(n)) return 0;
  if (n < 0) n = 0;
  if (n > 5) n = 5;
  return n;
}

/* Effectiveness of `element` against `sm` at a given rank. Returns
   'SE' | 'PE' | 'NVE', or '' when the SM has no elements. Rank-gated: an element
   that is SE with rankReq=3 reads as PE at ranks 0-2 and SE at 3-5, so the same
   table can flip PE→SE as the rank column increases — the whole point of scaling
   per-rank. */
function smCompGetEffectivenessAtRank(sm, element, rank) {
  if (!sm || !element || !sm.elements) return '';
  var effectiveRank = smCompClampRank(rank);
  var best = 'NVE';
  for (var i = 0; i < sm.elements.length; i++) {
    var el = sm.elements[i];
    if (el.element !== element) continue;
    if (el.effectiveness === 'SE' && el.rankReq <= effectiveRank) return 'SE';
    if (el.effectiveness === 'PE') best = 'PE';
    if (el.effectiveness === 'SE' && el.rankReq > effectiveRank) best = 'PE';
  }
  return best;
}

/* Raw (unfloored) neutral active value for an SM at level/rank, reconstructed
   from baseRaw + rankInc using the SAME per-type formula the generator floors for
   the `values` grid. The element calc scales THIS raw value (not the floor2'd
   grid) so the scaled cent matches the game — e.g. Archibald PE raw 25.5871 →
   ×15.75 vs grid 25.58 → ×15.74; Belle SE raw 59.7935% → 89.69 vs grid 59.79 →
   89.68. Returns null when there's no raw curve (legacy entry); callers fall back
   to the floor2 grid value. */
function smActiveRawNeutral(aEntry, level, rank) {
  if (!aEntry || !aEntry.baseRaw || !aEntry.rankInc) return null;
  var b = aEntry.baseRaw[level - 1];
  if (b == null) return null;
  var ri = aEntry.rankInc[rank];
  ri = ri == null ? 0 : ri;
  if (aEntry.type === 3) {
    var bp = b * 100;
    return bp + ri * (100 - bp); // decremental: base% + ri×(100−base%)
  }
  if (aEntry.type === 2) return b * (1 + ri) * 100; // percentage
  return b * (1 + ri); // multiplier
}

/* Floor to 2 decimals (the game floors the active display — 12.598 shows as
   ×12.59). 1e-4 epsilon strips float32 drift (matches generate_sm_actives.floor2). */
function smFloor2(x) {
  return Math.floor(x * 100 + 1e-4) / 100;
}

/* Element-scaling type for an active (the game's ActiveEffectFactorType
   EffectType, mapped 0 multiplier / 2 percentage / 3 cost-reduction). SEPARATE
   from `type` (display): Lei Na & Remedy display as % (type 2) but SCALE as
   multipliers (scaleType 0). Falls back to the display type for legacy entries. */
function smActiveScaleType(entry) {
  if (!entry) return 0;
  return entry.scaleType != null ? entry.scaleType : entry.type;
}

/* Decremental (cost-reduction) BUFF — SE strengthens the reduction toward a 99%
   cap. Decompiled DecrementalBuff (v5.58.0): with s = pct/100, e = modifier,
   K = SM_COMP_SM_STRENGTH_FACTOR,
     reduction = min(0.99, (1-s)·(1 - 1/((e-1)·s·K + 1)) + s)
   At e=1 it returns s (neutral). Input/output are percentages (e.g. 95.4). */
function smDecrementalBuffPct(pct, m) {
  var s = pct / 100;
  var denom = (m - 1) * s * SM_COMP_SM_STRENGTH_FACTOR + 1;
  if (denom <= 0) return pct;
  var r = (1 - s) * (1 - 1 / denom) + s;
  return Math.min(0.99, r) * 100;
}

/* Element-effectiveness scaling for a Super Manager *active*. Mirrors the
   decompiled GetSuperManagerActiveElementalStrength(skill, mod, effectType)
   (v5.58.0) — the shape is per effect type AND per buff (SE, mod>=1) vs debuff
   (PE/NVE, mod<1). `effType` is the sm_actives `type` field (0 multiplier /
   2 percentage / 3 cost-reduction); modifiers SE 1.5 / PE 0.6 / NVE 0.2.
     - multiplier  SE   : skill × mod                 (flat; MultiplierBuff)
     - multiplier  PE/NVE: (s+1) − max(1, s−(s-1)·mod) (MultiplierDebuff; = s for
                            s≤1, = 1+(s-1)·mod for s>1)
     - percentage  any  : value × mod                 (flat; Percentage Buff=Debuff)
     - decremental PE/NVE: value × mod                (flat; DecrementalDebuff)
     - decremental SE   : min(0.99, efficiency form)  (DecrementalBuff)
   PE/NVE multipliers verified against in-game readings; the rest are binary-
   confirmed. Feed type-0 the RAW base (smActiveRawNeutral) so the floored cent
   matches the game; type 2/3 are flat/fraction-based and precise off the grid. */
function adjustActiveForEff(value, eff, scaleType, displayType) {
  var m = SM_COMP_ELEMENT_FACTORS[eff];
  if (m == null || value == null) return value;
  if (scaleType === 2) return smFloor2(value * m); // percentage: flat, scale-invariant
  if (scaleType === 3) {
    if (m >= 1) return smFloor2(smDecrementalBuffPct(value, m)); // cost-reduction SE
    return smFloor2(value * m); // cost-reduction PE/NVE: flat
  }
  // Multiplier scaling. Internal skill is the raw multiplier; a %-DISPLAY
  // multiplier (Lei Na/Remedy, "collects X% more") shows skill×100, so convert
  // in and back out — the formula is NOT scale-invariant.
  var pct = displayType === 2;
  var s = pct ? value / 100 : value;
  // Decompiled MultiplierBuff = s×mod (flat). MultiplierDebuff =
  // (s+1) − max(1, s−(s−1)×mod): for s≥1 that's 1+(s−1)×mod (the usual bonus
  // shape); for s<1 it returns s unchanged, so a sub-1× active (a small "% more")
  // is untouched by PE/NVE but still amplified by SE.
  var scaled = m >= 1 ? s * m : s + 1 - Math.max(1, s - (s - 1) * m);
  return smFloor2(pct ? scaled * 100 : scaled);
}
