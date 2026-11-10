import type { ThaiHoroscope } from 'thai-astrology';
import { formatBirthTime } from '../lib/birthTime';
import { contentFor } from '../lib/wanjai';
import { ZodiacIcon } from './ZodiacIcon';
import type { WanjaiPageProps } from './wanjai/WanjaiShared';

export function NatalChartHero({ chart, p }: { chart: ThaiHoroscope; p: WanjaiPageProps }) {
  const { t, profile, language } = p;
  const signs = contentFor(language).signs;
  const sun = chart.points.sun;
  const date = profile?.birth_date
    ? new Intl.DateTimeFormat(`${t.dateLocale}-u-ca-gregory`, {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        timeZone: 'UTC',
      }).format(new Date(`${profile.birth_date}T00:00:00Z`))
    : '';
  return (
    <section
      className="mb-6 px-1 pb-3 pt-5 text-center"
      aria-label={t.th_personal}
      data-testid="natal-chart-hero"
    >
      <h2 className="break-words text-[24px] font-semibold leading-9 text-ink/90">
        {profile?.display_name || t.brandName}
      </h2>
      <p className="mt-1 text-[11px] leading-6 text-muted">
        {date} · {formatBirthTime(profile?.birth_time, t)}
      </p>
      <div className="mb-3 mt-5" data-hero-point="sun">
        <p className="text-[11px] leading-5 text-muted">{t.q_sun}</p>
        <p className="text-base font-medium leading-7 text-gold/90">{signs[sun.sign].name}</p>
      </div>
      <div className="grid grid-cols-[1fr_1.65fr_1fr] items-center gap-2">
        <div className="min-w-0" data-hero-point="moon">
          <span aria-hidden="true" className="text-[22px] text-muted">
            ☾
          </span>
          <p className="mt-1 text-[10px] leading-5 text-muted">{t.q_moon}</p>
          <p className="break-words text-[13px] font-medium leading-6 text-ink/85">
            {signs[chart.points.moon.sign].name}
          </p>
        </div>
        <div className="relative aspect-square rounded-full border border-line/80 p-2">
          <span
            aria-hidden="true"
            className="celestial-twinkle absolute -left-2 top-6 text-sm text-gold/70"
          >
            ✦
          </span>
          <span
            aria-hidden="true"
            className="celestial-float absolute -right-2 bottom-5 text-xl text-muted/70"
          >
            ☾
          </span>
          <span
            aria-hidden="true"
            className="absolute -top-0.5 left-1/2 h-1 w-1 rounded-full bg-muted/70"
          />
          <ZodiacIcon
            signIndex={sun.sign}
            name={signs[sun.sign].name}
            large
            className="celestial-float h-full w-full"
          />
          <span
            aria-hidden="true"
            className="absolute -bottom-0.5 left-1/2 h-1 w-1 rounded-full bg-muted/70"
          />
        </div>
        <div className="min-w-0" data-hero-point="ascendant">
          <span aria-hidden="true" className="text-[22px] text-muted">
            ↗
          </span>
          <p className="mt-1 text-[10px] leading-5 text-muted">{t.q_asc}</p>
          <p className="break-words text-[13px] font-medium leading-6 text-ink/85">
            {signs[chart.points.ascendant.sign].name}
          </p>
        </div>
      </div>
    </section>
  );
}
