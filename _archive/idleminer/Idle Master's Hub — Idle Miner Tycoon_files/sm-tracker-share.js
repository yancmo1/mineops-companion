function smExport() {
  var blob = new Blob([JSON.stringify(smUserState, null, 2)], { type: 'application/json' });
  var a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = 'sm-tracker-backup.json';
  a.click();
  URL.revokeObjectURL(a.href);
  if (typeof trackEvent === 'function') trackEvent('sm_export');
}

function smApplyImportedState(data) {
  if (typeof data !== 'object' || data === null || Array.isArray(data)) {
    throw new Error('Invalid format. Expected a JSON object.');
  }
  for (var id in data) {
    var st = data[id];
    if (typeof st !== 'object' || st === null) {
      delete data[id];
      continue;
    }
    smClampFields(st, id);
  }
  smUserState = data;
  smSaveState();
  smRenderGrid();
}

function smImport(file) {
  var reader = new FileReader();
  reader.onload = function (e) {
    try {
      var data = JSON.parse(e.target.result);
      smApplyImportedState(data);
      if (typeof trackEvent === 'function') trackEvent('sm_import');
      alert('Imported successfully!');
    } catch (err) {
      alert(err && err.message ? 'Failed to import: ' + err.message : 'Failed to import.');
    }
  };
  reader.readAsText(file);
}

// ===== Shareable snapshot =====

var SM_SHARE_ESSENCE_KEYS = [
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
  'epic',
  'legendary',
];
var SM_SHARE_POUCH_KEYS = ['regular', 'big', 'giant'];

function smShareReadEssences() {
  try {
    var raw = localStorage.getItem('essencePlannerState');
    if (!raw) return null;
    var s = JSON.parse(raw);
    if (!s || typeof s !== 'object') return null;
    var inv = {};
    var hasInv = false;
    if (s.inventory && typeof s.inventory === 'object') {
      for (var i = 0; i < SM_SHARE_ESSENCE_KEYS.length; i++) {
        var k = SM_SHARE_ESSENCE_KEYS[i];
        var n = parseInt(s.inventory[k], 10);
        if (!isNaN(n) && n > 0) {
          inv[k] = n;
          hasInv = true;
        }
      }
    }
    var p = {};
    var hasPouch = false;
    if (s.pouches && typeof s.pouches === 'object') {
      for (var j = 0; j < SM_SHARE_POUCH_KEYS.length; j++) {
        var pk = SM_SHARE_POUCH_KEYS[j];
        var pn = parseInt(s.pouches[pk], 10);
        if (!isNaN(pn) && pn > 0) {
          p[pk] = pn;
          hasPouch = true;
        }
      }
    }
    if (!hasInv && !hasPouch) return null;
    var out = {};
    if (hasInv) out.inv = inv;
    if (hasPouch) out.p = p;
    return out;
  } catch (e) {
    return null;
  }
}

function smShareHasEssenceData() {
  return !!smShareReadEssences();
}

function smShareBuildSmsPayload() {
  var sms = {};
  for (var id in smUserState) {
    if (!Object.prototype.hasOwnProperty.call(smUserState, id)) continue;
    var st = smUserState[id];
    if (!st || typeof st !== 'object') continue;
    var unlocked = st.unlocked ? 1 : 0;
    var rank = +st.rank || 0;
    var level = +st.level || 1;
    var promoted = +st.promoted || 0;
    var fragments = +st.fragments || 0;
    if (unlocked === 0 && rank === 0 && level === 1 && promoted === 0 && fragments === 0) {
      // Skip pure-default entries to keep the payload small.
      continue;
    }
    sms[id] = [unlocked, rank, level, promoted, fragments];
  }
  return sms;
}

// Flag flipped to true when sm_share_created successfully fires inside a
// modal session; read by the hidden.bs.modal listener so we can tag the
// dismiss event with whether the user actually shared anything.
var smShareSessionDidShare = false;

