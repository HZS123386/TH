import { useState } from 'react';
import { ChevronDown, MapPin } from 'lucide-react';
import type { Copy } from '../lib/i18n';
import type { Language } from '../types';
import { BIRTH_COUNTRIES, COMMON_TIMEZONES, findBirthplace } from '../lib/birthplaces';
import { PickerDialog, WheelGroup } from './PickerDialog';
import { WheelColumn } from './WheelColumn';

export function BirthplacePicker({
  value,
  timezone,
  language,
  t,
  onChange,
}: {
  value: string;
  timezone: string;
  language: Language;
  t: Copy;
  onChange: (place: string, timezone: string) => void;
}) {
  const [draft, setDraft] = useState<{
    country: string;
    city: string;
    custom: boolean;
    text: string;
  } | null>(null);
  const found = findBirthplace(value);
  const country = BIRTH_COUNTRIES.find((item) => item.id === draft?.country) || BIRTH_COUNTRIES[0];
  const city = country.cities.find((item) => item.id === draft?.city) || country.cities[0];
  const regions = new Intl.DisplayNames([t.dateLocale], { type: 'region' });
  return (
    <div>
      <label className="label" htmlFor="birthplace">
        {t.birthplace}
      </label>
      <button
        id="birthplace"
        type="button"
        aria-haspopup="dialog"
        className="field flex items-center justify-between gap-3 text-left"
        onClick={() =>
          setDraft({
            country: found?.country.id || 'TH',
            city: found?.city.id || 'Bangkok',
            custom: !!value && !found,
            text: value,
          })
        }
      >
        <span className={value ? '' : 'text-muted'}>
          {found
            ? `${regions.of(found.country.id)} · ${found.city.names[language]}`
            : value || t.chooseBirthplace}
        </span>
        <MapPin size={17} className="shrink-0 text-accent" />
      </button>
      {draft && (
        <PickerDialog
          title={t.birthplace}
          t={t}
          onCancel={() => setDraft(null)}
          onConfirm={() => {
            onChange(
              draft.custom ? draft.text.trim() : `${city.id}, ${country.name}`,
              draft.custom ? timezone : city.zone,
            );
            setDraft(null);
          }}
        >
          <p className="mb-4 text-xs leading-5 text-muted">
            {draft.custom ? t.customCityHint : t.cityPickerHint}
          </p>
          {draft.custom ? (
            <div className="py-6">
              <label htmlFor="custom-city" className="label">
                {t.birthplace}
              </label>
              <input
                id="custom-city"
                className="field"
                value={draft.text}
                maxLength={100}
                placeholder={t.birthplacePlaceholder}
                onChange={(event) => setDraft({ ...draft, text: event.target.value })}
              />
              <p className="mt-3 text-xs text-muted">
                {t.timezone} · {timezone}
              </p>
            </div>
          ) : (
            <WheelGroup>
              <WheelColumn
                label={t.birthCountry}
                value={country.id}
                options={BIRTH_COUNTRIES.map((item) => ({
                  value: item.id,
                  label: regions.of(item.id) || item.name,
                }))}
                onChange={(id) => {
                  const next = BIRTH_COUNTRIES.find((item) => item.id === id)!;
                  setDraft({ ...draft, country: id, city: next.cities[0].id });
                }}
              />
              <WheelColumn
                label={t.birthplace}
                value={city.id}
                options={country.cities.map((item) => ({
                  value: item.id,
                  label: item.names[language],
                }))}
                onChange={(id) => setDraft({ ...draft, city: id })}
              />
            </WheelGroup>
          )}
          <button
            type="button"
            className="btn-quiet mt-3 w-full !text-xs"
            onClick={() => setDraft({ ...draft, custom: !draft.custom })}
          >
            {draft.custom ? t.commonCities : t.customCity}
          </button>
        </PickerDialog>
      )}
    </div>
  );
}

export function TimezonePicker({
  value,
  t,
  onChange,
}: {
  value: string;
  t: Copy;
  onChange: (value: string) => void;
}) {
  const [draft, setDraft] = useState<string | null>(null);
  const [search, setSearch] = useState('');
  const zones = [
    ...new Set([
      value,
      'UTC',
      ...(typeof Intl.supportedValuesOf === 'function'
        ? Intl.supportedValuesOf('timeZone')
        : COMMON_TIMEZONES),
    ]),
  ].sort();
  const filtered = zones.filter((zone) =>
    zone.toLowerCase().replaceAll('_', ' ').includes(search.toLowerCase().replaceAll('_', ' ')),
  );
  return (
    <div>
      <label className="label" htmlFor="timezone">
        {t.timezone}
      </label>
      <button
        id="timezone"
        type="button"
        aria-haspopup="dialog"
        className="field flex items-center justify-between gap-3 text-left"
        onClick={() => {
          setSearch('');
          setDraft(value);
        }}
      >
        <span className="truncate">{value}</span>
        <ChevronDown size={17} className="shrink-0 text-accent" />
      </button>
      {draft !== null && (
        <PickerDialog
          title={t.timezone}
          t={t}
          onCancel={() => setDraft(null)}
          onConfirm={() => {
            onChange(draft);
            setDraft(null);
          }}
        >
          <label className="sr-only" htmlFor="timezone-search">
            {t.searchTimezone}
          </label>
          <input
            id="timezone-search"
            className="field mb-5"
            value={search}
            placeholder={t.searchTimezone}
            onChange={(event) => {
              const text = event.target.value;
              setSearch(text);
              const matches = zones.filter((zone) =>
                zone
                  .toLowerCase()
                  .replaceAll('_', ' ')
                  .includes(text.toLowerCase().replaceAll('_', ' ')),
              );
              if (matches.length && !matches.includes(draft)) setDraft(matches[0]);
            }}
          />
          {filtered.length ? (
            <WheelGroup>
              <WheelColumn
                label={t.timezone}
                value={filtered.includes(draft) ? draft : filtered[0]}
                options={filtered.map((zone) => ({ value: zone, label: zone }))}
                onChange={setDraft}
              />
            </WheelGroup>
          ) : (
            <p className="py-12 text-center text-sm text-muted">{t.noTimezone}</p>
          )}
          <p className="mt-3 text-center text-xs text-muted">
            {t.selectedTimezone} · {draft}
          </p>
        </PickerDialog>
      )}
    </div>
  );
}
