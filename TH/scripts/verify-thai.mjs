import assert from 'node:assert/strict';
import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import {
  calculateThaiHoroscope,
  calculateSunrise,
  resolveCivilTimeOffset,
  getThaiAstrologyProvinceLocations,
} from 'thai-astrology';
import { ENGINE, calculateProfile, calculateCurrentTransits } from './thai-engine.mjs';

const read = (path) => JSON.parse(readFileSync(path, 'utf8'));
const checks = [];
function check(group, name, run) {
  try {
    const evidence = run();
    checks.push({ group, name, passed: true, ...evidence });
  } catch (error) {
    checks.push({ group, name, passed: false, error: error.message });
  }
}
const input = {
  date: { year: 2024, era: 'CE', month: 9, day: 15 },
  time: { hour: 8, minute: 30 },
  location: { province: 'เชียงใหม่' },
};
const profile = {
  birth_date: '2024-09-15',
  birth_time: '08:30',
  timezone: 'Asia/Bangkok',
  birthplace: 'Chiang Mai',
  country_code: 'TH',
};
check('release-regression', 'Published README example; CE/BE and adapter equivalence', () => {
  const chart = calculateThaiHoroscope(input);
  assert.equal(chart.points.ascendant.sign, 5);
  assert.equal(chart.points.sun.sign, 4);
  assert.deepEqual(chart.charts.rasi.channels.thai, [
    '',
    '๕*๐',
    '๓',
    '',
    '๑๔',
    'ลั๖',
    '',
    '',
    '๙',
    '๒',
    '๗',
    '๘',
  ]);
  assert.deepEqual(
    chart.calendar.thaiLunarDate && [
      chart.calendar.thaiLunarDate.phase,
      chart.calendar.thaiLunarDate.day,
      chart.calendar.thaiLunarDate.month,
    ],
    ['waxing', 13, 10],
  );
  assert.deepEqual(
    chart,
    calculateThaiHoroscope({ ...input, date: { ...input.date, year: 2567, era: 'BE' } }),
  );
  const adapted = calculateProfile(profile, 25200).chart;
  assert.deepEqual(adapted.points, chart.points);
  assert.deepEqual(adapted.taksa, chart.taksa);
  return {
    source: `${ENGINE.source}/blob/${ENGINE.commit}/README-en.md`,
    independent: false,
    note: 'Regression against the published package example, not an independent planetary oracle.',
  };
});
for (const place of getThaiAstrologyProvinceLocations())
  check('province-invariants', place.province, () => {
    const chart = calculateThaiHoroscope({ ...input, location: { province: place.province } });
    assert.equal(Object.keys(chart.points).length, 11);
    assert.equal(chart.houses.length, 12);
    for (const point of Object.values(chart.points)) {
      assert.ok(point.longitudeDegrees >= 0 && point.longitudeDegrees < 360);
      assert.equal(point.house, ((point.sign - chart.points.ascendant.sign + 12) % 12) + 1);
    }
    for (const division of Object.values(chart.charts))
      assert.equal(division.channels.thai.length, 12);
    assert.equal(chart.points.ascendant.house, 1);
  });
