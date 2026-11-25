/* Shell for formats converted to HTML on the Dart side (RTF, and the legacy
 * binary formats shown as text).
 *
 * There is no rendering engine here: the markup is already in the page. This
 * script only reports readiness, builds an outline and implements search, so
 * the host application gets the same controller surface as every other format.
 */
(function () {
  'use strict';

  const stage = document.getElementById('stage');

  // Legacy DOC/PPT and RTF are reflowed text. There are no original pages:
  // each section is one readable viewport of scroll distance.
  let stride = 1;
  let maxScroll = 0;
  let units = 1;
  let current = -1;
  let scrollFrame = 0;
  let scrollingToSectionUntil = 0;

  function locate(index) {
    const next = Math.max(0, Math.min(units - 1, index));
    if (next === current) return;
    current = next;
    Bridge.send('located', { index: next });
  }

  function measure() {
    stride = Math.max(1, window.innerHeight * 0.82);
    maxScroll = Math.max(0,
      document.documentElement.scrollHeight - window.innerHeight);
    units = maxScroll < 8 ? 1 : Math.ceil(maxScroll / stride) + 1;
    Bridge.send('rendered', { ms: 0, units: units, styled: true, outline: [] });
    locate(window.scrollY >= maxScroll - 2
      ? units - 1 : Math.round(window.scrollY / stride));
  }

  Bridge.on('goto', function (payload) {
    const index = Math.max(0, Math.min(units - 1, Number(payload.index) || 0));
    scrollingToSectionUntil = Date.now() + 900;
    window.scrollTo({ top: Math.min(maxScroll, index * stride), behavior: 'smooth' });
    locate(index);
  });

  window.addEventListener('scroll', function () {
    if (Date.now() < scrollingToSectionUntil) return;
    if (scrollFrame) return;
    scrollFrame = window.requestAnimationFrame(function () {
      scrollFrame = 0;
      locate(window.scrollY >= maxScroll - 2
        ? units - 1 : Math.round(window.scrollY / stride));
    });
  }, { passive: true });
  let resizeTimer = 0;
  window.addEventListener('resize', function () {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(measure, 120);
  });
  if (document.fonts && document.fonts.ready) {
    document.fonts.ready.then(measure);
  }

  Bridge.on('search', function (payload) {
    const query = (payload.query || '').toLocaleLowerCase('tr');

    stage.querySelectorAll('mark.hit').forEach(function (mark) {
      const parent = mark.parentNode;
      parent.replaceChild(document.createTextNode(mark.textContent), mark);
      parent.normalize();
    });

    if (!query) {
      Bridge.send('searchResult', { hits: 0 });
      return;
    }

    let hits = 0;
    const walker = document.createTreeWalker(stage, NodeFilter.SHOW_TEXT);
    const targets = [];
    while (walker.nextNode()) {
      if (walker.currentNode.nodeValue.toLocaleLowerCase('tr').indexOf(query) >= 0) {
        targets.push(walker.currentNode);
      }
    }

    targets.forEach(function (node) {
      const value = node.nodeValue;
      const lower = value.toLocaleLowerCase('tr');
      const fragment = document.createDocumentFragment();
      let cursor = 0;
      let found = lower.indexOf(query, cursor);
      while (found >= 0) {
        fragment.appendChild(document.createTextNode(value.slice(cursor, found)));
        const mark = document.createElement('mark');
        mark.className = 'hit';
        mark.textContent = value.slice(found, found + query.length);
        fragment.appendChild(mark);
        hits++;
        cursor = found + query.length;
        found = lower.indexOf(query, cursor);
      }
      fragment.appendChild(document.createTextNode(value.slice(cursor)));
      node.parentNode.replaceChild(fragment, node);
    });

    const first = stage.querySelector('mark.hit');
    if (first) {
      first.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
    Bridge.send('searchResult', { hits: hits });
  });

  /* The markup is already present, so the bytes handshake is skipped: report
     immediately rather than waiting for a transfer that will never come. */
  Bridge.on('noop', function () {});
  Bridge.send('ready', {});
  measure();

  document.addEventListener('click', function () {
    const selection = window.getSelection();
    if (selection && String(selection).length > 0) {
      return;
    }
    Bridge.send('toggleChrome', {});
  });
})();
