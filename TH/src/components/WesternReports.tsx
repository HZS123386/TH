import { useEffect, useState } from 'react';
import {
  ArrowLeft,
  ArrowRight,
  BookOpen,
  Check,
  Crown,
  LockKeyhole,
  RefreshCw,
  ShieldCheck,
  Trash2,
} from 'lucide-react';
import type { Copy } from '../lib/i18n';
import type { Language } from '../types';
import {
  readWesternExampleSaved,
  removeWesternExample,
  saveWesternExample,
  westernCopy,
  type WesternCopy,
  type WesternReport,
} from '../lib/western';
import { PickerDialog } from './PickerDialog';

export function WesternPurchaseDialog({
  language,
  t,
  example,
  onCancel,
  onPreview,
}: {
  language: Language;
  t: Copy;
  example: boolean;
  onCancel: () => void;
  onPreview: () => void;
}) {
  const a = westernCopy(language);
  const [restore, setRestore] = useState(false);
  return (
    <PickerDialog title={a.offerTitle} t={t} hideConfirm onCancel={onCancel}>
      <div className="mb-5 flex items-center gap-4 rounded-2xl border border-gold/25 bg-gold/5 p-4">
        <span className="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-gold/10 text-gold">
          <Crown size={25} strokeWidth={1.3} />
        </span>
        <div>
          <p className="text-sm font-medium">FATE · {a.fullReport}</p>
          <p className="mt-1 text-xs leading-6 text-muted">{a.offerText}</p>
        </div>
      </div>
      <ul className="space-y-4 py-2">
        {[a.offerFeature1, a.offerFeature2, a.offerFeature3].map((text) => (
          <li key={text} className="flex items-start gap-3 text-xs leading-6">
            <Check size={16} className="mt-1 shrink-0 text-gold" />
            {text}
          </li>
        ))}
      </ul>
      <p className="mb-3 mt-5 text-center text-xs text-muted">{a.pricePending}</p>
      <button disabled className="jy-primary w-full">
        <LockKeyhole size={16} />
        {a.appleBuy}
      </button>
      <p className="mt-3 flex gap-2 text-[11px] leading-6 text-muted">
        <ShieldCheck size={15} className="mt-1 shrink-0 text-gold/60" />
        {a.purchasePreview}
      </p>
      <button
        onClick={() => setRestore(true)}
        className="mt-3 min-h-11 w-full text-xs text-gold underline decoration-gold/30 underline-offset-4"
      >
        {a.restore}
      </button>
      {restore && (
        <p role="status" className="rounded-xl bg-canvas p-3 text-xs leading-6 text-muted">
          {a.restoreNote}
        </p>
      )}
      {example && (
        <div className="mt-4 border-t border-line pt-4">
          <button onClick={onPreview} className="jy-outline w-full">
            {a.previewFull}
            <ArrowRight size={15} />
          </button>
          <p className="mt-2 text-[10px] leading-5 text-muted">{a.previewFullNote}</p>
        </div>
      )}
    </PickerDialog>
  );
}

