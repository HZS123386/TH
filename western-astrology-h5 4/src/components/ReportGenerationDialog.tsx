import { useEffect, useRef, useState, type CSSProperties } from "react";
import { createPortal } from "react-dom";
import { Sparkles } from "lucide-react";
import { generationCopy, lifeCopy, type GenerationProgress } from "../lib/lifeReport";
import type { Language } from "../lib/reading";
import animationUrl from "../../dist/assets/report-loading.mp4?url";

export function ReportGenerationDialog({ language, progress, error, onCancel, onRetry, onComplete, kind = "full" }: {
  language: Language;
  progress: GenerationProgress;
  error: string;
  onCancel: () => void;
  onRetry: () => void;
  onComplete?: () => void;
  kind?: "preview" | "full";
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  const video = useRef<HTMLVideoElement>(null);
  const [reduced, setReduced] = useState(() => matchMedia("(prefers-reduced-motion: reduce)").matches);
  const [videoUnavailable, setVideoUnavailable] = useState(false);
  const [percent, setPercent] = useState(0);
  const c = generationCopy[language];
  useEffect(() => {
    // Reveal confirmed progress one percentage point at a time; never run beyond the API value.
    const timer = window.setInterval(() => setPercent(current => {
      const next = Math.min(progress.percent, current + 1);
      if (next >= progress.percent) window.clearInterval(timer);
      return next;
    }), 20);
    return () => window.clearInterval(timer);
  }, [progress.percent]);
  useEffect(() => {
    if (percent !== 100 || progress.phase !== "ready" || error || !onComplete) return;
    const timer = window.setTimeout(onComplete, 150);
    return () => window.clearTimeout(timer);
  }, [percent, progress.phase, error, onComplete]);
  useEffect(() => {
    const query = matchMedia("(prefers-reduced-motion: reduce)");
    const update = () => setReduced(query.matches);
    query.addEventListener("change", update);
    const element = dialog.current;
    element?.showModal();
    return () => { query.removeEventListener("change", update); element?.close(); };
  }, []);
  useEffect(() => {
    const element = video.current;
    if (!element) return;
    let active = true;
    if (reduced || videoUnavailable || error || progress.phase === "ready") element.pause();
    else void element.play().catch(() => { if (active) setVideoUnavailable(true); });
    return () => { active = false; element.pause(); };
  }, [reduced, videoUnavailable, error, progress.phase]);
  const fallback = reduced || videoUnavailable;
  return createPortal(
    <dialog ref={dialog} className="report-generation-dialog" aria-labelledby="report-loading-title" data-testid="report-generation"
      onCancel={event => { event.preventDefault(); onCancel(); }}>
      <div className="report-loading relative py-5 text-center" aria-busy={!error && progress.phase !== "ready"}>
        <video ref={video} src={animationUrl} className={fallback ? "hidden" : "report-generation-video"}
          autoPlay={!reduced} muted playsInline loop preload="auto" aria-hidden="true" onError={() => setVideoUnavailable(true)} />
        {fallback && <div className="report-generation-static flex items-center justify-center text-gold" aria-hidden="true"><Sparkles size={72} strokeWidth={.8} /></div>}
        <h2 id="report-loading-title" className="m-0 px-4 text-base font-medium leading-7 text-cream">{kind === "preview" ? error ? c.previewFailed : c.previewTitle : error ? c.failed : c.title}</h2>
        <div className="report-progress" style={{ "--report-progress-value": `${percent}%` } as CSSProperties}>
          <span className="report-progress-value" aria-hidden="true">{percent}%</span>
          <div className="report-progress-track" role="progressbar" aria-labelledby="report-loading-title" aria-valuemin={0} aria-valuemax={100} aria-valuenow={percent}>
            <span className="report-progress-fill" aria-hidden="true" />
          </div>
        </div>
        <p className="mb-0 mt-4 px-5 text-xs leading-6 text-lavender" role="status">{error || c[progress.phase]}</p>
        {progress.sections && <div className="mx-auto mt-3 grid max-w-xs gap-1.5 px-5 text-[10px] leading-5 text-lavender" data-testid="generation-sections">
          {progress.sections.map(section => <div key={section.key} className="flex justify-between gap-4"><span>{c.sections[section.key]}</span><span className="tabular-nums text-gold">{Math.floor(section.percent)}%</span></div>)}
        </div>}
        <div className="mt-4 flex justify-center gap-3 px-5">
          {error && <button type="button" className="report-secondary" onClick={onRetry}>{lifeCopy[language].retry}</button>}
          <button type="button" className="report-secondary" onClick={onCancel}>{error ? kind === "preview" ? c.back : c.returnReport : c.cancel}</button>
        </div>
      </div>
    </dialog>, document.body,
  );
}
