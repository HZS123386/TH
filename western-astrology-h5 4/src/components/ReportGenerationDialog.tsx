import { useEffect, useRef, useState, type CSSProperties } from "react";
import { createPortal } from "react-dom";
import { Sparkles } from "lucide-react";
import { careerCopy, generationCopy, lifeCopy, type GenerationProgress } from "../lib/lifeReport";
import type { Language } from "../lib/reading";
import animationUrl from "../../dist/assets/report-loading.mp4?url";

export function ReportGenerationDialog({ language, progress, error, onCancel, onRetry, onComplete, kind = "full", career = false }: {
  language: Language;
  progress: GenerationProgress;
  error: string;
  onCancel: () => void;
  onRetry: () => void;
  onComplete?: () => void;
  kind?: "preview" | "full";
  career?: boolean;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  const video = useRef<HTMLVideoElement>(null);
  const ambient = useRef<HTMLCanvasElement>(null);
  const [reduced, setReduced] = useState(() => matchMedia("(prefers-reduced-motion: reduce)").matches);
  const [videoUnavailable, setVideoUnavailable] = useState(false);
  const [percent, setPercent] = useState(0);
  const c = generationCopy[language];
  const decision = careerCopy[language];
  const careerSections: Partial<Record<keyof typeof c.sections, string>> = { preview_summary: decision.takeaway, preview_strength: decision.benefits[0], preview_decisions: decision.benefits[1],
    preview_relationships: decision.benefits[3], work: decision.shortTitle };
  const description = career && progress.phase === "preview" ? decision.previewHint : career && progress.phase === "full" ? decision.fullHint : c[progress.phase];
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
    // A ready report still needs the animation while the visible progress reaches 100.
    if (reduced || videoUnavailable || error) element.pause();
    else void element.play().catch(() => { if (active) setVideoUnavailable(true); });
    return () => { active = false; element.pause(); };
  }, [reduced, videoUnavailable, error]);
  const fallback = reduced || videoUnavailable;
  useEffect(() => {
    const source = video.current;
    const target = ambient.current;
    const context = target?.getContext("2d");
    if (!source || !target || !context) return;

    // Reuse the playing video's frames for the blurred backdrop.
    const draw = () => {
      if (source.readyState >= HTMLMediaElement.HAVE_CURRENT_DATA) {
        context.drawImage(source, 0, 0, target.width, target.height);
      }
    };
    draw();
    if (!source.requestVideoFrameCallback) {
      source.addEventListener("timeupdate", draw);
      return () => source.removeEventListener("timeupdate", draw);
    }
    let frame = source.requestVideoFrameCallback(function paint() {
      draw();
      frame = source.requestVideoFrameCallback(paint);
    });
    return () => source.cancelVideoFrameCallback(frame);
  }, [fallback]);

  return createPortal(
    <dialog ref={dialog} className="report-generation-dialog" aria-labelledby="report-loading-title" data-testid="report-generation"
      onCancel={event => { event.preventDefault(); onCancel(); }}>
      <div className="report-generation-art" aria-hidden="true">
        {!fallback && <canvas ref={ambient} className="report-generation-ambient" width={96} height={48} />}
        <div className="report-generation-foreground">
          <video ref={video} src={animationUrl} className={fallback ? "hidden" : "report-generation-video"}
            autoPlay={!reduced} muted playsInline loop preload="auto" onError={() => setVideoUnavailable(true)} />
          {fallback && <div className="report-generation-static text-gold"><Sparkles size={72} strokeWidth={.8} /></div>}
        </div>
      </div>
      <div className="report-loading relative py-5 text-center" aria-busy={!error && progress.phase !== "ready"}>
        <h2 id="report-loading-title" className="m-0 px-4 text-base font-medium leading-7 text-cream">{kind === "preview" ? error ? c.previewFailed : c.previewTitle : error ? c.failed : career ? decision.shortTitle : c.title}</h2>
        <div className="report-progress" style={{ "--report-progress-value": `${percent}%` } as CSSProperties}>
          <span className="report-progress-value" aria-hidden="true">{percent}%</span>
          <div className="report-progress-track" role="progressbar" aria-labelledby="report-loading-title" aria-valuemin={0} aria-valuemax={100} aria-valuenow={percent}>
            <span className="report-progress-fill" aria-hidden="true" />
          </div>
        </div>
        <p className="mb-0 mt-4 px-5 text-xs leading-6 text-lavender" role="status">{error || description}</p>
        {progress.sections && <div className="mx-auto mt-3 grid max-w-xs gap-1.5 px-5 text-[10px] leading-5 text-lavender" data-testid="generation-sections">
          {progress.sections.map(section => <div key={section.key} className="flex justify-between gap-4"><span>{(career && careerSections[section.key]) || c.sections[section.key]}</span><span className="tabular-nums text-gold">{Math.floor(section.percent)}%</span></div>)}
        </div>}
        <div className="mt-4 flex justify-center gap-3 px-5">
          {error && <button type="button" className="report-secondary" onClick={onRetry}>{lifeCopy[language].retry}</button>}
          <button type="button" className="report-secondary" onClick={onCancel}>{error ? kind === "preview" ? c.back : c.returnReport : c.cancel}</button>
        </div>
      </div>
    </dialog>, document.body,
  );
}
