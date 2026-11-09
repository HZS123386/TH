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
  onPreview,
}: {
  profile: Profile | null;
  language: Language;
  t: Copy;
  state: CompanionState;
  update: (patch: Partial<CompanionState>) => void;
  onSave: (profile: Profile, openConcern?: boolean) => Promise<void>;
  onCancel?: () => void;
  onPreview?: () => void;
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
          className={`flex w-full items-center gap-4 rounded-2xl border p-4 text-left ${selected ? 'border-primary bg-[#eee1cc]' : 'border-line bg-[#fdfaf4]'}`}
        >
          <span className="rounded-full border border-gold/30 bg-[#f2e8d4] p-3 text-gold">
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
      {onPreview && (
        <button className="jy-outline mb-5 w-full" onClick={onPreview}>
          {t.j_exampleChart}
          <ArrowRight size={16} />
        </button>
      )}
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
            <p className="mt-3 flex items-center gap-2 text-xs text-[#64724d]">
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
              timezone={form.timezone}
              language={language}
              t={t}
              onChange={(birthplace, timezone) =>
                setForm((prev) => ({
                  ...prev,
                  birthplace,
                  timezone,
                  location_id: null,
                  country_code: null,
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
        <section>
          <h2 className="mb-5 font-display text-xl">{t.f_concern}</h2>
          <div className="space-y-3">{concernCards(0, 6)}</div>
          <details className="mt-5">
            <summary className="cursor-pointer text-sm text-muted">{t.f_more}</summary>
            <div className="mt-4 space-y-3">{concernCards(6, 10)}</div>
          </details>
        </section>
        <p className="text-xs leading-6 text-muted">{t.f_privacy}</p>
        {error && (
          <p role="alert" className="text-sm text-accent">
            {error}
          </p>
        )}
        <div
          className={
            profile
              ? 'sticky bottom-20 -mx-2 rounded-2xl border border-line bg-panel/95 p-3 backdrop-blur'
              : 'fixed bottom-0 left-1/2 z-20 w-full max-w-[430px] -translate-x-1/2 border-t border-line bg-[#f7f4ed]/95 px-5 pb-[max(14px,env(safe-area-inset-bottom))] pt-4 backdrop-blur'
          }
        >
          <button
            type="submit"
            className="jy-primary w-full justify-center"
            disabled={!valid || saving}
          >
            {saving ? t.loading : state.concern ? t.j_seeConcern : t.f_cta}
            <ArrowRight size={18} />
          </button>
          {state.concern && (
            <button
              type="button"
              className="mt-2 min-h-10 w-full text-xs text-[#9b8058]"
              disabled={!valid || saving}
              onClick={() => void submit(undefined, false)}
            >
              {t.j_todayLater}
            </button>
          )}
          <p className="mt-3 text-center text-[11px] leading-5 text-muted">{t.f_free}</p>
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
