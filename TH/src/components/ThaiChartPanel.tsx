import { useEffect, useRef, useState } from 'react';
import { CalendarDays, Clock3, MapPin, RefreshCw, UserRound } from 'lucide-react';
import type { ThaiHoroscope } from 'thai-astrology';
import { api } from '../lib/api';
import { ThaiRasiWheel } from './ThaiRasiWheel';
import { ThaiOrbitWheel } from './ThaiOrbitWheel';
import { NatalChartDetails } from './NatalChartDetails';
import { ZodiacIcon } from './ZodiacIcon';
import { ChartCalculationNote } from './ChartCalculationNote';
import { formatBirthTime } from '../lib/birthTime';
import { contentFor } from '../lib/wanjai';
import { taksaKeys, taksaThai, type ThaiTransits } from '../lib/thai';
import { PageIntro, Note, type WanjaiPageProps } from './wanjai/WanjaiShared';

export function ThaiChartPanel(p: WanjaiPageProps & { hideIntro?: boolean; example?: boolean }) {
  const { t, thai } = p;
  const value = thai.value;
  const chart = value?.chart;
  const data = contentFor(p.language);
  const [mode, setMode] = useState<keyof ThaiHoroscope['charts']>('rasi');
  const [wheelView, setWheelView] = useState<'orbit' | 'traditional'>('orbit');
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
  const weekday = (n: number | null | undefined) =>
    n == null
      ? '—'
      : new Intl.DateTimeFormat(t.dateLocale, { weekday: 'long', timeZone: 'UTC' }).format(
          new Date(Date.UTC(2024, 8, n)),
        );
  const lunar = value?.calendar.thaiLunarDate;
  return (
    <>
      {!p.hideIntro && <PageIntro title={t.th_title} sub={t.th_intro} />}
      {thai.loading && (
        <p role="status" className="panel mb-5 flex items-center gap-3 p-6 text-sm">
          <RefreshCw size={16} className="animate-spin" />
          {t.th_loading}
        </p>
      )}
      {thai.error && (
        <div role="alert" className="panel mb-5 p-5">
          <p className="text-sm text-accent">{thai.error}</p>
          <button className="btn-quiet mt-3" onClick={thai.retry}>
            {t.retry}
          </button>
        </div>
      )}
      <div className="grid items-start gap-5">
        <section className={chart ? 'min-w-0' : 'panel p-5 sm:p-7'}>
          <h2 className="mb-4 font-display text-xl">
            {p.example ? t.j_exampleChart : t.th_personal}
          </h2>
          {chart ? (
            <>
              <ChartCalculationNote value={value} t={t} />
              <div className="mb-4 grid grid-cols-2 gap-2">
                {(['orbit', 'traditional'] as const).map((view) => (
                  <button
                    key={view}
                    className={`min-h-11 rounded-xl border px-2 py-2 text-xs ${wheelView === view ? 'border-gold/70 bg-[#f3ead9] text-[#85633c]' : 'border-line text-muted'}`}
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
              <section
                className="mt-6 rounded-[22px] border border-[#d6bb8f] bg-[#f2e8d7] p-4"
                data-testid="natal-birth-card"
                aria-label={t.c_profileCard}
              >
                <div className="flex items-center gap-3">
                  <ZodiacIcon
                    signIndex={chart.points.sun.sign}
                    name={data.signs[chart.points.sun.sign].name}
                    className="h-16 w-16"
                  />
                  <div className="min-w-0 flex-1">
                    <h3 className="mb-1 text-lg font-semibold">
                      {p.profile?.display_name || t.brandName}
                    </h3>
                    <div className="flex flex-wrap gap-x-3 text-xs leading-7 text-[#8e7351]">
                      <span className="inline-flex items-center gap-1">
                        <CalendarDays size={12} />
                        {p.profile?.birth_date}
                      </span>
                      <span className="inline-flex items-center gap-1">
                        <Clock3 size={12} />
                        {formatBirthTime(p.profile?.birth_time, t)}
                      </span>
                    </div>
                    <p className="flex items-start gap-1 text-xs leading-6 text-[#8e7351]">
                      <MapPin size={12} className="mt-1 shrink-0" />
                      {p.profile?.birthplace || value?.location?.nameEnglish} ·{' '}
                      {p.profile?.timezone}
                    </p>
                  </div>
                </div>
                <div className="mt-4 grid grid-cols-3 gap-2 border-t border-[#dac6a6] pt-3">
                  {(['sun', 'moon', 'ascendant'] as const).map((key) => (
                    <div key={key} className="text-center text-xs leading-6">
                      <span className="block text-[10px] text-muted">
                        {t[key === 'sun' ? 'q_sun' : key === 'moon' ? 'q_moon' : 'q_asc']}
                      </span>
                      <b className="font-medium text-accent">
                        {data.signs[chart.points[key].sign].name}
                      </b>
                    </div>
                  ))}
                </div>
              </section>
            </>
          ) : value || !p.profile ? (
            <div data-testid="thai-chart-placeholder">
              <div className="rounded-2xl bg-[#f6f0e4] p-3 [&_svg]:bg-transparent">
                <ThaiOrbitWheel
                  t={t}
                  language={p.language}
                  profile={p.profile}
                  location={value?.location}
                />
              </div>
              <h3 className="mb-2 mt-5 text-base font-medium">{t.th_chartPending}</h3>
              <p className="text-[13px] leading-7 text-muted">
                {!p.profile
                  ? t.w_noBirth
                  : value?.status === 'time-unknown'
                    ? t.th_unknown
                    : t.th_missingPlace}
              </p>
              <button className="jy-primary mt-4 w-full" onClick={() => p.navigate('profile')}>
                <UserRound size={15} />
                {t.j_editBirth}
              </button>
              <button className="jy-outline mt-3 w-full" onClick={() => p.navigate('example')}>
                {t.j_exampleChart}
              </button>
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
          <Note>{t.th_factOnly}</Note>
        </section>
        {chart && (
          <NatalChartDetails
            key={p.profile ? JSON.stringify(p.profile) : 'example'}
            chart={chart}
            p={p}
          />
        )}
        <div className="space-y-5">
          {value && (
            <section className="panel p-6">
              <h2 className="mb-4 font-display text-xl">{t.th_calendar}</h2>
              <dl className="space-y-4 text-sm">
                <div>
                  <dt className="text-xs text-muted">{t.th_civilDay}</dt>
                  <dd className="mt-2">{weekday(value.calendar.civilWeekday)}</dd>
                </div>
                <div>
                  <dt className="text-xs text-muted">{t.th_astroDay}</dt>
                  <dd className="mt-2">{weekday(value.calendar.astrologicalWeekday)}</dd>
                </div>
                <div>
                  <dt className="text-xs text-muted">{t.th_lunar}</dt>
                  <dd className="mt-2 leading-7">
                    {lunar
                      ? `${lunar.phase === 'waxing' ? t.th_waxing : t.th_waning} ${lunar.day} · ${lunar.month}${lunar.secondEighthMonth ? ' (8/2)' : ''} ${t.th_lunarMonth}`
                      : t.th_noLunar}
                  </dd>
                </div>
              </dl>
            </section>
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
          {p.children}
        </div>
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
      <details className="mt-6 rounded-xl border border-line p-5 text-xs leading-7 text-muted">
        <summary className="cursor-pointer text-accent">{t.th_rules}</summary>
        <p className="mt-3">{t.th_rulesNote}</p>
        <p className="mt-3">{t.th_taksaNote}</p>
        <p className="mt-3">{t.th_seatNote} GeoNames · CC BY 4.0</p>
        <p className="mt-3">
          thai-astrology 0.3.2 · MIT · whole-sign · CE 1582–2076 ({t.th_lunar})
        </p>
        <a
          className="mt-3 block text-accent underline"
          href="https://github.com/kongesque/thai-astrology/tree/445577e7cbc8c09ddc98f2ec016cd3d1e32940fb"
          target="_blank"
          rel="noreferrer"
        >
          GitHub · kongesque/thai-astrology ↗
        </a>
        <a
          className="mt-2 block text-accent underline"
          href={`/reports/thai-validation.html?lang=${p.language}`}
          target="_blank"
          rel="noreferrer"
        >
          {t.th_validation} ↗
        </a>
      </details>
      <Note>{t.th_noGuarantee}</Note>
      {chart && (
        <div className="mt-6 space-y-2 rounded-[18px] border border-[#e3d6c1] bg-[#f7f4ed] p-3">
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
