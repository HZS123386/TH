import { useState } from 'react';
import { ArrowRight, BookOpen, Check, Copy, Download, LockKeyhole, Trash2 } from 'lucide-react';
import { useThaiChart } from '../../lib/thai';
import type { Profile } from '../../types';
import type { Topic } from '../../lib/wanjai';
import { ThaiChartPanel } from '../ThaiChartPanel';
import { ThaiBasis } from '../ThaiBasis';
import { ThaiSkyPattern } from '../ThaiSkyPattern';
import { PickerDialog } from '../PickerDialog';
import { WanjaiQuestions } from './WanjaiQuestions';
import { JourneyCard } from './WanjaiCards';
import { type WanjaiPageProps, PageIntro, Note, usePage } from './WanjaiShared';
import {
  readSavedReadings,
  removeSavedReading,
  downloadReading,
  type SavedReading,
} from '../../lib/readingLibrary';

function ReportLibrary(p: WanjaiPageProps) {
  const { t, navigate } = p;
  const owner = p.account?.user_id || 'guest';
  const [saved, setSaved] = useState(() => readSavedReadings(owner));
  const [selected, setSelected] = useState<SavedReading | null>(null);
  const [error, setError] = useState('');
  const ready = !!p.thai.value?.chart;
  return (
    <div className="space-y-5" data-testid="report-library">
      <PageIntro title={t.ux_reports} sub={t.ux_reportsIntro} />
      <section className="border-b border-line pb-5 text-xs leading-6 text-muted">
        <p>
          {p.profile?.display_name || t.brandName} · {p.profile?.birth_date}
        </p>
        <button className="min-h-10 text-gold" onClick={() => navigate('profile')}>
          {t.j_editBirth}
        </button>
      </section>
      {[
        { id: 'chart-reading' as const, title: t.ux_natalReport, text: t.ux_natalReportNote },
        { id: 'thai-test' as const, title: t.ux_topicReport, text: t.ux_topicReportNote },
        { id: 'overview' as const, title: t.ux_periodReport, text: t.ux_periodReportNote },
      ].map((report) => (
        <button
          key={report.id}
          className="jy-card flex w-full items-start gap-3 text-left"
          onClick={() => navigate(report.id)}
        >
          <BookOpen size={20} className="mt-1 shrink-0 text-gold" />
          <span className="min-w-0 flex-1">
            <span className="block text-base font-medium">{report.title}</span>
            <span className="mt-2 block text-xs leading-7 text-muted">{report.text}</span>
            {!ready && report.id !== 'overview' && (
              <span className="mt-2 block text-xs text-gold">{t.ux_completeChart}</span>
            )}
          </span>
          <ArrowRight size={16} className="mt-1 shrink-0" />
        </button>
      ))}
      <section className="space-y-3" data-testid="saved-readings">
        <h2 className="text-lg font-medium">{t.ux_savedReports}</h2>
        <p className="text-xs leading-7 text-muted">{t.ux_localReports}</p>
        {!saved.length && <p className="py-3 text-sm text-muted">{t.ux_noSavedReports}</p>}
        {saved.map((reading) => (
          <article key={reading.id} className="rounded-2xl border border-line p-4">
            <button className="w-full text-left" onClick={() => setSelected(reading)}>
              <h3 className="text-sm font-medium">{reading.title}</h3>
              <p className="mt-1 text-xs leading-6 text-muted">
                {reading.birthDate} · {new Date(reading.savedAt).toLocaleString(t.dateLocale)}
              </p>
              <span className="mt-2 block text-xs text-gold">{t.ux_openSaved}</span>
            </button>
            <div className="mt-3 flex gap-5">
              <button
                className="inline-flex min-h-10 items-center gap-2 text-xs text-gold"
                onClick={() => downloadReading(reading)}
              >
                <Download size={15} />
                {t.ux_downloadReport}
              </button>
              <button
                aria-label={`${t.ux_removeSaved} · ${reading.title}`}
                className="ml-auto min-h-10 px-2 text-muted"
                onClick={() => {
                  try {
                    setSaved(removeSavedReading(owner, reading.id));
                  } catch {
                    setError(t.ux_saveFailed);
                  }
                }}
              >
                <Trash2 size={16} />
              </button>
            </div>
          </article>
        ))}
        {error && (
          <p role="alert" className="text-xs text-accent">
            {error}
          </p>
        )}
      </section>
      <details className="border-t border-line pt-4 text-xs text-muted">
        <summary className="cursor-pointer py-2">{t.ux_otherReports}</summary>
        <button className="jy-link w-full text-left" onClick={() => navigate('solution')}>
          {t.w_solution}
          <ArrowRight size={15} />
        </button>
        <button className="jy-link w-full text-left" onClick={() => navigate('life')}>
          {t.w_life}
          <ArrowRight size={15} />
        </button>
      </details>
      {selected && (
        <PickerDialog
          title={selected.title}
          t={t}
          wide
          hideConfirm
          onCancel={() => setSelected(null)}
        >
          <p className="mb-3 text-xs leading-6 text-muted">{t.ux_savedSnapshot}</p>
          <iframe
            title={selected.title}
            sandbox=""
            srcDoc={selected.html}
            className="h-[65dvh] w-full rounded-xl border border-line"
          />
        </PickerDialog>
      )}
    </div>
  );
}

