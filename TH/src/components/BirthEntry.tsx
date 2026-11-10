import { useState, type FormEvent } from 'react';
import { ArrowRight, Check, ChevronDown } from 'lucide-react';
import type { Copy } from '../lib/i18n';
import type { Language, Profile } from '../types';
import { cleanGuestBirth } from '../lib/guestBirth';
import { contentFor, type CompanionState, type Topic } from '../lib/wanjai';
import { BirthDatePicker } from './BirthDatePicker';
import { BirthTimeInput } from './BirthTimeInput';
import { BirthplacePicker, TimezonePicker } from './BirthplacePicker';
import { ThaiLocationInput } from './ThaiLocationInput';
import { ThaiSkyPattern } from './ThaiSkyPattern';
import { concernIcons } from './wanjai/WanjaiShared';

export function BirthEntry({
  profile,
  language,
  t,
  state,
  update,
  onSave,
  onCancel,
}: {
  profile: Profile | null;
  language: Language;
  t: Copy;
  state: CompanionState;
  update: (patch: Partial<CompanionState>) => void;
  onSave: (profile: Profile, openConcern?: boolean) => Promise<void>;
  onCancel?: () => void;
}) {
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
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const valid = cleanGuestBirth(form);
  const today = new Intl.DateTimeFormat('en-CA', {
    timeZone: form.timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
  const concerns = contentFor(language).concernLibrary;
  async function submit(event?: FormEvent, openConcern = !!state.concern) {
    event?.preventDefault();
    if (!valid) {
      setError(t.chooseBirthDate);
      return;
    }
    setSaving(true);
    setError('');
    try {
      await onSave({ ...valid, language }, openConcern);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : String(cause));
    } finally {
      setSaving(false);
    }
  }
  function concernCards(start: number, end: number) {
    return concerns.slice(start, end).map((concern, index) => {
      const Icon = concernIcons[start + index];
      const selected = state.concern === concern.id;
      return (
        <button
          type="button"
          key={concern.id}
          aria-pressed={selected}
          onClick={() =>
            update({
              concern: selected ? null : concern.id,
              option: null,
              topic: (concern.topic as Topic | null) || state.topic,
            })
          }
          className={`flex w-full items-center gap-4 rounded-2xl border p-4 text-left ${selected ? 'border-primary bg-surface' : 'border-line bg-panel'}`}
        >
          <span className="rounded-full border border-gold/30 bg-surface p-3 text-gold">
            <Icon size={20} />
          </span>
          <span className="min-w-0 flex-1">
            <span className="block text-xs text-muted">{concern.label}</span>
            <span className="mt-1 block text-sm leading-7">{concern.question}</span>
          </span>
          {selected ? (
            <Check size={16} className="shrink-0 text-accent" />
          ) : (
            <ArrowRight size={15} className="shrink-0 text-accent" />
          )}
        </button>
      );
    });
  }
  return (
    <div className="mx-auto max-w-2xl" data-testid="birth-entry">
      <header className="relative isolate mb-7 overflow-hidden rounded-2xl py-4 pr-6">
        <div
          aria-hidden="true"
          className="pointer-events-none absolute inset-0 -z-10 bg-[radial-gradient(ellipse_at_100%_35%,rgba(202,168,88,0.22),transparent_70%)]"
        />
        <ThaiSkyPattern className="pointer-events-none absolute -right-12 top-0 -z-10 h-52 w-52 text-gold/40 sm:-right-6 sm:h-64 sm:w-64" />
        <p className="mb-4 text-xs tracking-wide text-gold">{t.f_intro}</p>
        <h1 className="relative max-w-lg font-display text-3xl leading-relaxed sm:text-4xl">
          {t.f_title}
        </h1>
        <p className="mt-4 text-sm leading-7 text-muted">{t.f_partial}</p>
      </header>
      <form
        onSubmit={(event) => void submit(event)}
        className="panel space-y-7 rounded-3xl p-5 sm:p-8"
      >
        <div>
          <h2 className="font-display text-2xl">{t.f_start}</h2>
          <p className="mt-3 text-sm leading-7 text-muted">{t.f_required}</p>
        </div>
        <div>
          <BirthDatePicker
            value={form.birth_date}
            maximum={today}
            t={t}
            onChange={(birth_date) => setForm((prev) => ({ ...prev, birth_date }))}
          />
          {valid && (
            <p className="mt-3 flex items-center gap-2 text-xs text-emerald-300">
              <Check size={14} />
              {t.f_dateConfirmed} · {form.birth_date} · พ.ศ.{' '}
              {Number(form.birth_date.slice(0, 4)) + 543}
            </p>
          )}
        </div>
        <details className="border-y border-line py-5">
          <summary className="cursor-pointer text-sm text-accent">
            {t.f_optional}
            <ChevronDown size={15} className="ml-2 inline" />
          </summary>
          <div className="mt-5 space-y-6">
            <BirthTimeInput
              value={form.birth_time}
              t={t}
              onChange={(birth_time) => setForm((prev) => ({ ...prev, birth_time }))}
            />
            <BirthplacePicker
              value={form.birthplace}
              locationId={form.location_id}
              countryCode={form.country_code}
              timezone={form.timezone}
              language={language}
              t={t}
              onChange={(birthplace, timezone, location) =>
                setForm((prev) => ({
                  ...prev,
                  birthplace,
                  timezone,
                  location_id: location?.id || null,
                  country_code: location?.countryCode || null,
                  latitude: null,
                  longitude: null,
                }))
              }
            />
            {form.birthplace && (
              <button
                type="button"
                className="btn-quiet !text-xs"
                onClick={() =>
                  setForm((prev) => ({
                    ...prev,
                    birthplace: '',
                    location_id: null,
                    country_code: null,
                    latitude: null,
                    longitude: null,
                  }))
                }
              >
                {t.f_clearPlace}
              </button>
            )}
            <details className="text-xs text-muted">
              <summary className="cursor-pointer py-2">{t.ux_advancedBirth}</summary>
              <div className="mt-3 space-y-4">
                <TimezonePicker
                  value={form.timezone}
                  t={t}
                  onChange={(timezone) => setForm((prev) => ({ ...prev, timezone }))}
                />
                <ThaiLocationInput
                  profile={form}
                  t={t}
                  onChange={(patch) => setForm((prev) => ({ ...prev, ...patch }))}
                />
              </div>
            </details>
          </div>
        </details>
        <section>
          <h2 className="mb-5 font-display text-xl">{t.f_concern}</h2>
          <div className="space-y-3">{concernCards(0, 6)}</div>
          <details className="mt-5">
            <summary className="cursor-pointer text-sm text-muted">{t.f_more}</summary>
            <div className="mt-4 space-y-3">{concernCards(6, 10)}</div>
          </details>
        </section>
        {error && (
          <p role="alert" className="text-sm text-accent">
            {error}
          </p>
        )}
        <div
          className={
            profile
              ? 'sticky bottom-20 -mx-2 rounded-2xl border border-line bg-panel/95 px-3 py-2 backdrop-blur'
              : 'fixed bottom-0 left-1/2 z-20 w-full max-w-[430px] -translate-x-1/2 border-t border-line bg-panel/95 px-5 pb-[max(10px,env(safe-area-inset-bottom))] pt-2 backdrop-blur'
          }
        >
          <button
            type="submit"
            className="jy-primary min-h-11 w-full justify-center py-2.5"
            disabled={!valid || saving}
          >
            {saving ? t.loading : state.concern ? t.j_seeConcern : t.f_cta}
            <ArrowRight size={18} />
          </button>
          {state.concern && (
            <button
              type="button"
              className="mt-1 min-h-9 w-full text-xs text-muted"
              disabled={!valid || saving}
              onClick={() => void submit(undefined, false)}
            >
              {t.j_todayLater}
            </button>
          )}
          <p className="mt-1 text-center text-[11px] leading-4 text-muted">{t.f_free}</p>
        </div>
        {onCancel && (
          <button type="button" className="btn-quiet" disabled={saving} onClick={onCancel}>
            {t.cancel}
          </button>
        )}
      </form>
    </div>
  );
}
