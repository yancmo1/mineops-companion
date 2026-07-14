function smRenderGrid() {
  if (!smDefaultData) return;
  var search = (document.getElementById('smSearch').value || '').toLowerCase();
  var fArea = document.getElementById('smFilterArea').value;
  var fRarity = document.getElementById('smFilterRarity').value;
  var fElement = document.getElementById('smFilterElement').value;
  var fStatus = document.getElementById('smFilterStatus').value;
  var fIncome = document.getElementById('smFilterIncome').checked;
  var fMSUCR = document.getElementById('smFilterMSUCR').checked;
  var fPassive = document.getElementById('smFilterPassive').value;

  var filtered = [];
  smDefaultData.forEach(function (sm) {
    var st = smGetState(sm.id);
    if (search && sm.name.toLowerCase().indexOf(search) === -1) return;
    if (fArea && sm.area !== fArea) return;
    if (fRarity && sm.rarity !== fRarity) return;
    if (fElement) {
      var hasEl = sm.elements.some(function (e) {
        return e.element === fElement && e.effectiveness === 'SE';
      });
      if (!hasEl) return;
    }
    if (fStatus === 'unlocked' && !st.unlocked) return;
    if (fStatus === 'locked' && st.unlocked) return;
    if (fStatus === 'chrono-included' && st.chronoExcluded) return;
    if (fStatus === 'chrono-excluded' && !st.chronoExcluded) return;
    if (fStatus === 'tl-included' && st.tierlistExcluded) return;
    if (fStatus === 'tl-excluded' && !st.tierlistExcluded) return;
    if (
      fIncome &&
      !sm.passives.some(function (p) {
        return p.type === 'MIF' || p.type === 'CIF';
      })
    )
      return;
    if (
      fMSUCR &&
      !sm.passives.some(function (p) {
        return p.type === 'MSUCR';
      })
    )
      return;
    if (
      fPassive &&
      !sm.passives.some(function (p) {
        return p.type === fPassive;
      })
    )
      return;
    filtered.push(sm);
  });

  var sortVal = document.getElementById('smSort').value;
  // Tiers shared by all in-game-style sorts. Locked rentals go between
  // unlocked and fully-locked SMs (the game does this for Sir Henry, etc).
  function tier(sm, st) {
    if (st.unlocked) return 0;
    if (sm.rental) return 1;
    return 2;
  }
  var inGameRarityCmp = smInGameRarityCmp;
  function primarySE(sm) {
    // Catalog's first SE entry, used as the bucket key.
    if (!sm || !sm.elements) return null;
    for (var i = 0; i < sm.elements.length; i++) {
      if (sm.elements[i].effectiveness === 'SE') return sm.elements[i];
    }
    return null;
  }
  var elementOrder = {
    nature: 1,
    frost: 2,
    flame: 3,
    light: 4,
    dark: 5,
    wind: 6,
    sand: 7,
    water: 8,
    chaos: 9,
    order: 10,
  };
  var areaOrder = { mineshaft: 1, elevator: 2, warehouse: 3 };
  var SM_FRAG_NEXT_LOCAL =
    typeof SM_FRAG_NEXT !== 'undefined' ? SM_FRAG_NEXT : [15, 30, 50, 80, 120];

  if (sortVal === 'level-desc') {
    filtered.sort(function (a, b) {
      var sa = smGetState(a.id),
        sb = smGetState(b.id);
      return sb.unlocked - sa.unlocked || sb.level - sa.level;
    });
  } else if (sortVal === 'level-asc') {
    filtered.sort(function (a, b) {
      var sa = smGetState(a.id),
        sb = smGetState(b.id);
      return sb.unlocked - sa.unlocked || sa.level - sb.level;
    });
  } else if (sortVal === 'element') {
    // By Element: bucket by catalog's first SE element. Within each element
    // bucket, SMs whose first SE has rankReq=0 (default-active for that
    // element) come before those whose first SE is rank-gated (rankReq>0).
    // Beyond that, fall through to the standard rarity/rank/level/gameId.
    filtered.sort(function (a, b) {
      var sa = smGetState(a.id),
        sb = smGetState(b.id);
      var ta = tier(a, sa),
        tb = tier(b, sb);
      if (ta !== tb) return ta - tb;
      if (ta === 0) {
        var pa = primarySE(a),
          pb = primarySE(b);
        var ea = pa ? elementOrder[pa.element] || 99 : 99;
        var eb = pb ? elementOrder[pb.element] || 99 : 99;
        if (ea !== eb) return ea - eb;
        var ra = pa && pa.rankReq === 0 ? 0 : 1;
        var rb = pb && pb.rankReq === 0 ? 0 : 1;
        if (ra !== rb) return ra - rb;
      }
      return inGameRarityCmp(a, b, sa, sb);
    });
  } else if (sortVal === 'area') {
    // By Area: bucket by area (mineshaft → elevator → warehouse), then
    // standard rarity/rank/level/gameId within each area.
    filtered.sort(function (a, b) {
      var sa = smGetState(a.id),
        sb = smGetState(b.id);
      var ta = tier(a, sa),
        tb = tier(b, sb);
      if (ta !== tb) return ta - tb;
      if (ta === 0) {
        var aa = areaOrder[a.area] || 99;
        var ab = areaOrder[b.area] || 99;
        if (aa !== ab) return aa - ab;
      }
      return inGameRarityCmp(a, b, sa, sb);
    });
  } else if (sortVal === 'rank-up') {
    // Closest to Rank Up:
    //   - R5 (rank-maxed) SMs first, ordered as in By Rarity
    //   - then non-R5 sorted by completion percentage descending
    //     (fragments / SM_FRAG_NEXT[rank]) — verified against a real save:
    //     8-of-8 match in the user's listed tier transition.
    //   - locked rentals, then locked non-rentals (same as other sorts)
    filtered.sort(function (a, b) {
      var sa = smGetState(a.id),
        sb = smGetState(b.id);
      var ta = tier(a, sa),
        tb = tier(b, sb);
      if (ta !== tb) return ta - tb;
      if (ta !== 0) return inGameRarityCmp(a, b, sa, sb);
      // Within unlocked tier, split by rank-maxed vs not.
      var maxedA = sa.rank === 5 ? 0 : 1;
      var maxedB = sb.rank === 5 ? 0 : 1;
      if (maxedA !== maxedB) return maxedA - maxedB;
      if (maxedA === 0) {
        // Both R5 — fall back to standard rarity/level/gameId.
        return inGameRarityCmp(a, b, sa, sb);
      }
      // Both non-R5 — compare completion %.
      var pctA = (sa.fragments || 0) / (SM_FRAG_NEXT_LOCAL[sa.rank] || 1);
      var pctB = (sb.fragments || 0) / (SM_FRAG_NEXT_LOCAL[sb.rank] || 1);
      if (pctA !== pctB) return pctB - pctA;
      return inGameRarityCmp(a, b, sa, sb);
    });
  } else if (sortVal === 'ingame') {
    // In-game order: rarity ↓ → rank ↓ → level ↓ → gameId ↓. Reads level/rank,
    // so cards re-order as you level — opt-in only.
    filtered.sort(function (a, b) {
      var sa = smGetState(a.id),
        sb = smGetState(b.id);
      var ta = tier(a, sa),
        tb = tier(b, sb);
      if (ta !== tb) return ta - tb;
      return inGameRarityCmp(a, b, sa, sb);
    });
  } else {
    // Default: stable. Owned-first → rarity ↓ → name A→Z. No mutable state in
    // the key, so editing level/rank never moves a card.
    filtered.sort(function (a, b) {
      var sa = smGetState(a.id),
        sb = smGetState(b.id);
      var ta = tier(a, sa),
        tb = tier(b, sb);
      if (ta !== tb) return ta - tb;
      return smStableRarityCmp(a, b);
    });
  }

  smCurrentVisibleIds = filtered.map(function (sm) {
    return sm.id;
  });
  smPaintGrid(filtered);
}

