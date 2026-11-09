import { ArrowLeft, ArrowRight, BookOpen, RefreshCw, UserRound } from 'lucide-react';
import { contentFor } from '../lib/wanjai';
import { chartRelations, type ChartRelationKind } from '../lib/chartGeometry';
import { fillCopy } from '../lib/fortune';
import { planetLabel } from './OrbitEvidence';
import { ZodiacIcon } from './ZodiacIcon';
import { ChartCalculationNote } from './ChartCalculationNote';
import { formatBirthTime } from '../lib/birthTime';
import { PageIntro, type WanjaiPageProps } from './wanjai/WanjaiShared';

const pointKeys = [
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
  const signs = contentFor(p.language).signs;
  const roles = t.r_roles.split('｜');
  const houseTitles = t.r_houseTitles.split('｜');
  const houseNotes = t.r_houseNotes.split('｜');
  const relationNotes = t.r_relationNotes.split('｜');
  const links = chart ? chartRelations(chart) : [];
  return (
    <div className="min-w-0 space-y-5 [overflow-wrap:anywhere]" data-testid="chart-reading-page">
      <button
        className="inline-flex min-h-11 items-center gap-2 text-sm text-[#9b8058]"
        onClick={() => p.navigate('chart')}
      >
        <ArrowLeft size={17} />
        {t.r_back}
      </button>
      <PageIntro title={t.r_title} sub={t.r_intro} />
      {profile && (
        <section
          className="rounded-[20px] border border-[#d6bb8f] bg-[#f2e8d7] p-5"
          data-testid="reading-birth-source"
        >
          <p className="jy-kicker">{t.c_birthSource}</p>
          <h2 className="mb-2 mt-1 text-lg font-medium">{profile.display_name || t.brandName}</h2>
          <p className="text-sm leading-7">
            {profile.birth_date} · {formatBirthTime(profile.birth_time, t)}
          </p>
          <p className="text-xs leading-7 text-muted">
            {profile.birthplace || value?.location?.nameEnglish || '—'}
            {(profile.birthplace || value?.location) && ` · ${profile.timezone}`}
          </p>
        </section>
      )}
      {thai.loading && (
        <p role="status" className="jy-card flex items-center gap-3 text-sm">
          <RefreshCw size={16} className="animate-spin" />
          {t.th_loading}
        </p>
      )}
      {thai.error && (
        <section role="alert" className="jy-card">
          <p className="jy-copy">{thai.error}</p>
          <button className="jy-outline mt-3" onClick={thai.retry}>
            {t.retry}
          </button>
        </section>
      )}
      {!thai.loading && !thai.error && !chart && (
        <section className="jy-card" data-testid="reading-incomplete">
          <BookOpen size={25} className="mb-4 text-gold" />
          <h2 className="mb-3 text-lg">{t.th_chartPending}</h2>
          <p className="jy-copy">
            {!profile
              ? t.w_noBirth
              : value?.status === 'time-unknown'
                ? t.th_unknown
                : t.th_missingPlace}
          </p>
          <button className="jy-primary mt-5 w-full" onClick={() => p.navigate('profile')}>
            <UserRound size={16} />
            {t.j_editBirth}
          </button>
        </section>
      )}
      {chart && (
        <>
          <ChartCalculationNote value={value} t={t} />
          <section>
            <h2 className="mb-3 text-lg font-medium">{t.r_overview}</h2>
            <div className="grid grid-cols-3 gap-2">
              {(['sun', 'moon', 'ascendant'] as const).map((key) => {
                const point = chart.points[key];
                return (
                  <article
                    key={key}
                    className="min-w-0 rounded-[18px] border border-line bg-panel p-3 text-center"
                    data-reading-point={key}
                  >
                    <ZodiacIcon
                      signIndex={point.sign}
                      name={signs[point.sign].name}
                      className="mx-auto mb-2 h-12 w-12"
                    />
                    <h3 className="text-xs text-muted">
                      {t[key === 'sun' ? 'q_sun' : key === 'moon' ? 'q_moon' : 'q_asc']}
                    </h3>
                    <p className="my-2 text-sm font-medium text-accent">{signs[point.sign].name}</p>
                    <p className="text-[11px] leading-6 text-muted">
                      {roles[pointKeys.indexOf(key)]}
                    </p>
                  </article>
                );
              })}
            </div>
            <p className="mt-3 text-xs leading-7 text-muted">{t.r_natalScope}</p>
          </section>
          <section className="jy-card !p-0" data-testid="reading-planets">
            <h2 className="border-b border-line p-5 text-lg font-medium">{t.r_planets}</h2>
            {pointKeys.map((key, index) => {
              const point = chart.points[key];
              return (
                <details
                  key={key}
                  className="border-b border-line last:border-0"
                  data-reading-detail={key}
                >
                  <summary className="cursor-pointer px-5 py-4 text-sm leading-7">
                    <span className="font-medium">{planetLabel(key, t)}</span>
                    <span className="ml-2 text-xs text-muted">
                      {signs[point.sign].name} · {t.th_house} {point.house}
                    </span>
                  </summary>
                  <div className="space-y-2 px-5 pb-5 text-sm leading-7 text-[#765b4e]">
                    <p>{roles[index]}</p>
                    <p>
                      {fillCopy(t.r_planetContext, {
                        house: point.house,
                        theme: houseTitles[point.house - 1],
                      })}
                    </p>
                    <p className="text-xs text-muted">
                      {t.c_signPosition} · {signs[point.sign].name} · {point.degrees}°{' '}
                      {point.minutes.toFixed(1)}′
                    </p>
                  </div>
                </details>
              );
            })}
          </section>
          <section className="jy-card !p-0" data-testid="reading-houses">
            <h2 className="border-b border-line p-5 text-lg font-medium">{t.r_houses}</h2>
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
                <div className="space-y-3 px-5 pb-5 text-sm leading-7 text-[#765b4e]">
                  <p>{houseNotes[house.number - 1]}</p>
                  <dl className="grid grid-cols-[auto_1fr] gap-x-3 gap-y-2 text-xs">
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
          <section className="jy-card" data-testid="reading-relations">
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
                <li
                  key={`${line.from.key}-${line.to.key}`}
                  className="flex flex-wrap items-start justify-between gap-x-3 gap-y-1 py-3 text-xs leading-6"
                >
                  <span className="inline-flex items-center gap-2">
                    <i className="h-0.5 w-5 shrink-0" style={{ backgroundColor: line.color }} />
                    {planetLabel(line.from.key, t)} · {planetLabel(line.to.key, t)}
                  </span>
                  <span className="ml-auto max-w-full text-right text-muted">
                    {t[`c_relation_${line.kind}`]}
                  </span>
                </li>
              ))}
            </ul>
          </section>
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
        {t.r_scope}
      </p>
      <button className="jy-outline w-full" onClick={() => p.navigate('chart')}>
        <ArrowLeft size={16} />
        {t.r_back}
      </button>
    </div>
  );
}
