import { useState } from 'react';
import { ArrowRight, CalendarDays, Compass, RefreshCw, Sparkles } from 'lucide-react';
import type { Copy } from '../lib/i18n';
import type { Language, Profile } from '../types';
import { contentFor } from '../lib/wanjai';
import {
  westernAscendant,
  westernCopy,
  westernPlanets,
  westernSymbols,
  type WesternCalculation,
  type WesternPlanetKey,
} from '../lib/western';
import { ZodiacWheel } from './ZodiacWheel';

const at = (longitude: number, radius: number) => {
  const radian = ((longitude - 90) * Math.PI) / 180;
  return { x: 180 + Math.cos(radian) * radius, y: 180 + Math.sin(radian) * radius };
};

export function WesternWheel({
  result,
  selected,
  onSelect,
  language,
}: {
  result: WesternCalculation;
  selected: WesternPlanetKey;
  onSelect: (key: WesternPlanetKey) => void;
  language: Language;
}) {
  const data = contentFor(language);
  const planets = westernPlanets(result);
  const label = (key: WesternPlanetKey) =>
    data.ASTRO_SAMPLE.planets.find((planet) => planet.id === key)?.name || key;
  return (
    <svg
      viewBox="0 0 360 360"
      className="mx-auto w-full max-w-[390px] overflow-visible"
      role="img"
      aria-label={westernCopy(language).myChart}
    >
      <defs>
        <radialGradient id="western-wheel-glow">
          <stop stopColor="#493260" stopOpacity=".35" />
          <stop offset="1" stopColor="#130c24" stopOpacity=".1" />
        </radialGradient>
      </defs>
      <circle
        cx="180"
        cy="180"
        r="169"
        fill="url(#western-wheel-glow)"
        stroke="#e4bc78"
        strokeOpacity=".65"
        strokeWidth="1"
      />
      {[164, 137, 112, 83].map((radius) => (
        <circle
          key={radius}
          cx="180"
          cy="180"
          r={radius}
          fill="none"
          stroke="#e4bc78"
          strokeOpacity={radius === 137 ? '.55' : '.2'}
          strokeWidth=".65"
        />
      ))}
      {Array.from({ length: 72 }, (_, i) => {
        const start = at(i * 5, i % 6 === 0 ? 113 : 158),
          end = at(i * 5, 164);
        return (
          <path
            key={i}
            d={`M${start.x} ${start.y}L${end.x} ${end.y}`}
            stroke="#e4bc78"
            strokeWidth=".6"
            strokeOpacity={i % 6 === 0 ? '.6' : '.35'}
          />
        );
      })}
      {data.signs.map((sign, i) => {
        const point = at(i * 30 + 15, 150);
        return (
          <text
            key={sign.id}
            x={point.x}
            y={point.y + 4}
            textAnchor="middle"
            fill="#e4bc78"
            fontSize="17"
          >
            {['♈', '♉', '♊', '♋', '♌', '♍', '♎', '♏', '♐', '♑', '♒', '♓'][i]}
          </text>
        );
      })}
      {result.facts.flatMap((fact) => {
        if (fact.kind !== 'aspect') return [];
        const from = planets.find((planet) => planet.key === fact.value.from),
          to = planets.find((planet) => planet.key === fact.value.to);
        if (!from || !to) return [];
        const p1 = at(from.longitude, 103),
          p2 = at(to.longitude, 103);
        return (
          <path
            key={fact.fact_id}
            d={`M${p1.x} ${p1.y}L${p2.x} ${p2.y}`}
            stroke={fact.value.angle === 90 || fact.value.angle === 180 ? '#c78b9c' : '#8fafe3'}
            strokeOpacity=".5"
            strokeWidth=".8"
          />
        );
      })}
      {result.facts.flatMap((fact) => {
        if (fact.kind !== 'house') return [];
        const from = at(fact.value.longitude, 84),
          to = at(fact.value.longitude, 136);
        return (
          <path
            key={fact.fact_id}
            d={`M${from.x} ${from.y}L${to.x} ${to.y}`}
            stroke="#e4bc78"
            strokeOpacity=".35"
            strokeWidth=".8"
          />
        );
      })}
      {planets.map((planet, i) => {
        const point = at(planet.longitude, 109 + (i % 2) * 13);
        return (
          <g
            key={planet.key}
            role="button"
            tabIndex={0}
            aria-label={label(planet.key)}
            aria-pressed={selected === planet.key}
            className="cursor-pointer outline-offset-4"
            onClick={() => onSelect(planet.key)}
            onKeyDown={(event) => {
              if (event.key === 'Enter' || event.key === ' ') {
                event.preventDefault();
                onSelect(planet.key);
              }
            }}
          >
            <circle
              cx={point.x}
              cy={point.y}
              r="13"
              fill={selected === planet.key ? '#e4bc78' : '#261a3b'}
              stroke="#e4bc78"
              strokeOpacity={selected === planet.key ? '1' : '.35'}
            />
            <text
              x={point.x}
              y={point.y + 5}
              textAnchor="middle"
              fontSize="16"
              fill={selected === planet.key ? '#20132e' : '#e4bc78'}
            >
              {westernSymbols[planet.key]}
            </text>
          </g>
        );
      })}
      <text x="180" y="176" textAnchor="middle" fill="#e4bc78" fontSize="22">
        ✧
      </text>
      <text x="180" y="194" textAnchor="middle" fill="#b4a8c6" fontSize="8" letterSpacing="2">
        FATE
      </text>
    </svg>
  );
}

