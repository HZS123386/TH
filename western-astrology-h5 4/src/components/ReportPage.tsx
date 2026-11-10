import { useEffect, useRef, useState } from "react";
import { ArrowLeft, LoaderCircle } from "lucide-react";
import { generateLifeReport, generationCopy, initialPreviewProgress, isLifeReport, lifeApi, lifeCopy, lifeLabels, lifeReportUrl, type GenerationProgress, type LifeReport } from "../lib/lifeReport";
import type { Language } from "../lib/reading";
import { LifeReportView } from "./LifeReportView";
import { ReportGenerationDialog } from "./ReportGenerationDialog";
import "../reading.css";

export function ReportPage() {
  const params = new URLSearchParams(location.search);
  const identifier = params.get("id") || "";
  const [language, setLanguage] = useState<Language>(params.get("lang") === "th" ? "th" : "zh");
  const [report, setReport] = useState<LifeReport | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [generation, setGeneration] = useState<GenerationProgress | null>(null);
  const [generationError, setGenerationError] = useState("");
  const [readyReport, setReadyReport] = useState<LifeReport | null>(null);
  const request = useRef<AbortController | null>(null);
  const c = lifeCopy[language], flow = generationCopy[language];
  const landing = new URL("./", document.baseURI);
  landing.searchParams.set("lang", language);
  if (report?.input.career) landing.searchParams.set("topic", "career");
  landing.hash = "birth-section";

  function display(value: LifeReport) {
    setReport(value); setLanguage(value.input.profile.language);
    document.title = `${lifeLabels(value).title} · ASTRO AI`;
  }
  useEffect(() => { document.documentElement.lang = language; }, [language]);
  async function load() {
    request.current?.abort();
    const controller = new AbortController(); request.current = controller;
    setLoading(true); setError("");
    try {
      if (!/^[A-Za-z0-9_-]{8,128}$/.test(identifier)) throw new Error(flow.missing);
      const value = await lifeApi<unknown>(`/api/life-reports/${encodeURIComponent(identifier)}`, language, controller.signal);
      if (!isLifeReport(value) || value.id !== identifier) throw new Error(c.historyError);
      if (!controller.signal.aborted) display(value);
    } catch (cause) {
      if (!controller.signal.aborted) setError(cause instanceof Error && (cause.message === flow.missing || cause.message === flow.storage) ? cause.message : c.historyError);
    } finally { if (!controller.signal.aborted) setLoading(false); }
  }
  useEffect(() => {
    void load();
    return () => request.current?.abort();
  }, [identifier]);

  async function retryPreview() {
    if (!report || loading) return;
    request.current?.abort();
    const controller = new AbortController(); request.current = controller;
    setLoading(true); setError("");
    setGeneration(current => current || initialPreviewProgress); setGenerationError(""); setReadyReport(null);
    try {
      const value = await generateLifeReport(report.input, controller.signal, progress => {
        if (!controller.signal.aborted) setGeneration(progress);
      });
      if (!controller.signal.aborted) setReadyReport(value);
    } catch (cause) {
      if (!controller.signal.aborted) setGenerationError(cause instanceof Error ? cause.message : c.historyError);
    } finally { if (!controller.signal.aborted) setLoading(false); }
  }
  function cancelPreview() {
    request.current?.abort(); setGeneration(null); setReadyReport(null); setLoading(false);
    if (generationError) window.location.assign(landing.href);
  }

  function completePreview() {
    if (!readyReport) return;
    if (readyReport.id !== identifier) {
      window.location.assign(lifeReportUrl(readyReport));
      return;
    }
    display(readyReport); setGeneration(null); setReadyReport(null);
  }
  return <div className="phone" data-testid="report-page">
    <header className="topbar">
      <a className="brand" href={landing.href} aria-label="Astro AI"><span className="brand-star" aria-hidden="true">✧</span>ASTRO<span className="brand-dot">·</span>AI</a>
      <a className="report-secondary" href={landing.href}><ArrowLeft size={13} />{flow.back}</a>
    </header>
    <main className="px-5 pb-8" aria-busy={loading}>
      {loading && <p className="my-12 flex items-center justify-center gap-2 text-xs text-lavender" role="status"><LoaderCircle size={18} className="animate-spin" />{c.loading}</p>}
      {!!error && <div className="my-10 rounded-xl border border-solid border-gold/30 bg-plum/60 p-5"><p role="alert" className="text-sm leading-7 text-cream">{error}</p><button type="button" className="report-secondary mt-4" onClick={() => void load()}>{flow.retry}</button></div>}
      {report && <LifeReportView key={report.id} initial={report} previewBusy={loading} onRetryPreview={() => void retryPreview()} />}
    </main>
    <footer>{report?.input.career
      ? language === "zh" ? "依据泰式排盘与行运规则解读，仅供娱乐与自我探索" : "อ่านจากดวงไทยและหลักดาวจร เพื่อความบันเทิงและสำรวจตัวเอง"
      : language === "zh" ? "解读由 AI 生成，仅供娱乐与自我探索" : "คำอ่านสร้างด้วย AI เพื่อความบันเทิงและสำรวจตัวเอง"}</footer>
    {generation && <ReportGenerationDialog kind="preview" career={!!report?.input.career} language={language} progress={generation} error={generationError} onCancel={cancelPreview}
      onRetry={() => void retryPreview()} onComplete={readyReport ? completePreview : undefined} />}
  </div>;
}
