import { useEffect, useRef, useState } from 'react';
import { CalendarDays, Clock3, MapPin, Maximize2, RefreshCw, UserRound } from 'lucide-react';
import type { ThaiHoroscope } from 'thai-astrology';
import { api } from '../lib/api';
import { ThaiRasiWheel } from './ThaiRasiWheel';
import { ThaiOrbitWheel } from './ThaiOrbitWheel';
import { NatalChartDetails } from './NatalChartDetails';
import { NatalChartHero } from './NatalChartHero';
import { ZodiacIcon } from './ZodiacIcon';
import { formatBirthTime } from '../lib/birthTime';
import { contentFor } from '../lib/wanjai';
import { taksaKeys, taksaThai, type ThaiTransits } from '../lib/thai';
import { PageIntro, Note, type WanjaiPageProps } from './wanjai/WanjaiShared';
import { PickerDialog } from './PickerDialog';
import { BirthOverview } from './BirthOverview';

export function ThaiChartPanel(p: WanjaiPageProps & { hideIntro?: boolean; example?: boolean }) {
  const { t, thai } = p;
  const value = thai.value;
  const chart = value?.chart;
  const unknownTime = !!p.profile && p.profile.birth_time === null;
  const data = contentFor(p.language);
  const [mode, setMode] = useState<keyof ThaiHoroscope['charts']>('rasi');
  const [wheelView, setWheelView] = useState<'orbit' | 'traditional'>('orbit');
  const [expanded, setExpanded] = useState(false);
  const [transit, setTransit] = useState<ThaiTransits | null>(null);
  const [transitError, setTransitError] = useState('');
  const [calculating, setCalculating] = useState(false);
  const controller = useRef<AbortController | null>(null);
  useEffect(() => () => controller.current?.abort(), []);
  async function getTransits() {
    controller.current?.abort();
    const request = new AbortController();
    controller.current = request;
    setCalculating(true);
    setTransitError('');
    try {
      const result = await api<ThaiTransits>(
        p.account ? '/api/thai-transits' : '/api/thai-transits/preview',
        {
          signal: request.signal,
          ...(p.account ? {} : { method: 'POST', body: JSON.stringify(p.profile) }),
        },
      );
      if (!request.signal.aborted) setTransit(result);
    } catch (cause) {
      if (!request.signal.aborted)
        setTransitError(cause instanceof Error ? cause.message : String(cause));
    } finally {
      if (!request.signal.aborted) setCalculating(false);
    }
  }
  return (
    <>
      {!p.hideIntro && <PageIntro title={t.th_title} sub={t.th_intro} />}
      {thai.loading && !unknownTime && (
        <p role="status" className="panel mb-5 flex items-center gap-3 p-6 text-sm">
          <RefreshCw size={16} className="animate-spin" />
          {t.th_loading}
        </p>
      )}
      {thai.error && !unknownTime && (
        <div role="alert" className="panel mb-5 p-5">
          <p className="text-sm text-accent">{thai.error}</p>
          <button className="btn-quiet mt-3" onClick={thai.retry}>
            {t.retry}
          </button>
        </div>
      )}
      <div className="grid items-start gap-5">
        <section className={chart ? 'min-w-0' : 'panel p-5 sm:p-7'}>
          {chart ? (
            <NatalChartHero chart={chart} p={p} />
          ) : !unknownTime && value?.status !== 'time-unknown' ? (
            <h2 className="mb-4 font-display text-xl">
              {p.example ? t.j_exampleChart : t.th_personal}
            </h2>
          ) : null}
          {chart ? (
            <>
              <div className="mb-4 grid grid-cols-2 gap-2">
                {(['orbit', 'traditional'] as const).map((view) => (
                  <button
                    key={view}
                    className={`min-h-11 rounded-xl border px-2 py-2 text-xs ${wheelView === view ? 'border-gold/70 bg-surface text-gold' : 'border-line text-muted'}`}
                    aria-pressed={wheelView === view}
                    onClick={() => setWheelView(view)}
                  >
                    {view === 'orbit' ? t.c_orbitView : t.c_traditionalView}
                  </button>
                ))}
              </div>
              {wheelView === 'traditional' && (
                <div role="group" aria-label={t.th_personal} className="mb-5 flex flex-wrap gap-2">
                  {(['rasi', 'navamsa', 'drekkana'] as const).map((key) => (
                    <button
                      key={key}
                      aria-pressed={mode === key}
                      onClick={() => setMode(key)}
                      className={`rounded-lg border px-3 py-2 text-xs ${mode === key ? 'border-primary bg-surface text-accent' : 'border-line'}`}
                    >
                      {t[`th_${key === 'rasi' ? 'natal' : key}`]}
                    </button>
                  ))}
                </div>
              )}
              <div className="mb-1 flex justify-end">
                <button
                  type="button"
                  className="btn-quiet min-h-10 !px-2 !text-xs"
                  aria-haspopup="dialog"
                  onClick={() => setExpanded(true)}
                >
                  <Maximize2 size={15} />
                  {t.c_expandChart}
                </button>
              </div>
              {wheelView === 'orbit' ? (
                <ThaiOrbitWheel
                  chart={chart}
                  t={t}
                  language={p.language}
                  profile={p.profile}
                  location={value?.location}
                  showDetails={false}
                />
              ) : (
                <ThaiRasiWheel chart={chart} mode={mode} t={t} />
              )}
              {expanded && (
                <PickerDialog
                  title={t.c_expandedChart}
                  t={t}
                  wide
                  onCancel={() => setExpanded(false)}
                  onConfirm={() => setExpanded(false)}
                >
                  <div className="mx-auto max-w-[min(100%,68dvh)]">
                    {wheelView === 'orbit' ? (
                      <ThaiOrbitWheel
                        chart={chart}
                        t={t}
                        language={p.language}
                        profile={p.profile}
                        location={value?.location}
                        showDetails={false}
                      />
                    ) : (
                      <ThaiRasiWheel chart={chart} mode={mode} t={t} />
                    )}
                  </div>
                </PickerDialog>
              )}
              <section
                className="mt-6 rounded-[22px] border border-gold/35 bg-surface px-4 py-3"
                data-testid="natal-birth-card"
                aria-label={t.c_profileCard}
              >
                <div className="flex items-center gap-3">
                  <ZodiacIcon
                    signIndex={chart.points.sun.sign}
                    name={data.signs[chart.points.sun.sign].name}
                    className="h-20 w-20"
                  />
                  <div className="min-w-0 flex-1">
                    <h3 className="mb-0.5 break-words text-[17px] font-semibold leading-6">
                      {p.profile?.display_name || t.brandName}
                    </h3>
                    <div className="flex flex-wrap gap-x-3 gap-y-0.5 text-xs leading-5 text-ink/85">
                      <span className="inline-flex items-center gap-1">
                        <CalendarDays size={12} className="shrink-0 text-gold" />
                        {p.profile?.birth_date}
                      </span>
                      <span className="inline-flex min-w-0 items-center gap-1">
                        <Clock3 size={12} className="shrink-0 text-gold" />
                        <span>{formatBirthTime(p.profile?.birth_time, t)}</span>
                      </span>
                    </div>
                    <p className="mt-0.5 flex items-start gap-1 text-xs leading-5 text-muted">
                      <MapPin size={12} className="mt-1 shrink-0 text-gold" />
                      <span className="min-w-0 break-words">
                        {p.profile?.birthplace || value?.location?.nameEnglish}
                      </span>
                    </p>
                  </div>
                </div>
                <div className="mt-3 grid grid-cols-3 gap-2 border-t border-line pt-2">
                  {(['sun', 'moon', 'ascendant'] as const).map((key) => (
                    <div key={key} className="text-center text-xs leading-5">
                      <span className="block text-[10px] text-muted">
                        {t[key === 'sun' ? 'q_sun' : key === 'moon' ? 'q_moon' : 'q_asc']}
                      </span>
                      <b className="block font-medium text-accent">
                        {data.signs[chart.points[key].sign].name}
                      </b>
                    </div>
                  ))}
                </div>
              </section>
            </>
          ) : unknownTime || value?.status === 'time-unknown' ? (
            <BirthOverview p={p} />
          ) : value?.status === 'location-required' ? (
            <section className="space-y-4" data-testid="chart-location-required">
              <p className="jy-copy">{t.th_missingPlace}</p>
              <button className="jy-primary w-full" onClick={() => p.navigate('profile')}>
                {t.j_editBirth}
              </button>
            </section>
          ) : !p.profile ? (
            <div data-testid="thai-chart-placeholder">
              <div className="rounded-2xl bg-panel p-3 [&_svg]:bg-transparent">
                <ThaiOrbitWheel
                  t={t}
                  language={p.language}
                  profile={p.profile}
                  location={value?.location}
                />
              </div>
            </div>
          ) : null}
          {!p.example && chart && (
            <button
              className="btn-quiet mt-4 border border-line"
              onClick={() => p.navigate('profile')}
            >
              <UserRound size={14} />
              {p.profile ? t.edit : t.createProfile}
            </button>
          )}
        </section>
        {chart && (
          <NatalChartDetails
            key={p.profile ? JSON.stringify(p.profile) : 'example'}
            chart={chart}
            p={p}
          />
        )}
        {value?.taksa && (
          <section className="panel p-6">
            <h2 className="mb-5 font-display text-xl">{t.th_taksa}</h2>
            <div className="grid grid-cols-2 gap-3">
              {taksaKeys.map((key, i) => (
                <div key={key} className="rounded-xl border border-line p-3">
                  <p className="text-xs text-muted">{t.th_taksaLabels.split('｜')[i]}</p>
                  <p lang="th" className="mt-1 text-[10px] text-gold">
                    {taksaThai[i]}
                  </p>
                  <b className="mt-2 block font-display text-2xl text-accent">
                    {value.taksa![key]}
                  </b>
                </div>
              ))}
            </div>
            <Note>{t.th_taksaNote}</Note>
          </section>
        )}
      </div>
      {chart && (
        <>
          <section className="panel mt-5 p-6">
            <button
              className="btn-primary"
              disabled={calculating}
              onClick={() => void getTransits()}
            >
              {calculating && <RefreshCw size={14} className="animate-spin" />}
              {t.th_transits}
            </button>
            <Note>{t.th_transitNote}</Note>
            {transitError && (
              <p role="alert" className="mt-4 text-sm text-accent">
                {transitError}
              </p>
            )}
            {transit?.status === 'ready' && (
              <div className="mt-5">
                <p className="text-xs text-muted">
                  {new Intl.DateTimeFormat(t.dateLocale, {
                    timeZone: 'Asia/Bangkok',
                    dateStyle: 'medium',
                    timeStyle: 'short',
                  }).format(new Date(transit.calculated_at))}{' '}
                  · {t.w_bangkok}
                </p>
                <ul className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                  {Object.entries(transit.comparison).map(([key, factor]) => {
                    const point =
                      transit.transit.points[key as keyof typeof transit.transit.points];
                    return (
                      <li key={key} className="rounded-lg bg-canvas p-4 text-xs leading-6">
                        {point.number} {point.nameThai} · {data.signs[point.sign].name}{' '}
                        {point.degrees}° {point.minutes.toFixed(1)}′<br />
                        {t.th_house} {factor.natalHouse}
                      </li>
                    );
                  })}
                </ul>
              </div>
            )}
          </section>
        </>
      )}
      {chart && (
        <div className="mt-6 space-y-2 rounded-[18px] border border-line bg-panel p-3">
          <button
            className="jy-primary w-full"
            onClick={() =>
              document
                .getElementById('natal-chart-data')
                ?.scrollIntoView({ behavior: 'smooth', block: 'start' })
            }
          >
            {t.c_viewData}
          </button>
          {!p.example && (
            <button className="jy-outline w-full" onClick={() => p.navigate('profile')}>
              {t.c_updateBirth}
            </button>
          )}
        </div>
      )}
    </>
  );
}
