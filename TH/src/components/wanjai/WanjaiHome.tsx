import { ArrowRight, Bell, RefreshCw, Sparkles } from 'lucide-react';
import { useEffect, useState } from 'react';
import type { Copy } from '../../lib/i18n';
import { type Topic } from '../../lib/wanjai';
import {
  fillCopy,
  useFortune,
  type FortuneFactor,
  type FortuneGeneration,
} from '../../lib/fortune';
import { WanjaiDaily } from './WanjaiCompanion';
import { ZodiacIcon } from '../ZodiacIcon';
import { JourneyCard, ReportsTeaser } from './WanjaiCards';
import { type WanjaiPageProps, topicIcons, usePage } from './WanjaiShared';

function FortuneStatus({
  generation,
  t,
  onRetry,
}: {
  generation: FortuneGeneration;
  t: Copy;
  onRetry: () => void;
}) {
  const [retryAt, setRetryAt] = useState(() => Date.now() + (generation.retry_after || 0) * 1000);
  const [now, setNow] = useState(Date.now);
  useEffect(() => {
    setRetryAt(Date.now() + (generation.retry_after || 0) * 1000);
    setNow(Date.now());
  }, [generation]);
  useEffect(() => {
    if (now >= retryAt) return;
    const timer = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(timer);
  }, [retryAt, now >= retryAt]);
  const message = !generation.available
    ? t.ux_rulesReady
    : generation.reason === 'limited'
      ? generation.limit_scope === 'personal'
        ? t.ux_personalLimit
        : generation.limit_scope === 'network'
          ? t.ux_sharedLimit
          : t.ux_serviceBusy
      : generation.reason === 'pending'
        ? t.ux_readingPending
        : t.ux_serviceBusy;
  const waiting = now < retryAt;
  return (
    <div
      role="status"
      className="mb-3 text-xs leading-6 text-muted"
      data-testid="fortune-fallback-status"
    >
      <p>{message}</p>
      {generation.available && (
        <>
          {generation.retry_after && (
            <p>
              {fillCopy(t.ux_retryAt, {
                time: new Intl.DateTimeFormat(t.dateLocale, {
                  ...(new Date(retryAt).toLocaleDateString() !== new Date(now).toLocaleDateString()
                    ? { month: 'short', day: 'numeric' }
                    : {}),
                  hour: '2-digit',
                  minute: '2-digit',
                  ...(generation.retry_after! < 3600 ? { second: '2-digit' } : {}),
                }).format(new Date(retryAt)),
              })}
            </p>
          )}
          <button
            disabled={waiting}
            className="mt-1 min-h-10 underline underline-offset-4"
            onClick={onRetry}
          >
            {waiting ? t.ux_retryWaiting : t.ux_retryReading}
          </button>
        </>
      )}
    </div>
  );
}