function smShareOpenModal() {
  var modalEl = document.getElementById('smShareModal');
  if (!modalEl || typeof bootstrap === 'undefined' || !bootstrap.Modal) return;
  // Reset state every time we open.
  smShareSessionDidShare = false;
  document.getElementById('smShareForm').hidden = false;
  document.getElementById('smShareResult').hidden = true;
  var errEl = document.getElementById('smShareModalError');
  if (errEl) errEl.hidden = true;
  var nameInput = document.getElementById('smShareName');
  if (nameInput) nameInput.value = '';
  var toggleWrap = document.getElementById('smShareEssenceToggleWrap');
  var toggle = document.getElementById('smShareEssenceToggle');
  if (smShareHasEssenceData()) {
    if (toggleWrap) toggleWrap.hidden = false;
    if (toggle) toggle.checked = true;
  } else {
    if (toggleWrap) toggleWrap.hidden = true;
    if (toggle) toggle.checked = false;
  }
  bootstrap.Modal.getOrCreateInstance(modalEl).show();
  if (typeof trackEvent === 'function') trackEvent('sm_share_modal_open');
}

function smShareShowError(msg) {
  var errEl = document.getElementById('smShareModalError');
  if (!errEl) return;
  errEl.textContent = msg;
  errEl.hidden = false;
}

function smShareGenerate() {
  var btn = document.getElementById('smShareGenerateBtn');
  if (btn) {
    btn.disabled = true;
    btn.textContent = 'Generating...';
  }
  var sms = smShareBuildSmsPayload();
  if (!Object.keys(sms).length) {
    smShareShowError('Nothing to share yet — unlock or rank up some Super Managers first.');
    if (btn) {
      btn.disabled = false;
      btn.textContent = 'Generate link';
    }
    return;
  }

  var nameInput = document.getElementById('smShareName');
  var name = nameInput ? String(nameInput.value || '').trim() : '';
  var includeEssences =
    smShareHasEssenceData() &&
    !!(
      document.getElementById('smShareEssenceToggle') &&
      document.getElementById('smShareEssenceToggle').checked
    );

  var payload = { sms: sms };
  if (name) payload.n = name;
  if (includeEssences) {
    var e = smShareReadEssences();
    if (e) payload.e = e;
  }

  fetch('/api/share', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  })
    .then(function (r) {
      return r.json().then(function (body) {
        return { status: r.status, body: body };
      });
    })
    .then(function (res) {
      if (btn) {
        btn.disabled = false;
        btn.textContent = 'Generate link';
      }
      if (res.status === 429) {
        smShareShowError('Too many shares in the last hour. Try again later.');
        return;
      }
      if (res.status === 413) {
        smShareShowError('Snapshot is too large to share. Try again with fewer SMs.');
        return;
      }
      if (!res.body || !res.body.success || !res.body.id) {
        smShareShowError(
          (res.body && res.body.error) || 'Could not create share link. Please try again.'
        );
        return;
      }
      var url = location.origin + location.pathname + '#share=' + encodeURIComponent(res.body.id);
      var urlInput = document.getElementById('smShareUrl');
      if (urlInput) urlInput.value = url;
      var preview = document.getElementById('smSharePreviewLink');
      if (preview) preview.href = url;
      var expEl = document.getElementById('smShareExpiresText');
      if (expEl) {
        var d = new Date(res.body.expiresAt);
        expEl.textContent = 'Expires ' + d.toISOString().slice(0, 10);
      }
      document.getElementById('smShareForm').hidden = true;
      document.getElementById('smShareResult').hidden = false;
      smShareCopyLink({ silent: true });
      smShareSessionDidShare = true;
      if (typeof trackEvent === 'function') {
        trackEvent('sm_share_created', {
          smCount: Object.keys(sms).length,
          hasName: !!name,
          includesEssences: includeEssences,
        });
      }
    })
    .catch(function () {
      if (btn) {
        btn.disabled = false;
        btn.textContent = 'Generate link';
      }
      smShareShowError('Network error. Please try again.');
    });
}

