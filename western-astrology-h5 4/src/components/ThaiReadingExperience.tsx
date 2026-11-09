import { useEffect, useRef, useState, type FormEvent } from "react";
import {
  BookOpen,
  BriefcaseBusiness,
  CalendarDays,
  ArrowUpRight,
  Coins,
  Compass,
  Heart,
  House,
  LoaderCircle,
  History,
} from "lucide-react";
import {
  readingCopy,
  readings,
  ui,
  type Language,
  type Place,
} from "../lib/reading";
import { generateLifeReport, initialPreviewProgress, lifeCopy, lifeReportUrl, lifeSignature, type GenerationProgress, type LifeInput, type LifeReport } from "../lib/lifeReport";
import { ReportGenerationDialog } from "./ReportGenerationDialog";
import { ReportHistory } from "./ReportHistory";
import { BirthplaceFields } from "./BirthplaceFields";
import "../reading.css";

const icons = {
  overview: Compass,
  annual: CalendarDays,
  money: Coins,
  love: Heart,
  work: BriefcaseBusiness,
  family: House,
};

export function ThaiReadingExperience({
  language,
  onLanguageChange,
}: {
  language: Language;
  onLanguageChange: (language: Language) => void;
}) {
  const c = ui[language],
    b = readingCopy(language);
  const life = lifeCopy[language];
  const [date, setDate] = useState("");
  const [time, setTime] = useState("");
  const [unknown, setUnknown] = useState(false);
  const [place, setPlace] = useState<Place | null>(null);
  const year = new Date().getFullYear();
  const [generation, setGeneration] = useState<GenerationProgress | null>(null);
  const [readyReport, setReadyReport] = useState<LifeReport | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [historyOpen, setHistoryOpen] = useState(false);
  const [animationPrepared, setAnimationPrepared] = useState(false);
  const request = useRef<AbortController | null>(null);
  const timezone = place?.timeZone || "Asia/Bangkok";
  const input: LifeInput = {
    profile: {
      display_name: "",
      birth_date: date,
      birth_time: unknown ? null : time || null,
      birthplace: place
        ? `${place.nameEnglish}, ${place.countryCode}`
        : "",
      timezone,
      language,
      country_code: place?.countryCode || "",
      location_id: place?.id || null,
      latitude: null,
      longitude: null,
    },
    year,
  };
  const signature = lifeSignature(input);
  const latest = useRef(signature);
  latest.current = signature;
  let today = "";
  try {
    today = new Intl.DateTimeFormat("en-CA", { timeZone: timezone }).format(
      new Date(),
    );
  } catch {
    /* The form displays a localized validation error. */
  }

  useEffect(() => {
    request.current?.abort();
    setGeneration(null); setReadyReport(null);
    setError("");
    setLoading(false);
    return () => request.current?.abort();
  }, [signature]);

  function fail(message: string, field: string) {
    setError(message);
    document.getElementById(field)?.focus();
  }
  async function generate(event?: FormEvent) {
    event?.preventDefault();
    if (!today) return fail(c.invalidTimezone, "birth-country");
    const parsed = new Date(`${date}T00:00:00Z`);
    if (
      !date ||
      !Number.isFinite(parsed.getTime()) ||
      parsed.toISOString().slice(0, 10) !== date ||
      date < "1901-01-01" ||
      date > today ||
      date > "2099-12-31"
    )
      return fail(c.invalidDate, "birth-date");
    if (!time && !unknown) return fail(c.timeRequired, "birth-time");
    if (!place) return fail(c.invalidPlace, document.querySelector<HTMLInputElement>("#birth-form [data-location-valid='false']:enabled")?.id || "birth-city");
    request.current?.abort();
    const controller = new AbortController();
    request.current = controller;
    const sent = signature;
    setLoading(true);
    setError("");
    setGeneration(current => current || initialPreviewProgress); setReadyReport(null);
    try {
      const value = await generateLifeReport(input, controller.signal, progress => {
        if (!controller.signal.aborted && latest.current === sent) setGeneration(progress);
      });
      if (controller.signal.aborted || latest.current !== sent) return;
      setReadyReport(value);
    } catch (cause) {
      if (!controller.signal.aborted && latest.current === sent)
        setError(cause instanceof Error ? cause.message : c.network);
    } finally {
      if (request.current === controller) {
        request.current = null;
        setLoading(false);
      }
    }
  }
  function cancel() {
    request.current?.abort();
    request.current = null;
    setLoading(false);
    setGeneration(null); setReadyReport(null);
  }
  function openSaved(value: LifeReport) {
    request.current?.abort();
    window.location.assign(lifeReportUrl(value));
  }

  return (
    <div className="thai-reading" data-testid="thai-reading-experience">
      <div className="mb-4 flex justify-end"><button type="button" className="report-secondary" onClick={() => setHistoryOpen(true)}><History size={13} />{life.history}</button></div>
      <form id="birth-form" noValidate onSubmit={generate} aria-busy={loading} onFocusCapture={() => setAnimationPrepared(true)}>
        <label className="field-label" htmlFor="birth-date">
          <span className="field-icon" aria-hidden="true">
            ☉
          </span>
          {c.date}
          <span className="field-hint">{c.ce}</span>
        </label>
        <input
          id="birth-date"
          type="date"
          min="1901-01-01"
          max={today || undefined}
          value={date}
          onChange={(e) => setDate(e.target.value)}
          required
          aria-describedby="form-error"
        />
        <div className="time-label">
          <label className="field-label" htmlFor="birth-time">
            <span className="field-icon" aria-hidden="true">
              ◷
            </span>
            {c.time}
          </label>
          <label className="unknown">
            <input
              id="unknown-time"
              type="checkbox"
              checked={unknown}
              onChange={(e) => setUnknown(e.target.checked)}
            />
            {c.unknown}
          </label>
        </div>
        <input
          id="birth-time"
          type="time"
          value={time}
          disabled={unknown}
          onChange={(e) => setTime(e.target.value)}
          required={!unknown}
          aria-describedby={unknown ? "time-note" : undefined}
        />
        {unknown && (
          <p className="time-note" id="time-note">
            {c.timeNote}
          </p>
        )}
        <BirthplaceFields language={language} value={place} onChange={setPlace} />
        <p className="error" id="form-error" role="alert" hidden={!error}>
          {error}
        </p>
        <button className="primary" type="submit" disabled={loading}>
          {loading ? (
            <LoaderCircle size={19} className="shrink-0 animate-spin" />
          ) : (
            <BookOpen size={19} className="shrink-0" />
          )}
          <span id="main-cta">{loading ? life.generating : life.generate}</span>
        </button>
        <section className="mt-8" aria-label={life.includes} data-testid="life-themes">
          <h3 className="m-0 text-sm font-semibold text-cream">{life.includes}</h3>
          <p className="mb-3 mt-2 text-[10px] leading-6 text-lavender">{life.includesHint}</p>
          <div className="grid grid-cols-2 gap-3" data-testid="life-theme-grid">
            {readings.map(key => {
              const Icon = icons[key];
              return <article key={key} className="theme-option relative flex aspect-square w-full min-h-0 min-w-0 flex-col p-3 max-[360px]:p-2.5">
                <Icon size={32} strokeWidth={1.25} className="mb-3 shrink-0 text-gold max-[360px]:mb-1.5 max-[360px]:h-6 max-[360px]:w-6" aria-hidden="true" />
                <ArrowUpRight size={18} strokeWidth={1.5} className="absolute right-3 top-3 text-gold/65 max-[360px]:right-2.5 max-[360px]:top-2.5 max-[360px]:h-3.5 max-[360px]:w-3.5" aria-hidden="true" />
                <h4 className="m-0 text-sm font-semibold leading-6 text-cream max-[360px]:text-xs max-[360px]:leading-[18px]">{b.readings[key].title}</h4>
                <p className="mb-0 mt-1.5 text-[10px] leading-5 text-lavender max-[360px]:mt-1 max-[360px]:text-[9px] max-[360px]:leading-[14px]">{b.readings[key].subtitle}</p>
              </article>;
            })}
          </div>
        </section>
        <p className="time-note mt-4">{c.formHint}</p>
      </form>

      {(generation || animationPrepared) && <ReportGenerationDialog kind="preview" open={!!generation} language={language} progress={generation || initialPreviewProgress} error={generation ? error : ""} onCancel={cancel} onRetry={() => void generate()}
        onComplete={readyReport ? () => window.location.assign(lifeReportUrl(readyReport)) : undefined} />}
      {historyOpen && <ReportHistory language={language} onClose={() => setHistoryOpen(false)} onOpen={openSaved} />}

    </div>
  );
}
