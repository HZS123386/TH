import { ArrowRight, CalendarDays, UserRound } from 'lucide-react';
import type { WanjaiPageProps } from './wanjai/WanjaiShared';

export function BirthOverview({ p }: { p: WanjaiPageProps }) {
  const { profile, t } = p;
  return (
    <section className="space-y-4" data-testid="birthday-overview">
      <CalendarDays size={28} className="text-gold" />
      <h2 className="text-lg font-medium">{t.ux_birthdayOverview}</h2>
      <p className="text-sm leading-7 text-ink/85">{t.ux_unknownBirthNote}</p>
      {profile && (
        <div className="border-y border-line py-4 text-sm leading-7">
          <p className="text-xs text-muted">{t.ux_confirmedBirth}</p>
          <p className="mt-1">
            {profile.birth_date} ·{' '}
            {new Intl.DateTimeFormat(t.dateLocale, { weekday: 'long', timeZone: 'UTC' }).format(
              new Date(`${profile.birth_date}T12:00:00Z`),
            )}
          </p>
          {profile.birthplace && <p className="text-xs text-muted">{profile.birthplace}</p>}
        </div>
      )}
      <button className="jy-primary w-full" onClick={() => p.navigate('overview')}>
        {t.ux_dateFortune}
        <ArrowRight size={16} />
      </button>
      <button className="jy-outline w-full" onClick={() => p.navigate('profile')}>
        <UserRound size={16} />
        {t.ux_completeChart}
      </button>
    </section>
  );
}