export function WanjaiReports(p: WanjaiPageProps) {
  const { t, state, update, navigate } = p;
  const { data, concern, solution } = usePage(p);
  const [checkout, setCheckout] = useState(false);
  const [copied, setCopied] = useState('');
  const life = p.view === 'life';
  const key: 'life' | 'solution' = life ? 'life' : 'solution';
  const unlocked = state.demo_unlocks.includes(key);
  const option = solution?.options.find((row) => row.id === state.option);
  const path = option && solution ? solution.paths[solution.options.indexOf(option)] : null;
  async function copy(text: string) {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(text);
    } catch {
      setCopied(t.w_copyFailed);
    }
  }
  if (p.view === 'reports') return <ReportLibrary key={p.account?.user_id || 'guest'} {...p} />;
  if (!life && (!concern || !solution)) return <WanjaiQuestions {...p} />;
  const pathCard = (value: NonNullable<typeof path>) => (
    <article key={value.title} className="rounded-[17px] border border-line bg-surface p-5">
      <h3 className="text-[17px] leading-8">{value.title}</h3>
      <p className="mb-3 mt-2 text-xs leading-6 text-muted">{value.when}</p>
      <p className="jy-copy">{value.action}</p>
    </article>
  );
  return (
    <div className="space-y-5" data-testid={life ? 'jy-life-page' : 'jy-plan-page'}>
      <button
        className="min-h-10 text-sm text-muted"
        onClick={() => navigate(life ? 'chart' : 'concern')}
      >
        ‹ {life ? t.w_chart : t.j_backQuestion}
      </button>
      {life ? (
        <section className="relative isolate overflow-hidden rounded-[23px] border border-gold/35 bg-surface p-6 text-ink/85">
          <ThaiSkyPattern className="pointer-events-none absolute -right-16 top-9 -z-10 h-64 w-64 text-muted/40" />
          <div className="mb-8 flex justify-between gap-3 text-xs">
            <span>{t.brandTagline}</span>
            <span>{unlocked ? t.w_locked : t.w_preview}</span>
          </div>
          <BookOpen size={37} strokeWidth={1} className="mb-5" />
          <h1 className="font-display text-[30px] leading-[1.6]">{t.w_life}</h1>
          <p className="mb-7 mt-3 max-w-60 text-base leading-8">{t.w_lifeIntro}</p>
          <p className="border-t border-line pt-4 text-xs leading-6">
            {p.profile?.display_name || t.brandName} · {p.profile?.birth_date}
          </p>
        </section>
      ) : (
        <>
          <PageIntro title={t.w_solution} sub={concern!.question} />
          <section className="jy-card">
            <h2 className="mb-2 text-[17px]">{option ? t.j_context : solution!.intakeTitle}</h2>
            {option && <p className="jy-copy my-3">{option.label}</p>}
            <details open={!option}>
              <summary className="cursor-pointer text-xs leading-6 text-muted">
                {t.j_changeContext}
              </summary>
              <div className="mt-3 space-y-2">
                {solution!.options.map((row) => (
                  <button
                    className={`jy-outline w-full justify-between text-left ${state.option === row.id ? '!border-primary !bg-surface' : ''}`}
                    aria-pressed={state.option === row.id}
                    key={row.id}
                    onClick={() => update({ option: row.id as 'a' | 'b' })}
                  >
                    {row.label}
                    {state.option === row.id && <Check size={14} />}
                  </button>
                ))}
              </div>
            </details>
          </section>
        </>
      )}
      <details className="jy-card !p-0">
        <summary className="cursor-pointer p-4 text-sm text-gold">{t.f_basis}</summary>
        <div className="border-t border-line p-4">
          <ThaiBasis p={p} topic={life ? undefined : (concern?.topic as Topic)} />
        </div>
      </details>
      {life ? (
        <>
          <nav aria-label={t.w_life} className="jy-card !py-3">
            {data.lifeChapters.map((chapter, i) => (
              <a href={`#chapter-${chapter.id}`} key={chapter.id} className="jy-link text-muted">
                <span className="mr-2 text-xs">0{i + 1}</span>
                <span className="flex-1">{chapter.name}</span>
                {i > 0 && !unlocked ? <LockKeyhole size={14} /> : <ArrowRight size={14} />}
              </a>
            ))}
          </nav>
          {data.lifeChapters.map((chapter, i) => {
            const content =
              chapter.id === 'self'
                ? [t.th_asc, t.th_factOnly, t.th_lifePractice]
                : data.lifeLongNotes[chapter.id as keyof typeof data.lifeLongNotes];
            return (
              <section className="jy-card" id={`chapter-${chapter.id}`} key={chapter.id}>
                <p className="jy-kicker mb-2">
                  {t.w_chapter} {i + 1} · {i === 0 ? t.w_preview : t.w_editorial}
                </p>
                <h2 className="mb-3 text-[22px] leading-9">{chapter.name}</h2>
                {i === 0 || unlocked ? (
                  <>
                    <h3 className="mb-3 text-base leading-8">{content[0]}</h3>
                    {content.slice(1).map((text, j) => (
                      <p className="jy-copy my-3" key={j}>
                        {text}
                      </p>
                    ))}
                    <Note>{t.w_reflectionNote}</Note>
                  </>
                ) : (
                  <button className="jy-outline w-full" onClick={() => setCheckout(true)}>
                    <LockKeyhole size={15} />
                    {t.w_demoUnlock}
                  </button>
                )}
              </section>
            );
          })}
        </>
      ) : path ? (
        <>
          <section className="space-y-4">
            <div className="flex items-center justify-between">
              <h2 className="text-[18px]">{t.j_context}</h2>
              <span className="text-xs text-muted">{t.w_preview}</span>
            </div>
            <p className="jy-copy">{option!.summary}</p>
            {pathCard(path)}
          </section>
          {unlocked ? (
            <section className="space-y-4">
              <h2 className="text-xl">{t.w_locked}</h2>
              {solution!.paths.filter((row) => row !== path).map(pathCard)}
              <h2 className="pt-2 text-xl">{t.w_templates}</h2>
              {solution!.templates.map((template) => (
                <article key={template.title} className="jy-card">
                  <h3 className="mb-3 text-[17px] leading-8">{template.title}</h3>
                  <p className="whitespace-pre-wrap rounded-xl bg-surface p-4 text-sm leading-8">
                    {template.text}
                  </p>
                  <button className="jy-outline mt-4" onClick={() => void copy(template.text)}>
                    <Copy size={14} />
                    {copied === template.text ? t.w_copied : t.w_copy}
                  </button>
                </article>
              ))}
              <h2 className="pt-2 text-xl">{t.w_branches}</h2>
              {solution!.branches.map((branch) => (
                <article key={branch.when} className="jy-card">
                  <h3 className="mb-3 text-sm leading-7">{branch.when}</h3>
                  <p className="jy-copy">{branch.action}</p>
                </article>
              ))}
            </section>
          ) : null}
        </>
      ) : (
        <p className="jy-card jy-copy">{t.w_hubSub}</p>
      )}
      {!unlocked && (life || !!path) && (
        <section className="rounded-[22px] border border-gold/35 bg-surface p-6 text-center">
          <LockKeyhole size={27} className="mx-auto mb-4 text-gold" />
          <h2 className="text-xl leading-8">{t.w_demoUnlock}</h2>
          <p className="jy-copy my-4">{life ? t.w_lifeIntro : t.w_planIntro}</p>
          <p className="mb-2 font-display text-3xl text-accent">฿{life ? 199 : 99}</p>
          <p className="mb-5 text-xs text-muted">{t.w_priceNote}</p>
          <button className="jy-primary w-full" onClick={() => setCheckout(true)}>
            {t.w_demoUnlock}
            <ArrowRight size={16} />
          </button>
        </section>
      )}
      {copied === t.w_copyFailed && (
        <p role="status" className="text-sm text-accent">
          {copied}
        </p>
      )}
      <Note>{t.w_paymentNote}</Note>
      <JourneyCard p={p} />
      {!life && (
        <button className="jy-primary w-full" onClick={() => navigate('journey')}>
          {t.w_journey}
          <ArrowRight size={16} />
        </button>
      )}
      <button
        className="jy-outline w-full"
        onClick={() => p.ask(concern?.question || t.w_lifeIntro)}
      >
        {t.w_talk}
        <ArrowRight size={16} />
      </button>
      {checkout && (
        <PickerDialog
          title={`${t.w_demoUnlock} · ฿${life ? 199 : 99}`}
          t={t}
          onCancel={() => setCheckout(false)}
          onConfirm={() => {
            update({ demo_unlocks: [...new Set([...state.demo_unlocks, key])] });
            setCheckout(false);
          }}
        >
          <p className="mb-4 text-base leading-8">{life ? t.w_lifeIntro : t.w_planIntro}</p>
          <p className="jy-copy">{t.w_paymentNote}</p>
          <Note>{t.w_priceNote}</Note>
        </PickerDialog>
      )}
    </div>
  );
}

