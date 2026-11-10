import { referenceContent } from '../lib/wanjai';
import { BrandMark } from './BrandMark';
import { zodiacArtwork } from '../lib/zodiac';

export function WanjaiMark({ className = 'h-9 w-9' }: { className?: string }) {
  return <BrandMark className={className} />;
}
export function ProductArt({
  color,
  dark,
  type,
  title,
}: {
  color: string;
  dark: string;
  type: string;
  title: string;
}) {
  return (
    <svg role="img" aria-label={title} viewBox="0 0 280 210" className="h-full w-full">
      <defs>
        <radialGradient id={`bead-${dark.replace('#', '')}`} cx="28%" cy="25%">
          <stop offset="0" stopColor="#fffefa" stopOpacity=".9" />
          <stop offset=".35" stopColor={color} />
          <stop offset="1" stopColor={dark} />
        </radialGradient>
      </defs>
      <ellipse cx="140" cy="173" rx="73" ry="10" fill={dark} opacity=".08" />
      {type === 'bracelet' ? (
        Array.from({ length: 18 }, (_, i) => {
          const a = (i * Math.PI) / 9;
          return (
            <circle
              key={i}
              cx={140 + Math.cos(a) * 61}
              cy={103 + Math.sin(a) * 48}
              r="11.5"
              fill={`url(#bead-${dark.replace('#', '')})`}
              stroke={dark}
              strokeOpacity=".2"
            />
          );
        })
      ) : type === 'charm' ? (
        <g stroke="#b7975a" fill={color}>
          <path d="M140 28v42" fill="none" />
          <circle cx="140" cy="84" r="13" fill="none" />
          <path d="m140 92 12 25 27 4-20 20 5 28-24-13-24 13 5-28-20-20 27-4Z" strokeWidth="2" />
        </g>
      ) : (
        <g stroke={dark} strokeWidth="1.2">
          <path d="m140 37 35 34 14 76-47 26-50-28 14-71Z" fill={color} />
          <path
            d="m140 37 5 136m-39-99 39 99 30-102m-83 74 53-43 44 45"
            fill="none"
            opacity=".35"
          />
          <path d="m140 37-10 46-24-9Z" fill="#fffefa" opacity=".4" />
        </g>
      )}
      <path d="M220 49v14m-7-7h14M61 133v10m-5-5h10" stroke="#b7975a" opacity=".55" />
    </svg>
  );
}

export function TeachingWheel() {
  const planets = referenceContent.ASTRO_SAMPLE.planets;
  const point = (id: string) => {
    const planet = planets.find((p) => p.id === id)!;
    const angle =
      ((referenceContent.signs.findIndex((s) => s.id === planet.sign) * 30 + planet.degree - 90) *
        Math.PI) /
      180;
    return { x: 210 + Math.cos(angle) * 118, y: 210 + Math.sin(angle) * 118 };
  };
  return (
    <svg
      viewBox="0 0 420 420"
      className="mx-auto w-full max-w-[420px] text-gold"
      aria-hidden="true"
    >
      <circle cx="210" cy="210" r="191" fill="rgb(var(--c-canvas))" stroke="currentColor" strokeWidth="1.2" />
      {[168, 142, 118].map((r) => (
        <circle
          key={r}
          cx="210"
          cy="210"
          r={r}
          fill="none"
          stroke="currentColor"
          strokeOpacity=".4"
        />
      ))}
      {referenceContent.signs.map((s, i) => {
        const a = ((i * 30 - 90) * Math.PI) / 180;
        return (
          <g key={s.id}>
            <path
              d={`M210 210  ${210 + 191 * Math.cos(a)} ${210 + 191 * Math.sin(a)}`}
              stroke="currentColor"
              strokeOpacity=".25"
            />
            <image
              href={zodiacArtwork(i)!.src}
              x={196 + 179 * Math.cos(a + 0.26)}
              y={196 + 179 * Math.sin(a + 0.26)}
              width={28}
              height={28}
              preserveAspectRatio="xMidYMid meet"
            />
          </g>
        );
      })}
      {referenceContent.ASTRO_SAMPLE.aspects.map((a, i) => {
        const p = point(a.a),
          q = point(a.b);
        return (
          <path
            key={i}
            d={`M${p.x} ${p.y}L${q.x} ${q.y}`}
            stroke={a.angle === 180 ? '#d98d98' : '#a5bace'}
            strokeOpacity=".7"
            fill="none"
          />
        );
      })}
      {planets.map((p) => {
        const pos = point(p.id);
        return (
          <g key={p.id}>
            <circle {...{ cx: pos.x, cy: pos.y }} r="11" fill="rgb(var(--c-surface))" stroke="rgb(var(--c-gold))" />
            <text x={pos.x} y={pos.y + 5} textAnchor="middle" fontSize="14" fill="rgb(var(--c-ink))">
              {p.symbol}
            </text>
          </g>
        );
      })}
    </svg>
  );
}
