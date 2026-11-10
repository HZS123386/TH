import { beforeEach, describe, expect, it } from 'vitest';
import { parseWesternCalculation, parseWesternReport, readWesternBirth, saveWesternBirth, readWesternExampleSaved, saveWesternExample, westernCopy, westernExample, westernSymbols } from './western';
import type { Language, Profile } from '../types';

const trial = {
  report_id: 'report-1', system: 'western_natal', calculation_result_id: westernExample.result_id,
  locale: 'zh', access: 'preview', summary: '一份试读',
  preview: [{ key: 'traits', title: '特点', paragraphs: ['试读内容'] }], sections: [],
};

beforeEach(() => localStorage.clear());
describe('Western facts and report boundaries', () => {
  it('accepts a Western response but rejects a different calculation system', () => {
    expect(parseWesternCalculation(westernExample).facts.length).toBeGreaterThan(0);
    expect(() => parseWesternCalculation({ ...westernExample, system: 'thai_natal' })).toThrow();
  });
  it('rejects missing-time houses, ascendant and planet house positions', () => {
    const dateOnly = { ...westernExample, input_precision: 'date_only' };
    expect(parseWesternCalculation(dateOnly).input_precision).toBe('date_only');
    for (const fact of [
      { fact_id: 'asc', kind: 'ascendant', value: { longitude: 30 } },
      { fact_id: 'house1', kind: 'house', value: { number: 1, longitude: 30 } },
      { fact_id: 'planet-with-house', kind: 'planet', value: { key: 'sun', longitude: 30, house: 1 } },
    ]) expect(() => parseWesternCalculation({ ...dateOnly, facts: [fact] })).toThrow('time_dependent_fact_without_birth_time');
  });
  it('rejects invalid and duplicate positions, including inherited object keys', () => {
    for (const value of [{ key: 'sun', longitude: 360 }, { key: 'constructor', longitude: 20 }, { key: 'moon', longitude: NaN }])
      expect(() => parseWesternCalculation({ ...westernExample, facts: [{ fact_id: 'bad', kind: 'planet', value }] })).toThrow();
    const first = westernExample.facts[0];
    expect(() => parseWesternCalculation({ ...westernExample, facts: [first, { ...first, fact_id: 'another-id' }] })).toThrow('duplicate_western_planet');
  });
  it('requires the expected result and language, and does not accept paid body in a trial response', () => {
    expect(parseWesternReport(trial, westernExample.result_id, 'zh').access).toBe('preview');
    expect(() => parseWesternReport(trial, 'another-result', 'zh')).toThrow();
    expect(() => parseWesternReport(trial, westernExample.result_id, 'th')).toThrow();
    expect(() => parseWesternReport({ ...trial, sections: [{ key: 'paid', title: '完整', paragraphs: ['私有报告正文'] }] }, westernExample.result_id, 'zh')).toThrow();
  });
  it('keeps per-account local birth data and example bookmarks separate from entitlements', () => {
    const profile: Profile = { display_name: '', birth_date: '1999-02-20', birth_time: null, birthplace: 'Bangkok', timezone: 'Asia/Bangkok', language: 'th' };
    saveWesternBirth('owner-a', profile);
    saveWesternExample('owner-a');
    expect(readWesternBirth('owner-b')).toBeNull();
    expect(readWesternExampleSaved('owner-b')).toBeNull();
    expect(readWesternBirth('owner-a')?.birth_time).toBeNull();
    expect(readWesternExampleSaved('owner-a')).toEqual(expect.any(Number));
    expect(Object.keys(localStorage).sort()).toEqual(['fate.western.birth.owner-a', 'fate.western.example.owner-a']);
  });
  it('has matching, nonempty copy and every planet explanation in all four languages', () => {
    const keys = Object.keys(westernCopy('zh')).sort();
    for (const language of ['zh', 'th', 'en', 'vi'] as Language[]) {
      const copy = westernCopy(language);
      expect(Object.keys(copy).sort()).toEqual(keys);
      expect(Object.values(copy).every((value) => typeof value === 'string' && value.trim())).toBe(true);
      for (const planet of Object.keys(westernSymbols))
        expect(copy[`${planet}Meaning` as keyof typeof copy]).toBeTruthy();
    }
  });
});
