import { readFileSync } from 'node:fs';
import { calculateFortune } from './thai-fortune.mjs';
import { indexedLocation, recognizeBirthplace, searchBirthCities } from './birth-locations.mjs';
import { fileURLToPath } from 'node:url';
import {
  calculateThaiHoroscope,
  calculateHoroscopeTransits,
  searchThaiAstrologyLocations,
} from 'thai-astrology';

export const ENGINE = {
  name: 'thai-astrology',
  version: '0.3.2',
  source: 'https://github.com/kongesque/thai-astrology',
  commit: '445577e7cbc8c09ddc98f2ec016cd3d1e32940fb',
  rules: 'wanjai-suriyayatra-1',
  houseSystem: 'whole-sign',
  weekdayBoundary: '06:00',
  planetaryFrameSeconds: 24124,
};
const countries = ['TH', 'CN', 'VN', 'US'];
const birthRegions = JSON.parse(readFileSync(new URL('../backend/content/birth-regions.json', import.meta.url), 'utf8')).items;
function catalog(countryCode) {
  const rows = [];
  for (let offset = 0; offset < 5000; offset += 100) {
    const page = searchThaiAstrologyLocations({ countryCode, limit: 100, offset });
    rows.push(...page.items);
    if (rows.length >= page.total) break;
  }
  const byId = new Map(rows.map(row => [row.id, row]));
  for (const region of birthRegions.filter(row => row.countryCode === countryCode)) {
    const city = byId.get(region.id);
    byId.set(region.id, city ? { ...city, nameChinese: region.nameChinese } : region);
  }
  return [...byId.values()];
}
const searchText = text => String(text || '').normalize('NFKD').replace(/[\u0300-\u036f\s\p{P}]/gu, '').toLowerCase();
function searchLocations(request) {
  const country = request.country || 'TH';
  const query = searchText(request.query);
  const rows = request.level === 'province'
    ? birthRegions.filter(row => row.countryCode === country)
    : catalog(country);
  const matched = rows.filter(row => [row.nameEnglish, row.nameChinese, row.nameThai, row.province, ...(row.aliases || [])]
    .some(name => searchText(name).includes(query)));
  const offset = request.offset || 0;
  return { items: matched.slice(offset, offset + 100), total: matched.length };
}
function findLocation(profile) {
  if (Number.isFinite(profile.latitude) && Number.isFinite(profile.longitude))
    return {
      latitude: profile.latitude,
      longitude: profile.longitude,
      timeZone: profile.timezone,
      coordinateKind: 'user-supplied',
      nameEnglish: profile.birthplace,
    };
  const country = profile.country_code;
  const rows = (country ? [country] : countries).flatMap(catalog);
  if (profile.location_id) return indexedLocation(profile.location_id, country) || rows.find((row) => row.id === profile.location_id) || null;
  const text = String(profile.birthplace || '')
    .split(',')[0]
    .trim()
    .toLocaleLowerCase();
  const matches = rows.filter((row) =>
    [row.nameEnglish, row.nameChinese, row.nameThai, row.province].some(
      (name) => name?.toLocaleLowerCase() === text,
    ),
  );
  return matches.length === 1 ? matches[0] : null;
}
function civil(date, time) {
  const [year, month, day] = date.split('-').map(Number);
  const [hour, minute] = time.split(':').map(Number);
  return { date: { year, month, day, era: 'CE' }, time: { hour, minute } };
}
function inputFor(profile, offset) {
  const location = findLocation(profile);
  if (!location) return { location: null, input: null };
  return {
    location,
    input: {
      ...civil(profile.birth_date, profile.birth_time),
      ascendantReference: {
        method: 'sunrise',
        latitude: location.latitude,
        longitude: location.longitude,
        utcOffsetHours: offset / 3600,
        timePrecision: 'minute',
      },
      planetaryTimeReference: {
        civilUtcOffsetSeconds: offset,
        referenceUtcOffsetSeconds: ENGINE.planetaryFrameSeconds,
      },
    },
  };
}
export function calculateProfile(profile, offset) {
  const known = !!profile.birth_time;
  const first = calculateThaiHoroscope({
    ...civil(profile.birth_date, known ? profile.birth_time : '00:00'),
    referenceMode: 'traditional',
  });
  const last =
    !known &&
    calculateThaiHoroscope({ ...civil(profile.birth_date, '23:59'), referenceMode: 'traditional' });
  const lunar = first.calendar.thaiLunarDate;
  const stableLunar =
    known || JSON.stringify(lunar) === JSON.stringify(last.calendar.thaiLunarDate);
  const base = {
    engine: ENGINE,
    calendar: {
      civilWeekday: first.calendar.civilWeekday,
      astrologicalWeekday: known ? first.calendar.astrologicalWeekday : null,
      thaiLunarDate: stableLunar ? lunar : null,
    },
    taksa: known ? first.taksa : null,
    chart: null,
    location: null,
    time_known: known,
  };
  if (!known) return { ...base, status: 'time-unknown', required: ['birth_time'] };
  const { location, input } = inputFor(profile, offset);
  if (!input) return { ...base, status: 'location-required', required: ['location'] };
  const chart = calculateThaiHoroscope(input);
  return {
    ...base,
    calendar: chart.calendar,
    taksa: chart.taksa,
    status: 'ready',
    location,
    chart,
    required: [],
  };
}
export function calculateCurrentTransits(profile, offset, now) {
  if (!profile.birth_time) return { status: 'time-unknown', engine: ENGINE };
  const { input } = inputFor(profile, offset);
  if (!input) return { status: 'location-required', engine: ENGINE };
  const result = calculateHoroscopeTransits(input, {
    ...civil(now.date, now.time),
    location: { province: 'กรุงเทพมหานคร' },
  });
  return {
    status: 'ready',
    engine: ENGINE,
    calculated_at: now.iso,
    transit_location: 'Bangkok, Thailand',
    transit: result.transit,
    comparison: result.comparison,
  };
}

