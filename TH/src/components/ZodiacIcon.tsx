import { zodiacArtwork } from '../lib/zodiac';

export function ZodiacIcon({
  signIndex,
  name,
  className = 'h-12 w-12',
  large = false,
}: {
  signIndex: number;
  name: string;
  className?: string;
  large?: boolean;
}) {
  const artwork = zodiacArtwork(signIndex, large ? 256 : 96);
  if (!artwork) return null;
  return (
    <img
      src={artwork.src}
      srcSet={artwork.srcSet}
      alt={name}
      width={large ? 256 : 96}
      height={large ? 256 : 96}
      decoding="async"
      draggable={false}
      data-zodiac-sign={artwork.id}
      className={`shrink-0 object-contain ${className}`}
    />
  );
}
