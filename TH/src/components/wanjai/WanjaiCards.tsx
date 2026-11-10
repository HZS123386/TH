import { ArrowRight, BookOpen, MessageCircle } from 'lucide-react';
import { type WanjaiPageProps, usePage } from './WanjaiShared';

export function TalkEntry({
  p,
  text,
  compact = false,
}: {
  p: WanjaiPageProps;
  text?: string;
  compact?: boolean;
}) {
  const { concern } = usePage(p);
  return (
    <section
      className={`${compact ? 'p-4' : 'p-[17px]'} rounded-[20px] border border-gold/35 bg-surface`}
    >
      {!compact && <p className="mb-3 text-[11px] text-accent">{p.t[`f_${p.state.period}`]}</p>}
      <div className="flex items-center gap-3">
        <span className="grid h-[42px] w-[42px] shrink-0 place-items-center rounded-[15px] bg-primary text-on-primary">
          <MessageCircle size={24} />
        </span>
        <div>
          <h2 className="text-[17px] font-medium leading-7 text-gold">
            {concern?.question || p.t.j_startTalk}
          </h2>
          {text && <p className="mt-1 text-[13px] leading-6 text-ink/85">{text}</p>}
        </div>
      </div>
      <button
        className="jy-primary mt-3 w-full"
        onClick={() => p.ask(concern?.question || text || p.t.j_startTalk)}
      >
        {p.t.w_talk}
        <ArrowRight size={17} />
      </button>
      {!compact && <p className="mt-3 text-xs leading-6 text-ink/85">{p.t.j_topicCaption}</p>}
    </section>
  );
}

export function JourneyCard({ p }: { p: WanjaiPageProps }) {
  const { concern } = usePage(p);
  if (!concern) return null;
  const records = p.state.records.filter((row) => row.concern === concern.id);
  return (
    <button className="jy-card w-full text-left" onClick={() => p.navigate('journey')}>
      <span className="jy-kicker">{p.t.j_journeyTitle}</span>
      <span className="mt-1 flex items-center justify-between gap-3">
        <b className="text-[15px] font-medium leading-7">{concern.question}</b>
        <ArrowRight size={17} className="shrink-0 text-accent" />
      </span>
      <span className="mt-4 flex gap-1.5">
        {Array.from({ length: 7 }, (_, i) => (
          <span
            key={i}
            className={`h-1.5 flex-1 rounded-full ${i < records.length ? 'bg-primary' : 'bg-line'}`}
          />
        ))}
      </span>
      <span className="mt-3 block text-xs text-muted">
        {p.t.w_step} {Math.min(records.length + 1, 7)} / 7 · {p.t.w_journeyHint}
      </span>
    </button>
  );
}

export function ReportsTeaser({ p }: { p: WanjaiPageProps }) {
  return (
    <button
      className="flex w-full items-center gap-4 rounded-[20px] border border-line bg-surface p-5 text-left"
      onClick={() => p.navigate('reports')}
    >
      <span className="grid h-24 w-16 shrink-0 place-items-center rounded-r-lg border border-gold/50 bg-surface text-gold shadow-sm">
        <BookOpen size={32} strokeWidth={1} />
      </span>
      <span className="min-w-0">
        <span className="jy-kicker">{p.t.ux_natalReport}</span>
        <b className="mt-1 block font-display text-[21px] text-gold">{p.t.ux_reports}</b>
        <span className="mt-2 block text-xs leading-6 text-ink/85">{p.t.ux_reportsIntro}</span>
      </span>
      <ArrowRight size={16} className="ml-auto shrink-0 text-gold" />
    </button>
  );
}
