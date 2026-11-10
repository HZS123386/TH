import { useEffect, useState } from 'react';
import type { ThaiHoroscope } from 'thai-astrology';
import {
  ArrowLeft,
  ArrowRight,
  BookOpen,
  Bookmark,
  Download,
  RefreshCw,
  UserRound,
} from 'lucide-react';
import { contentFor } from '../lib/wanjai';
import { chartRelations, planetSymbols, type ChartRelationKind } from '../lib/chartGeometry';
import { natalPlanetShares, natalReadingCopy, readingPlanetKeys } from '../lib/natalReading';
import { zodiacAbbreviation } from '../lib/zodiac';
import { fillCopy } from '../lib/fortune';
import { planetLabel } from './OrbitEvidence';
import { ZodiacIcon } from './ZodiacIcon';
import { ChartCalculationNote } from './ChartCalculationNote';
import { ThaiOrbitWheel } from './ThaiOrbitWheel';
import {
  NatalReadingDistribution,
  NatalReadingSummary,
  NatalReadingTopics,
} from './NatalReadingSections';
import {
  captureReading,
  saveReading,
  downloadReading,
  type SavedReading,
} from '../lib/readingLibrary';
import { formatBirthTime } from '../lib/birthTime';
import { BirthOverview } from './BirthOverview';
import type { WanjaiPageProps } from './wanjai/WanjaiShared';

const roleKeys = [
  'sun',
  'moon',
  'mars',
  'mercury',
  'jupiter',
  'venus',
  'saturn',
  'rahu',
  'ketu',
  'uranus',
  'ascendant',
] as const;
const relationKinds: ChartRelationKind[] = ['trine', 'sextile', 'square', 'opposition'];