var smRenderSeq = 0;
var smCurrentVisibleIds = null;
var SM_RENDER_BATCH = 24;

// Build (lazily) + return the edit panel for a card id. The panel shell is
// emitted empty by smRenderCard; its contents are only built the first time it
// is opened, keeping the bulk grid render light.
function smFillEditPanel(id) {
  var panel = document.getElementById('smEdit-' + id);
  if (!panel) return null;
  if (!panel.innerHTML && smDataById && smDataById[id]) {
    panel.innerHTML = smBuildEditPanel(smDataById[id]);
  }
  return panel;
}

function smAfterPaint() {
  smRenderStats();
  if (smExpandedId) {
    var panel = smFillEditPanel(smExpandedId);
    if (panel) panel.classList.add('open');
  }
}

// Paint the filtered cards into #smGrid. In a browser the cards stream in
// ~SM_RENDER_BATCH per animation frame so a 100+ card render never blocks the
// main thread in one long task (that was the multi-second phone freeze on the
// blank grid). A render-sequence token cancels an in-flight paint when a newer
// render (edit / filter / search) starts. Fallback: when requestAnimationFrame
// is unavailable or the grid element has no insertAdjacentHTML (the test
// harness mocks only support innerHTML), paint synchronously in one assignment
// so DOM/string assertions still see the whole grid immediately.
function smPaintGrid(filtered) {
  var seq = ++smRenderSeq;
  var grid = document.getElementById('smGrid');
  if (!grid) return;
  if (!filtered.length) {
    grid.innerHTML =
      '<div class="col-12 text-center text-muted py-4">No Super Managers match your filters</div>';
    smRenderStats();
    return;
  }
  var canChunk =
    typeof requestAnimationFrame === 'function' && typeof grid.insertAdjacentHTML === 'function';
  if (!canChunk) {
    var html = '';
    for (var i = 0; i < filtered.length; i++) html += smRenderCard(filtered[i]);
    grid.innerHTML = html;
    smAfterPaint();
    return;
  }
  grid.innerHTML = '';
  var idx = 0;
  (function step() {
    if (seq !== smRenderSeq) return; // a newer render superseded this one
    var end = Math.min(idx + SM_RENDER_BATCH, filtered.length);
    var chunk = '';
    for (; idx < end; idx++) chunk += smRenderCard(filtered[idx]);
    grid.insertAdjacentHTML('beforeend', chunk);
    if (idx < filtered.length) requestAnimationFrame(step);
    else smAfterPaint();
  })();
}