check('boundaries', '06:00 weekday boundary, including Wednesday night convention', () => {
  const before = calculateThaiHoroscope({
    ...input,
    date: { ...input.date, day: 18 },
    time: { hour: 5, minute: 59 },
  });
  const after = calculateThaiHoroscope({
    ...input,
    date: { ...input.date, day: 18 },
    time: { hour: 6, minute: 0 },
  });
  const night = calculateThaiHoroscope({
    ...input,
    date: { ...input.date, day: 18 },
    time: { hour: 23, minute: 59 },
  });
  assert.equal(before.calendar.civilWeekday, 4);
  assert.equal(before.calendar.astrologicalWeekday, 3);
  assert.equal(after.calendar.astrologicalWeekday, 4);
  assert.deepEqual(night.taksa, after.taksa);
  assert.equal(after.taksa.boriwan, 4);
});
check('boundaries', 'Unknown time and unresolved place never fabricate a full chart', () => {
  const unknown = calculateProfile({ ...profile, birth_time: null }, null);
  assert.equal(unknown.status, 'time-unknown');
  assert.equal(unknown.chart, null);
  assert.equal(unknown.taksa, null);
  assert.equal(unknown.calendar.astrologicalWeekday, null);
  const missing = calculateProfile({ ...profile, birthplace: 'not a catalog city' }, 25200);
  assert.equal(missing.status, 'location-required');
  assert.equal(missing.chart, null);
  assert.ok(missing.taksa);
});
check('boundaries', 'Transit natal houses and shortest differences stay in range', () => {
  const result = calculateCurrentTransits(profile, 25200, {
    date: '2026-11-05',
    time: '09:30',
    iso: '2026-11-05T09:30:00+07:00',
  });
  for (const [key, factor] of Object.entries(result.comparison)) {
    assert.equal(
      factor.natalHouse,
      ((result.transit.points[key].sign -
        calculateProfile(profile, 25200).chart.points.ascendant.sign +
        12) %
        12) +
        1,
    );
    assert.ok(factor.longitudeDifferenceDegrees >= -180 && factor.longitudeDifferenceDegrees < 180);
  }
});

const upstream = read('scripts/fixtures/thai/usno-upstream.json');
const unique = [...new Map(upstream.cases.map((row) => [JSON.stringify(row), row])).values()];
function compareSunrise(row) {
  const result = calculateSunrise(row);
  if (row.expectedSunriseMinutes === null) {
    assert.equal(result.status, 'no-rise');
    return { noRise: true };
  }
  assert.equal(result.status, 'rise');
  const errorMinutes = Math.abs(result.timeMinutes - row.expectedSunriseMinutes);
  assert.ok(
    errorMinutes <= 2,
    `Sunrise error ${errorMinutes} exceeds predeclared 2-minute tolerance`,
  );
  return {
    expectedMinutes: row.expectedSunriseMinutes,
    actualMinutes: result.timeMinutes,
    errorMinutes,
  };
}
unique.forEach((row, i) =>
  check('sunrise-upstream-fixtures', `USNO fixture ${i + 1}`, () => ({
    ...compareSunrise(row),
    input: row,
    source: `${ENGINE.source}/blob/${ENGINE.commit}/test/fixtures/sunrise-events.json`,
    independentlyRetrieved: false,
  })),
);

const live = [
  ['usno-bangkok-summer.json', '2024-06-21', 13.7563, 100.5018, 7],
  ['usno-bangkok-winter.json', '2024-12-21', 13.7563, 100.5018, 7],
  ['usno-chiangmai.json', '2024-09-15', 18.79038, 98.98468, 7],
  ['usno-newyork.json', '2024-03-10', 40.7128, -74.006, -4],
];
for (const [file, date, latitude, longitude, utcOffsetHours] of live)
  check('sunrise-independent-fetch', file, () => {
    const path = `public/reports/thai-evidence/${file}`,
      raw = read(path);
    assert.deepEqual(raw.geometry.coordinates, [longitude, latitude]);
    const data = raw.properties.data,
      sunrise = data.sundata.find((row) => row.phen === 'Rise');
    assert.equal(data.tz, utcOffsetHours);
    assert.equal(data.isdst, false);
    const [hour, minute] = sunrise.time.split(':').map(Number);
    const [yearCe, month, day] = date.split('-').map(Number);
    assert.equal(data.year, yearCe);
    assert.equal(data.month, month);
    assert.equal(data.day, day);
    return {
      ...compareSunrise({
        yearCe,
        month,
        day,
        latitude,
        longitude,
        utcOffsetHours,
        expectedSunriseMinutes: hour * 60 + minute,
      }),
      source: `https://aa.usno.navy.mil/api/rstt/oneday?date=${date}&coords=${latitude},${longitude}&tz=${utcOffsetHours}`,
      rawEvidence: `/reports/thai-evidence/${file}`,
      sha256: createHash('sha256').update(readFileSync(path)).digest('hex'),
      retrievedDate: '2026-11-05',
      apiVersion: raw.apiversion,
      independentlyRetrieved: true,
    };
  });

