import copy from '../content/western-app.json';
import { referenceContent } from './wanjai';
import { api } from './api';
import { normalizeLanguage } from './languages';
import { cleanGuestBirth } from './guestBirth';
import type { Language, Profile } from '../types';

export type WesternCopy = typeof copy.zh;
export const westernCopy = (language: Language): WesternCopy => copy[language];
export const westernSystem = 'western_natal' as const;
export function westernPlanetName(language: Language, key: WesternPlanetKey): string {
  const labels = {
    sun: 'pSun',
    moon: 'pMoon',
    mercury: 'pMercury',
    venus: 'pVenus',
    mars: 'pMars',
    jupiter: 'pJupiter',
    saturn: 'pSaturn',
    uranus: 'pUranus',
    neptune: 'pNeptune',
    pluto: 'pPluto',
  } as const;
  return westernCopy(language)[labels[key]];
}
export type WesternPlanetKey =
  | 'sun'
  | 'moon'
  | 'mercury'
  | 'venus'
  | 'mars'
  | 'jupiter'
  | 'saturn'
  | 'uranus'
  | 'neptune'
  | 'pluto';
export const westernSymbols: Record<WesternPlanetKey, string> = {
  sun: '☉',
  moon: '☽',
  mercury: '☿',
  venus: '♀',
  mars: '♂',
  jupiter: '♃',
  saturn: '♄',
  uranus: '♅',
  neptune: '♆',
  pluto: '♇',
};
export interface WesternPlanet {
  key: WesternPlanetKey;
  longitude: number;
  house?: number;
}
export type WesternFact =
  | { fact_id: string; kind: 'planet'; value: WesternPlanet }
  | { fact_id: string; kind: 'ascendant'; value: { longitude: number } }
  | { fact_id: string; kind: 'house'; value: { number: number; longitude: number } }
  | {
      fact_id: string;
      kind: 'aspect';
      value: { from: WesternPlanetKey; to: WesternPlanetKey; angle: number };
    };
export interface WesternCalculation {
  result_id: string;
  system: typeof westernSystem;
  status: 'complete' | 'partial';
  input_precision: 'exact_time' | 'date_only';
  engine_version: string;
  ruleset_version: string;
  missing_fields: string[];
  facts: WesternFact[];
}
export interface WesternReportSection {
  key: string;
  title: string;
  paragraphs: string[];
}
export interface WesternReport {
  report_id: string;
  system: typeof westernSystem;
  calculation_result_id: string;
  locale: Language;
  access: 'preview' | 'full';
  summary: string;
  preview: WesternReportSection[];
  sections: WesternReportSection[];
}
export interface WesternProfileRef {
  profile_id: string;
  revision: number;
}

const boundedLongitude = (value: unknown): value is number =>
  typeof value === 'number' && Number.isFinite(value) && value >= 0 && value < 360;
const planetKey = (value: unknown): value is WesternPlanetKey =>
  typeof value === 'string' && Object.prototype.hasOwnProperty.call(westernSymbols, value);
const object = (value: unknown): value is Record<string, unknown> =>
  !!value && typeof value === 'object' && !Array.isArray(value);

export function parseWesternCalculation(raw: unknown): WesternCalculation {
  if (
    !object(raw) ||
    raw.system !== westernSystem ||
    typeof raw.result_id !== 'string' ||
    !['complete', 'partial'].includes(String(raw.status)) ||
    !['exact_time', 'date_only'].includes(String(raw.input_precision)) ||
    typeof raw.engine_version !== 'string' ||
    typeof raw.ruleset_version !== 'string' ||
    !Array.isArray(raw.missing_fields) ||
    !raw.missing_fields.every((field) => typeof field === 'string') ||
    !Array.isArray(raw.facts) ||
    raw.facts.length > 200
  )
    throw new Error('invalid_western_calculation');
  const ids = new Set<string>();
  for (const fact of raw.facts) {
    if (
      !object(fact) ||
      typeof fact.fact_id !== 'string' ||
      ids.has(fact.fact_id) ||
      !object(fact.value)
    )
      throw new Error('invalid_western_fact');
    ids.add(fact.fact_id);
    const value = fact.value;
    if (fact.kind === 'planet') {
      if (
        !planetKey(value.key) ||
        !boundedLongitude(value.longitude) ||
        (value.house !== undefined &&
          (!Number.isInteger(value.house) || Number(value.house) < 1 || Number(value.house) > 12))
      )
        throw new Error('invalid_western_planet');
    } else if (fact.kind === 'house') {
      if (
        !boundedLongitude(value.longitude) ||
        !Number.isInteger(value.number) ||
        Number(value.number) < 1 ||
        Number(value.number) > 12
      )
        throw new Error('invalid_western_house');
    } else if (fact.kind === 'ascendant') {
      if (!boundedLongitude(value.longitude)) throw new Error('invalid_western_ascendant');
    } else if (fact.kind === 'aspect') {
      if (
        !planetKey(value.from) ||
        !planetKey(value.to) ||
        typeof value.angle !== 'number' ||
        !Number.isFinite(value.angle) ||
        value.angle < 0 ||
        value.angle > 180
      )
        throw new Error('invalid_western_aspect');
    } else throw new Error('invalid_western_fact_kind');
    if (
      raw.input_precision === 'date_only' &&
      (fact.kind === 'house' || fact.kind === 'ascendant' || value.house !== undefined)
    )
      throw new Error('time_dependent_fact_without_birth_time');
  }
  const facts = raw.facts as WesternFact[];
  const planets = facts.flatMap((fact) => (fact.kind === 'planet' ? [fact.value] : []));
  if (new Set(planets.map((value) => value.key)).size !== planets.length)
    throw new Error('duplicate_western_planet');
  return raw as unknown as WesternCalculation;
}

