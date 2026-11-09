import { useEffect, useState, type FormEvent } from 'react';
import { ArrowLeft, ArrowRight, Check, Info, Sparkles, UserRound } from 'lucide-react';
import type { Copy } from '../lib/i18n';
import type { Language, Profile } from '../types';
import { BirthTimeInput } from './BirthTimeInput';
import { BirthDatePicker } from './BirthDatePicker';
import { BirthplacePicker, TimezonePicker } from './BirthplacePicker';
import { LANGUAGES } from '../lib/languages';
import { ThaiLocationInput } from './ThaiLocationInput';

export function ProfileForm({
  profile,
  language,
  t,
  onSave,
  onBack,
  onboarding = false,
}: {
  profile?: Profile;
  language: Language;
  t: Copy;
  onSave: (profile: Profile) => Promise<void>;
  onBack: () => void;
  onboarding?: boolean;
}) {
  const [form, setForm] = useState<Profile>(
    profile || {
      display_name: '',
      birth_date: '',
      birth_time: '',
      timezone: 'Asia/Bangkok',
      birthplace: '',
      language,
    },
  );
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [timeInputRevision, setTimeInputRevision] = useState(0);
  useEffect(() => setError(''), [language]);
  const change = <K extends keyof Profile>(key: K, value: Profile[K]) =>
    setForm((prev) => ({ ...prev, [key]: value }));
  const today = new Intl.DateTimeFormat('en-CA', {
    timeZone: form.timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!form.birth_date || form.birth_date < '1901-01-01' || form.birth_date > today) {
      setError(t.chooseBirthDate);
      document.getElementById('birth-date')?.focus();
      return;
    }
    setSaving(true);
    setError('');
    try {
      await onSave({ ...form, birth_time: form.birth_time || null, language });
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  }
  return (
    <section className="panel enter mx-auto max-w-3xl p-6 sm:p-9">
      <div className="mb-7 flex flex-wrap items-start justify-between gap-4">
        <div>
          <span className="mb-4 inline-flex rounded-xl bg-surface p-3 text-accent">
            <UserRound size={21} />
          </span>
          <h2 className="text-xl font-semibold">
            {onboarding ? t.onboardingTitle : t.profileTitle}
          </h2>
          <p className="mt-2 max-w-md text-sm leading-6 text-muted">
            {onboarding ? t.onboardingSub : t.profileSub}
          </p>
        </div>
        <button
          type="button"
          className="btn-quiet border border-line !text-xs"
          disabled={saving}
          onClick={() => {
            setForm({
              display_name: 'Nok',
              birth_date: '1995-08-17',
              birth_time: '09:30',
              timezone: 'Asia/Bangkok',
              birthplace: 'Bangkok',
              language,
            });
            setTimeInputRevision((prev) => prev + 1);
          }}
        >
          <Sparkles size={14} />
          {t.sample}
        </button>
      </div>
      <form
        onSubmit={submit}
        className="space-y-6"
        onInvalidCapture={(event) => {
          event.preventDefault();
          setError(
            (event.target as HTMLElement).id.startsWith('birth-') &&
              (event.target as HTMLElement).id !== 'birth-date'
              ? t.exactTimeRequired
              : t.formInvalid,
          );
          event.currentTarget
            .querySelector<HTMLElement>('input:invalid,select:invalid,textarea:invalid')
            ?.focus();
        }}
      >
        <div>
          <label className="label" htmlFor="display-name">
            {t.name}
          </label>
          <input
            id="display-name"
            className="field"
            value={form.display_name}
            onChange={(e) => change('display_name', e.target.value)}
            placeholder={t.namePlaceholder}
            maxLength={60}
            autoComplete="nickname"
          />
        </div>
        <div className="grid gap-6 sm:grid-cols-2">
          <BirthDatePicker
            value={form.birth_date}
            maximum={today}
            t={t}
            onChange={(value) => change('birth_date', value)}
          />
          <BirthTimeInput
            key={timeInputRevision}
            value={form.birth_time}
            t={t}
            onChange={(value) => change('birth_time', value)}
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
          <TimezonePicker
            value={form.timezone}
            t={t}
            onChange={(value) => change('timezone', value)}
          />
        </div>
        <ThaiLocationInput
          profile={form}
          t={t}
          onChange={(patch) => setForm((prev) => ({ ...prev, ...patch }))}
        />
        <p className="text-xs leading-6 text-muted">
          {t.selectedLanguage}：
          <span className="text-ink">{LANGUAGES.find((item) => item.id === language)!.label}</span>
          <span className="mt-1 block">{t.languageHint}</span>
        </p>
        <div className="flex gap-3 rounded-xl bg-canvas p-4 text-xs leading-6 text-muted">
          <Info size={17} className="mt-1 shrink-0 text-accent" />
          <div>
            <p>{t.profileNote}</p>
            {onboarding && <p className="mt-2 text-accent">{t.accountBinding}</p>}
            {profile && <p className="mt-2 font-medium text-gold">{t.profileUpdate}</p>}
          </div>
        </div>
        {error && (
          <p role="alert" className="text-sm text-rose-300">
            {error}
          </p>
        )}
        <div className="flex flex-wrap justify-between gap-3 border-t border-line pt-5">
          {!onboarding && (
            <button type="button" className="btn-quiet" disabled={saving} onClick={onBack}>
              <ArrowLeft size={15} />
              {t.cancel}
            </button>
          )}
          <button
            type="submit"
            className={`btn-primary ${onboarding ? 'w-full sm:ml-auto sm:w-auto' : ''}`}
            disabled={saving}
          >
            {saving ? (
              <span className="h-4 w-4 animate-spin rounded-full border-2 border-white/30 border-t-white" />
            ) : (
              <Check size={16} />
            )}
            {saving ? t.saving : onboarding ? t.onboardingSave : t.saveProfile}
            <ArrowRight size={16} />
          </button>
        </div>
      </form>
    </section>
  );
}