export function ThaiChartReading(p: WanjaiPageProps) {
  const { t, thai, profile } = p;
  const value = thai.value;
  const chart = value?.chart;
  const unknownTime = !!profile && profile.birth_time === null;
  const signs = contentFor(p.language).signs;
  const roles = t.r_roles.split('｜');
  const roleFor = (key: keyof ThaiHoroscope['points']) => roles[roleKeys.indexOf(key)];
  const houseTitles = t.r_houseTitles.split('｜');
  const houseNotes = t.r_houseNotes.split('｜');
  const relationNotes = t.r_relationNotes.split('｜');
  const links = chart ? chartRelations(chart) : [];
  const planetShares = chart ? natalPlanetShares(chart) : [];
  const copy = natalReadingCopy(p.language);
  const [highlightedPoints, setHighlightedPoints] = useState<(keyof ThaiHoroscope['points'])[]>([]);
  const [saveStatus, setSaveStatus] = useState('');
  const [saveError, setSaveError] = useState(false);
  function exportReading(download = false) {
    const element = document.querySelector<HTMLElement>('[data-testid="chart-reading-page"]');
    if (!element || !profile || !chart) return;
    const reading: SavedReading = {
      id: crypto.randomUUID(),
      title: `${profile.display_name || t.brandName} · ${t.ux_natalReport}`,
      birthDate: profile.birth_date,
      savedAt: Date.now(),
      html: captureReading(element, t.r_title),
    };
    try {
      if (download) downloadReading(reading);
      else saveReading(p.account?.user_id || 'guest', reading);
      setSaveError(false);
      setSaveStatus(download ? t.ux_downloadedReport : t.ux_savedReport);
    } catch {
      setSaveError(true);
      setSaveStatus(t.ux_saveFailed);
    }
  }
  useEffect(() => setHighlightedPoints([]), [chart]);
  function focusPoints(keys: (keyof ThaiHoroscope['points'])[]) {
    setHighlightedPoints(keys);
    const drawing = document.getElementById('reading-chart');
    drawing?.scrollIntoView({ block: 'start' });
    drawing?.focus({ preventScroll: true });
  }
  return (
    <div className="min-w-0 space-y-5 [overflow-wrap:anywhere]" data-testid="chart-reading-page">
      <button
        className="inline-flex min-h-11 items-center gap-2 text-sm text-muted"
        onClick={() => p.navigate('chart')}
      >
        <ArrowLeft size={17} />
        {t.r_back}
      </button>
      <header className="space-y-2">
        <h1 className="text-xl font-medium leading-relaxed">{t.r_title}</h1>
        <p className="text-xs leading-6 text-muted">{t.r_intro}</p>
      </header>
      {profile && (
        <section className="border-0 bg-transparent p-3" data-testid="reading-birth-source">
          <p className="sr-only">{t.c_birthSource}</p>
          <h2 className="mb-1 text-base font-medium">{profile.display_name || t.brandName}</h2>
          <p className="text-xs leading-6">
            {profile.birth_date} · {formatBirthTime(profile.birth_time, t)}
          </p>
          <p className="text-[11px] leading-5 text-muted">
            {profile.birthplace || value?.location?.nameEnglish || '—'}
          </p>
        </section>
      )}
      {thai.loading && !unknownTime && (
        <p role="status" className="jy-card flex items-center gap-3 text-sm">
          <RefreshCw size={16} className="animate-spin" />
          {t.th_loading}
        </p>
      )}
      {thai.error && !unknownTime && (
        <section role="alert" className="jy-card">
          <p className="jy-copy">{thai.error}</p>
          <button className="jy-outline mt-3" onClick={thai.retry}>
            {t.retry}
          </button>
        </section>
      )}
      {!chart && (unknownTime || (!thai.loading && !thai.error)) && (
        <section className="jy-card" data-testid="reading-incomplete">
          {unknownTime || value?.status === 'time-unknown' ? (
            <BirthOverview p={p} />
          ) : (
            <>
              <BookOpen size={25} className="mb-4 text-gold" />
              <h2 className="mb-3 text-lg">{t.th_chartPending}</h2>
              <p className="jy-copy">{!profile ? t.w_noBirth : t.th_missingPlace}</p>
              <button className="jy-primary mt-5 w-full" onClick={() => p.navigate('profile')}>
                <UserRound size={16} />
                {t.j_editBirth}
              </button>
            </>
          )}
        </section>
      )}
      {chart && (
        <>
          <NatalReadingSummary chart={chart} p={p} />
          <div data-testid="reading-library-actions" className="space-y-2">
            <div className="grid grid-cols-2 gap-2">
              <button className="jy-outline !px-2 !text-xs" onClick={() => exportReading()}>
                <Bookmark size={15} />
                {t.ux_saveReport}
              </button>
              <button className="jy-outline !px-2 !text-xs" onClick={() => exportReading(true)}>
                <Download size={15} />
                {t.ux_downloadReport}
              </button>
            </div>
            {saveStatus && (
              <p role={saveError ? 'alert' : 'status'} className="text-xs leading-6 text-gold">
                {saveStatus}
              </p>
            )}
            <button
              className="min-h-10 text-xs text-muted underline underline-offset-4"
              onClick={() => p.navigate('reports')}
            >
              {t.ux_reports}
            </button>
          </div>
          <nav
            aria-label={copy.navigation}
            className="sticky top-[62px] z-20 -mx-1 flex gap-2 overflow-x-auto rounded-2xl border border-line bg-canvas/95 p-2 backdrop-blur [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
            data-testid="reading-contents"
          >
            {['overview', 'elements', 'planets', 'houses', 'relations', 'topics'].map(
              (id, index) => (
                <button
                  key={id}
                  type="button"
                  className="min-h-9 shrink-0 rounded-full border border-line bg-panel px-3 py-1.5 text-xs text-muted hover:border-gold/60 hover:text-gold"
                  onClick={() =>
                    document.getElementById(`reading-${id}`)?.scrollIntoView({ block: 'start' })
                  }
                >
                  {copy.sections[index]}
                </button>
              ),
            )}
          </nav>
          <section
            id="reading-chart"
            tabIndex={-1}
            className="scroll-mt-32 border-0 bg-transparent p-4"
            data-testid="reading-chart"
          >
            <div className="flex flex-wrap items-center justify-between gap-2">
              <h2 className="text-sm font-medium text-ink/85">{copy.chartTitle}</h2>
              <span className="rounded-full bg-surface px-2 py-1 text-[10px] text-gold/90">
                {copy.basicReport}
              </span>
            </div>
            <ThaiOrbitWheel
              chart={chart}
              t={t}
              language={p.language}
              profile={profile}
              location={value?.location}
              showDetails={false}
              highlightedPoints={highlightedPoints}
            />
            <div className="mt-2 flex flex-wrap items-center gap-x-3 gap-y-2 text-[11px] text-muted">
              <span className="inline-flex items-center gap-1.5">
                <i className="h-2 w-2 rounded-full border border-gold bg-surface" />
                {copy.legend}
              </span>
              {highlightedPoints.length > 0 && (
                <>
                  <span>
                    {copy.focus} · {highlightedPoints.map((key) => planetLabel(key, t)).join(' / ')}
                  </span>
                  <button
                    type="button"
                    className="min-h-9 text-gold"
                    onClick={() => setHighlightedPoints([])}
                  >
                    {copy.reset}
                  </button>
                </>
              )}
            </div>
            <p className="mt-2 text-xs leading-6 text-muted">{copy.chartNote}</p>
            <details
              className="mt-3 text-xs leading-6 text-muted"
              data-testid="reading-chart-guide"
            >
              <summary className="cursor-pointer text-gold/90">{t.ux_chartGuide}</summary>
              <p className="mt-2">{t.ux_chartGuideNote}</p>
              <p className="mt-2">
                {signs
                  .map((sign, index) => `${zodiacAbbreviation(index)} ${sign.name}`)
                  .join(' · ')}
              </p>
              <p className="mt-2">
                {readingPlanetKeys
                  .map((key) => `${chart.points[key].number} ${planetLabel(key, t)}`)
                  .join(' · ')}
              </p>
            </details>
          </section>
          <section id="reading-overview" className="scroll-mt-32">
            <h2 className="mb-3 text-lg font-medium">{t.r_overview}</h2>
            <div className="grid grid-cols-2 gap-2">
              {(['sun', 'moon'] as const).map((key) => {
                const point = chart.points[key];
                return (
                  <article
                    key={key}
                    className="min-w-0 border-0 bg-transparent p-3 text-center"
                    data-reading-point={key}
                  >
                    <ZodiacIcon
                      signIndex={point.sign}
                      name={signs[point.sign].name}
                      className="mx-auto mb-2 h-12 w-12"
                    />
                    <h3 className="text-xs text-muted">{t[key === 'sun' ? 'q_sun' : 'q_moon']}</h3>
                    <p className="my-2 text-sm font-medium text-accent">{signs[point.sign].name}</p>
                    <p className="text-[11px] leading-6 text-muted">{roleFor(key)}</p>
                    <p className="mt-2 text-[11px] leading-6 text-ink/75">
                      {copy.signStyles[point.sign]}
                    </p>
                  </article>
                );
              })}
            </div>
            <p className="mt-3 text-xs leading-7 text-muted">{t.r_natalScope}</p>
          </section>
          <NatalReadingDistribution chart={chart} p={p} />
          <section
            id="reading-planets"
            className="scroll-mt-32 border-0 bg-transparent"
            data-testid="reading-planets"
          >
            <h2 className="mb-2 text-lg font-medium">{t.ux_planetShares}</h2>
            <p className="mb-5 text-xs leading-7 text-muted">{t.ux_planetSharesNote}</p>
            <div
              className="grid grid-cols-5 gap-x-3 gap-y-5 py-2"
              data-testid="reading-planet-selector"
            >
              {planetShares.map(({ key, count, total, percent }) => (
                <button
                  key={key}
                  type="button"
                  className="group flex min-w-0 flex-col items-center gap-2 bg-transparent text-center"
                  aria-label={`${copy.showOnChart} · ${planetLabel(key, t)}`}
                  aria-describedby={`reading-share-${key}`}
                  aria-pressed={highlightedPoints.includes(key)}
                  data-planet-choice={key}
                  onClick={() => focusPoints([key])}
                >
                  <span
                    className={`relative grid aspect-square w-full place-items-center rounded-full border bg-[radial-gradient(ellipse_at_28%_20%,rgba(206,171,239,0.16),transparent_55%),linear-gradient(145deg,#583276_0%,#3f205d_56%,#2b1646_100%)] text-[clamp(24px,6.5vw,34px)] leading-none shadow-[inset_0_1px_1px_rgb(224_200_245_/_0.2),inset_0_-3px_6px_rgb(34_12_58_/_0.35),0_3px_6px_rgb(27_11_44_/_0.25)] transition-colors ${highlightedPoints.includes(key) ? 'border-gold/80 text-gold' : 'border-[#a38ab9]/40 text-purple-200 group-hover:border-purple-300/65'}`}
                    data-planet-circle={key}
                  >
                    <span
                      aria-hidden="true"
                      className="[text-shadow:0_1px_1px_rgb(26_8_43_/_0.55),0_-1px_0_rgb(241_225_255_/_0.08)]"
                    >
                      {planetSymbols[key]}
                    </span>
                    <span
                      id={`reading-share-${key}`}
                      className="absolute -right-1 -top-1 rounded-full border border-[#c2a4cf]/25 bg-gradient-to-b from-[#643487] via-[#512770] to-[#3f1b5d] px-1.5 py-0.5 text-[10px] font-medium leading-4 tabular-nums text-[#f1e8f7] shadow-[inset_0_1px_0_rgb(249_230_255_/_0.14),0_2px_3px_rgb(31_10_51_/_0.3)]"
                      data-share-count={count}
                      data-share-total={total}
                      data-share-percent={percent ?? ''}
                    >
                      {percent === null ? '—' : `${percent}%`}
                    </span>
                  </span>
                  <span className="block text-[11px] leading-5 text-muted">
                    {planetLabel(key, t)}
                  </span>
                </button>
              ))}
            </div>
            <details
              className="mb-4 mt-3 text-[11px] leading-6 text-muted"
              data-testid="planet-share-method"
            >
              <summary className="cursor-pointer">{copy.planetShareTitle}</summary>
              <p className="mt-2">
                {planetShares[0]?.total ? copy.planetShareMethod : copy.planetShareEmpty}
              </p>
            </details>
            {readingPlanetKeys.map((key) => {
              const point = chart.points[key];
              return (
                <details
                  key={key}
                  className="scroll-mt-32 border-b border-line last:border-0"
                  data-reading-detail={key}
                >
                  <summary
                    className="cursor-pointer px-5 py-4 text-sm leading-7"
                    onClick={() => setHighlightedPoints([key])}
                  >
                    <span
                      className="mr-2 inline-block w-5 text-center text-lg text-gold/85"
                      aria-hidden="true"
                    >
                      {planetSymbols[key]}
                    </span>
                    <span className="font-medium">{planetLabel(key, t)}</span>
                    <span className="ml-2 text-xs text-muted">
                      {zodiacAbbreviation(point.sign)} · {point.degrees}°
                      {String(Math.floor(point.minutes)).padStart(2, '0')}′ · {t.th_house}{' '}
                      {point.house}
                    </span>
                  </summary>
                  <div className="space-y-2 px-5 pb-5 text-sm leading-7 text-ink/85">
                    <p>{roleFor(key)}</p>
                    <h3 className="pt-2 text-xs font-medium text-gold/90">
                      {copy.signStyleTitle} · {signs[point.sign].name}
                    </h3>
                    <p>{copy.signStyles[point.sign]}</p>
                    <p>
                      {fillCopy(t.r_planetContext, {
                        house: point.house,
                        theme: houseTitles[point.house - 1],
                      })}
                    </p>
                    <div className="rounded-xl bg-surface/70 p-3">
                      <h3 className="text-xs font-medium text-gold/90">{copy.observe}</h3>
                      <p className="mt-1">{copy.houseActions[point.house - 1]}</p>
                    </div>
                    <p className="text-xs text-muted">
                      {t.c_signPosition} · {signs[point.sign].name} · {point.degrees}°{' '}
                      {point.minutes.toFixed(1)}′
                    </p>
                    <button
                      type="button"
                      className="jy-outline w-full !text-xs"
                      onClick={() => focusPoints([key])}
                    >
                      {copy.showOnChart}
                    </button>
                  </div>
                </details>
              );
            })}
          </section>
          <section
            id="reading-houses"
            className="jy-card scroll-mt-32 !p-0"
            data-testid="reading-houses"
          >
            <h2 className="border-b border-line p-5 text-lg font-medium">{t.r_houses}</h2>
            <p className="px-5 pt-4 text-xs leading-7 text-muted">{copy.cuspNote}</p>
            {chart.houses.map((house) => (
              <details key={house.number} className="border-b border-line last:border-0">
                <summary className="cursor-pointer px-5 py-4 text-sm leading-7">
                  <span className="font-medium">
                    {house.number} · {houseTitles[house.number - 1]}
                  </span>
                  <span lang="th" className="ml-2 text-[11px] text-gold">
                    {house.nameThai}
                  </span>
                </summary>
                <div className="space-y-3 px-5 pb-5 text-sm leading-7 text-ink/85">
                  <p>{houseNotes[house.number - 1]}</p>
                  <p>{copy.houseActions[house.number - 1]}</p>
                  <dl className="grid grid-cols-[auto_1fr] gap-x-3 gap-y-2 text-xs">
                    <dt className="text-muted">{copy.houseCusp}</dt>
                    <dd>{zodiacAbbreviation(house.sign)} · 0°00′</dd>
                    <dt className="text-muted">{t.c_signPosition}</dt>
                    <dd>{signs[house.sign].name}</dd>
                    <dt className="text-muted">{t.r_ruler}</dt>
                    <dd>
                      {planetLabel(house.ruler.key, t)} · {t.th_house} {house.ruler.house}
                    </dd>
                    <dt className="text-muted">{t.r_occupants}</dt>
                    <dd>
                      {house.occupants.map((key) => planetLabel(key, t)).join(' · ') || t.r_empty}
                    </dd>
                  </dl>
                </div>
              </details>
            ))}
            <p className="border-t border-line p-5 text-xs leading-7 text-muted">{t.r_emptyNote}</p>
          </section>
          <section
            id="reading-relations"
            className="jy-card scroll-mt-32"
            data-testid="reading-relations"
          >
            <h2 className="mb-3 text-lg font-medium">
              {t.c_relationsTitle} · {links.length}
            </h2>
            <p className="text-xs leading-7 text-muted">{t.c_relationScope}</p>
            <div className="my-4 grid grid-cols-2 gap-3">
              {relationKinds.map((kind, index) => (
                <article key={kind} className="rounded-xl bg-canvas p-3">
                  <h3 className="text-xs font-medium text-accent">
                    {t[`c_relation_${kind}`]} · {links.filter((line) => line.kind === kind).length}
                  </h3>
                  <p className="mt-2 text-xs leading-6 text-muted">{relationNotes[index]}</p>
                </article>
              ))}
            </div>
            <ul className="divide-y divide-line">
              {links.map((line) => (
                <li key={`${line.from.key}-${line.to.key}`} className="py-3 text-xs leading-6">
                  <details>
                    <summary className="flex cursor-pointer flex-wrap items-start justify-between gap-x-3 gap-y-1">
                      <span className="inline-flex items-center gap-2">
                        <i className="h-0.5 w-5 shrink-0" style={{ backgroundColor: line.color }} />
                        {planetLabel(line.from.key, t)} · {planetLabel(line.to.key, t)}
                      </span>
                      <span className="ml-auto max-w-full text-right text-muted">
                        {t[`c_relation_${line.kind}`]}
                      </span>
                    </summary>
                    <p className="w-full text-ink/75">
                      {fillCopy(copy.relatedThemes, {
                        first: roleFor(line.from.key).replace(/[。.!！？?]+$/, ''),
                        second: roleFor(line.to.key).replace(/[。.!！？?]+$/, ''),
                      })}
                    </p>
                    <p className="w-full text-muted">
                      {relationNotes[relationKinds.indexOf(line.kind)]}
                    </p>
                    <button
                      type="button"
                      className="min-h-9 text-gold/85"
                      onClick={() => focusPoints([line.from.key, line.to.key])}
                    >
                      {copy.showOnChart}
                    </button>
                  </details>
                </li>
              ))}
            </ul>
          </section>
          <NatalReadingTopics chart={chart} p={p} onFocus={focusPoints} />
          <details
            className="rounded-2xl border border-line bg-panel p-4"
            data-testid="reading-calculation"
          >
            <summary className="cursor-pointer text-xs leading-6 text-muted">
              {copy.readingBasis}
            </summary>
            <div className="mt-3">
              <ChartCalculationNote value={value} t={t} />
            </div>
          </details>
          <section className="jy-card">
            <h2 className="mb-3 text-lg font-medium">{t.r_continue}</h2>
            <p className="jy-copy">{t.r_continueNote}</p>
            <button className="jy-primary mt-4 w-full" onClick={() => p.ask(t.c_chatChart)}>
              {t.w_questions}
              <ArrowRight size={16} />
            </button>
            <button className="jy-outline mt-3 w-full" onClick={() => p.navigate('overview')}>
              {t.w_home}
              <ArrowRight size={15} />
            </button>
          </section>
        </>
      )}
      <p className="text-xs leading-7 text-muted" data-testid="reading-scope">
        {copy.scope}
      </p>
      <button className="jy-outline w-full" onClick={() => p.navigate('chart')}>
        <ArrowLeft size={16} />
        {t.r_back}
      </button>
    </div>
  );
}
