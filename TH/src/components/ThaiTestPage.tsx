import { useCallback, useEffect, useId, useRef, useState, type FormEvent } from 'react';
import { ArrowLeft, BookOpen, Download, LockKeyhole, RefreshCw } from 'lucide-react';
import type { Copy } from '../lib/i18n';
import type { Language, Profile } from '../types';
import { api } from '../lib/api';
import {
  thaiReadingCopy,
  thaiReportHtml,
  thaiPeriodLabel,
  type ThaiReading,
  type ThaiReadingInput,
  type ThaiReadingResult,
} from '../lib/thaiReading';
import { BirthDatePicker } from './BirthDatePicker';
import { BirthTimeInput } from './BirthTimeInput';
import { BirthplacePicker, TimezonePicker } from './BirthplacePicker';
import { ThaiLocationInput } from './ThaiLocationInput';
import { formatBirthTime } from '../lib/birthTime';
import { ThaiReadingCards } from './ThaiReadingCards';
import type { WanjaiBottomAction } from './WanjaiShell';

export function ThaiTestPage({
  profile,
  language,
  t,
  onBack,
  onEditBirth,
  onBottomActionChange,
}: {
  profile: Profile | null;
  language: Language;
  t: Copy;
  onBack: () => void;
  onEditBirth?: () => void;
  onBottomActionChange?: (action: WanjaiBottomAction | undefined) => void;
}) {
  const b = thaiReadingCopy(language);
  const [birth, setBirth] = useState<Profile>(
    () =>
      profile || {
        display_name: '',
        birth_date: '',
        birth_time: null,
        birthplace: '',
        timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || 'Asia/Bangkok',
        language,
      },
  );
  const [reading, setReading] = useState<ThaiReading>(() => {
    const selected = new URLSearchParams(location.search).get('reading');
    return selected && Object.keys(b.readings).includes(selected)
      ? (selected as ThaiReading)
      : 'overview';
  });
  const [year, setYear] = useState(() => {
    const selected = Number(new URLSearchParams(location.search).get('year'));
    return Number.isInteger(selected) && selected >= 1901 && selected <= 2100
      ? selected
      : new Date().getFullYear();
  });
  useEffect(() => {
    if (!['/thai-test', '/bazi-test'].includes(location.pathname)) return;
    const url = new URL(location.href);
    if (reading === 'overview') url.searchParams.delete('reading');
    else url.searchParams.set('reading', reading);
    if (reading === 'annual') url.searchParams.set('year', String(year));
    else url.searchParams.delete('year');
    history.replaceState(history.state, '', url.pathname + url.search + url.hash);
  }, [reading, year]);
  const [result, setResult] = useState<ThaiReadingResult | null>(null);
  const [detailsUnlocked, setDetailsUnlocked] = useState(false);
  const detailsId = useId();
  const detailsHeading = useRef<HTMLHeadingElement>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const request = useRef<AbortController | null>(null);
  useEffect(() => {
    if (profile) setBirth(profile);
  }, [profile]);
  const input: ThaiReadingInput = {
    profile: { ...birth, language, birth_time: birth.birth_time || null },
    reading,
    year: reading === 'annual' ? year : new Date().getFullYear(),
  };
  const signature = JSON.stringify(input);
  const latest = useRef(signature);
  latest.current = signature;
  useEffect(() => {
    request.current?.abort();
    setResult(null);
    setDetailsUnlocked(false);
    setError('');
    setLoading(false);
    return () => request.current?.abort();
  }, [signature]);
  const detailsLocked =
    !!result &&
    result.report.generation.state === 'ready' &&
    result.report.sections.some(
      (section) => section.id !== 'interpretation' && section.items.length > 0,
    ) &&
    !detailsUnlocked;
  const unlockDetails = useCallback(() => setDetailsUnlocked(true), []);
  useEffect(() => {
    onBottomActionChange?.(
      detailsLocked
        ? { label: b.unlock, kind: 'unlock', controls: detailsId, onClick: unlockDetails }
        : undefined,
    );
    return () => onBottomActionChange?.(undefined);
  }, [detailsLocked, b.unlock, detailsId, onBottomActionChange, unlockDetails]);
  useEffect(() => {
    if (detailsUnlocked) {
      detailsHeading.current?.focus({ preventScroll: true });
      detailsHeading.current?.scrollIntoView?.({ block: 'start', behavior: 'smooth' });
    }
  }, [detailsUnlocked]);
  const today = new Intl.DateTimeFormat('en-CA', {
    timeZone: birth.timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
  const coordinatesReady = birth.latitude != null && birth.longitude != null;
  const partialCoordinates = (birth.latitude != null) !== (birth.longitude != null);
  const complete =
    !!birth.birth_date &&
    !!birth.birth_time &&
    !partialCoordinates &&
    (!!birth.location_id || coordinatesReady || !!birth.birthplace.trim());

  async function generate(event?: FormEvent) {
    event?.preventDefault();
    if (!complete) {
      setError(b.required);
      return;
    }
    request.current?.abort();
    const controller = new AbortController();
    request.current = controller;
    const sent = signature;
    setLoading(true);
    setError('');
    setResult(null);
    setDetailsUnlocked(false);
    try {
      const value = await api<ThaiReadingResult>('/api/thai-reading', {
        method: 'POST',
        body: JSON.stringify(input),
        signal: controller.signal,
      });
      if (!controller.signal.aborted && latest.current === sent) setResult(value);
    } catch (cause) {
      if (!controller.signal.aborted && latest.current === sent)
        setError(cause instanceof Error ? cause.message : b.error);
    } finally {
      if (request.current === controller) setLoading(false);
    }
  }
  function saveReport() {
    if (!result) return;
    const url = URL.createObjectURL(
      new Blob([thaiReportHtml(result, detailsUnlocked)], { type: 'text/html;charset=utf-8' }),
    );
    const anchor = document.createElement('a');
    anchor.href = url;
    anchor.download = `Thai-Astrology-${result.report_id}.html`;
    anchor.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }

  function renderItems(section: ThaiReadingResult['report']['sections'][number]) {
    return (
      <div className="space-y-6">
        {section.items.map((item, index) => (
          <article
            key={index}
            className={
              section.id === 'interpretation' ? '' : 'rounded-xl border border-line bg-panel p-4'
            }
          >
            {item.period && (
              <p className="mb-2 text-xs font-medium text-gold">
                {thaiPeriodLabel(item.period, language)}
              </p>
            )}
            <h4 className="flex items-start gap-2 text-sm font-semibold leading-6 text-ink/85">
              {section.id === 'advice' && (
                <span
                  className="inline-flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-surface text-xs text-gold"
                  aria-hidden="true"
                >
                  {index + 1}
                </span>
              )}
              {item.title}
            </h4>
            <p className="mt-2 text-sm leading-7 text-ink/85">{item.text}</p>
            {item.signals && (
              <div className="mt-4">
                <h5 className="text-xs font-medium text-gold">{b.signals}</h5>
                <ul className="mt-2 list-disc space-y-2 pl-4 text-sm leading-7 text-ink/85">
                  {item.signals.map((signal, i) => (
                    <li key={i}>{signal}</li>
                  ))}
                </ul>
              </div>
            )}
            {item.response && (
              <div className="mt-4">
                <h5 className="text-xs font-medium text-gold">{b.response}</h5>
                <p className="mt-2 text-sm leading-7 text-ink/85">{item.response}</p>
              </div>
            )}
            {item.steps && (
              <ol className="mt-4 space-y-3">
                {item.steps.map((step, i) => (
                  <li key={i} className="flex items-start gap-2.5 text-sm leading-7 text-ink/85">
                    <span
                      className="mt-0.5 flex h-6 w-6 shrink-0 items-center justify-center rounded-full border border-line text-[11px] text-gold"
                      aria-hidden="true"
                    >
                      {i + 1}
                    </span>
                    <span>{step}</span>
                  </li>
                ))}
              </ol>
            )}
            {item.example && (
              <div className="mt-4 rounded-lg border border-line bg-panel p-3.5">
                <h5 className="text-xs font-medium text-gold">{b.example}</h5>
                <p className="mt-2 text-sm leading-7 text-ink/85">{item.example}</p>
              </div>
            )}
            {item.pitfall && (
              <div className="mt-4 border-t border-line pt-4">
                <h5 className="text-xs font-medium text-gold">{b.pitfall}</h5>
                <p className="mt-2 text-sm leading-7 text-ink/85">{item.pitfall}</p>
              </div>
            )}
            {item.check && (
              <div className="mt-4">
                <h5 className="text-xs font-medium text-gold">{b.check}</h5>
                <p className="mt-2 text-sm leading-7 text-ink/85">{item.check}</p>
              </div>
            )}
          </article>
        ))}
      </div>
    );
  }

  return (
    <div className="min-w-0 space-y-5 [overflow-wrap:anywhere]" data-testid="thai-test-page">
      <button className="jy-outline" onClick={onBack}>
        <ArrowLeft size={16} />
        {t.back}
      </button>
      <header>
        <p className="jy-kicker">{b.category}</p>
        <h1 className="jy-title mt-2">{b.title}</h1>
        <p className="jy-copy mt-3">{b.intro}</p>
      </header>
      <form className="space-y-5" onSubmit={(event) => void generate(event)}>
        {profile && onEditBirth ? (
          <section className="jy-card space-y-3" data-testid="thai-birth-summary">
            <h2 className="text-lg font-medium">{b.birth}</h2>
            <p className="text-sm">{profile.display_name || t.brandName}</p>
            <p className="text-xs leading-6 text-muted">
              {profile.birth_date} · {formatBirthTime(profile.birth_time, t)}
              <br />
              {profile.birthplace || t.birthplace}
            </p>
            <p className="text-xs leading-6 text-muted">{t.ux_birthReuse}</p>
            <button type="button" className="jy-outline !text-xs" onClick={onEditBirth}>
              {t.j_editBirth}
            </button>
            {!complete && <p className="text-xs leading-7 text-gold">{b.required}</p>}
          </section>
        ) : (
          <section className="jy-card space-y-5">
            <h2 className="text-lg font-medium">{b.birth}</h2>
            <BirthDatePicker
              value={birth.birth_date}
              maximum={today}
              t={t}
              onChange={(birth_date) => setBirth((v) => ({ ...v, birth_date }))}
            />
            <BirthTimeInput
              value={birth.birth_time}
              t={t}
              onChange={(birth_time) => setBirth((v) => ({ ...v, birth_time }))}
            />
            <BirthplacePicker
              value={birth.birthplace}
              locationId={birth.location_id}
              countryCode={birth.country_code}
              timezone={birth.timezone}
              language={language}
              t={t}
              onChange={(birthplace, timezone, location) =>
                setBirth((v) => ({
                  ...v,
                  birthplace,
                  timezone,
                  location_id: location?.id || null,
                  country_code: location?.countryCode || null,
                  latitude: null,
                  longitude: null,
                }))
              }
            />
            <details className="text-xs text-muted">
              <summary className="cursor-pointer py-2">{t.ux_advancedBirth}</summary>
              <div className="mt-3 space-y-4">
                <TimezonePicker
                  value={birth.timezone}
                  t={t}
                  onChange={(timezone) => setBirth((v) => ({ ...v, timezone }))}
                />
                <ThaiLocationInput
                  profile={birth}
                  t={t}
                  onChange={(patch) => setBirth((v) => ({ ...v, ...patch }))}
                />
              </div>
            </details>
            {!complete && <p className="text-xs leading-7 text-muted">{b.required}</p>}
          </section>
        )}
        <ThaiReadingCards value={reading} language={language} onChange={setReading} />
        {reading === 'annual' && (
          <section className="jy-card space-y-3">
            <label className="label" htmlFor="thai-year">
              {b.year}
            </label>
            <input
              id="thai-year"
              className="field"
              type="number"
              min={1901}
              max={2100}
              value={year}
              onChange={(event) => setYear(Number(event.target.value))}
              required
            />
            <p className="text-xs leading-7 text-muted">{b.yearNote}</p>
          </section>
        )}
        {error && (
          <p role="alert" className="jy-card text-sm text-accent">
            {error}
          </p>
        )}
        <button className="jy-primary w-full" disabled={loading || !complete} type="submit">
          {loading ? <RefreshCw className="animate-spin" size={16} /> : <BookOpen size={16} />}
          {loading ? b.loading : b.generate}
        </button>
        {loading && (
          <div role="status" className="jy-card">
            <p className="jy-copy">{b.loading}</p>
            <button
              className="jy-outline my-3"
              type="button"
              onClick={() => {
                request.current?.abort();
                setLoading(false);
              }}
            >
              {b.cancel}
            </button>
            <p className="text-xs leading-6 text-muted">{b.cancelNote}</p>
          </div>
        )}
      </form>
      {result && (
        <div className="space-y-5" data-testid="thai-results">
          <section className="jy-card" data-testid="thai-result-input">
            <p className="text-xs text-muted">{b.results}</p>
            <p className="mt-2 text-xs leading-7 text-muted">
              {result.input.profile.birth_date} · {result.input.profile.birth_time} ·{' '}
              {result.input.profile.birthplace}
            </p>
          </section>
          <section className="jy-card" data-testid="thai-report">
            <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
              <h2 className="text-lg font-medium">{b.report}</h2>
              <button className="jy-outline !text-xs" type="button" onClick={saveReport}>
                <Download size={14} />
                {detailsLocked ? b.downloadPreview : b.download}
              </button>
            </div>
            <p className="mb-4 text-xs leading-7 text-muted">
              {result.report.title}
              {result.input.reading === 'annual' ? ` · ${result.input.year}` : ''}
            </p>
            {result.report.summary && (
              <div
                className="mb-7 rounded-2xl border border-gold/35 bg-gold/10 p-5"
                data-testid="thai-report-summary"
              >
                <h3 className="text-xs font-medium text-gold">{b.summary}</h3>
                <p className="mt-3 text-lg font-medium leading-8 text-ink/85">
                  {result.report.summary}
                </p>
              </div>
            )}
            {result.report.generation.state !== 'ready' && (
              <p role="status" className="jy-copy">
                {b.states[result.report.generation.state]}
              </p>
            )}
            {result.report.sections
              .filter((section) => section.id === 'interpretation')
              .map((section) => (
                <section
                  key={section.id}
                  className="border-t border-line py-6"
                  data-report-section={section.id}
                >
                  <h3 className="mb-5 text-base font-semibold">{section.title}</h3>
                  {renderItems(section)}
                </section>
              ))}
            {result.report.sections.some((section) => section.id !== 'interpretation') && (
              <section className="border-t border-line py-6">
                <h3
                  ref={detailsHeading}
                  tabIndex={-1}
                  className="mb-5 scroll-mt-20 text-base font-semibold outline-none"
                >
                  {b.sections.opportunities}
                </h3>
                <div
                  id={detailsId}
                  className={`relative ${detailsLocked ? 'max-h-[420px] overflow-hidden' : ''}`}
                >
                  <div
                    className={`space-y-8 ${detailsLocked ? 'pointer-events-none select-none blur-[6px] opacity-50' : ''}`}
                    aria-hidden={detailsLocked ? true : undefined}
                    {...(detailsLocked ? { inert: '' } : {})}
                    data-testid="thai-locked-content"
                    data-locked={detailsLocked}
                  >
                    {result.report.sections
                      .filter((section) => section.id !== 'interpretation')
                      .map((section) => (
                        <section
                          key={section.id}
                          data-report-section={section.id}
                          className={section.id === 'advice' ? 'border-t border-line pt-6' : ''}
                        >
                          {section.id !== 'opportunities' && (
                            <h3 className="mb-5 text-base font-semibold">{section.title}</h3>
                          )}
                          {renderItems(section)}
                        </section>
                      ))}
                  </div>
                  {detailsLocked && (
                    <div
                      className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center gap-4 px-5 text-center"
                      role="img"
                      aria-label={b.lockedHint}
                      data-testid="thai-lock-badge"
                    >
                      <span className="inline-flex h-16 w-16 items-center justify-center rounded-full border border-line bg-panel/95 text-gold shadow-lg">
                        <LockKeyhole size={30} strokeWidth={1.5} aria-hidden="true" />
                      </span>
                      <span className="rounded-full bg-panel/95 px-4 py-2 text-xs leading-6 text-gold shadow-sm">
                        {b.lockedHint}
                      </span>
                    </div>
                  )}
                </div>
              </section>
            )}
          </section>
          {result.report.generation.state !== 'ready' && (
            <button className="jy-outline w-full" onClick={() => void generate()}>
              {b.retry}
            </button>
          )}
        </div>
      )}
    </div>
  );
}
