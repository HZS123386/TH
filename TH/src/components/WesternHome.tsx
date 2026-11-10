import {
  ArrowRight,
  ArrowUpRight,
  BookOpen,
  CalendarDays,
  Compass,
  Crown,
  Sparkles,
} from 'lucide-react';
import type { Language, Profile } from '../types';
import { westernCopy } from '../lib/western';
import { ZodiacWheel } from './ZodiacWheel';

export function WesternHome({
  language,
  profile,
  onBirth,
  onChart,
  onReports,
  onPurchase,
}: {
  language: Language;
  profile: Profile | null;
  onBirth: () => void;
  onChart: () => void;
  onReports: () => void;
  onPurchase: () => void;
}) {
  const a = westernCopy(language);
  const cards = [
    { title: a.chart, note: a.chartNote, icon: Compass, action: onChart, kind: 'chart' },
    { title: a.reports, note: a.reportNote, icon: BookOpen, action: onReports, kind: 'report' },
    { title: a.fullReport, note: a.fullNote, icon: Crown, action: onPurchase, kind: 'full' },
    { title: a.birth, note: a.birthNote, icon: CalendarDays, action: onBirth, kind: 'birth' },
  ];
  return (
    <div className="space-y-5" data-testid="western-home">
      <section className="relative -mx-[19px] -mt-3 isolate min-h-[310px] overflow-hidden px-[23px] pb-7 pt-9">
        <div
          aria-hidden="true"
          className="absolute inset-0 -z-20 bg-[radial-gradient(ellipse_at_75%_40%,#4a2e7380,transparent_70%)]"
        />
        <img
          src="/images/fate-astrologer.webp"
          alt=""
          width="450"
          height="675"
          fetchPriority="high"
          className="pointer-events-none absolute -right-[69px] -top-2 -z-10 h-[370px] w-[330px] max-w-none object-cover object-top [mask-image:linear-gradient(to_right,transparent,black_28%,black_87%,transparent)]"
        />
        <div
          aria-hidden="true"
          className="absolute inset-0 -z-10 bg-[linear-gradient(90deg,#130c24_3%,#130c2480_48%,transparent_78%),linear-gradient(0deg,#130c24,transparent_35%)]"
        />
        <p className="mb-5 flex items-center gap-2 text-[10px] tracking-[0.15em] text-gold">
          <Sparkles size={12} />
          {a.system}
        </p>
        <h1 className="max-w-[245px] whitespace-pre-line text-[29px] font-semibold leading-[1.5] tracking-[-0.6px] text-ink brandCompact:max-w-[205px] brandCompact:text-[25px]">
          {a.heroTitle}
        </h1>
        <p className="mt-4 max-w-[190px] text-[12px] leading-[1.9] text-ink/75">{a.heroText}</p>
        <span className="mt-5 inline-flex items-center gap-2 rounded-full border border-gold/40 bg-canvas/50 px-3 py-1.5 text-[10px] text-gold">
          <span className="h-1.5 w-1.5 rounded-full bg-gold" />
          {a.heroBadge}
        </span>
      </section>
      <button
        onClick={profile ? onChart : onBirth}
        className="relative -mt-2 flex min-h-[58px] w-full items-center gap-3 rounded-full border border-gold/55 bg-[linear-gradient(100deg,#392647,#21162f)] p-2 pl-4 text-left shadow-[0_8px_35px_-20px_#e4bc7880]"
      >
        <Compass size={22} strokeWidth={1.5} className="text-gold" />
        <span className="flex-1 text-sm font-medium">{profile ? a.continue : a.start}</span>
        <span className="grid h-10 w-10 shrink-0 place-items-center rounded-full bg-gold text-on-primary">
          <ArrowRight size={20} />
        </span>
      </button>
      <div className="flex items-center justify-between pt-1">
        <h2 className="text-[15px] font-medium">{a.journey}</h2>
        <span aria-hidden="true" className="text-gold">
          ✧
        </span>
      </div>
      <section className="grid grid-cols-2 gap-3" aria-label={a.system}>
        {cards.map(({ title, note, icon: Icon, action, kind }, index) => (
          <button
            key={kind}
            onClick={action}
            className={`relative isolate min-h-[145px] overflow-hidden rounded-[21px] border p-4 text-left transition-colors hover:border-gold/70 ${index === 0 ? 'border-gold/40 bg-[linear-gradient(140deg,#332048,#1a142d)]' : 'border-[#706182]/45 bg-[linear-gradient(140deg,#251a3d,#171326)]'}`}
          >
            {kind === 'chart' ? (
              <ZodiacWheel
                className="pointer-events-none absolute -bottom-8 -right-8 -z-10 h-[150px] w-[150px] text-gold/60 opacity-40"
                monochrome
              />
            ) : (
              <Icon
                aria-hidden="true"
                strokeWidth={0.7}
                className="absolute -bottom-4 -right-3 -z-10 h-[100px] w-[100px] rotate-[-10deg] text-[#aa87db]/15"
              />
            )}
            <Icon size={23} strokeWidth={1.35} className="mb-5 text-gold" />
            <h3 className="pr-4 text-[17px] font-semibold leading-7">{title}</h3>
            <p className="mt-1 max-w-[130px] text-[10px] leading-5 text-muted">{note}</p>
            <span className="absolute bottom-3 right-3 grid h-6 w-6 place-items-center rounded-full border border-gold/25 text-gold">
              <ArrowUpRight size={13} />
            </span>
          </button>
        ))}
      </section>
      <button
        onClick={onReports}
        className="relative isolate flex min-h-[151px] w-full items-center overflow-hidden rounded-[23px] border border-gold/30 bg-[radial-gradient(ellipse_at_right,#4d2d6e99,#21172f_75%)] px-5 py-6 text-left"
      >
        <div className="max-w-[220px] pr-8">
          <p className="mb-2 flex items-center gap-2 text-[10px] tracking-wider text-gold">
            <BookOpen size={12} />
            FATE
          </p>
          <h2 className="text-[19px] font-medium leading-8">{a.homeReportTitle}</h2>
          <p className="mt-2 text-[11px] leading-6 text-muted">{a.homeReportText}</p>
        </div>
        <div
          aria-hidden="true"
          className="absolute -right-5 top-7 -z-10 h-32 w-32 rounded-full border border-[#b296dd]/50 bg-[radial-gradient(circle_at_32%_28%,#efe4ff99_0%,#a67ee166_16%,#4f2e8799_42%,#171024_76%)] shadow-[0_0_40px_#8f61ce30]"
        >
          <span className="absolute left-7 top-7 text-[45px] text-gold/80">✧</span>
        </div>
      </button>
      <div className="grid grid-cols-3 gap-2 py-2 text-center">
        {[a.stepBirth, a.stepChart, a.stepReport].map((text, i) => (
          <div key={text}>
            <span className="mx-auto mb-2 grid h-6 w-6 place-items-center rounded-full border border-gold/20 text-[10px] text-gold">
              0{i + 1}
            </span>
            <p className="text-[10px] leading-5 text-muted">{text}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
