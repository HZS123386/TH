import { useEffect, useRef, useState } from "react";
import { ArrowDown, ArrowRight, BookOpen, Check, Download, LoaderCircle, LockKeyhole, Printer, Sparkles } from "lucide-react";
import { ApiError, reportHtml, ui, type Language } from "../lib/reading";
import { initialGenerationProgress, isLifeReport, lifeApi, lifeCopy, lifeReportPollInterval, unlockLifeReport, type Feedback, type GenerationProgress, type LifeReport } from "../lib/lifeReport";
import { reportContent } from "../lib/reportContent";
import { saveReportPdf } from "../lib/reportPdf";
import { EvidenceDetails } from "./EvidenceDetails";
import { PaidReportSections } from "./PaidReportSections";
import { ReportGenerationDialog } from "./ReportGenerationDialog";

function moveTo(id: string) {
  const target = document.getElementById(id);
  if (!target) return;
  target.focus({ preventScroll: true });
  window.scrollTo({ top: window.scrollY + target.getBoundingClientRect().top - 24,
    behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth" });
}

export function LifeReportView({ initial, onRetryPreview, previewBusy = false }: { initial: LifeReport; onRetryPreview: () => void; previewBusy?: boolean }) {
  const [report, setReport] = useState(initial);
  const [error, setError] = useState("");
  const [opening, setOpening] = useState(false);
  const [generation, setGeneration] = useState<GenerationProgress | null>(null);
  const [generationError, setGenerationError] = useState("");
  const [readyReport, setReadyReport] = useState<LifeReport | null>(null);
  const unlockRequest = useRef<AbortController | null>(null);
  const scrollAfterUnlock = useRef(false);
  const [feedback, setFeedback] = useState<Feedback | null>(initial.feedback);
  const [feedbackBusy, setFeedbackBusy] = useState(false);
  const [exportingPdf, setExportingPdf] = useState(false);
  const [pdfStatus, setPdfStatus] = useState("");
  const [pdfError, setPdfError] = useState("");
  const [pdfPosition, setPdfPosition] = useState<"top" | "bottom">("top");
  const [offerSeen, setOfferSeen] = useState(false);
  const offer = useRef<HTMLDivElement>(null);
  const mounted = useRef(true);
  const requests = useRef(new Set<AbortController>());
  const language = report.input.profile.language;
  const c = lifeCopy[language];
  const full = report.access === "full";
  const ready = report.full_state === "ready";
  const fullPercent = ready ? 100 : Math.min(99, report.generation_progress?.percent ?? Math.floor(report.progress.completed / report.progress.total * 100));
  const preview = report.preview;
  const sections = reportContent(report);

  useEffect(() => {
    requests.current.forEach(controller => controller.abort());
    setReport(initial);
    setFeedback(initial.feedback);
    setOpening(false);
    setGeneration(null); setGenerationError(""); setReadyReport(null);
    scrollAfterUnlock.current = false;
    setExportingPdf(false);
    setPdfStatus("");
    setPdfError("");
    setError("");
  }, [initial]);

  useEffect(() => {
    mounted.current = true;
    return () => { mounted.current = false; requests.current.forEach(controller => controller.abort()); };
  }, []);
  useEffect(() => {
    if (scrollAfterUnlock.current && full && ready && !generation) {
      scrollAfterUnlock.current = false;
      moveTo("life-full-report");
    }
  }, [full, ready, generation]);
  useEffect(() => {
    if (!offer.current || full) return;
    const observer = new IntersectionObserver(entries => {
      if (entries.some(entry => entry.isIntersecting)) setOfferSeen(true);
    }, { threshold: 0.1 });
    observer.observe(offer.current);
    return () => observer.disconnect();
  }, [full, !!preview]);
  useEffect(() => {
    if (report.full_state !== "generating" || generation) return;
    const controller = new AbortController();
    let timer: number;
    async function poll() {
      let again = true;
      let delay = lifeReportPollInterval;
      try {
        const value = await lifeApi<unknown>(`/api/life-reports/${report.id}`, language, controller.signal);
        if (controller.signal.aborted || !mounted.current) return;
        if (!isLifeReport(value) || value.id !== report.id) throw new Error(c.historyError);
        setReport(value);
        setError("");
        again = value.full_state === "generating";
      } catch (cause) {
        if (cause instanceof ApiError && cause.status === 429) delay = Math.max(lifeReportPollInterval, cause.retryAfterMs ?? 60000);
        else if (!controller.signal.aborted && mounted.current) setError(cause instanceof Error ? cause.message : c.historyError);
      } finally {
        if (again && !controller.signal.aborted) timer = window.setTimeout(() => void poll(), delay);
      }
    }
    timer = window.setTimeout(() => void poll(), lifeReportPollInterval);
    return () => { clearTimeout(timer); controller.abort(); };
  }, [report.id, report.access, report.full_state, language, c.historyError, !!generation]);

  async function unlock() {
    unlockRequest.current?.abort();
    const controller = new AbortController();
    unlockRequest.current = controller;
    requests.current.add(controller);
    setOpening(true);
    setError("");
    setGeneration(current => current || initialGenerationProgress);
    setGenerationError(""); setReadyReport(null);
    try {
      const value = await unlockLifeReport(report, controller.signal, progress => {
        if (mounted.current && !controller.signal.aborted) setGeneration(progress);
      });
      if (mounted.current && !controller.signal.aborted) {
        setReadyReport(value);
      }
    } catch (cause) { if (!controller.signal.aborted && mounted.current) setGenerationError(cause instanceof Error ? cause.message : c.states.unavailable); }
    finally { requests.current.delete(controller); if (mounted.current && unlockRequest.current === controller) setOpening(false); }
  }
  function cancelGeneration() {
    unlockRequest.current?.abort(); unlockRequest.current = null;
    setGeneration(null); setGenerationError(""); setReadyReport(null); setOpening(false);
    scrollAfterUnlock.current = false;
  }
  function showFullReport() {
    if (!readyReport) return;
    scrollAfterUnlock.current = true;
    setReport(readyReport); setGeneration(null); setReadyReport(null);
  }
  async function sendFeedback(rating: Feedback) {
    const controller = new AbortController();
    requests.current.add(controller);
    setFeedbackBusy(true);
    setError("");
    try {
      await lifeApi(`/api/life-reports/${report.id}/feedback`, language, controller.signal, { rating });
      if (mounted.current && !controller.signal.aborted) setFeedback(rating);
    } catch (cause) { if (!controller.signal.aborted && mounted.current) setError(cause instanceof Error ? cause.message : c.historyError); }
    finally { requests.current.delete(controller); if (mounted.current) setFeedbackBusy(false); }
  }
  function save() {
    const url = URL.createObjectURL(new Blob([reportHtml(report, c)], { type: "text/html;charset=utf-8" }));
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = `Life-Report-${report.id}${full && ready ? "" : "-preview"}.html`;
    anchor.click();
    window.setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  async function exportPdf(position: "top" | "bottom") {
    if (exportingPdf) return;
    const controller = new AbortController();
    requests.current.add(controller);
    setExportingPdf(true);
    setPdfPosition(position);
    setPdfStatus(c.pdfPreparing);
    setPdfError("");
    try {
      const outcome = await saveReportPdf(report, c, controller.signal);
      if (mounted.current && !controller.signal.aborted) setPdfStatus(outcome === "saved" ? c.pdfSaved : outcome === "downloaded" ? c.pdfDownloaded : "");
    } catch {
      if (mounted.current && !controller.signal.aborted) { setPdfError(c.pdfError); setPdfStatus(""); }
    } finally {
      requests.current.delete(controller);
      if (mounted.current && !controller.signal.aborted) setExportingPdf(false);
    }
  }

  return (
    <section className="personal-report life-report -mx-2 mt-7 rounded-2xl border border-solid border-gold/35 bg-night text-cream" data-testid="life-report">
      <header id="life-section-basics" tabIndex={-1} className="life-report-cover rounded-t-2xl border-0 border-b border-solid border-gold/20 px-5 pb-6 pt-7">
        <div className="flex items-center justify-between gap-3 text-[10px] text-gold"><span className="tracking-[0.15em]">ASTRO · AI</span><span>{full ? c.fullVersion : c.preview}</span></div>
        <Sparkles className="mb-3 mt-6 text-gold" size={27} strokeWidth={1.2} aria-hidden="true" />
        <h2 id="life-report-title" tabIndex={-1} className="text-[30px] font-medium leading-tight tracking-wide">{c.title}</h2>
        <p className="mt-3 text-xs leading-6 text-lavender">{c.subtitle}</p>
        <h3 className="mt-6 text-sm font-semibold text-gold">{sections[0].title}</h3>
        <dl className="mb-0 mt-3 grid gap-3 border-0 border-t border-solid border-gold/20 pt-4 text-[10px] leading-5">
          <div><dt className="text-gold">{c.name}</dt><dd className="m-0 mt-1 text-cream">{report.input.profile.display_name || c.defaultName}</dd></div>
          <div><dt className="text-gold">{c.birth}</dt><dd className="m-0 mt-1 text-cream">{report.input.profile.birth_date} · {report.input.profile.birth_time || c.timeUnknown}<br />{report.input.profile.birthplace} · {report.input.profile.timezone}</dd></div>
          <div className="flex flex-wrap gap-x-5 gap-y-2"><div><dt className="text-lavender">{c.number}</dt><dd className="m-0 font-mono text-cream">{report.id.slice(0, 12).toUpperCase()}</dd></div><div><dt className="text-lavender">{c.created}</dt><dd className="m-0 text-cream">{new Intl.DateTimeFormat(language === "zh" ? "zh-CN" : "th-TH", { dateStyle: "medium", calendar: "gregory" }).format(new Date(report.created_at))}</dd></div></div>
          <div><dt className="text-lavender">{c.method}</dt><dd className="m-0 text-cream">{c.methodValue} · {report.input.year}</dd></div>
          <div><dt className="text-lavender">{c.timeRange}</dt><dd className="m-0 text-cream">{report.input.year} · {c.yearReference}</dd></div>
        </dl>
        {!report.input.profile.birth_time && <p className="mt-4 rounded-lg border border-solid border-gold/25 bg-gold/5 p-3 text-[11px] leading-6 text-lavender" data-testid="report-time-note">{ui[language].timeNote}</p>}
      </header>

      {!preview && <div className="p-5"><p role="status" className="text-sm leading-7 text-lavender">{c.previewStates[report.preview_state]}</p><button type="button" className="primary mt-4" disabled={previewBusy} onClick={onRetryPreview}>{c.retryPreview}</button></div>}
      {preview && <>
        <div className="px-5 py-6">
          <p className="text-[10px] tracking-widest text-gold">{c.preview}</p>
          <h3 id="life-section-summary" tabIndex={-1} className="mb-3 mt-2 scroll-mt-6 text-lg font-medium">{sections[1].title}</h3>
          <p className="text-[18px] leading-[1.9] text-cream">{preview.summary.text}</p>
          <EvidenceDetails evidence={preview.summary.evidence} language={language} />
          <h3 id="life-section-traits" tabIndex={-1} className="mb-5 mt-8 scroll-mt-6 text-base font-semibold text-gold">{sections[2].title}</h3>
          <div className="space-y-6" data-testid="life-free-traits">{preview.traits.map((item, index) => <article key={item.key} className="border-0 border-t border-solid border-gold/20 pt-5">
            <div className="flex items-start gap-3"><span className="pt-1 font-serif text-xl text-gold/65">0{index + 1}</span><div className="min-w-0 flex-1"><h4 className="m-0 text-base font-semibold leading-7">{item.title}</h4><p className="mt-3 text-sm leading-[2] text-lavender">{item.text}</p><EvidenceDetails evidence={item.evidence} language={language} /></div></div>
          </article>)}</div>
          <div className="mt-7 border-0 border-t border-solid border-gold/20 pt-5"><p className="text-xs text-cream">{c.feedback}</p><div className="mt-3 flex flex-wrap gap-2">{(["close", "partly", "different"] as const).map((value, index) => <button type="button" key={value} aria-pressed={feedback === value} disabled={feedbackBusy} onClick={() => void sendFeedback(value)} className={`min-h-9 rounded-full border border-solid px-3 py-2 text-[10px] ${feedback === value ? "border-gold bg-gold/15 text-gold" : "border-gold/25 bg-transparent text-lavender"}`}>{c.feedbackOptions[index]}</button>)}</div><p role="status" className="mt-3 text-[10px] leading-5 text-lavender">{feedback ? c.feedbackSaved : c.feedbackHint}</p></div>
          <div className="mt-5 flex flex-wrap gap-3"><button type="button" onClick={save} className="report-secondary"><Download size={13} />{full && ready ? c.save : c.savePreview}</button><button type="button" onClick={() => void exportPdf("top")} disabled={exportingPdf} className="report-secondary" data-testid="life-pdf-button">{exportingPdf ? <LoaderCircle size={13} className="animate-spin" /> : <Printer size={13} />}{exportingPdf ? c.pdfPreparing : c.exportPdf}</button></div>
          {pdfPosition === "top" && <><p role="status" className="mt-3 text-[11px] leading-6 text-gold">{pdfStatus}</p>{pdfError && <p role="alert" className="mt-3 text-xs leading-6 text-[#f2a6af]">{pdfError}</p>}</>}
        </div>

        <div className="border-0 border-t border-solid border-gold/25 px-5 py-6" data-testid="life-catalog">
          <p className="text-[10px] tracking-widest text-gold">{c.chapterCount}</p><h3 className="mb-2 mt-2 text-xl font-medium leading-8">{c.catalog}</h3><p className="text-xs leading-6 text-lavender">{c.catalogHint}</p>
          <div className="mt-4 space-y-2">{sections.map(item => <button key={item.key} type="button" className="life-catalog-card w-full rounded-xl border border-solid border-gold/25 px-3 py-2.5 text-left" onClick={() => moveTo(!item.paid || full && item.ready ? `life-section-${item.key}` : full ? "life-full-report" : "life-unlock-offer")} aria-label={item.title}>
            <div className="flex items-start gap-3"><span className="min-w-0 flex-1"><strong className="block text-sm font-semibold leading-6 text-cream">{item.title}</strong><span className="mt-0.5 block text-[11px] leading-5 text-lavender">{item.description}</span><span className="mt-1.5 flex items-center gap-1 text-[10px] leading-4 text-gold">{!item.paid || full && item.ready ? <Check size={11} /> : full ? <LoaderCircle size={11} /> : <LockKeyhole size={11} />}{!item.paid ? c.freeContent : full ? item.ready ? c.available : c.states.not_started : c.locked}</span></span><ArrowDown size={15} className="mt-1 shrink-0 text-gold" /></div>
          </button>)}</div>
        </div>

        {!full && <div id="life-unlock-offer" ref={offer} tabIndex={-1} className="life-unlock-offer mx-3 mb-5 rounded-2xl border border-solid border-gold/50 p-5 text-center" data-testid="life-unlock-offer">
          <BookOpen className="mx-auto text-gold" size={27} strokeWidth={1.4} /><h3 className="mb-3 mt-4 text-xl font-medium leading-8 text-cream">{c.offerTitle}</h3><p className="text-xs leading-7 text-lavender">{c.offerText}</p><ul className="my-5 grid list-none grid-cols-2 gap-3 p-0 text-left text-[11px] leading-5 text-cream">{c.benefits.map(text => <li key={text} className="flex items-start gap-2"><Check size={13} className="mt-0.5 shrink-0 text-gold" />{text}</li>)}</ul>
          <p className="text-[32px] font-semibold text-gold">¥300 <span className="text-[10px] font-normal text-lavender">CNY</span></p><p className="mt-2 text-[10px] leading-5 text-lavender">{c.once}</p>
          <p role="status" className="mt-3 text-xs leading-6 text-gold" data-testid="life-background-status">{ready ? c.backgroundReady : report.full_state === "generating" ? c.backgroundGenerating : c.backgroundRetry}</p>
          <button className="primary" type="button" disabled={opening} onClick={() => void unlock()} data-testid="life-unlock-button">{opening ? <LoaderCircle size={17} className="animate-spin" /> : <LockKeyhole size={17} />}{opening ? c.unlocking : c.unlock}</button><p className="mt-3 text-[10px] leading-5 text-lavender">{c.direct}</p>
        </div>}

        {full && <div id="life-full-report" tabIndex={-1} className="border-0 border-t border-solid border-gold/30 px-5 py-7" data-testid="life-full-report">
          <p className="flex items-center gap-2 text-xs text-gold"><Check size={15} />{c.full}</p>
          {!ready && <div className="mt-5 rounded-xl border border-solid border-gold/25 bg-plum/50 p-4" role="status"><p className="text-sm font-semibold text-cream">{report.full_state === "generating" ? c.progress : c.states[report.full_state]}</p><p className="mt-2 text-[11px] leading-6 text-lavender">{report.full_state === "generating" ? c.progressHint : c.pausedHint}</p><progress className="mt-4 h-1.5 w-full accent-gold" value={fullPercent} max={100} /><p className="mt-2 text-[10px] text-gold">{fullPercent}%</p>{report.full_state !== "generating" && <button type="button" className="report-secondary mt-4" disabled={opening} onClick={() => void unlock()}>{c.retry}</button>}</div>}
          <PaidReportSections report={report} onNavigate={moveTo} />
          {ready && <div className="mt-7 border-0 border-t border-solid border-gold/25 pt-5"><p role="status" className="mb-4 text-xs text-gold">{c.done}</p><button type="button" className="primary" onClick={save}><Download size={17} />{c.save}</button><button type="button" className="report-secondary mt-3" onClick={() => void exportPdf("bottom")} disabled={exportingPdf}>{exportingPdf ? <LoaderCircle size={14} className="animate-spin" /> : <Printer size={14} />}{exportingPdf ? c.pdfPreparing : c.exportPdf}</button>{pdfPosition === "bottom" && <><p role="status" className="mt-3 text-[11px] leading-6 text-gold">{pdfStatus}</p>{pdfError && <p role="alert" className="mt-3 text-xs leading-6 text-[#f2a6af]">{pdfError}</p>}</>}</div>}
        </div>}
        <details className="mx-5 mb-6 rounded-xl border border-solid border-gold/20 bg-plum/40 p-4 text-[10px] leading-6 text-lavender"><summary className="cursor-pointer text-gold">{c.sourceVersion}</summary><p className="mt-3">{report.method.name} · {report.method.house_system}</p><p className="mt-1 break-all">{report.method.version} / {report.version}</p></details>
      </>}
      {!!error && <div className="mx-5 mb-5"><p role="alert" className="text-xs leading-6 text-[#f2a6af]">{error}</p>{full && <button type="button" className="report-secondary mt-3" disabled={opening} onClick={() => void unlock()}>{c.retry}</button>}</div>}
      {preview && !full && offerSeen && <div className="report-unlock-bar"><button type="button" className="primary" disabled={opening} onClick={() => void unlock()}><LockKeyhole size={17} />{opening ? c.unlocking : c.unlock}<ArrowRight size={16} className="ml-auto shrink-0" /></button></div>}
      {generation && <ReportGenerationDialog language={language} progress={generation} error={generationError} onCancel={cancelGeneration}
        onRetry={() => void unlock()} onComplete={readyReport ? showFullReport : undefined} />}
    </section>
  );
}