function ExampleExtra({ a }: { a: WesternCopy }) {
  return (
    <>
      <div className="space-y-6">
        {[1, 2].map((i) => (
          <article key={i}>
            <h3 className="mb-2 text-[15px] font-medium">
              {a[`sampleWatch${i}Title` as keyof WesternCopy]}
            </h3>
            <p className="text-[13px] leading-[2] text-ink/75">
              {a[`sampleWatch${i}Text` as keyof WesternCopy]}
            </p>
          </article>
        ))}
      </div>
      <h2 className="mb-5 mt-8 border-t border-line pt-7 text-[18px] font-medium">{a.advice}</h2>
      <div className="space-y-4">
        {[1, 2, 3].map((i) => (
          <article key={i} className="rounded-2xl border border-line/80 bg-canvas/55 p-4">
            <h3 className="mb-3 flex items-start gap-2 text-[14px] font-medium">
              <span className="grid h-5 w-5 shrink-0 place-items-center rounded-full bg-gold/15 text-[10px] text-gold">
                {i}
              </span>
              {a[`sampleAdvice${i}Title` as keyof WesternCopy]}
            </h3>
            <p className="text-[13px] leading-[2] text-ink/75">
              {a[`sampleAdvice${i}Text` as keyof WesternCopy]}
            </p>
          </article>
        ))}
      </div>
      {[
        { title: a.chapterLove, text: a.sampleLoveText, action: a.sampleLoveAction },
        { title: a.chapterWork, text: a.sampleWorkText, action: a.sampleWorkAction },
        { title: a.chapterMoney, text: a.sampleMoneyText, action: a.sampleMoneyAction },
      ].map((section) => (
        <section key={section.title} className="mt-8 border-t border-line pt-7">
          <h2 className="mb-4 text-[18px] font-medium">{section.title}</h2>
          <p className="text-[13px] leading-[2] text-ink/75">{section.text}</p>
          <div className="mt-4 rounded-2xl border border-line/80 bg-canvas/55 p-4">
            <h3 className="mb-2 text-sm font-medium text-gold">{a.advice}</h3>
            <p className="text-[13px] leading-[2] text-ink/75">{section.action}</p>
          </div>
        </section>
      ))}
    </>
  );
}