export function WanjaiHome(p: WanjaiPageProps) {
  const { t, state, update, navigate } = p;
  const { data, concern } = usePage(p);
  const fortune = useFortune(p.profile, state.period, p.language, p.account?.user_id || 'guest');
  const value = fortune.value;
  const focusTopic = (concern?.topic as Topic | null) || state.topic;
  const focus = value?.readings[focusTopic];
  const date = (iso: string) =>
    new Intl.DateTimeFormat(t.dateLocale, {
      month: 'short',
      day: 'numeric',
      timeZone: 'UTC',
    }).format(new Date(`${iso}T12:00:00Z`));
  const signs = value?.birth.reference_signs.map((i) => data.signs[i]);
  const reference = signs?.map((sign) => sign.name).join(' / ');
  const factorLabel = (factor: FortuneFactor) => {
    const planets = factor.bodies
      .map((body) => t[`c_planet_${body}` as keyof typeof t] || body)
      .join(' · ');
    if (factor.kind === 'sign_change')
      return `${planets} · ${data.signs[factor.from_sign!].name} → ${data.signs[factor.sign!].name} · ${t.o_betweenSamples}`;
    if (factor.kind === 'sign_relationship')
      return `${planets} · ${t[`c_relation_${factor.relationship!}`]}`;
    return `${planets} · ${data.signs[factor.sign!].name} · ${t.f_position} ${factor.positions?.map((position) => position.position).join(' / ')} · ${fillCopy(t.o_observed, { count: factor.sample_count!, total: factor.total_samples! })}`;
  };
  const ask = (topic: Topic) =>
    p.ask(
      [
        `${t[`w_${state.period}`]} · ${data.topics.find((row) => row.id === topic)?.name}`,
        t.f_chatReading,
        concern?.question,
      ]
        .filter(Boolean)
        .join('\n'),
    );
  return (
    <div className="space-y-[18px]" data-testid="jy-fortune-page">
      <div className="flex items-center justify-between gap-3 pb-0.5">
        <div>
          <p className="mb-2 text-[11px] text-muted">
            {p.profile?.display_name || reference || t.brandName}
          </p>
          <h1 className="text-[21px] font-semibold leading-8 tracking-tight">{t.w_hello}</h1>
        </div>
        <button
          aria-label={t.w_chart}
          onClick={() => navigate('chart')}
          className="grid h-12 w-12 shrink-0 place-items-center rounded-full text-gold"
        >
          {value && signs?.length ? (
            <span className="flex -space-x-3">
              {value.birth.reference_signs.map((signIndex) => (
                <ZodiacIcon
                  key={signIndex}
                  signIndex={signIndex}
                  name={data.signs[signIndex].name}
                  className={signs.length === 1 ? 'h-12 w-12' : 'h-8 w-8'}
                />
              ))}
            </span>
          ) : (
            <Sparkles size={22} />
          )}
        </button>
      </div>
      <section aria-label={t.w_home}>
        <div
          role="group"
          aria-label={t.w_home}
          className="grid grid-cols-3 gap-[3px] rounded-[14px] bg-surface p-[5px]"
        >
          {(['today', 'week', 'month'] as const).map((period) => (
            <button
              key={period}
              aria-pressed={state.period === period}
              onClick={() => update({ period })}
              className={`min-h-11 rounded-[10px] px-1 py-2.5 text-sm ${state.period === period ? 'bg-primary text-on-primary shadow-sm' : 'text-muted'}`}
            >
              {t[`w_${period}`]}
            </button>
          ))}
        </div>
        <div className="mt-3 flex flex-wrap items-center justify-between gap-2 text-[11px] text-muted">
          <span>
            {value
              ? `${date(value.period_start)}${value.period_end !== value.period_start ? ` — ${date(value.period_end)}` : ''}`
              : t.loading}{' '}
            · {t.w_bangkok}
          </span>
          <small>{value?.narrative.source === 'ai' ? t.o_ai : t.f_computed}</small>
        </div>
      </section>
      {fortune.loading && (
        <p role="status" className="jy-card flex items-center gap-3 text-sm">
          <RefreshCw size={17} className="animate-spin" />
          {fillCopy(t.f_calculating, { period: t[`w_${state.period}`] })}
        </p>
      )}
      {fortune.error && (
        <div role="alert" className="jy-card">
          <p className="jy-copy">{fortune.error}</p>
          <button className="jy-outline mt-3" onClick={fortune.retry}>
            {t.retry}
          </button>
        </div>
      )}
      {value && focus && (
        <>
          <section
            data-testid="fortune-focus"
            data-period={value.period}
            aria-label={t[`w_${value.period}`]}
            aria-live="polite"
            className="rounded-[20px] border border-gold/35 bg-[radial-gradient(ellipse_at_top_right,#4c2c6655,transparent_70%)] bg-surface p-[17px]"
          >
            <p className="mb-3 text-xs text-accent">{t[`n_motto_${value.period}`]}</p>
            <h2 className="text-[18px] font-medium leading-8 text-gold">
              {value.narrative.affirmation}
            </h2>
            <div className="mt-5 border-t border-line pt-4">
              <h3 className="mb-3 text-base font-medium text-accent">{t[`w_${value.period}`]}</h3>
              {fortune.writing && (
                <p
                  role="status"
                  className="mb-3 flex items-center gap-2 text-xs leading-6 text-muted"
                >
                  <RefreshCw size={14} className="shrink-0 animate-spin" />
                  {t.o_generating}
                </p>
              )}
              {!fortune.writing && value.generation?.state === 'fallback' && (
                <FortuneStatus generation={value.generation} t={t} onRetry={fortune.retry} />
              )}
              <div
                className="space-y-4 text-sm leading-8 text-ink/85"
                data-testid="fortune-narrative"
              >
                {value.narrative.paragraphs.map((paragraph, index) => {
                  const source = value.narrative.paragraph_evidence?.[index]?.[0];
                  const factor = value.analysis?.factors.find((row) => row.id === source);
                  return (
                    <div key={index}>
                      {factor && (
                        <p
                          className="mb-1 text-[10px] leading-5 text-muted"
                          data-testid="fortune-paragraph-evidence"
                        >
                          {factorLabel(factor)}
                        </p>
                      )}
                      <p>{paragraph}</p>
                    </div>
                  );
                })}
              </div>
            </div>
            <p className="mt-4 text-xs leading-6 text-ink/85">
              {fillCopy(t.f_birthUsed, { date: value.birth.date })} · {t.f_reference}：{reference}
            </p>
            <p className="mt-1 text-[11px] leading-6 text-muted">
              {t[value.birth.basis === 'ascendant' ? 'f_basisAsc' : 'f_basisSun']}
            </p>
            {value.birth.reference_signs.length > 1 && (
              <p className="mt-1 text-[11px] leading-6 text-muted">{t.f_boundary}</p>
            )}
            {state.period === 'today' && (
              <div className="mt-5 border-t border-line pt-4">
                <p className="mb-3 text-[13px] text-ink/85">{t.w_feedback}</p>
                <div className="flex flex-wrap gap-2">
                  <button
                    aria-pressed={state.helpful === true}
                    className={`jy-outline flex-1 !text-xs ${state.helpful === true ? '!border-primary !bg-surface' : ''}`}
                    onClick={() => update({ helpful: true })}
                  >
                    {t.w_helpful}
                  </button>
                  <button
                    className="jy-outline flex-1 !text-xs"
                    onClick={() => {
                      update({ helpful: false });
                      navigate('questions');
                    }}
                  >
                    {t.w_different}
                  </button>
                </div>
              </div>
            )}
          </section>
          <section data-testid="fortune-topics">
            <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
              <h2 className="text-[17px] font-medium">
                {t[`w_${value.period}`]} · {t.j_fourTopics}
              </h2>
              <span className="text-[10px] text-muted">{t.f_readingHint}</span>
            </div>
            <div className="grid grid-cols-2 gap-3">
              {data.topics.map((topic) => {
                const key = topic.id as Topic;
                const reading = value.readings[key];
                const Icon = topicIcons[key];
                return (
                  <article
                    key={key}
                    data-testid={`fortune-${key}`}
                    data-code={reading.code}
                    className={`min-w-0 rounded-[17px] border bg-panel p-[14px] ${focusTopic === key ? 'border-primary' : 'border-line'}`}
                  >
                    <h3 className="mb-3 flex items-center gap-2 text-sm font-medium text-accent">
                      <Icon size={17} className="shrink-0" />
                      {topic.name}
                    </h3>
                    <p className="mb-2 text-[15px] font-medium leading-7">
                      {t[`f_${reading.code}`]}
                    </p>
                    <p className="text-xs leading-7 text-ink/85">
                      {value.narrative.topics[key].text}
                    </p>
                    {value.narrative.source === 'ai' && (
                      <p className="mt-3 border-t border-line pt-2 text-xs leading-7 text-muted">
                        {value.narrative.topics[key].outlook}
                      </p>
                    )}
                  </article>
                );
              })}
            </div>
            <button className="jy-outline mt-3 w-full" onClick={() => ask(focusTopic)}>
              {t.f_chatReading}
              <ArrowRight size={16} />
            </button>
          </section>
          <details data-testid="fortune-basis" className="jy-card !p-0">
            <summary className="cursor-pointer p-4 text-sm text-gold">{t.f_basis}</summary>
            <div className="space-y-3 border-t border-line p-4 text-xs leading-7 text-muted">
              <p>{t.j_backendNote}</p>
              <p>
                {t.f_reference} · {reference}
              </p>
              <p>{t[value.birth.basis === 'ascendant' ? 'f_basisAsc' : 'f_basisSun']}</p>
              <p>
                {t[`w_${state.period}`]} · {value.period_start} — {value.period_end}
              </p>
              <p>
                {fillCopy(t.f_samples, { count: value.sampling.count })} ·{' '}
                {
                  t[
                    value.sampling.method === 'current-minute'
                      ? 'f_samplingToday'
                      : 'f_samplingDays'
                  ]
                }
              </p>
              <p>{t.f_rules}</p>
              <p>{t.f_limits}</p>
              {value.analysis && (
                <details className="border-t border-line pt-2" data-testid="fortune-analysis">
                  <summary className="cursor-pointer">
                    {t.o_factors} · {value.analysis.factors.length}
                  </summary>
                  <p className="mt-2">{t.o_adapter}</p>
                  <p>
                    {value.narrative.source === 'ai' ? t.o_ai : t.o_rules} ·{' '}
                    {value.analysis.upstream} · {value.analysis.adapter_version}
                  </p>
                  <p>{fillCopy(t.o_sampling, { count: value.analysis.sampling.count })}</p>
                  <ul className="mt-3 divide-y divide-line">
                    {value.analysis.factors.map((factor) => (
                      <li key={factor.id} data-factor-id={factor.id} className="py-2">
                        <p>{factorLabel(factor)}</p>
                        <p className="text-[10px]">
                          {factor.start.replace('T', ' ')} — {factor.end.replace('T', ' ')} ·{' '}
                          {t.w_bangkok}
                        </p>
                        {factor.kind === 'sign_relationship' && (
                          <p className="text-[10px]">
                            {t.o_dates} · {factor.observed_dates?.join(', ')}
                          </p>
                        )}
                      </li>
                    ))}
                  </ul>
                </details>
              )}
              <p>
                {t.n_calendarBasis} · {value.calendar.date} · {t.th_lunar}：
                {value.calendar.thai_lunar_date?.label || t.th_noLunar} · {t.c_planet_moon}{' '}
                {value.calendar.moon.longitude.toFixed(2)}°
              </p>
              {data.topics.map((topic) => (
                <details key={topic.id} className="border-t border-line pt-2">
                  <summary className="cursor-pointer">
                    {topic.name} · {value.readings[topic.id as Topic].number} · {t.f_position}
                  </summary>
                  {value.readings[topic.id as Topic].alternatives.map((alt) => (
                    <div key={alt.reference_sign} className="mt-3">
                      <p>{data.signs[alt.reference_sign].name}</p>
                      {alt.evidence.map((row) => (
                        <p key={row.date}>
                          {row.date} · {row.time} · {data.signs[row.sign].name} ·{' '}
                          {row.longitude.toFixed(2)}° · #{row.position}
                        </p>
                      ))}
                    </div>
                  ))}
                </details>
              ))}
              <button className="jy-outline" onClick={() => navigate('profile')}>
                {t.j_editBirth}
              </button>
            </div>
          </details>
          <JourneyCard p={p} />
          {state.period === 'today' && (
            <details className="jy-card !p-0">
              <summary className="cursor-pointer p-4 text-sm text-gold">
                {t.w_daily} · {t.w_rhythm} · {t.w_palette}
              </summary>
              <div className="border-t border-line p-3">
                <WanjaiDaily {...p} embedded />
              </div>
            </details>
          )}
          <details className="pt-2">
            <summary className="mb-4 cursor-pointer text-sm text-muted">{t.j_longTerm}</summary>
            <ReportsTeaser p={p} />
          </details>
          <section className="flex gap-3 rounded-[18px] border border-line bg-surface p-4">
            <Bell size={23} className="mt-1 shrink-0 text-gold" />
            <div>
              <h2 className="text-[15px] leading-7">{t.w_return}</h2>
              <p className="mt-1 text-xs leading-6 text-muted">{t.w_rhythmNote}</p>
              <button
                className="mt-2 text-xs text-accent underline underline-offset-4"
                onClick={() => navigate('daily')}
              >
                {t.w_reminder} →
              </button>
            </div>
          </section>
        </>
      )}
    </div>
  );
}
