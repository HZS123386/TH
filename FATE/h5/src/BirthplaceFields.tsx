import { useEffect, useState } from 'react';
import { api, type Place, type Region } from './api';
import { copy, type Language } from './copy';

type Choice = { id: string; label: string; detail?: string };

function Picker({ id, label, value, placeholder, options, disabled, hint, onEdit, onPick, onBrowse }: {
  id: string; label: string; value: string; placeholder: string; options: Choice[];
  disabled?: boolean; hint?: string; onEdit: (value: string) => void;
  onPick: (id: string) => void; onBrowse?: (open: boolean) => void;
}) {
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState(-1);
  const expanded = open && !disabled;

  function browse(next: boolean) {
    setOpen(next);
    setActive(-1);
    onBrowse?.(next);
  }

  function pick(choice: Choice) {
    onPick(choice.id);
    browse(false);
  }

  return <div className="place-field" onBlur={event => {
    if (!event.currentTarget.contains(event.relatedTarget)) browse(false);
  }}>
    <label htmlFor={id}>{id === 'birth-country' && <span className="field-icon" aria-hidden="true">⌖</span>}{label}</label>
    <div className="place-control">
      <input id={id} type="text" role="combobox" aria-autocomplete="list" aria-expanded={expanded}
        aria-controls={expanded && options.length ? `${id}-options` : undefined}
        aria-activedescendant={expanded && options[active] ? `${id}-option-${active}` : undefined}
        value={value} placeholder={placeholder} disabled={disabled} autoComplete="off" maxLength={80}
        onFocus={() => browse(true)} onChange={event => { onEdit(event.target.value); browse(true); }}
        onKeyDown={event => {
          if (event.key === 'Escape' && expanded) { event.preventDefault(); browse(false); }
          if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
            event.preventDefault();
            if (!expanded) browse(true);
            const next = event.key === 'ArrowDown' ? active + 1 : active <= 0 ? options.length - 1 : active - 1;
            if (options.length) {
              const index = next % options.length;
              setActive(index);
              document.getElementById(`${id}-option-${index}`)?.scrollIntoView({ block: 'nearest' });
            }
          }
          if (event.key === 'Enter' && expanded && options.length) {
            event.preventDefault();
            pick(options[Math.max(0, active)]);
          }
        }} />
      <button className="place-chevron" type="button" disabled={disabled} aria-label={label}
        aria-expanded={expanded} onClick={() => browse(!expanded)}><span aria-hidden="true">⌄</span></button>
    </div>
    {expanded && (options.length > 0 ? <div className="suggestions" role="listbox" id={`${id}-options`} aria-label={label}>
      {options.map((option, index) => <button type="button" role="option" aria-selected={active === index}
        id={`${id}-option-${index}`} key={option.id} onClick={() => pick(option)}>
        <span>{option.label}</span>{option.detail && <small>{option.detail}</small>}
      </button>)}
    </div> : hint && <p className="place-hint">{hint}</p>)}
  </div>;
}

function locationName(place: Place | Region, language: Language) {
  return language === 'zh' ? place.name_zh || place.name : place.name_th || place.name;
}

function matches(text: string, ...names: (string | undefined)[]) {
  const query = text.normalize('NFKC').trim().toLowerCase();
  return names.some(name => name?.normalize('NFKC').toLowerCase().includes(query));
}

