function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

function displayDataTable(data, columns) {
  const thead = document.getElementById('dataTableHead');
  const tbody = document.getElementById('dataTableBody');

  // Create header row with escaped content
  thead.innerHTML = '<tr>' + columns.map((col) => `<th>${escapeHtml(col)}</th>`).join('') + '</tr>';

  // Create data rows with escaped content
  tbody.innerHTML = data
    .map(
      (row) =>
        '<tr>' + columns.map((col) => `<td>${escapeHtml(row[col] || '')}</td>`).join('') + '</tr>'
    )
    .join('');

  // Calculate and apply breakpoint highlighting
  highlightBreakpoints(data);
}

function highlightBreakpoints(data) {
  // Calculate breakpoint indices using correct simulation
  const breakpoints = calculateBreakpoints(data);

  // Add breakpoint lines to the table
  const tbody = document.getElementById('dataTableBody');
  const rows = tbody.querySelectorAll('tr');

  // Special handling for breakpoint at index 0 (can skip from start)
  let insertOffset = 0;
  if (breakpoints.elite === 0) {
    const lineElement = document.createElement('tr');
    lineElement.innerHTML =
      '<td colspan="100%" class="p-0"><div class="breakpoint-line elite-user" title="🟡 Elite Pass Breakpoint: With Elite Pass, you have enough FC from the start to skip through all barriers">🟡 ELITE PASS BREAKPOINT - CAN SKIP FROM START</div></td>';
    tbody.insertBefore(lineElement, tbody.firstChild);
    insertOffset = 1; // Account for elite line inserted at top
  }

  // Collect all breakpoints with their info, excluding elite index 0 (already handled)
  const breakpointList = [];

  if (breakpoints.free > 0) {
    breakpointList.push({
      index: breakpoints.free,
      type: 'free',
      html: '<td colspan="100%" class="p-0"><div class="breakpoint-line free-user" title="🟢 Free User Breakpoint: From this barrier onward, you can wait through all remaining barriers to accumulate FC, then use that FC to skip all remaining barriers">🟢 FREE USER BREAKPOINT</div></td>',
    });
  }

  if (breakpoints.premium > 0) {
    breakpointList.push({
      index: breakpoints.premium,
      type: 'premium',
      html: '<td colspan="100%" class="p-0"><div class="breakpoint-line premium-user" title="🔵 Premium Pass Breakpoint: From this barrier onward, you can wait through all remaining barriers to accumulate FC, then use that FC to skip all remaining barriers">🔵 PREMIUM PASS BREAKPOINT</div></td>',
    });
  }

  if (breakpoints.elite > 0) {
    breakpointList.push({
      index: breakpoints.elite,
      type: 'elite',
      html: '<td colspan="100%" class="p-0"><div class="breakpoint-line elite-user" title="🟡 Elite Pass Breakpoint: From this barrier onward, you can wait through all remaining barriers to accumulate FC, then use that FC to skip all remaining barriers">🟡 ELITE PASS BREAKPOINT</div></td>',
    });
  }

  // Sort breakpoints by index (lowest to highest) to maintain correct insertion order
  breakpointList.sort((a, b) => a.index - b.index);

  // Insert breakpoint lines in order
  // NOTE: Breakpoint at index N means "skip from barrier N", so line goes after barrier N-1
  breakpointList.forEach((breakpoint) => {
    const insertAfterIndex = breakpoint.index - 1 + insertOffset; // Insert after the last "wait through" barrier
    if (insertAfterIndex >= 0 && insertAfterIndex < tbody.querySelectorAll('tr').length) {
      const lineElement = document.createElement('tr');
      lineElement.innerHTML = breakpoint.html;
      tbody.querySelectorAll('tr')[insertAfterIndex].insertAdjacentElement('afterend', lineElement);
      insertOffset++; // Increment for next insertion
    }
  });
}

function calculateBreakpoints(data) {
  // Test scenarios: [hasPremium, hasElite, label]
  const scenarios = [
    [false, false, 'free'],
    [true, false, 'premium'],
    [false, true, 'elite'],
  ];

  const results = {};

  scenarios.forEach(([hasPremium, hasElite, label]) => {
    const breakpoint = findBreakpointForScenario(data, hasPremium, hasElite);
    results[label] = breakpoint;
  });

  return results;
}

