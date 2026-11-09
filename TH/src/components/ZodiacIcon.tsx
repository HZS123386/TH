import { zodiacArtwork } from '../lib/zodiac';

export function ZodiacIcon({
  signIndex,
  name,
  className = 'h-12 w-12',
}: {
  signIndex: number;
  name: string;
  className?: string;
}) {
  const artwork = zodiacArtwork(signIndex);
  if (!artwork) return null;
  return (
    <img
      src={artwork.src}
      srcSet={artwork.srcSet}
      alt={name}
      width={96}
      height={96}
      decoding="async"
      draggable={false}
      data-zodiac-sign={artwork.id}
      className={`shrink-0 object-contain ${className}`}
    />
  );
}
