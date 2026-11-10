import { useState } from 'react';
import type { ThaiHoroscope } from 'thai-astrology';
import type { WanjaiPageProps } from './wanjai/WanjaiShared';
import { chartRelations, planetSymbols, wholeSignHouseCusps } from '../lib/chartGeometry';
import { contentFor } from '../lib/wanjai';
import { zodiacAbbreviation } from '../lib/zodiac';
import { OrbitEvidence, planetLabel } from './OrbitEvidence';
import { PickerDialog } from './PickerDialog';

const pointOrder = [
  'sun',
  'moon',
  'mercury',
  'venus',
  'mars',
  'jupiter',
  'saturn',
  'uranus',
  'rahu',
  'ketu',
  'ascendant',
] as const;

function positionLabel(degrees: number, minutes: number) {
  return `${degrees}°${String(Math.floor(minutes)).padStart(2, '0')}′`;
}

export function NatalChartDetails({ chart, p }: { chart: ThaiHoroscope; p: WanjaiPageProps }) {
  const { t } = p;
  const signs = contentFor(p.language).signs;
  const [pointKey, setPointKey] = useState<keyof ThaiHoroscope['points'] | null>(null);
  const [lineKey, setLineKey] = useState<string | null>(null);
  const [houseNumber, setHouseNumber] = useState<number | null>(null);
  const cusps = wholeSignHouseCusps(chart);
  const house = cusps.find((row) => row.number === houseNumber);
  const links = chartRelations(chart);
  const line = links.find((row) => `${row.from.key}:${row.to.key}` === lineKey);
  const close = () => {
    setPointKey(null);
    setLineKey(null);
    setHouseNumber(null);
  };
  return (
    <div id="natal-chart-data" className="scroll-mt-20 space-y-6" data-testid="natal-chart-data">
      <section data-testid="planet-cusp-tables">
        <h2 className="mb-4 flex items-center gap-2 text-lg font-semibold text-ink/85">
          <span className="min-w-0">
            {t.c_planetHouseTitle}
            <span className="ml-2 inline-block rounded-full border border-line bg-surface px-2 py-0.5 align-middle text-[9px] font-normal leading-4 text-muted">
              {t.c_wholeSignLabel}
            </span>
          </span>
          <span aria-hidden="true" className="h-px min-w-3 flex-1 bg-gold/35" />
          <span aria-hidden="true" className="text-gold">
            ✦
          </span>
        </h2>
        <div className="grid grid-cols-[1.25fr_1fr] gap-2.5">
          <section
            className="min-w-0 overflow-hidden rounded-[20px] border border-gold/25 bg-panel"
            data-testid="orbit-points"
          >
            <h3 className="border-b border-line px-3 py-3 text-xs font-medium text-muted">
              {t.c_planetsTitle}
            </h3>
            {pointOrder.map((key) => {
              const point = chart.points[key];
              return (
                <button
                  key={point.key}
                  onClick={() => {
                    setLineKey(null);
                    setHouseNumber(null);
                    setPointKey(point.key);
                  }}
                  aria-label={planetLabel(point.key, t)}
                  aria-haspopup="dialog"
                  data-natal-point={point.key}
                  className="grid min-h-12 w-full grid-cols-[16px_minmax(0,1fr)_30px_40px] items-center gap-x-1 px-2 py-2 text-left hover:bg-surface/70"
                >
                  <span
                    aria-hidden="true"
                    data-planet-symbol={point.key}
                    className={`text-center leading-none text-muted ${point.key === 'ascendant' ? 'text-[10px]' : 'text-[19px]'}`}
                  >
                    {planetSymbols[point.key]}
                  </span>
                  <b className="min-w-0 break-words text-[11px] font-medium leading-4 text-ink/85">
                    {planetLabel(point.key, t)}
                  </b>
                  <abbr
                    title={signs[point.sign].name}
                    className="rounded-full bg-surface px-1 py-0.5 text-center font-display text-[10px] leading-4 text-muted no-underline"
                  >
                    {zodiacAbbreviation(point.sign)}
                  </abbr>
                  <span className="whitespace-nowrap text-right text-[10px] tabular-nums text-muted">
                    {positionLabel(point.degrees, point.minutes)}
                  </span>
                </button>
              );
            })}
          </section>
          <section
            className="min-w-0 overflow-hidden rounded-[20px] border border-gold/25 bg-panel"
            data-testid="natal-houses"
          >
            <h3 className="border-b border-line px-3 py-3 text-xs font-medium text-muted">
              {t.c_houseCuspsTitle}
            </h3>
            <ol>
              {cusps.map((house) => (
                <li key={house.number}>
                  <button
                    className="grid min-h-11 w-full grid-cols-[20px_30px_minmax(0,1fr)] items-center gap-1 px-2 py-2 text-left hover:bg-surface/70"
                    aria-label={`${t.c_houseCuspsTitle} ${house.number} · ${signs[house.sign].name} · ${positionLabel(house.degrees, house.minutes)}`}
                    aria-haspopup="dialog"
                    data-house-cusp={house.number}
                    data-longitude={house.longitudeDegrees}
                    onClick={() => {
                      setPointKey(null);
                      setLineKey(null);
                      setHouseNumber(house.number);
                    }}
                  >
                    <b className="grid h-5 w-5 place-items-center rounded-full bg-surface text-[10px] font-medium text-muted">
                      {house.number}
                    </b>
                    <abbr
                      title={signs[house.sign].name}
                      className="rounded-full bg-surface px-1 py-0.5 text-center font-display text-[10px] leading-4 text-muted no-underline"
                    >
                      {zodiacAbbreviation(house.sign)}
                    </abbr>
                    <span className="whitespace-nowrap text-right text-[10px] tabular-nums text-muted">
                      {positionLabel(house.degrees, house.minutes)}
                    </span>
                  </button>
                </li>
              ))}
            </ol>
          </section>
        </div>
        <p className="mt-3 text-[10px] leading-6 text-muted">{t.c_wholeStartNote}</p>
      </section>
      <section>
        <h2 className="mb-4 flex items-center gap-3 text-lg font-semibold text-ink/85">
          {t.c_relationsTitle}
          <span className="h-px flex-1 bg-gold/35" />
          <span className="text-gold">✦</span>
        </h2>
        <div
          className="overflow-hidden rounded-[20px] border border-line bg-panel"
          data-testid="orbit-links"
        >
          <div className="flex items-center justify-between border-b border-line px-4 py-3 text-[10px] text-muted">
            <span>
              {t.c_lineDetails} · {links.length}
            </span>
            <span>{t.c_angularDistance}</span>
          </div>
          {links.map((row) => {
            const difference = Math.abs(row.from.longitudeDegrees - row.to.longitudeDegrees);
            const separation = Math.min(difference, 360 - difference);
            return (
              <button
                key={`${row.from.key}:${row.to.key}`}
                onClick={() => {
                  setPointKey(null);
                  setHouseNumber(null);
                  setLineKey(`${row.from.key}:${row.to.key}`);
                }}
                aria-haspopup="dialog"
                className="grid min-h-[62px] w-full grid-cols-[1fr_1.3fr_1fr] items-center gap-2 border-b border-line/70 px-3 py-3 text-xs last:border-0"
              >
                <span className="text-left leading-6">
                  <span aria-hidden="true" className="mr-1 text-base text-muted">
                    {planetSymbols[row.from.key]}
                  </span>
                  {planetLabel(row.from.key, t)}
                </span>
                <span className="text-center text-[10px] leading-5">
                  <span
                    className="inline-block h-2 w-2 rounded-full"
                    style={{ background: row.color }}
                  />{' '}
                  {t[`c_relation_${row.kind}`]}
                  <span className="block tabular-nums text-muted">
                    {Math.floor(separation)}°{Math.floor((separation % 1) * 60)}′
                  </span>
                </span>
                <span className="text-right leading-6">
                  {planetLabel(row.to.key, t)}
                  <span aria-hidden="true" className="ml-1 text-base text-muted">
                    {planetSymbols[row.to.key]}
                  </span>
                </span>
              </button>
            );
          })}
        </div>
        <p className="mt-3 text-[10px] leading-6 text-muted">{t.c_relationScope}</p>
      </section>
      {(pointKey || line) && (
        <OrbitEvidence
          point={pointKey ? chart.points[pointKey] : undefined}
          line={line}
          profile={p.profile}
          location={p.thai.value?.location}
          language={p.language}
          t={t}
          onClose={close}
        />
      )}
      {house && (
        <PickerDialog
          title={`${t.c_houseCuspsTitle} ${house.number}`}
          t={t}
          onCancel={close}
          onConfirm={close}
        >
          <p className="flex items-center gap-2 text-lg text-accent">
            <abbr title={signs[house.sign].name} className="font-display no-underline">
              {zodiacAbbreviation(house.sign)}
            </abbr>
            {positionLabel(house.degrees, house.minutes)}
          </p>
          <p className="mt-2 text-xs tabular-nums text-muted">
            {t.c_longitude} · {house.longitudeDegrees.toFixed(2)}°
          </p>
          <p className="my-4 text-xs leading-7 text-muted">{t.c_wholeStartNote}</p>
          <p className="text-sm leading-7">
            {t.th_ruler} {planetSymbols[house.ruler.key]} · {planetLabel(house.ruler.key, t)} →{' '}
            {t.th_house} {house.ruler.house}
          </p>
          <p className="mt-4 text-sm leading-7">
            {t.c_planetsTitle} ·{' '}
            {house.occupants.map((key) => planetLabel(key, t)).join(' / ') || '—'}
          </p>
        </PickerDialog>
      )}
    </div>
  );
}
