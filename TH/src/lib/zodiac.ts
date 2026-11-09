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

export function zodiacArtwork(signIndex: number) {
  if (!Number.isInteger(signIndex) || signIndex < 0 || signIndex >= ZODIAC_SIGNS.length)
    return null;
  const id = ZODIAC_SIGNS[signIndex];
  const src = `/images/zodiac/${id}-96.webp`;
  return { id, src, srcSet: `${src} 1x, /images/zodiac/${id}-192.webp 2x` };
}
