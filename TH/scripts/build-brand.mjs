import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { brandSvg } from '../src/lib/brand.ts';

mkdirSync('public/brand', { recursive: true });
const mark = brandSvg();
writeFileSync('public/brand/lotus-star.svg', mark + '\n');
writeFileSync('public/brand/lotus-star-light.svg', brandSvg('#fbf5e8', '#e3c183') + '\n');
writeFileSync(
  'public/favicon.svg',
  brandSvg('#fbf5e8', '#e3c183').replace(
    '><path',
    '><rect width="64" height="64" rx="15" fill="#8d3a31"/><path',
  ) + '\n',
);
const escape = (value) =>
  value.replace(
    /[&<>"']/g,
    (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&apos;' })[c],
  );
for (const code of ['zh-CN', 'th', 'vi', 'en-US']) {
  const t = JSON.parse(readFileSync(`src/locales/${code}.json`, 'utf8'));
  const content = mark.slice(mark.indexOf('>') + 1, mark.lastIndexOf('</svg>'));
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="420" height="126" viewBox="0 0 420 126" role="img" aria-label="${escape(t.brandName)}"><rect width="420" height="126" rx="16" fill="#faf8f4"/><g transform="translate(24 24) scale(1.12)" fill="none" stroke-linecap="round" stroke-linejoin="round">${content}</g><text x="116" y="60" fill="#8d3a31" font-family="${code === 'th' ? 'Noto Sans Thai, Leelawadee UI, Tahoma, sans-serif' : 'Georgia, Microsoft YaHei, serif'}" font-size="34" font-weight="600">${escape(t.brandName)}</text><text x="117" y="87" fill="#94753d" font-family="Noto Sans Thai, Microsoft YaHei, Tahoma, sans-serif" font-size="13">${escape(t.brandTagline)}</text></svg>`;
  writeFileSync(`public/brand/brand-${code}.svg`, svg + '\n');
}
console.log('Generated original lotus/star symbol, favicon and four localized brand lockups.');
