import type { Language } from '../types';
import type { BaziTopic } from './bazi';
import {
  baziElementName,
  baziFactorNames,
  baziGodName,
  baziPillarName,
  baziProseMatches,
  baziStemName,
} from './baziLocale';

import terms from '../content/bazi-terms.json';
const verdicts: Record<Language, Record<string, string>> = terms.verdicts;
const labels = terms.labels;
const object = (value: unknown): Record<string, unknown> =>
  value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
const text = (value: unknown) =>
  typeof value === 'string' || typeof value === 'number' ? String(value) : '—';
const list = (value: unknown): unknown[] => (Array.isArray(value) ? value : []);
const pillar = (value: unknown, language: Language) => {
  const row = object(value);
  return baziPillarName(
    text(object(row.stem).chinese) + text(object(row.branch).chinese),
    language,
  );
};

export interface BaziFactBlock {
  paragraphs?: string[];
  columns?: string[];
  rows?: string[][];
}

export function baziFactBlocks(
  operation: BaziTopic,
  data: Record<string, unknown>,
  language: Language,
  translations: Record<string, string> = {},
): BaziFactBlock[] {
  const l = labels[language];
  const god = (value: unknown) => baziGodName(object(value), language);
  const prose = (key: string, raw: unknown) => {
    const value = translations[key] || raw;
    return baziProseMatches(value, language) ? value : '';
  };
  if (operation === 'chart')
    return [
      {
        paragraphs: [
          `${l[0]} · ${baziStemName(object(data.dayMaster).chinese, language)} · ${baziElementName(object(data.dayMaster).elementLocalized || object(data.dayMaster).element, language)}`,
        ],
      },
    ];
  if (operation === 'strength')
    return [
      {
        paragraphs: [
          `${l[0]} · ${verdicts[language][text(data.verdict)] || text(data.verdict)} · ${l[1]} ${text(data.score)}`,
          ...list(data.factors).map((item, index) => {
            const row = object(item);
            const detail = prose(`strength.factors.${index}.detail`, row.detail);
            return `${baziFactorNames[language][index] || '—'} · ${text(row.contribution)}${detail ? ' · ' + detail : ''}`;
          }),
          `${l[4]} · ${
            list(data.favorableElements)
              .map((element) => baziElementName(element, language))
              .join(' / ') || '—'
          }`,
          `${l[5]} · ${
            list(data.unfavorableElements)
              .map((element) => baziElementName(element, language))
              .join(' / ') || '—'
          }`,
        ],
      },
    ];
  if (operation === 'luck')
    return [
      { paragraphs: [`${l[6]} · ${text(data.startAge)}`] },
      {
        columns: [l[7], l[8], l[9], l[10]],
        rows: list(data.luckPillars).map((item) => {
          const row = object(item);
          return [
            pillar(row, language),
            `${text(row.startAge)}–${text(row.endAge)}`,
            `${text(row.startYear)}–${text(row.endYear)}`,
            god(row.tenGod),
          ];
        }),
      },
    ];
  return [
    {
      paragraphs: [
        `${text(data.year)} · ${pillar(data.annualPillar, language)} · ${god(data.tenGod)}`,
        ...(prose('annual.yearBranchRelationMeaning', data.yearBranchRelationMeaning)
          ? [prose('annual.yearBranchRelationMeaning', data.yearBranchRelationMeaning)]
          : []),
      ],
    },
  ];
}
