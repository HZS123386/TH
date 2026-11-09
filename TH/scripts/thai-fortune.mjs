import { calculateThaiHoroscope } from 'thai-astrology';

export const GUIDANCE_VERSION = 'wanjai-thai-guidance-1';
export const TOPIC_RULES = {
  love: { planet: 'venus', number: 6, supportive: [5, 7, 11], reflective: [6, 8, 12] },
  money: { planet: 'jupiter', number: 5, supportive: [2, 5, 9, 11], reflective: [6, 8, 12] },
  family: { planet: 'moon', number: 2, supportive: [1, 4, 5, 9], reflective: [6, 8, 12] },
  work: { planet: 'mercury', number: 4, supportive: [3, 6, 10, 11], reflective: [8, 12] },
};
const shift = (date, days) =>
  new Date(Date.parse(`${date}T12:00:00Z`) + days * 86400000).toISOString().slice(0, 10);
const civil = (date, time) => {
  const [year, month, day] = date.split('-').map(Number),
    [hour, minute] = time.split(':').map(Number);
  return { date: { year, month, day, era: 'CE' }, time: { hour, minute } };
};
export function periodWindow(period, now) {
  const date = now.date,
    year = Number(date.slice(0, 4)),
    month = Number(date.slice(5, 7));
  if (period === 'today')
    return {
      start: date,
      end: date,
      samples: [{ date, time: now.time }],
      sampling: 'current-minute',
    };
  if (period === 'week') {
    const weekday = new Date(`${date}T12:00:00Z`).getUTCDay();
    const start = shift(date, -((weekday + 6) % 7));
    return {
      start,
      end: shift(start, 6),
      samples: Array.from({ length: 7 }, (_, i) => ({ date: shift(start, i), time: '12:00' })),
      sampling: 'daily-noon',
    };
  }
  if (period === 'month') {
    const start = `${year}-${String(month).padStart(2, '0')}-01`,
      days = new Date(Date.UTC(year, month, 0)).getUTCDate();
    return {
      start,
      end: shift(start, days - 1),
      samples: Array.from({ length: days }, (_, i) => ({ date: shift(start, i), time: '12:00' })),
      sampling: 'daily-noon',
    };
  }
  throw new Error('Invalid period');
}
function bucket(position, rule) {
  return rule.supportive.includes(position)
    ? 'supportive'
    : rule.reflective.includes(position)
      ? 'reflective'
      : 'steady';
}
function dominant(counts, count) {
  const [key, value] = Object.entries(counts).sort((a, b) => b[1] - a[1])[0];
  return value / count >= 0.6 ? key : 'mixed';
}

// Analysis uses a stable full-period schedule, independently of the live snapshot.
// These are sign-based native relationships, never Western exact aspects/orbs.
function analysisSample(sample) {
  const points = Object.fromEntries(
    Object.entries(sample.chart.points)
      .filter(([, point]) => point.number !== null)
      .map(([name, point]) => [
        name,
        {
          number: point.number,
          sign: point.sign,
          longitude: point.longitudeDegrees,
        },
      ]),
  );
  const entries = Object.entries(points),
    relationships = [];
  for (let i = 0; i < entries.length; i++) {
    const [from, point] = entries[i];
    const row = sample.chart.relationships.find((item) => item.sign === point.sign);
    if (!row) continue;
    for (const [to, other] of entries.slice(i + 1)) {
      const kind = row.opposition.includes(other.number)
        ? 'opposition'
        : row.squares.flat().includes(other.number)
          ? 'square'
          : row.trines.flat().includes(other.number)
            ? 'trine'
            : row.sextiles.flat().includes(other.number)
              ? 'sextile'
              : null;
      if (kind) relationships.push({ from, to, kind });
    }
  }
  return {
    date: sample.date,
    time: sample.time,
    points,
    relationships,
    lunar: sample.chart.calendar.thaiLunarDate,
  };
}