export function WesternChart({
  result,
  example,
  profile,
  status,
  language,
  t,
  onBirth,
  onExample,
  onRetry,
  onReport,
}: {
  result: WesternCalculation | null;
  example: boolean;
  profile: Profile | null;
  status: 'idle' | 'loading' | 'unavailable' | 'error';
  language: Language;
  t: Copy;
  onBirth: () => void;
  onExample: () => void;
  onRetry: () => void;
  onReport: () => void;
}) {
  const a = westernCopy(language),
    data = contentFor(language);
  const [selected, setSelected] = useState<WesternPlanetKey>('sun');
  const [tab, setTab] = useState<'planets' | 'houses' | 'aspects'>('planets');
  const planets = result ? westernPlanets(result) : [];
  const selectedPlanet = planets.find((planet) => planet.key === selected);
  const planetName = (key: WesternPlanetKey) =>
    data.ASTRO_SAMPLE.planets.find((planet) => planet.id === key)?.name || key;
  const position = (longitude: number) =>
    `${data.signs[Math.floor(longitude / 30)].name} ${Math.floor(longitude % 30)}°${String(Math.floor((longitude % 1) * 60)).padStart(2, '0')}′`;
  const ascendant = result ? westernAscendant(result) : undefined;
  return (
    <div className="space-y-5" data-testid="western-chart">
      <div>
        <p className="mb-2 text-[10px] tracking-wider text-gold">{a.system}</p>
        <h1 className="text-[24px] font-semibold leading-9">{a.myChart}</h1>
        <p className="mt-2 text-xs leading-6 text-muted">{a.myChartText}</p>
      </div>
      {example && (
        <div className="rounded-xl border border-gold/25 bg-gold/5 p-3 text-[11px] leading-6 text-muted">
          <strong className="mr-2 font-medium text-gold">{a.exampleBadge}</strong>
          {a.exampleNote}
        </div>
      )}
      {!result ? (
        <section className="relative overflow-hidden rounded-[24px] border border-line bg-panel/60 p-5 text-center">
          <ZodiacWheel className="mx-auto h-52 w-52 text-gold/45 opacity-55" monochrome />
          <h2 className="mt-1 text-base font-medium">
            {status === 'loading' ? a.waiting : status === 'error' ? a.error : profile ? a.unavailable : a.noChart}
          </h2>
          <p className="mx-auto mt-3 max-w-xs text-xs leading-7 text-muted">
            {profile ? a.unavailableText : a.noChartText}
          </p>
          <button
            onClick={profile ? onRetry : onBirth}
            disabled={status === 'loading'}
            className="jy-primary mt-5 w-full"
          >
            {status === 'loading' ? (
              <RefreshCw className="animate-spin" size={17} />
            ) : (
              <Compass size={17} />
            )}
            {profile ? a.retry : a.start}
          </button>
          <button
            onClick={onExample}
            className="mt-3 min-h-11 text-xs text-gold underline decoration-gold/30 underline-offset-4"
          >
            {a.example}
          </button>
        </section>
      ) : (
        <>
          <section className="rounded-[24px] border border-gold/25 bg-panel/40 p-3">
            <div className="flex items-center justify-between gap-3 px-2 pt-2 text-[10px] text-muted">
              <span>{example ? a.exampleBadge : profile?.display_name || 'FATE'}</span>
              <button onClick={onBirth} className="flex min-h-9 items-center gap-1 text-gold">
                <CalendarDays size={12} />
                {a.editBirth}
              </button>
            </div>
            <WesternWheel
              result={result}
              selected={selected}
              onSelect={setSelected}
              language={language}
            />
            <div className="grid grid-cols-3 gap-2 pb-2 text-center">
              {[
                {
                  label: a.sun,
                  longitude: planets.find((planet) => planet.key === 'sun')?.longitude,
                },
                {
                  label: a.moon,
                  longitude: planets.find((planet) => planet.key === 'moon')?.longitude,
                },
                { label: a.ascendant, longitude: ascendant },
              ].map((item) => (
                <div
                  key={item.label}
                  className="rounded-xl border border-line/65 bg-canvas/50 px-1 py-3"
                >
                  <p className="text-[10px] text-muted">{item.label}</p>
                  <p className="mt-1.5 text-xs text-gold">
                    {item.longitude !== undefined
                      ? data.signs[Math.floor(item.longitude / 30)].name
                      : a.emptyValue}
                  </p>
                </div>
              ))}
            </div>
          </section>
          <p className="flex items-center gap-2 text-[11px] leading-6 text-muted">
            <Sparkles size={13} className="shrink-0 text-gold" />
            {a.planetHint}
          </p>
          {selectedPlanet && (
            <section
              aria-live="polite"
              className="flex items-center gap-4 rounded-2xl border border-gold/20 bg-surface/60 p-4"
            >
              <span className="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-gold/10 text-2xl text-gold">
                {westernSymbols[selected]}
              </span>
              <div>
                <h2 className="text-sm">{planetName(selected)}</h2>
                <p className="mt-1 text-xs text-muted">
                  {position(selectedPlanet.longitude)}
                  {selectedPlanet.house ? ` · ${a.house} ${selectedPlanet.house}` : ''}
                </p>
                <p className="mt-2 text-xs leading-6 text-ink/75">
                  {a[`${selected}Meaning`]}
                </p>
              </div>
            </section>
          )}
          {result.input_precision === 'date_only' && (
            <p className="text-xs leading-6 text-muted">{a.unknownTime}</p>
          )}
          <div
            role="group"
            aria-label={a.myChart}
            className="grid grid-cols-3 rounded-xl bg-surface p-1"
          >
            {(['planets', 'houses', 'aspects'] as const).map((key) => (
              <button
                key={key}
                aria-pressed={tab === key}
                onClick={() => setTab(key)}
                className={`min-h-11 rounded-lg px-1 text-xs ${tab === key ? 'bg-gold text-on-primary' : 'text-muted'}`}
              >
                {a[key]}
              </button>
            ))}
          </div>
          <section className="rounded-2xl border border-line bg-panel/60 px-4">
            {tab === 'planets' &&
              planets.map((planet) => (
                <button
                  key={planet.key}
                  onClick={() => setSelected(planet.key)}
                  className="flex min-h-14 w-full items-center gap-3 border-b border-line/70 py-3 text-left text-xs last:border-0"
                >
                  <span className="w-6 text-xl text-gold">{westernSymbols[planet.key]}</span>
                  <span className="flex-1">{planetName(planet.key)}</span>
                  <span className="text-muted">{position(planet.longitude)}</span>
                </button>
              ))}
            {tab === 'houses' &&
              (result.facts.some((fact) => fact.kind === 'house') ? (
                result.facts.flatMap((fact) =>
                  fact.kind === 'house'
                    ? [
                        <p
                          key={fact.fact_id}
                          className="flex min-h-12 items-center justify-between border-b border-line/70 text-xs last:border-0"
                        >
                          <span>
                            {a.house} {fact.value.number}
                          </span>
                          <span className="text-muted">{position(fact.value.longitude)}</span>
                        </p>,
                      ]
                    : [],
                )
              ) : (
                <p className="py-5 text-xs text-muted">{a.emptyValue}</p>
              ))}
            {tab === 'aspects' &&
              (result.facts.some((fact) => fact.kind === 'aspect') ? (
                result.facts.flatMap((fact) =>
                  fact.kind === 'aspect'
                    ? [
                        <p
                          key={fact.fact_id}
                          className="flex min-h-12 items-center justify-between gap-2 border-b border-line/70 text-xs last:border-0"
                        >
                          <span>
                            {planetName(fact.value.from)} · {planetName(fact.value.to)}
                          </span>
                          <span className="text-gold">{fact.value.angle}°</span>
                        </p>,
                      ]
                    : [],
                )
              ) : (
                <p className="py-5 text-xs text-muted">{a.emptyValue}</p>
              ))}
          </section>
          <button onClick={onReport} className="jy-primary w-full">
            {a.chartRead}
            <ArrowRight size={17} />
          </button>
        </>
      )}
      {!example && profile && (
        <button onClick={onBirth} className="jy-outline w-full">
          {a.editBirth}
        </button>
      )}
      <span className="sr-only">{t.brandName}</span>
    </div>
  );
}