export function BirthplaceFields({ language, place, setPlace }: {
  language: Language; place: Place | null; setPlace: (place: Place | null) => void;
}) {
  const text = copy[language];
  const [country, setCountry] = useState('');
  const [countryQuery, setCountryQuery] = useState('');
  const [regions, setRegions] = useState<Region[]>([]);
  const [region, setRegion] = useState<Region | null>(null);
  const [regionQuery, setRegionQuery] = useState('');
  const [regionError, setRegionError] = useState(false);
  const [regionRetry, setRegionRetry] = useState(0);
  const [cityQuery, setCityQuery] = useState('');
  const [cityOptions, setCityOptions] = useState<Place[]>([]);
  const [cityOpen, setCityOpen] = useState(false);
  const [cityError, setCityError] = useState(false);
  const hasRegions = country === 'CN' || country === 'TH';
  const canSearchCity = country === 'global' || Boolean(region);
  const countryOptions = [
    { id: 'CN', label: text.china, names: ['中国', '中國', 'China', 'จีน', 'CN'] },
    { id: 'TH', label: text.thailand, names: ['泰国', '泰國', 'Thailand', 'ไทย', 'TH'] },
    { id: 'global', label: text.globalCities, names: ['world', 'global', text.globalCities] },
  ];

  useEffect(() => {
    if (country !== 'CN' && country !== 'TH') return;
    const abort = new AbortController();
    setRegionError(false);
    api<Region[]>('/locations/regions?country=' + country, { signal: abort.signal })
      .then(rows => { if (!abort.signal.aborted) setRegions(rows); })
      .catch(() => { if (!abort.signal.aborted) setRegionError(true); });
    return () => abort.abort();
  }, [country, regionRetry]);

  useEffect(() => {
    if (!cityOpen || !canSearchCity) return;
    const abort = new AbortController();
    setCityError(false);
    const timer = window.setTimeout(() => {
      const params = new URLSearchParams({ q: cityQuery });
      if (region) {
        params.set('country', country);
        params.set('region', region.id);
      }
      api<Place[]>('/locations?' + params, { signal: abort.signal })
        .then(rows => { if (!abort.signal.aborted) setCityOptions(rows); })
        .catch(() => { if (!abort.signal.aborted) setCityError(true); });
    }, 180);
    return () => { clearTimeout(timer); abort.abort(); };
  }, [cityOpen, canSearchCity, cityQuery, country, region]);

  function clearCity() {
    setPlace(null);
    setCityQuery('');
    setCityOptions([]);
    setCityOpen(false);
    setCityError(false);
  }

  function changeCountry(next: string) {
    if (next === country) return;
    setCountry(next);
    setRegions([]);
    setRegion(null);
    setRegionQuery('');
    setRegionError(false);
    clearCity();
  }

  return <div className="birthplace">
    <Picker id="birth-country" label={text.country} value={countryOptions.find(item => item.id === country)?.label ?? countryQuery}
      placeholder={text.countryPrompt} options={countryOptions.filter(item => matches(countryQuery, ...item.names))}
      onEdit={value => { setCountryQuery(value); changeCountry(''); }}
      onPick={id => { setCountryQuery(''); changeCountry(id); }} />
    <div className="birthplace-row">
      <div>
        <Picker id="birth-region" label={text.region} value={region ? locationName(region, language) : regionQuery}
          placeholder={!hasRegions ? text.countryFirst : !regions.length && !regionError ? text.regionPending : country === 'TH' ? text.thaiRegionPrompt : text.regionPrompt}
          disabled={!hasRegions || !regions.length}
          options={regions.filter(item => matches(regionQuery, item.name, item.name_zh, item.name_th))
            .map(item => ({ id: item.id, label: locationName(item, language) }))}
          onEdit={value => { setRegionQuery(value); setRegion(null); clearCity(); }}
          onPick={id => { setRegionQuery(''); setRegion(regions.find(item => item.id === id) ?? null); clearCity(); }} />
        {regionError && <button type="button" className="region-retry" onClick={() => setRegionRetry(count => count + 1)}>{text.regionRetry}</button>}
      </div>
      <Picker id="birth-city" label={text.city} value={place ? locationName(place, language) : cityQuery}
        placeholder={canSearchCity ? country === 'CN' ? text.cityExample : text.citySearch : country ? text.regionFirst : text.countryFirst}
        disabled={!canSearchCity} hint={cityError ? text.cityError : text.cityHint} onBrowse={setCityOpen}
        options={cityOptions.map(item => ({ id: item.id, label: locationName(item, language), detail: item.name }))}
        onEdit={value => { setPlace(null); setCityOptions([]); setCityQuery(value); }}
        onPick={id => { setPlace(cityOptions.find(item => item.id === id) ?? null); setCityQuery(''); }} />
    </div>
    <p className="place-hint">{text.placeHint}</p>
  </div>;
}