function smToggleEdit(id) {
  if (smIsReadOnly()) return;
  if (smExpandedId === id) {
    smExpandedId = null;
  } else {
    smExpandedId = id;
    if (typeof trackEvent === 'function') trackEvent('sm_toggle_edit', { id: id });
  }
  // Close all, open selected
  document.querySelectorAll('.sm-edit-panel').forEach(function (p) {
    p.classList.remove('open');
  });
  if (smExpandedId) {
    var panel = smFillEditPanel(smExpandedId);
    if (panel) panel.classList.add('open');
  }
}

function smUpdate(id, field, value) {
  if (smIsReadOnly()) return;
  var state = smEnsureState(id, false);
  state[field] = value;
  if (field === 'unlocked' && !value) {
    state.rank = 0;
    state.level = 1;
    state.promoted = 0;
  }
  smAutoAdjust(state, field, id);
  smClampFields(state, id);
  smSaveState();
  smRenderGrid();
  if (typeof trackEvent === 'function') {
    if (field === 'unlocked') trackEvent(value ? 'sm_unlock' : 'sm_lock', { id: id });
    else if (field === 'level') trackEvent('sm_level_change', { id: id, value: value });
    else if (field === 'promoted') trackEvent('sm_promoted_change', { id: id, value: value });
    else if (field === 'fragments') trackEvent('sm_fragments_change', { id: id, value: value });
  }
}

