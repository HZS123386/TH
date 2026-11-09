import { ZODIAC_SIGNS, zodiacArtwork } from '../lib/zodiac';

/** Decorative zodiac artwork, not a calculated natal chart. */
export function ZodiacWheel({
  className = '',
  monochrome = false,
}: {
  className?: string;
  monochrome?: boolean;
}) {
  const point = (angle: number, radius: number) => ({
    x: 180 + Math.cos((angle * Math.PI) / 180) * radius,
    y: 180 + Math.sin((angle * Math.PI) / 180) * radius,
  });
  return (
    <svg viewBox="0 0 360 360" className={className} fill="none" aria-hidden="true">
      <circle
        cx="180"
        cy="180"
        r="164"
        stroke="currentColor"
        strokeOpacity=".85"
        strokeWidth="1.2"
      />
      <circle cx="180" cy="180" r="170" stroke="currentColor" strokeOpacity=".12" strokeWidth="5" />
      <circle cx="180" cy="180" r="150" stroke="currentColor" strokeOpacity=".4" strokeWidth=".7" />
      <circle cx="180" cy="180" r="113" stroke="currentColor" strokeOpacity=".5" strokeWidth=".7" />
      <circle
        cx="180"
        cy="180"
        r="90"
        stroke="currentColor"
        strokeOpacity=".2"
        strokeDasharray="2 5"
      />
      {Array.from({ length: 72 }, (_, i) => {
        const from = point(i * 5, i % 6 === 0 ? 107 : 145);
        const to = point(i * 5, 150);
        return (
          <path
            key={i}
            d={`M${from.x} ${from.y}L${to.x} ${to.y}`}
            stroke="currentColor"
            strokeWidth=".7"
            strokeOpacity={i % 6 === 0 ? '.5' : '.3'}
          />
        );
      })}
      {ZODIAC_SIGNS.map((sign, i) => {
        const p = point(i * 30 + 15, 132);
        return (
          <image
            key={sign}
            href={zodiacArtwork(i)!.src}
            x={p.x - 16}
            y={p.y - 16}
            width={32}
            height={32}
            preserveAspectRatio="xMidYMid meet"
            opacity={monochrome ? '.14' : '.85'}
          />
        );
      })}
      <path
        d="m117 198 97-56-56 101-41-45 123 12-81-89-1 122"
        stroke={monochrome ? 'currentColor' : '#be9bf7'}
        strokeWidth="1"
        strokeOpacity=".7"
      />
      <path
        d="m117 198 42-77 55 21 26 68-82 33"
        stroke={monochrome ? 'currentColor' : '#8ebfea'}
        strokeWidth=".8"
        strokeOpacity=".6"
      />
      <path
        d="m159 121 55 21-56 101 82-33"
        stroke={monochrome ? 'currentColor' : '#eda3c8'}
        strokeWidth=".8"
        strokeOpacity=".65"
      />
      {[
        { angle: 36, color: '#eed197' },
        { angle: 112, color: '#d6c6fa' },
        { angle: 206, color: '#9fcdf1' },
        { angle: 284, color: '#eab1d9' },
      ].map(({ angle, color }) => {
        const p = point(angle, 103);
        return (
          <g key={angle}>
            <circle
              cx={p.x}
              cy={p.y}
              r="8"
              fill={monochrome ? 'currentColor' : color}
              opacity=".1"
            />
            <circle cx={p.x} cy={p.y} r="3.5" fill={monochrome ? 'currentColor' : color} />
          </g>
        );
      })}
      <circle cx="180" cy="180" r="3" fill={monochrome ? 'currentColor' : '#eed197'} />
    </svg>
  );
}
