import { useState, type FormEvent } from 'react';
import { ArrowLeft, ArrowRight, CalendarDays, ShieldCheck } from 'lucide-react';
import type { Copy } from '../lib/i18n';
import type { Language, Profile } from '../types';
import { westernCopy } from '../lib/western';
import { BirthDatePicker } from './BirthDatePicker';
import { BirthTimeInput } from './BirthTimeInput';
import { BirthplacePicker, TimezonePicker } from './BirthplacePicker';

export function WesternBirthForm({
  profile,
  language,
  t,
  onSave,
  onBack,
}: {
  profile: Profile | null;
  language: Language;
  t: Copy;
  onSave: (value: Profile) => Promise<void>;
  onBack: () => void;
}) {
  const a = westernCopy(language);
  const [form, setForm] = useState<Profile>(
    profile || {
      display_name: '',
      birth_date: '',
      birth_time: '',
      birthplace: '',
      timezone: 'Asia/Bangkok',
      language,
    },
  );
  const [pending, setPending] = useState(false);
  const [error, setError] = useState('');
  const today = new Intl.DateTimeFormat('en-CA', {
    timeZone: form.timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
  async function submit(event: FormEvent) {
    event.preventDefault();
    if (pending) return;
    if (!form.birth_date || form.birth_date < '1901-01-01' || form.birth_date > today) {
      setError(t.chooseBirthDate);
      return;
    }
    if (!form.birthplace.trim()) {
      setError(a.placeRequired);
      return;
    }
    if (form.birth_time === '') {
      setError(t.exactTimeRequired);
      return;
    }
    setPending(true);
    setError('');
    try {
      await onSave({ ...form, display_name: form.display_name.trim(), language });
    } catch {
      setError(a.error);
    } finally {
      setPending(false);
    }
  }
  return (
    <section data-testid="western-birth-form">
      <button
        onClick={onBack}
        className="mb-4 inline-flex min-h-10 items-center gap-2 text-xs text-muted"
      >
        <ArrowLeft size={15} />
        {a.back}
      </button>
      <span className="mb-4 inline-grid h-11 w-11 place-items-center rounded-2xl border border-gold/25 bg-gold/5 text-gold">
        <CalendarDays size={22} strokeWidth={1.3} />
      </span>
      <h1 className="text-[24px] font-semibold leading-9">{a.birth}</h1>
      <p className="mb-6 mt-2 text-xs leading-7 text-muted">{a.birthIntro}</p>
      <form
        onSubmit={submit}
        onInvalidCapture={(event) => {
          event.preventDefault();
          setError(t.formInvalid);
          event.currentTarget.querySelector<HTMLElement>('input:invalid')?.focus();
        }}
      >
        <fieldset
          disabled={pending}
          className="space-y-5 rounded-[23px] border border-line bg-panel/75 p-5"
        >
          <div>
            <label htmlFor="western-name" className="label">
              {a.nickname}
            </label>
            <input
              id="western-name"
              className="field"
              value={form.display_name}
              maxLength={60}
              autoComplete="nickname"
              placeholder={a.nicknamePlaceholder}
              onChange={(event) => setForm({ ...form, display_name: event.target.value })}
            />
          </div>
          <BirthDatePicker
            value={form.birth_date}
            maximum={today}
            t={t}
            onChange={(birth_date) => setForm({ ...form, birth_date })}
          />
          <BirthTimeInput
            value={form.birth_time}
            t={t}
            onChange={(birth_time) => setForm({ ...form, birth_time })}
          />
          <BirthplacePicker
            value={form.birthplace}
            locationId={form.location_id}
            countryCode={form.country_code}
            timezone={form.timezone}
            language={language}
            t={t}
            onChange={(birthplace, timezone, location) =>
              setForm({
                ...form,
                birthplace,
                timezone,
                location_id: location?.id || null,
                country_code: location?.countryCode || null,
                latitude: null,
                longitude: null,
              })
            }
          />
          <TimezonePicker
            value={form.timezone}
            t={t}
            onChange={(timezone) => setForm({ ...form, timezone })}
          />
          {form.birth_time === null && (
            <p className="rounded-xl bg-canvas p-3 text-xs leading-6 text-muted">{a.unknownTime}</p>
          )}
          <p className="flex gap-2 text-[11px] leading-6 text-muted">
            <ShieldCheck size={15} className="mt-1 shrink-0 text-gold/70" />
            {a.birthStorage}
          </p>
        </fieldset>
        {error && (
          <p role="alert" className="mt-4 text-xs leading-6 text-rose-300">
            {error}
          </p>
        )}
        <button type="submit" disabled={pending} className="jy-primary mt-5 w-full">
          {pending ? t.saving : a.saveBirth}
          <ArrowRight size={17} />
        </button>
      </form>
    </section>
  );
}
