/* xlsx kabuğunun mantığı.
 *
 * Bilerek ayrı bir dosya: satır içi `<script>` blokları sıkı CSP altında
 * (`script-src 'self'`, `'unsafe-inline'` yok) çalışmıyor. CSP'yi gevşetmek
 * yerine kodu dışarı aldık — hem politika sıkı kalıyor hem kabuk okunur
 * oluyor. Harici scriptler yükleniyor ama satır içi olan sessizce
 * bloklanıyordu; teşhisi zor bir hataydı, tekrar etmemesi için bu not burada.
 */
(function () {
  'use strict';

  const stage = document.getElementById('stage');
  const tabs = document.getElementById('tabs');
  const rangeNav = document.getElementById('range-nav');
  let sheets = [];
  let activeSheet = -1;
  let currentWindow = null;
  let request = 0;

  const colName = function (index) {
    let label = '';
    for (let n = index + 1; n > 0; n = Math.floor((n - 1) / 26)) {
      label = String.fromCharCode(65 + ((n - 1) % 26)) + label;
    }
    return label;
  };

  /* Spreadsheets are authored for paper, not phones: official forms in
     particular use dozens of narrow columns, so the used range is often three
     or four times the viewport. Left unscaled the sheet reads as broken —
     content pushed off to the right, columns apparently misaligned, borders
     and fills technically present but impossible to take in.

     Scaling preserves every relationship in the sheet and keeps pinch-zoom
     available. When fitting would make text too small, the sheet keeps its
     natural size and scrolls horizontally. */
  const MIN_SCALE = 0.7;

  function fitToWidth() {
    const table = stage.querySelector('table.sheet');
    if (!table) {
      return;
    }
    table.style.transform = '';
    table.style.transformOrigin = 'top left';
    stage.style.height = '';

    const available = stage.clientWidth;
    const natural = table.scrollWidth;
    if (!natural || !available || natural <= available) {
      return;
    }

    const scale = available / natural;
    if (scale < MIN_SCALE) return;
    table.style.transform = 'scale(' + scale + ')';
    // A transformed element keeps its layout box, so the container would
    // otherwise reserve the unscaled height.
    stage.style.height = table.offsetHeight * scale + 'px';
  }

  async function show(index, rowStart, colStart) {
    const sheet = sheets[index];
    if (!sheet) {
      return;
    }
    const ticket = ++request;
    activeSheet = index;
    rangeNav.style.pointerEvents = 'none';
    stage.textContent = 'Cargando hoja…';
    const view = await sheet.renderWindow(
      rowStart == null ? sheet.rowStart : rowStart,
      colStart == null ? sheet.colStart : colStart
    );
    if (ticket !== request) return;
    rangeNav.style.pointerEvents = 'auto';
    sheet.rowStart = view.rowStart;
    sheet.colStart = view.colStart;
    currentWindow = view;
    stage.innerHTML = view.html;
    fitToWidth();
    updateRangeNav();
    Array.prototype.forEach.call(tabs.children, function (button, i) {
      button.setAttribute('aria-selected', String(i === index));
    });
    window.scrollTo(0, 0);
    Bridge.send('located', { index: index, label: sheet.name });
  }

  function navigate(index, rowStart, colStart) {
    show(index, rowStart, colStart).catch(function (error) {
      rangeNav.style.pointerEvents = 'auto';
      Bridge.send('error', { code: 'sheet_failed', detail: String(error) });
    });
  }

  function navigationButton(text, label, action) {
    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = text;
    button.setAttribute('aria-label', label);
    button.addEventListener('click', action);
    rangeNav.appendChild(button);
    return button;
  }

  const previousRows = navigationButton('↑', 'Filas anteriores', function () {
    navigate(activeSheet, Math.max(currentWindow.firstRow,
      currentWindow.rowStart - currentWindow.windowRows), currentWindow.colStart);
  });
  const nextRows = navigationButton('↓', 'Filas siguientes', function () {
    navigate(activeSheet, currentWindow.rowEnd + 1, currentWindow.colStart);
  });
  const previousCols = navigationButton('←', 'Columnas anteriores', function () {
    navigate(activeSheet, currentWindow.rowStart, Math.max(currentWindow.firstCol,
      currentWindow.colStart - currentWindow.windowCols));
  });
  const nextCols = navigationButton('→', 'Columnas siguientes', function () {
    navigate(activeSheet, currentWindow.rowStart, currentWindow.colEnd + 1);
  });
  const jumpRow = document.createElement('input');
  jumpRow.type = 'number';
  jumpRow.setAttribute('aria-label', 'Ir a fila');
  jumpRow.addEventListener('change', function () {
    if (!currentWindow) return;
    const row = Math.max(currentWindow.firstRow,
      Math.min(currentWindow.lastRow, (Number(jumpRow.value) || 1) - 1));
    navigate(activeSheet, row, currentWindow.colStart);
  });
  rangeNav.appendChild(jumpRow);
  const rangeLabel = document.createElement('span');
  rangeLabel.className = 'range-label';
  rangeNav.appendChild(rangeLabel);

  function updateRangeNav() {
    const view = currentWindow;
    if (!view) return;
    const paged = view.rowEnd < view.lastRow || view.colEnd < view.lastCol ||
      view.rowStart > view.firstRow || view.colStart > view.firstCol;
    rangeNav.style.display = paged ? 'flex' : 'none';
    previousRows.disabled = view.rowStart <= view.firstRow;
    nextRows.disabled = view.rowEnd >= view.lastRow;
    previousCols.disabled = view.colStart <= view.firstCol;
    nextCols.disabled = view.colEnd >= view.lastCol;
    jumpRow.min = String(view.firstRow + 1);
    jumpRow.max = String(view.lastRow + 1);
    jumpRow.value = String(view.rowStart + 1);
    rangeLabel.textContent = 'Filas ' + (view.rowStart + 1) + '–' +
      (view.rowEnd + 1) + ' de ' + (view.lastRow + 1) +
      ' · Columnas ' + colName(view.colStart) + '–' +
      colName(view.colEnd) + ' de ' + colName(view.lastCol);
  }

  function buildTabs() {
    tabs.innerHTML = '';
    if (sheets.length < 2) {
      return;
    }
    sheets.forEach(function (sheet, i) {
      const button = document.createElement('button');
      button.type = 'button';
      button.setAttribute('role', 'tab');
      button.textContent = sheet.name;
      button.addEventListener('click', function () {
        navigate(i);
      });
      tabs.appendChild(button);
    });
  }

  async function render(bytes) {
    const started = performance.now();
    const result = await XlsxRender.render(
      bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength)
    );

    sheets = result.sheets;
    buildTabs();
    await show(0);

    // Rotation and split-view change the available width.
    window.addEventListener('resize', fitToWidth);

    Bridge.send('rendered', {
      ms: Math.round(performance.now() - started),
      units: sheets.length,
      styled: result.styled,
      truncated: false,
      outline: sheets.map(function (sheet) {
        return sheet.name;
      })
    });
  }

  Bridge.on('goto', function (payload) {
    navigate(payload.index);
  });

  Bridge.on('search', function (payload) {
    // Türkçe'de büyük/küçük harf eşlemesi İ/ı yüzünden yerel ayara duyarlı.
    const query = (payload.query || '').toLocaleLowerCase('tr');
    let hits = 0;
    stage.querySelectorAll('td').forEach(function (cell) {
      cell.classList.remove('hit');
      if (query && cell.textContent.toLocaleLowerCase('tr').indexOf(query) >= 0) {
        cell.classList.add('hit');
        hits++;
      }
    });
    Bridge.send('searchResult', { hits: hits });
  });

  Bridge.start(render);
})();
