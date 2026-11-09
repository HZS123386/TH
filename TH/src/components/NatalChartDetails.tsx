import { useState } from 'react';
import type { ThaiHoroscope } from 'thai-astrology';
import type { WanjaiPageProps } from './wanjai/WanjaiShared';
import { chartRelations } from '../lib/chartGeometry';
import { contentFor } from '../lib/wanjai';
import { OrbitEvidence, planetLabel } from './OrbitEvidence';
import { ZodiacIcon } from './ZodiacIcon';
import { PickerDialog } from './PickerDialog';

export function NatalChartDetails({ chart, p }: { chart: ThaiHoroscope; p: WanjaiPageProps }) {
  const { t } = p;
  const signs = contentFor(p.language).signs;
  const [pointKey, setPointKey] = useState<keyof ThaiHoroscope['points'] | null>(null);
  const [lineKey, setLineKey] = useState<string | null>(null);
  const [houseNumber, setHouseNumber] = useState<number | null>(null);
  const house = chart.houses.find((row) => row.number === houseNumber);
  const links = chartRelations(chart);
  const line = links.find((row) => `${row.from.key}:${row.to.key}` === lineKey);
  const close = () => {
    setPointKey(null);
    setLineKey(null);
    setHouseNumber(null);
  };
  return (
    <div id="natal-chart-data" className="scroll-mt-20 space-y-6" data-testid="natal-chart-data">
      <section>
        <h2 className="mb-4 flex items-center gap-3 text-lg font-semibold text-[#705337]">
          {t.c_planetHouseTitle}
          <span className="h-px flex-1 bg-[#d9c49e]" />
          <span className="text-gold">✦</span>
        </h2>
        <div className="grid grid-cols-[1.12fr_1fr] gap-2.5">
          <section
            className="min-w-0 overflow-hidden rounded-[20px] border border-[#d9c5a5] bg-panel"
            data-testid="orbit-points"
          >
            <h3 className="border-b border-line px-3 py-3 text-xs font-medium text-muted">
              {t.th_planets}
            </h3>
            {Object.values(chart.points).map((point) => (
              <button
                key={point.key}
                onClick={() => {
                  setLineKey(null);
                  setHouseNumber(null);
                  setPointKey(point.key);
                }}
                aria-label={planetLabel(point.key, t)}
                aria-haspopup="dialog"
                className="grid min-h-[58px] w-full grid-cols-[20px_minmax(0,1fr)] items-center gap-x-2 border-b border-line/70 px-2.5 py-2 text-left last:border-0"
              >
                <span className="grid h-5 w-5 place-items-center rounded-full bg-[#eee2cf] text-[10px] text-[#967345]">
                  {point.number ?? 'ลั'}
                </span>
                <span className="min-w-0">
                  <b className="block text-[11px] font-medium leading-5">
                    {planetLabel(point.key, t)}
                  </b>
                  <span className="flex flex-wrap items-center gap-x-1 text-[10px] leading-5 text-muted">
                    <ZodiacIcon
                      signIndex={point.sign}
                      name={signs[point.sign].name}
                      className="h-4 w-4"
                    />
                    <span>{signs[point.sign].name}</span>
                    <span className="tabular-nums">
                      {point.degrees}°{Math.floor(point.minutes)}′
                    </span>
                  </span>
                </span>
              </button>
            ))}
          </section>
          <section
            className="min-w-0 overflow-hidden rounded-[20px] border border-[#d9c5a5] bg-panel"
            data-testid="natal-houses"
          >
            <h3 className="border-b border-line px-3 py-3 text-xs font-medium text-muted">
              {t.th_houses}
            </h3>
            <ol>
              {chart.houses.map((house) => (
                <li key={house.number} className="border-b border-line/70 last:border-0">
                  <button
                    className="grid min-h-[53px] w-full grid-cols-[22px_minmax(0,1fr)] items-center gap-1.5 px-2.5 py-2 text-left"
                    aria-haspopup="dialog"
                    onClick={() => {
                      setPointKey(null);
                      setLineKey(null);
                      setHouseNumber(house.number);
                    }}
                  >
                    <b className="grid h-[22px] w-[22px] place-items-center rounded-full bg-[#eee2cf] text-[10px] font-medium text-[#967345]">
                      {house.number}
                    </b>
                    <span className="min-w-0 text-[10px] leading-5">
                      <span className="block font-medium">{signs[house.sign].name}</span>
                      <span lang="th" className="block text-[9px] text-muted">
                        {house.nameThai} · 0°
                      </span>
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
        <h2 className="mb-4 flex items-center gap-3 text-lg font-semibold text-[#705337]">
          {t.c_relationsTitle}
          <span className="h-px flex-1 bg-[#d9c49e]" />
          <span className="text-gold">✦</span>
        </h2>
        <div
          className="overflow-hidden rounded-[20px] border border-[#d9c5a5] bg-panel"
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
                  <b className="mr-1 font-medium text-gold">{row.from.number}</b>
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
                  <b className="ml-1 font-medium text-gold">{row.to.number}</b>
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
          title={`${t.th_house} ${house.number} · ${house.nameThai}`}
          t={t}
          onCancel={close}
          onConfirm={close}
        >
          <p className="text-lg text-accent">{signs[house.sign].name} · 0°</p>
          <p className="my-4 text-xs leading-7 text-muted">{t.c_wholeStartNote}</p>
          <p className="text-sm leading-7">
            {t.th_ruler} {house.ruler.number} · {house.ruler.nameThai} → {t.th_house}{' '}
            {house.ruler.house}
          </p>
          <p className="mt-4 text-sm leading-7">
            {t.th_planets} · {house.occupants.map((key) => planetLabel(key, t)).join(' / ') || '—'}
          </p>
        </PickerDialog>
      )}
    </div>
  );
}
