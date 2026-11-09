import { expect, it } from 'vitest';
import { encodeBirthTime, formatBirthTime } from './birthTime';

it('preserves every local minute across a 12-hour to 24-hour conversion', () => {
  for (let hour = 0; hour < 24; hour++)
    for (let minute = 0; minute < 60; minute++) {
      expect(encodeBirthTime(hour < 12 ? 'am' : 'pm', hour % 12 || 12, minute)).toBe(
        `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`,
      );
    }
});

it('makes the confirmed morning time different from the phone screenshot evening time', () => {
  const t = { am: '上午', pm: '下午', timeUnknown: '未知' };
  expect(encodeBirthTime('am', 7, 15)).toBe('07:15');
  expect(encodeBirthTime('pm', 7, 15)).toBe('19:15');
  expect(formatBirthTime('07:15', t)).toBe('07:15 · 上午');
  expect(formatBirthTime('19:15', t)).toBe('19:15 · 下午');
  expect(formatBirthTime(null, t)).toBe('未知');
});

it('rejects malformed clock values instead of silently changing them', () => {
  for (const [period, hour, minute] of [
    ['am', 0, 0],
    ['pm', 13, 15],
    ['am', 7, 60],
    ['other', 7, 15],
  ] as const)
    expect(() => encodeBirthTime(period, hour, minute)).toThrow(RangeError);
  expect(() => formatBirthTime('25:15', { am: 'AM', pm: 'PM', timeUnknown: '?' })).toThrow(
    RangeError,
  );
});
