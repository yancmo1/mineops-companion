(function () {
  var resolveReady;
  var ready = new Promise(function (resolve) {
    resolveReady = resolve;
  });
  var started = false;

  function partialBase() {
    return location.pathname.includes('/pages/') ? '../static/partials/' : '/static/partials/';
  }

  function injectPartial(placeholder, html) {
    var template = document.createElement('template');
    template.innerHTML = html;
    placeholder.replaceWith(template.content);
  }

  function injectError(placeholder, name) {
    // Rebuild the failed partial's tab-pane shell so the error stays confined to
    // its section. The placeholder declares its pane id via data-pane (the id the
    // real partial's root carries); without the tab-pane class + id the div is not
    // governed by Bootstrap's tab display and would show across every tab.
    var div = document.createElement('div');
    div.className = 'tab-pane fade text-center text-danger py-4';
    div.setAttribute('role', 'tabpanel');
    var paneId = placeholder.getAttribute('data-pane');
    if (paneId) {
      div.id = paneId;
      // If this is the active tab (e.g. the default landing tab on a no-hash
      // load, where nothing calls bootstrap.Tab.show), the pane must carry
      // "show active" itself or it stays display:none and the error never shows.
      var active = document.querySelector('#mainTabs .nav-link.active');
      if (active && active.getAttribute('data-bs-target') === '#' + paneId) {
        div.className += ' show active';
      }
    }
    div.textContent = 'Failed to load this section (' + name + ').';
    placeholder.replaceWith(div);
  }

  function fetchPartial(url) {
    if (location.protocol === 'file:' && typeof XMLHttpRequest !== 'undefined') {
      return new Promise(function (resolve, reject) {
        var xhr = new XMLHttpRequest();
        xhr.open('GET', url, true);
        xhr.onload = function () {
          if (xhr.status === 0 || (xhr.status >= 200 && xhr.status < 300))
            resolve(xhr.responseText);
          else reject(new Error('Failed to load partial: ' + url));
        };
        xhr.onerror = function () {
          reject(new Error('Failed to load partial: ' + url));
        };
        xhr.send();
      });
    }
    return fetch(url, { credentials: 'same-origin' }).then(function (response) {
      if (!response.ok) throw new Error('Failed to load partial: ' + url);
      return response.text();
    });
  }

  function start() {
    if (started) return;
    started = true;
    var placeholders = Array.prototype.slice.call(document.querySelectorAll('[data-partial]'));
    if (!placeholders.length) {
      resolveReady();
      return;
    }
    // Load every partial independently: a single failure degrades to just that
    // section showing an inline error, never blanking the whole SPA. partialsReady
    // always resolves so downstream tab init runs against whatever injected.
    Promise.all(
      placeholders.map(function (placeholder) {
        var name = placeholder.getAttribute('data-partial');
        return fetchPartial(partialBase() + name + '.html')
          .then(function (html) {
            injectPartial(placeholder, html);
          })
          .catch(function (error) {
            console.error(error);
            injectError(placeholder, name);
          });
      })
    ).then(resolveReady);
  }

  window.partialsReady = ready;
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start);
  } else {
    start();
  }
})();
