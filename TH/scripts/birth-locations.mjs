import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { DatabaseSync } from 'node:sqlite';

const regions = JSON.parse(readFileSync(new URL('../backend/content/birth-regions.json', import.meta.url), 'utf8')).items;
const countries = {
  CN: { zh: '中国', th: 'จีน', aliases: ['中华人民共和国', '中国', '中國', 'China', 'ประเทศจีน', 'จีน'] },
  TH: { zh: '泰国', th: 'ไทย', aliases: ['泰国', '泰國', 'Thailand', 'ประเทศไทย', 'ไทย'] },
};
let database;
function db() {
  database ??= new DatabaseSync(fileURLToPath(new URL('../data/birth-locations.sqlite3', import.meta.url)), { readOnly: true });
  return database;
}
const normalized = value => String(value || '').normalize('NFKD').replace(/[\u0300-\u036f\s\p{P}]/gu, '').toLowerCase();
const joined = parts => parts.filter((part, index) => part && part !== parts[index - 1]).join('，');
const priority = "CASE p.feature WHEN 'PPLC' THEN 0 WHEN 'PPLA' THEN 1 WHEN 'PPLA2' THEN 2 WHEN 'ADM2' THEN 3 WHEN 'PPLA3' THEN 4 WHEN 'ADM3' THEN 5 WHEN 'PPLA4' THEN 6 WHEN 'ADM4' THEN 7 ELSE 8 END";

function provincePlace(region) {
  return {
    ...region, placeType: 'province',
    provinceId: region.id, provinceNameEnglish: region.nameEnglish,
    provinceNameChinese: region.nameChinese, provinceNameThai: region.nameThai,
    labelChinese: joined([countries[region.countryCode].zh, region.nameChinese]),
    labelThai: joined([countries[region.countryCode].th, region.nameThai]),
  };
}
function cityPlace(row) {
  const parent = db().prepare('SELECT payload FROM regions WHERE country=? AND admin1=?').get(row.country, row.admin1);
  const region = parent ? JSON.parse(parent.payload) : null;
  return {
    id: `geonames:${row.id}`, geonameId: row.id, countryCode: row.country,
    nameEnglish: row.name_en, nameChinese: row.name_zh, nameThai: row.name_th,
    latitude: row.latitude, longitude: row.longitude, timeZone: row.zone,
    coordinateKind: row.kind, placeType: 'city',
    featureCode: row.feature, admin1Code: row.admin1, admin2Code: row.admin2,
    provinceId: region?.id, provinceNameEnglish: region?.nameEnglish,
    provinceNameChinese: region?.nameChinese, provinceNameThai: region?.nameThai,
    labelChinese: joined([countries[row.country].zh, region?.nameChinese, row.name_zh || row.name_en]),
    labelThai: joined([countries[row.country].th, region?.nameThai, row.name_th || row.name_en]),
  };
}
export function indexedLocation(identifier, country) {
  const match = /^geonames:([1-9][0-9]{0,10})$/.exec(identifier || '');
  if (!match) return null;
  const row = db().prepare('SELECT * FROM places WHERE id=?').get(Number(match[1]));
  if (row && (!country || row.country === country)) return cityPlace(row);
  const region = regions.find(value => value.id === identifier && (!country || value.countryCode === country));
  return region ? provincePlace(region) : null;
}

export function recognizeBirthplace(input, selectedCountry) {
  let query = normalized(input);
  let country = countries[selectedCountry] ? selectedCountry : null;
  if (!query) return { items: [], total: 0, resolved: null };
  const countryWords = String(input).split(/[,，、;；/\s]+/u).map(normalized);
  for (const [code, value] of Object.entries(countries)) {
    const name = value.aliases.map(normalized).find(alias => countryWords.includes(alias)
      || (/[^\x00-\x7f]/u.test(alias) && query.startsWith(alias)));
    if (name) { country = code; query = query.replace(name, ''); break; }
  }
  const parts = String(input).split(/[,，、;；/]+/u).map(normalized);
  const candidates = regions.filter(row => !country || row.countryCode === country).flatMap(region =>
    [region.nameChinese, region.nameThai, region.nameEnglish, ...(region.aliases || [])]
      .map(normalized)
      .filter(name => name.length >= 2 && (query.startsWith(name) || parts.includes(name)))
      .map(name => ({ region, name })),
  ).sort((left, right) => right.name.length - left.name.length);
  const province = candidates[0]?.region;
  let provinceCode;
  if (province) {
    country = province.countryCode;
    query = query.replace(candidates[0].name, '');
    if (!query) {
      const place = provincePlace(province);
      return { items: [place], total: 1, resolved: place };
    }
    const parent = db().prepare('SELECT admin1 FROM regions WHERE country=? AND json_extract(payload,\'$.id\')=?').get(country, province.id);
    provinceCode = parent?.admin1;
  }
  if (!query) {
    const items = regions.filter(row => !country || row.countryCode === country).map(provincePlace);
    return { items, total: items.length, resolved: null };
  }
  return searchPlaces(query, country, provinceCode, 0);
}

// Structured inputs must stay inside the explicitly selected country and province.
export function searchBirthCities(country, provinceId, input, offset = 0) {
  const region = regions.find(row => row.countryCode === country && row.id === provinceId);
  if (!region) return { items: [], total: 0, resolved: null };
  const parent = db().prepare('SELECT admin1 FROM regions WHERE country=? AND json_extract(payload,\'$.id\')=?').get(country, provinceId);
  if (!parent) return { items: [], total: 0, resolved: null };
  return searchPlaces(normalized(input), country, parent.admin1, offset, true);
}

function searchPlaces(query, country, provinceCode, offset, administrative = false) {
  if (!query) {
    if (!country || !provinceCode) return { items: [], total: 0, resolved: null };
    const total = db().prepare('SELECT COUNT(*) AS total FROM places WHERE country=? AND admin1=?').get(country, provinceCode).total;
    const rows = db().prepare(`SELECT p.* FROM places p WHERE p.country=? AND p.admin1=? ORDER BY ${priority},p.population DESC,p.id LIMIT 100 OFFSET ?`).all(country, provinceCode, offset);
    return { items: rows.map(cityPlace), total, resolved: null };
  }
  const where = ['n.country IN (\'CN\',\'TH\')', 'n.name>=?', 'n.name<?'];
  const params = [query, query + '\uffff'];
  if (country) { where.push('p.country=?'); params.push(country); }
  if (provinceCode) { where.push('p.admin1=?'); params.push(provinceCode); }
  if (!administrative) where.push('p.feature NOT LIKE \'ADM%\'');
  const condition = where.join(' AND ');
  const total = db().prepare(`SELECT COUNT(DISTINCT n.id) AS total FROM names n JOIN places p ON p.id=n.id WHERE ${condition}`).get(...params).total;
  const matches = db().prepare(`SELECT p.*,MIN(CASE WHEN n.name=? THEN 0 ELSE 1 END) AS match_rank,
    ${priority} AS priority
    FROM names n JOIN places p ON p.id=n.id WHERE ${condition} GROUP BY p.id
    ORDER BY match_rank,priority,p.population DESC,p.id LIMIT 100 OFFSET ?`).all(query, ...params, offset);
  const items = matches.map(cityPlace);
  // Homonymous places require confirmation instead of guessing from population.
  const exactCount = db().prepare(`SELECT COUNT(DISTINCT n.id) AS total FROM names n JOIN places p ON p.id=n.id WHERE ${condition} AND n.name=?`).get(...params, query).total;
  const resolved = offset === 0 && exactCount === 1 ? items[0] : null;
  return { items, total, resolved };
}