function findBreakpointForScenario(data, hasPremium, hasElite) {
  // Initial FC calculation
  let initialFC = 705; // Base FC
  if (hasPremium) initialFC += 500;
  if (hasElite) initialFC += 600;

  // Try each barrier as potential breakeven point (starting from index 0)
  for (let breakevenIndex = 0; breakevenIndex < data.length; breakevenIndex++) {
    const success = testBreakevenAtBarrier(data, breakevenIndex, initialFC, hasPremium, hasElite);
    if (success) {
      return breakevenIndex;
    }
  }

  return -1; // No breakeven point found
}

function testBreakevenAtBarrier(data, breakevenIndex, initialFC, hasPremium, hasElite) {
  // Phase 1: Calculate FC accumulated by waiting through barriers 0 to (breakevenIndex-1)
  let accumulatedFC = initialFC;

  for (let i = 0; i < breakevenIndex; i++) {
    const row = data[i];

    // Get FC rewards for completing this barrier (by waiting, not skipping)
    const baseReward = parseInt(row['FC received after unlocking it (no pass)']) || 0;
    const premiumReward = hasPremium ? parseInt(row['Premium Pass']) || 0 : 0;
    const eliteReward = hasElite ? parseInt(row['Elite Frontier Pass']) || 0 : 0;

    const totalReward = baseReward + premiumReward + eliteReward;
    accumulatedFC += totalReward;
  }

  // Phase 2: Simulate skipping from breakevenIndex to end
  let currentFC = accumulatedFC;

  for (let i = breakevenIndex; i < data.length; i++) {
    const row = data[i];

    // Get skip cost
    const skipCost = parseInt(row['FC Cost After']) || 0;

    // Check if we can afford to skip
    if (currentFC < skipCost) {
      return false; // Failed at this barrier
    }

    // Pay skip cost
    currentFC -= skipCost;

    // Get FC rewards for completing this barrier (even when skipped)
    const baseReward = parseInt(row['FC received after unlocking it (no pass)']) || 0;
    const premiumReward = hasPremium ? parseInt(row['Premium Pass']) || 0 : 0;
    const eliteReward = hasElite ? parseInt(row['Elite Frontier Pass']) || 0 : 0;

    const totalReward = baseReward + premiumReward + eliteReward;
    currentFC += totalReward;
  }

  return true; // Successfully completed all barriers
}

function simulateProgression(data, startIndex, hasPremium, hasElite) {
  // This function is kept for backward compatibility but now calls the correct logic
  const breakpoint = findBreakpointForScenario(data, hasPremium, hasElite);

  // Return true if the startIndex is at or after the breakpoint
  return breakpoint >= 0 && startIndex >= breakpoint;
}

let userEditedFC = false;
let fcCashTrackTimer = null;
let customAmountTrackTimer = null;

fmOnReady(function () {
  document.getElementById('useDefault').addEventListener('change', function () {
    document.getElementById('customFC').style.display = this.checked ? 'none' : 'block';

    trackFmEvent('fm_use_default_toggle', {
      element: 'useDefault_checkbox',
      value: this.checked,
    });
  });

  // Track pass selections and update FC amount
  document.getElementById('fcCash').addEventListener('input', function () {
    userEditedFC = true;
    var self = this;
    clearTimeout(fcCashTrackTimer);
    fcCashTrackTimer = setTimeout(function () {
      trackFmEvent('fm_fc_cash_change', { value: parseInt(self.value) || 0 });
    }, 600);
  });

  // Custom FC amount (only meaningful when "Use default" is unchecked).
  // Debounced like fcCash since it's also a free-text number input.
  var customAmountEl = document.getElementById('customAmount');
  if (customAmountEl) {
    customAmountEl.addEventListener('input', function () {
      clearTimeout(customAmountTrackTimer);
      customAmountTrackTimer = setTimeout(function () {
        trackFmEvent('fm_custom_fc_change', { value: parseInt(customAmountEl.value) || 0 });
      }, 600);
    });
  }
});

function getDefaultFC() {
  let totalFC = 705;
  if (document.getElementById('premiumPass').checked) totalFC += 500;
  if (document.getElementById('elitePass').checked) totalFC += 600;
  return totalFC;
}
