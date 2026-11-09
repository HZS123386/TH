import { useState } from 'react';
import { Clock3 } from 'lucide-react';
import type { Copy } from '../lib/i18n';
import { PickerDialog, WheelGroup } from './PickerDialog';
import { WheelColumn } from './WheelColumn';
import { encodeBirthTime } from '../lib/birthTime';

export function BirthTimeInput({
  value,
  t,
  onChange,
}: {
  value: string | null;
  t: Copy;
  onChange: (value: string | null) => void;
}) {
  const [lastKnown, setLastKnown] = useState(value || '');
  const [draft, setDraft] = useState<string | null>(null);
  const unknown = value === null;
  const [hour, minute] = (draft || value || '09:00').split(':').map(Number);
  const period = hour >= 12 ? 'pm' : 'am';
  function update(nextPeriod: string, nextHour: number, nextMinute: number) {
    setDraft(encodeBirthTime(nextPeriod, nextHour, nextMinute));
  }
  const format = (time: string) => {
    const [h, m] = time.split(':');
    return `${Number(h) >= 12 ? t.pm : t.am} ${Number(h) % 12 || 12}:${m}`;
  };
  return (
    <fieldset>
      <legend className="label">{t.birthTime}</legend>
      <button
        id="birth-time"
        type="button"
        aria-label={t.birthTime}
        aria-haspopup="dialog"
        disabled={unknown}
        className="field flex items-center justify-between gap-3 text-left"
        onClick={() => setDraft(value || lastKnown || '09:00')}
      >
        <span className={value ? '' : 'text-muted'}>
          {unknown ? t.timeUnknown : value ? format(value) : t.chooseBirthTime}
        </span>
        <Clock3 size={17} className="shrink-0 text-accent" />
      </button>
      <label className="mt-3 flex items-start gap-2 text-xs leading-5 text-muted">
        <input
          type="checkbox"
          className="mt-0.5 h-4 w-4 shrink-0 accent-accent"
          checked={unknown}
          onChange={(event) => {
            if (event.target.checked) {
              setLastKnown(value || lastKnown);
              onChange(null);
            } else onChange(lastKnown);
          }}
        />
        {t.timeUnknown}
      </label>
      {unknown && <p className="mt-2 text-xs leading-6 text-accent">{t.unknownTimeNote}</p>}
      {draft !== null && (
        <PickerDialog
          title={t.birthTime}
          t={t}
          onCancel={() => setDraft(null)}
          onConfirm={() => {
            setLastKnown(draft);
            onChange(draft);
            setDraft(null);
          }}
        >
          <p className="mb-4 text-xs leading-5 text-muted">{t.timePickerHint}</p>
          <WheelGroup>
            <WheelColumn
              label={t.period}
              value={period}
              options={[
                { value: 'am', label: t.am },
                { value: 'pm', label: t.pm },
              ]}
              onChange={(p) => update(p, hour % 12 || 12, minute)}
            />
            <WheelColumn
              label={t.birthHour}
              value={String(hour % 12 || 12)}
              options={Array.from({ length: 12 }, (_, i) => ({
                value: String(i + 1),
                label: String(i + 1).padStart(2, '0'),
              }))}
              onChange={(h) => update(period, Number(h), minute)}
            />
            <WheelColumn
              label={t.birthMinute}
              value={String(minute)}
              options={Array.from({ length: 60 }, (_, i) => ({
                value: String(i),
                label: String(i).padStart(2, '0'),
              }))}
              onChange={(m) => update(period, hour % 12 || 12, Number(m))}
            />
          </WheelGroup>
          <p className="mt-4 text-sm leading-7 text-accent" data-testid="birth-clock-preview">
            {t.q_savedTime} · {draft}
          </p>
        </PickerDialog>
      )}
    </fieldset>
  );
}