// Daily Bangkok-noon samples of classical longitudes, relative to the actual
// natal ascendant. Counts describe sampling, never event probabilities.
function transitSample(date, ascendant, keys) {
  const chart = calculateThaiHoroscope({
    ...civil(date, '12:00'),
    location: { province: 'กรุงเทพมหานคร' },
  });
  return keys.map((key) => {
    const sign = chart.points[key].sign;
    return { key, sign, house: ((sign - ascendant + 12) % 12) + 1 };
  });
}

export function calculateAnnual(year, ascendant) {
  const keys = ['sun', 'mercury', 'venus', 'mars', 'jupiter', 'saturn', 'rahu', 'ketu', 'uranus'];
  return Array.from({ length: 12 }, (_, index) => {
    const days = new Date(Date.UTC(year, index + 1, 0)).getUTCDate();
    const states = Object.fromEntries(keys.map((key) => [key, []]));
    for (let day = 1; day <= days; day++) {
      const date = `${year}-${String(index + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
      for (const { key, sign, house } of transitSample(date, ascendant, keys)) {
        const prior = states[key].find((state) => state.sign === sign);
        if (prior) prior.samples++;
        else states[key].push({ sign, house, samples: 1 });
      }
    }
    return { year, month: index + 1, days, sampling: 'daily-noon-Asia/Bangkok', states };
  });
}

function calculateCareerWindow(start, ascendant) {
  const date = new Date(`${start}T00:00:00Z`);
  const keys = ['mercury', 'jupiter', 'saturn'];
  const windows = Object.fromEntries(keys.map((key) => [key, []]));
  for (let day = 0; day < 30; day++, date.setUTCDate(date.getUTCDate() + 1)) {
    const sampleDate = date.toISOString().slice(0, 10);
    for (const { key, sign, house } of transitSample(sampleDate, ascendant, keys)) {
      const prior = windows[key].at(-1);
      if (prior?.sign === sign) prior.end = sampleDate;
      else windows[key].push({ key, sign, house, start: sampleDate, end: sampleDate });
    }
  }
  return windows;
}

export function dispatch(request) {
  if (request.operation === 'annual') return calculateAnnual(request.year, request.ascendant);
  if (request.operation === 'career-window') return calculateCareerWindow(request.start, request.ascendant);
  if (request.operation === 'fortune') {
    const natal =
      request.profile.birth_time && request.birth_window.length === 1
        ? calculateProfile(request.profile, request.birth_window[0].offset_seconds)
        : null;
    return calculateFortune(request, ENGINE, natal);
  }
  if (request.operation === 'locations') {
    if (request.level === 'detail') {
      const place = indexedLocation(request.query, request.country);
      return { items: place ? [place] : [], total: place ? 1 : 0, resolved: place };
    }
    if (request.level === 'locality') return searchBirthCities(request.country, request.province, request.query, request.offset);
    return request.level === 'auto' ? recognizeBirthplace(request.query, request.country) : searchLocations(request);
  }
  if (request.operation === 'transits')
    return calculateCurrentTransits(request.profile, request.offset_seconds, request.now);
  if (request.operation === 'natal')
    return calculateProfile(request.profile, request.offset_seconds);
  throw new Error('Unsupported operation');
}
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  try {
    process.stdout.write(JSON.stringify(dispatch(JSON.parse(readFileSync(0, 'utf8')))));
  } catch {
    process.stderr.write('thai_calculation_failed');
    process.exitCode = 1;
  }
}
