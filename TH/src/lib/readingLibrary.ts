export interface SavedReading {
  id: string;
  title: string;
  birthDate: string;
  savedAt: number;
  html: string;
}

const libraryKey = (owner: string) => `astro.saved-readings.v1.${owner}`;
const maximumSaved = 5;

export function readSavedReadings(owner: string): SavedReading[] {
  try {
    const rows: unknown = JSON.parse(localStorage.getItem(libraryKey(owner)) || '[]');
    if (!Array.isArray(rows)) return [];
    return rows
      .filter(
        (row): row is SavedReading =>
          !!row &&
          typeof row.id === 'string' &&
          /^[a-zA-Z0-9-]{1,64}$/.test(row.id) &&
          typeof row.title === 'string' &&
          row.title.length <= 150 &&
          typeof row.birthDate === 'string' &&
          /^\d{4}-\d{2}-\d{2}$/.test(row.birthDate) &&
          Number.isFinite(row.savedAt) &&
          typeof row.html === 'string' &&
          row.html.startsWith('<!doctype html>') &&
          row.html.length <= 500_000,
      )
      .slice(0, maximumSaved);
  } catch {
    return [];
  }
}

export function saveReading(owner: string, reading: SavedReading) {
  if (reading.html.length > 500_000) throw new Error('Report is too large to save');
  const rows = [reading, ...readSavedReadings(owner).filter((row) => row.id !== reading.id)].slice(
    0,
    maximumSaved,
  );
  localStorage.setItem(libraryKey(owner), JSON.stringify(rows));
}

export function removeSavedReading(owner: string, id: string) {
  const rows = readSavedReadings(owner).filter((row) => row.id !== id);
  localStorage.setItem(libraryKey(owner), JSON.stringify(rows));
  return rows;
}

export function captureReading(element: HTMLElement, title: string): string {
  const clone = element.cloneNode(true) as HTMLElement;
  clone.querySelectorAll('[data-planet-choice]').forEach((button) => {
    const item = document.createElement('div');
    item.innerHTML = button.innerHTML;
    button.replaceWith(item);
  });
  clone
    .querySelectorAll('button,nav,[data-testid="reading-library-actions"]')
    .forEach((node) => node.remove());
  clone
    .querySelectorAll('[data-testid="reading-summary"] li > span:first-child')
    .forEach((node) => node.remove());
  clone.querySelectorAll('[data-planet],[data-link]').forEach((node) => {
    node.setAttribute('opacity', '1');
  });
  clone.querySelectorAll('img').forEach((node) => {
    const label = document.createElement('span');
    label.textContent = node.alt;
    node.replaceWith(label);
  });
  clone.querySelectorAll('details').forEach((node) => {
    node.open = true;
  });
  clone.querySelectorAll('[tabindex]').forEach((node) => {
    node.removeAttribute('tabindex');
    if (node.getAttribute('role') === 'button') node.removeAttribute('role');
  });
  const heading = document.createElement('title');
  heading.textContent = title;
  return `<!doctype html><html lang="${document.documentElement.lang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">${heading.outerHTML}<style>
    :root{--c-gold:228 188 120;--c-surface:39 23 61;--c-canvas:19 12 36;--c-muted:180 168 198;--c-ink:255 245 223;--c-line:72 51 87}
    *{box-sizing:border-box}body{margin:0;background:#130c24;color:#eee5f3;font:15px/1.9 system-ui,sans-serif}main{max-width:760px;margin:auto;padding:24px}h1,h2,h3,h4{color:#e4bc78;line-height:1.5}h3>span{margin-left:8px;display:inline-block;font-size:13px;color:#b4a8c6}section{margin:28px 0}article,details{margin:14px 0;padding:12px 0;border-bottom:1px solid #483357}summary{font-weight:600}p{margin:10px 0}svg{width:22px;height:22px}figure{margin:20px 0}figure>svg{width:100%;height:auto}dl{display:grid;grid-template-columns:auto 1fr;gap:8px}dd{margin:0}li{margin:8px 0}.sr-only{display:none}[data-testid=reading-planet-selector]{display:grid;grid-template-columns:repeat(5,1fr);gap:8px;text-align:center}[data-planet-circle]{display:block;font-size:28px}[data-share-percent]{display:block;font-size:12px}[data-element]{display:inline-block;width:24%;text-align:center}#reading-overview article{display:inline-block;width:49%;vertical-align:top}img{max-width:72px;height:auto}small{color:#b4a8c6}@media print{body{background:white;color:#302838}h1,h2,h3,h4{color:#503466}details,article{break-inside:avoid}}
    </style></head><body><main>${clone.innerHTML}</main></body></html>`;
}

export function downloadReading(reading: SavedReading) {
  const url = URL.createObjectURL(new Blob([reading.html], { type: 'text/html;charset=utf-8' }));
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = `FATE-${reading.birthDate}-${reading.id}.html`;
  anchor.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
