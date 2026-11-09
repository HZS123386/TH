import { useEffect, useRef, useState, type CSSProperties } from "react";
import { createPortal } from "react-dom";
import { Sparkles } from "lucide-react";
import { generationCopy, lifeCopy, type GenerationProgress } from "../lib/lifeReport";
import type { Language } from "../lib/reading";
import animationUrl from "../../dist/assets/report-loading-web.mp4?url";
import posterUrl from "../../dist/assets/report-loading-poster.webp?url";

export function ReportGenerationDialog({ language, progress, error, onCancel, onRetry, onComplete, kind = "full", open = true }: {
  language: Language;
  progress: GenerationProgress;
  error: string;
  onCancel: () => void;
  onRetry: () => void;
  onComplete?: () => void;
  kind?: "preview" | "full";
  open?: boolean;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  const video = useRef<HTMLVideoElement>(null);
  const [reduced, setReduced] = useState(() => matchMedia("(prefers-reduced-motion: reduce)").matches);
  const [videoUnavailable, setVideoUnavailable] = useState(false);
  const [videoReady, setVideoReady] = useState(false);
  const [posterReady, setPosterReady] = useState(false);
  const [percent, setPercent] = useState(0);
  const c = generationCopy[language];
  useEffect(() => {
    if (!open) { setPercent(0); return; }
    // Reveal confirmed progress one percentage point at a time; never run beyond the API value.
    const timer = window.setInterval(() => setPercent(current => {
      const next = Math.min(progress.percent, current + 1);
      if (next >= progress.percent) window.clearInterval(timer);
      return next;
    }), 20);
    return () => window.clearInterval(timer);
  }, [open, progress.percent]);
  useEffect(() => {
    if (!open || percent !== 100 || progress.phase !== "ready" || error || !onComplete) return;
    const timer = window.setTimeout(onComplete, 150);
    return () => window.clearTimeout(timer);
  }, [open, percent, progress.phase, error, onComplete]);
  useEffect(() => {
    const query = matchMedia("(prefers-reduced-motion: reduce)");
    const update = () => setReduced(query.matches);
    query.addEventListener("change", update);
    return () => query.removeEventListener("change", update);
  }, []);
  useEffect(() => {
    const element = dialog.current;
    if (!element) return;
    if (open) element.showModal();
    else element.close();
    return () => element.close();
  }, [open]);
  useEffect(() => {
    const element = video.current;
    if (!element) return;
    let active = true;
    if (!open || reduced || videoUnavailable || error || progress.phase === "ready") {
      element.pause();
      if (!open && element.readyState >= HTMLMediaElement.HAVE_METADATA) element.currentTime = 0;
    }
    else void element.play().catch(() => { if (active) setVideoUnavailable(true); });
    return () => { active = false; element.pause(); };
  }, [open, reduced, videoUnavailable, error, progress.phase]);
  const fallback = reduced || videoUnavailable || !videoReady;
  return createPortal(
    <dialog ref={dialog} className="report-generation-dialog" aria-labelledby="report-loading-title" data-testid="report-generation"
      onCancel={event => { event.preventDefault(); onCancel(); }}>
      <div className="report-loading relative py-5 text-center" aria-busy={!error && progress.phase !== "ready"}>
        <div className="report-generation-media relative aspect-[2/1] w-full" aria-hidden="true">
          <video ref={video} src={reduced ? undefined : animationUrl} className="report-generation-video absolute inset-0 h-full" style={{ opacity: fallback ? 0 : 1 }}
            autoPlay={open && !reduced} muted playsInline loop preload={reduced ? "none" : "auto"}
            onLoadedData={() => setVideoReady(true)} onPlaying={() => setVideoReady(true)} onEmptied={() => setVideoReady(false)}
            onError={() => setVideoUnavailable(true)} />
          {fallback && <div className={`report-generation-static absolute inset-0 flex h-full items-center justify-center text-gold${open && !reduced && !error && progress.phase !== "ready" ? " motion-safe:animate-report-visual-breathe" : ""}`} data-testid="generation-visual">
            {!reduced && <img src={posterUrl} className="report-generation-poster absolute inset-0 h-full" alt="" decoding="async" onLoad={() => setPosterReady(true)} />}
            {(reduced || !posterReady) && <Sparkles className="relative" size={72} strokeWidth={.8} />}
          </div>}
        </div>
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
