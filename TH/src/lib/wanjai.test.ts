import { describe, expect, it } from 'vitest';
import { bangkokDay, cleanCompanion, contentFor, zodiacIndex } from './wanjai';

describe('WANJAI content and progress', () => {
  it.each([
    ['1999-02-20', 11],
    ['2000-01-19', 9],
    ['2000-01-20', 10],
    ['2000-03-21', 0],
    ['2000-12-22', 9],
  ] as const)('matches calendar Sun sign for %s', (date, index) =>
    expect(zodiacIndex(date)).toBe(index),
  );
  it('keeps all four languages and complete reference content', () => {
    for (const language of ['zh', 'th', 'vi', 'en'] as const) {
      const data = contentFor(language);
      expect(data.concernLibrary).toHaveLength(10);
      expect(data.products).toHaveLength(6);
      expect(data.lifeChapters).toHaveLength(6);
      for (const concern of data.concernLibrary) {
        const plan = data.solutionLibrary[concern.id as keyof typeof data.solutionLibrary];
        expect(plan.options).toHaveLength(2);
        expect(plan.paths).toHaveLength(2);
        expect(plan.templates).toHaveLength(2);
        expect(plan.branches).toHaveLength(2);
      }
    }
  });
  it('uses Bangkok midnight for the next daily step', () => {
    expect(bangkokDay(new Date('2026-11-04T17:01:00Z'))).toBe('2026-11-05');
  });
  it('keeps valid JY preferences and demo receipts while rejecting broken local storage', () => {
    const receipt = {
      id: 'test-1',
      product: 'moon',
      size: '16 cm',
      quantity: 2,
      total: 980,
      day: '2026-01-01',
    };
    const state = cleanCompanion({
      taste: { style: 'soft', category: 'bracelet', budget: 500 },
      demo_orders: [receipt, { ...receipt, quantity: -1 }, { ...receipt, product: 'bad' }],
    });
    expect(state.taste).toEqual({ style: 'soft', category: 'bracelet', budget: 500 });
    expect(state.demo_orders).toEqual([receipt]);
    expect(
      cleanCompanion({ taste: { style: 'guaranteed-luck', budget: -1 }, demo_orders: 'bad' }).taste,
    ).toEqual({ style: 'any', category: 'all', budget: 1000 });
  });
  it('cleans broken guest state and duplicate progress rather than creating fake access', () => {
    const row = { concern: 'work_change', day: '2026-01-01', feedback: 'hard' };
    const state = cleanCompanion({
      records: [row, row, { ...row, concern: 'unknown' }],
      favorites: ['moon', 'moon', 'bad'],
      demo_unlocks: ['paid-order'],
      topic: 'invalid',
    });
    expect(state.records).toEqual([row]);
    expect(state.favorites).toEqual(['moon']);
    expect(state.demo_unlocks).toEqual([]);
    expect(state.topic).toBe('love');
  });
});
