import { useEffect, useState, type KeyboardEvent } from "react";
import { ChevronDown, MapPin } from "lucide-react";
import { api, placeName, ui, type Language, type Place } from "../lib/reading";

const normalize = (value: string) => value.normalize("NFKD").replace(/[\u0300-\u036f\s\p{P}]/gu, "").toLowerCase();
const countryAliases = {
  CN: ["中国", "中國", "中华人民共和国", "China", "CN", "จีน", "ประเทศจีน"],
  TH: ["泰国", "泰國", "Thailand", "TH", "ไทย", "ประเทศไทย"],
};
function countryCode(value: string) {
  return (Object.keys(countryAliases) as (keyof typeof countryAliases)[])
    .find(code => countryAliases[code].some(alias => normalize(alias) === normalize(value))) || "";
}
const localName = (place: Place, language: Language) =>
  (language === "zh" ? place.nameChinese : place.nameThai) || place.nameEnglish;
const provinceName = (place: Place, language: Language) =>
  (language === "zh" ? place.provinceNameChinese : place.provinceNameThai) || place.provinceNameEnglish || "";
type Field = "country" | "province" | "city";
const matchesName = (place: Place, query: string) =>
  [place.nameChinese, place.nameThai, place.nameEnglish, ...(place.aliases || [])]
    .some(name => name && normalize(name).includes(normalize(query)));

function BirthplaceInput({ field, label, text, placeholder, disabled, valid, expanded, active, language, onChange, onOpen, onKeyDown }: {
  field: Field; label: string; text: string; placeholder: string; disabled?: boolean; valid: boolean;
  expanded: boolean; active?: string; language: Language;
  onChange: (text: string) => void; onOpen: () => void; onKeyDown: (event: KeyboardEvent) => void;
}) {
  return <div className="min-w-0">
    <label className={`field-label ${field === "country" ? "" : "!mb-2 !mt-0"}`} htmlFor={`birth-${field}`}>
      {field === "country" && <span className="field-icon" aria-hidden="true">⌖</span>}{label}
    </label>
    <div className="relative">
      <input id={`birth-${field}`} type="text" role="combobox" aria-autocomplete="list" aria-haspopup="listbox"
        aria-controls={`birth-${field}-options`} aria-expanded={expanded} aria-activedescendant={active}
        value={text} maxLength={80} className="!min-w-0 !pr-10" autoComplete="off" required disabled={disabled}
        data-location-valid={valid} placeholder={placeholder} aria-describedby="birth-place-hint"
        onChange={event => onChange(event.target.value)} onClick={onOpen} onKeyDown={onKeyDown} />
      <button type="button" disabled={disabled} aria-label={language === "zh" ? `选择${label}` : `เลือก${label}`}
        aria-haspopup="listbox" aria-expanded={expanded} aria-controls={`birth-${field}-options`}
        className="absolute inset-y-0 right-0 flex w-10 items-center justify-center rounded-r-lg border-0 bg-transparent p-0 text-gold"
        onClick={onOpen} onKeyDown={onKeyDown}><ChevronDown size={17} aria-hidden="true" /></button>
    </div>
  </div>;
}