function smShareCopyLink(opts) {
  var urlInput = document.getElementById('smShareUrl');
  if (!urlInput || !urlInput.value) return;
  var copyBtn = document.getElementById('smShareCopyBtn');
  var done = function () {
    if (copyBtn) {
      var orig = copyBtn.textContent;
      copyBtn.textContent = 'Copied';
      setTimeout(function () {
        copyBtn.textContent = orig;
      }, 1500);
    }
  };
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard
      .writeText(urlInput.value)
      .then(done)
      .catch(function () {
        urlInput.select();
        try {
          document.execCommand('copy');
          done();
        } catch (e) {}
      });
  } else {
    urlInput.select();
    try {
      document.execCommand('copy');
      done();
    } catch (e) {}
  }
  if (!opts || !opts.silent) {
    if (typeof trackEvent === 'function') trackEvent('sm_share_copy_link');
  }
}

function smShareRenderBanner(snapshot) {
  var banner = document.getElementById('smShareBanner');
  if (!banner) return;
  var titleEl = document.getElementById('smShareBannerTitle');
  var metaEl = document.getElementById('smShareBannerMeta');
  var ctaEl = document.getElementById('smShareBannerCta');
  var name = snapshot && typeof snapshot.n === 'string' ? snapshot.n : '';
  if (titleEl) {
    titleEl.textContent = name ? name + "'s Super Managers" : 'Shared Super Managers snapshot';
  }
  if (metaEl) {
    var dateStr = '';
    if (snapshot && typeof snapshot.c === 'number') {
      var d = new Date(snapshot.c);
      dateStr = d.toISOString().slice(0, 10);
    }
    metaEl.textContent = dateStr ? 'Snapshot from ' + dateStr : '';
  }
  if (ctaEl) {
    ctaEl.href = location.pathname + '#sm';
  }
  banner.hidden = false;
}

function smShareRenderEssencePanel(essences) {
  var panel = document.getElementById('smShareEssencePanel');
  if (!panel) return;
  if (!essences || (!essences.inv && !essences.p)) {
    panel.hidden = true;
    panel.innerHTML = '';
    return;
  }
  var html = '<h6>Essences &amp; Pouches</h6>';
  if (essences.inv) {
    html += '<div class="sm-share-essence-section"><div class="sm-share-essence-grid">';
    for (var i = 0; i < SM_SHARE_ESSENCE_KEYS.length; i++) {
      var k = SM_SHARE_ESSENCE_KEYS[i];
      var v = parseInt(essences.inv[k], 10) || 0;
      if (v <= 0) continue;
      html +=
        '<div class="sm-share-essence-row"><span class="label">' +
        escapeHtml(k) +
        '</span><span class="value">' +
        v +
        '</span></div>';
    }
    html += '</div></div>';
  }
  if (essences.p) {
    var pHtml = '';
    for (var j = 0; j < SM_SHARE_POUCH_KEYS.length; j++) {
      var pk = SM_SHARE_POUCH_KEYS[j];
      var pv = parseInt(essences.p[pk], 10) || 0;
      if (pv <= 0) continue;
      pHtml +=
        '<div class="sm-share-essence-row"><span class="label">' +
        escapeHtml(pk) +
        ' pouch</span><span class="value">' +
        pv +
        '</span></div>';
    }
    if (pHtml) {
      html +=
        '<div class="sm-share-essence-section"><div class="sm-share-essence-grid">' +
        pHtml +
        '</div></div>';
    }
  }
  panel.innerHTML = html;
  panel.hidden = false;
}

function smShareApplyReadOnly(snapshot) {
  if (!snapshot || typeof snapshot !== 'object' || !snapshot.sms) return false;
  var hydrated = {};
  for (var id in snapshot.sms) {
    if (!Object.prototype.hasOwnProperty.call(snapshot.sms, id)) continue;
    var arr = snapshot.sms[id];
    if (!Array.isArray(arr) || arr.length !== 5) continue;
    var st = {
      unlocked: !!arr[0],
      rank: +arr[1] || 0,
      level: +arr[2] || 1,
      promoted: +arr[3] || 0,
      fragments: +arr[4] || 0,
      chronoExcluded: false,
      tierlistExcluded: false,
    };
    smClampFields(st, id);
    hydrated[id] = st;
  }
  smUserState = hydrated;
  window.SM_READ_ONLY = true;
  document.body.classList.add('sm-share-readonly');
  smShareRenderBanner(snapshot);
  smShareRenderEssencePanel(snapshot.e);
  return true;
}

