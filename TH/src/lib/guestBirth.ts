import type { Profile } from '../types';

export const GUEST_BIRTH_KEY = 'wanjai.birth';
export function cleanGuestBirth(value: unknown): Profile | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  const row = value as Partial<Profile>;
  if (typeof row.birth_date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(row.birth_date))
    return null;
  const date = new Date(`${row.birth_date}T12:00:00Z`);
  if (
    !Number.isFinite(date.getTime()) ||
    date.toISOString().slice(0, 10) !== row.birth_date ||
    row.birth_date < '1901-01-01'
  )
    return null;
  const timezone = typeof row.timezone === 'string' ? row.timezone : 'Asia/Bangkok';
  try {
    const today = new Intl.DateTimeFormat('en-CA', {
      timeZone: timezone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(new Date());
    if (row.birth_date > today) return null;
  } catch {
    return null;
  }
  if (
    row.birth_time != null &&
    row.birth_time !== '' &&
    !/^([01]\d|2[0-3]):[0-5]\d$/.test(row.birth_time)
  )
    return null;
  const profile: Profile = {
    display_name: typeof row.display_name === 'string' ? row.display_name.slice(0, 60) : '',
    birth_date: row.birth_date,
    birth_time: row.birth_time || null,
    timezone,
    birthplace: typeof row.birthplace === 'string' ? row.birthplace.slice(0, 100) : '',
    language: ['zh', 'th', 'vi', 'en'].includes(row.language || '') ? row.language! : 'th',
  };
  if (row.gender === 'female' || row.gender === 'male') profile.gender = row.gender;
  if (row.country_code && /^[A-Z]{2}$/.test(row.country_code))
    profile.country_code = row.country_code;
  if (row.location_id && /^geonames:[1-9][0-9]{0,10}$/.test(row.location_id))
    profile.location_id = row.location_id;
  if (
    typeof row.latitude === 'number' &&
    Number.isFinite(row.latitude) &&
    Math.abs(row.latitude) <= 90 &&
    typeof row.longitude === 'number' &&
    Number.isFinite(row.longitude) &&
    Math.abs(row.longitude) <= 180
  ) {
    profile.latitude = row.latitude;
    profile.longitude = row.longitude;
  }
  return profile;
}
export function hasChartBirthDetails(profile: Profile | null) {
  return !!(
    profile?.display_name.trim() &&
    (profile.gender === 'female' || profile.gender === 'male') &&
    profile.birth_date &&
    profile.birthplace.trim() &&
    profile.birth_time !== ''
  );
}
export function readGuestBirth(): Profile | null {
  try {
    return cleanGuestBirth(JSON.parse(localStorage.getItem(GUEST_BIRTH_KEY) || 'null'));
  } catch {
    return null;
  }
}
