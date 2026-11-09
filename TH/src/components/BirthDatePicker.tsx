import { useState } from 'react';
import { CalendarDays } from 'lucide-react';
import type { Copy } from '../lib/i18n';
import { dateParts, daysInMonth, validBirthDate } from '../lib/birthDate';
import { PickerDialog, WheelGroup } from './PickerDialog';
import { WheelColumn } from './WheelColumn';

export function BirthDatePicker({
  value,
  maximum,
  t,
  onChange,
}: {
  value: string;
  maximum: string;
  t: Copy;
  onChange: (value: string) => void;
}) {
  const [draft, setDraft] = useState<string | null>(null);
  const [era, setEra] = useState<'ce' | 'be'>('ce');
  const parts = dateParts(draft || value || '2000-01-01');
  const max = dateParts(maximum);
  const monthCount = parts.year === max.year ? max.month : 12;
  const dayCount =
    parts.year === max.year && parts.month === max.month
      ? max.day
      : daysInMonth(parts.year, parts.month);
  const update = (change: Partial<typeof parts>) => {
    const next = { ...parts, ...change };
    setDraft(validBirthDate(next.year, next.month, next.day, maximum));
  };
  const formatted = value
    ? new Intl.DateTimeFormat(`${t.dateLocale}-u-ca-gregory`, {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        timeZone: 'UTC',
      }).format(new Date(`${value}T00:00:00Z`))
    : t.chooseBirthDate;
  return (
    <div>
      <label className="label" htmlFor="birth-date">
        {t.birthDate}
      </label>
      <button
        id="birth-date"
        type="button"
        aria-haspopup="dialog"
        className="field flex items-center justify-between gap-3 text-left"
        onClick={() => setDraft(value || validBirthDate(2000, 1, 1, maximum))}
      >
        <span className={value ? '' : 'text-muted'}>{formatted}</span>
        <CalendarDays size={17} className="shrink-0 text-accent" />
      </button>
      {draft !== null && (
        <PickerDialog
          title={t.birthDate}
          t={t}
          onCancel={() => setDraft(null)}
          onConfirm={() => {
            onChange(draft);
            setDraft(null);
          }}
        >
          <p className="mb-4 text-xs leading-5 text-muted">{t.w_eraHint}</p>
          <div className="mb-5 flex gap-2">
            {(['ce', 'be'] as const).map((value) => (
              <button
                key={value}
                type="button"
                aria-pressed={era === value}
                className={`flex-1 rounded-lg border px-3 py-2 text-xs ${era === value ? 'border-primary bg-surface text-accent' : 'border-line text-muted'}`}
                onClick={() => setEra(value)}
              >
                {value === 'ce' ? t.w_gregorian : t.w_buddhist}
              </button>
            ))}
          </div>
          <WheelGroup>
            <WheelColumn
              label={t.pickerYear}
              value={String(parts.year)}
              options={Array.from({ length: max.year - 1900 }, (_, i) => ({
                value: String(i + 1901),
                label: String(i + 1901 + (era === 'be' ? 543 : 0)),
              }))}
              onChange={(year) => update({ year: Number(year) })}
            />
            <WheelColumn
              label={t.pickerMonth}
              value={String(parts.month)}
              options={Array.from({ length: monthCount }, (_, i) => ({
                value: String(i + 1),
                label: new Intl.DateTimeFormat(t.dateLocale, {
                  month: 'short',
                  timeZone: 'UTC',
                }).format(new Date(Date.UTC(2000, i, 1))),
              }))}
              onChange={(month) => update({ month: Number(month) })}
            />
            <WheelColumn
              label={t.pickerDay}
              value={String(parts.day)}
              options={Array.from({ length: dayCount }, (_, i) => ({
                value: String(i + 1),
                label: String(i + 1),
              }))}
              onChange={(day) => update({ day: Number(day) })}
            />
          </WheelGroup>
        </PickerDialog>
      )}
    </div>
  );
}
