import { useEffect, useState } from 'react';
import type { AstrologyLocation } from 'thai-astrology';
import { MapPin } from 'lucide-react';
import { api } from '../lib/api';
import type { Copy } from '../lib/i18n';
import type { Profile } from '../types';

export function ThaiLocationInput({
  profile,
  t,
  onChange,
}: {
  profile: Profile;
  t: Copy;
  onChange: (patch: Partial<Profile>) => void;
}) {
  const [country, setCountry] = useState(profile.country_code || 'TH');
  const [query, setQuery] = useState('');
  const [places, setPlaces] = useState<AstrologyLocation[]>([]);
  const [error, setError] = useState('');
  const [manual, setManual] = useState(profile.latitude != null);
  const [expanded, setExpanded] = useState(!!profile.location_id || profile.latitude != null);
  useEffect(() => {
    if (!expanded) return;
    const controller = new AbortController();
    const timer = window.setTimeout(() => {
      setError('');
      void api<{ items: AstrologyLocation[] }>(
        `/api/thai-locations?country=${country}&query=${encodeURIComponent(query)}`,
        { signal: controller.signal },
      )
        .then((data) => {
          if (!controller.signal.aborted) setPlaces(data.items);
        })
        .catch((cause: unknown) => {
          if (!controller.signal.aborted)
            setError(cause instanceof Error ? cause.message : String(cause));
        });
    }, 250);
    return () => {
      clearTimeout(timer);
      controller.abort();
    };
  }, [country, query, expanded]);
  const selected = places.find((place) => place.id === profile.location_id);
  return (
    <details
      className="rounded-xl border border-line bg-canvas p-5"
      open={expanded}
      onToggle={(event) => setExpanded(event.currentTarget.open)}
    >
      <summary className="cursor-pointer text-sm text-accent">{t.th_locationTitle}</summary>
      <p className="mb-5 mt-3 text-xs leading-6 text-muted">{t.th_locationHint}</p>
      <div className="grid gap-3 sm:grid-cols-2">
        <label className="text-xs text-muted">
          {t.birthCountry}
          <select
            className="field mt-2"
            value={country}
            onChange={(event) => {
              setCountry(event.target.value);
              setQuery('');
            }}
          >
            {['TH', 'CN', 'VN', 'US'].map((code) => (
              <option key={code} value={code}>
                {new Intl.DisplayNames([t.dateLocale], { type: 'region' }).of(code)}
              </option>
            ))}
          </select>
        </label>
        <label className="text-xs text-muted">
          {t.th_locationSearch}
          <input
            className="field mt-2"
            value={query}
            maxLength={80}
            onChange={(event) => setQuery(event.target.value)}
          />
        </label>
      </div>
      <label className="mt-4 block text-xs text-muted" htmlFor="thai-location">
        {t.th_catalogPlace}
      </label>
      <select
        id="thai-location"
        className="field mt-2"
        value={profile.location_id || ''}
        onChange={(event) => {
          const place = places.find((row) => row.id === event.target.value);
          if (place)
            onChange({
              country_code: place.countryCode,
              location_id: place.id,
              latitude: null,
              longitude: null,
              timezone: place.timeZone,
              birthplace: `${place.nameEnglish}, ${new Intl.DisplayNames(['en'], { type: 'region' }).of(place.countryCode)}`,
            });
          else onChange({ country_code: null, location_id: null });
        }}
      >
        <option value="">{t.choose}</option>
        {profile.location_id && !selected && (
          <option value={profile.location_id}>{profile.birthplace}</option>
        )}
        {places.map((place) => (
          <option key={place.id} value={place.id}>
            {t.dateLocale.startsWith('th')
              ? place.nameThai || place.nameEnglish
              : `${place.nameEnglish}${place.nameThai ? ` · ${place.nameThai}` : ''}`}
          </option>
        ))}
      </select>
      {selected && (
        <p className="mt-3 flex items-center gap-2 text-xs text-muted">
          <MapPin size={13} />
          {selected.latitude}, {selected.longitude} · {selected.timeZone}
        </p>
      )}
      {error && (
        <p role="alert" className="mt-3 text-xs text-accent">
          {error}
        </p>
      )}
      <label className="mt-5 flex items-start gap-2 text-xs leading-6 text-muted">
        <input
          type="checkbox"
          className="mt-1 accent-primary"
          checked={manual}
          onChange={(event) => {
            setManual(event.target.checked);
            if (!event.target.checked) onChange({ latitude: null, longitude: null });
          }}
        />
        {t.th_manualCoords}
      </label>
      {manual && (
        <>
          <div className="mt-4 grid grid-cols-2 gap-3">
            <label className="text-xs text-muted">
              {t.th_latitude}
              <input
                className="field mt-2"
                type="number"
                step="any"
                min="-90"
                max="90"
                value={profile.latitude ?? ''}
                onChange={(event) =>
                  onChange({
                    latitude: event.target.value === '' ? null : Number(event.target.value),
                  })
                }
              />
            </label>
            <label className="text-xs text-muted">
              {t.th_longitude}
              <input
                className="field mt-2"
                type="number"
                step="any"
                min="-180"
                max="180"
                value={profile.longitude ?? ''}
                onChange={(event) =>
                  onChange({
                    longitude: event.target.value === '' ? null : Number(event.target.value),
                  })
                }
              />
            </label>
          </div>
          <p className="mt-3 text-xs leading-6 text-muted">{t.th_coordsNote}</p>
        </>
      )}
      <p className="mt-4 text-[10px] leading-5 text-muted">
        GeoNames · CC BY 4.0 · {t.th_seatNote}
      </p>
    </details>
  );
}
