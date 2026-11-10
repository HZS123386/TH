import { BriefcaseBusiness, CalendarDays, Check, Coins, Compass, Heart, House } from 'lucide-react';
import { baziCopy, type BaziReading } from '../lib/bazi';
import type { Language } from '../types';

const readings = [
  { id: 'overview', icon: Compass, color: 'text-rose-300', background: 'bg-rose-950/40' },
  { id: 'annual', icon: CalendarDays, color: 'text-rose-300', background: 'bg-rose-950/40' },
  { id: 'money', icon: Coins, color: 'text-gold', background: 'bg-gold/10' },
  { id: 'love', icon: Heart, color: 'text-rose-300', background: 'bg-rose-950/40' },
  { id: 'work', icon: BriefcaseBusiness, color: 'text-emerald-300', background: 'bg-emerald-950/35' },
  { id: 'family', icon: House, color: 'text-gold', background: 'bg-surface' },
] as const;

export function BaziReadingCards({
  value,
  language,
  basicOnly,
  onChange,
}: {
  value: BaziReading;
  language: Language;
  basicOnly: boolean;
  onChange: (value: BaziReading) => void;
}) {
  const b = baziCopy(language);
  return (
    <fieldset
      className="rounded-[20px] border border-line bg-gold/10 p-4"
      data-testid="bazi-reading-cards"
    >
      <legend className="sr-only">{b.readingCategory}</legend>
      <div className="mb-4 text-center">
        <p className="text-[10px] tracking-[0.18em] text-gold">{b.category}</p>
        <div className="mt-2 flex items-center gap-3">
          <span className="h-px flex-1 bg-gold/35" aria-hidden="true" />
          <h2 className="font-display text-xl font-semibold text-gold">{b.categoryTitle}</h2>
          <span className="h-px flex-1 bg-gold/35" aria-hidden="true" />
        </div>
        <p className="mt-2 text-xs leading-6 text-muted">{b.categoryIntro}</p>
      </div>
      <div className="grid grid-cols-2 gap-3">
        {readings.map(({ id, icon: Icon, color, background }) => (
          <label
            key={id}
            className="relative min-w-0 cursor-pointer has-[:disabled]:cursor-not-allowed"
          >
            <input
              type="radio"
              name="bazi-reading"
              value={id}
              aria-label={b.readings[id].title}
              checked={value === id}
              onChange={() => onChange(id)}
              disabled={basicOnly && id !== 'overview'}
              className="peer absolute inset-0 z-10 h-full w-full cursor-pointer opacity-0 disabled:cursor-not-allowed"
            />
            <span className="relative flex h-full min-h-32 flex-col items-start rounded-2xl border border-line bg-panel p-3.5 transition-colors peer-checked:border-primary peer-checked:bg-surface peer-focus-visible:ring-2 peer-focus-visible:ring-accent peer-disabled:opacity-45">
              <span
                className={`mb-3 inline-flex h-10 w-10 items-center justify-center rounded-xl ${color} ${background}`}
              >
                <Icon size={24} strokeWidth={1.6} aria-hidden="true" />
              </span>
              {value === id && (
                <Check
                  className="absolute right-3 top-3 text-gold"
                  size={15}
                  aria-hidden="true"
                />
              )}
              <span className="text-base font-semibold leading-6">{b.readings[id].title}</span>
              <span className="mt-1 text-[11px] leading-5 text-muted">
                {b.readings[id].subtitle}
              </span>
            </span>
          </label>
        ))}
      </div>
    </fieldset>
  );
}
