import { useId } from 'react';
import { thaiSignNames } from '../lib/thai';

/** Decorative Thai zodiac seal; it does not represent a calculated birth chart. */
export function ThaiSkyPattern({ className = '' }: { className?: string }) {
  const id = useId().replace(/:/g, '');
  const at = (radius: number, angle: number) => ({
    x: 150 + radius * Math.cos((angle * Math.PI) / 180),
    y: 150 + radius * Math.sin((angle * Math.PI) / 180),
  });
  return (
    <svg
      viewBox="0 0 300 300"
      fill="none"
      className={className}
      aria-hidden="true"
      focusable="false"
      data-sky-pattern="thai"
    >
      <defs>
        <radialGradient id={`${id}-halo`}>
          <stop stopColor="currentColor" stopOpacity=".13" />
          <stop offset="1" stopColor="currentColor" stopOpacity="0" />
        </radialGradient>
      </defs>
      <circle cx="150" cy="150" r="150" fill={`url(#${id}-halo)`} />
      <g stroke="currentColor" strokeWidth=".65">
        <circle cx="150" cy="150" r="124" />
        <circle cx="150" cy="150" r="117" />
        <circle cx="150" cy="150" r="85" />
        <circle cx="150" cy="150" r="36" />
        {Array.from({ length: 72 }, (_, i) => {
          const a = at(i % 6 === 0 ? 117 : 121, i * 5 - 90),
            b = at(124, i * 5 - 90);
          return <path key={i} d={`M${a.x} ${a.y}L${b.x} ${b.y}`} />;
        })}
        {thaiSignNames.map((name, i) => {
          const a = at(85, i * 30 - 105),
            b = at(117, i * 30 - 105),
            label = at(101, i * -30 - 90);
          return (
            <g key={name}>
              <path d={`M${a.x} ${a.y}L${b.x} ${b.y}`} />
              <text
                x={label.x}
                y={label.y}
                stroke="none"
                fill="currentColor"
                textAnchor="middle"
                dominantBaseline="middle"
                fontSize="9"
                lang="th"
              >
                {name}
              </text>
            </g>
          );
        })}
        <path
          d="M150 72 164 136 228 150 164 164 150 228 136 164 72 150 136 136Z"
          strokeOpacity=".65"
        />
        <path d="m94 94 56 35 56-35-35 56 35 56-56-35-56 35 35-56Z" strokeOpacity=".35" />
        <circle cx="150" cy="150" r="28" />
      </g>
      <path d="M158 132a20 20 0 1 0 8 31 17 17 0 0 1-8-31Z" fill="currentColor" fillOpacity=".75" />
      <path d="m163 139 2 6 6 2-6 2-2 6-2-6-6-2 6-2Z" fill="currentColor" />
      <g fill="currentColor">
        <circle cx="26" cy="67" r="1.2" />
        <circle cx="267" cy="93" r="1.4" />
        <circle cx="251" cy="242" r="1" />
        <circle cx="54" cy="257" r="1.5" />
        <path d="m35 195 1.5 5 5 1.5-5 1.5-1.5 5-1.5-5-5-1.5 5-1.5Z" />
      </g>
      <path
        d="m21 103 22 17-8 23 23 13"
        stroke="currentColor"
        strokeWidth=".6"
        strokeOpacity=".5"
      />
      <g fill="currentColor" fillOpacity=".7">
        <circle cx="21" cy="103" r="1.6" />
        <circle cx="43" cy="120" r="1.5" />
        <circle cx="35" cy="143" r="1.6" />
        <circle cx="58" cy="156" r="1.5" />
      </g>
    </svg>
  );
}
