// Aries is index 0 in both the Thai engine and the localized sign catalog.
export const ZODIAC_SIGNS = [
  'aries',
  'taurus',
  'gemini',
  'cancer',
  'leo',
  'virgo',
  'libra',
  'scorpio',
  'sagittarius',
  'capricorn',
  'aquarius',
  'pisces',
] as const;

export function zodiacAbbreviation(signIndex: number) {
  return ZODIAC_SIGNS[signIndex]?.slice(0, 3).toUpperCase() ?? '—';
}

export function zodiacArtwork(signIndex: number, size: 96 | 256 = 96) {
  if (!Number.isInteger(signIndex) || signIndex < 0 || signIndex >= ZODIAC_SIGNS.length)
    return null;
  const id = ZODIAC_SIGNS[signIndex];
  const folder = size === 96 ? '/images/zodiac' : '/images/zodiac/illustrated';
  const src = `${folder}/${id}-${size}.webp`;
  return { id, src, srcSet: `${src} 1x, ${folder}/${id}-${size * 2}.webp 2x` };
}