function smSetRank(id, n, el) {
  if (smIsReadOnly()) return;
  var sm = smDataById[id];
  if (sm && sm.rental) return;
  var cur = smGetState(id).rank || 0;
  var newRank = cur === n ? n - 1 : n;
  var state = smEnsureState(id, false);
  state.rank = newRank;
  if (newRank > 0) state.unlocked = true;
  smAutoAdjust(state, 'rank', id);
  smClampFields(state, id);
  smSaveState();
  smRenderGrid();
  if (typeof trackEvent === 'function') trackEvent('sm_rank_change', { id: id, rank: newRank });
}

function smToggleUnlockAll() {
  if (smIsReadOnly()) return;
  if (!smDefaultData) return;
  var allUnlocked = smDefaultData.every(function (sm) {
    return smGetState(sm.id).unlocked;
  });
  smDefaultData.forEach(function (sm) {
    var state = smEnsureState(sm.id, !allUnlocked);
    state.unlocked = !allUnlocked;
    if (allUnlocked) {
      state.rank = 0;
      state.level = 1;
      state.promoted = 0;
    }
    smClampFields(state, sm.id);
  });
  smSaveState();
  smRenderGrid();
  if (typeof trackEvent === 'function') trackEvent(allUnlocked ? 'sm_lock_all' : 'sm_unlock_all');
}

function smMaxToggle(id) {
  if (smIsReadOnly()) return;
  var s = smEnsureState(id, false);
  var sm = smDataById[id];
  var maxLvl = sm && sm.maxLevel ? sm.maxLevel : 50;
  var isMaxed = s.unlocked && s.rank === 5 && s.level === maxLvl;
  if (isMaxed) {
    var isRental = sm && sm.rental;
    s.rank = 0;
    s.level = 1;
    s.promoted = 0;
    if (isRental) s.unlocked = false;
  } else {
    s.unlocked = true;
    s.rank = 5;
    s.level = maxLvl;
    s.promoted = Math.min(5, Math.floor(maxLvl / 10));
  }
  smClampFields(s, id);
  smSaveState();
  smRenderGrid();
}

function smP30Toggle(id) {
  if (smIsReadOnly()) return;
  var s = smEnsureState(id, false);
  var sm = smDataById[id];
  var isP30 = s.unlocked && s.level === 30 && s.rank >= 3;
  if (isP30) {
    var isRental = sm && sm.rental;
    s.rank = 0;
    s.level = 1;
    s.promoted = 0;
    if (isRental) s.unlocked = false;
  } else {
    s.unlocked = true;
    s.level = 30;
    if (s.rank < 3) s.rank = 3;
    s.promoted = Math.min(s.rank, 3);
  }
  smClampFields(s, id);
  smSaveState();
  smRenderGrid();
}

function smGetVisibleIds() {
  if (smCurrentVisibleIds) return smCurrentVisibleIds.slice();
  var ids = [];
  document.querySelectorAll('#smGrid .sm-card-col').forEach(function (el) {
    var id = el.getAttribute('data-sm-id');
    if (id) ids.push(id);
  });
  return ids;
}

function smToggleMaxAll() {
  if (smIsReadOnly()) return;
  if (!smDefaultData) return;
  var visible = smGetVisibleIds();
  var allMaxed =
    visible.length > 0 &&
    visible.every(function (id) {
      var s = smGetState(id);
      var sm = smDataById[id];
      var maxLvl = sm && sm.maxLevel ? sm.maxLevel : 50;
      return s.unlocked && s.rank === 5 && s.level === maxLvl;
    });
  visible.forEach(function (id) {
    var state = smEnsureState(id, false);
    var sm = smDataById[id];
    var maxLvl = sm && sm.maxLevel ? sm.maxLevel : 50;
    if (allMaxed) {
      state.rank = 0;
      state.level = 1;
      state.promoted = 0;
    } else {
      state.unlocked = true;
      state.rank = 5;
      state.level = maxLvl;
      state.promoted = Math.min(5, Math.floor(maxLvl / 10));
    }
    smClampFields(state, id);
  });
  smSaveState();
  smRenderGrid();
  if (typeof trackEvent === 'function') trackEvent(allMaxed ? 'sm_unmax_all' : 'sm_max_all');
}
