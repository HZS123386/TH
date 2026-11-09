import copies from '../content/bazi-test.json';
import type { Chart, Language, Profile } from '../types';
import { baziFactBlocks } from './baziFacts';
import { baziElementName, baziPillarName } from './baziLocale';

export const baziCopy = (language: Language) => copies[language];
export type BaziSource = 'compare' | 'github' | 'roxy';
export type BaziTopic = 'chart' | 'strength' | 'luck' | 'annual';
export type BaziFocus = 'overview' | 'work' | 'love' | 'money' | 'family';
export type BaziReading = BaziFocus | 'annual';
export const baziReadingTopics: Record<BaziReading, BaziTopic[]> = {
  overview: ['chart', 'strength'],
  work: ['chart', 'strength'],
  love: ['chart', 'strength'],
  money: ['chart', 'strength'],
  family: ['chart', 'strength'],
  annual: ['chart', 'annual'],
};
export interface BaziTestInput {
  profile: Profile;
  source: BaziSource;
  topics: BaziTopic[];
  clock: 'local' | 'beijing';
  focus: BaziFocus;
  gender: 'male' | 'female' | null;
  year: number;
}
export interface BaziTestResult {
  report_id: string;
  generated_at: string;
  input: BaziTestInput;
  calculation_input: Record<string, string | null>;
  sources: Partial<
    Record<
      'github' | 'roxy',
      {
        status: 'ready' | 'partial' | 'unavailable';
        chart: Chart | null;
        details?: Partial<
          Record<BaziTopic, { data: Record<string, unknown>; cached: boolean; language: string }>
        >;
        errors?: Record<string, string>;
      }
    >
  >;
  comparison: {
    status: 'match' | 'different' | 'partial';
    rows: {
      pillar: 'year' | 'month' | 'day' | 'hour';
      github: string | null;
      roxy: string | null;
      match: boolean | null;
    }[];
    scope: string;
  };
  report: {
    title: string;
    language: Language;
    translations?: Record<string, string>;
    generation?: { state: string; cached?: boolean; version?: string };
    sections: {
      id: string;
      title: string;
      source: string;
      paragraphs: string[];
      language?: string;
    }[];
  };
}

const escape = (text: unknown) =>
  String(text ?? '').replace(
    /[&<>"']/g,
    (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]!,
  );

export function baziReportHtml(result: BaziTestResult) {
  const copy = baziCopy(result.report.language);
  const names = {
    year: copy.yearPillar,
    month: copy.monthPillar,
    day: copy.dayPillar,
    hour: copy.hourPillar,
  };
  const tables = Object.entries(result.sources)
    .map(([, value]) => {
      const chart = value.chart;
      const errors = Object.values(value.errors || {})
        .map((code) => (copy.roxyErrors as Record<string, string>)[code] || code)
        .join(' · ');
      const details = Object.entries(value.details || {})
        .map(([topic, detail]) => {
          if (!detail) return '';
          const blocks = baziFactBlocks(
            topic as BaziTopic,
            detail.data,
            result.report.language,
            result.report.translations,
          );
          return `<h3>${escape(copy[topic as BaziTopic])}</h3>${blocks
            .map(
              (block) =>
                `${(block.paragraphs || []).map((text) => `<p>${escape(text)}</p>`).join('')}${
                  block.columns
                    ? `<table><thead><tr>${block.columns.map((column) => `<th>${escape(column)}</th>`).join('')}</tr></thead><tbody>${(block.rows || []).map((row) => `<tr>${row.map((cell) => `<td>${escape(cell)}</td>`).join('')}</tr>`).join('')}</tbody></table>`
                    : ''
                }`,
            )
            .join('')}`;
        })
        .join('');
      return `<section><h2>${escape(copy.chart)}</h2><p>${escape(errors)}</p>${
        chart
          ? `<table><tr>${Object.values(names)
              .map((n) => `<th>${escape(n)}</th>`)
              .join('')}</tr><tr>${Object.keys(names)
              .map(
                (n) =>
                  `<td>${escape(baziPillarName(chart.pillars[n as keyof Chart['pillars']], result.report.language))}</td>`,
              )
              .join('')}</tr></table><p>${escape(copy.elements)}: ${Object.entries(
              chart.visible_element_counts,
            )
              .map(([k, v]) => `${escape(baziElementName(k, result.report.language))} ${escape(v)}`)
              .join(' · ')}</p>`
          : ''
      }${details}</section>`;
    })
    .join('');
  const paragraphs = result.report.sections
    .filter((section) => !['focus', 'scope'].includes(section.id))
    .map(
      (section) =>
        `<section><h2>${escape(section.title)}</h2>${section.paragraphs.map((text) => `<p>${escape(text)}</p>`).join('')}</section>`,
    )
    .join('');
  const comparison =
    result.input.source === 'compare' ? `<p>${escape(copy[result.comparison.status])}</p>` : '';
  const state = result.report.generation?.state;
  const generation =
    state && state !== 'ready'
      ? `<p>${escape((copy.reportStates as Record<string, string>)[state] || copy.reportStates.unavailable)}</p>`
      : '';
  return `<!doctype html><html lang="${escape(result.report.language)}"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${escape(result.report.title)}</title><style>body{max-width:820px;margin:40px auto;padding:0 22px;font:16px/1.9 system-ui,sans-serif;color:#292321}h1{font-size:27px}h2{font-size:20px;margin-top:30px}.source{color:#74675e;font-size:13px}table{width:100%;border-collapse:collapse}td,th{border:1px solid #ddd;padding:12px;text-align:center}section{break-inside:avoid}@media print{body{margin:0}}</style><h1>${escape(result.report.title)}</h1><p>${escape(result.input.profile.display_name)} ${escape(result.input.profile.birth_date)} · ${escape(result.input.profile.birth_time || '—')} · ${escape(result.input.profile.timezone)}</p><p class="source">${escape(copy.timing)} ${escape(result.generated_at)} · ${escape(result.report_id)}</p>${tables}${comparison}${generation}${paragraphs}</html>`;
}