export function WesternReports({
  language,
  t,
  owner,
  detail,
  example,
  report,
  loading,
  onGenerate,
  onExample,
  onBack,
  onPurchase,
}: {
  language: Language;
  t: Copy;
  owner: string;
  detail: boolean;
  example: boolean;
  report: WesternReport | null;
  loading: boolean;
  onGenerate: () => void;
  onExample: () => void;
  onBack: () => void;
  onPurchase: (preview: () => void, example: boolean) => void;
}) {
  const a = westernCopy(language);
  const [savedAt, setSavedAt] = useState(() => readWesternExampleSaved(owner));
  const [expandedExample, setExpandedExample] = useState(false);
  const [savedMessage, setSavedMessage] = useState(false);
  useEffect(() => {
    setExpandedExample(false);
    setSavedMessage(false);
  }, [example, report?.report_id, owner]);
  const full = example ? expandedExample : report?.access === 'full';
  const chapters = [a.chapterPersonality, a.chapterLove, a.chapterWork, a.chapterMoney];
  const purchase = () => onPurchase(() => setExpandedExample(true), example);
  if (!detail || (!example && !report))
    return (
      <div className="space-y-5" data-testid="western-reports">
        <div>
          <p className="mb-2 text-[10px] tracking-wider text-gold">FATE · {a.system}</p>
          <h1 className="text-[24px] font-semibold leading-9">{a.reports}</h1>
          <p className="mt-2 text-xs leading-7 text-muted">{a.reportIntro}</p>
        </div>
        <section className="relative isolate overflow-hidden rounded-[24px] border border-gold/30 bg-[radial-gradient(ellipse_at_top_right,#55316c66,#20152f_70%)] p-5">
          <BookOpen
            aria-hidden="true"
            className="absolute -right-5 top-2 -z-10 h-36 w-36 rotate-[12deg] text-gold/10"
            strokeWidth={0.7}
          />
          <span className="inline-flex rounded-full border border-gold/25 bg-gold/5 px-3 py-1 text-[10px] text-gold">
            {a.free}
          </span>
          <h2 className="mt-5 max-w-[270px] text-[23px] font-medium leading-9">{a.reportTitle}</h2>
          <p className="mt-2 text-xs leading-7 text-muted">{a.homeReportText}</p>
          <div className="mt-5 grid grid-cols-2 gap-2 border-t border-line pt-4">
            {chapters.map((chapter, i) => (
              <p key={chapter} className="flex items-start gap-2 text-[11px] leading-6 text-muted">
                <span className="text-gold/60">0{i + 1}</span>
                {chapter}
              </p>
            ))}
          </div>
          <button onClick={onGenerate} disabled={loading} className="jy-primary mt-5 w-full">
            {loading ? <RefreshCw size={16} className="animate-spin" /> : <BookOpen size={16} />}
            {loading ? a.waiting : a.generate}
            <ArrowRight size={15} />
          </button>
          <button
            onClick={onExample}
            className="mt-3 min-h-11 w-full text-xs text-gold underline decoration-gold/30 underline-offset-4"
          >
            {a.exampleReport}
          </button>
        </section>
        {report && (
          <button onClick={onGenerate} className="jy-card flex w-full items-center gap-3 text-left">
            <BookOpen size={19} className="text-gold" />
            <span className="flex-1 text-sm">{a.openReport}</span>
            <ArrowRight size={15} />
          </button>
        )}
        <section className="rounded-2xl border border-line bg-panel/40 p-5">
          <h2 className="text-[15px] font-medium">{a.savedReports}</h2>
          <p className="mt-2 text-[11px] leading-6 text-muted">{a.exampleSavedNote}</p>
          {savedAt ? (
            <div className="mt-4 flex items-center gap-2 border-t border-line pt-4">
              <button onClick={onExample} className="min-h-11 flex-1 text-left">
                <p className="text-sm">{a.reportTitle}</p>
                <p className="mt-1 text-[10px] text-muted">
                  {a.exampleBadge} · {new Date(savedAt).toLocaleDateString(t.dateLocale)}
                </p>
              </button>
              <button
                aria-label={a.remove}
                onClick={() => {
                  removeWesternExample(owner);
                  setSavedAt(null);
                }}
                className="jy-icon"
              >
                <Trash2 size={16} />
              </button>
            </div>
          ) : (
            <p className="mt-5 text-xs text-muted">{a.reportEmpty}</p>
          )}
        </section>
      </div>
    );
  return (
    <div data-testid="western-report-detail" className="space-y-5 pb-24">
      <button
        onClick={onBack}
        className="inline-flex min-h-10 items-center gap-2 text-xs text-muted"
      >
        <ArrowLeft size={15} />
        {a.reports}
      </button>
      {example && (
        <p className="rounded-xl border border-gold/20 bg-gold/5 p-3 text-[11px] leading-6 text-muted">
          <strong className="mr-2 text-gold">{a.exampleBadge}</strong>
          {a.exampleNote}
        </p>
      )}
      <article
        className="overflow-hidden rounded-[25px] border border-gold/25 bg-panel/75 p-5"
        aria-label={a.reportTitle}
      >
        <div className="mb-4 flex items-center justify-between gap-2">
          <span className="text-[10px] tracking-wider text-gold">FATE · {a.system}</span>
          {example && (
            <button
              onClick={() => {
                try {
                  saveWesternExample(owner);
                  setSavedAt(readWesternExampleSaved(owner));
                  setSavedMessage(true);
                } catch {
                  setSavedMessage(false);
                }
              }}
              className="min-h-10 text-xs text-gold"
            >
              {savedMessage ? a.reportSaved : a.saveReport}
            </button>
          )}
        </div>
        <h1 className="text-[25px] font-medium leading-10">{a.reportTitle}</h1>
        <p className="mt-2 text-[11px] leading-6 text-muted">{a.reportIntro}</p>
        <section className="my-6 rounded-[19px] border border-gold/30 bg-[linear-gradient(135deg,#59402e55,#35233e88)] p-5">
          <h2 className="mb-3 text-[11px] text-gold">{a.summary}</h2>
          <p className="text-[18px] leading-[1.85]">
            {example ? a.sampleSummary : report?.summary}
          </p>
        </section>
        <section className="border-t border-line pt-6">
          <h2 className="mb-5 text-[18px] font-medium">{a.traits}</h2>
          <div className="space-y-6">
            {example
              ? [1, 2].map((i) => (
                  <article key={i}>
                    <h3 className="mb-2 text-[15px] font-medium">
                      {a[`sampleTrait${i}Title` as keyof WesternCopy]}
                    </h3>
                    <p className="text-[13px] leading-[2] text-ink/75">
                      {a[`sampleTrait${i}Text` as keyof WesternCopy]}
                    </p>
                  </article>
                ))
              : report?.preview.map((section) => (
                  <article key={section.key}>
                    <h3 className="mb-2 text-[15px] font-medium">{section.title}</h3>
                    {section.paragraphs.map((text, i) => (
                      <p key={i} className="mt-2 text-[13px] leading-[2] text-ink/75">
                        {text}
                      </p>
                    ))}
                  </article>
                ))}
          </div>
        </section>
        <section className="relative mt-7 border-t border-line pt-6">
          <h2 className="mb-5 text-[18px] font-medium">{a.watch}</h2>
          {full ? (
            example ? (
              <ExampleExtra a={a} />
            ) : (
              report?.sections.map((section) => (
                <article key={section.key} className="mb-6">
                  <h3 className="mb-2 text-[15px] font-medium">{section.title}</h3>
                  {section.paragraphs.map((text, i) => (
                    <p key={i} className="mt-2 text-[13px] leading-[2] text-ink/75">
                      {text}
                    </p>
                  ))}
                </article>
              ))
            )
          ) : (
            <>
              <div aria-hidden="true" className="pointer-events-none select-none blur-[6px]">
                {example ? (
                  <ExampleExtra a={a} />
                ) : (
                  <div className="space-y-5 py-4">
                    {Array.from({ length: 5 }, (_, i) => (
                      <div key={i}>
                        <div className="mb-3 h-4 w-2/3 rounded bg-muted/20" />
                        {[1, 2, 3].map((j) => (
                          <div key={j} className="mb-2 h-3 w-full rounded bg-muted/10" />
                        ))}
                      </div>
                    ))}
                  </div>
                )}
              </div>
              <div className="absolute inset-x-0 top-24 flex flex-col items-center bg-[radial-gradient(ellipse,#20152ff5,#20152f66_60%,transparent_80%)] px-2 py-5 text-center">
                <span className="mb-4 grid h-16 w-16 place-items-center rounded-full border border-gold/55 bg-panel shadow-[0_0_35px_#e4bc7815]">
                  <LockKeyhole size={25} strokeWidth={1.3} className="text-gold" />
                </span>
                <h3 className="text-base font-medium">{a.lockedTitle}</h3>
                <p className="mt-2 max-w-[260px] text-xs leading-7 text-muted">{a.lockedText}</p>
                <button onClick={purchase} className="jy-outline mt-4">
                  {a.unlock}
                  <ArrowRight size={15} />
                </button>
              </div>
            </>
          )}
        </section>
      </article>
      {!full && (
        <div className="fixed bottom-[var(--app-nav-height,82px)] left-1/2 z-30 w-full max-w-[430px] -translate-x-1/2 border-t border-gold/15 bg-panel/95 px-[19px] py-3 backdrop-blur-xl">
          <button onClick={purchase} className="jy-primary w-full">
            <LockKeyhole size={17} />
            <span className="flex-1">{a.unlock}</span>
            <ArrowRight size={17} />
          </button>
        </div>
      )}
    </div>
  );
}

export function WesternPurchases({
  language,
  onRestore,
}: {
  language: Language;
  onRestore: () => void;
}) {
  const a = westernCopy(language);
  return (
    <div className="space-y-5">
      <h1 className="text-[24px] font-semibold leading-9">{a.purchaseHistory}</h1>
      <section className="rounded-[24px] border border-line bg-panel/60 px-5 py-10 text-center">
        <Crown className="mx-auto mb-6 h-12 w-12 text-gold/65" strokeWidth={1} />
        <h2 className="text-base font-medium">{a.noPurchases}</h2>
        <p className="mt-3 text-xs leading-7 text-muted">{a.noPurchasesText}</p>
        <button onClick={onRestore} className="jy-outline mt-6 w-full">
          {a.restore}
        </button>
      </section>
    </div>
  );
}