function smShareRenderEmptyState(heading, body) {
  var grid = document.getElementById('smGrid');
  if (grid) {
    grid.innerHTML =
      '<div class="col-12 sm-share-not-found">' +
      '<h3>' +
      heading +
      '</h3>' +
      '<p>' +
      body +
      '</p>' +
      '<a href="' +
      location.pathname +
      '#sm">Go to your own tracker &rarr;</a>' +
      '</div>';
  }
  document.body.classList.add('sm-share-readonly');
  var banner = document.getElementById('smShareBanner');
  if (banner) banner.hidden = true;
}

function smShareRenderNotFound() {
  smShareRenderEmptyState(
    'Snapshot not available',
    'This share link has expired or was never created. Snapshots are kept for 12 months.'
  );
}

function smShareRenderLoadError() {
  smShareRenderEmptyState(
    'Couldn’t load snapshot',
    'Something went wrong loading this snapshot. Check your connection and try again.'
  );
}

function smShareLoadView(id) {
  // Skip loading the user's own state — we never want to touch it in share view.
  smLoaded = true;
  smLoadActivesShowPercent();
  // Element view is session-only and never wired in share view (smInit wires the
  // selector only in its non-share branch), so smActiveModalElement stays at its
  // '' default here — share view shows the sharer's actual (neutral) values.
  // Mark read-only immediately so any code that races with the fetch is gated.
  window.SM_READ_ONLY = true;
  document.body.classList.add('sm-share-readonly');

  var rosterPromise = new Promise(function (resolve, reject) {
    smLoadData(SM_DATA_URL, resolve, reject);
  });
  var snapshotPromise = fetch('/api/share/' + encodeURIComponent(id)).then(function (r) {
    return r.json().then(function (body) {
      return { status: r.status, body: body };
    });
  });

  Promise.all([rosterPromise, snapshotPromise])
    .then(function (results) {
      var data = results[0];
      var resp = results[1];
      smDefaultData = data;
      smDataById = {};
      smDefaultData.forEach(function (sm) {
        smDataById[sm.id] = sm;
      });
      if (resp.status === 404) {
        smShareRenderNotFound();
        if (typeof trackEvent === 'function') {
          trackEvent('sm_share_view_missing', { id: id });
        }
        return;
      }
      if (!resp.body || !resp.body.success || !resp.body.snapshot) {
        smShareRenderLoadError();
        return;
      }
      var snap = resp.body.snapshot;
      var ok = smShareApplyReadOnly(snap);
      if (!ok) {
        smShareRenderLoadError();
        return;
      }
      smRenderGrid();
      if (typeof trackEvent === 'function') {
        var ageHours =
          snap && typeof snap.c === 'number'
            ? Math.max(0, Math.floor((Date.now() - snap.c) / 3600000))
            : 0;
        trackEvent('sm_share_viewed', {
          ageHours: ageHours,
          smCount: snap.sms ? Object.keys(snap.sms).length : 0,
          hasEssences: !!snap.e,
        });
      }
    })
    .catch(function () {
      smShareRenderLoadError();
    });

  // Stream actives + passives in parallel so promoted passive numbers fill in
  // (read-only render still benefits from these tables).
  smLoadData(
    SM_ACTIVES_URL,
    function (data) {
      if (data) smActivesData = data;
    },
    function () {}
  );
  smLoadData(
    SM_PASSIVE_TABLES_URL,
    function (data) {
      if (!data) return;
      smPassiveTables = data;
      window.dispatchEvent(new CustomEvent('sm-passive-tables-loaded'));
      if (smDefaultData) smRenderGrid();
    },
    function () {}
  );
}
