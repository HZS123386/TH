import type { Copy } from './i18n';

export function encodeBirthTime(period: string, hour: number, minute: number) {
  if (
    !['am', 'pm'].includes(period) ||
    !Number.isInteger(hour) ||
    hour < 1 ||
    hour > 12 ||
    !Number.isInteger(minute) ||
    minute < 0 ||
    minute > 59
  )
    throw new RangeError('Invalid birth clock');
  const hour24 = (hour % 12) + (period === 'pm' ? 12 : 0);
  return `${String(hour24).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
}

/** Keep the actual 24-hour value visible and explicitly disambiguate AM/PM. */
export function formatBirthTime(
  value: string | null | undefined,
  t: Pick<Copy, 'am' | 'pm' | 'timeUnknown'>,
) {
  if (!value) return t.timeUnknown;
  if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(value)) throw new RangeError('Invalid birth clock');
  return `${value} · ${Number(value.slice(0, 2)) < 12 ? t.am : t.pm}`;
}
