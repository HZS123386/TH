// Geometry adapted from kongesque/thai-astrology scripts/render-readme-chart.cjs
// (MIT, Copyright (c) 2026 Kongesque). See public/licenses/thai-astrology-MIT.txt.
import { useId } from 'react';
import type { ThaiHoroscope } from 'thai-astrology';
import { thaiSignNames } from '../lib/thai';
import type { Copy } from '../lib/i18n';

const center = { x: 480, y: 490 };
const radius = 326;
const halfSquare = 59;
const chord = Math.sqrt(radius ** 2 - halfSquare ** 2);
const positions = [
  [480, 292],
  [365, 300],
  [292, 370],
  [270, 490],
  [292, 610],
  [354, 676],
  [480, 682],
  [606, 676],
  [668, 610],
  [685, 490],
  [668, 370],
  [593, 300],
];

/** Same fixed sign orientation and internal divisions as the upstream README. */
export function ThaiRasiWheel({
  chart,
  mode,
  t,
}: {
  chart?: ThaiHoroscope;
  mode: keyof ThaiHoroscope['charts'];
  t: Copy;
}) {
  const id = useId();
  const channels = chart?.charts[mode].channels.thai ?? Array<string>(12).fill('');
  const sun = chart?.points.sun;
  return (
    <figure>
      <svg
        viewBox="145 155 670 670"
        role="img"
        aria-labelledby={`${id}-title`}
        aria-describedby={`${id}-desc`}
        className="mx-auto h-auto w-full rounded-xl bg-[#fffdf8]"
      >
        <title id={`${id}-title`}>
          {chart ? t[`th_${mode === 'rasi' ? 'natal' : mode}`] : t.th_chartLayout}
        </title>
        <desc id={`${id}-desc`}>
          {chart
            ? `${t.th_chartSymbol} ${channels.map((value, i) => `${thaiSignNames[i]}: ${value || '—'}`).join('; ')}`
            : t.th_chartPendingNote}
        </desc>
        <circle cx="480" cy="490" r={radius} fill="#fffdf8" stroke="#685b48" strokeWidth="1.2" />
        <g stroke="#80715c" strokeWidth="0.8">
          {[-halfSquare, halfSquare].map((offset) => (
            <g key={offset}>
              <line
                x1={center.x + offset}
                y1={center.y - chord}
                x2={center.x + offset}
                y2={center.y + chord}
              />
              <line
                x1={center.x - chord}
                y1={center.y + offset}
                x2={center.x + chord}
                y2={center.y + offset}
              />
            </g>
          ))}
          {[-1, 1].flatMap((x) =>
            [-1, 1].map((y) => (
              <line
                key={`${x},${y}`}
                x1={center.x + x * halfSquare}
                y1={center.y + y * halfSquare}
                x2={center.x + (x * radius) / Math.sqrt(2)}
                y2={center.y + (y * radius) / Math.sqrt(2)}
              />
            )),
          )}
        </g>
        <circle cx="480" cy="490" r="285" fill="none" stroke="#685b48" strokeWidth="1.8" />
        <circle cx="480" cy="490" r="279" fill="none" stroke="#685b48" strokeWidth="0.8" />
        <g textAnchor="middle" dominantBaseline="central" fontWeight="400">
          {thaiSignNames.map((sign, i) => {
            const angle = -90 - i * 30;
            const radians = (angle * Math.PI) / 180;
            const x = center.x + 305 * Math.cos(radians),
              y = center.y + 305 * Math.sin(radians);
            let rotation = angle + 90;
            while (rotation < -90) rotation += 180;
            while (rotation > 90) rotation -= 180;
            if (i === 9) rotation += 180;
            return (
              <text
                lang="th"
                key={i}
                transform={`translate(${x} ${y}) rotate(${rotation})`}
                fill="#284c69"
                fontSize="26"
              >
                {sign}
              </text>
            );
          })}
          {channels.map(
            (channel, i) =>
              channel && (
                <text
                  key={i}
                  x={positions[i][0]}
                  y={positions[i][1]}
                  aria-label={`${thaiSignNames[i]} ${channel}`}
                  fill="#2f2922"
                  fontSize={channel.length > 5 ? 30 : 40}
                  textLength={channel.length > 5 ? 105 : undefined}
                  lengthAdjust="spacingAndGlyphs"
                  letterSpacing="1"
                >
                  {channel.split(/(ลั|\*)/).map((part, j) => (
                    <tspan
                      key={j}
                      fill={part === 'ลั' || part === '*' ? '#b73732' : undefined}
                      fontSize={part === '*' ? 23 : undefined}
                    >
                      {part}
                    </tspan>
                  ))}
                </text>
              ),
          )}
          {!chart ? (
            <g fill="none" stroke="#b7975a" strokeWidth="3" aria-hidden="true">
              <circle cx="480" cy="490" r="28" />
              <path d="M480 472v18l14 10" strokeLinecap="round" strokeLinejoin="round" />
            </g>
          ) : mode === 'rasi' && sun ? (
            <text
              x="480"
              y="476"
              fill="#3e3326"
              fontSize="22"
              aria-label={`${t.th_centerSun} ${sun.degrees}° ${sun.minutes.toFixed(1)}′`}
            >
              <tspan x="480">{sun.degrees}°</tspan>
              <tspan x="480" dy="27">
                {sun.minutes.toFixed(1)}′
              </tspan>
            </text>
          ) : (
            <text lang="th" x="480" y="490" fill="#8d6734" fontSize="19">
              {mode === 'navamsa' ? 'นวางค์' : 'ตรียางค์'}
            </text>
          )}
        </g>
      </svg>
      <figcaption className="mt-3 text-[10px] leading-6 text-muted">
        {chart ? t.th_chartSymbol : t.th_chartPendingNote}
        {chart && mode === 'rasi' && ` ${t.th_centerSun}`}
      </figcaption>
    </figure>
  );
}
