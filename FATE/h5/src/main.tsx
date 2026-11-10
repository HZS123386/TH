import { useCallback, useEffect, useRef, useState, type FormEvent } from 'react';
import { createRoot } from 'react-dom/client';
import { api, readingKey, recentReadings, recordVisit, updateReadingHistory, type Place, type Reading, type ChartResult, type SavedReading } from './api';
import { BirthplaceFields } from './BirthplaceFields';
import { Chart, ReportCheckout } from './Chart';
import { Interpretation, birthDetailMs, interpretationSteps, type ReadingFlowStage } from './Interpretation';
import { AstrologerPortrait, LandingIcon, QuestionPicker, ThemeCards } from './LandingDetails';
import { Welcome } from './Welcome';
import { copy, message, topics, type Language, type Topic } from './copy';
import './style.css';

const motionPreference = window.matchMedia('(prefers-reduced-motion: reduce)');
const progressSettleMs = 500;

function languageQuery(language: Language) {
  return language === 'zh' ? '?lang=zh' : '';
}

interface PageLanguage {
  language: Language;
  onLanguageChange: (language: Language) => void;
}

function Header({ language, onLanguageChange }: PageLanguage) {
  return <header className="topbar">
    <a href={'/' + languageQuery(language)} aria-label={copy[language].home}><span className="brand-star" aria-hidden="true">✧</span> FATE</a>
    <div className="languages" role="group" aria-label={language === 'th' ? 'ภาษา' : '语言'}>
      <button type="button" lang="th" aria-label="ภาษาไทย" aria-pressed={language === 'th'} onClick={() => onLanguageChange('th')}>TH</button>
      <span aria-hidden="true">/</span>
      <button type="button" lang="zh" aria-pressed={language === 'zh'} onClick={() => onLanguageChange('zh')}>中文</button>
    </div>
  </header>;
}

function Information({ support, language, onLanguageChange }: PageLanguage & { support: boolean }) {
  const [email, setEmail] = useState('');
  const text = copy[language];
  const query = languageQuery(language);
  useEffect(() => {
    api<{ support_email: string }>('/config').then(data => setEmail(data.support_email)).catch(() => {});
  }, []);
  return <div className="site">
    <Header language={language} onLanguageChange={onLanguageChange} />
    <main className="info panel">
      <a href={'/' + query}>{text.back}</a>
      <h1>{support ? text.supportTitle : text.privacy}</h1>
      {support ? <p>{email ? <a href={'mailto:' + email}>{email}</a> : text.noSupport}</p> : <>
        {text.privacyDetails.map(detail => <p key={detail}>{detail}</p>)}
        <p>{text.privacyContact} <a href={'/support' + query}>{text.support}</a></p>
      </>}
      <p className="subtle small">{text.geoNames} <a href="https://www.geonames.org/">GeoNames</a> (CC BY 4.0)</p>
    </main>
  </div>;
}

