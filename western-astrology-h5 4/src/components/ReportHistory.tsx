import { useEffect, useId, useRef, useState } from "react";
import { LoaderCircle, X } from "lucide-react";
import { isLifeReport, lifeApi, lifeCopy, type LifeHistory, type LifeReport } from "../lib/lifeReport";
import type { Language } from "../lib/reading";

export function ReportHistory({ language, onClose, onOpen }: { language: Language; onClose: () => void; onOpen: (report: LifeReport) => void }) {
  const dialog = useRef<HTMLDialogElement>(null);
  const title = useId();
  const [items, setItems] = useState<LifeHistory[] | null>(null);
  const [error, setError] = useState("");
  const [opening, setOpening] = useState(false);
  const request = useRef<AbortController | null>(null);
  const c = lifeCopy[language];
  useEffect(() => {
    dialog.current?.showModal();
    const controller = new AbortController();
    lifeApi<{ items: LifeHistory[] }>("/api/life-reports", language, controller.signal)
      .then(value => { if (!controller.signal.aborted) setItems(value.items); })
      .catch(() => { if (!controller.signal.aborted) setError(c.historyError); });
    return () => { controller.abort(); request.current?.abort(); dialog.current?.close(); };
  }, [language, c.historyError]);
  async function open(id: string) {
    request.current?.abort();
    const controller = new AbortController();
    request.current = controller;
    setOpening(true); setError("");
    try {
      const value = await lifeApi<unknown>(`/api/life-reports/${id}`, language, controller.signal);
      if (!isLifeReport(value)) throw new Error(c.historyError);
      if (!controller.signal.aborted) { onOpen(value); onClose(); }
    } catch (cause) { if (!controller.signal.aborted) setError(cause instanceof Error ? cause.message : c.historyError); }
    finally { if (!controller.signal.aborted) setOpening(false); }
  }
  return <dialog ref={dialog} aria-labelledby={title} onCancel={onClose} className="report-history p-5" onClick={event => { if (event.target === event.currentTarget) { const r = event.currentTarget.getBoundingClientRect(); if (event.clientX < r.left || event.clientX > r.right || event.clientY < r.top || event.clientY > r.bottom) onClose(); } }}>
    <div className="flex items-center justify-between"><h2 id={title} className="text-xl font-medium">{c.history}</h2><button className="bg-transparent p-2 text-gold" type="button" onClick={onClose} aria-label={c.close}><X size={20} /></button></div><p className="mt-2 text-xs leading-6 text-lavender">{c.historyHint}</p>
    {!items && !error && <LoaderCircle className="my-6 animate-spin text-gold" size={20} aria-label={c.loading} />}
    {items?.length === 0 && <p className="my-6 text-sm text-lavender">{c.emptyHistory}</p>}
    <div className="mt-5 space-y-3">{items?.map(item => <button key={item.id} disabled={opening} type="button" onClick={() => void open(item.id)} className="w-full rounded-xl border border-solid border-gold/30 bg-plum/70 p-4 text-left"><span className="block text-sm text-cream">{item.input.profile.birth_date} · {item.input.year}</span><span className="mt-1 block text-[10px] leading-5 text-lavender">{item.input.profile.birthplace} · {item.input.profile.language === "zh" ? "中文" : "ไทย"}</span><span className="mt-3 block text-[10px] text-gold">{item.access === "full" ? c.fullVersion : c.previewVersion} · {c.open} ↗</span></button>)}</div>
    {!!error && <p role="alert" className="mt-4 text-xs leading-6 text-[#f2a6af]">{error}</p>}
  </dialog>;
}