const offsets = read('scripts/fixtures/thai/iana-2025b.json');
offsets.cases.forEach((row, i) =>
  check('iana-offsets', `Time zone ${i + 1}: ${row.timeZone}`, () => {
    if (row.candidates.length !== 1)
      assert.throws(() => resolveCivilTimeOffset(row.civilTime, row.timeZone));
    if (!row.candidates.length) return { status: 'civil-time-gap-rejected' };
    for (const [index, candidate] of row.candidates.entries()) {
      const actual = resolveCivilTimeOffset(
        row.civilTime,
        row.timeZone,
        index === 0 ? 'earlier' : 'later',
      );
      assert.equal(actual.utcEpochMilliseconds, candidate.utcEpochMilliseconds);
      assert.equal(actual.utcOffsetHours, candidate.utcOffsetHours);
    }
    return {
      source: offsets.source,
      sourceVersion: offsets.sourceVersion,
      note: 'Upstream distilled IANA facts; Intl runtime comparison, not a new timezone audit.',
    };
  }),
);
const lunarAnchors = [
  ['2024-02-24', 3, 'https://uttaradit.prd.go.th/th/content/page/index/id/263536'],
  ['2024-05-22', 6, 'https://www.prd.go.th/th/content/category/detail/id/31/iid/288362'],
  ['2024-07-20', 8, 'https://nan.prd.go.th/th/content/category/detail/id/9/iid/308385'],
];
for (const [date, month, source] of lunarAnchors)
  check('thai-calendar-anchors', date, () => {
    const actual = calculateProfile({ ...profile, birth_date: date, birth_time: '12:00' }, 25200)
      .calendar.thaiLunarDate;
    assert.equal(actual?.phase, 'waxing');
    assert.equal(actual.day, 15);
    assert.equal(actual.month, month);
    return {
      expected: { phase: 'waxing', day: 15, month },
      actual,
      source,
      note: 'Three fixed 2024 dates only; not a representative estimate of calendar accuracy.',
    };
  });

const groups = Object.fromEntries(
  [...new Set(checks.map((c) => c.group))].map((group) => {
    const cases = checks.filter((c) => c.group === group),
      errors = cases.filter((c) => c.errorMinutes !== undefined).map((c) => c.errorMinutes);
    return [
      group,
      {
        cases: cases.length,
        passed: cases.filter((c) => c.passed).length,
        failed: cases.filter((c) => !c.passed).length,
        ...(errors.length
          ? {
              maxErrorMinutes: Math.max(...errors),
              meanErrorMinutes: errors.reduce((a, b) => a + b, 0) / errors.length,
            }
          : {}),
      },
    ];
  }),
);
const report = {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  engine: ENGINE,
  environment: { node: process.version, icu: process.versions.icu, tz: process.versions.tz },
  summary: {
    cases: checks.length,
    passed: checks.filter((c) => c.passed).length,
    failed: checks.filter((c) => !c.passed).length,
  },
  groups,
  checks,
  independentPlanetaryValidation: {
    status: 'pending-same-school-external-reference',
    samples: 0,
    note: 'No independent Suriyayatra planetary/ascendant oracle was available. Package examples and invariants cannot establish external positional accuracy.',
  },
  predictiveAccuracy: {
    status: 'not-established',
    percentage: null,
    note: 'No prospective outcome study. Software pass counts, sunrise errors and satisfaction scores do not measure fortune-telling predictive accuracy.',
  },
};
writeFileSync('public/reports/thai-validation.json', JSON.stringify(report, null, 2) + '\n');
console.log(
  JSON.stringify(
    { ...report.summary, groups, report: 'public/reports/thai-validation.json' },
    null,
    2,
  ),
);
if (report.summary.failed) {
  console.error(
    JSON.stringify(
      checks.filter((c) => !c.passed),
      null,
      2,
    ),
  );
  process.exitCode = 1;
}