/** Computed factors + openly versioned editorial rules, without predictive scores. */
export function calculateFortune(request, engine, natal) {
  const { profile, birth_window, period, now } = request;
  const window = periodWindow(period, now);
  const birthCharts = birth_window.map(({ time, offset_seconds }) =>
    calculateThaiHoroscope({
      ...civil(profile.birth_date, time),
      referenceMode: 'traditional',
      planetaryTimeReference: {
        civilUtcOffsetSeconds: offset_seconds,
        referenceUtcOffsetSeconds: engine.planetaryFrameSeconds,
      },
    }),
  );
  const suns = birthCharts.map((chart) => ({
    sign: chart.points.sun.sign,
    longitude: chart.points.sun.longitudeDegrees,
  }));
  // The Sun moves forward by less than one sign over these <=50-hour windows.
  const sunSigns = [...new Set(suns.map((sun) => sun.sign))];
  const full = natal?.status === 'ready' ? natal.chart : null;
  const references = full ? [full.points.ascendant.sign] : sunSigns;
  const basis = full ? 'ascendant' : sunSigns.length === 1 ? 'sun-sign' : 'sun-sign-range';
  const calendarChart = calculateThaiHoroscope({
    ...civil(profile.birth_date, profile.birth_time || '00:00'),
    referenceMode: 'traditional',
  });
  const calendarEnd = profile.birth_time
    ? calendarChart
    : calculateThaiHoroscope({
        ...civil(profile.birth_date, '23:59'),
        referenceMode: 'traditional',
      });
  const lunar =
    JSON.stringify(calendarChart.calendar.thaiLunarDate) ===
    JSON.stringify(calendarEnd.calendar.thaiLunarDate)
      ? calendarChart.calendar.thaiLunarDate
      : null;
  const birthTaksa = profile.birth_time ? calendarChart.taksa : null;
  const samples = window.samples.map((sample) => ({
    ...sample,
    chart: calculateThaiHoroscope({
      ...civil(sample.date, sample.time),
      location: { province: 'กรุงเทพมหานคร' },
    }),
  }));
  const analysisSamples =
    period === 'today'
      ? ['00:00', '06:00', '12:00', '18:00', '23:59'].map((time) => ({
          date: now.date,
          time,
          chart: calculateThaiHoroscope({
            ...civil(now.date, time),
            location: { province: 'กรุงเทพมหานคร' },
          }),
        }))
      : samples;
  const readings = {};
  for (const [topic, rule] of Object.entries(TOPIC_RULES)) {
    const alternatives = references.map((reference) => {
      const counts = { supportive: 0, reflective: 0, steady: 0 };
      const evidence = samples.map((sample) => {
        const point = sample.chart.points[rule.planet];
        const position = ((point.sign - reference + 12) % 12) + 1;
        const code = bucket(position, rule);
        counts[code]++;
        return {
          date: sample.date,
          time: sample.time,
          planet: rule.planet,
          number: rule.number,
          sign: point.sign,
          longitude: point.longitudeDegrees,
          reference_sign: reference,
          position,
          code,
        };
      });
      return {
        reference_sign: reference,
        counts,
        dominant: dominant(counts, samples.length),
        evidence,
      };
    });
    const same = alternatives.every((item) => item.dominant === alternatives[0].dominant);
    readings[topic] = {
      planet: rule.planet,
      number: rule.number,
      code: same ? alternatives[0].dominant : 'mixed',
      consistent_across_birth_window: same,
      alternatives,
    };
  }
  const current =
    period === 'today'
      ? samples[0].chart
      : calculateThaiHoroscope({
          ...civil(now.date, now.time),
          location: { province: 'กรุงเทพมหานคร' },
        });
  return {
    schema_version: 1,
    engine,
    guidance_version: GUIDANCE_VERSION,
    period,
    period_start: window.start,
    period_end: window.end,
    as_of: now.iso,
    time_zone: 'Asia/Bangkok',
    sampling: { method: window.sampling, count: samples.length, dates: window.samples },
    analysis_samples: analysisSamples.map(analysisSample),
    calendar: {
      date: now.date,
      civil_weekday: current.calendar.civilWeekday,
      thai_lunar_date: current.calendar.thaiLunarDate,
      moon: {
        sign: current.points.moon.sign,
        longitude: current.points.moon.longitudeDegrees,
        reference_positions: references.map(
          (sign) => ((current.points.moon.sign - sign + 12) % 12) + 1,
        ),
      },
    },
    birth: {
      date: profile.birth_date,
      civil_weekday: calendarChart.calendar.civilWeekday,
      thai_lunar_date: lunar,
      sun_window: suns,
      sun_signs: sunSigns,
      taksa: birthTaksa,
      astrological_weekday: profile.birth_time ? calendarChart.calendar.astrologicalWeekday : null,
      time_known: !!profile.birth_time,
      zone_known: request.zone_known,
      basis,
      reference_signs: references,
      location: full ? natal.location : null,
      missing: [
        ...(!profile.birth_time ? ['birth_time'] : []),
        ...(!full ? ['precise_location_or_time'] : []),
      ],
    },
    readings,
    limits: {
      predictive_accuracy: 'not-established',
      interpretation: 'versioned-editorial-rules',
      natal_houses_used: !!full,
    },
  };
}
