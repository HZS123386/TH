import { useEffect, useRef, useState, type FormEvent } from 'react';
import { ArrowLeft, BookOpen, Download, RefreshCw } from 'lucide-react';
import type { Copy } from '../lib/i18n';
import type { Language, Profile } from '../types';
import { api } from '../lib/api';
import {
  baziCopy,
  baziReportHtml,
  baziReadingTopics,
  type BaziTestInput,
  type BaziTestResult,
  type BaziSource,
  type BaziTopic,
  type BaziReading,
} from '../lib/bazi';
import { BirthDatePicker } from './BirthDatePicker';
import { BirthTimeInput } from './BirthTimeInput';
import { TimezonePicker } from './BirthplacePicker';
import { BaziRoxyDetails } from './BaziRoxyDetails';
import { BaziReadingCards } from './BaziReadingCards';
import { baziElementName, baziPillarName } from '../lib/baziLocale';

export function BaziTestPage({
  profile,
  language,
  t,
  roxyEnabled,
  onBack,
}: {
  profile: Profile | null;
  language: Language;
  t: Copy;
  roxyEnabled: boolean;
  onBack: () => void;
}) {
  const b = baziCopy(language);
  const [birth, setBirth] = useState<Profile>(
    () =>
      profile || {
        display_name: '',
        birth_date: '',
        birth_time: null,
        birthplace: '',
        timezone: 'Asia/Shanghai',
        language,
      },
  );
  const source: BaziSource = roxyEnabled ? 'roxy' : 'github';
  const [reading, setReading] = useState<BaziReading>('overview');
  const topics: BaziTopic[] = roxyEnabled ? baziReadingTopics[reading] : ['chart'];
  const focus = reading === 'annual' ? 'overview' : reading;
  const [clock, setClock] = useState<'local' | 'beijing'>('local');
  const [year, setYear] = useState(new Date().getFullYear());
  const [result, setResult] = useState<BaziTestResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const request = useRef<AbortController | null>(null);
  const input: BaziTestInput = {
    profile: { ...birth, language, birth_time: birth.birth_time || null },
    source,
    topics,
    focus,
    clock,
    gender: null,
    year: topics.includes('annual') ? year : new Date().getFullYear(),
  };
  const signature = JSON.stringify([reading, input]);
  const latest = useRef(signature);
  latest.current = signature;
  useEffect(() => {
    request.current?.abort();
    setResult(null);
    setError('');
    setLoading(false);
    return () => request.current?.abort();
  }, [signature]);
  const today = new Intl.DateTimeFormat('en-CA', {
    timeZone: birth.timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
  const pillarNames = {
    year: b.yearPillar,
    month: b.monthPillar,
    day: b.dayPillar,
    hour: b.hourPillar,
  };
  const displayError = (code: string) => (b.roxyErrors as Record<string, string>)[code] || b.error;

  async function generate(event?: FormEvent) {
    event?.preventDefault();
    if (!birth.birth_date) {
      setError(b.validation);
      return;
    }
    request.current?.abort();
    const controller = new AbortController();
    request.current = controller;
    const sent = signature;
    setLoading(true);
    setError('');
    setResult(null);
    try {
      const value = await api<BaziTestResult>('/api/bazi/test', {
        method: 'POST',
        body: JSON.stringify(input),
        signal: controller.signal,
      });
      if (!controller.signal.aborted && latest.current === sent)
        setResult({
          ...value,
          report: { ...value.report, title: `${b.category} · ${b.readings[reading].title}` },
        });
    } catch (err) {
      if (!controller.signal.aborted && latest.current === sent)
        setError(err instanceof Error ? err.message : b.error);
    } finally {
      if (request.current === controller) setLoading(false);
    }
  }
  function saveReport() {
    if (!result) return;
    const url = URL.createObjectURL(
      new Blob([baziReportHtml(result)], { type: 'text/html;charset=utf-8' }),
    );
    const anchor = document.createElement('a');
    anchor.href = url;
    anchor.download = `Bazi-${result.report_id}.html`;
    anchor.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }

  return (
    <div className="min-w-0 space-y-5 [overflow-wrap:anywhere]" data-testid="bazi-test-page">
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
          <TimezonePicker
            value={birth.timezone}
            t={t}
            onChange={(timezone) => setBirth((v) => ({ ...v, timezone }))}
          />
          <label className="label" htmlFor="bazi-clock">
            {b.clock}
          </label>
          <select
            id="bazi-clock"
            className="field"
            value={clock}
            onChange={(event) => setClock(event.target.value as typeof clock)}
          >
            <option value="local">{b.local}</option>
            <option value="beijing">{b.beijing}</option>
          </select>
          <p className="text-xs leading-7 text-muted">{b.clockNote}</p>
          {!birth.birth_time && roxyEnabled && (
            <p className="text-xs leading-7 text-accent">{b.timeRequired}</p>
          )}
        </section>
        <BaziReadingCards
          value={reading}
          language={language}
          basicOnly={!roxyEnabled}
          onChange={setReading}
        />
        {!roxyEnabled && <p className="text-xs leading-7 text-muted">{b.unconfigured}</p>}
        {topics.includes('annual') && (
          <section className="jy-card space-y-4">
            <div>
              <label className="label" htmlFor="bazi-year">
                {b.year}
              </label>
              <input
                id="bazi-year"
                className="field"
                type="number"
                min={1901}
                max={2100}
                value={year}
                onChange={(event) => setYear(Number(event.target.value))}
                required
              />
            </div>
          </section>
        )}
        {error && (
          <p role="alert" className="jy-card text-sm text-accent">
            {error}
          </p>
        )}
        <button
          className="jy-primary w-full"
          disabled={loading || !birth.birth_date || (roxyEnabled && !birth.birth_time)}
          type="submit"
        >
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
        <div className="space-y-5" data-testid="bazi-results">
          <section className="jy-card">
            <h2 className="text-lg font-medium">{b.results}</h2>
            <p className="mt-2 text-xs leading-7 text-muted">
              {result.input.profile.birth_date} · {result.input.profile.birth_time || t.timeUnknown}{' '}
              · {result.input.profile.timezone}
            </p>
            <p className="text-xs leading-7 text-muted">
              {result.calculation_input.birth_date} · {result.calculation_input.birth_time || '—'} ·{' '}
              {result.calculation_input.timezone}
            </p>
          </section>
          {Object.entries(result.sources).map(([name, value]) => (
            <section key={name} className="jy-card" data-testid={`bazi-source-${name}`}>
              <h3 className="mb-3 text-base font-medium">
                {b.chart} · {value.status === 'ready' ? b.ready : b.unavailable}
              </h3>
              {Object.entries(value.errors || {}).map(([topic, code]) => (
                <p key={topic} role="status" className="my-2 text-xs leading-7 text-accent">
                  {b[topic as BaziTopic]} · {displayError(code)}
                </p>
              ))}
              {value.chart && (
                <>
                  <div className="grid grid-cols-4 gap-2">
                    {(['year', 'month', 'day', 'hour'] as const).map((key) => (
                      <div key={key} className="rounded-xl bg-canvas px-1 py-4 text-center">
                        <p className="text-[10px] text-muted">{pillarNames[key]}</p>
                        <p
                          className={`mt-3 font-display text-accent ${language === 'zh' ? 'text-xl' : 'text-sm leading-6'}`}
                        >
                          {baziPillarName(value.chart!.pillars[key], language)}
                        </p>
                      </div>
                    ))}
                  </div>
                  <h4 className="mb-2 mt-5 text-xs">{b.elements}</h4>
                  <div className="grid grid-cols-5 gap-2">
                    {Object.entries(value.chart.visible_element_counts).map(([key, count]) => (
                      <div
                        key={key}
                        className="rounded-lg border border-line p-2 text-center text-xs"
                      >
                        {baziElementName(key, language)}
                        <b className="mt-2 block text-sm font-medium">{count}</b>
                      </div>
                    ))}
                  </div>
                  <p className="mt-3 text-xs leading-7 text-muted">{b.elementNote}</p>
                </>
              )}
              {Object.entries(value.details || {}).map(([topic, detail]) => (
                <div key={topic} className="mt-4 border-t border-line pt-3">
                  <h4 className="text-sm font-medium">{b[topic as BaziTopic]}</h4>
                  <BaziRoxyDetails
                    operation={topic as BaziTopic}
                    data={detail.data}
                    language={language}
                    translations={result.report.translations}
                  />
                </div>
              ))}
            </section>
          ))}
          <section className="jy-card" data-testid="bazi-report">
            <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
              <h2 className="text-lg font-medium">{b.report}</h2>
              <button className="jy-outline !text-xs" onClick={saveReport}>
                <Download size={14} />
                {b.download}
              </button>
            </div>
            <p className="mb-4 text-xs leading-7 text-muted">{result.report.title}</p>
            {result.report.generation && result.report.generation.state !== 'ready' && (
              <p role="status" className="jy-copy">
                {(b.reportStates as Record<string, string>)[result.report.generation.state] ||
                  b.reportStates.unavailable}
              </p>
            )}
            {result.report.sections
              .filter((section) => !['focus', 'scope'].includes(section.id))
              .map((section) => (
                <article key={section.id} className="border-t border-line py-4">
                  <h3 className="text-base font-medium">{section.title}</h3>
                  {section.paragraphs.map((text, index) => (
                    <p key={index} className="jy-copy my-2">
                      {text}
                    </p>
                  ))}
                </article>
              ))}
          </section>
          {(Object.keys(result.sources.roxy?.errors || {}).length > 0 ||
            ['unavailable', 'pending', 'limited', 'calculation_unavailable'].includes(
              result.report.generation?.state || '',
            )) && (
            <button className="jy-outline w-full" onClick={() => void generate()}>
              {b.retry}
            </button>
          )}
        </div>
      )}
    </div>
  );
}