function App({ language, onLanguageChange }: PageLanguage) {
  const [welcomeOpen, setWelcomeOpen] = useState(true);
  const [topic] = useState<Topic>(() => {
    const requested = new URLSearchParams(location.search).get('topic');
    return topics.find(item => item === requested) ?? 'life';
  });
  const [day, setDay] = useState('');
  const [clock, setClock] = useState('');
  const [unknown, setUnknown] = useState(false);
  const [place, setPlace] = useState<Place | null>(null);
  const [question, setQuestion] = useState('');
  const [preset, setPreset] = useState<number | null>(null);
  const [reportTopic, setReportTopic] = useState(topic);
  const [saved, setSaved] = useState<SavedReading[]>([]);
  const [historyError, setHistoryError] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [generationStage, setGenerationStage] = useState<ReadingFlowStage | null>(null);
  const [checkoutOpen, setCheckoutOpen] = useState(false);
  const [result, setResult] = useState<ChartResult | null>(null);
  const resultNode = useRef<HTMLDivElement>(null);
  const errorNode = useRef<HTMLParagraphElement>(null);
  const heroPortrait = useRef<HTMLImageElement>(null);
  const homeContent = useRef<HTMLElement>(null);
  const consentDialog = useRef<HTMLDialogElement>(null);
  const historyDialog = useRef<HTMLDialogElement>(null);
  const key = useRef('');
  const pending = useRef<{ payload: string; key: string } | null>(null);
  const visit = useRef<Promise<string | undefined> | undefined>(undefined);
  const resolveAnimation = useRef<(() => void) | null>(null);
  const text = copy[language];
  const theme = text.topics[topic];
  const localeQuery = languageQuery(language);
  const selectedQuestion = preset === null ? question.trim() : text.questions[preset][1];
  const finishAnimation = useCallback(() => {
    const resolve = resolveAnimation.current;
    resolveAnimation.current = null;
    resolve?.();
  }, []);

  useEffect(() => { visit.current = recordVisit(); }, []);

  useEffect(() => {
    if (!welcomeOpen && !checkoutOpen) homeContent.current?.focus({ preventScroll: true });
  }, [welcomeOpen, checkoutOpen]);

  useEffect(() => {
    if (error && generationStage === null) errorNode.current?.focus();
  }, [error, generationStage]);

  useEffect(() => {
    if (!result || generationStage !== null || !resultNode.current) return;
    const resultKey = key.current;
    const node = resultNode.current;
    node.scrollIntoView({ behavior: motionPreference.matches ? 'auto' : 'smooth', block: 'start' });
    node.focus({ preventScroll: true });
    const observer = new IntersectionObserver(entries => {
      if (entries.some(entry => entry.isIntersecting)) {
        observer.disconnect();
        void api('/reading/seen', { method: 'POST', key: resultKey }).catch(() => {});
      }
    });
    observer.observe(node);
    return () => observer.disconnect();
  }, [result, generationStage]);

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy) return;
    if (!place) { setError('place_required'); return; }
    setError('');
    consentDialog.current?.showModal();
  }

  async function generateReading() {
    if (!place || busy) return;
    setBusy(true);
    setError('');
    setResult(null);
    setGenerationStage('review');
    const payload = { birth_date: day, birth_time: unknown ? null : clock, place_id: place.id, consent: true };
    const fingerprint = JSON.stringify(payload);
    const token = pending.current?.payload === fingerprint ? pending.current.key : readingKey();
    pending.current = { payload: fingerprint, key: token };
    key.current = token;
    const reviewMs = birthDetailMs * (selectedQuestion ? 4 : 3);
    let reviewTimer = 0;
    const review = new Promise<void>(resolve => {
      reviewTimer = window.setTimeout(() => {
        setGenerationStage('submitting');
        resolve();
      }, reviewMs);
    });
    try {
      const visitId = await visit.current;
      const [initialReport] = await Promise.all([
        api<Reading>('/reading', {
          method: 'POST', key: token,
          body: { ...payload, visit_id: visitId },
          signal: AbortSignal.timeout(10000),
        }),
        review,
      ]);
      let report = initialReport;
      for (let count = 0; count < 75 && (report.status === 'queued' || report.status === 'running'); count++) {
        // Progress reflects observed job stages and stays monotonic during worker retries.
        const stage = report.status;
        setGenerationStage(current => current === 'running' ? current : stage);
        await new Promise(resolve => setTimeout(resolve, 1200));
        report = await api<Reading>('/reading', { key: token, signal: AbortSignal.timeout(8000) });
      }
      if (report.status === 'failed' || report.status === 'ready') pending.current = null;
      if (report.status !== 'ready' || !report.result) throw new Error(report.error || 'still_running');
      const focus = preset === null ? topic : 'career';
      updateReadingHistory(token, { topic: focus, locked: true });
      setResult(report.result);
      for (const step of interpretationSteps) {
        setGenerationStage(step.key);
        await new Promise(resolve => setTimeout(resolve, step.duration));
      }
      setGenerationStage('complete');
      await new Promise(resolve => setTimeout(resolve, motionPreference.matches ? 250 : progressSettleMs));
      const animation = new Promise<void>(resolve => { resolveAnimation.current = resolve; });
      setGenerationStage('loading');
      await animation;
      setResult(null);
      setCheckoutOpen(true);
    } catch (cause) {
      if (cause instanceof Error && cause.message === 'reading_not_found') pending.current = null;
      setError(cause instanceof Error ? cause.message : 'calculation_unavailable');
    } finally {
      window.clearTimeout(reviewTimer);
      finishAnimation();
      setGenerationStage(null);
      setBusy(false);
    }
  }

  function openHistory() {
    setHistoryError('');
    setSaved(recentReadings());
    historyDialog.current?.showModal();
  }

  async function openReport(entry: SavedReading) {
    setBusy(true);
    setHistoryError('');
    try {
      const report = await api<Reading>('/reading', { key: entry.key, signal: AbortSignal.timeout(8000) });
      if (report.status !== 'ready' || !report.result) throw new Error(report.error || 'still_running');
      key.current = entry.key;
      setReportTopic(entry.topic);
      setError('');
      setCheckoutOpen(entry.locked === true);
      setResult(entry.locked ? null : report.result);
      historyDialog.current?.close();
    } catch (cause) {
      const code = cause instanceof Error ? cause.message : 'calculation_unavailable';
      if (code === 'reading_not_found') {
        updateReadingHistory(entry.key);
        setSaved(recentReadings());
      }
      setHistoryError(code);
    } finally {
      setBusy(false);
    }
  }

  async function erase() {
    setBusy(true);
    setError('');
    try {
      await api('/reading', { method: 'DELETE', key: key.current, signal: AbortSignal.timeout(8000) });
      updateReadingHistory(key.current);
      key.current = '';
      setResult(null);
      setCheckoutOpen(false);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'calculation_unavailable');
    } finally {
      setBusy(false);
    }
  }

  return <>
    <div className="site" hidden={generationStage !== null || checkoutOpen} inert={welcomeOpen}>
      <Header language={language} onLanguageChange={onLanguageChange} />
      <main className="home" id="top" ref={homeContent} tabIndex={-1}>
        <div className="hero">
          <AstrologerPortrait className="portrait" imageRef={heroPortrait} />
          <span className="persona"><span aria-hidden="true">✦</span> {text.persona}</span>
        </div>

        <section className="panel form-panel" id="birth-section" aria-labelledby="form-title">
          <h1 id="form-title"><span aria-hidden="true">✦</span> {text.formTitle} <span aria-hidden="true">✦</span></h1>
          <p className="form-caption subtle">{text.formCaption}</p>
          <div className="history-row"><button className="secondary" type="button" disabled={busy} onClick={openHistory}>
            <LandingIcon name="history" />{text.history}
          </button></div>
          <form onSubmit={submit}>
            <fieldset disabled={busy}>
              <label className="field-label" htmlFor="birth-date"><span className="field-icon" aria-hidden="true">☉</span>{text.date}
                <span className="field-hint">{text.calendar}</span></label>
              <input id="birth-date" type="date" value={day} min="1900-01-01" max={new Date().toISOString().slice(0, 10)} required onChange={e => setDay(e.target.value)} />
              <div className="time-label">
                <label className="field-label" htmlFor="birth-time"><span className="field-icon" aria-hidden="true">◷</span>{text.time}</label>
                <label className="check"><input type="checkbox" checked={unknown} onChange={e => setUnknown(e.target.checked)} /> {text.unknown}</label>
              </div>
              <input id="birth-time" type="time" value={clock} disabled={unknown} required={!unknown} onChange={e => setClock(e.target.value)} />
              {unknown && <p className="time-note subtle">{text.unknownNote}</p>}
              <BirthplaceFields language={language} place={place} setPlace={setPlace} />
              <QuestionPicker language={language} question={question} setQuestion={setQuestion} preset={preset} setPreset={setPreset} />
              {error && <p ref={errorNode} tabIndex={-1} className="error" role="alert">{message(error, language)}</p>}
              <button className="primary" type="submit"><LandingIcon name="book" />{theme.action}</button>
            </fieldset>
          </form>
          <ThemeCards language={language} />
          <p className="form-note">{text.formHint}</p>
        </section>
        {result && generationStage === null && !checkoutOpen && <div className="report" tabIndex={-1} ref={resultNode}>
          <Chart key={key.current} result={result} language={language} topic={reportTopic} />
          <button className="erase" type="button" disabled={busy} onClick={erase}>{text.erase}</button>
        </div>}
      </main>
      <footer><p>{text.disclaimer}</p><div><a href={'/privacy' + localeQuery}>{text.privacy}</a><a href={'/support' + localeQuery}>{text.support}</a></div></footer>
    </div>
    <dialog ref={consentDialog} className="landing-dialog" aria-labelledby="consent-title">
      <h2 id="consent-title">{text.consentTitle}</h2>
      <p className="subtle">{text.consent} <a href={'/privacy' + localeQuery} target="_blank" rel="noreferrer">{text.privacy}</a></p>
      <div className="dialog-actions">
        <button className="secondary" type="button" onClick={() => consentDialog.current?.close()}>{text.cancel}</button>
        <button className="dialog-confirm" type="button" onClick={() => {
          consentDialog.current?.close();
          void generateReading();
        }}>{text.consentAction}</button>
      </div>
    </dialog>
    <dialog ref={historyDialog} className="landing-dialog" aria-labelledby="history-title">
      <div className="dialog-heading"><h2 id="history-title">{text.history}</h2>
        <button className="dialog-close" type="button" aria-label={text.close} onClick={() => historyDialog.current?.close()}>×</button>
      </div>
      <p className="subtle">{text.historyHint}</p>
      {saved.length ? saved.map(entry => <div className="history-item" key={entry.key}>
        <span>{text.topics[entry.topic].label}<small>{new Date(entry.date).toLocaleString(language)}</small></span>
        <button className="secondary" type="button" disabled={busy} onClick={() => void openReport(entry)}>
          {entry.locked ? text.checkout.resume : text.openReport}
        </button>
      </div>) : <p className="history-empty">{text.emptyHistory}</p>}
      {historyError && <p className="error" role="alert">{message(historyError, language)}</p>}
    </dialog>
    {welcomeOpen && <Welcome language={language} destination={heroPortrait} motionPreference={motionPreference} onEnter={() => setWelcomeOpen(false)} />}
    {generationStage && place && <Interpretation stage={generationStage} result={result} language={language}
      day={day} time={unknown ? null : clock} place={place} question={selectedQuestion}
      reducedMotion={motionPreference.matches} onAnimationFinished={finishAnimation} />}
    {generationStage === null && checkoutOpen && <ReportCheckout
      language={language} busy={busy} error={error} onErase={() => void erase()}
      onBack={() => { setError(''); setCheckoutOpen(false); }} />}
  </>;
}

function Site() {
  const [language, setLanguage] = useState<Language>(() => new URLSearchParams(location.search).get('lang') === 'zh' ? 'zh' : 'th');
  const support = location.pathname === '/support';
  const information = support || location.pathname === '/privacy';
  const text = copy[language];

  useEffect(() => {
    document.documentElement.lang = language;
    document.title = information ? `${support ? text.supportTitle : text.privacy} · FATE` : text.title;
  }, [language, information, support, text]);

  function changeLanguage(next: Language) {
    const url = new URL(location.href);
    url.searchParams.set('lang', next);
    history.replaceState(history.state, '', url);
    setLanguage(next);
  }

  return information ? <Information support={support} language={language} onLanguageChange={changeLanguage} /> :
    <App language={language} onLanguageChange={changeLanguage} />;
}

createRoot(document.getElementById('root')!).render(<Site />);
