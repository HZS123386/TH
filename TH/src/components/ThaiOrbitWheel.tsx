import { useId, useState } from 'react';
import type { ThaiHoroscope } from 'thai-astrology';
import type { Copy } from '../lib/i18n';
import { thaiSignNames } from '../lib/thai';
import { chartPoint, chartRelations } from '../lib/chartGeometry';
import type { Language, Profile } from '../types';
import type { ThaiChart } from '../lib/thai';
import { OrbitEvidence, planetLabel } from './OrbitEvidence';

export function ThaiOrbitWheel({
  chart,
  t,
  language,
  profile,
  location,
  showDetails = true,
}: {
  chart?: ThaiHoroscope;
  t: Copy;
  language: Language;
  profile?: Profile | null;
  location?: ThaiChart['location'];
  showDetails?: boolean;
}) {
  const id = useId();
  const [selectedPoint, setSelectedPoint] = useState<keyof ThaiHoroscope['points'] | null>(null);
  const [selectedLine, setSelectedLine] = useState<string | null>(null);
  const rotation = chart ? chart.points.ascendant.longitudeDegrees + 180 : 105;
  const planets = chart ? Object.values(chart.points).filter((point) => point.number !== null) : [];
  const links = chart ? chartRelations(chart) : [];
  const activeLine = links.find((line) => `${line.from.key}:${line.to.key}` === selectedLine);
  function inspectPoint(key: keyof ThaiHoroscope['points']) {
    setSelectedLine(null);
    setSelectedPoint(key);
  }
  function inspectLine(key: string) {
    setSelectedPoint(null);
    setSelectedLine(key);
  }
  function closeEvidence() {
    setSelectedPoint(null);
    setSelectedLine(null);
  }
  // Separate nearby labels radially; keep each planet at its calculated angular position.
  const lanes: number[][] = Array.from({ length: 5 }, () => []);
  const placed = planets
    .slice()
    .sort((a, b) => a.longitudeDegrees - b.longitudeDegrees)
    .map((point) => {
      const lane = lanes.findIndex((angles) =>
        angles.every(
          (angle) =>
            Math.min(
              Math.abs(angle - point.longitudeDegrees),
              360 - Math.abs(angle - point.longitudeDegrees),
            ) >= 10,
        ),
      );
      const index = lane < 0 ? 4 : lane;
      lanes[index].push(point.longitudeDegrees);
      return { point, ...chartPoint(point.longitudeDegrees, 169 - index * 13, rotation) };
    });
  return (
    <figure className="-mx-3" data-testid="thai-orbit-wheel">
      <svg
        role="img"
        aria-labelledby={`${id}-title`}
        aria-describedby={`${id}-desc`}
        viewBox="0 0 480 480"
        className="mx-auto block h-auto w-full overflow-visible"
      >
        <title id={`${id}-title`}>{chart ? t.th_natal : t.th_chartLayout}</title>
        <desc id={`${id}-desc`}>
          {chart
            ? `${t.c_orbitNote} ${planets.map((point) => `${point.nameThai}: ${point.longitudeDegrees.toFixed(2)}°, ${t.th_house} ${point.house}`).join('; ')}`
            : t.th_chartPendingNote}
        </desc>
        <defs>
          <radialGradient id={`${id}-fill`}>
            <stop stopColor="#faf2ee" />
            <stop offset="1" stopColor="#fffdf8" />
          </radialGradient>
          <filter id={`${id}-glow`} x="-50%" y="-50%" width="200%" height="200%">
            <feGaussianBlur stdDeviation="3" />
          </filter>
        </defs>
        <circle
          cx="240"
          cy="240"
          r="220"
          fill="none"
          stroke="#c6a175"
          strokeOpacity=".2"
          strokeWidth="8"
          filter={`url(#${id}-glow)`}
        />
        <circle
          cx="240"
          cy="240"
          r="232"
          fill="none"
          stroke="#baa4be"
          strokeOpacity=".4"
          strokeDasharray="2 9"
        />
        <circle
          cx="240"
          cy="240"
          r="220"
          fill={`url(#${id}-fill)`}
          stroke="#b89564"
          strokeWidth="2"
        />
        {[184, 150, 110].map((radius) => (
          <circle
            key={radius}
            cx="240"
            cy="240"
            r={radius}
            fill="none"
            stroke="#b6a7b0"
            strokeOpacity=".65"
          />
        ))}
        {thaiSignNames.map((name, i) => {
          const start = chartPoint(i * 30, 110, rotation),
            end = chartPoint(i * 30, 220, rotation),
            label = chartPoint(i * 30 + 15, 202, rotation),
            house = chartPoint(i * 30 + 15, 96, rotation);
          const houseNumber = chart?.houses.find((row) => row.sign === i)?.number;
          let labelRotation = rotation - (i * 30 + 15) + 90;
          while (labelRotation > 90) labelRotation -= 180;
          while (labelRotation < -90) labelRotation += 180;
          return (
            <g key={name}>
              <line
                x1={start.x}
                y1={start.y}
                x2={end.x}
                y2={end.y}
                stroke="#b6a7b0"
                strokeOpacity=".55"
              />
              <text
                lang="th"
                x={label.x}
                y={label.y}
                textAnchor="middle"
                dominantBaseline="central"
                fill="#6f5c4d"
                fontSize="18"
                transform={`rotate(${labelRotation} ${label.x} ${label.y})`}
              >
                {name}
              </text>
              {houseNumber && (
                <text
                  x={house.x}
                  y={house.y}
                  textAnchor="middle"
                  dominantBaseline="central"
                  fill="#a28a74"
                  fontSize="15"
                >
                  {houseNumber}
                </text>
              )}
            </g>
          );
        })}
        {chart &&
          links.map(({ from, to, color, kind }) => {
            const a = chartPoint(from.longitudeDegrees, 86, rotation),
              b = chartPoint(to.longitudeDegrees, 86, rotation);
            return (
              <g
                key={`${from.key}-${to.key}`}
                className="cursor-pointer"
                data-link={`${from.key}:${to.key}`}
                data-kind={kind}
                onClick={() => inspectLine(`${from.key}:${to.key}`)}
              >
                <line x1={a.x} y1={a.y} x2={b.x} y2={b.y} stroke="transparent" strokeWidth="12" />
                <line
                  key={`${from.key}-${to.key}`}
                  x1={a.x}
                  y1={a.y}
                  x2={b.x}
                  y2={b.y}
                  stroke={color}
                  strokeWidth="1.1"
                  strokeOpacity=".65"
                />
              </g>
            );
          })}
        {chart && (
          <g stroke="#bb914b" strokeWidth="1" strokeOpacity=".7">
            <line x1="20" y1="240" x2="460" y2="240" />
            <circle cx="240" cy="240" r="5" fill="#bb914b" />
            <text
              className="cursor-pointer"
              onClick={() => inspectPoint('ascendant')}
              x="62"
              y="232"
              fill="#987540"
              stroke="none"
              fontSize="14"
            >
              ลั / ASC
            </text>
          </g>
        )}
        {placed.map(({ point, x, y }) => (
          <g
            key={point.key}
            data-planet={point.key}
            data-longitude={point.longitudeDegrees}
            aria-label={`${point.nameThai} ${point.longitudeDegrees.toFixed(2)}°`}
            className="cursor-pointer"
            onClick={() => inspectPoint(point.key)}
          >
            <circle
              cx={x}
              cy={y}
              r="11"
              fill={point.key === 'sun' ? '#c59c58' : '#b88faa'}
              fillOpacity=".13"
            />
            <circle
              cx={x}
              cy={y}
              r="9"
              stroke="#a57c91"
              strokeWidth=".8"
              fill={point.key === 'sun' ? '#e9c47c' : '#fffdf8'}
            />
            <text
              x={x}
              y={y + 0.5}
              textAnchor="middle"
              dominantBaseline="central"
              fill="#704f52"
              fontSize="13"
              fontWeight="600"
            >
              {point.number}
            </text>
          </g>
        ))}
        {!chart && (
          <g fill="none" stroke="#b49667" strokeWidth="1.5">
            <circle cx="240" cy="240" r="18" />
            <path d="M240 228v12l8 6" strokeLinecap="round" />
          </g>
        )}
      </svg>
      <figcaption className="mx-3 mt-2 text-center text-[10px] leading-6 text-muted">
        {chart ? t.c_orbitNote : t.th_chartPendingNote}
      </figcaption>
      {chart && showDetails && (
        <div className="mx-3 mt-4">
          <p className="mb-3 text-xs leading-6 text-muted">{t.c_interactHint}</p>
          <details
            className="rounded-xl border border-line bg-canvas/70 p-3"
            data-testid="orbit-points"
          >
            <summary className="cursor-pointer text-xs leading-6 text-[#85633c]">
              {t.c_pointDetails}
            </summary>
            <div className="mt-3 grid grid-cols-5 gap-1.5">
              {Object.values(chart.points).map((point) => (
                <button
                  key={point.key}
                  className={`flex min-h-12 min-w-0 flex-col items-center justify-center gap-1 rounded-lg border border-line bg-panel px-1 py-2 text-[10px] leading-5 hover:border-gold/60 ${point.key === 'ascendant' ? 'col-span-5 !flex-row !gap-2' : ''}`}
                  aria-label={planetLabel(point.key, t)}
                  aria-haspopup="dialog"
                  onClick={() => inspectPoint(point.key)}
                >
                  <span className="grid h-5 w-5 shrink-0 place-items-center rounded-full bg-[#f1e5d3] text-xs text-[#947147]">
                    {point.number ?? 'ลั'}
                  </span>
                  <span>{planetLabel(point.key, t)}</span>
                </button>
              ))}
            </div>
          </details>
          <details
            className="mt-2 rounded-xl border border-line bg-canvas/70 p-3"
            data-testid="orbit-links"
          >
            <summary className="cursor-pointer text-xs leading-6 text-[#85633c]">
              {t.c_lineDetails} · {links.length}
            </summary>
            <div className="mt-2 max-h-60 overflow-y-auto">
              {links.map((line) => (
                <button
                  key={`${line.from.key}:${line.to.key}`}
                  className="flex min-h-11 w-full items-center gap-2 border-t border-line py-2 text-left text-xs leading-6"
                  onClick={() => inspectLine(`${line.from.key}:${line.to.key}`)}
                  aria-haspopup="dialog"
                >
                  <span className="h-0.5 w-5 shrink-0" style={{ background: line.color }} />
                  <span className="flex-1">
                    {planetLabel(line.from.key, t)} · {planetLabel(line.to.key, t)}
                  </span>
                  <span className="text-[10px] text-muted">{t[`c_relation_${line.kind}`]}</span>
                </button>
              ))}
            </div>
          </details>
        </div>
      )}
      {chart && (selectedPoint || activeLine) && (
        <OrbitEvidence
          point={selectedPoint ? chart.points[selectedPoint] : undefined}
          line={activeLine}
          t={t}
          language={language}
          profile={profile}
          location={location}
          onClose={closeEvidence}
        />
      )}
    </figure>
  );
}