const sampleProfile: Profile = {
  display_name: 'Nok',
  birth_date: '1999-02-20',
  birth_time: '09:15',
  birthplace: 'Bangkok',
  timezone: 'Asia/Bangkok',
  latitude: 13.7563,
  longitude: 100.5018,
  language: 'zh',
};
export function WanjaiChart(
  p: WanjaiPageProps & {
    exampleOnly?: boolean;
    showExample?: boolean;
    onExampleChange?: (value: boolean) => void;
  },
) {
  const example = !!p.exampleOnly || !!p.showExample;
  const sample = useThaiChart(
    undefined,
    null,
    example ? { ...sampleProfile, language: p.language } : null,
  );
  const model = example
    ? {
        ...p,
        profile: { ...sampleProfile, language: p.language },
        record: null,
        account: null,
        thai: sample,
      }
    : p;
  return (
    <div className="space-y-5" data-testid="jy-chart-page">
      {p.exampleOnly && (
        <button
          aria-label={p.t.back}
          className="min-h-11 text-sm text-muted"
          onClick={() => p.navigate(p.profile ? 'chart' : 'profile')}
        >
          ‹ {p.t.back}
        </button>
      )}
      {!p.exampleOnly && (
        <div className="grid grid-cols-2 gap-2">
          {[false, true].map((value) => (
            <button
              key={String(value)}
              className={`jy-outline !px-2 ${example === value ? '!border-primary !bg-primary !text-on-primary' : ''}`}
              aria-pressed={example === value}
              onClick={() => p.onExampleChange?.(value)}
            >
              {value ? p.t.j_exampleChart : p.t.j_myChart}
            </button>
          ))}
        </div>
      )}
      {example && (
        <p
          role="note"
          className="rounded-xl border border-line bg-surface p-4 text-xs leading-7 text-muted"
        >
          {p.t.j_exampleNotice}
        </p>
      )}
      <ThaiChartPanel key={String(example)} {...model} hideIntro example={example} />
    </div>
  );
}
