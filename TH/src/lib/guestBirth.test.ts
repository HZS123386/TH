import { expect, it } from 'vitest';
import { cleanGuestBirth, hasChartBirthDetails } from './guestBirth';

const profile = {
  display_name: 'Nok',
  gender: 'female' as const,
  birth_date: '1999-02-20',
  birth_time: '09:15',
  birthplace: 'Bangkok',
  timezone: 'Asia/Bangkok',
  language: 'zh' as const,
};

it('retains gender and birth details when restoring a guest profile', () => {
  const restored = cleanGuestBirth(JSON.parse(JSON.stringify(profile)));
  expect(restored).toMatchObject(profile);
  expect(hasChartBirthDetails(restored)).toBe(true);
  expect(hasChartBirthDetails(cleanGuestBirth({ ...profile, gender: 'invalid' }))).toBe(false);
});

it('requires the chart setup fields but preserves an explicitly unknown birth time', () => {
  expect(hasChartBirthDetails(null)).toBe(false);
  expect(hasChartBirthDetails({ ...profile, display_name: '   ' })).toBe(false);
  expect(hasChartBirthDetails({ ...profile, gender: null })).toBe(false);
  expect(hasChartBirthDetails({ ...profile, birthplace: '' })).toBe(false);
  expect(hasChartBirthDetails({ ...profile, birth_time: '' })).toBe(false);
  expect(hasChartBirthDetails({ ...profile, birth_time: null })).toBe(true);
});
