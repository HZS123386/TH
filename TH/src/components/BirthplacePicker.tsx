import { useEffect, useState } from 'react';
import { ChevronDown, MapPin } from 'lucide-react';
import type { Copy } from '../lib/i18n';
import type { Language } from '../types';
import { BIRTH_COUNTRIES, COMMON_TIMEZONES, findBirthplace } from '../lib/birthplaces';
import { PickerDialog, WheelGroup } from './PickerDialog';
import { WheelColumn } from './WheelColumn';
import { api } from '../lib/api';

interface DirectoryPlace {
  id: string;
  countryCode: string;
  nameEnglish: string;
  nameChinese?: string;
  nameThai?: string;
  timeZone: string;
  provinceId?: string;
  provinceNameEnglish?: string;
  labelChinese?: string;
  labelThai?: string;
}
interface DirectoryPage {
  items: DirectoryPlace[];
  total: number;
  resolved?: DirectoryPlace | null;
}
const localName = (place: DirectoryPlace, language: Language) =>
  (language === 'zh' ? place.nameChinese : language === 'th' ? place.nameThai : '') ||
  place.nameEnglish;

export function BirthplacePicker({
  value,
  timezone,
  language,
  t,
  onChange,
  locationId,
  countryCode,
}: {
  value: string;
  timezone: string;
  language: Language;
  t: Copy;
  onChange: (place: string, timezone: string, location?: DirectoryPlace) => void;
  locationId?: string | null;
  countryCode?: string | null;
}) {
  const [draft, setDraft] = useState<{
    country: string;
    city: string;
    custom: boolean;
    text: string;
    province: string;
    selected: DirectoryPlace | null;
    restoreId: string | null;
  } | null>(null);
  const [provinces, setProvinces] = useState<{ country: string; items: DirectoryPlace[] }>({
    country: '',
    items: [],
  });
  const [cities, setCities] = useState<{ scope: string; data: DirectoryPage }>({
    scope: '',
    data: { items: [], total: 0 },
  });
  const [search, setSearch] = useState('');
  const [offset, setOffset] = useState(0);
  const [provinceLoading, setProvinceLoading] = useState(false);
  const [cityLoading, setCityLoading] = useState(false);
  const [error, setError] = useState('');
  const [retry, setRetry] = useState(0);
  const found = findBirthplace(value);
  const country = BIRTH_COUNTRIES.find((item) => item.id === draft?.country) || BIRTH_COUNTRIES[0];
  const city = country.cities.find((item) => item.id === draft?.city) || country.cities[0];
  const regions = new Intl.DisplayNames([t.dateLocale], { type: 'region' });
  const directoryCountry =
    draft && !draft.custom && ['CN', 'TH'].includes(draft.country) ? draft.country : '';
  const province = draft?.province || '';
  const scope = `${directoryCountry}:${province}:${search}:${offset}`;
  const visibleCities = cities.scope === scope ? cities.data : { items: [], total: 0 };
  const selected = draft?.selected;
  const cityOptions =
    selected && !visibleCities.items.some((row) => row.id === selected.id)
      ? [selected, ...visibleCities.items]
      : visibleCities.items;

  useEffect(() => {
    if (!directoryCountry) return;
    const controller = new AbortController();
    setProvinceLoading(true);
    setError('');
    const timer = window.setTimeout(() => {
      void api<DirectoryPage>(`/api/thai-locations?country=${directoryCountry}&level=province`, {
        signal: controller.signal,
      })
        .then((data) => {
          if (!controller.signal.aborted)
            setProvinces({ country: directoryCountry, items: data.items });
        })
        .catch((cause: unknown) => {
          if (!controller.signal.aborted)
            setError(cause instanceof Error ? cause.message : String(cause));
        })
        .finally(() => {
          if (!controller.signal.aborted) setProvinceLoading(false);
        });
    }, 150);
    return () => {
      clearTimeout(timer);
      controller.abort();
    };
  }, [directoryCountry, retry]);

  useEffect(() => {
    if (!draft?.restoreId) return;
    const identifier = draft.restoreId;
    const controller = new AbortController();
    setError('');
    void api<DirectoryPage>(
      `/api/thai-locations?country=&level=detail&query=${encodeURIComponent(identifier)}`,
      { signal: controller.signal },
    )
      .then((data) => {
        if (controller.signal.aborted) return;
        if (!data.resolved) throw new Error(t.noBirthCities);
        const place = data.resolved;
        setDraft((current) =>
          current?.restoreId === identifier
            ? {
                ...current,
                country: place.countryCode,
                province: place.provinceId || '',
                city: place.id,
                selected: place,
                restoreId: null,
              }
            : current,
        );
      })
      .catch((cause: unknown) => {
        if (!controller.signal.aborted)
          setError(cause instanceof Error ? cause.message : String(cause));
      });
    return () => controller.abort();
  }, [draft?.restoreId, retry, t.noBirthCities]);

  useEffect(() => {
    if (!directoryCountry || draft?.restoreId) return;
    const controller = new AbortController();
    setCityLoading(true);
    setError('');
    const timer = window.setTimeout(() => {
      const params = new URLSearchParams({
        country: directoryCountry,
        province,
        level: 'locality',
        query: search.trim(),
        offset: String(offset),
      });
      void api<DirectoryPage>(`/api/thai-locations?${params}`, { signal: controller.signal })
        .then((data) => {
          if (controller.signal.aborted) return;
          setCities({ scope, data });
          setDraft((current) => {
            if (
              !current ||
              current.country !== directoryCountry ||
              current.province !== province ||
              current.custom
            )
              return current;
            const next =
              current.selected ||
              data.items.find(
                (row) => row.id === current.city || row.nameEnglish === current.city,
              ) ||
              data.items[0] ||
              null;
            return { ...current, selected: next, city: next?.id || '' };
          });
        })
        .catch((cause: unknown) => {
          if (!controller.signal.aborted)
            setError(cause instanceof Error ? cause.message : String(cause));
        })
        .finally(() => {
          if (!controller.signal.aborted) setCityLoading(false);
        });
    }, 250);
    return () => {
      clearTimeout(timer);
      controller.abort();
    };
  }, [directoryCountry, province, search, offset, scope, draft?.restoreId, retry]);

  function changeScope(country: string, nextProvince = '') {
    setSearch('');
    setOffset(0);
    setError('');
    setDraft((current) =>
      current
        ? {
            ...current,
            country,
            province: nextProvince,
            city: BIRTH_COUNTRIES.find((row) => row.id === country)?.cities[0].id || '',
            selected: null,
            restoreId: null,
          }
        : current,
    );
  }
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
        onClick={() => {
          setSearch('');
          setOffset(0);
          setError('');
          setDraft({
            country: countryCode || found?.country.id || 'TH',
            city: found?.city.id || 'Bangkok',
            custom: !!value && !found && !locationId,
            text: value,
            province: '',
            selected: null,
            restoreId: locationId || null,
          });
        }}
      >
        <span className={`min-w-0 break-words ${value ? '' : 'text-muted'}`}>
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
          confirmDisabled={
            draft.custom
              ? !draft.text.trim()
              : !!draft.restoreId ||
                (!!directoryCountry && (provinceLoading || cityLoading || !selected || !!error))
          }
          onConfirm={() => {
            if (directoryCountry && selected) {
              const label =
                language === 'zh'
                  ? selected.labelChinese
                  : language === 'th'
                    ? selected.labelThai
                    : '';
              onChange(
                (
                  label ||
                  [selected.nameEnglish, selected.provinceNameEnglish, country.name]
                    .filter(Boolean)
                    .join(', ')
                ).slice(0, 100),
                selected.timeZone,
                selected,
              );
            } else
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
            <>
              {directoryCountry && (
                <label className="mb-4 block text-xs text-muted">
                  {t.searchBirthCity}
                  <input
                    className="field mt-2"
                    value={search}
                    maxLength={80}
                    onChange={(event) => {
                      setSearch(event.target.value);
                      setOffset(0);
                      setDraft({ ...draft, city: '', selected: null, restoreId: null });
                    }}
                  />
                </label>
              )}
              <WheelGroup>
                <WheelColumn
                  label={t.birthCountry}
                  value={country.id}
                  options={BIRTH_COUNTRIES.map((item) => ({
                    value: item.id,
                    label: regions.of(item.id) || item.name,
                  }))}
                  onChange={(id) => changeScope(id)}
                />
                {directoryCountry && (
                  <WheelColumn
                    label={t.birthProvince}
                    value={province}
                    options={[
                      { value: '', label: t.allBirthProvinces },
                      ...(provinces.country === directoryCountry ? provinces.items : []).map(
                        (row) => ({ value: row.id, label: localName(row, language) }),
                      ),
                    ]}
                    onChange={(id) => changeScope(draft.country, id)}
                  />
                )}
                <WheelColumn
                  label={t.birthplace}
                  value={directoryCountry ? draft.city : city.id}
                  options={
                    directoryCountry
                      ? cityOptions.map((row) => ({
                          value: row.id,
                          label: localName(row, language),
                        }))
                      : country.cities.map((item) => ({
                          value: item.id,
                          label: item.names[language],
                        }))
                  }
                  onChange={(id) =>
                    setDraft({
                      ...draft,
                      city: id,
                      selected: cityOptions.find((row) => row.id === id) || null,
                      restoreId: null,
                    })
                  }
                />
              </WheelGroup>
              {directoryCountry && (
                <div className="mt-3 text-xs leading-6 text-muted">
                  {provinceLoading || cityLoading || draft.restoreId ? (
                    <p role="status">{t.birthCitiesLoading}</p>
                  ) : error ? (
                    <div role="alert">
                      <p>{error}</p>
                      <button
                        type="button"
                        className="btn-quiet"
                        onClick={() => setRetry((value) => value + 1)}
                      >
                        {t.retry}
                      </button>
                    </div>
                  ) : (
                    <>
                      {!visibleCities.total && <p>{t.noBirthCities}</p>}
                      {selected && (
                        <p className="break-words text-gold/90">
                          {(language === 'zh'
                            ? selected.labelChinese
                            : language === 'th'
                              ? selected.labelThai
                              : '') ||
                            [selected.provinceNameEnglish, selected.nameEnglish]
                              .filter(Boolean)
                              .join(' · ')}
                        </p>
                      )}
                      {!!visibleCities.total && (
                        <div className="mt-2 flex items-center justify-between gap-2">
                          <button
                            type="button"
                            className="btn-quiet !px-2"
                            disabled={!offset}
                            onClick={() => {
                              setOffset((value) => Math.max(0, value - 100));
                              setDraft({ ...draft, selected: null, city: '' });
                            }}
                          >
                            {t.previousCityPage}
                          </button>
                          <span className="tabular-nums">
                            {Math.floor(offset / 100) + 1} / {Math.ceil(visibleCities.total / 100)}
                          </span>
                          <button
                            type="button"
                            className="btn-quiet !px-2"
                            disabled={offset + 100 >= visibleCities.total}
                            onClick={() => {
                              setOffset((value) => value + 100);
                              setDraft({ ...draft, selected: null, city: '' });
                            }}
                          >
                            {t.nextCityPage}
                          </button>
                        </div>
                      )}
                    </>
                  )}
                </div>
              )}
            </>
          )}
          <button
            type="button"
            className="btn-quiet mt-3 w-full !text-xs"
            onClick={() => {
              setError('');
              setDraft({ ...draft, custom: !draft.custom, restoreId: null });
            }}
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
