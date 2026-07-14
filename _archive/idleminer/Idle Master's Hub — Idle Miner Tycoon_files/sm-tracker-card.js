function smRenderCard(sm) {
  var st = smGetState(sm.id);
  var isLocked = !st.unlocked;
  var initials = sm.name
    .split(/[\s\-_]+/)
    .map(function (w) {
      return w[0];
    })
    .join('')
    .substring(0, 2)
    .toUpperCase();
  var rank = st.rank || 0;

  // Stars
  var isRental = !!sm.rental;
  var headerStars =
    '<span class="sm-star-input" data-sm="' +
    sm.id +
    '">' +
    [1, 2, 3, 4, 5]
      .map(function (n) {
        if (isRental)
          return (
            '<span data-rank="' +
            n +
            '" class="' +
            (n <= rank ? 'active' : '') +
            '" style="cursor:default">\u2605</span>'
          );
        return (
          '<span data-rank="' +
          n +
          '" class="' +
          (n <= rank ? 'active' : '') +
          '" onclick="event.stopPropagation();smSetRank(' +
          q +
          sm.id +
          q +
          ',' +
          n +
          ',this)">\u2605</span>'
        );
      })
      .join('') +
    '</span>';

  // SE elements — stacked vertically in top-right
  var els = '';
  var seElements = sm.elements.filter(function (el) {
    return el.effectiveness === 'SE';
  });
  seElements.forEach(function (el) {
    var eff = el.effectiveness;
    var cls = 'eff-' + eff.toLowerCase();
    if (isLocked || (eff === 'SE' && el.rankReq > rank)) cls = 'eff-se-locked';
    var col = ELEMENT_COLORS[el.element] || '#999';
    var style = '';
    if (cls === 'eff-se') style = 'border-color:' + col + ';';
    var title = el.element + ' (' + eff + (el.rankReq > 0 ? ', rank ' + el.rankReq : '') + ')';
    var abbr = ELEMENT_ABBR[el.element] || '?';
    var imgName = el.element.charAt(0).toUpperCase() + el.element.slice(1);
    var imgUrl = ELEMENT_IMG_BASE + imgName + '.webp';
    els +=
      '<span class="sm-el ' +
      cls +
      '" style="' +
      style +
      '" title="' +
      escapeHtml(title) +
      '">' +
      '<img src="' +
      imgUrl +
      '" alt="' +
      abbr +
      '" loading="lazy" decoding="async" onerror="this.replaceWith(document.createTextNode(' +
      q +
      abbr +
      q +
      '))">' +
      '</span>';
  });

  // Passives — card face (short) and edit panel (full)
  var passiveCardHtml = '';
  if (sm.passives && sm.passives.length) {
    sm.passives.forEach(function (p) {
      var active = smEffectivePromoted(sm.id) >= p.promoReq;
      var isMultiplier = isBeamPassiveType(p.type) || isScaledMultiplierPassiveType(p.type);
      var val = smGetPassiveValue(sm, p);
      var valStr =
        val === null
          ? '?'
          : isMultiplier
            ? '\u00d7' + formatPassiveValue(val, 2)
            : formatPassiveValue(val, 1) + '%';
      var fullName = PASSIVE_NAMES[p.type] || p.type;
      var shortLabel = p.type + ' ' + valStr;
      if (p.promoReq > 0) {
        shortLabel += ' P' + p.promoReq * 10;
      }
      var cls = active ? '' : 'passive-locked';
      var tip = escapeHtml(
        active
          ? fullName + ' ' + valStr + ' - Active'
          : fullName + ' - Requires P' + p.promoReq * 10
      );
      passiveCardHtml +=
        '<div class="' + cls + '" title="' + tip + '">' + escapeHtml(shortLabel) + '</div>';
    });
  }

  // maxLvl / isMaxed feed the MAX button + fragment bar below. The full edit
  // panel (inputs + SE-unlock + PE/NVE element imgs + passive list + active
  // button) is built lazily by smBuildEditPanel() on first expand, so the
  // initial 100+ card render stays light.
  var maxLvl = sm.maxLevel || 50;
  var isMaxed = st.unlocked && (st.rank || 0) === 5 && (st.level || 1) === maxLvl;
  // Empty panel shell only \u2014 its contents are built lazily by
  // smBuildEditPanel() the first time the card is expanded.
  var editHtml =
    '<div class="sm-edit-panel" id="smEdit-' + sm.id + '" onclick="event.stopPropagation()"></div>';

  // Sprite / initials
  var rarityFolder = sm.rarity.charAt(0).toUpperCase() + sm.rarity.slice(1);
  var spriteUrl = smSpriteUrl(sm, initials);
  var avatarContent =
    '<img src="' +
    spriteUrl +
    '" alt="' +
    initials +
    '" loading="lazy" decoding="async"' +
    ' onerror="this.style.display=' +
    q +
    'none' +
    q +
    ';var s=document.createElement(' +
    q +
    'span' +
    q +
    ');s.className=' +
    q +
    'sm-initials' +
    q +
    ';s.textContent=' +
    q +
    initials +
    q +
    ';this.parentElement.appendChild(s)">';

  // Controls: unlock + max (top-left overlay)
  var unlockBtn =
    '<span class="sm-unlock-btn' +
    (isLocked ? '' : ' active') +
    '" title="' +
    (isLocked ? 'Unlock' : 'Lock') +
    '" role="button" tabindex="0" aria-label="' +
    (isLocked ? 'Unlock' : 'Lock') +
    ' ' +
    escapeHtml(sm.name) +
    '" onclick="event.stopPropagation();smUpdate(' +
    q +
    sm.id +
    q +
    ',' +
    q +
    'unlocked' +
    q +
    ',' +
    (isLocked ? 'true' : 'false') +
    ')">' +
    (isLocked ? '\u2610' : '\u2611') +
    '</span>';
  var maxBtn =
    '<span class="sm-max-btn' +
    (isMaxed ? ' active' : '') +
    '" title="' +
    (isMaxed ? 'Unmax' : 'Max') +
    '" role="button" tabindex="0" onclick="event.stopPropagation();smMaxToggle(' +
    q +
    sm.id +
    q +
    ')">MAX</span>';
  var isP30 = !isLocked && (st.level || 1) === 30 && rank >= 3;
  var p30Btn =
    '<span class="sm-p30-btn' +
    (isP30 ? ' active' : '') +
    '" title="' +
    (isP30 ? 'Reset' : 'Set p30') +
    '" role="button" tabindex="0" onclick="event.stopPropagation();smP30Toggle(' +
    q +
    sm.id +
    q +
    ')">p30</span>';
  var isExcluded = !!st.chronoExcluded;
  var chronoBtn =
    '<span class="sm-chrono-btn' +
    (isExcluded ? ' active' : '') +
    '" title="' +
    (isExcluded ? 'Include in Chrono' : 'Exclude from Chrono') +
    '" role="button" tabindex="0" onclick="event.stopPropagation();smUpdate(' +
    q +
    sm.id +
    q +
    ',' +
    q +
    'chronoExcluded' +
    q +
    ',' +
    !isExcluded +
    ')">Chrono Exclude</span>';
  var isTlExcluded = !!st.tierlistExcluded;
  var tlBtn =
    typeof tierlistShowExclusions !== 'undefined' && tierlistShowExclusions
      ? '<span class="sm-tl-btn' +
        (isTlExcluded ? ' active' : '') +
        '" title="' +
        (isTlExcluded ? 'Include in Tier List' : 'Exclude from Tier List') +
        '" role="button" tabindex="0" onclick="event.stopPropagation();smUpdate(' +
        q +
        sm.id +
        q +
        ',' +
        q +
        'tierlistExcluded' +
        q +
        ',' +
        !isTlExcluded +
        ')">TL</span>'
      : '';

  // Lock overlay
  var lockOverlay = isLocked ? '<div class="sm-lock-overlay">&#x1F512;</div>' : '';
  var areaAbbr = sm.area === 'elevator' ? 'E' : sm.area === 'warehouse' ? 'W' : 'MS';
  var areaBadge = '<div class="sm-area-badge">' + areaAbbr + '</div>';
  var rentalBadge = isRental
    ? '<div class="sm-area-badge" style="top:auto;bottom:22px;background:var(--accent-danger);color:#fff;font-size:0.5rem;">RENTAL</div>'
    : '';

  // Fragment bar — dynamic target based on rank
  var fragments = st.fragments || 0;
  var fragTarget = smFragTarget(st.unlocked, rank);
  var fragBar;
  if (isMaxed || rank >= 5) {
    fragBar =
      '<div class="sm-fragment-bar">' +
      '<div class="sm-fragment-fill" style="width:100%"></div></div>';
  } else {
    var fragPct = fragTarget > 0 ? Math.min(100, (fragments / fragTarget) * 100) : 0;
    fragBar =
      '<div class="sm-fragment-bar">' +
      '<div class="sm-fragment-fill" style="width:' +
      fragPct +
      '%"></div>' +
      '<span class="sm-fragment-text">' +
      fragments +
      '/' +
      fragTarget +
      '</span></div>';
  }

  // Card info: left (name/level/stars), right (passives)
  var infoHtml;
  if (isLocked) {
    infoHtml =
      '<div class="sm-card-info">' +
      '<div class="sm-card-info-left">' +
      '<div class="sm-name">' +
      escapeHtml(sm.name) +
      '</div>' +
      '<div style="font-size:0.65rem;color:var(--content-text-muted);">Locked</div></div></div>';
  } else {
    infoHtml =
      '<div class="sm-card-info">' +
      '<div class="sm-card-info-left">' +
      '<div class="sm-name">' +
      escapeHtml(sm.name) +
      '</div>' +
      '<div style="font-size:0.65rem;color:var(--content-text-muted);">Lv ' +
      (st.level || 1) +
      ((st.promoted || 0) > 0 ? ' · p' + st.promoted : '') +
      '</div>' +
      '<div>' +
      headerStars +
      '</div></div>' +
      '<div class="sm-card-info-right">' +
      passiveCardHtml +
      '</div></div>';
    var activeVal = smFormatActive(sm.id, rank, st.level || 1);
    if (activeVal) {
      infoHtml += '<div class="sm-active-value">Active: ' + activeVal + '</div>';
    }
  }

  return (
    '<div class="col-6 col-sm-4 col-md-3 col-lg-2 sm-card-col" data-sm-id="' +
    sm.id +
    '">' +
    '<div class="sm-card ' +
    (isLocked ? 'locked ' : '') +
    'rarity-' +
    sm.rarity +
    '" role="button" tabindex="0" aria-label="' +
    escapeHtml(sm.name) +
    '" onclick="smToggleEdit(' +
    q +
    sm.id +
    q +
    ')">' +
    '<div class="sm-card-controls">' +
    unlockBtn +
    maxBtn +
    p30Btn +
    chronoBtn +
    tlBtn +
    '</div>' +
    '<div class="sm-elements">' +
    els +
    '</div>' +
    '<div class="sm-avatar rarity-' +
    sm.rarity +
    '">' +
    avatarContent +
    lockOverlay +
    areaBadge +
    rentalBadge +
    '</div>' +
    infoHtml +
    fragBar +
    editHtml +
    '</div></div>'
  );
}

