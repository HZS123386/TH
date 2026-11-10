import { useState } from 'react';

function createSky(compact: boolean) {
  const stars = Array.from({ length: compact ? 72 : 115 }, (_, index) => ({
    x: Math.random() * (compact ? 430 : 1440),
    y: Math.random() * (compact ? 900 : 1100),
    radius: compact
      ? index % 12 === 0
        ? 1.5
        : 0.55 + Math.random() * 0.8
      : index % 13 === 0
        ? 1.7
        : 0.5 + Math.random(),
    opacity: compact
      ? (0.2 + Math.random() * 0.28) * (index % 3 === 0 ? 0.5 : 1)
      : 0.2 + Math.random() * 0.45,
    delay: Math.random() * -8,
  }));
  const shapes = [
    [
      [0, 0],
      [45, 24],
      [85, 5],
      [112, 48],
      [76, 91],
    ],
    [
      [0, 28],
      [38, 0],
      [65, 45],
      [33, 89],
      [93, 105],
    ],
    [
      [0, 0],
      [38, 37],
      [20, 87],
      [82, 108],
      [112, 76],
    ],
    [
      [0, 42],
      [24, 70],
      [48, 20],
      [74, 58],
      [112, 0],
    ],
    [
      [0, 18],
      [28, 8],
      [50, 28],
      [85, 35],
      [108, 65],
      [65, 80],
      [50, 28],
    ],
  ];
  const constellations = Array.from({ length: compact ? 5 : 4 }, (_, index) => ({
    points: shapes[Math.floor(Math.random() * shapes.length)],
    x: compact
      ? index % 2
        ? 360
        : -75
      : index % 2
        ? 250 + Math.random() * 80
        : 1220 + Math.random() * 35,
    y: compact ? 65 + index * 168 : 50 + index * 230 + Math.random() * 65,
  }));
  return { stars, constellations };
}

export function Starfield({ compact = false }: { compact?: boolean }) {
  // Randomize once per visit; typing, navigation and login keep the same sky.
  const [{ stars, constellations }] = useState(() => createSky(compact));
  return (
    <div
      aria-hidden="true"
      data-starfield={compact ? 'page' : 'full'}
      className={
        compact
          ? 'pointer-events-none fixed inset-y-0 left-1/2 z-0 h-dvh w-full max-w-[430px] -translate-x-1/2 overflow-hidden'
          : 'pointer-events-none fixed inset-0 -z-10 overflow-hidden'
      }
    >
      <svg
        viewBox={compact ? '0 0 430 900' : '0 0 1440 1100'}
        preserveAspectRatio="xMidYMin slice"
        className={compact ? 'h-full w-full' : 'h-full min-h-[900px] w-full'}
      >
        {stars.map((star, index) => (
          <circle
            key={index}
            cx={star.x}
            cy={star.y}
            r={star.radius}
            fill={
              index % 9 === 0
                ? 'rgb(var(--c-gold))'
                : compact && index % 7 === 0
                  ? 'rgb(var(--c-ink))'
                  : 'rgb(var(--c-muted))'
            }
            opacity={star.opacity}
            className={
              compact
                ? index % 8 === 0
                  ? 'celestial-twinkle'
                  : undefined
                : index % 13 === 0
                  ? 'star-twinkle'
                  : undefined
            }
            style={
              (compact ? index % 8 === 0 : index % 13 === 0)
                ? { animationDelay: `${star.delay}s` }
                : undefined
            }
          />
        ))}
        {compact &&
          stars
            .filter((_, index) => index % 24 === 0)
            .map((star, index) => (
              <path
                key={`sparkle-${index}`}
                d="M0 -4 1 -1 4 0 1 1 0 4 -1 1 -4 0 -1 -1Z"
                transform={`translate(${star.x} ${star.y})`}
                fill="rgb(var(--c-gold))"
                opacity=".3"
              />
            ))}
        {constellations.map((constellation, index) => (
          <g
            key={index}
            transform={`translate(${constellation.x} ${constellation.y})`}
            stroke="rgb(var(--c-muted))"
            strokeWidth=".8"
            strokeOpacity={compact ? '.26' : '.3'}
            fill="rgb(var(--c-muted))"
            fillOpacity={compact ? '.5' : '1'}
          >
            <polyline
              points={constellation.points.map((point) => point.join(',')).join(' ')}
              fill="none"
            />
            {constellation.points.map(([x, y], i) => (
              <circle
                key={i}
                cx={x}
                cy={y}
                r={i === 1 ? 2.4 : 1.7}
                fill={compact && i === 1 ? 'rgb(var(--c-gold))' : undefined}
              />
            ))}
          </g>
        ))}
      </svg>
    </div>
  );
}
