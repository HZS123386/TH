import copy from '../content/thai-test.json';
import type { Language, Profile } from '../types';
import type { ThaiChart } from './thai';
import { localeFor } from './languages';

export type ThaiReading = keyof typeof copy.zh.readings;
export const thaiReadingCopy = (language: Language) => copy[language];
export interface ThaiReadingInput {
  profile: Profile;
  reading: ThaiReading;
  year: number;
}
export interface ThaiReadingResult {
  report_id: string;
  generated_at: string;
  input: ThaiReadingInput;
  natal: ThaiChart;
  report: {
    title: string;
    summary: string | null;
    language: Language;
    sections: {
      id: string;
      title: string;
      items: {
        title: string;
        text: string;
        period: { year: number; month: number } | null;
        steps?: string[];
        example?: string;
        signals?: string[];
        response?: string;
        pitfall?: string;
        check?: string;
      }[];
    }[];
    generation: {
      state: 'ready' | 'pending' | 'limited' | 'unavailable' | 'unconfigured';
      version: string;
    };
  };
}

export function thaiPeriodLabel(period: { year: number; month: number }, language: Language) {
  return new Intl.DateTimeFormat(localeFor(language), {
    year: 'numeric',
    month: 'long',
    calendar: 'gregory',
    timeZone: 'UTC',
  }).format(new Date(Date.UTC(period.year, period.month - 1, 1)));
}

export function thaiReportHtml(result: ThaiReadingResult, detailsUnlocked: boolean) {
  const b = thaiReadingCopy(result.report.language);
  const escape = (value: string) =>
    value.replace(
      /[&<>"']/g,
      (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]!,
    );
  const birth = result.input.profile;
  const sections = result.report.sections
    .map((section) =>
      !detailsUnlocked && section.id !== 'interpretation'
        ? section.id === 'opportunities'
          ? `<section><h2>${escape(section.title)}</h2><p>${escape(b.lockedSave)}</p></section>`
          : ''
        : `<section><h2>${escape(section.title)}</h2>${section.items.map((item, index) => `<article>${item.period ? `<p class="period">${escape(thaiPeriodLabel(item.period, result.report.language))}</p>` : ''}<h3>${section.id === 'advice' ? `${index + 1}. ` : ''}${escape(item.title)}</h3><p>${escape(item.text)}</p>${item.signals ? `<strong>${escape(b.signals)}</strong><ul>${item.signals.map((signal) => `<li>${escape(signal)}</li>`).join('')}</ul>` : ''}${item.response ? `<strong>${escape(b.response)}</strong><p>${escape(item.response)}</p>` : ''}${item.steps ? `<ol>${item.steps.map((step) => `<li>${escape(step)}</li>`).join('')}</ol>` : ''}${item.example ? `<div class="example"><strong>${escape(b.example)}</strong><p>${escape(item.example)}</p></div>` : ''}${item.pitfall ? `<strong>${escape(b.pitfall)}</strong><p>${escape(item.pitfall)}</p>` : ''}${item.check ? `<strong>${escape(b.check)}</strong><p>${escape(item.check)}</p>` : ''}</article>`).join('')}</section>`,
    )
    .join('');
  const state = result.report.generation.state;
  return `<!doctype html><html lang="${result.report.language}"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${escape(result.report.title)}</title><style>body{max-width:780px;margin:40px auto;padding:0 24px;color:#493d34;background:#fffdf8;font:16px/1.9 system-ui,sans-serif}h1,h2{color:#a45338}h2{font-size:20px}h3{font-size:17px;margin-bottom:6px}section{border-top:1px solid #e4d9cb;margin-top:28px;padding-top:12px}article{margin:20px 0}p{overflow-wrap:anywhere}.summary{padding:20px;background:#fcf3df;border:1px solid #dbc08f;border-radius:16px}.summary p{font-size:20px;margin-bottom:0}.period{color:#9b713e;font-size:13px;margin-bottom:4px}@media print{body{margin:0}}</style><h1>${escape(result.report.title)}</h1><p>${escape(b.results)} · ${escape(birth.birth_date)} · ${escape(birth.birth_time || '')} · ${escape(birth.timezone)}</p>${result.input.reading === 'annual' ? `<p>${escape(b.year)} · ${result.input.year}</p>` : ''}${result.report.summary ? `<section class="summary"><h2>${escape(b.summary)}</h2><p>${escape(result.report.summary)}</p></section>` : ''}${sections}${state !== 'ready' ? `<p>${escape(b.states[state])}</p>` : ''}</html>`;
}