// Builds the INNER html of a card's edit panel (the empty
// `<div class="sm-edit-panel">` shell is emitted by smRenderCard). Called
// lazily by smToggleEdit / the grid re-open path the first time a card opens,
// so the initial 100+ card render never pays for inputs + element <img> it
// can't see. Returns the same markup the inline build produced before.
function smBuildEditPanel(sm) {
  var st = smGetState(sm.id);
  var rank = st.rank || 0;
  var isRental = !!sm.rental;
  var maxLvl = sm.maxLevel || 50;
  var isMaxed = st.unlocked && rank === 5 && (st.level || 1) === maxLvl;
  var lvlDisabled = isRental ? ' disabled style="opacity:0.5"' : '';
  var promoDisabled = isRental ? ' disabled style="opacity:0.5"' : '';
  var fragDisabled = isMaxed || isRental || rank >= 5 ? ' disabled style="opacity:0.5"' : '';
  var rankMaxLvl = maxLevelForRank(rank);
  var effectiveMax = Math.min(maxLvl, rankMaxLvl);
  var maxP = Math.min(Math.floor((st.level || 1) / 10), maxPromoForRank(rank));

  var html =
    '<div class="row g-2">' +
    '<div class="col-6"><label>Level (1-' +
    effectiveMax +
    ')</label>' +
    '<input type="number" class="form-control form-control-sm" min="1" max="' +
    effectiveMax +
    '" value="' +
    (st.level || 1) +
    '"' +
    lvlDisabled +
    ' onchange="smUpdate(' +
    q +
    sm.id +
    q +
    ',' +
    q +
    'level' +
    q +
    ',+this.value)"></div>' +
    '<div class="col-6"><label>Promoted (0-' +
    maxP +
    ')</label>' +
    '<input type="number" class="form-control form-control-sm" min="0" max="' +
    maxP +
    '" value="' +
    (st.promoted || 0) +
    '"' +
    promoDisabled +
    ' onchange="smUpdate(' +
    q +
    sm.id +
    q +
    ',' +
    q +
    'promoted' +
    q +
    ',+this.value)"></div>' +
    '<div class="col-6"><label>Fragments</label>' +
    '<input type="number" class="form-control form-control-sm" min="0" max="' +
    SM_FRAG_INPUT_MAX +
    '" value="' +
    (st.fragments || 0) +
    '"' +
    fragDisabled +
    ' onchange="smUpdate(' +
    q +
    sm.id +
    q +
    ',' +
    q +
    'fragments' +
    q +
    ',+this.value)"></div>' +
    '</div>';

  // Rank unlock info for SE elements
  var seInfo = sm.elements.filter(function (e) {
    return e.effectiveness === 'SE' && e.rankReq > 0;
  });
  if (seInfo.length) {
    html +=
      '<div class="mt-2" style="font-size:0.75rem;color:var(--content-text-muted);">SE unlocks: ';
    seInfo.forEach(function (e) {
      var unlocked = rank >= e.rankReq;
      html +=
        '<span style="color:' +
        (unlocked ? '#28a745' : '#dc3545') +
        '">' +
        e.element +
        ' at rank ' +
        e.rankReq +
        (unlocked ? ' ✓' : '') +
        '</span> ';
    });
    html += '</div>';
  }
  // PE & NVE elements
  var peEls = sm.elements.filter(function (e) {
    return e.effectiveness === 'PE' || (e.effectiveness === 'SE' && e.rankReq > rank);
  });
  var nveEls = sm.elements.filter(function (e) {
    return e.effectiveness === 'NVE';
  });
  if (peEls.length || nveEls.length) {
    html += '<div class="mt-2" style="font-size:0.75rem;">';
    if (peEls.length) {
      html +=
        '<div style="color:var(--content-text-muted);display:flex;align-items:center;gap:4px;flex-wrap:wrap;"><span>PE:</span>';
      peEls.forEach(function (e) {
        var col = ELEMENT_COLORS[e.element] || '#999';
        var imgName = e.element.charAt(0).toUpperCase() + e.element.slice(1);
        var imgUrl = ELEMENT_IMG_BASE + imgName + '.webp';
        var abbr = ELEMENT_ABBR[e.element] || '?';
        html +=
          '<span style="display:inline-flex;align-items:center;gap:2px;border:1px solid ' +
          col +
          ';border-radius:3px;padding:1px 4px;">' +
          '<img src="' +
          imgUrl +
          '" alt="' +
          abbr +
          '" style="width:12px;height:12px;" onerror="this.replaceWith(document.createTextNode(' +
          q +
          abbr +
          q +
          '))">' +
          '<span>' +
          abbr +
          '</span></span>';
      });
      html += '</div>';
    }
    if (nveEls.length) {
      html +=
        '<div style="color:var(--content-text-muted);display:flex;align-items:center;gap:4px;flex-wrap:wrap;margin-top:2px;"><span>NVE:</span>';
      nveEls.forEach(function (e) {
        var col = ELEMENT_COLORS[e.element] || '#999';
        var imgName = e.element.charAt(0).toUpperCase() + e.element.slice(1);
        var imgUrl = ELEMENT_IMG_BASE + imgName + '.webp';
        var abbr = ELEMENT_ABBR[e.element] || '?';
        html +=
          '<span style="display:inline-flex;align-items:center;gap:2px;border:1px solid ' +
          col +
          ';border-radius:3px;padding:1px 4px;">' +
          '<img src="' +
          imgUrl +
          '" alt="' +
          abbr +
          '" style="width:12px;height:12px;" onerror="this.replaceWith(document.createTextNode(' +
          q +
          abbr +
          q +
          '))">' +
          '<span>' +
          abbr +
          '</span></span>';
      });
      html += '</div>';
    }
    html += '</div>';
  }

  // Passives — full labels
  if (sm.passives && sm.passives.length) {
    var passiveEditHtml = '';
    sm.passives.forEach(function (p) {
      var active = smEffectivePromoted(sm.id) >= p.promoReq;
      var isMultiplier = isBeamPassiveType(p.type) || isScaledMultiplierPassiveType(p.type);
      var val = smGetPassiveValue(sm, p);
      var valStr =
        val === null
          ? '?'
          : isMultiplier
            ? '×' + formatPassiveValue(val, 2)
            : formatPassiveValue(val, 1) + '%';
      var fullName = PASSIVE_NAMES[p.type] || p.type;
      var fullLabel = fullName + ' ' + valStr;
      if (p.promoReq > 0) fullLabel += ' (P' + p.promoReq * 10 + ')';
      var cls = active ? '' : 'passive-locked';
      var tip = escapeHtml(
        active
          ? fullName + ' ' + valStr + ' - Active'
          : fullName + ' - Requires P' + p.promoReq * 10
      );
      passiveEditHtml +=
        '<span class="' + cls + '" title="' + tip + '">' + escapeHtml(fullLabel) + '</span> ';
    });
    html += '<div class="sm-passive mt-1">' + passiveEditHtml + '</div>';
  }

  if (smActivesData && smActivesData[sm.id]) {
    html +=
      '<div class="mt-2"><button type="button" class="btn btn-outline-secondary btn-sm sm-active-table-btn" onclick="smShowActiveTable(' +
      q +
      sm.id +
      q +
      ')">View Active Table</button></div>';
  }
  return html;
}