export function parseWesternReport(
  raw: unknown,
  resultId: string,
  language: Language,
): WesternReport {
  const sectionsValid = (value: unknown) =>
    Array.isArray(value) &&
    value.length <= 20 &&
    value.every(
      (section) =>
        object(section) &&
        typeof section.key === 'string' &&
        typeof section.title === 'string' &&
        Array.isArray(section.paragraphs) &&
        section.paragraphs.length <= 20 &&
        section.paragraphs.every(
          (text: unknown) => typeof text === 'string' && text.length <= 20_000,
        ),
    );
  if (
    !object(raw) ||
    raw.system !== westernSystem ||
    raw.calculation_result_id !== resultId ||
    typeof raw.report_id !== 'string' ||
    normalizeLanguage(String(raw.locale)) !== language ||
    !['preview', 'full'].includes(String(raw.access)) ||
    typeof raw.summary !== 'string' ||
    !sectionsValid(raw.preview) ||
    !sectionsValid(raw.sections) ||
    (raw.access === 'preview' && (raw.sections as unknown[]).length > 0)
  )
    throw new Error('invalid_western_report');
  return { ...raw, locale: language } as unknown as WesternReport;
}

// These contracts are shared with the future Flutter Repository. The current
// server advertises Western astrology as planned, so callers gate requests.
export async function requestWesternCalculation(
  profile: WesternProfileRef,
  requestKey: string,
  signal?: AbortSignal,
) {
  return parseWesternCalculation(
    await api<unknown>('/api/calculations', {
      method: 'POST',
      signal,
      headers: { 'Idempotency-Key': requestKey },
      body: JSON.stringify({
        system: westernSystem,
        profile_id: profile.profile_id,
        profile_revision: profile.revision,
      }),
    }),
  );
}
export async function requestWesternReport(
  result: WesternCalculation,
  profile: WesternProfileRef,
  language: Language,
  requestKey: string,
  signal?: AbortSignal,
) {
  const created = await api<{ report_id: string }>('/api/life-reports', {
    method: 'POST',
    signal,
    headers: { 'Idempotency-Key': requestKey },
    body: JSON.stringify({
      profile_revision: profile.revision,
      topic: 'natal',
      locale: language,
      calculation_result_id: result.result_id,
    }),
  });
  if (!created || typeof created.report_id !== 'string')
    throw new Error('invalid_report_reference');
  return parseWesternReport(
    await api<unknown>(`/api/life-reports/${encodeURIComponent(created.report_id)}`, { signal }),
    result.result_id,
    language,
  );
}

export const westernPlanets = (result: WesternCalculation) =>
  result.facts.flatMap((fact) => (fact.kind === 'planet' ? [fact.value] : []));
export const westernAscendant = (result: WesternCalculation) =>
  result.facts.find(
    (fact): fact is Extract<WesternFact, { kind: 'ascendant' }> => fact.kind === 'ascendant',
  )?.value.longitude;

// Reuse the existing teaching illustration. It is never calculated from a user
// profile and never stored or promoted as a personal result or entitlement.
export const westernExample: WesternCalculation = {
  result_id: 'western-teaching-example',
  system: westernSystem,
  status: 'complete',
  input_precision: 'exact_time',
  engine_version: 'illustration-only',
  ruleset_version: 'illustration-only',
  missing_fields: ['ascendant', 'houses'],
  facts: [
    ...referenceContent.ASTRO_SAMPLE.planets.map((planet) => ({
      fact_id: `example-${planet.id}`,
      kind: 'planet' as const,
      value: {
        key: planet.id as WesternPlanetKey,
        longitude:
          referenceContent.signs.findIndex((sign) => sign.id === planet.sign) * 30 + planet.degree,
      },
    })),
    ...referenceContent.ASTRO_SAMPLE.aspects.map((aspect, i) => ({
      fact_id: `example-aspect-${i}`,
      kind: 'aspect' as const,
      value: {
        from: aspect.a as WesternPlanetKey,
        to: aspect.b as WesternPlanetKey,
        angle: aspect.angle,
      },
    })),
  ],
};

export function readWesternBirth(owner: string): Profile | null {
  try {
    return cleanGuestBirth(
      JSON.parse(localStorage.getItem(`fate.western.birth.${owner}`) || 'null'),
    );
  } catch {
    return null;
  }
}
export function saveWesternBirth(owner: string, profile: Profile) {
  const clean = cleanGuestBirth(profile);
  if (!clean) throw new Error('invalid_birth_details');
  localStorage.setItem(`fate.western.birth.${owner}`, JSON.stringify(clean));
}
export function clearWesternBirth(owner: string) {
  localStorage.removeItem(`fate.western.birth.${owner}`);
}
export function readWesternExampleSaved(owner: string): number | null {
  try {
    const value: unknown = JSON.parse(
      localStorage.getItem(`fate.western.example.${owner}`) || 'null',
    );
    return typeof value === 'number' && Number.isFinite(value) && value > 0 ? value : null;
  } catch {
    return null;
  }
}
export function saveWesternExample(owner: string) {
  localStorage.setItem(`fate.western.example.${owner}`, JSON.stringify(Date.now()));
}
export function removeWesternExample(owner: string) {
  localStorage.removeItem(`fate.western.example.${owner}`);
}