export function BirthplaceFields({ language, value, onChange }: {
  language: Language;
  value: Place | null;
  onChange: (place: Place | null) => void;
}) {
  const c = ui[language];
  const [countryText, setCountryText] = useState("");
  const [provinceText, setProvinceText] = useState("");
  const [cityText, setCityText] = useState("");
  const [regions, setRegions] = useState<Place[]>([]);
  const [cities, setCities] = useState<Place[]>([]);
  const [total, setTotal] = useState(0);
  const [offset, setOffset] = useState(0);
  const [regionBusy, setRegionBusy] = useState(false);
  const [cityBusy, setCityBusy] = useState(false);
  const [regionError, setRegionError] = useState(false);
  const [cityError, setCityError] = useState(false);
  const [lookup, setLookup] = useState(0);
  const [menu, setMenu] = useState<Field | null>(null);
  const [filterMenu, setFilterMenu] = useState(false);
  const [browseCities, setBrowseCities] = useState(false);
  const [activeOption, setActiveOption] = useState(0);
  const country = countryCode(countryText);
  const matching = regions.filter(row => row.countryCode === country &&
    [row.nameChinese, row.nameThai, row.nameEnglish, ...(row.aliases || [])]
      .some(name => name && normalize(name) === normalize(provinceText)));
  const province = matching.length === 1 ? matching[0] : null;

  // Restoring a report also restores all three fields; older snapshots are enriched by ID.
  useEffect(() => {
    setCities([]); setTotal(0); setOffset(0); setBrowseCities(false);
    setMenu(null); setActiveOption(0); setCityError(false);
    if (!value) return;
    setCountryText(ui[language].countryNames[value.countryCode as "CN" | "TH"] || value.countryCode);
    setCityText(localName(value, language));
    setProvinceText(provinceName(value, language));
    if (value.provinceId) return;
    const controller = new AbortController();
    void api<{ resolved?: Place | null }>(`/api/thai-locations?country=${value.countryCode}&level=detail&query=${encodeURIComponent(value.id)}`, language, controller.signal)
      .then(data => { if (!controller.signal.aborted && data.resolved) setProvinceText(provinceName(data.resolved, language)); })
      .catch(() => { /* The saved report remains readable if its location cannot be enriched. */ });
    return () => controller.abort();
  }, [value?.id, language]);

  useEffect(() => {
    if (menu) document.getElementById(`birth-${menu}-option-${activeOption}`)?.scrollIntoView({ block: "nearest" });
  }, [menu, activeOption]);

  useEffect(() => {
    setRegions([]);
    setRegionError(false);
    if (!country) { setRegionBusy(false); return; }
    const controller = new AbortController();
    setRegionBusy(true);
    void api<{ items: Place[] }>(`/api/thai-locations?country=${country}&level=province`, language, controller.signal)
      .then(data => { if (!controller.signal.aborted) setRegions(data.items); })
      .catch(() => { if (!controller.signal.aborted) setRegionError(true); })
      .finally(() => { if (!controller.signal.aborted) setRegionBusy(false); });
    return () => controller.abort();
  }, [country, language, lookup]);

  useEffect(() => {
    if (!province || (!browseCities && (!cityText.trim() || value))) { setCityBusy(false); return; }
    const controller = new AbortController();
    setCityBusy(true);
    setCityError(false);
    const timer = window.setTimeout(() => {
      const params = new URLSearchParams({ country, province: province.id, level: "locality", query: browseCities ? "" : cityText.trim(), offset: String(offset) });
      void api<{ items: Place[]; total: number; resolved?: Place | null }>(`/api/thai-locations?${params}`, language, controller.signal)
        .then(data => {
          if (controller.signal.aborted) return;
          setCities(current => offset ? [...current, ...data.items] : data.items);
          setTotal(data.total);
          if (!offset) setActiveOption(0);
          if (!browseCities && data.resolved) onChange(data.resolved);
        })
        .catch(() => { if (!controller.signal.aborted) setCityError(true); })
        .finally(() => { if (!controller.signal.aborted) setCityBusy(false); });
    }, 300);
    return () => { clearTimeout(timer); controller.abort(); };
  }, [country, province?.id, cityText, offset, language, lookup, value, browseCities]);

  function clearCity() {
    setCityText(""); setCities([]); setTotal(0); setOffset(0);
    setBrowseCities(false); setMenu(null); setCityError(false); onChange(null);
  }
  function chooseCity(row: Place) {
    setCityText(localName(row, language)); setBrowseCities(false); setMenu(null); onChange(row);
  }
  const countryOptions = (["CN", "TH"] as const).filter(code => !filterMenu || countryAliases[code].some(alias => normalize(alias).includes(normalize(countryText))))
    .map(code => ({ id: code, label: c.countryNames[code], detail: code, choose: () => {
      setCountryText(c.countryNames[code]);
      if (country !== code) { setProvinceText(""); clearCity(); }
      setMenu(null);
    } }));
  const provinceOptions = regions.filter(row => row.countryCode === country && (!filterMenu || matchesName(row, provinceText)))
    .map(row => ({ id: row.id, label: localName(row, language), detail: row.nameEnglish, choose: () => {
      setProvinceText(localName(row, language));
      if (province?.id !== row.id) clearCity();
      setMenu(null);
    } }));
  const cityOptions = cities.map(row => ({ id: row.id, label: placeName(row, language), detail: row.coordinateKind === "administrative-area" ? c.areaLabel : c.cityLabel, choose: () => chooseCity(row) }));
  const options = menu === "country" ? countryOptions : menu === "province" ? provinceOptions : cityOptions;
  function openMenu(field: Field) {
    setMenu(current => current === field ? null : field); setFilterMenu(false); setActiveOption(0);
    if (field === "city" && !browseCities) { setBrowseCities(true); setCities([]); setOffset(0); }
  }
  function handleKey(event: KeyboardEvent, field: Field) {
    if (event.key === "Escape") { setMenu(null); return; }
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault();
      if (menu !== field) { openMenu(field); return; }
      if (options.length) setActiveOption(current => (current + (event.key === "ArrowDown" ? 1 : -1) + options.length) % options.length);
    }
    if (event.key === "Enter" && menu === field) {
      event.preventDefault(); options[activeOption]?.choose();
    }
  }
  const list = (field: Field) => menu === field && options.length > 0 && <div id={`birth-${field}-options`} role="listbox" aria-label={field === "city" ? c.chooseCity : field === "country" ? c.country : c.province}
    className="mt-2 max-h-56 overflow-y-auto rounded-lg border border-solid border-gold/25 bg-night">
    {options.map((option, index) => <button key={option.id} id={`birth-${field}-option-${index}`} type="button" role="option" aria-selected={activeOption === index}
      data-place-id={field === "city" ? option.id : undefined} data-region-id={field === "province" ? option.id : undefined}
      className={`block w-full border-0 px-3 py-3 text-left text-xs leading-6 ${activeOption === index ? "bg-gold/15 text-gold" : "bg-transparent text-cream"}`}
      onMouseEnter={() => setActiveOption(index)} onClick={option.choose}>{option.label}<span className="ml-2 text-[10px] text-lavender">{option.detail}</span></button>)}
  </div>;
  const inputProps = (field: Field) => ({ field, language, expanded: menu === field && options.length > 0,
    active: menu === field && options[activeOption] ? `birth-${field}-option-${activeOption}` : undefined,
    onOpen: () => openMenu(field), onKeyDown: (event: KeyboardEvent) => handleKey(event, field) });
  return (
    <div onBlur={event => { if (!event.currentTarget.contains(event.relatedTarget)) setMenu(null); }}>
      <BirthplaceInput {...inputProps("country")} label={c.country} text={countryText} placeholder={c.countryPlaceholder} valid={Boolean(country)}
        onChange={next => {
          setCountryText(next);
          if (countryCode(next) !== country) { setProvinceText(""); clearCity(); }
          setMenu("country"); setFilterMenu(true); setActiveOption(0);
        }} />
      {list("country")}
      <div className="mt-4 grid grid-cols-2 gap-3">
        <BirthplaceInput {...inputProps("province")} label={c.province} text={provinceText} disabled={!country || regionBusy} valid={Boolean(province)}
          placeholder={!country ? c.countryFirst : country === "TH" ? c.thaiProvincePlaceholder : c.provincePlaceholder}
          onChange={next => { setProvinceText(next); clearCity(); setMenu("province"); setFilterMenu(true); setActiveOption(0); }} />
        <BirthplaceInput {...inputProps("city")} label={c.city} text={cityText} disabled={!province} valid={Boolean(value)}
          placeholder={!province ? c.provinceFirst : country === "TH" ? c.thaiCityPlaceholder : c.cityPlaceholder}
          onChange={next => {
            setCityText(next); setCities([]); setTotal(0); setOffset(0); setBrowseCities(false);
            setMenu("city"); setFilterMenu(true); setActiveOption(0); setCityError(false); onChange(null);
          }} />
      </div>
      {list("province")}
      {list("city")}
      <div className="mt-2">
        <p className="time-note" id="birth-place-hint">{c.placeHint}</p>
        {countryText.trim() && !country && <p className="time-note">{c.invalidCountry}</p>}
        {provinceText.trim() && country && !regionBusy && !regionError && !province && <p className="time-note">{c.invalidProvince}</p>}
        {(regionBusy || cityBusy) && <p className="time-note" role="status">{c.searching}</p>}
        {menu === "city" && cities.length < total && <button type="button" className="report-secondary mt-2" disabled={cityBusy} onClick={() => { document.getElementById("birth-city")?.focus(); setOffset(cities.length); }}>{c.morePlaces}</button>}
        {province && cityText.trim() && !value && !cityBusy && !cityError && !cities.length && <p className="time-note">{c.noCity}</p>}
        {(regionError || cityError) && <p className="time-note" role="status">{c.locationError}{" "}<button type="button" className="bg-transparent p-1 text-gold underline" onClick={() => setLookup(current => current + 1)}>{c.retryPlaces}</button></p>}
        {value && <p className="mt-2 flex items-start gap-1 rounded-lg border border-solid border-gold/25 bg-gold/5 p-3 text-[11px] leading-6 text-gold" role="status" data-testid="detected-birthplace"><MapPin size={11} />{c.selectedPlace} · {placeName(value, language)}</p>}
        {value?.coordinateKind === "administrative-area" && <p className="time-note">{c.areaNote}</p>}
        {value?.placeType === "province" && <p className="time-note">{c.provinceNote}</p>}
      </div>
    </div>
  );
}
